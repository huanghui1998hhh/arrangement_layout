import 'dart:async';

import 'package:arrangement_layout/arrangement_layout.dart';
import 'package:arrangement_layout_example/scenes/cinema.dart';
import 'package:arrangement_layout_example/scenes/claw.dart';
import 'package:arrangement_layout_example/scenes/explore_map.dart';
import 'package:arrangement_layout_example/scenes/reader.dart';
import 'package:arrangement_layout_example/scenes/reminders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _inner = Size(1024, 720);
const _outer = Size(420, 640);

IosFoldReading _reading(String pose, Size size) {
  final vertical = Rect.fromLTWH(size.width / 2 - 20, 0, 40, size.height);
  final horizontal = Rect.fromLTWH(0, size.height / 2 - 20, size.width, 40);
  return switch (pose) {
    'book' => IosFoldReading(
      hinge: const HingeState(posture: HingePosture.partiallyOpen),
      regions: [
        IosReservedRegion(
          kind: IosRegionKind.division,
          bounds: vertical,
          isActive: true,
        ),
      ],
    ),
    'tabletop' => IosFoldReading(
      hinge: const HingeState(posture: HingePosture.partiallyOpen),
      regions: [
        IosReservedRegion(
          kind: IosRegionKind.division,
          bounds: horizontal,
          isActive: true,
        ),
      ],
    ),
    'closed' => const IosFoldReading(
      hinge: HingeState(posture: HingePosture.closed),
      regions: [],
    ),
    _ => const IosFoldReading(
      hinge: HingeState(posture: HingePosture.fullyOpen),
      regions: [],
    ),
  };
}

final _pages = <String, Widget Function()>{
  'cinema': () => const CinemaPage(),
  'map': () => const ExploreMapPage(),
  'reminders': () => const RemindersPage(),
  'reader': () => const ReaderPage(),
  'claw': () => const ClawPage(),
};

void main() {
  testWidgets('claw finishes a round after grabbing', (tester) async {
    tester.view.physicalSize = _inner;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ArrangementScope(child: child!),
        home: const ClawPage(),
      ),
    );
    await tester.tap(find.text('抓'));
    await tester.pump();
    expect(find.text('下爪……'), findsOneWidget);
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('下爪……'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  for (final entry in _pages.entries) {
    for (final (pose, size) in [
      ('flat', _inner),
      ('book', _inner),
      ('tabletop', _inner),
      ('closed', _outer),
    ]) {
      testWidgets('${entry.key} lays out in $pose', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final events = StreamController<IosFoldReading>();
        final controller = ArrangementController(foldEvents: events.stream);
        addTearDown(controller.dispose);
        addTearDown(events.close);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) =>
                ArrangementScope(controller: controller, child: child!),
            home: entry.value(),
          ),
        );
        events.add(_reading('flat', size));
        await tester.pump();
        events.add(_reading(pose, size));
        await tester.pump();
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
