import 'dart:ui';

import 'package:arrangement_layout/arrangement_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  testWidgets('secondary keeps its state when it leaves and comes back', (
    tester,
  ) async {
    const Key secondaryKey = Key('secondary');
    Widget harness(ArrangementStyle style, Size size) {
      return MaterialApp(
        home: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: ArrangementLayout(
              style: style,
              primary: const ColoredBox(color: Color(0xFF1565C0)),
              secondary: const _Memory(key: secondaryKey),
            ),
          ),
        ),
      );
    }

    const ArrangementStyle split = ArrangementStyle.split(
      minPrimaryExtent: 100,
      minSecondaryExtent: 100,
    );
    const ArrangementStyle horizontalOnly = ArrangementStyle.split(
      axes: <Axis>{Axis.horizontal},
      minPrimaryExtent: 100,
      minSecondaryExtent: 100,
    );

    await tester.pumpWidget(harness(split, const Size(800, 400)));
    await settle(tester);
    await tester.tap(find.text('未记住'));
    await tester.pump();

    expect(find.text('已记住'), findsOneWidget);

    await tester.pumpWidget(harness(horizontalOnly, const Size(400, 500)));
    await settle(tester);
    expect(find.text('已记住'), findsOneWidget);

    await tester.pumpWidget(harness(split, const Size(800, 400)));
    await settle(tester);
    expect(find.text('已记住'), findsOneWidget);
  });

  testWidgets('a hidden secondary is not hittable and has no semantics', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    var taps = 0;

    Widget harness(Set<Axis> axes) {
      return MaterialApp(
        home: ArrangementLayout(
          style: ArrangementStyle.split(
            axes: axes,
            minPrimaryExtent: 100,
            minSecondaryExtent: 100,
          ),
          primary: const ColoredBox(color: Color(0xFF1565C0)),
          secondary: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps += 1,
                ),
              ),
              const Center(child: Text('次级')),
            ],
          ),
        ),
      );
    }

    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetDisplayFeatures);
    tester.view.displayFeatures = const <DisplayFeature>[
      DisplayFeature(
        bounds: Rect.fromLTRB(500, 0, 540, 600),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureFlat,
      ),
    ];

    try {
      await tester.pumpWidget(harness(<Axis>{Axis.horizontal, Axis.vertical}));
      await settle(tester);
      expect(find.bySemanticsLabel('次级'), findsOneWidget);

      await tester.tapAt(const Offset(560, 20));
      await tester.pump();
      expect(taps, 1);

      await tester.pumpWidget(harness(<Axis>{Axis.vertical}));
      await settle(tester);
      expect(_semanticsTreeContains('次级'), isFalse);

      await tester.tapAt(const Offset(650, 300));
      await tester.pump();
      expect(taps, 1);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('layered primary receives the hit above secondary', (
    tester,
  ) async {
    var hit = '';
    await tester.pumpWidget(
      MaterialApp(
        home: ArrangementLayout(
          style: const ArrangementStyle.overlay(),
          primary: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => hit = 'primary',
            child: const SizedBox(width: 80, height: 80),
          ),
          secondary: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => hit = 'secondary',
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await settle(tester);

    await tester.tapAt(const Offset(40, 40));
    await tester.pump();
    expect(hit, 'primary');

    await tester.tapAt(const Offset(400, 400));
    await tester.pump();
    expect(hit, 'secondary');
  });

  testWidgets('only a presentation change animates the frames', (tester) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const Key primaryKey = Key('primary');
    Widget harness() {
      return MaterialApp(
        home: ArrangementLayout(
          duration: const Duration(milliseconds: 300),
          curve: Curves.linear,
          style: const ArrangementStyle.split(
            minPrimaryExtent: 100,
            minSecondaryExtent: 100,
          ),
          primary: const SizedBox.expand(key: primaryKey),
          secondary: const SizedBox.expand(),
        ),
      );
    }

    await tester.pumpWidget(harness());
    await settle(tester);
    expect(
      tester.getRect(find.byKey(primaryKey)),
      const Rect.fromLTWH(0, 0, 450, 400),
    );

    tester.view.physicalSize = const Size(400, 900);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final Rect mid = tester.getRect(find.byKey(primaryKey));
    expect(mid.width, closeTo(425, 0.1));
    expect(mid.height, closeTo(425, 0.1));

    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(primaryKey)),
      const Rect.fromLTWH(0, 0, 400, 450),
    );
  });

  testWidgets('a hinge below an app bar is measured in local coordinates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetDisplayFeatures);
    tester.view.displayFeatures = const <DisplayFeature>[
      DisplayFeature(
        bounds: Rect.fromLTRB(0, 450, 800, 470),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureFlat,
      ),
    ];

    const Key primaryKey = Key('primary');
    const Key secondaryKey = Key('secondary');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('标题')),
          body: const ArrangementLayout(
            style: ArrangementStyle.split(
              minPrimaryExtent: 48,
              minSecondaryExtent: 48,
            ),
            primary: SizedBox.expand(key: primaryKey),
            secondary: SizedBox.expand(key: secondaryKey),
          ),
        ),
      ),
    );
    await settle(tester);

    final Rect arrangement = tester.getRect(find.byType(ArrangementLayout));
    final Rect primary = tester.getRect(find.byKey(primaryKey));
    final Rect secondary = tester.getRect(find.byKey(secondaryKey));
    expect(arrangement.top, greaterThan(0));
    expect(primary.bottom, closeTo(450, 0.1));
    expect(secondary.top, closeTo(470, 0.1));
  });

  testWidgets('panes publish the resolved presentation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ArrangementLayout(
          style: ArrangementStyle.overlay(),
          primary: _PaneLabel(),
          secondary: _PaneLabel(),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('primary overlayLayered 1.0'), findsOneWidget);
    expect(find.text('secondary overlayLayered 0.0'), findsOneWidget);
  });
}

bool _semanticsTreeContains(String label) {
  final SemanticsNode? root =
      WidgetsBinding.instance.rootPipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root == null) {
    return false;
  }
  var found = false;
  void visit(SemanticsNode node) {
    if (node.label == label) {
      found = true;
    }
    node.visitChildren((SemanticsNode child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return found;
}

class _Memory extends StatefulWidget {
  const _Memory({super.key});

  @override
  State<_Memory> createState() => _MemoryState();
}

class _MemoryState extends State<_Memory> {
  bool remembered = false;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => remembered = true),
      child: Text(remembered ? '已记住' : '未记住'),
    );
  }
}

class _PaneLabel extends StatelessWidget {
  const _PaneLabel();

  @override
  Widget build(BuildContext context) {
    final ArrangementPane pane = ArrangementPane.of(context);
    return Text(
      '${pane.role.name} ${pane.presentation.name} ${pane.zIndex.toStringAsFixed(1)}',
    );
  }
}
