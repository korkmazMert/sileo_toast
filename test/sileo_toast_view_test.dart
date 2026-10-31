// Spec: plan §7.1 Rendering, Interaction, Tap targets, Semantics,
// Accessibility settings; §9 "Layout and toast view", "Interaction",
// "Accessibility"; §10 edge cases.
//
// Hand-computed numbers (1.0 scale, Ahem font in tests):
// * header 40; pill = title row (24 badge + 8 gap + text) + 26;
// * description 'x' (14/20) -> content 16 + 20 + 16 = 52, so the expanded
//   toast is max(40 * 2.25 = 90, 40 + 52 = 92) = 92 tall (body 52);
// * a 1 dp description -> content 33 -> max(90, 73) = 90 (body 50);
// * the shape sits 4 dp inside the 48 dp gesture box.
import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sileo_toast/sileo_toast.dart';
import 'package:sileo_toast/src/sileo_shape_painter.dart';

/// Advances fake time in 20 ms frames (one big pump would be a single frame,
/// and springs start on the frame after a timer fires).
Future<void> _wait(WidgetTester t, int ms) async {
  var left = ms;
  while (left > 0) {
    final step = left < 20 ? left : 20;
    await t.pump(Duration(milliseconds: step));
    left -= step;
  }
}

Future<void> _host(
  WidgetTester tester,
  SileoController c, {
  Size size = const Size(400, 800),
  TextScaler scaler = TextScaler.noScaling,
  bool accessible = false,
  bool noAnimations = false,
  bool persistA11y = true,
  SileoPosition position = SileoPosition.topRight,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: scaler,
        accessibleNavigation: accessible,
        disableAnimations: noAnimations,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SileoToaster(
          controller: c,
          position: position,
          persistWhenAccessibleNavigation: persistA11y,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

Finder get _painters => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is SileoShapePainter,
);

Finder _painterOf([String? id]) => id == null
    ? _painters
    : find.descendant(of: find.byKey(ValueKey(id)), matching: _painters);

SileoShapePainter _shape(WidgetTester t, [String? id]) =>
    t.widget<CustomPaint>(_painterOf(id)).painter! as SileoShapePainter;

/// Gesture box of one toast (shape box, including the 4 dp extensions).
Rect _box(WidgetTester t, [String? id]) => t.getRect(_painterOf(id));

/// Visible pill: x from the painter's pillX, y at the 4 dp extension
/// (top) or the box bottom minus 4 (bottom positions).
Rect _pill(WidgetTester t, {String? id, bool top = true}) {
  final box = _box(t, id);
  final s = _shape(t, id);
  final y = top ? box.top + 4 : box.bottom - 4 - s.headerHeight;
  return Rect.fromLTWH(
    box.left + s.pillX.value,
    y,
    s.pillWidth.value,
    s.headerHeight,
  );
}

double _body(WidgetTester t, [String? id]) => _shape(t, id).bodyHeight.value;

SileoOptions _desc({
  String title = 'Saved',
  String id = 'sileo-default',
  SileoState? type,
  SileoAutopilot autopilot = const SileoAutopilot(),
  SileoButton? button,
  SileoPosition? position,
  Widget? description,
  bool persistent = false,
}) => SileoOptions(
  title: title,
  id: id,
  type: type,
  description: description ?? const Text('x'),
  autopilot: autopilot,
  button: button,
  position: position,
  persistent: persistent,
);

void main() {
  late SileoController c;
  setUp(() => c = SileoController());
  // Hosts are removed in each test so the toast timers are cancelled first.
  tearDown(() => c.dispose());

  SemanticsHandle? handle;
  Future<void> end(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    c.dispose();
    handle?.dispose();
    handle = null;
  }

  group('pill sizing', () {
    // Mutation: padding constant (26 = 2*8 + 10) changed, or badge/gap dropped.
    testWidgets('pill width = title row + 26', (tester) async {
      await _host(tester, c);
      c.show(const SileoOptions(title: 'Hi'));
      await _wait(tester, 1000);
      final text = tester.getSize(find.text('Hi')).width;
      expect(_shape(tester).pillWidth.value, closeTo(24 + 8 + text + 26, 0.1));
      await end(tester);
    });

    testWidgets('a longer title widens the pill by its extra width', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(const SileoOptions(title: 'Hi', id: 'a'));
      await _wait(tester, 1000);
      final short = _shape(tester, 'a').pillWidth.value;
      c.show(const SileoOptions(title: 'Hi there', id: 'a'));
      await _wait(tester, 2000);
      final extra =
          tester.getSize(find.text('Hi there')).width -
          13.2 * 2; // Ahem: one font size per glyph
      expect(_shape(tester, 'a').pillWidth.value, closeTo(short + extra, 0.1));
      await end(tester);
    });

    // Mutation: no clamp -> pill wider than the toast, or title overflows.
    testWidgets('very long title clamps to the toast width, ellipsized', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(SileoOptions(title: 'x' * 80));
      await _wait(tester, 1000);
      expect(_shape(tester).pillWidth.value, closeTo(350, 0.01));
      expect(tester.takeException(), isNull);
      await end(tester);
    });

    // Mutation: title shown through a Turkish-unsafe capitalize.
    testWidgets('title is shown as given; only the fallback is capitalized', (
      tester,
    ) async {
      await _host(tester, c);
      c
        ..show(const SileoOptions(title: 'iyi', id: 'a'))
        ..show(const SileoOptions(type: SileoState.warning, id: 'b'));
      await _wait(tester, 1000);
      expect(find.text('iyi'), findsOneWidget);
      expect(find.text('Iyi'), findsNothing);
      expect(find.text('Warning'), findsOneWidget);
      await end(tester);
    });
  });

  group('expanding', () {
    // Mutation: expanded height formula changes (e.g. header + content
    // without the 2.25 floor).
    testWidgets('autopilot expands to header + content (92) after 150 ms', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_desc());
      await _wait(tester, 100);
      expect(_body(tester), lessThan(1));
      await _wait(tester, 1500);
      expect(_body(tester), closeTo(52, 0.5));
      expect(_box(tester).height, closeTo(92 + 8, 0.5));
      await end(tester);
    });

    // Mutation: minExpandRatio floor dropped -> body 33 instead of 50.
    testWidgets('short content still opens to 2.25 x header (90)', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_desc(description: const SizedBox(height: 1, width: 10)));
      await _wait(tester, 1600);
      expect(_body(tester), closeTo(50, 0.5));
      await end(tester);
    });

    testWidgets('autopilot collapses after 4 s', (tester) async {
      await _host(tester, c);
      c.show(_desc());
      await _wait(tester, 1500);
      expect(_body(tester), closeTo(52, 0.5));
      await _wait(tester, 3000); // t = 4.5 s, collapse fired at 4.0 s
      await _wait(tester, 1500);
      expect(_body(tester), lessThan(0.5));
      await end(tester);
    });

    // Mutation: timers not rescheduled after the first cycle (view or
    // controller), so the second toast never expands / dismisses.
    testWidgets('timers run through 3 show/dismiss cycles', (tester) async {
      await _host(tester, c);
      for (var i = 0; i < 3; i++) {
        c.show(_desc());
        await _wait(tester, 100);
        expect(_body(tester), lessThan(1), reason: 'cycle $i before expand');
        await _wait(tester, 1500);
        expect(_body(tester), closeTo(52, 0.5), reason: 'cycle $i expanded');
        await _wait(tester, 4000);
        expect(_body(tester), lessThan(0.5), reason: 'cycle $i collapsed');
        await _wait(tester, 1000); // t = 6.6 s after show
        expect(c.items, isEmpty, reason: 'cycle $i dismissed');
        await _wait(tester, 100);
        expect(_painters, findsNothing);
      }
      await end(tester);
    });

    testWidgets('no description and no button never expands', (tester) async {
      await _host(tester, c);
      c.show(const SileoOptions(title: 'Plain'));
      await _wait(tester, 2000);
      expect(_body(tester), 0);
      await tester.tap(find.text('Plain'));
      await _wait(tester, 1000);
      expect(_body(tester), 0);
      await end(tester);
    });

    // Mutation: loading allowed to expand.
    // Autopilot is active here (finite duration), so only the loading guard
    // keeps it closed.
    testWidgets('loading with autopilot never expands', (tester) async {
      await _host(tester, c);
      c.show(_desc(type: SileoState.loading));
      await _wait(tester, 2000);
      expect(_body(tester), 0);
      await end(tester);
    });

    testWidgets('loading never expands, even on tap', (tester) async {
      await _host(tester, c);
      c.show(_desc(type: SileoState.loading, persistent: true));
      await _wait(tester, 2000);
      expect(_body(tester), 0);
      await tester.tap(find.text('Saved'));
      await _wait(tester, 1000);
      expect(_body(tester), 0);
      await end(tester);
    });

    // Mutation: every toast treated as active.
    testWidgets('only the active (latest) toast expands', (tester) async {
      await _host(tester, c);
      c
        ..show(_desc(id: 'a', title: 'A'))
        ..show(_desc(id: 'b', title: 'B'));
      await _wait(tester, 1500);
      expect(_body(tester, 'b'), closeTo(52, 0.5));
      expect(_body(tester, 'a'), lessThan(0.5));
      await end(tester);
    });

    testWidgets('touching an older toast makes it the expanded one', (
      tester,
    ) async {
      await _host(tester, c);
      c
        ..show(_desc(id: 'a', title: 'A', autopilot: SileoAutopilot.off))
        ..show(_desc(id: 'b', title: 'B'));
      await _wait(tester, 1500);
      await tester.tapAt(_pill(tester, id: 'a').center);
      await _wait(tester, 1500);
      expect(_body(tester, 'a'), closeTo(52, 0.5));
      expect(_body(tester, 'b'), lessThan(0.5));
      await end(tester);
    });
  });

  group('bottom positions expand upward', () {
    testWidgets('bottom: box bottom fixed, header stays at the bottom', (
      tester,
    ) async {
      await _host(tester, c, position: SileoPosition.bottomRight);
      c.show(_desc(autopilot: SileoAutopilot.off));
      await _wait(tester, 1000);
      final before = _box(tester);
      expect(before.bottom, closeTo(800 - 12 + 4, 0.01));
      await tester.tapAt(_pill(tester, top: false).center);
      await _wait(tester, 1500);
      final after = _box(tester);
      expect(after.bottom, closeTo(before.bottom, 0.01));
      expect(after.top, closeTo(before.top - 52, 0.5));
      final title = tester.getRect(find.text('Saved'));
      final desc = tester.getRect(find.text('x'));
      expect(title.center.dy, greaterThan(after.bottom - 4 - 40));
      expect(desc.bottom, lessThanOrEqualTo(title.top));
      await end(tester);
    });

    testWidgets('top: box top fixed, body grows downward', (tester) async {
      await _host(tester, c);
      c.show(_desc(autopilot: SileoAutopilot.off));
      await _wait(tester, 1000);
      final before = _box(tester);
      expect(before.top, closeTo(12 - 4, 0.01));
      await tester.tapAt(_pill(tester).center);
      await _wait(tester, 1500);
      final after = _box(tester);
      expect(after.top, closeTo(before.top, 0.01));
      expect(after.bottom, closeTo(before.bottom + 52, 0.5));
      expect(
        tester.getRect(find.text('x')).top,
        greaterThanOrEqualTo(tester.getRect(find.text('Saved')).bottom),
      );
      await end(tester);
    });
  });

  group('morph (same id)', () {
    testWidgets('collapses, swaps after 200 ms, then re-expands', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(
        const SileoOptions(
          title: 'One',
          description: Text('x'),
          type: SileoState.info,
        ),
      );
      await _wait(tester, 1500);
      expect(_body(tester), closeTo(52, 0.5));

      c.show(
        const SileoOptions(
          title: 'Two',
          description: Text('x'),
          type: SileoState.success,
        ),
      );
      await _wait(tester, 190);
      expect(_body(tester), lessThan(52 - 5), reason: 'collapsing');
      expect(find.text('Two'), findsNothing, reason: 'not swapped before 200');
      expect(find.text('One'), findsOneWidget);

      await _wait(tester, 30); // t = 220 ms
      expect(find.text('Two'), findsOneWidget, reason: 'swapped after 200');

      await _wait(tester, 2500);
      expect(_body(tester), closeTo(52, 0.5), reason: 're-expanded');
      expect(find.text('One'), findsNothing);
      await end(tester);
    });

    // Mutation: swap waits for the full collapse (600 ms).
    testWidgets('swap happens before the collapse has settled', (tester) async {
      await _host(tester, c);
      c.show(const SileoOptions(title: 'One', description: Text('x')));
      await _wait(tester, 1500);
      c.show(const SileoOptions(title: 'Two', description: Text('x')));
      await _wait(tester, 250);
      expect(find.text('Two'), findsOneWidget);
      expect(_body(tester), greaterThan(1), reason: 'still collapsing');
      await end(tester);
    });

    // §10: never more than one previous header layer.
    testWidgets('rapid replacements keep at most one previous header', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(const SileoOptions(title: 'One'));
      await _wait(tester, 1000);
      c.show(const SileoOptions(title: 'Two'));
      await _wait(tester, 100);
      c.show(const SileoOptions(title: 'Three'));
      await _wait(tester, 100);
      expect(find.text('One'), findsNothing);
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('Three'), findsOneWidget);
      await _wait(tester, 600);
      expect(find.text('Two'), findsNothing);
      await end(tester);
    });
  });

  group('tap and hover', () {
    testWidgets('tap toggles expand and pauses / resumes dismissal', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_desc(autopilot: SileoAutopilot.off));
      await _wait(tester, 1000);
      expect(_body(tester), 0);

      await tester.tapAt(_pill(tester).center);
      await _wait(tester, 1500);
      expect(_body(tester), closeTo(52, 0.5), reason: 'tap expands');

      // Paused: well past the 6 s default, the toast is still live.
      await _wait(tester, 7000);
      expect(c.items.single.exiting, isFalse);

      await tester.tapAt(_pill(tester).center);
      await _wait(tester, 1500);
      expect(_body(tester), lessThan(0.5), reason: 'second tap collapses');
      // Resume reschedules the FULL 6 s.
      await _wait(tester, 4400); // 5.9 s after resume
      expect(c.items.single.exiting, isFalse);
      await _wait(tester, 200); // 6.1 s
      expect(c.items.single.exiting, isTrue);
      await _wait(tester, 700);
      expect(c.items, isEmpty);
      await end(tester);
    });

    testWidgets('mouse hover does the same: expand + pause, exit resumes', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_desc(autopilot: SileoAutopilot.off));
      await _wait(tester, 1000);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(5, 500));
      addTearDown(mouse.removePointer);

      await mouse.moveTo(_pill(tester).center);
      await _wait(tester, 1500);
      expect(_body(tester), closeTo(52, 0.5));
      await _wait(tester, 7000);
      expect(c.items.single.exiting, isFalse, reason: 'hover pauses');

      await mouse.moveTo(const Offset(5, 500));
      await _wait(tester, 1500);
      expect(_body(tester), lessThan(0.5), reason: 'exit collapses');
      await _wait(tester, 4400); // 5.9 s after resume
      expect(c.items.single.exiting, isFalse);
      await _wait(tester, 200); // 6.1 s
      expect(c.items.single.exiting, isTrue);
      await _wait(tester, 700);
      await end(tester);
    });
  });

  group('swipe', () {
    SileoItem item() => c.items.single;

    for (final dir in [1.0, -1.0]) {
      final label = dir > 0 ? 'down' : 'up';
      // Mutation: threshold <= 30 / >= 29, or sign ignored.
      testWidgets('swipe $label 29 dp snaps back, no dismiss', (tester) async {
        await _host(tester, c);
        c.show(const SileoOptions(title: 'Swipe', persistent: true));
        await _wait(tester, 1000);
        final rest = _box(tester).top;
        await tester.dragFrom(_pill(tester).center, Offset(0, 29 * dir));
        await _wait(tester, 1500);
        expect(item().exiting, isFalse);
        expect(_box(tester).top, closeTo(rest, 0.2), reason: 'springs back');
        await end(tester);
      });

      testWidgets('swipe $label 31 dp dismisses', (tester) async {
        await _host(tester, c);
        c.show(const SileoOptions(title: 'Swipe', persistent: true));
        await _wait(tester, 1000);
        await tester.dragFrom(_pill(tester).center, Offset(0, 31 * dir));
        await _wait(tester, 10);
        expect(item().exiting, isTrue);
        await _wait(tester, 700);
        expect(c.items, isEmpty);
        await end(tester);
      });
    }

    // Mutation: swipeMax clamp removed -> follows the finger to 40.
    testWidgets('the toast follows the finger clamped to 20 dp', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(const SileoOptions(title: 'Swipe', persistent: true));
      await _wait(tester, 1000);
      final rest = _box(tester).top;
      final g = await tester.startGesture(_pill(tester).center);
      await g.moveBy(const Offset(0, 25));
      await g.moveBy(const Offset(0, 60));
      await tester.pump();
      expect(_box(tester).top - rest, closeTo(20, 0.01));
      await g.up();
      await _wait(tester, 10);
      await end(tester);
    });

    testWidgets('a swipe that starts on the button is ignored', (tester) async {
      var pressed = 0;
      await _host(tester, c);
      c.show(
        _desc(
          button: SileoButton(title: 'Undo', onPressed: () => pressed++),
        ),
      );
      await _wait(tester, 1500);
      await tester.dragFrom(
        tester.getCenter(find.text('Undo')),
        const Offset(0, 80),
      );
      await _wait(tester, 100);
      expect(c.items.single.exiting, isFalse);
      expect(pressed, 0);
      await end(tester);
    });
  });

  group('button', () {
    Future<int Function()> open(WidgetTester tester) async {
      var pressed = 0;
      await _host(tester, c);
      c.show(
        _desc(
          button: SileoButton(title: 'Undo', onPressed: () => pressed++),
        ),
      );
      await _wait(tester, 1500);
      return () => pressed;
    }

    Rect pillRect(WidgetTester t) => t.getRect(
      find.ancestor(
        of: find.text('Undo'),
        matching: find.byType(AnimatedContainer),
      ),
    );

    // Mutation: tap bubbles to the toast and toggles it (collapses).
    testWidgets('fires onPressed and does not toggle the toast', (
      tester,
    ) async {
      final pressed = await open(tester);
      await tester.tap(find.text('Undo'));
      await _wait(tester, 1500);
      expect(pressed(), 1);
      expect(_body(tester), greaterThan(60), reason: 'still expanded');
      await end(tester);
    });

    testWidgets('visual pill is 28 dp tall', (tester) async {
      await open(tester);
      expect(pillRect(tester).height, closeTo(28, 0.01));
      await end(tester);
    });

    // Mutation: hit box shrinks to the 28 dp pill (or grows past 48).
    testWidgets('hit box spans 48 dp: taps 9 dp off the pill fire', (
      tester,
    ) async {
      final pressed = await open(tester);
      final r = pillRect(tester);
      await tester.tapAt(Offset(r.center.dx, r.top - 9));
      expect(pressed(), 1, reason: 'top edge');
      await tester.tapAt(Offset(r.center.dx, r.bottom + 9));
      expect(pressed(), 2, reason: 'bottom edge');
      await end(tester);
    });

    testWidgets('taps 11 dp off the pill do not fire', (tester) async {
      final pressed = await open(tester);
      final r = pillRect(tester);
      await tester.tapAt(Offset(r.center.dx, r.top - 11));
      await tester.tapAt(Offset(r.center.dx, r.bottom + 11));
      expect(pressed(), 0);
      await end(tester);
    });
  });

  group('tap target guidelines', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('collapsed and expanded toasts pass on $platform', (
        tester,
      ) async {
        handle = tester.ensureSemantics();
        tester.view
          ..physicalSize = const Size(400, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) =>
                SileoToaster(controller: c, child: child!),
            home: const SizedBox.expand(),
          ),
        );
        c.show(
          _desc(
            autopilot: SileoAutopilot.off,
            button: SileoButton(title: 'Undo', onPressed: () {}),
          ),
        );
        await _wait(tester, 1000);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        await tester.tapAt(_pill(tester).center);
        await _wait(tester, 1500);
        expect(_body(tester), greaterThan(50));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await end(tester);
      });
    }
  });

  group('semantics', () {
    SemanticsNode node(WidgetTester t, Pattern label) =>
        t.getSemantics(find.bySemanticsLabel(label));

    testWidgets('liveRegion container is labeled with the title', (
      tester,
    ) async {
      handle = tester.ensureSemantics();
      await _host(tester, c);
      c.show(const SileoOptions(title: 'Saved'));
      await _wait(tester, 1000);
      final data = node(tester, 'Saved').getSemanticsData();
      expect(data.label, 'Saved');
      expect(data.flagsCollection.isLiveRegion, isTrue);
      await end(tester);
    });

    testWidgets('a String description joins the label', (tester) async {
      handle = tester.ensureSemantics();
      await _host(tester, c);
      c.show(
        const SileoOptions(
          title: 'Saved',
          description: Text('Body text', style: TextStyle(fontSize: 14)),
        ),
      );
      await _wait(tester, 1000);
      final n = node(tester, RegExp('Saved'));
      expect(n.label, allOf(startsWith('Saved'), contains('Body text')));
      await end(tester);
    });

    testWidgets('the button is its own node, not merged into the container', (
      tester,
    ) async {
      handle = tester.ensureSemantics();
      await _host(tester, c);
      c.show(
        SileoOptions(
          title: 'Saved',
          description: const SizedBox(height: 10),
          button: SileoButton(title: 'Undo', onPressed: () {}),
        ),
      );
      await _wait(tester, 1500);
      final container = node(tester, RegExp('^Saved'));
      final button = node(tester, 'Undo');
      expect(button.id, isNot(container.id));
      expect(container.label, isNot(contains('Undo')));
      final bd = button.getSemanticsData();
      expect(bd.label, 'Undo');
      expect(bd.flagsCollection.isButton, isTrue);
      expect(bd.hasAction(SemanticsAction.tap), isTrue);
      expect(
        container.getSemanticsData().flagsCollection.isButton,
        isFalse,
        reason: 'container itself is not a button',
      );
      await end(tester);
    });

    // Mutation: onDismiss not wired -> action missing / does nothing.
    testWidgets('the dismiss action dismisses the toast', (tester) async {
      handle = tester.ensureSemantics();
      await _host(tester, c);
      c.show(const SileoOptions(title: 'Saved', persistent: true));
      await _wait(tester, 1000);
      final n = node(tester, 'Saved');
      expect(n.getSemanticsData().hasAction(SemanticsAction.dismiss), isTrue);
      tester.semantics.performAction(
        find.semantics.byLabel('Saved'),
        SemanticsAction.dismiss,
      );
      await _wait(tester, 10);
      expect(c.items.single.exiting, isTrue);
      await _wait(tester, 700);
      expect(c.items, isEmpty);
      await end(tester);
    });

    testWidgets('the tap action toggles expansion', (tester) async {
      handle = tester.ensureSemantics();
      await _host(tester, c);
      c.show(_desc(autopilot: SileoAutopilot.off));
      await _wait(tester, 1000);
      final n = node(tester, RegExp('^Saved'));
      expect(n.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.performAction(
        find.semantics.byLabel(RegExp('^Saved')),
        SemanticsAction.tap,
      );
      await _wait(tester, 1500);
      expect(_body(tester), closeTo(52, 0.5));
      await end(tester);
    });

    testWidgets('a toast without content offers no tap action', (tester) async {
      handle = tester.ensureSemantics();
      await _host(tester, c);
      c.show(const SileoOptions(title: 'Saved'));
      await _wait(tester, 1000);
      expect(
        node(tester, 'Saved').getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      await end(tester);
    });
  });

  group('accessibility settings', () {
    // Spec: accessible navigation + persistWhenAccessibleNavigation ->
    // autopilot expands with no collapse (and no auto-dismiss).
    testWidgets('accessible navigation: expands and never collapses', (
      tester,
    ) async {
      await _host(tester, c, accessible: true);
      c.show(_desc());
      await _wait(tester, 1500);
      expect(_body(tester), closeTo(52, 0.5));
      await _wait(tester, 4000); // t = 5.5 s, collapse would be at 4.15 s
      expect(_body(tester), closeTo(52, 0.5), reason: 'no collapse');
      await end(tester);
    });

    testWidgets('persistWhenAccessibleNavigation false: collapses as usual', (
      tester,
    ) async {
      await _host(tester, c, accessible: true, persistA11y: false);
      c.show(_desc());
      await _wait(tester, 1500);
      await _wait(tester, 3500);
      await _wait(tester, 1500);
      expect(_body(tester), lessThan(0.5));
      await end(tester);
    });

    testWidgets('accessible navigation: no auto-dismiss', (tester) async {
      await _host(tester, c, accessible: true);
      c.show(_desc());
      await _wait(tester, 7000);
      expect(c.items, hasLength(1));
      expect(c.items.single.exiting, isFalse);
      await end(tester);
    });

    testWidgets('persistWhenAccessibleNavigation false: still dismisses', (
      tester,
    ) async {
      await _host(tester, c, accessible: true, persistA11y: false);
      c.show(_desc());
      await _wait(tester, 7000);
      expect(c.items, isEmpty);
      await end(tester);
    });

    // Spec §10: a screen reader turning on mid-toast creates no new timers,
    // the running one still dismisses.
    testWidgets('accessible navigation turning on mid-toast keeps the timer', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_desc());
      await _wait(tester, 3000);
      await _host(tester, c, accessible: true);
      await _wait(tester, 4000);
      expect(c.items, isEmpty);
      await end(tester);
    });

    // Mutation: springs still animate under reduce motion.
    testWidgets('reduce motion: no animation in flight after one pump', (
      tester,
    ) async {
      await _host(tester, c, noAnimations: true);
      c.show(_desc());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.binding.transientCallbackCount, 0);
      expect(_body(tester), closeTo(52, 0.5), reason: 'jumped to the end');
      await end(tester);
    });

    testWidgets('control: with animations the expand is still in flight', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_desc());
      await _wait(tester, 250); // expand fired at 150 ms, spring mid-flight
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      expect(_body(tester), allOf(greaterThan(0), lessThan(52)));
      await end(tester);
    });

    testWidgets('reduce motion: collapse also jumps', (tester) async {
      await _host(tester, c, noAnimations: true);
      c.show(_desc());
      await _wait(tester, 200);
      expect(_body(tester), closeTo(52, 0.5));
      await _wait(tester, 4000);
      expect(tester.binding.transientCallbackCount, 0);
      expect(_body(tester), lessThan(0.5));
      await end(tester);
    });
  });

  group('header blur', () {
    // Plan AC: ImageFiltered only while a header transition runs.
    testWidgets('steady state has no ImageFiltered; a morph adds it', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_desc(autopilot: SileoAutopilot.off));
      await _wait(tester, 1500);
      expect(find.byType(ImageFiltered), findsNothing);
      c.show(_desc(title: 'Other', autopilot: SileoAutopilot.off));
      await _wait(tester, 100);
      expect(find.byType(ImageFiltered), findsWidgets);
      await _wait(tester, 1500);
      expect(find.byType(ImageFiltered), findsNothing);
      await end(tester);
    });
  });

  group('content semantics and keyboard', () {
    const column = Column(children: [Text('First line'), Text('Second line')]);

    testWidgets('a non-Text description is readable only when open', (
      tester,
    ) async {
      handle = tester.ensureSemantics();
      await _host(tester, c);
      c.show(_desc(description: column, autopilot: SileoAutopilot.off));
      await _wait(tester, 1000);
      expect(find.bySemanticsLabel(RegExp('Second line')), findsNothing);
      tester.semantics.performAction(
        find.semantics.byLabel(RegExp('^Saved')),
        SemanticsAction.tap,
      );
      await _wait(tester, 1500);
      expect(find.bySemanticsLabel(RegExp('First line')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Second line')), findsOneWidget);
      await end(tester);
    });

    testWidgets('expanded flag follows open, only with content', (
      tester,
    ) async {
      handle = tester.ensureSemantics();
      await _host(tester, c);
      c.show(_desc(autopilot: SileoAutopilot.off));
      await _wait(tester, 1000);
      Tristate expanded() => tester
          .getSemantics(find.bySemanticsLabel(RegExp('^Saved')))
          .getSemanticsData()
          .flagsCollection
          .isExpanded;
      expect(expanded(), Tristate.isFalse);
      tester.semantics.performAction(
        find.semantics.byLabel(RegExp('^Saved')),
        SemanticsAction.tap,
      );
      await _wait(tester, 1500);
      expect(expanded(), Tristate.isTrue);
      c.show(const SileoOptions(title: 'Plain'));
      await _wait(tester, 1500);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Plain'))
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        Tristate.none,
      );
      await end(tester);
    });

    Future<int Function()> openButton(WidgetTester tester) async {
      var pressed = 0;
      await _host(tester, c);
      c.show(
        _desc(
          button: SileoButton(title: 'Undo', onPressed: () => pressed++),
        ),
      );
      await _wait(tester, 1500);
      Focus.of(tester.element(find.text('Undo'))).requestFocus();
      await tester.pump();
      return () => pressed;
    }

    for (final key in [
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.numpadEnter,
    ]) {
      testWidgets('focused button fires on ${key.keyLabel}', (tester) async {
        final pressed = await openButton(tester);
        await tester.sendKeyEvent(key);
        expect(pressed(), 1);
        await end(tester);
      });
    }

    testWidgets('other keys do not fire the button', (tester) async {
      final pressed = await openButton(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      expect(pressed(), 0);
      await end(tester);
    });

    testWidgets('focus shows a tone ring, blur removes it', (tester) async {
      await openButton(tester);
      double ring() =>
          ((tester
                              .widget<AnimatedContainer>(
                                find.ancestor(
                                  of: find.text('Undo'),
                                  matching: find.byType(AnimatedContainer),
                                ),
                              )
                              .decoration!
                          as ShapeDecoration)
                      .shape
                  as StadiumBorder)
              .side
              .width;
      await tester.pump(const Duration(milliseconds: 300));
      expect(ring(), 2);
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump(const Duration(milliseconds: 300));
      expect(ring(), 0);
      await end(tester);
    });
  });

  group('text scale and narrow width', () {
    SileoOptions rich() => SileoOptions(
      title: 'A fairly long toast title',
      description: const Text(
        'A description long enough to wrap over several lines inside.',
      ),
      button: SileoButton(title: 'Undo it', onPressed: () {}),
    );

    // Mutation: fixed 40 header, or clipped rows -> overflow exception.
    testWidgets('2.0 text scale: header grows to 48, no overflow', (
      tester,
    ) async {
      await _host(tester, c, scaler: const TextScaler.linear(2));
      c.show(rich());
      await _wait(tester, 1500);
      expect(_shape(tester).headerHeight, closeTo(48, 0.01));
      expect(_pill(tester).height, closeTo(48, 0.01));
      expect(_body(tester), greaterThan(48));
      expect(tester.takeException(), isNull);
      await end(tester);
    });

    testWidgets('1.0 text scale keeps the 40 dp header', (tester) async {
      await _host(tester, c);
      c.show(rich());
      await _wait(tester, 1500);
      expect(_shape(tester).headerHeight, closeTo(40, 0.01));
      await end(tester);
    });

    // Toast width = min(350, 320 - 24) = 296.
    testWidgets('320 dp width: toast is 296 wide, no overflow', (tester) async {
      await _host(tester, c, size: const Size(320, 640));
      c.show(rich());
      await _wait(tester, 1500);
      expect(_box(tester).width, closeTo(296, 0.01));
      expect(_box(tester).right, closeTo(320 - 12, 0.01));
      expect(tester.takeException(), isNull);
      await end(tester);
    });

    testWidgets('320 dp and 2.0 scale together: no overflow', (tester) async {
      await _host(
        tester,
        c,
        size: const Size(320, 640),
        scaler: const TextScaler.linear(2),
      );
      c.show(rich());
      await _wait(tester, 1500);
      expect(tester.takeException(), isNull);
      expect(_body(tester), greaterThan(48));
      await end(tester);
    });
  });

  group('lifecycle', () {
    // Mutation: view timers not cancelled in dispose -> pending timer / setState
    // after dispose error (testWidgets fails on pending timers).
    testWidgets('removing the host with live view timers is clean', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_desc());
      await _wait(tester, 50); // expand + collapse timers still pending
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await _wait(tester, 5000);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unmounted toast mid-morph does not throw', (tester) async {
      await _host(tester, c);
      c.show(const SileoOptions(title: 'One', description: Text('x')));
      await _wait(tester, 1500);
      c.show(const SileoOptions(title: 'Two', description: Text('x')));
      await _wait(tester, 100); // swap timer pending
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await _wait(tester, 1000);
      expect(tester.takeException(), isNull);
    });
  });
}
