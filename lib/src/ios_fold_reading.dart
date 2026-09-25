import 'dart:ui';

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

/// iOS 插件一次上报的铰链和区域。
///
/// 铰链与区域放在同一次事件里，避免姿态和矩形各走各的、中间帧对不上。
class IosFoldReading {
  /// 创建一份读数。[hinge] 为 null 表示交互离开了能提供铰链的视图层级。
  const IosFoldReading({required this.hinge, required this.regions});

  /// 当前铰链。设备没有铰链，或交互尚未挂上时为 null。
  final HingeState? hinge;

  /// 本次读到的区域，包含未生效的折痕和摄像头。
  final List<IosReservedRegion> regions;

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
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! IosFoldReading ||
        other.hinge != hinge ||
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
  int get hashCode => Object.hash(hinge, Object.hashAll(regions));
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
