import 'dart:ui';

import 'package:arrangement_layout/arrangement_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hinge = DisplayFeature(
    bounds: Rect.fromLTWH(10, 0, 20, 100),
    type: DisplayFeatureType.hinge,
    state: DisplayFeatureState.postureFlat,
  );
  const halfOpenedFold = DisplayFeature(
    bounds: Rect.fromLTWH(0, 400, 800, 12),
    type: DisplayFeatureType.fold,
    state: DisplayFeatureState.postureHalfOpened,
  );
  const cutout = DisplayFeature(
    bounds: Rect.fromLTWH(300, 0, 80, 32),
    type: DisplayFeatureType.cutout,
    state: DisplayFeatureState.unknown,
  );
  const duoCrease = Rect.fromLTWH(380, 0, 40, 800);
  const camera = Rect.fromLTWH(360, 0, 80, 24);

  test(
    'Android hinge flat becomes fully open and keeps the engine feature',
    () {
      final state = mergeArrangement(
        engineFeatures: const [hinge],
        iosReading: null,
      );

      expect(state.displayFeatures, const [hinge]);
      expect(state.inactiveDisplayFeatures, isEmpty);
      expect(state.hinge, const HingeState(posture: HingePosture.fullyOpen));
    },
  );

  test('Android half-opened fold wins over a flat hinge', () {
    final state = mergeArrangement(
      engineFeatures: const [hinge, halfOpenedFold],
      iosReading: null,
    );

    expect(state.hinge, const HingeState(posture: HingePosture.partiallyOpen));
    expect(state.displayFeatures, const [hinge, halfOpenedFold]);
  });

  test('a cutout alone is not a hinge', () {
    final state = mergeArrangement(
      engineFeatures: const [cutout],
      iosReading: null,
    );

    expect(state.hinge, isNull);
    expect(state.displayFeatures, const [cutout]);
  });

  test('an unknown folding state stays unknown', () {
    const feature = DisplayFeature(
      bounds: Rect.fromLTWH(0, 0, 8, 100),
      type: DisplayFeatureType.hinge,
      state: DisplayFeatureState.unknown,
    );

    final state = mergeArrangement(
      engineFeatures: const [feature],
      iosReading: null,
    );

    expect(state.hinge, const HingeState(posture: HingePosture.unknown));
  });

  test('Duo half-open active crease is a separating fold', () {
    final state = mergeArrangement(
      engineFeatures: const [],
      iosReading: const IosFoldReading(
        hinge: HingeState(posture: HingePosture.partiallyOpen, angle: 1.2),
        regions: [
          IosReservedRegion(
            kind: IosRegionKind.division,
            bounds: duoCrease,
            isActive: true,
          ),
        ],
      ),
    );

    expect(
      state.hinge,
      const HingeState(posture: HingePosture.partiallyOpen, angle: 1.2),
    );
    expect(state.displayFeatures, [
      const DisplayFeature(
        bounds: duoCrease,
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    ]);
    expect(state.inactiveDisplayFeatures, isEmpty);
  });

  test(
    'Duo flat crease stays inactive even if the region still says active',
    () {
      final state = mergeArrangement(
        engineFeatures: const [],
        iosReading: const IosFoldReading(
          hinge: HingeState(posture: HingePosture.fullyOpen, angle: 3.1416),
          regions: [
            IosReservedRegion(
              kind: IosRegionKind.division,
              bounds: duoCrease,
              isActive: true,
            ),
          ],
        ),
      );

      expect(state.displayFeatures, isEmpty);
      expect(state.inactiveDisplayFeatures, [
        const DisplayFeature(
          bounds: duoCrease,
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureFlat,
        ),
      ]);
    },
  );

  test(
    'a half-open crease that is not active does not separate the screen',
    () {
      final state = mergeArrangement(
        engineFeatures: const [],
        iosReading: const IosFoldReading(
          hinge: HingeState(posture: HingePosture.partiallyOpen, angle: 1),
          regions: [
            IosReservedRegion(
              kind: IosRegionKind.division,
              bounds: duoCrease,
              isActive: false,
            ),
          ],
        ),
      );

      expect(state.displayFeatures, isEmpty);
      expect(
        state.inactiveDisplayFeatures.single.state,
        DisplayFeatureState.postureFlat,
      );
    },
  );

  test('a zero-size crease is not published while half open', () {
    const zeroWidth = Rect.fromLTRB(400, 0, 400, 800);
    final state = mergeArrangement(
      engineFeatures: const [],
      iosReading: const IosFoldReading(
        hinge: HingeState(posture: HingePosture.partiallyOpen, angle: 1),
        regions: [
          IosReservedRegion(
            kind: IosRegionKind.division,
            bounds: zeroWidth,
            isActive: true,
          ),
        ],
      ),
    );

    expect(state.displayFeatures, isEmpty);
    expect(state.inactiveDisplayFeatures.single.bounds, zeroWidth);
  });

  test('closed posture drops the crease and keeps an active camera', () {
    final state = mergeArrangement(
      engineFeatures: const [],
      iosReading: const IosFoldReading(
        hinge: HingeState(posture: HingePosture.closed, angle: 0),
        regions: [
          IosReservedRegion(
            kind: IosRegionKind.division,
            bounds: duoCrease,
            isActive: true,
          ),
          IosReservedRegion(
            kind: IosRegionKind.occlusion,
            bounds: camera,
            isActive: true,
          ),
        ],
      ),
    );

    expect(state.hinge?.posture, HingePosture.closed);
    expect(state.displayFeatures, [
      const DisplayFeature(
        bounds: camera,
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      ),
    ]);
    expect(state.inactiveDisplayFeatures, isEmpty);
  });

  test('an inactive camera stays out of MediaQuery features', () {
    final state = mergeArrangement(
      engineFeatures: const [],
      iosReading: const IosFoldReading(
        hinge: HingeState(posture: HingePosture.partiallyOpen, angle: 1),
        regions: [
          IosReservedRegion(
            kind: IosRegionKind.occlusion,
            bounds: camera,
            isActive: false,
          ),
        ],
      ),
    );

    expect(state.displayFeatures, isEmpty);
    expect(
      state.inactiveDisplayFeatures.single.type,
      DisplayFeatureType.cutout,
    );
    expect(
      state.inactiveDisplayFeatures.single.state,
      DisplayFeatureState.unknown,
    );
  });

  test(
    'engine fold or hinge wins and the plugin only contributes the hinge',
    () {
      final state = mergeArrangement(
        engineFeatures: const [hinge],
        iosReading: const IosFoldReading(
          hinge: HingeState(posture: HingePosture.partiallyOpen, angle: 1.2),
          regions: [
            IosReservedRegion(
              kind: IosRegionKind.division,
              bounds: duoCrease,
              isActive: true,
            ),
            IosReservedRegion(
              kind: IosRegionKind.occlusion,
              bounds: camera,
              isActive: true,
            ),
          ],
        ),
      );

      expect(state.displayFeatures, const [hinge]);
      expect(state.inactiveDisplayFeatures, isEmpty);
      expect(
        state.hinge,
        const HingeState(posture: HingePosture.partiallyOpen, angle: 1.2),
      );
    },
  );

  test(
    'an iOS reading with a null hinge does not fall back to engine posture',
    () {
      final state = mergeArrangement(
        engineFeatures: const [cutout],
        iosReading: const IosFoldReading(hinge: null, regions: []),
      );

      expect(state.displayFeatures, const [cutout]);
      expect(state.hinge, isNull);
    },
  );

  test('engine cutouts are kept when iOS adds a separating fold', () {
    final state = mergeArrangement(
      engineFeatures: const [cutout],
      iosReading: const IosFoldReading(
        hinge: HingeState(posture: HingePosture.partiallyOpen, angle: 1),
        regions: [
          IosReservedRegion(
            kind: IosRegionKind.division,
            bounds: duoCrease,
            isActive: true,
          ),
        ],
      ),
    );

    expect(state.displayFeatures, [
      cutout,
      const DisplayFeature(
        bounds: duoCrease,
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    ]);
  });

  test('plugin event maps hinge status and skips unknown regions', () {
    final reading = IosFoldReading.fromMap({
      'hinge': {'status': 'fullyOpen', 'angle': 3},
      'regions': [
        {'kind': 'division', 'l': 1, 't': 2, 'r': 3, 'b': 4, 'active': false},
        {'kind': 'future', 'l': 0, 't': 0, 'r': 1, 'b': 1, 'active': true},
      ],
    });

    expect(
      reading.hinge,
      const HingeState(posture: HingePosture.fullyOpen, angle: 3),
    );
    expect(reading.regions, const [
      IosReservedRegion(
        kind: IosRegionKind.division,
        bounds: Rect.fromLTRB(1, 2, 3, 4),
        isActive: false,
      ),
    ]);
  });

  test('a null hinge in the plugin event stays null', () {
    final reading = IosFoldReading.fromMap({
      'hinge': null,
      'regions': <Object?>[],
    });

    expect(reading.hinge, isNull);
    expect(reading.regions, isEmpty);
  });
}
