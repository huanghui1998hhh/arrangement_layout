import 'dart:async';
import 'dart:ui';

import 'package:arrangement_layout/arrangement_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('controller follows FlutterView.displayFeatures', (tester) async {
    addTearDown(tester.view.resetDisplayFeatures);
    final controller = ArrangementController();
    addTearDown(controller.dispose);

    expect(controller.value.hinge, isNull);

    tester.view.displayFeatures = const [
      DisplayFeature(
        bounds: Rect.fromLTWH(0, 400, 800, 12),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    ];

    expect(
      controller.value.hinge,
      const HingeState(posture: HingePosture.partiallyOpen),
    );
    expect(controller.value.displayFeatures, hasLength(1));
    expect(controller.value.hinge?.angle, isNull);
  });

  testWidgets(
    'controller applies an injected iOS reading without a platform channel',
    (tester) async {
      final events = StreamController<IosFoldReading>(sync: true);
      addTearDown(events.close);
      final controller = ArrangementController(foldEvents: events.stream);
      addTearDown(controller.dispose);

      events.add(
        const IosFoldReading(
          hinge: HingeState(posture: HingePosture.fullyOpen, angle: 3.14),
          regions: [
            IosReservedRegion(
              kind: IosRegionKind.division,
              bounds: Rect.fromLTWH(380, 0, 40, 800),
              isActive: false,
            ),
          ],
        ),
      );

      expect(controller.value.displayFeatures, isEmpty);
      expect(controller.value.inactiveDisplayFeatures, hasLength(1));
      expect(
        controller.value.hinge,
        const HingeState(posture: HingePosture.fullyOpen, angle: 3.14),
      );
    },
  );
}
