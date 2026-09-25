import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'arrangement_state.dart';
import 'ios_fold_reading.dart';
import 'merge_arrangement.dart';

const _foldChannelName = 'arrangement_layout/fold';

/// 不依赖 [BuildContext] 的折叠屏状态。
///
/// 几何来自 [FlutterView.displayFeatures]，也就是 `MediaQuery` 的数据来源，
/// 但读取本身不经过 widget 树。变更通过 [WidgetsBindingObserver.didChangeMetrics]
/// 接收，不会改写 `PlatformDispatcher.onMetricsChanged`（那个回调位已被渲染层占用）。
///
/// 在 iOS 上还会订阅插件事件，把 iPhone Duo 的折痕、摄像头和铰链并进来。
/// 构造前需要已经调用 `WidgetsFlutterBinding.ensureInitialized`。
///
/// [foldEvents] 用于测试或自定义数据源。传入之后不再订阅平台通道。
class ArrangementController extends ValueNotifier<ArrangementState>
    with WidgetsBindingObserver {
  /// 监听 [view] 的显示特征。省略时使用 `implicitView`。
  ArrangementController({FlutterView? view, Stream<IosFoldReading>? foldEvents})
    : _view = view ?? _implicitView(),
      super(ArrangementState.empty) {
    WidgetsBinding.instance.addObserver(this);
    final events = foldEvents ?? _platformEventsIfNeeded();
    if (events != null) {
      _listen(events);
    }
    _recompute();
  }

  final FlutterView _view;
  StreamSubscription<IosFoldReading>? _subscription;
  IosFoldReading? _iosReading;

  @override
  void didChangeMetrics() {
    _recompute();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _listen(Stream<IosFoldReading> events) {
    try {
      _subscription = events.listen(
        (reading) {
          _iosReading = reading;
          _recompute();
        },
        onError: (Object error, StackTrace stack) {
          if (error is MissingPluginException) {
            return;
          }
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'arrangement_layout',
              context: ErrorDescription('while listening for fold events'),
            ),
          );
        },
      );
    } on MissingPluginException {
      // 桌面测试或尚未注册插件时，保持引擎给出的特征。
    }
  }

  void _recompute() {
    final next = mergeArrangement(
      engineFeatures: _view.displayFeatures,
      iosReading: _iosReading,
    );
    if (next == value) {
      return;
    }
    value = next;
  }

  static Stream<IosFoldReading>? _platformEventsIfNeeded() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    return const EventChannel(_foldChannelName).receiveBroadcastStream().map((
      event,
    ) {
      return IosFoldReading.fromMap(Map<Object?, Object?>.from(event as Map));
    });
  }

  static FlutterView _implicitView() {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) {
      throw StateError(
        'ArrangementController 需要一个 FlutterView。'
        '多窗口场景请传入 view，单窗口应用请在 runApp 之后创建。',
      );
    }
    return view;
  }
}
