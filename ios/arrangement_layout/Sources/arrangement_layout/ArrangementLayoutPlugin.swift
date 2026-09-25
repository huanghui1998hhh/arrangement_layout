import Flutter
import QuartzCore
import UIKit

/// 把 iPhone Duo 的铰链和 reserved region 发到 `arrangement_layout/fold`。
///
/// 编译需要 Xcode 27.1。运行在更早的系统上时，事件里的铰链为 null、区域为空。
@objc(ArrangementLayoutPlugin)
public final class ArrangementLayoutPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let registrar: FlutterPluginRegistrar
  private let channel: FlutterEventChannel
  private var sink: FlutterEventSink?
  private var probe: RegionProbeView?
  private var hingeInteraction: UIInteraction?
  private var displayLink: CADisplayLink?
  private var latestHinge: [String: Any]?
  private var lastPayload: NSDictionary?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    channel = FlutterEventChannel(
      name: "arrangement_layout/fold",
      binaryMessenger: registrar.messenger()
    )
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = ArrangementLayoutPlugin(registrar: registrar)
    instance.channel.setStreamHandler(instance)
    registrar.publish(instance)
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    detach()
    sink = events
    if !attachIfPossible() {
      startWaitingForView()
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    detach()
    return nil
  }

  deinit {
    displayLink?.invalidate()
  }

  /// UIScene 下注册插件时 viewController 可能还是 nil，所以挂接放在开始监听之后。
  private func attachIfPossible() -> Bool {
    guard let flutterView = registrar.viewController?.view else {
      return false
    }
    if hingeInteraction == nil, #available(iOS 27.1, *) {
      let interaction = UIHingeInteraction { [weak self] _, update in
        guard let self else { return }
        if let hinge = update.hinge {
          self.latestHinge = [
            "status": Self.statusName(hinge.status),
            "angle": Double(hinge.angle),
          ]
        } else {
          self.latestHinge = nil
        }
        self.probe?.setNeedsLayout()
      }
      flutterView.addInteraction(interaction)
      hingeInteraction = interaction
    }
    if probe == nil {
      let probe = RegionProbeView(frame: flutterView.bounds)
      probe.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      probe.isUserInteractionEnabled = false
      probe.backgroundColor = .clear
      probe.isHidden = false
      probe.onLayout = { [weak self] in
        self?.publish()
      }
      flutterView.addSubview(probe)
      self.probe = probe
    }
    return true
  }

  private func publish() {
    guard let probe, sink != nil else { return }
    var regions: [[String: Any]] = []
    if #available(iOS 27.1, *) {
      regions += payloads(
        probe.reservedRegions(kind: .division, options: .includeInactive),
        kind: "division"
      )
      regions += payloads(
        probe.reservedRegions(kind: .occlusion, options: .includeInactive),
        kind: "occlusion"
      )
    }
    let payload: [String: Any] = [
      "hinge": latestHinge ?? NSNull(),
      "regions": regions,
    ]
    let boxed = payload as NSDictionary
    if let lastPayload, lastPayload.isEqual(boxed) {
      return
    }
    lastPayload = boxed
    sink?(payload)
  }

  @available(iOS 27.1, *)
  private func payloads(
    _ regions: [UIView.ReservedRegion],
    kind: String
  ) -> [[String: Any]] {
    regions.map { region in
      let frame = region.frame
      return [
        "kind": kind,
        "l": Double(frame.minX),
        "t": Double(frame.minY),
        "r": Double(frame.maxX),
        "b": Double(frame.maxY),
        "active": region.isActive,
      ]
    }
  }

  @available(iOS 27.1, *)
  private static func statusName(_ status: UIHinge.Status) -> String {
    switch status {
    case .unknown:
      return "unknown"
    case .closed:
      return "closed"
    case .partiallyOpen:
      return "partiallyOpen"
    case .fullyOpen:
      return "fullyOpen"
    @unknown default:
      return "unknown"
    }
  }

  private func startWaitingForView() {
    guard displayLink == nil else { return }
    let link = CADisplayLink(target: self, selector: #selector(tryAttach))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  @objc private func tryAttach() {
    guard sink != nil else {
      stopWaiting()
      return
    }
    if attachIfPossible() {
      stopWaiting()
    }
  }

  private func stopWaiting() {
    displayLink?.invalidate()
    displayLink = nil
  }

  private func detach() {
    stopWaiting()
    probe?.removeFromSuperview()
    probe = nil
    if let hingeInteraction, let view = registrar.viewController?.view {
      view.removeInteraction(hingeInteraction)
    }
    hingeInteraction = nil
    latestHinge = nil
    lastPayload = nil
  }
}

/// 铺满 Flutter 视图、不接收触摸。在 layoutSubviews 里读取 reserved region，
/// UIKit 才会在区域变化时再排一次布局。
private final class RegionProbeView: UIView {
  var onLayout: (() -> Void)?
  private var publishing = false

  override func layoutSubviews() {
    super.layoutSubviews()
    guard !publishing else { return }
    publishing = true
    onLayout?()
    publishing = false
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    nil
  }
}
