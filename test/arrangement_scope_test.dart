import 'dart:async';

import 'package:arrangement_layout/arrangement_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'injected half-open fold keeps the dialog on one side of the crease',
    (tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final events = StreamController<IosFoldReading>(sync: true);
      addTearDown(events.close);
      final controller = ArrangementController(foldEvents: events.stream);
      addTearDown(controller.dispose);
      events.add(
        const IosFoldReading(
          hinge: HingeState(posture: HingePosture.partiallyOpen, angle: 1.5),
          regions: [
            IosReservedRegion(
              kind: IosRegionKind.division,
              bounds: Rect.fromLTRB(390, 0, 430, 800),
              isActive: true,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            return ArrangementScope(
              controller: controller,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) =>
                        const AlertDialog(content: Text('对话框内容')),
                  );
                },
                child: const Text('打开'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.byType(AlertDialog));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(390));
      expect(tester.view.displayFeatures, isEmpty);
    },
  );
}
