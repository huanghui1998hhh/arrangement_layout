# arrangement_layout

把 Flutter 引擎已经提供的 `DisplayFeature` 和 iPhone Duo 的铰链读数放在一起。

Android 上的折痕、铰链和挖孔直接来自 `FlutterView.displayFeatures`，不经过 `BuildContext`，也不再读一遍 WindowManager。iOS 上引擎这份列表是空的，插件把 iPhone Duo 的折痕和内屏摄像头按同一套 `DisplayFeature` 规则补进去，并额外提供铰链角度和姿态。

## 要求

- 编译 iOS 插件需要 Xcode 27.1。折痕相关 API 在运行时要求 iOS 27.1；更早的系统上铰链为 null、区域为空。
- 插件的最低部署版本是 iOS 13。example 在接入 Swift Package Manager 时会被 Flutter 提到 iOS 15。
- 读取状态不需要 `BuildContext`。只有要把特征交给对话框时，才用下面的 widget。

## 用法

`ArrangementScope` 要放在 `MaterialApp.builder` 里，也就是 Navigator 之上。默认会把当前生效的特征写进 `MediaQuery.displayFeatures`，这样对话框、底部弹层和菜单会避开半开的折痕。

```dart
MaterialApp(
  builder: (context, child) {
    return ArrangementScope(child: child ?? const SizedBox.shrink());
  },
  home: Builder(
    builder: (context) {
      final state = ArrangementScope.of(context);
      return Text('${state.hinge?.posture} ${state.hinge?.angle}');
    },
  ),
)
```

不需要 widget 树时，自己持有控制器：

```dart
final controller = ArrangementController();
controller.addListener(() {
  final state = controller.value;
});
```

多窗口时把对应的 `FlutterView` 传给 `ArrangementController(view: ...)`。

## 状态

- `displayFeatures`：当前会影响布局的特征，也是写进 `MediaQuery` 的那一份。半开且生效的 iPhone Duo 折痕是 `fold` + `postureHalfOpened`。
- `inactiveDisplayFeatures`：设备上存在、但当前不该切开屏幕的特征，例如摊平后仍有宽度的折痕。不要写回 `MediaQuery`，否则对话框会被切到半屏。
- `hinge`：姿态（`closed`、`partiallyOpen`、`fullyOpen`）和角度（弧度）。Android 第一版没有连续角度，`angle` 为 null。

引擎自己已经上报了 `fold` 或 `hinge` 时（Android，以及将来官方 iOS 支持合入之后），几何以引擎为准，插件只补充铰链读数。
