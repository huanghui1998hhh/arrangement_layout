import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'arrangement_pane.dart';
import 'arrangement_style.dart';

/// 一次布局决策的结果。
///
/// [primary] 或 [secondary] 为 null 表示这块本次不摆放，但 widget 仍然留在树上。
/// [floatRegion] 只在 [ArrangementPresentation.overlayLayered] 时有值，
/// 浮层的最终 frame 要等测完 child 的自然尺寸才能确定。
class ArrangementResolution {
  /// 创建一份决策结果。
  const ArrangementResolution({
    required this.presentation,
    required this.axis,
    required this.primary,
    required this.secondary,
    required this.floatRegion,
  });

  /// 当前呈现。
  final ArrangementPresentation presentation;

  /// 并排时的分栏轴。层叠和只显示 primary 时为 null。
  final Axis? axis;

  /// primary 的 frame。层叠时为 null，改用 [floatRegion]。
  final Rect? primary;

  /// secondary 的 frame。只显示 primary 时为 null。
  final Rect? secondary;

  /// 层叠时浮层可以对齐进去的区域。
  final Rect? floatRegion;

  @override
  bool operator ==(Object other) {
    return other is ArrangementResolution &&
        other.presentation == presentation &&
        other.axis == axis &&
        other.primary == primary &&
        other.secondary == secondary &&
        other.floatRegion == floatRegion;
  }

  @override
  int get hashCode =>
      Object.hash(presentation, axis, primary, secondary, floatRegion);

  @override
  String toString() {
    return 'ArrangementResolution($presentation, axis: $axis, '
        'primary: $primary, secondary: $secondary, floatRegion: $floatRegion)';
  }
}

/// 从显示特征里取出会把容器切成两块的分界，并转成容器本地坐标。
///
/// [hinge] 不论姿态都保留，摊平的物理铰链仍然是碰不到的间隙。
/// [fold] 只在 [DisplayFeatureState.postureHalfOpened] 时保留。
/// 挖孔和容器不相交的特征丢掉。宽度为 0 的折痕保留，分界就是一条线。
///
/// 多个分界同时存在时，[resolveArrangement] 取和容器重叠面积最大的一个；
/// 面积相同则保留本列表里更靠前的那个。
List<Rect> separatingFeatures({
  required List<DisplayFeature> features,
  required Rect container,
}) {
  if (container.width <= 0 || container.height <= 0) {
    return const <Rect>[];
  }
  final List<Rect> result = <Rect>[];
  for (final DisplayFeature feature in features) {
    if (!_separates(feature) || !_overlaps(feature.bounds, container)) {
      continue;
    }
    final Rect clipped = Rect.fromLTRB(
      math.max(feature.bounds.left, container.left),
      math.max(feature.bounds.top, container.top),
      math.min(feature.bounds.right, container.right),
      math.min(feature.bounds.bottom, container.bottom),
    );
    result.add(clipped.shift(-container.topLeft));
  }
  return List<Rect>.unmodifiable(result);
}

/// 按容器尺寸、分界和样式决定两块内容的 frame。
///
/// 决策顺序：
///
/// 1. 竖直分界要求左右分栏，水平分界要求上下分栏。
/// 2. split 的该轴被允许，且两侧都达到最小尺寸：贴着分界摆放，不用 [SplitArrangementStyle.ratio]。
///    左右分栏时 primary 在 leading，上下分栏时 primary 在上。
///    overlay 只要两侧都有正的尺寸就分开，primary 靠样式里的边。
/// 3. split 的轴不被允许，或某一侧小于最小尺寸：只显示 primary，frame 落在较大的一侧，
///    不横跨间隙。两侧一样大时，竖直分界选 trailing，水平分界选上半。
///    overlay 某一侧没有可用空间时，在较大的一侧里层叠。
/// 4. 没有分界时，split 才看宽高比和最小尺寸。宽大于等于高视为更宽。
///    overlay 没有分界时始终层叠。
/// 5. 其余情况 split 只显示 primary，frame 是整个容器。
///
/// 折痕矩形不因书写方向镜像。leading / trailing 才跟随 [textDirection]。
ArrangementResolution resolveArrangement({
  required Size size,
  required List<Rect> separators,
  required TextDirection textDirection,
  required ArrangementStyle style,
}) {
  if (size.width <= 0 || size.height <= 0) {
    return _primaryOnly(Rect.zero);
  }
  final Rect? separator = _dominant(separators);
  return switch (style) {
    SplitArrangementStyle split =>
      separator == null
          ? _splitByAspect(size, textDirection, split)
          : _splitBySeparator(size, textDirection, split, separator),
    OverlayArrangementStyle overlay =>
      separator == null
          ? _layered(Offset.zero & size, textDirection, overlay)
          : _overlayBySeparator(size, textDirection, overlay, separator),
  };
}

bool _separates(DisplayFeature feature) {
  return switch (feature.type) {
    DisplayFeatureType.hinge => true,
    DisplayFeatureType.fold =>
      feature.state == DisplayFeatureState.postureHalfOpened,
    DisplayFeatureType.cutout || DisplayFeatureType.unknown => false,
  };
}

bool _overlaps(Rect a, Rect b) {
  if (a.right < b.left || b.right < a.left) {
    return false;
  }
  if (a.bottom < b.top || b.bottom < a.top) {
    return false;
  }
  return true;
}

Rect? _dominant(List<Rect> separators) {
  Rect? best;
  var bestScore = -1.0;
  for (final Rect separator in separators) {
    final double score = _score(separator);
    if (score > bestScore) {
      best = separator;
      bestScore = score;
    }
  }
  return best;
}

double _score(Rect rect) {
  final double area = rect.width * rect.height;
  if (area > 0) {
    return area;
  }
  return math.max(rect.width, rect.height) * 1e-6;
}

/// 竖直分界（更高而窄）沿水平轴切开，水平分界沿垂直轴切开。
Axis _axisFor(Rect separator) {
  if (separator.height > separator.width) {
    return Axis.horizontal;
  }
  return Axis.vertical;
}

class _Sides {
  const _Sides({
    required this.leading,
    required this.trailing,
    required this.top,
    required this.bottom,
  });

  final Rect leading;
  final Rect trailing;
  final Rect top;
  final Rect bottom;
}

_Sides _sides(Rect separator, Size size, TextDirection direction) {
  final double splitX = separator.left.clamp(0.0, size.width);
  final double resumeX = separator.right.clamp(0.0, size.width);
  final double splitY = separator.top.clamp(0.0, size.height);
  final double resumeY = separator.bottom.clamp(0.0, size.height);
  final Rect left = Rect.fromLTRB(0, 0, splitX, size.height);
  final Rect right = Rect.fromLTRB(resumeX, 0, size.width, size.height);
  final bool ltr = direction == TextDirection.ltr;
  return _Sides(
    leading: ltr ? left : right,
    trailing: ltr ? right : left,
    top: Rect.fromLTRB(0, 0, size.width, splitY),
    bottom: Rect.fromLTRB(0, resumeY, size.width, size.height),
  );
}

double _extent(Rect rect, Axis axis) {
  return axis == Axis.horizontal ? rect.width : rect.height;
}

bool _fits(
  Rect primary,
  Rect secondary,
  Axis axis,
  double minPrimary,
  double minSecondary,
) {
  final double primaryExtent = _extent(primary, axis);
  final double secondaryExtent = _extent(secondary, axis);
  return primaryExtent > 0 &&
      secondaryExtent > 0 &&
      primaryExtent >= minPrimary &&
      secondaryExtent >= minSecondary;
}

Rect _fallbackSide({
  required Rect first,
  required Rect second,
  required Axis axis,
  required bool preferSecondOnTie,
  required Size size,
}) {
  final double firstExtent = _extent(first, axis);
  final double secondExtent = _extent(second, axis);
  final Rect chosen;
  if (firstExtent > secondExtent) {
    chosen = first;
  } else if (secondExtent > firstExtent) {
    chosen = second;
  } else {
    chosen = preferSecondOnTie ? second : first;
  }
  if (chosen.width > 0 && chosen.height > 0) {
    return chosen;
  }
  final Rect other = identical(chosen, first) ? second : first;
  if (other.width > 0 && other.height > 0) {
    return other;
  }
  return Offset.zero & size;
}

ArrangementResolution _primaryOnly(Rect primary) {
  return ArrangementResolution(
    presentation: ArrangementPresentation.primaryOnly,
    axis: null,
    primary: primary,
    secondary: null,
    floatRegion: null,
  );
}

ArrangementResolution _splitByAspect(
  Size size,
  TextDirection direction,
  SplitArrangementStyle style,
) {
  final bool wider = size.width >= size.height;
  if (wider && style.axes.contains(Axis.horizontal)) {
    final ArrangementResolution? resolution = _ratioSplit(
      size: size,
      direction: direction,
      ratio: style.ratio ?? 0.5,
      axis: Axis.horizontal,
      minPrimary: style.minPrimaryExtent,
      minSecondary: style.minSecondaryExtent,
    );
    if (resolution != null) {
      return resolution;
    }
  } else if (!wider && style.axes.contains(Axis.vertical)) {
    final ArrangementResolution? resolution = _ratioSplit(
      size: size,
      direction: direction,
      ratio: style.ratio ?? 0.5,
      axis: Axis.vertical,
      minPrimary: style.minPrimaryExtent,
      minSecondary: style.minSecondaryExtent,
    );
    if (resolution != null) {
      return resolution;
    }
  }
  return _primaryOnly(Offset.zero & size);
}

ArrangementResolution? _ratioSplit({
  required Size size,
  required TextDirection direction,
  required double ratio,
  required Axis axis,
  required double minPrimary,
  required double minSecondary,
}) {
  if (axis == Axis.horizontal) {
    final double primaryExtent = size.width * ratio;
    final double secondaryExtent = size.width - primaryExtent;
    if (primaryExtent <= 0 ||
        secondaryExtent <= 0 ||
        primaryExtent < minPrimary ||
        secondaryExtent < minSecondary) {
      return null;
    }
    final Rect primary = direction == TextDirection.ltr
        ? Rect.fromLTWH(0, 0, primaryExtent, size.height)
        : Rect.fromLTWH(secondaryExtent, 0, primaryExtent, size.height);
    final Rect secondary = direction == TextDirection.ltr
        ? Rect.fromLTWH(primaryExtent, 0, secondaryExtent, size.height)
        : Rect.fromLTWH(0, 0, secondaryExtent, size.height);
    return ArrangementResolution(
      presentation: ArrangementPresentation.splitHorizontal,
      axis: Axis.horizontal,
      primary: primary,
      secondary: secondary,
      floatRegion: null,
    );
  }

  final double primaryExtent = size.height * ratio;
  final double secondaryExtent = size.height - primaryExtent;
  if (primaryExtent <= 0 ||
      secondaryExtent <= 0 ||
      primaryExtent < minPrimary ||
      secondaryExtent < minSecondary) {
    return null;
  }
  return ArrangementResolution(
    presentation: ArrangementPresentation.splitVertical,
    axis: Axis.vertical,
    primary: Rect.fromLTWH(0, 0, size.width, primaryExtent),
    secondary: Rect.fromLTWH(0, primaryExtent, size.width, secondaryExtent),
    floatRegion: null,
  );
}

ArrangementResolution _splitBySeparator(
  Size size,
  TextDirection direction,
  SplitArrangementStyle style,
  Rect separator,
) {
  final Axis axis = _axisFor(separator);
  final _Sides sides = _sides(separator, size, direction);
  final Rect primarySide = axis == Axis.horizontal ? sides.leading : sides.top;
  final Rect secondarySide = axis == Axis.horizontal
      ? sides.trailing
      : sides.bottom;
  if (style.axes.contains(axis) &&
      _fits(
        primarySide,
        secondarySide,
        axis,
        style.minPrimaryExtent,
        style.minSecondaryExtent,
      )) {
    return ArrangementResolution(
      presentation: axis == Axis.horizontal
          ? ArrangementPresentation.splitHorizontal
          : ArrangementPresentation.splitVertical,
      axis: axis,
      primary: primarySide,
      secondary: secondarySide,
      floatRegion: null,
    );
  }
  return _primaryOnly(
    _fallbackSide(
      first: primarySide,
      second: secondarySide,
      axis: axis,
      preferSecondOnTie: axis == Axis.horizontal,
      size: size,
    ),
  );
}

ArrangementResolution _overlayBySeparator(
  Size size,
  TextDirection direction,
  OverlayArrangementStyle style,
  Rect separator,
) {
  final Axis axis = _axisFor(separator);
  final _Sides sides = _sides(separator, size, direction);
  final ArrangementEdge edge = axis == Axis.horizontal
      ? style.horizontalEdge
      : style.verticalEdge;
  final Rect primarySide = _rectForEdge(edge, sides);
  final Rect secondarySide = _rectForEdge(_opposite(edge), sides);
  if (_extent(primarySide, axis) > 0 && _extent(secondarySide, axis) > 0) {
    return ArrangementResolution(
      presentation: ArrangementPresentation.overlaySeparated,
      axis: axis,
      primary: primarySide,
      secondary: secondarySide,
      floatRegion: null,
    );
  }
  return _layered(
    _fallbackSide(
      first: axis == Axis.horizontal ? sides.leading : sides.top,
      second: axis == Axis.horizontal ? sides.trailing : sides.bottom,
      axis: axis,
      preferSecondOnTie: axis == Axis.horizontal,
      size: size,
    ),
    direction,
    style,
  );
}

ArrangementEdge _opposite(ArrangementEdge edge) {
  return switch (edge) {
    ArrangementEdge.leading => ArrangementEdge.trailing,
    ArrangementEdge.trailing => ArrangementEdge.leading,
    ArrangementEdge.top => ArrangementEdge.bottom,
    ArrangementEdge.bottom => ArrangementEdge.top,
  };
}

Rect _rectForEdge(ArrangementEdge edge, _Sides sides) {
  return switch (edge) {
    ArrangementEdge.leading => sides.leading,
    ArrangementEdge.trailing => sides.trailing,
    ArrangementEdge.top => sides.top,
    ArrangementEdge.bottom => sides.bottom,
  };
}

ArrangementResolution _layered(
  Rect bounds,
  TextDirection direction,
  OverlayArrangementStyle style,
) {
  return ArrangementResolution(
    presentation: ArrangementPresentation.overlayLayered,
    axis: null,
    primary: null,
    secondary: bounds,
    floatRegion: _deflate(bounds, style.layeredPadding.resolve(direction)),
  );
}

Rect _deflate(Rect rect, EdgeInsets padding) {
  final double left = rect.left + padding.left;
  final double top = rect.top + padding.top;
  final double right = math.max(left, rect.right - padding.right);
  final double bottom = math.max(top, rect.bottom - padding.bottom);
  return Rect.fromLTRB(left, top, right, bottom);
}
