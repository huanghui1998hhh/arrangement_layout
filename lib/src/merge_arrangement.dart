import 'dart:ui';

import 'arrangement_state.dart';
import 'hinge_state.dart';
import 'ios_fold_reading.dart';

/// 把引擎的 [DisplayFeature] 和 iOS 插件读数合成一份 [ArrangementState]。
///
/// 引擎列表里已经有 [DisplayFeatureType.fold] 或 [DisplayFeatureType.hinge] 时
/// （Android 始终如此，将来官方 iOS 引擎填上之后也是如此），几何完全以引擎为准，
/// 插件只提供 [ArrangementState.hinge]。这样官方实现合入后，应用行为不变。
///
/// iOS 折痕只在铰链处于 [HingePosture.partiallyOpen]、区域正在生效、并且宽高都大于 0
/// 时进入 [ArrangementState.displayFeatures]。摊平后仍有宽度的折痕留在
/// [ArrangementState.inactiveDisplayFeatures]：它的 `shortestSide` 大于 0，
/// 写进 `MediaQuery` 会让对话框被切到半屏。合上时视图在外屏，不报折痕。
ArrangementState mergeArrangement({
  required List<DisplayFeature> engineFeatures,
  IosFoldReading? iosReading,
}) {
  final engineOwnsGeometry = engineFeatures.any(
    (feature) =>
        feature.type == DisplayFeatureType.fold ||
        feature.type == DisplayFeatureType.hinge,
  );
  final hinge = iosReading != null
      ? iosReading.hinge
      : _hingeFromEngine(engineFeatures);
  if (engineOwnsGeometry || iosReading == null) {
    return ArrangementState(
      displayFeatures: List.unmodifiable(engineFeatures),
      inactiveDisplayFeatures: const <DisplayFeature>[],
      hinge: hinge,
    );
  }

  final active = <DisplayFeature>[...engineFeatures];
  final inactive = <DisplayFeature>[];
  final posture = iosReading.hinge?.posture;
  for (final region in iosReading.regions) {
    switch (region.kind) {
      case IosRegionKind.division:
        if (posture == null || posture == HingePosture.closed) {
          break;
        }
        final separates =
            posture == HingePosture.partiallyOpen &&
            region.isActive &&
            region.bounds.width > 0 &&
            region.bounds.height > 0;
        final feature = DisplayFeature(
          bounds: region.bounds,
          type: DisplayFeatureType.fold,
          state: separates
              ? DisplayFeatureState.postureHalfOpened
              : DisplayFeatureState.postureFlat,
        );
        if (separates) {
          active.add(feature);
        } else {
          inactive.add(feature);
        }
      case IosRegionKind.occlusion:
        final feature = DisplayFeature(
          bounds: region.bounds,
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        );
        if (region.isActive) {
          active.add(feature);
        } else {
          inactive.add(feature);
        }
    }
  }
  return ArrangementState(
    displayFeatures: List.unmodifiable(active),
    inactiveDisplayFeatures: List.unmodifiable(inactive),
    hinge: hinge,
  );
}

/// 从 Android 已映射好的折叠特征推出姿态。没有折叠特征时返回 null。
HingeState? _hingeFromEngine(List<DisplayFeature> features) {
  final folds = features.where(
    (feature) =>
        feature.type == DisplayFeatureType.fold ||
        feature.type == DisplayFeatureType.hinge,
  );
  if (folds.isEmpty) {
    return null;
  }
  if (folds.any(
    (feature) => feature.state == DisplayFeatureState.postureHalfOpened,
  )) {
    return const HingeState(posture: HingePosture.partiallyOpen);
  }
  if (folds.any(
    (feature) => feature.state == DisplayFeatureState.postureFlat,
  )) {
    return const HingeState(posture: HingePosture.fullyOpen);
  }
  return const HingeState(posture: HingePosture.unknown);
}
