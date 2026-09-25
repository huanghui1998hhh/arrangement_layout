import 'package:flutter/widgets.dart';

import 'arrangement_controller.dart';
import 'arrangement_state.dart';

/// 把 [ArrangementController] 放进 widget 树，并默认把生效中的特征写进 [MediaQuery]。
///
/// 要让对话框、底部弹层和菜单读到注入后的折痕，把它放在 `MaterialApp.builder`
/// （或 `CupertinoApp.builder`）里，也就是 Navigator 之上：
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) {
///     return ArrangementScope(child: child ?? const SizedBox.shrink());
///   },
/// )
/// ```
///
/// 省略 [controller] 时，本组件会自己创建一个，并在销毁时释放。
/// [injectDisplayFeatures] 默认为 true。设为 false 时只提供 [ArrangementScope.of]，
/// 不改写 `MediaQuery`。
class ArrangementScope extends StatefulWidget {
  /// 创建折叠屏作用域。
  const ArrangementScope({
    super.key,
    this.controller,
    this.injectDisplayFeatures = true,
    required this.child,
  });

  /// 外部持有的控制器。为 null 时由本组件创建。
  final ArrangementController? controller;

  /// 是否用 [ArrangementState.displayFeatures] 替换当前 [MediaQuery] 的特征。
  final bool injectDisplayFeatures;

  /// 作用域下的子树。
  final Widget child;

  /// 读取最近的状态。找不到时抛出 [FlutterError]。
  static ArrangementState of(BuildContext context) {
    final state = maybeOf(context);
    if (state == null) {
      throw FlutterError(
        'ArrangementScope.of() 找不到 ArrangementScope。'
        '请把它放在 MaterialApp.builder 里，并且位于使用它的组件之上。',
      );
    }
    return state;
  }

  /// 读取最近的状态。没有 [ArrangementScope] 时返回 null。
  static ArrangementState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ArrangementData>()
        ?.state;
  }

  @override
  State<ArrangementScope> createState() => _ArrangementScopeState();
}

class _ArrangementScopeState extends State<ArrangementScope> {
  late ArrangementController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _adopt(widget.controller);
  }

  @override
  void didUpdateWidget(ArrangementScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (_ownsController) {
        _controller.dispose();
      }
      _adopt(widget.controller);
    }
  }

  void _adopt(ArrangementController? controller) {
    _ownsController = controller == null;
    _controller = controller ?? ArrangementController();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final state = _controller.value;
        var result = child!;
        if (widget.injectDisplayFeatures) {
          result = MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(displayFeatures: state.displayFeatures),
            child: result,
          );
        }
        return _ArrangementData(state: state, child: result);
      },
      child: widget.child,
    );
  }
}

class _ArrangementData extends InheritedWidget {
  const _ArrangementData({required this.state, required super.child});

  final ArrangementState state;

  @override
  bool updateShouldNotify(_ArrangementData oldWidget) =>
      state != oldWidget.state;
}
