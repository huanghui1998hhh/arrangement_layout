import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'arrangement_pane.dart';
import 'resolve_arrangement.dart';

/// 按 [ArrangementResolution] 摆放 primary 和 secondary。
///
/// 两个槽位的 child 身份固定，切换呈现时不重新挂载。隐藏的一块仍按上次可见的
/// 尺寸布局，但不绘制、不参与命中测试，也不进入语义树。
class ArrangementLayoutBody
    extends SlottedMultiChildRenderObjectWidget<ArrangementRole, RenderBox> {
  /// 创建摆放两块内容的渲染 widget。
  const ArrangementLayoutBody({
    super.key,
    required this.resolution,
    required this.textDirection,
    required this.animation,
    required this.duration,
    required this.curve,
    required this.layeredAlignment,
    required this.layeredConstraints,
    required this.primary,
    required this.secondary,
  });

  /// 目标呈现和 frame。
  final ArrangementResolution resolution;

  /// 层叠浮层的对齐要用到书写方向。
  final TextDirection textDirection;

  /// 呈现变化时从 0 走到 1。尺寸变化不使用这段动画。
  final AnimationController animation;

  /// 呈现变化的动画时长。为零时直接跳到目标。
  final Duration duration;

  /// 动画曲线。
  final Curve curve;

  /// 层叠时浮层的对齐。
  final AlignmentDirectional layeredAlignment;

  /// 层叠时测量浮层的约束。
  final BoxConstraints layeredConstraints;

  /// primary 子树。
  final Widget primary;

  /// secondary 子树。
  final Widget secondary;

  @override
  Iterable<ArrangementRole> get slots => ArrangementRole.values;

  @override
  Widget? childForSlot(ArrangementRole slot) {
    return switch (slot) {
      ArrangementRole.primary => primary,
      ArrangementRole.secondary => secondary,
    };
  }

  @override
  SlottedContainerRenderObjectMixin<ArrangementRole, RenderBox>
  createRenderObject(BuildContext context) {
    return _RenderArrangementLayout(
      resolution: resolution,
      textDirection: textDirection,
      animation: animation,
      duration: duration,
      curve: curve,
      layeredAlignment: layeredAlignment,
      layeredConstraints: layeredConstraints,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    SlottedContainerRenderObjectMixin<ArrangementRole, RenderBox> renderObject,
  ) {
    final _RenderArrangementLayout box =
        renderObject as _RenderArrangementLayout;
    box
      ..textDirection = textDirection
      ..animation = animation
      ..duration = duration
      ..curve = curve
      ..layeredAlignment = layeredAlignment
      ..layeredConstraints = layeredConstraints
      ..resolution = resolution;
  }
}

class _PaneFrame {
  const _PaneFrame(this.rect, this.opacity);

  final Rect? rect;
  final double opacity;
}

class _RenderArrangementLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<ArrangementRole, RenderBox> {
  _RenderArrangementLayout({
    required ArrangementResolution resolution,
    required TextDirection textDirection,
    required AnimationController animation,
    required Duration duration,
    required Curve curve,
    required AlignmentDirectional layeredAlignment,
    required BoxConstraints layeredConstraints,
  }) : _resolution = resolution,
       _textDirection = textDirection,
       _animation = animation,
       _duration = duration,
       _curve = curve,
       _layeredAlignment = layeredAlignment,
       _layeredConstraints = layeredConstraints {
    _animation.addListener(_handleTick);
  }

  ArrangementResolution _resolution;
  TextDirection _textDirection;
  AnimationController _animation;
  Duration _duration;
  Curve _curve;
  AlignmentDirectional _layeredAlignment;
  BoxConstraints _layeredConstraints;

  Rect? _fromPrimary;
  Rect? _fromSecondary;
  double _fromPrimaryOpacity = 0;
  double _fromSecondaryOpacity = 0;
  bool _animating = false;

  Rect? _shownPrimary;
  Rect? _shownSecondary;
  double _primaryOpacity = 0;
  double _secondaryOpacity = 0;
  bool _primaryHittable = false;
  bool _secondaryHittable = false;
  bool _needsOpacityLayer = false;

  Size? _lastPrimarySize;
  Size? _lastSecondarySize;
  Offset _lastPrimaryOffset = Offset.zero;
  Offset _lastSecondaryOffset = Offset.zero;

  set resolution(ArrangementResolution value) {
    if (_resolution == value) {
      return;
    }
    final bool presentationChanged =
        _resolution.presentation != value.presentation;
    if (presentationChanged && _duration > Duration.zero) {
      _fromPrimary = _shownPrimary;
      _fromSecondary = _shownSecondary;
      _fromPrimaryOpacity = _primaryOpacity;
      _fromSecondaryOpacity = _secondaryOpacity;
      _animating = true;
      _animation.forward(from: 0);
    } else {
      _animating = false;
      if (_animation.isAnimating || _animation.value != 1) {
        _animation.value = 1;
      }
    }
    _resolution = value;
    markNeedsLayout();
  }

  set textDirection(TextDirection value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  set animation(AnimationController value) {
    if (identical(_animation, value)) {
      return;
    }
    _animation.removeListener(_handleTick);
    _animation = value;
    _animation.addListener(_handleTick);
    markNeedsLayout();
  }

  set duration(Duration value) {
    if (_duration == value) {
      return;
    }
    _duration = value;
  }

  set curve(Curve value) {
    if (_curve == value) {
      return;
    }
    _curve = value;
    if (_animating) {
      markNeedsLayout();
    }
  }

  set layeredAlignment(AlignmentDirectional value) {
    if (_layeredAlignment == value) {
      return;
    }
    _layeredAlignment = value;
    markNeedsLayout();
  }

  set layeredConstraints(BoxConstraints value) {
    if (_layeredConstraints == value) {
      return;
    }
    _layeredConstraints = value;
    markNeedsLayout();
  }

  void _handleTick() {
    if (attached) {
      markNeedsLayout();
    }
  }

  @override
  void dispose() {
    _animation.removeListener(_handleTick);
    super.dispose();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  bool get alwaysNeedsCompositing => _needsOpacityLayer;

  @override
  void performLayout() {
    size = constraints.biggest;
    final RenderBox? primary = childForSlot(ArrangementRole.primary);
    final RenderBox? secondary = childForSlot(ArrangementRole.secondary);
    final Rect? primaryTarget = _primaryTarget(primary);
    final Rect? secondaryTarget = _resolution.secondary;
    final double t = _animating
        ? _curve.transform(_animation.value.clamp(0.0, 1.0))
        : 1;
    final _PaneFrame primaryFrame = _frame(
      from: _fromPrimary,
      fromOpacity: _fromPrimaryOpacity,
      to: primaryTarget,
      t: t,
    );
    final _PaneFrame secondaryFrame = _frame(
      from: _fromSecondary,
      fromOpacity: _fromSecondaryOpacity,
      to: secondaryTarget,
      t: t,
    );
    _place(primary, primaryFrame, _lastPrimarySize, _lastPrimaryOffset);
    _place(secondary, secondaryFrame, _lastSecondarySize, _lastSecondaryOffset);
    if (primaryFrame.rect != null && primaryFrame.opacity > 0) {
      _lastPrimarySize = primaryFrame.rect!.size;
      _lastPrimaryOffset = primaryFrame.rect!.topLeft;
    }
    if (secondaryFrame.rect != null && secondaryFrame.opacity > 0) {
      _lastSecondarySize = secondaryFrame.rect!.size;
      _lastSecondaryOffset = secondaryFrame.rect!.topLeft;
    }
    _shownPrimary = primaryFrame.rect;
    _shownSecondary = secondaryFrame.rect;
    _primaryOpacity = primaryFrame.opacity;
    _secondaryOpacity = secondaryFrame.opacity;
    final bool primaryHittable =
        _resolution.primary != null || _resolution.floatRegion != null;
    final bool secondaryHittable = _resolution.secondary != null;
    if (primaryHittable != _primaryHittable ||
        secondaryHittable != _secondaryHittable) {
      _primaryHittable = primaryHittable;
      _secondaryHittable = secondaryHittable;
      markNeedsSemanticsUpdate();
    }
    final bool needsOpacity =
        (_primaryOpacity > 0 && _primaryOpacity < 1) ||
        (_secondaryOpacity > 0 && _secondaryOpacity < 1);
    if (needsOpacity != _needsOpacityLayer) {
      _needsOpacityLayer = needsOpacity;
      markNeedsCompositingBitsUpdate();
    }
  }

  Rect? _primaryTarget(RenderBox? child) {
    final Rect? region = _resolution.floatRegion;
    if (region == null) {
      return _resolution.primary;
    }
    if (child == null) {
      return region;
    }
    child.layout(_floatConstraints(region), parentUsesSize: true);
    return _layeredAlignment
        .resolve(_textDirection)
        .inscribe(child.size, region);
  }

  BoxConstraints _floatConstraints(Rect region) {
    final double maxWidth = math.min(
      _layeredConstraints.maxWidth,
      math.max(0, region.width),
    );
    final double maxHeight = math.min(
      _layeredConstraints.maxHeight,
      math.max(0, region.height),
    );
    return BoxConstraints(
      minWidth: math.min(_layeredConstraints.minWidth, maxWidth),
      maxWidth: maxWidth,
      minHeight: math.min(_layeredConstraints.minHeight, maxHeight),
      maxHeight: maxHeight,
    );
  }

  _PaneFrame _frame({
    required Rect? from,
    required double fromOpacity,
    required Rect? to,
    required double t,
  }) {
    if (!_animating) {
      return _PaneFrame(to, to == null ? 0 : 1);
    }
    final double toOpacity = to == null ? 0 : 1;
    if (from == null && to == null) {
      return const _PaneFrame(null, 0);
    }
    if (from == null) {
      return _PaneFrame(to, toOpacity * t);
    }
    if (to == null) {
      return _PaneFrame(from, fromOpacity * (1 - t));
    }
    return _PaneFrame(
      Rect.lerp(from, to, t),
      fromOpacity + (toOpacity - fromOpacity) * t,
    );
  }

  void _place(
    RenderBox? child,
    _PaneFrame frame,
    Size? lastSize,
    Offset lastOffset,
  ) {
    if (child == null) {
      return;
    }
    final Rect? rect = frame.rect;
    final BoxParentData parentData = child.parentData! as BoxParentData;
    if (rect == null || frame.opacity <= 0) {
      child.layout(BoxConstraints.tight(lastSize ?? Size.zero));
      parentData.offset = lastOffset;
      return;
    }
    child.layout(BoxConstraints.tight(rect.size));
    parentData.offset = rect.topLeft;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, (
      PaintingContext context,
      Offset offset,
    ) {
      _paintPane(context, offset, ArrangementRole.secondary, _secondaryOpacity);
      _paintPane(context, offset, ArrangementRole.primary, _primaryOpacity);
    });
  }

  void _paintPane(
    PaintingContext context,
    Offset offset,
    ArrangementRole role,
    double opacity,
  ) {
    final RenderBox? child = childForSlot(role);
    if (child == null || opacity <= 0) {
      return;
    }
    final BoxParentData parentData = child.parentData! as BoxParentData;
    if (opacity >= 1) {
      context.paintChild(child, offset + parentData.offset);
      return;
    }
    context.pushOpacity(
      offset + parentData.offset,
      (opacity * 255).round().clamp(0, 255),
      (PaintingContext context, Offset offset) {
        context.paintChild(child, offset);
      },
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_hitTestPane(
      result,
      position,
      ArrangementRole.primary,
      _primaryHittable,
    )) {
      return true;
    }
    if (_hitTestPane(
      result,
      position,
      ArrangementRole.secondary,
      _secondaryHittable,
    )) {
      return true;
    }
    return false;
  }

  bool _hitTestPane(
    BoxHitTestResult result,
    Offset position,
    ArrangementRole role,
    bool hittable,
  ) {
    if (!hittable) {
      return false;
    }
    final RenderBox? child = childForSlot(role);
    if (child == null) {
      return false;
    }
    final BoxParentData parentData = child.parentData! as BoxParentData;
    return result.addWithPaintOffset(
      offset: parentData.offset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        return child.hitTest(result, position: transformed);
      },
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final RenderBox? primary = childForSlot(ArrangementRole.primary);
    final RenderBox? secondary = childForSlot(ArrangementRole.secondary);
    if (primary != null && _primaryHittable) {
      visitor(primary);
    }
    if (secondary != null && _secondaryHittable) {
      visitor(secondary);
    }
  }
}
