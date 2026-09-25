import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'hinge_state.dart';

/// 一次合并后的折叠屏状态。
///
/// 几何只用 [DisplayFeature]。[displayFeatures] 是当前会影响布局的特征，
/// 也是 [ArrangementScope] 默认写进 `MediaQuery.displayFeatures` 的那一份。
/// [inactiveDisplayFeatures] 是设备上存在、但当前不该切开布局的特征
/// （摊平后仍有宽度的折痕、尚未开启的摄像头），调用方可以用来区分
/// 折叠设备和普通大屏，但不应写回 `MediaQuery`。
class ArrangementState {
  /// 创建一份状态。
  const ArrangementState({
    required this.displayFeatures,
    required this.inactiveDisplayFeatures,
    required this.hinge,
  });

  /// 没有折叠特征、也没有铰链读数。
  static const ArrangementState empty = ArrangementState(
    displayFeatures: <DisplayFeature>[],
    inactiveDisplayFeatures: <DisplayFeature>[],
    hinge: null,
  );

  /// 当前生效、可以注入 `MediaQuery` 的特征。
  final List<DisplayFeature> displayFeatures;

  /// 存在但当前不生效的特征。永不注入 `MediaQuery`。
  final List<DisplayFeature> inactiveDisplayFeatures;

  /// 铰链角度与姿态。当前平台或设备提供不了时为 null。
  final HingeState? hinge;

  @override
  bool operator ==(Object other) {
    return other is ArrangementState &&
        other.hinge == hinge &&
        listEquals(other.displayFeatures, displayFeatures) &&
        listEquals(other.inactiveDisplayFeatures, inactiveDisplayFeatures);
  }

  @override
  int get hashCode => Object.hash(
    hinge,
    Object.hashAll(displayFeatures),
    Object.hashAll(inactiveDisplayFeatures),
  );

  @override
  String toString() {
    return 'ArrangementState(hinge: $hinge, '
        'displayFeatures: $displayFeatures, '
        'inactiveDisplayFeatures: $inactiveDisplayFeatures)';
  }
}
