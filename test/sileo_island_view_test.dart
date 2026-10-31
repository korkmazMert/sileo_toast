// Spec: docs/plans/sileo-large-island.md §7.1 (resolver), §7.2 (geometry),
// §7.2b (performance), §7.3 (rendering), §9 "Island rendering",
// "Performance", "Island geometry" (override); §10 edge cases. Expectations
// are hand-computed from the plan, never read off the implementation.
//
// Scenario list (393 x 852 view, padding.top = 59, 1.0 scale, Ahem font):
// * Resolved island (table row 59/393x852): rect 126 x 37 at top 11.6,
//   centered (left 133.5 + ... = (393 - 126) / 2 = 133.5).
// * Pill top == padding.top == 59 (box.top = 59 - 4 tap extension = 55).
// * Neck top == island.top - bleed = 11.6 - 1.5 = 10.1, so the neck is
//   59 - 10.1 = 48.9 long and ends at the pill top; its capsule is
//   126 + 3 = 129 wide, 37 + 3 = 40 tall, centered on the island (x 196.5).
// * Custom resolver Rect(100, 20, 200 x 30) at padding 59: neck length
//   59 - 20 + 1.5 = 40.5. Android centered punch hole (181.5, 12, 30 x 30)
//   with padding 40: neck length 40 - 12 + 1.5 = 29.5, corner hole: none.
// * Entry: first frame neck 0, pill at the island width (126), opacity 1;
//   exit: neck back to 0, removed after exitDuration (600 ms).
// * Fill: exactly 0xFF000000 under light/dark/system/no theme and with
//   options.fill set; a fallback toast keeps the theme fill.
// * Null resolver / 47 pt notch MediaQuery: box and pill identical to a
//   topCenter toast, theme fill, no neck. Rotation: landscape -> fallback,
//   portrait again -> neck again.
// * One slot: a second island id marks the first exiting; same id morphs
//   (single live item); topCenter toasts and the island still coexist.
// * Reduce motion: neck and pill jump, nothing in flight after one pump.
// * Resolver memo: one call per size / top-padding / displayFeatures
//   change, none per frame, per toast or for a text-scale change.
// * Performance: 0 package-widget rebuilds per frame while an island
//   toast expands, 0 repaints idle, no filter layer or saveLayer.
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sileo_toast/sileo_toast.dart';
import 'package:sileo_toast/src/sileo_shape_painter.dart';

const _black = Color(0xFF000000);

/// Advances fake time in 20 ms frames (springs start on the frame after a
/// timer fires).
Future<void> _wait(WidgetTester t, int ms) async {
  var left = ms;
  while (left > 0) {
    final step = left < 20 ? left : 20;
    await t.pump(Duration(milliseconds: step));
    left -= step;
  }
}

MediaQueryData _mq({
  Size size = const Size(393, 852),
  double top = 59,
  TextScaler scaler = TextScaler.noScaling,
  bool noAnimations = false,
  Brightness brightness = Brightness.light,
  List<DisplayFeature> features = const [],
}) => MediaQueryData(
  size: size,
  padding: EdgeInsets.only(top: top),
  viewPadding: EdgeInsets.only(top: top),
  textScaler: scaler,
  disableAnimations: noAnimations,
  platformBrightness: brightness,
  displayFeatures: features,
);

/// Pumps (or re-pumps, keeping state) a toaster under [mq].
Future<void> _host(
  WidgetTester tester,
  SileoController c,
  MediaQueryData mq, {
  SileoIslandResolver? island,
  SileoThemeMode? theme,
}) async {
  tester.view
    ..physicalSize = mq.size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: mq,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SileoToaster(
          controller: c,
          position: SileoPosition.topCenter,
          theme: theme,
          island: island ?? SileoIsland.detect,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

Finder _painterOf([String? id]) {
  final painters = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is SileoShapePainter,
  );
  return id == null
      ? painters
      : find.descendant(of: find.byKey(ValueKey(id)), matching: painters);
}

SileoShapePainter _shape(WidgetTester t, [String? id]) =>
    t.widget<CustomPaint>(_painterOf(id)).painter! as SileoShapePainter;

Rect _box(WidgetTester t, [String? id]) => t.getRect(_painterOf(id));

/// Screen y of the visible pill top (the box has a 4 dp tap extension).
double _pillTop(WidgetTester t, [String? id]) => _box(t, id).top + 4;

/// Screen y of the neck top: the pill top minus the neck's current length.
double _neckTop(WidgetTester t, [String? id]) =>
    _pillTop(t, id) - _shape(t, id).neckHeight!.value;

SileoOptions _toast({
  String title = 'Hi',
  String id = 'i',
  SileoPosition position = SileoPosition.island,
  Widget? description = const Text('x'),
  Color? fill,
  SileoSize? size,
  bool persistent = true,
}) => SileoOptions(
  title: title,
  id: id,
  position: position,
  description: description,
  fill: fill,
  size: size,
  persistent: persistent,
  autopilot: SileoAutopilot.off,
);

const _packageWidgets = {
  'SileoToaster',
  'SileoToastView',
  '_Viewport',
  '_ToastContent',
  '_ToastHeader',
  '_ToastShape',
  '_ToastEntry',
  '_LargeBody',
  '_ActionButton',
};

int _rebuilds = 0;

void _countRebuilds() {
  _rebuilds = 0;
  debugOnRebuildDirtyWidget = (element, _) {
    if (_packageWidgets.contains(element.widget.runtimeType.toString())) {
      _rebuilds++;
    }
  };
  addTearDown(() => debugOnRebuildDirtyWidget = null);
}

int _paints(WidgetTester t) {
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find
        .ancestor(of: _painterOf(), matching: find.byType(RepaintBoundary))
        .first,
  );
  return boundary.debugSymmetricPaintCount + boundary.debugAsymmetricPaintCount;
}

void _filterLayers(Layer layer, List<String> found) {
  if (layer is BackdropFilterLayer ||
      layer is ImageFilterLayer ||
      layer is ShaderMaskLayer ||
      layer is ColorFilterLayer ||
      // Fully opaque OpacityLayers are no-ops for the engine (no saveLayer).
      (layer is OpacityLayer && layer.alpha != 255 && layer.alpha != 0)) {
    found.add(layer.runtimeType.toString());
  }
  if (layer is ContainerLayer) {
    for (var c = layer.firstChild; c != null; c = c.nextSibling) {
      _filterLayers(c, found);
    }
  }
}

class _Recording implements Canvas {
  final calls = <Symbol>[];
  final paints = <Paint>[];

  @override
  void drawPath(Path path, Paint paint) {
    calls.add(#drawPath);
    paints.add(paint);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation.memberName);
  }
}

void _expectNoExpensiveOps(WidgetTester t) {
  final found = <String>[];
  _filterLayers(RendererBinding.instance.renderViews.first.debugLayer!, found);
  expect(found, isEmpty, reason: 'filter layers in steady state: $found');
  final canvas = _Recording();
  final render = t.renderObject<RenderCustomPaint>(_painterOf());
  render.painter!.paint(canvas, render.size);
  expect(canvas.calls, contains(#drawPath));
  expect(canvas.calls, isNot(contains(#saveLayer)));
  for (final p in canvas.paints) {
    expect(p.imageFilter, isNull);
    expect(p.maskFilter, isNull);
  }
}

void main() {
  late SileoController c;
  setUp(() => c = SileoController());
  tearDown(() => c.dispose());

  Future<void> end(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    c.dispose();
  }

  group('island geometry (393 x 852, padding.top 59)', () {
    // Mutation: pill top uses padding.top + viewportPadding (the topCenter
    // placement, 71) instead of padding.top.
    testWidgets('pill top == padding.top (59)', (tester) async {
      await _host(tester, c, _mq());
      c.show(_toast());
      await _wait(tester, 1500);
      expect(_pillTop(tester), closeTo(59, 0.01));
      await end(tester);
    });

    // Mutation: bleed dropped, or the neck anchored to the pill instead of
    // the island top.
    testWidgets('neck top == island.top - bleed (10.1), neck 48.9 long', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      c.show(_toast());
      await _wait(tester, 1500);
      expect(_neckTop(tester), closeTo(11.6 - 1.5, 0.01));
      expect(_shape(tester).neckHeight!.value, closeTo(48.9, 0.01));
      await end(tester);
    });

    // Mutation: neck capsule not inflated by the bleed, or off-center.
    testWidgets('neck capsule is 129 x 40, centered on the island (196.5)', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      c.show(_toast());
      await _wait(tester, 1500);
      final neck = _shape(tester).neck!;
      expect(neck.width, closeTo(129, 0.01));
      expect(neck.height, closeTo(40, 0.01));
      expect(_box(tester).left + neck.center.dx, closeTo(196.5, 0.01));
      await end(tester);
    });

    // Mutation: the neck stops short of the pill (gap) or is not painted.
    testWidgets('the painted neck covers the island row down to the pill', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      c.show(_toast());
      await _wait(tester, 1500);
      final box = _box(tester);
      final cx = box.width / 2;
      // Path coordinates: the pill top is at y = 0, the neck is above it.
      // Inside the neck column (just above the pill, mid-neck, just under
      // the neck top) is painted; beside the neck and above its top is not.
      expect(
        tester.renderObject(_painterOf()),
        paints..path(
          color: _black,
          includes: [Offset(cx, -2), Offset(cx, -25), Offset(cx, -46.9)],
          excludes: [
            Offset(cx - 150, -25),
            Offset(cx + 150, -25),
            Offset(cx, -48.9 - 2),
          ],
        ),
      );
      await end(tester);
    });

    // Mutation: the geometry is hard-coded instead of taken from the resolver.
    testWidgets('a custom resolver rect drives the neck (40.5 long)', (
      tester,
    ) async {
      await _host(
        tester,
        c,
        _mq(),
        island: (_) => const Rect.fromLTWH(100, 20, 200, 30),
      );
      c.show(_toast());
      await _wait(tester, 1500);
      expect(_pillTop(tester), closeTo(59, 0.01));
      expect(_shape(tester).neckHeight!.value, closeTo(40.5, 0.01));
      expect(_shape(tester).neck!.width, closeTo(203, 0.01));
      await end(tester);
    });

    // Mutation: the 430 x 932 table row is not honoured by the toaster.
    testWidgets('the 430 x 932 iPhone row resolves too', (tester) async {
      await _host(tester, c, _mq(size: const Size(430, 932)));
      c.show(_toast());
      await _wait(tester, 1500);
      expect(_shape(tester).neckHeight!.value, closeTo(59 - 11.6 + 1.5, 0.01));
      await end(tester);
    });

    // Mutation: Android displayFeatures cutouts ignored by the default.
    testWidgets('Android centered punch hole drives the neck (29.5 long)', (
      tester,
    ) async {
      await _host(
        tester,
        c,
        _mq(
          top: 40,
          features: const [
            DisplayFeature(
              bounds: Rect.fromLTWH(181.5, 12, 30, 30),
              type: DisplayFeatureType.cutout,
              state: DisplayFeatureState.unknown,
            ),
          ],
        ),
      );
      c.show(_toast());
      await _wait(tester, 1500);
      expect(_pillTop(tester), closeTo(40, 0.01));
      expect(_shape(tester).neckHeight!.value, closeTo(29.5, 0.01));
      await end(tester);
    });

    // Mutation: a corner hole is treated as an island.
    testWidgets('Android corner punch hole falls back (no neck)', (
      tester,
    ) async {
      await _host(
        tester,
        c,
        _mq(
          top: 40,
          features: const [
            DisplayFeature(
              bounds: Rect.fromLTWH(340, 8, 30, 30),
              type: DisplayFeatureType.cutout,
              state: DisplayFeatureState.unknown,
            ),
          ],
        ),
      );
      c.show(_toast());
      await _wait(tester, 1500);
      expect(_shape(tester).neck, isNull);
      expect(_pillTop(tester), closeTo(40 + 12, 0.01));
      await end(tester);
    });

    // Mutation: SileoToaster.island override ignored (always detect).
    testWidgets('SileoToaster(island:) overrides detection on a notch', (
      tester,
    ) async {
      await _host(
        tester,
        c,
        _mq(top: 47),
        island: (_) => const Rect.fromLTWH(150, 10, 100, 30),
      );
      c.show(_toast());
      await _wait(tester, 1500);
      expect(_shape(tester).neck, isNotNull);
      expect(_pillTop(tester), closeTo(47, 0.01));
      await end(tester);
    });

    // Mutation: the toast gets a content-sized neck even without content.
    testWidgets('island toast keeps the status bar row free (pill top 59)', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      c.show(_toast(description: null));
      await _wait(tester, 1500);
      expect(_box(tester).top + 4, greaterThanOrEqualTo(59));
      await end(tester);
    });
  });

  group('entry and exit', () {
    // Mutation: neck starts at full length, pill starts at its target width,
    // or opacity starts at 0 (scale/fade entry used for island).
    testWidgets('first frame: neck 0, pill at island width, opacity 1', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      c.show(_toast(title: 'Hello world'));
      await tester.pump();
      expect(_shape(tester).neckHeight!.value, closeTo(0, 0.01));
      expect(_shape(tester).pillWidth.value, closeTo(126, 0.01));
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(of: _painterOf(), matching: find.byType(FadeTransition))
            .first,
      );
      expect(fade.opacity.value, 1);
      await _wait(tester, 100);
      expect(_shape(tester).neckHeight!.value, greaterThan(0.5));
      expect(_shape(tester).neckHeight!.value, lessThan(48.9));
      await _wait(tester, 1500);
      expect(_shape(tester).neckHeight!.value, closeTo(48.9, 0.05));
      expect(_shape(tester).pillWidth.value, greaterThan(126));
      await end(tester);
    });

    // Mutation: exit leaves the neck at full length or never removes it.
    testWidgets('exit retracts the neck and removes after 600 ms', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      c.show(_toast());
      await _wait(tester, 1500);
      c.dismiss('i');
      await _wait(tester, 100);
      expect(c.items.single.exiting, isTrue);
      expect(_shape(tester).neckHeight!.value, lessThan(48.9 - 1));
      await _wait(tester, 400);
      expect(c.items, hasLength(1), reason: 'still removing before 600 ms');
      await _wait(tester, 300);
      expect(c.items, isEmpty);
      expect(_painterOf(), findsNothing);
      await end(tester);
    });
  });

  group('fill', () {
    for (final (name, theme, brightness) in [
      ('light', SileoThemeMode.light, Brightness.light),
      ('dark', SileoThemeMode.dark, Brightness.dark),
      ('system (dark platform)', SileoThemeMode.system, Brightness.dark),
      ('no theme', null, Brightness.light),
      ('no theme (dark platform)', null, Brightness.dark),
    ]) {
      // Mutation: the island takes the theme fill (white/dark).
      testWidgets('island fill is #000000 under $name', (tester) async {
        await _host(tester, c, _mq(brightness: brightness), theme: theme);
        c.show(_toast());
        await _wait(tester, 1500);
        expect(_shape(tester).fill, _black);
        await end(tester);
      });
    }

    // Mutation: options.fill wins over the island black.
    testWidgets('options.fill does not change the island black', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      c.show(_toast(fill: const Color(0xFFFF0000)));
      await _wait(tester, 1500);
      expect(_shape(tester).fill, _black);
      await end(tester);
    });

    // Mutation: the fallback also forces black.
    testWidgets('fallback keeps options.fill (and no neck)', (tester) async {
      await _host(tester, c, _mq(top: 47));
      c.show(_toast(fill: const Color(0xFFFF0000)));
      await _wait(tester, 1500);
      expect(_shape(tester).fill, const Color(0xFFFF0000));
      expect(_shape(tester).neck, isNull);
      await end(tester);
    });
  });

  group('fallback (no island)', () {
    Future<(Rect, Color, double, double)> placed(
      WidgetTester tester,
      SileoOptions o,
      MediaQueryData mq, {
      SileoIslandResolver? island,
      SileoThemeMode? theme,
    }) async {
      final controller = SileoController();
      await _host(tester, controller, mq, island: island, theme: theme);
      controller.show(o);
      await _wait(tester, 1500);
      final result = (
        _box(tester),
        _shape(tester).fill,
        _shape(tester).pillWidth.value,
        _shape(tester).toastHeight.value,
      );
      expect(_shape(tester).neck, isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      return result;
    }

    // Mutation: the fallback keeps island insets (pill at 47 instead of 59).
    testWidgets('47 pt notch: identical to topCenter, theme fill', (
      tester,
    ) async {
      final mq = _mq(top: 47);
      final island = await placed(tester, _toast(), mq);
      final top = await placed(
        tester,
        _toast(position: SileoPosition.topCenter),
        mq,
      );
      expect(island.$1, top.$1);
      expect(island.$2, top.$2);
      expect(island.$3, closeTo(top.$3, 0.01));
      expect(island.$4, closeTo(top.$4, 0.01));
      expect(island.$2, isNot(_black), reason: 'theme fill, not island black');
      expect(island.$1.top + 4, closeTo(47 + 12, 0.01));
      await tester.pumpWidget(const SizedBox());
    });

    // Mutation: an explicit null resolver crashes or draws a default island.
    testWidgets('null resolver on a 59 pt screen = topCenter, dark theme', (
      tester,
    ) async {
      final island = await placed(
        tester,
        _toast(),
        _mq(),
        island: (_) => null,
        theme: SileoThemeMode.dark,
      );
      final top = await placed(
        tester,
        _toast(position: SileoPosition.topCenter),
        _mq(),
        theme: SileoThemeMode.dark,
      );
      expect(island.$1, top.$1);
      expect(island.$2, top.$2);
      expect(island.$1.top + 4, closeTo(59 + 12, 0.01));
      await tester.pumpWidget(const SizedBox());
    });

    // Mutation: the fallback toast is not one-slot (depends on the device).
    testWidgets('fallback is still one slot', (tester) async {
      await _host(tester, c, _mq(top: 47));
      c
        ..show(_toast(id: 'a'))
        ..show(_toast(id: 'b'));
      await _wait(tester, 100);
      expect(c.items.firstWhere((i) => i.id == 'a').exiting, isTrue);
      expect(c.items.firstWhere((i) => i.id == 'b').exiting, isFalse);
      await end(tester);
    });
  });

  group('rotation', () {
    // Mutation: the resolver result is cached for the first MediaQuery only.
    testWidgets('landscape falls back, portrait restores the neck', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      c.show(_toast());
      await _wait(tester, 1500);
      expect(_shape(tester).neck, isNotNull);
      expect(_pillTop(tester), closeTo(59, 0.01));

      await _host(tester, c, _mq(size: const Size(852, 393), top: 0));
      await _wait(tester, 1500);
      expect(_shape(tester).neck, isNull);
      expect(_pillTop(tester), closeTo(0 + 12, 0.01));
      expect(_shape(tester).fill, isNot(_black));
      expect(tester.takeException(), isNull);

      await _host(tester, c, _mq());
      await _wait(tester, 1500);
      expect(_shape(tester).neck, isNotNull);
      expect(_shape(tester).fill, _black);
      expect(_pillTop(tester), closeTo(59, 0.01));
      expect(_neckTop(tester), closeTo(10.1, 0.05));
      await end(tester);
    });
  });

  group('one slot', () {
    // Mutation: the controller keeps both island toasts live.
    testWidgets('a second island id exits the first and enters itself', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      c.show(_toast(id: 'a', title: 'First'));
      await _wait(tester, 1500);
      c.show(_toast(id: 'b', title: 'Second'));
      await _wait(tester, 100);
      expect(c.items.firstWhere((i) => i.id == 'a').exiting, isTrue);
      expect(c.items.firstWhere((i) => i.id == 'b').exiting, isFalse);
      await _wait(tester, 800);
      expect(c.items.map((i) => i.id), ['b']);
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
      expect(_neckTop(tester, 'b'), closeTo(10.1, 0.05));
      await end(tester);
    });

    // Mutation: same id also exits/duplicates instead of morphing.
    testWidgets('the same island id morphs in place', (tester) async {
      await _host(tester, c, _mq());
      c.show(_toast(title: 'First'));
      await _wait(tester, 1500);
      c.show(_toast(title: 'Second'));
      await _wait(tester, 2000);
      expect(c.items, hasLength(1));
      expect(c.items.single.exiting, isFalse);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('First'), findsNothing);
      expect(_shape(tester).neckHeight!.value, closeTo(48.9, 0.05));
      await end(tester);
    });

    // Mutation: the one-slot rule leaks into other positions.
    testWidgets('other positions still stack and coexist with the island', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      c
        ..show(_toast(id: 'island'))
        ..show(_toast(id: 't1', position: SileoPosition.topCenter))
        ..show(_toast(id: 't2', position: SileoPosition.topCenter));
      await _wait(tester, 1500);
      expect(c.items, hasLength(3));
      expect(c.items.where((i) => i.exiting), isEmpty);
      expect(_painterOf(), findsNWidgets(3));
      expect(_shape(tester, 'island').neck, isNotNull);
      expect(_shape(tester, 't1').neck, isNull);
      // Stacked, not overlapping.
      expect(
        (_box(tester, 't1').top - _box(tester, 't2').top).abs(),
        greaterThan(40),
      );
      await end(tester);
    });
  });

  group('reduce motion', () {
    // Mutation: the neck spring or the pill still animates under
    // disableAnimations.
    testWidgets('island jumps to its end values, nothing in flight', (
      tester,
    ) async {
      await _host(tester, c, _mq(noAnimations: true));
      c.show(_toast());
      await tester.pump();
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      expect(_shape(tester).neckHeight!.value, closeTo(48.9, 0.01));
      expect(_pillTop(tester), closeTo(59, 0.01));
      await tester.tap(find.text('Hi'));
      await tester.pump();
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      expect(_shape(tester).bodyHeight.value, greaterThan(10));
      await end(tester);
    });

    testWidgets('large island under reduce motion has nothing in flight', (
      tester,
    ) async {
      await _host(tester, c, _mq(noAnimations: true));
      c.show(_toast(size: SileoSize.large));
      await tester.pump();
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      expect(_shape(tester).neckHeight!.value, closeTo(48.9, 0.01));
      await end(tester);
    });
  });

  group('resolver memo', () {
    // Mutation: the resolver runs per build/frame/toast instead of per
    // relevant MediaQuery change.
    testWidgets('one call per MediaQuery change, not per frame or toast', (
      tester,
    ) async {
      var calls = 0;
      Rect? resolver(MediaQueryData d) {
        calls++;
        return const Rect.fromLTWH(133.5, 11.6, 126, 37);
      }

      await _host(tester, c, _mq(), island: resolver);
      expect(calls, 0, reason: 'no island toast yet');
      c.show(_toast(id: 'a'));
      await _wait(tester, 1500);
      expect(calls, 1);
      c.show(_toast(id: 'b'));
      await _wait(tester, 1500);
      expect(calls, 1, reason: 'a second toast reuses the resolved rect');
      await tester.tap(find.text('Hi'));
      await _wait(tester, 1500);
      expect(calls, 1, reason: 'expanding does not re-resolve');

      await _host(
        tester,
        c,
        _mq(scaler: const TextScaler.linear(1.5)),
        island: resolver,
      );
      await _wait(tester, 100);
      expect(calls, 1, reason: 'text scale is not a resolver input');

      await _host(tester, c, _mq(size: const Size(430, 932)), island: resolver);
      await _wait(tester, 100);
      expect(calls, 2, reason: 'size changed');

      await _host(
        tester,
        c,
        _mq(size: const Size(430, 932), top: 62),
        island: resolver,
      );
      await _wait(tester, 100);
      expect(calls, 3, reason: 'top padding changed');

      await _host(
        tester,
        c,
        _mq(
          size: const Size(430, 932),
          top: 62,
          features: const [
            DisplayFeature(
              bounds: Rect.fromLTWH(200, 10, 30, 30),
              type: DisplayFeatureType.cutout,
              state: DisplayFeatureState.unknown,
            ),
          ],
        ),
        island: resolver,
      );
      await _wait(tester, 100);
      expect(calls, 4, reason: 'displayFeatures changed');
      await end(tester);
    });
  });

  group('drag and keyboard', () {
    // Mutation: an upward drag moves the pill into the status-bar row.
    testWidgets(
      'upward drag keeps the pill at padding.top; far drag dismisses',
      (tester) async {
        await _host(tester, c, _mq());
        c.show(_toast());
        await _wait(tester, 1500);
        expect(_pillTop(tester), closeTo(59, 0.01));
        final g = await tester.startGesture(tester.getCenter(find.text('Hi')));
        await g.moveBy(const Offset(0, -25));
        await tester.pump();
        await g.moveBy(const Offset(0, -2));
        await tester.pump();
        expect(_pillTop(tester), closeTo(59, 0.01));
        await g.up();
        await _wait(tester, 800);
        expect(_pillTop(tester), closeTo(59, 0.01));
        expect(find.text('Hi'), findsOneWidget, reason: '27 up < threshold');

        final g2 = await tester.startGesture(tester.getCenter(find.text('Hi')));
        await g2.moveBy(const Offset(0, -20));
        await g2.moveBy(const Offset(0, -20));
        await tester.pump();
        expect(_pillTop(tester), closeTo(59, 0.01));
        await g2.up();
        await _wait(tester, 1500);
        expect(find.text('Hi'), findsNothing);
        await end(tester);
      },
    );

    // Mutation: the island path reads the whole MediaQueryData.
    testWidgets('a viewInsets change does not rebuild the toast view', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final mq = ValueNotifier(_mq());
      addTearDown(mq.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<MediaQueryData>(
          valueListenable: mq,
          builder: (context, data, child) =>
              MediaQuery(data: data, child: child!),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SileoToaster(
              controller: c,
              position: SileoPosition.topCenter,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      c.show(_toast());
      await _wait(tester, 1500);
      _countRebuilds();
      mq.value = mq.value.copyWith(
        viewInsets: const EdgeInsets.only(bottom: 300),
      );
      await tester.pump();
      expect(_rebuilds, 0);
      await end(tester);
    });

    // Guard: header content is not re-recorded while only the drag transform
    // moves (holds without a RepaintBoundary: Transform updates its layer).
    testWidgets('header does not repaint while the drag transform moves', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      final painter = _CountingPainter();
      c.show(
        SileoOptions(
          title: 'Hi',
          id: 'i',
          position: SileoPosition.island,
          icon: CustomPaint(size: const Size(8, 8), painter: painter),
          persistent: true,
          autopilot: SileoAutopilot.off,
        ),
      );
      await _wait(tester, 1500);
      final g = await tester.startGesture(tester.getCenter(find.text('Hi')));
      for (final dy in [30.0, 1.0, 1.0]) {
        await g.moveBy(Offset(0, dy));
        await tester.pump();
      }
      await _wait(tester, 200);
      final before = painter.paints;
      final top = _pillTop(tester);
      for (var i = 0; i < 10; i++) {
        await g.moveBy(const Offset(0, -3));
        await tester.pump();
      }
      expect(_pillTop(tester), lessThan(top), reason: 'transform moved');
      expect(painter.paints, greaterThan(0), reason: 'icon painted');
      expect(painter.paints, before);
      await g.up();
      await _wait(tester, 800);
      await end(tester);
    });
  });

  group('performance', () {
    // Mutation: a package widget rebuilds each frame while the neck/body
    // springs run.
    testWidgets('0 package widget rebuilds per frame while island expands', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      c.show(_toast(description: const Text('Description')));
      await _wait(tester, 1500);
      await tester.tap(find.text('Hi'));
      await _wait(tester, 60);
      _countRebuilds();
      final before = _paints(tester);
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_shape(tester).bodyHeight.value, greaterThan(10));
      expect(_paints(tester), greaterThan(before), reason: 'counter is live');
      expect(_rebuilds, 0, reason: 'package widgets rebuilt while animating');
      await end(tester);
    });

    // Mutation: the neck entry also rebuilds per frame.
    testWidgets('0 package widget rebuilds while the neck grows', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      c.show(_toast(size: SileoSize.large));
      await _wait(tester, 40);
      _countRebuilds();
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_shape(tester).neckHeight!.value, closeTo(48.9, 0.5));
      expect(_rebuilds, 0);
      await end(tester);
    });

    // Mutation: a ticker keeps running or the painter repaints when idle.
    testWidgets('an idle island toast repaints 0 times, no tickers', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      c.show(_toast());
      await _wait(tester, 2000);
      final before = _paints(tester);
      await _wait(tester, 500);
      expect(_paints(tester), before);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await end(tester);
    });

    // Mutation: BackdropFilter / blur / saveLayer added to the neck path.
    testWidgets('steady state has no filter layer or saveLayer', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      c.show(_toast());
      await _wait(tester, 2000);
      _expectNoExpensiveOps(tester);
      await tester.tap(find.text('Hi'));
      await _wait(tester, 2000);
      _expectNoExpensiveOps(tester);
      await end(tester);
    });

    testWidgets('large island: steady state has no filter or saveLayer', (
      tester,
    ) async {
      await _host(tester, c, _mq());
      c.show(_toast(size: SileoSize.large));
      await _wait(tester, 2000);
      _expectNoExpensiveOps(tester);
      await tester.tap(find.text('Hi'));
      await _wait(tester, 2000);
      _expectNoExpensiveOps(tester);
      await end(tester);
    });
  });
}

class _CountingPainter extends CustomPainter {
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) => paints++;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
