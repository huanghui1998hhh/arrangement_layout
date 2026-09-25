import 'dart:ui';

import 'package:arrangement_layout/arrangement_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Size wide = Size(800, 400);
  const Size tall = Size(400, 800);
  const Size square = Size(800, 800);

  ArrangementResolution resolve({
    Size size = wide,
    List<Rect> separators = const <Rect>[],
    TextDirection direction = TextDirection.ltr,
    ArrangementStyle style = ArrangementStyle.automatic,
  }) {
    return resolveArrangement(
      size: size,
      separators: separators,
      textDirection: direction,
      style: style,
    );
  }

  DisplayFeature feature(
    Rect bounds,
    DisplayFeatureType type,
    DisplayFeatureState state,
  ) {
    return DisplayFeature(bounds: bounds, type: type, state: state);
  }

  test('hinge stays a separator when flat, fold and cutout do not', () {
    const Rect crease = Rect.fromLTRB(390, 0, 430, 800);
    const Rect container = Rect.fromLTWH(0, 0, 800, 800);
    final List<Rect> kept = separatingFeatures(
      features: [
        feature(
          crease,
          DisplayFeatureType.hinge,
          DisplayFeatureState.postureFlat,
        ),
        feature(
          crease,
          DisplayFeatureType.fold,
          DisplayFeatureState.postureFlat,
        ),
        feature(
          const Rect.fromLTWH(300, 0, 80, 32),
          DisplayFeatureType.cutout,
          DisplayFeatureState.unknown,
        ),
        feature(
          crease,
          DisplayFeatureType.fold,
          DisplayFeatureState.postureHalfOpened,
        ),
      ],
      container: container,
    );

    expect(kept, <Rect>[crease, crease]);
  });

  test('a separator outside the container is ignored', () {
    final List<Rect> kept = separatingFeatures(
      features: [
        feature(
          const Rect.fromLTWH(2000, 0, 20, 800),
          DisplayFeatureType.hinge,
          DisplayFeatureState.postureHalfOpened,
        ),
      ],
      container: const Rect.fromLTWH(0, 0, 800, 800),
    );

    expect(kept, isEmpty);
  });

  test('a zero-width fold is kept and shifted into local coordinates', () {
    final List<Rect> kept = separatingFeatures(
      features: [
        feature(
          const Rect.fromLTRB(500, 80, 500, 880),
          DisplayFeatureType.fold,
          DisplayFeatureState.postureHalfOpened,
        ),
      ],
      container: const Rect.fromLTWH(100, 80, 800, 600),
    );

    expect(kept, <Rect>[const Rect.fromLTRB(400, 0, 400, 600)]);
  });

  test('the separator with the larger overlap wins', () {
    final ArrangementResolution resolution = resolve(
      size: square,
      separators: const <Rect>[
        Rect.fromLTWH(0, 0, 10, 800),
        Rect.fromLTWH(300, 0, 40, 800),
      ],
      style: const ArrangementStyle.split(
        minPrimaryExtent: 0,
        minSecondaryExtent: 0,
      ),
    );

    expect(resolution.presentation, ArrangementPresentation.splitHorizontal);
    expect(resolution.primary, const Rect.fromLTWH(0, 0, 300, 800));
    expect(resolution.secondary, const Rect.fromLTWH(340, 0, 460, 800));
  });

  test('a wider window without a separator splits horizontally by ratio', () {
    final ArrangementResolution resolution = resolve(
      style: const ArrangementStyle.split(
        ratio: 0.25,
        minPrimaryExtent: 100,
        minSecondaryExtent: 100,
      ),
    );

    expect(resolution.presentation, ArrangementPresentation.splitHorizontal);
    expect(resolution.axis, Axis.horizontal);
    expect(resolution.primary, const Rect.fromLTWH(0, 0, 200, 400));
    expect(resolution.secondary, const Rect.fromLTWH(200, 0, 600, 400));
    expect(resolution.floatRegion, isNull);
  });

  test('a wider window in RTL keeps primary on the leading side', () {
    final ArrangementResolution resolution = resolve(
      direction: TextDirection.rtl,
      style: const ArrangementStyle.split(
        ratio: 0.25,
        minPrimaryExtent: 100,
        minSecondaryExtent: 100,
      ),
    );

    expect(resolution.primary, const Rect.fromLTWH(600, 0, 200, 400));
    expect(resolution.secondary, const Rect.fromLTWH(0, 0, 600, 400));
  });

  test('a taller window stacks primary above secondary', () {
    final ArrangementResolution resolution = resolve(
      size: tall,
      style: const ArrangementStyle.split(
        ratio: 0.25,
        minPrimaryExtent: 100,
        minSecondaryExtent: 100,
      ),
    );

    expect(resolution.presentation, ArrangementPresentation.splitVertical);
    expect(resolution.axis, Axis.vertical);
    expect(resolution.primary, const Rect.fromLTWH(0, 0, 400, 200));
    expect(resolution.secondary, const Rect.fromLTWH(0, 200, 400, 600));
  });

  test('a square window is treated as wider', () {
    final ArrangementResolution resolution = resolve(size: square);

    expect(resolution.presentation, ArrangementPresentation.splitHorizontal);
    expect(resolution.primary, const Rect.fromLTWH(0, 0, 400, 800));
  });

  test('only the aspect-matching axis is tried', () {
    final ArrangementResolution wide = resolve(
      style: const ArrangementStyle.split(axes: <Axis>{Axis.vertical}),
    );
    final ArrangementResolution narrow = resolve(
      size: tall,
      style: const ArrangementStyle.split(axes: <Axis>{Axis.horizontal}),
    );

    expect(wide.presentation, ArrangementPresentation.primaryOnly);
    expect(wide.primary, const Rect.fromLTWH(0, 0, 800, 400));
    expect(wide.secondary, isNull);
    expect(narrow.presentation, ArrangementPresentation.primaryOnly);
    expect(narrow.primary, Offset.zero & tall);
  });

  test('minimum extents keep a short split from squeezing both panes', () {
    final ArrangementResolution resolution = resolve(
      style: const ArrangementStyle.split(
        ratio: 0.5,
        minPrimaryExtent: 500,
        minSecondaryExtent: 500,
      ),
    );

    expect(resolution.presentation, ArrangementPresentation.primaryOnly);
    expect(resolution.primary, const Rect.fromLTWH(0, 0, 800, 400));
  });

  test('a vertical hinge places panes on either side and ignores ratio', () {
    final ArrangementResolution resolution = resolve(
      size: const Size(800, 600),
      separators: const <Rect>[Rect.fromLTRB(300, 0, 340, 600)],
      style: const ArrangementStyle.split(
        ratio: 0.2,
        minPrimaryExtent: 100,
        minSecondaryExtent: 100,
      ),
    );

    expect(resolution.presentation, ArrangementPresentation.splitHorizontal);
    expect(resolution.primary, const Rect.fromLTWH(0, 0, 300, 600));
    expect(resolution.secondary, const Rect.fromLTWH(340, 0, 460, 600));
  });

  test('a horizontal hinge stacks primary above the gap', () {
    final ArrangementResolution resolution = resolve(
      size: const Size(800, 600),
      separators: const <Rect>[Rect.fromLTRB(0, 200, 800, 240)],
      style: const ArrangementStyle.split(
        minPrimaryExtent: 100,
        minSecondaryExtent: 100,
      ),
    );

    expect(resolution.presentation, ArrangementPresentation.splitVertical);
    expect(resolution.primary, const Rect.fromLTWH(0, 0, 800, 200));
    expect(resolution.secondary, const Rect.fromLTWH(0, 240, 800, 360));
  });

  test('RTL mirrors leading and trailing around a vertical hinge', () {
    const Rect hinge = Rect.fromLTRB(300, 0, 340, 600);
    final ArrangementResolution ltr = resolve(
      size: const Size(800, 600),
      separators: const <Rect>[hinge],
      style: const ArrangementStyle.split(
        minPrimaryExtent: 100,
        minSecondaryExtent: 100,
      ),
    );
    final ArrangementResolution rtl = resolve(
      size: const Size(800, 600),
      separators: const <Rect>[hinge],
      direction: TextDirection.rtl,
      style: const ArrangementStyle.split(
        minPrimaryExtent: 100,
        minSecondaryExtent: 100,
      ),
    );

    expect(rtl.primary, ltr.secondary);
    expect(rtl.secondary, ltr.primary);
  });

  test('a side below the minimum leaves primary on the larger side', () {
    final ArrangementResolution resolution = resolve(
      size: const Size(800, 600),
      separators: const <Rect>[Rect.fromLTRB(100, 0, 140, 600)],
    );

    expect(resolution.presentation, ArrangementPresentation.primaryOnly);
    expect(resolution.primary, const Rect.fromLTWH(140, 0, 660, 600));
    expect(resolution.secondary, isNull);
  });

  test('an equal vertical split that cannot open keeps the trailing side', () {
    final ArrangementResolution ltr = resolve(
      size: square,
      separators: const <Rect>[Rect.fromLTRB(400, 0, 400, 800)],
      style: const ArrangementStyle.split(axes: <Axis>{Axis.vertical}),
    );
    final ArrangementResolution rtl = resolve(
      size: square,
      separators: const <Rect>[Rect.fromLTRB(400, 0, 400, 800)],
      direction: TextDirection.rtl,
      style: const ArrangementStyle.split(axes: <Axis>{Axis.vertical}),
    );

    expect(ltr.presentation, ArrangementPresentation.primaryOnly);
    expect(ltr.primary, const Rect.fromLTWH(400, 0, 400, 800));
    expect(rtl.primary, const Rect.fromLTWH(0, 0, 400, 800));
  });

  test('an equal horizontal split that cannot open keeps the top', () {
    final ArrangementResolution resolution = resolve(
      size: square,
      separators: const <Rect>[Rect.fromLTRB(0, 400, 800, 400)],
      style: const ArrangementStyle.split(axes: <Axis>{Axis.horizontal}),
    );

    expect(resolution.presentation, ArrangementPresentation.primaryOnly);
    expect(resolution.primary, const Rect.fromLTWH(0, 0, 800, 400));
  });

  test('overlay without a separator floats primary over a full secondary', () {
    final ArrangementResolution resolution = resolve(
      size: const Size(800, 600),
      style: const ArrangementStyle.overlay(),
    );

    expect(resolution.presentation, ArrangementPresentation.overlayLayered);
    expect(resolution.axis, isNull);
    expect(resolution.primary, isNull);
    expect(resolution.secondary, const Rect.fromLTWH(0, 0, 800, 600));
    expect(resolution.floatRegion, const Rect.fromLTRB(16, 16, 784, 584));
  });

  test('overlay padding follows the writing direction', () {
    final ArrangementResolution resolution = resolve(
      size: const Size(800, 600),
      direction: TextDirection.rtl,
      style: const ArrangementStyle.overlay(
        layeredPadding: EdgeInsetsDirectional.fromSTEB(1, 2, 3, 4),
      ),
    );

    expect(resolution.floatRegion, const Rect.fromLTRB(3, 2, 799, 596));
  });

  test(
    'a book hinge puts overlay primary on the requested horizontal edge',
    () {
      const Rect hinge = Rect.fromLTRB(300, 0, 340, 600);
      final ArrangementResolution trailing = resolve(
        size: const Size(800, 600),
        separators: const <Rect>[hinge],
        style: const ArrangementStyle.overlay(),
      );
      final ArrangementResolution leading = resolve(
        size: const Size(800, 600),
        separators: const <Rect>[hinge],
        style: const ArrangementStyle.overlay(
          horizontalEdge: ArrangementEdge.leading,
        ),
      );

      expect(trailing.presentation, ArrangementPresentation.overlaySeparated);
      expect(trailing.axis, Axis.horizontal);
      expect(trailing.primary, const Rect.fromLTWH(340, 0, 460, 600));
      expect(trailing.secondary, const Rect.fromLTWH(0, 0, 300, 600));
      expect(leading.primary, const Rect.fromLTWH(0, 0, 300, 600));
      expect(leading.secondary, const Rect.fromLTWH(340, 0, 460, 600));
    },
  );

  test('a tabletop hinge puts overlay primary on the bottom by default', () {
    final ArrangementResolution resolution = resolve(
      size: const Size(800, 600),
      separators: const <Rect>[Rect.fromLTRB(0, 200, 800, 240)],
      style: const ArrangementStyle.overlay(),
    );

    expect(resolution.presentation, ArrangementPresentation.overlaySeparated);
    expect(resolution.axis, Axis.vertical);
    expect(resolution.primary, const Rect.fromLTWH(0, 240, 800, 360));
    expect(resolution.secondary, const Rect.fromLTWH(0, 0, 800, 200));
  });

  test('overlay layers inside the only usable side of a hinge', () {
    final ArrangementResolution resolution = resolve(
      size: const Size(800, 600),
      separators: const <Rect>[Rect.fromLTRB(0, 0, 800, 600)],
      style: const ArrangementStyle.overlay(),
    );

    expect(resolution.presentation, ArrangementPresentation.overlayLayered);
    expect(resolution.secondary!.width, greaterThan(0));
  });
}
