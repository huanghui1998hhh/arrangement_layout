import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 分隔生效之后，overlay 的 primary 所靠的边。
///
/// [leading] 和 [trailing] 跟随 [Directionality]。[top] 和 [bottom] 是物理方向。
enum ArrangementEdge {
  /// 书写方向的起始边。
  leading,

  /// 书写方向的结束边。
  trailing,

  /// 上方。
  top,

  /// 下方。
  bottom,
}

/// 两块内容的关系。
///
/// [automatic] 等于 [ArrangementStyle.split]。尺寸偏好写在样式上：
/// split 只有轴、比例和最小尺寸，overlay 只有分开后靠哪条边以及层叠时的浮层。
sealed class ArrangementStyle {
  const ArrangementStyle();

  /// 系统默认关系，解析成 [ArrangementStyle.split]。
  static const ArrangementStyle automatic = SplitArrangementStyle();

  /// 两块内容互不遮挡。空间不够沿允许的轴切开时，只留 primary。
  const factory ArrangementStyle.split({
    Set<Axis> axes,
    double? ratio,
    double minPrimaryExtent,
    double minSecondaryExtent,
  }) = SplitArrangementStyle;

  /// 没有分界时 primary 浮在 secondary 上；有分界时改到分界两侧。
  const factory ArrangementStyle.overlay({
    ArrangementEdge horizontalEdge,
    ArrangementEdge verticalEdge,
    AlignmentDirectional layeredAlignment,
    EdgeInsetsGeometry layeredPadding,
    BoxConstraints layeredConstraints,
  }) = OverlayArrangementStyle;
}

/// 并排关系。
///
/// [axes] 决定允许沿哪条轴切开。更宽时用 [Axis.horizontal]，更高时用
/// [Axis.vertical]；该轴不在集合里就只显示 primary。
/// [ratio] 只在没有分界时生效，表示 primary 沿分栏轴所占的比例，省略时为 0.5。
/// 有分界时分界矩形优先，比例不参与。
/// [minPrimaryExtent] 和 [minSecondaryExtent] 是沿分栏轴的最小尺寸，某一侧达不到
/// 就不硬挤成两栏。
class SplitArrangementStyle extends ArrangementStyle {
  /// 创建并排关系。
  const SplitArrangementStyle({
    this.axes = const <Axis>{Axis.horizontal, Axis.vertical},
    this.ratio,
    this.minPrimaryExtent = 320,
    this.minSecondaryExtent = 320,
  }) : assert(ratio == null || (ratio > 0 && ratio < 1)),
       assert(minPrimaryExtent >= 0),
       assert(minSecondaryExtent >= 0);

  /// 允许切开的轴。
  final Set<Axis> axes;

  /// 无分界时 primary 所占的比例。null 表示 0.5。
  final double? ratio;

  /// primary 沿分栏轴的最小尺寸。
  final double minPrimaryExtent;

  /// secondary 沿分栏轴的最小尺寸。
  final double minSecondaryExtent;

  @override
  bool operator ==(Object other) {
    return other is SplitArrangementStyle &&
        setEquals(other.axes, axes) &&
        other.ratio == ratio &&
        other.minPrimaryExtent == minPrimaryExtent &&
        other.minSecondaryExtent == minSecondaryExtent;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(axes),
    ratio,
    minPrimaryExtent,
    minSecondaryExtent,
  );

  @override
  String toString() {
    return 'ArrangementStyle.split(axes: $axes, ratio: $ratio, '
        'minPrimaryExtent: $minPrimaryExtent, '
        'minSecondaryExtent: $minSecondaryExtent)';
  }
}

/// 层叠关系。
///
/// 没有分界时 secondary 铺满，primary 按 [layeredAlignment] 放在
/// [layeredPadding] 留出的区域内，尺寸受 [layeredConstraints] 限制。
/// 出现竖直分界时 primary 靠 [horizontalEdge]；出现水平分界时 primary 靠
/// [verticalEdge]。
class OverlayArrangementStyle extends ArrangementStyle {
  /// 创建层叠关系。
  const OverlayArrangementStyle({
    this.horizontalEdge = ArrangementEdge.trailing,
    this.verticalEdge = ArrangementEdge.bottom,
    this.layeredAlignment = AlignmentDirectional.topStart,
    this.layeredPadding = const EdgeInsets.all(16),
    this.layeredConstraints = const BoxConstraints(maxWidth: 400),
  }) : assert(
         horizontalEdge == ArrangementEdge.leading ||
             horizontalEdge == ArrangementEdge.trailing,
       ),
       assert(
         verticalEdge == ArrangementEdge.top ||
             verticalEdge == ArrangementEdge.bottom,
       );

  /// 竖直分界（左右两块）时 primary 所靠的边。
  final ArrangementEdge horizontalEdge;

  /// 水平分界（上下两块）时 primary 所靠的边。
  final ArrangementEdge verticalEdge;

  /// 层叠时浮层在留白区域内的对齐。
  final AlignmentDirectional layeredAlignment;

  /// 层叠时浮层与容器边缘的间距。
  final EdgeInsetsGeometry layeredPadding;

  /// 层叠时测量浮层使用的约束。浮层不会超出留白区域。
  final BoxConstraints layeredConstraints;

  @override
  bool operator ==(Object other) {
    return other is OverlayArrangementStyle &&
        other.horizontalEdge == horizontalEdge &&
        other.verticalEdge == verticalEdge &&
        other.layeredAlignment == layeredAlignment &&
        other.layeredPadding == layeredPadding &&
        other.layeredConstraints == layeredConstraints;
  }

  @override
  int get hashCode => Object.hash(
    horizontalEdge,
    verticalEdge,
    layeredAlignment,
    layeredPadding,
    layeredConstraints,
  );

  @override
  String toString() {
    return 'ArrangementStyle.overlay(horizontalEdge: $horizontalEdge, '
        'verticalEdge: $verticalEdge)';
  }
}
