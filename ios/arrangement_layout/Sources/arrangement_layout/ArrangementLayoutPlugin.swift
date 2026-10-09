import Flutter
import QuartzCore
import UIKit

/// 把 iPhone Duo 的铰链、reserved region、安全区和状态栏发到 `arrangement_layout/fold`。
///
/// 编译需要 Xcode 27.1。运行在更早的系统上时，事件里的铰链为 null、区域为空，
/// 竖排栏边为 none；安全区和状态栏仍然上报。
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
    var verticalBarEdge = "none"
    if #available(iOS 27.1, *) {
      regions += payloads(
        probe.reservedRegions(kind: .division, options: .includeInactive),
        kind: "division"
      )
      regions += payloads(
        probe.reservedRegions(kind: .occlusion, options: .includeInactive),
        kind: "occlusion"
      )
      verticalBarEdge = Self.verticalBarEdgeName(of: probe)
    }
    let payload: [String: Any] = [
      "hinge": latestHinge ?? NSNull(),
      "regions": regions,
      "safeArea": Self.safeAreaPayload(of: probe),
      "verticalBarEdge": verticalBarEdge,
      "statusBar": Self.statusBarPayload(in: probe),
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

  /// leading / trailing 换成物理左右，竖排按钮才不会跟着书写方向镜像到错误的一边。
  @available(iOS 27.1, *)
  private static func verticalBarEdgeName(of view: UIView) -> String {
    let rightToLeft = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
    switch view.traitCollection.verticalBarEdge {
    case .leading:
      return rightToLeft ? "right" : "left"
    case .trailing:
      return rightToLeft ? "left" : "right"
    case .unspecified:
      return "none"
    @unknown default:
      return "none"
    }
  }

  private static func safeAreaPayload(of view: UIView) -> [String: Double] {
    let insets = view.safeAreaInsets
    return [
      "l": Double(insets.left),
      "t": Double(insets.top),
      "r": Double(insets.right),
      "b": Double(insets.bottom),
    ]
  }

  /// `statusBarFrame` 在屏幕坐标系里。转成 Flutter 视图坐标后，竖排状态栏的底边
  /// 才能跟着灵动岛变高。隐藏或还没进 window 时上报 null。
  private static func statusBarPayload(in view: UIView) -> Any {
    guard let window = view.window,
          let manager = window.windowScene?.statusBarManager
    else { return NSNull() }
    let frame = manager.statusBarFrame
    guard !frame.isNull, !frame.isEmpty,
          frame.origin.x.isFinite, frame.origin.y.isFinite,
          frame.size.width.isFinite, frame.size.height.isFinite
    else { return NSNull() }
    let inWindow = window.convert(frame, from: window.screen.coordinateSpace)
    let inView = view.convert(inWindow, from: window)
    guard !inView.isNull, !inView.isEmpty else { return NSNull() }
    return [
      "l": Double(inView.minX),
      "t": Double(inView.minY),
      "r": Double(inView.maxX),
      "b": Double(inView.maxY),
    ]
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
    publishLayout()
  }

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    publishLayout()
  }

  /// 安全区变化不一定等到下一次 layout。灵动岛长高时两侧都会走到这里。
  private func publishLayout() {
    guard !publishing else { return }
    publishing = true
    onLayout?()
    publishing = false
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    nil
  }
}
