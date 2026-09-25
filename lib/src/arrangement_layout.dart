import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'arrangement_pane.dart';
import 'arrangement_scope.dart';
import 'arrangement_style.dart';
import 'render_arrangement_layout.dart';
import 'resolve_arrangement.dart';

/// 两块内容的布局容器，行为对齐 SwiftUI 的 `ArrangementView`。
///
/// 调用方声明 [primary]、[secondary] 和一种 [style]。容器根据自身尺寸、
/// 书写方向，以及和自己相交的折痕或铰链，决定每一块出不出现、出现在哪。
/// 铰链角度不参与布局。
///
/// 特征优先读 [ArrangementScope]；没有 scope 时退回 `MediaQuery` 里的
/// `displayFeatures`。Android 上摊平的 [DisplayFeatureType.hinge] 仍然切开
/// 布局，摊平的 [DisplayFeatureType.fold] 则按普通大窗口处理。
///
/// 需要有界的宽和高，不要放进滚动视图。导航放在它外面。
/// 子树用 [ArrangementPane.of] 读取已经解析好的呈现。
class ArrangementLayout extends StatefulWidget {
  /// 创建两块内容的布局容器。
  const ArrangementLayout({
    super.key,
    this.style = ArrangementStyle.automatic,
    required this.primary,
    required this.secondary,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOutCubic,
  });

  /// 两块内容的关系。默认是 split。
  final ArrangementStyle style;

  /// 空间不够时留下来的那一块。overlay 里它是前景。
  final Widget primary;

  /// 可以暂时离开屏幕的那一块。overlay 里它是铺满的背景。
  final Widget secondary;

  /// 呈现变化时 frame 和透明度的动画时长。只有呈现改变才动画，
  /// 单纯的尺寸变化会直接跳到新位置。
  final Duration duration;

  /// [duration] 使用的曲线。
  final Curve curve;

  @override
  State<ArrangementLayout> createState() => _ArrangementLayoutState();
}

class _ArrangementLayoutState extends State<ArrangementLayout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(ArrangementLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<DisplayFeature> features =
        ArrangementScope.maybeOf(context)?.displayFeatures ??
        MediaQuery.maybeOf(context)?.displayFeatures ??
        const <DisplayFeature>[];
    final TextDirection textDirection = Directionality.of(context);
    final ArrangementStyle style = widget.style;
    return _MetricsBuilder(
      builder: (BuildContext context, _ArrangementMetrics metrics) {
        final ArrangementResolution resolution = resolveArrangement(
          size: metrics.size,
          separators: separatingFeatures(
            features: features,
            container: metrics.origin & metrics.size,
          ),
          textDirection: textDirection,
          style: style,
        );
        final OverlayArrangementStyle? overlay =
            style is OverlayArrangementStyle ? style : null;
        return ArrangementLayoutBody(
          resolution: resolution,
          textDirection: textDirection,
          animation: _controller,
          duration: widget.duration,
          curve: widget.curve,
          layeredAlignment:
              overlay?.layeredAlignment ?? AlignmentDirectional.topStart,
          layeredConstraints:
              overlay?.layeredConstraints ??
              const BoxConstraints(maxWidth: 400),
          primary: _PaneHost(
            pane: _paneFor(ArrangementRole.primary, resolution),
            removal: _removalFor(
              role: ArrangementRole.primary,
              resolution: resolution,
              container: metrics.size,
            ),
            child: widget.primary,
          ),
          secondary: _PaneHost(
            pane: _paneFor(ArrangementRole.secondary, resolution),
            removal: _removalFor(
              role: ArrangementRole.secondary,
              resolution: resolution,
              container: metrics.size,
            ),
            child: widget.secondary,
          ),
        );
      },
    );
  }
}

ArrangementPane _paneFor(
  ArrangementRole role,
  ArrangementResolution resolution,
) {
  final bool isPrimary = role == ArrangementRole.primary;
  final bool visible = isPrimary
      ? resolution.primary != null || resolution.floatRegion != null
      : resolution.secondary != null;
  final double zIndex =
      isPrimary &&
          resolution.presentation == ArrangementPresentation.overlayLayered
      ? 1
      : 0;
  return ArrangementPane(
    role: role,
    presentation: resolution.presentation,
    axis: resolution.axis,
    zIndex: zIndex,
    isVisible: visible,
  );
}

_PaddingRemoval _removalFor({
  required ArrangementRole role,
  required ArrangementResolution resolution,
  required Size container,
}) {
  final bool floating =
      role == ArrangementRole.primary &&
      resolution.presentation == ArrangementPresentation.overlayLayered;
  if (floating) {
    return const _PaddingRemoval(
      left: true,
      right: true,
      top: true,
      bottom: true,
    );
  }
  final Rect? frame = role == ArrangementRole.primary
      ? resolution.primary
      : resolution.secondary;
  if (frame == null) {
    return const _PaddingRemoval();
  }
  const double epsilon = 0.5;
  return _PaddingRemoval(
    left: frame.left > epsilon,
    right: frame.right < container.width - epsilon,
    top: frame.top > epsilon,
    bottom: frame.bottom < container.height - epsilon,
  );
}

class _PaddingRemoval {
  const _PaddingRemoval({
    this.left = false,
    this.right = false,
    this.top = false,
    this.bottom = false,
  });

  final bool left;
  final bool right;
  final bool top;
  final bool bottom;
}

class _PaneHost extends StatelessWidget {
  const _PaneHost({
    required this.pane,
    required this.removal,
    required this.child,
  });

  final ArrangementPane pane;
  final _PaddingRemoval removal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget result = child;
    final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery != null) {
      result = MediaQuery(
        data: mediaQuery.removePadding(
          removeLeft: removal.left,
          removeRight: removal.right,
          removeTop: removal.top,
          removeBottom: removal.bottom,
        ),
        child: result,
      );
    }
    return ArrangementPaneScope(
      pane: pane,
      child: TickerMode(
        enabled: pane.isVisible,
        child: ExcludeFocus(
          excluding: !pane.isVisible,
          child: ExcludeSemantics(
            excluding: !pane.isVisible,
            child: IgnorePointer(ignoring: !pane.isVisible, child: result),
          ),
        ),
      ),
    );
  }
}

class _ArrangementMetrics {
  const _ArrangementMetrics({required this.size, required this.origin});

  final Size size;
  final Offset origin;

  @override
  bool operator ==(Object other) {
    return other is _ArrangementMetrics &&
        other.size == size &&
        other.origin == origin;
  }

  @override
  int get hashCode => Object.hash(size, origin);
}

class _MetricsBuilder extends AbstractLayoutBuilder<_ArrangementMetrics> {
  const _MetricsBuilder({required this.builder});

  @override
  final Widget Function(BuildContext context, _ArrangementMetrics layoutInfo)
  builder;

  @override
  bool updateShouldRebuild(_MetricsBuilder oldWidget) => true;

  @override
  RenderAbstractLayoutBuilderMixin<_ArrangementMetrics, RenderBox>
  createRenderObject(BuildContext context) {
    return _RenderMetricsBuilder();
  }
}

class _RenderMetricsBuilder extends RenderBox
    with
        RenderObjectWithChildMixin<RenderBox>,
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<_ArrangementMetrics, RenderBox> {
  bool _originCheckScheduled = false;
  Offset _layoutOrigin = Offset.zero;

  @override
  _ArrangementMetrics get layoutInfo {
    return _ArrangementMetrics(
      size: hasSize ? size : Size.zero,
      origin: _layoutOrigin,
    );
  }

  /// 路由转场进行到一半时，祖先还没有 size，[localToGlobal] 会失败。
  /// 失败时沿用上一帧的原点，等这一帧画完再复核。
  Offset _readOrigin() {
    if (!attached) {
      return _layoutOrigin;
    }
    try {
      return localToGlobal(Offset.zero);
    } catch (_) {
      return _layoutOrigin;
    }
  }

  @override
  void performLayout() {
    size = _boundedSize(constraints);
    _layoutOrigin = _readOrigin();
    final Offset used = _layoutOrigin;
    runLayoutCallback();
    child?.layout(BoxConstraints.tight(size));
    _scheduleOriginCheck(used);
  }

  Size _boundedSize(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      throw FlutterError(
        'ArrangementLayout 需要有界的宽和高。'
        '不要把它放进 ListView、Row 或 Column 的滚动方向上。',
      );
    }
    return constraints.biggest;
  }

  void _scheduleOriginCheck(Offset used) {
    if (_originCheckScheduled) {
      return;
    }
    _originCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _originCheckScheduled = false;
      if (!attached) {
        return;
      }
      final Offset now = _readOrigin();
      if ((now - used).distance > 0.5) {
        _layoutOrigin = now;
        markNeedsLayout();
      }
    });
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.hasBoundedWidth && constraints.hasBoundedHeight
        ? constraints.biggest
        : Size.zero;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return child?.hitTest(result, position: position) ?? false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }
}
