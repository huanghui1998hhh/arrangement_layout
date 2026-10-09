import 'dart:ui';

import 'package:flutter/painting.dart';

import 'hinge_state.dart';

/// iOS reserved region 的种类。
enum IosRegionKind {
  /// 折痕。对应 `UIView.ReservedRegion.Kind.division`。
  division,

  /// 遮挡，例如内屏摄像头。对应 `occlusion`。
  occlusion,
}

/// 一块 iOS reserved region，坐标是 Flutter 视图的逻辑像素。
class IosReservedRegion {
  /// 创建一块区域。
  const IosReservedRegion({
    required this.kind,
    required this.bounds,
    required this.isActive,
  });

  /// 区域种类。
  final IosRegionKind kind;

  /// 区域矩形，使用 `ReservedRegion.frame`，已包含可交互内容的边距。
  final Rect bounds;

  /// 区域当前是否生效。摊平的折痕和未开启的摄像头为 false。
  final bool isActive;

  /// 解析插件事件里的一条区域。种类无法识别时返回 null。
  static IosReservedRegion? tryParse(Map<Object?, Object?> map) {
    final kind = switch (map['kind']) {
      'division' => IosRegionKind.division,
      'occlusion' => IosRegionKind.occlusion,
      _ => null,
    };
    if (kind == null) {
      return null;
    }
    final left = _asDouble(map['l']);
    final top = _asDouble(map['t']);
    final right = _asDouble(map['r']);
    final bottom = _asDouble(map['b']);
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    return IosReservedRegion(
      kind: kind,
      bounds: Rect.fromLTRB(left, top, right, bottom),
      isActive: map['active'] == true,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IosReservedRegion &&
        other.kind == kind &&
        other.bounds == bounds &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(kind, bounds, isActive);
}

/// 系统竖排栏贴着哪条物理边。
///
/// 插件把 `UITraitCollection.verticalBarEdge` 的 leading / trailing 按当前布局方向
/// 换成左右。`none` 表示这个方向没有竖排栏。
enum IosVerticalBarEdge {
  /// 没有竖排栏。
  none,

  /// 贴物理左缘。
  left,

  /// 贴物理右缘。
  right,
}

/// iOS 插件一次上报的铰链、区域和侧栏安全区。
///
/// 铰链、区域、安全区和状态栏放在同一次事件里，避免灵动岛变高时按钮和状态信息各走各的。
class IosFoldReading {
  /// 创建一份读数。[hinge] 为 null 表示交互离开了能提供铰链的视图层级。
  const IosFoldReading({
    required this.hinge,
    required this.regions,
    this.safeAreaInsets = EdgeInsets.zero,
    this.verticalBarEdge = IosVerticalBarEdge.none,
    this.statusBarBounds,
  });

  /// 当前铰链。设备没有铰链，或交互尚未挂上时为 null。
  final HingeState? hinge;

  /// 本次读到的区域，包含未生效的折痕和摄像头。
  final List<IosReservedRegion> regions;

  /// 宿主视图的 `safeAreaInsets`。Duo 上侧向 inset 就是竖排栏占住的安全区。
  final EdgeInsets safeAreaInsets;

  /// 系统放置竖排栏的物理边。
  final IosVerticalBarEdge verticalBarEdge;

  /// 状态栏矩形，坐标是 Flutter 视图的逻辑像素。隐藏时为 null。
  final Rect? statusBarBounds;

  /// 解析插件事件。
  factory IosFoldReading.fromMap(Map<Object?, Object?> map) {
    final hingeValue = map['hinge'];
    final regions = <IosReservedRegion>[];
    final rawRegions = map['regions'];
    if (rawRegions is List) {
      for (final item in rawRegions) {
        if (item is Map) {
          final region = IosReservedRegion.tryParse(
            Map<Object?, Object?>.from(item),
          );
          if (region != null) {
            regions.add(region);
          }
        }
      }
    }
    return IosFoldReading(
      hinge: hingeValue is Map
          ? _hingeFromMap(Map<Object?, Object?>.from(hingeValue))
          : null,
      regions: List.unmodifiable(regions),
      safeAreaInsets: _edgeInsets(map['safeArea']),
      verticalBarEdge: _verticalBarEdge(map['verticalBarEdge']),
      statusBarBounds: _rect(map['statusBar']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! IosFoldReading ||
        other.hinge != hinge ||
        other.safeAreaInsets != safeAreaInsets ||
        other.verticalBarEdge != verticalBarEdge ||
        other.statusBarBounds != statusBarBounds ||
        other.regions.length != regions.length) {
      return false;
    }
    for (var i = 0; i < regions.length; i++) {
      if (regions[i] != other.regions[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    hinge,
    safeAreaInsets,
    verticalBarEdge,
    statusBarBounds,
    Object.hashAll(regions),
  );
}

HingeState _hingeFromMap(Map<Object?, Object?> map) {
  final posture = switch (map['status']) {
    'closed' => HingePosture.closed,
    'partiallyOpen' => HingePosture.partiallyOpen,
    'fullyOpen' => HingePosture.fullyOpen,
    _ => HingePosture.unknown,
  };
  return HingeState(posture: posture, angle: _asDouble(map['angle']));
}

double? _asDouble(Object? value) {
  return switch (value) {
    final double number => number,
    final int number => number.toDouble(),
    _ => null,
  };
}

EdgeInsets _edgeInsets(Object? value) {
  if (value is! Map) {
    return EdgeInsets.zero;
  }
  final map = Map<Object?, Object?>.from(value);
  return EdgeInsets.fromLTRB(
    _asDouble(map['l']) ?? 0,
    _asDouble(map['t']) ?? 0,
    _asDouble(map['r']) ?? 0,
    _asDouble(map['b']) ?? 0,
  );
}

IosVerticalBarEdge _verticalBarEdge(Object? value) {
  return switch (value) {
    'left' => IosVerticalBarEdge.left,
    'right' => IosVerticalBarEdge.right,
    _ => IosVerticalBarEdge.none,
  };
}

/// 状态栏缺失、为空，或坐标读不全时返回 null。
Rect? _rect(Object? value) {
  if (value is! Map) {
    return null;
  }
  final map = Map<Object?, Object?>.from(value);
  final left = _asDouble(map['l']);
  final top = _asDouble(map['t']);
  final right = _asDouble(map['r']);
  final bottom = _asDouble(map['b']);
  if (left == null || top == null || right == null || bottom == null) {
    return null;
  }
  final rect = Rect.fromLTRB(left, top, right, bottom);
  if (rect.isEmpty) {
    return null;
  }
  return rect;
}
