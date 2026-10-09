import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'hinge_state.dart';
import 'ios_fold_reading.dart';

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
    this.safeAreaInsets = EdgeInsets.zero,
    this.verticalBarEdge = IosVerticalBarEdge.none,
    this.statusBarBounds,
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

  /// 宿主视图的安全区，逻辑像素。
  ///
  /// iPhone Duo 的侧向 inset 就是竖排栏所在的那条安全区。顶部 inset 不是灵动岛：
  /// 灵动岛长在侧栏里，高度看 [statusBarBounds] 和遮挡矩形。
  final EdgeInsets safeAreaInsets;

  /// 系统要把竖排栏放在哪条物理边。没有竖排栏时为 [IosVerticalBarEdge.none]。
  final IosVerticalBarEdge verticalBarEdge;

  /// 状态栏在 Flutter 视图里的矩形。隐藏或读不到时为 null。
  ///
  /// 竖排时这是侧栏里的一条竖条，底边会随灵动岛变高。横排时它横跨窗口，
  /// 调用方应自己忽略，不要把它当成顶部安全区。
  final Rect? statusBarBounds;

  @override
  bool operator ==(Object other) {
    return other is ArrangementState &&
        other.hinge == hinge &&
        other.safeAreaInsets == safeAreaInsets &&
        other.verticalBarEdge == verticalBarEdge &&
        other.statusBarBounds == statusBarBounds &&
        listEquals(other.displayFeatures, displayFeatures) &&
        listEquals(other.inactiveDisplayFeatures, inactiveDisplayFeatures);
  }

  @override
  int get hashCode => Object.hash(
    hinge,
    safeAreaInsets,
    verticalBarEdge,
    statusBarBounds,
    Object.hashAll(displayFeatures),
    Object.hashAll(inactiveDisplayFeatures),
  );

  @override
  String toString() {
    return 'ArrangementState(hinge: $hinge, '
        'safeAreaInsets: $safeAreaInsets, '
        'verticalBarEdge: $verticalBarEdge, '
        'statusBarBounds: $statusBarBounds, '
        'displayFeatures: $displayFeatures, '
        'inactiveDisplayFeatures: $inactiveDisplayFeatures)';
  }
}
