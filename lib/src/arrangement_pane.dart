import 'package:flutter/widgets.dart';

/// 一块内容在 [ArrangementLayout] 里的角色。
enum ArrangementRole {
  /// 空间不够时留下来的那一块；层叠时是前景。
  primary,

  /// 可以暂时离开屏幕的那一块；层叠时是铺满的背景。
  secondary,
}

/// 容器已经解析好的呈现，子视图不用再从环境和样式推一遍。
enum ArrangementPresentation {
  /// 左右并排，互不遮挡。
  splitHorizontal,

  /// 上下并排，primary 在上。
  splitVertical,

  /// primary 浮在铺满的 secondary 上。
  overlayLayered,

  /// 由 overlay 关系产生的并排，两块都不重叠。
  overlaySeparated,

  /// 只摆了 primary。secondary 仍保留 State。
  primaryOnly,
}

/// 子树读到的呈现结果。
///
/// 用 [ArrangementPane.of] 读取。浮层是否还浮着只看 [isFloating]；
/// 紧凑或展开用 [presentation] 区分。
class ArrangementPane {
  /// 创建一份呈现结果。
  const ArrangementPane({
    required this.role,
    required this.presentation,
    required this.axis,
    required this.zIndex,
    required this.isVisible,
  });

  /// 这块内容的角色。
  final ArrangementRole role;

  /// 当前呈现。
  final ArrangementPresentation presentation;

  /// 并排时的分栏轴。层叠和只显示 primary 时为 null。
  final Axis? axis;

  /// 只有层叠时的 primary 大于 0，其余为 0。
  ///
  /// 内容根上读到的就是这个值，不像 SwiftUI 那样根视图始终读到 0。
  final double zIndex;

  /// 这块内容当前是否参与绘制、命中测试和语义。
  final bool isVisible;

  /// 是否还浮在背景之上。
  bool get isFloating => zIndex > 0;

  /// 读取最近的呈现。找不到时抛出 [FlutterError]。
  static ArrangementPane of(BuildContext context) {
    final ArrangementPane? pane = maybeOf(context);
    if (pane == null) {
      throw FlutterError(
        'ArrangementPane.of() 找不到 ArrangementLayout。'
        '只能在它的 primary 或 secondary 子树里读取。',
      );
    }
    return pane;
  }

  /// 读取最近的呈现。不在 arrangement 子树里时返回 null。
  static ArrangementPane? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ArrangementPaneScope>()
        ?.pane;
  }

  @override
  bool operator ==(Object other) {
    return other is ArrangementPane &&
        other.role == role &&
        other.presentation == presentation &&
        other.axis == axis &&
        other.zIndex == zIndex &&
        other.isVisible == isVisible;
  }

  @override
  int get hashCode => Object.hash(role, presentation, axis, zIndex, isVisible);

  @override
  String toString() {
    return 'ArrangementPane(role: $role, presentation: $presentation, '
        'axis: $axis, zIndex: $zIndex, isVisible: $isVisible)';
  }
}

/// 把 [ArrangementPane] 提供给子树。
///
/// [ArrangementLayout] 会为每一块内容插入一份。测试里也可以直接包一层，
/// 让子树读到伪造的呈现。
class ArrangementPaneScope extends InheritedWidget {
  /// 创建呈现作用域。
  const ArrangementPaneScope({super.key, required this.pane, required super.child});

  /// 子树读到的呈现。
  final ArrangementPane pane;

  @override
  bool updateShouldNotify(ArrangementPaneScope oldWidget) =>
      pane != oldWidget.pane;
}
