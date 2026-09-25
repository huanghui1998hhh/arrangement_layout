/// 铰链姿态，与 iOS 27.1 的 `UIHinge.Status` 一一对应。
///
/// Android 没有「合上」这一档：引擎只在展开后的窗口上报折叠特征，
/// 因此只能推出 [partiallyOpen] 或 [fullyOpen]。
enum HingePosture {
  /// 平台没有给出可识别的姿态。
  unknown,

  /// 设备合上，当前窗口在外屏。
  closed,

  /// 介于合上与完全展开之间。
  partiallyOpen,

  /// 铰链已经开到设备允许的最大角度。
  fullyOpen,
}

/// 铰链读数。
///
/// [angle] 单位是弧度，0 为合上，π 为摊平。平台没有连续角度时为 null，
/// 不会用姿态去伪造一个角度。
class HingeState {
  /// 创建一份铰链读数。
  const HingeState({required this.posture, this.angle});

  /// 当前姿态。
  final HingePosture posture;

  /// 铰链角度，单位弧度。取不到时为 null。
  final double? angle;

  @override
  bool operator ==(Object other) {
    return other is HingeState &&
        other.posture == posture &&
        other.angle == angle;
  }

  @override
  int get hashCode => Object.hash(posture, angle);

  @override
  String toString() => 'HingeState($posture, angle: $angle)';
}
