// Spec: plan §7.1 SileoToaster, Layout, "Text above the Navigator";
// §9 "Layout and toast view", "Theme and constants", controller ownership;
// §10 host disposed with a pending promise.
//
// Hand-computed: viewport 400 x 800, safe padding L10 T44 R20 B34, offset
// L5 T6 R7 B8. Pill edges: left 10+5+12 = 27, right 400-(20+7+12) = 361,
// top 44+6+12 = 62, bottom 800-(34+8+12) = 746. Toast width =
// min(350, 400-(27+39)) = 334; centered pill midpoint (27+361)/2 = 194.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sileo_toast/sileo_toast.dart';
import 'package:sileo_toast/src/sileo_shape_painter.dart';

Future<void> _wait(WidgetTester t, int ms) async {
  var left = ms;
  while (left > 0) {
    final step = left < 20 ? left : 20;
    await t.pump(Duration(milliseconds: step));
    left -= step;
  }
}

Future<void> _host(
  WidgetTester tester, {
  SileoController? controller,
  Size size = const Size(400, 800),
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets? offset,
  SileoPosition position = SileoPosition.topRight,
  SileoThemeMode? theme,
  SileoOptions? options,
  Brightness brightness = Brightness.light,
  TextDirection direction = TextDirection.ltr,
  Widget child = const SizedBox.expand(),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: padding,
        platformBrightness: brightness,
      ),
      child: Directionality(
        textDirection: direction,
        child: SileoToaster(
          controller: controller,
          position: position,
          offset: offset,
          theme: theme,
          options: options,
          child: child,
        ),
      ),
    ),
  );
}

Finder get _painters => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is SileoShapePainter,
);

Finder _painterOf(String id) =>
    find.descendant(of: find.byKey(ValueKey(id)), matching: _painters);

SileoShapePainter _shape(WidgetTester t, [String? id]) =>
    t.widget<CustomPaint>(id == null ? _painters : _painterOf(id)).painter!
        as SileoShapePainter;

Rect _pill(WidgetTester t, {String? id, bool top = true}) {
  final box = t.getRect(id == null ? _painters : _painterOf(id));
  final s = _shape(t, id);
  return Rect.fromLTWH(
    box.left + s.pillX.value,
    top ? box.top + 4 : box.bottom - 4 - s.headerHeight,
    s.pillWidth.value,
    s.headerHeight,
  );
}

TextStyle _styleOf(WidgetTester t, String text) =>
    t.renderObject<RenderParagraph>(find.text(text)).text.style!;

void main() {
  late SileoController c;
  setUp(() => c = SileoController());
  tearDown(() => c.dispose());

  Future<void> end(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    c.dispose();
  }

  group('viewport positions', () {
    const padding = EdgeInsets.fromLTRB(10, 44, 20, 34);
    const offset = EdgeInsets.fromLTRB(5, 6, 7, 8);

    final cases = <SileoPosition, (double?, double?, double?, double?)>{
      // (left, right, top, bottom) edge of the visible pill, null = n/a.
      SileoPosition.topLeft: (27, null, 62, null),
      SileoPosition.topRight: (null, 361, 62, null),
      SileoPosition.bottomLeft: (27, null, null, 746),
      SileoPosition.bottomRight: (null, 361, null, 746),
    };

    for (final e in cases.entries) {
      // Mutation: safe area, 12 padding or offset dropped for any edge.
      testWidgets('${e.key.name} sits at safe area + 12 + offset', (
        tester,
      ) async {
        await _host(
          tester,
          controller: c,
          padding: padding,
          offset: offset,
          position: e.key,
        );
        c.show(const SileoOptions(title: 'Hi'));
        await _wait(tester, 1000);
        final r = _pill(tester, top: e.key.isTop);
        final (l, rt, t, b) = e.value;
        if (l != null) expect(r.left, closeTo(l, 0.01));
        if (rt != null) expect(r.right, closeTo(rt, 0.01));
        if (t != null) expect(r.top, closeTo(t, 0.01));
        if (b != null) expect(r.bottom, closeTo(b, 0.01));
        await end(tester);
      });
    }

    for (final top in [true, false]) {
      testWidgets('${top ? 'top' : 'bottom'}Center is centered between the '
          'insets', (tester) async {
        await _host(
          tester,
          controller: c,
          padding: padding,
          offset: offset,
          position: top ? SileoPosition.topCenter : SileoPosition.bottomCenter,
        );
        c.show(const SileoOptions(title: 'Hi'));
        await _wait(tester, 1000);
        final r = _pill(tester, top: top);
        expect(r.center.dx, closeTo(194, 0.01));
        expect(top ? r.top : r.bottom, closeTo(top ? 62 : 746, 0.01));
        await end(tester);
      });
    }

    // Mutation: positions mirrored for RTL.
    testWidgets('positions are physical: topLeft stays left in RTL', (
      tester,
    ) async {
      await _host(
        tester,
        controller: c,
        position: SileoPosition.topLeft,
        direction: TextDirection.rtl,
      );
      c.show(const SileoOptions(title: 'Hi'));
      await _wait(tester, 1000);
      expect(_pill(tester).left, closeTo(12, 0.01));
      await end(tester);
    });

    testWidgets('toast width is min(350, available - 24)', (tester) async {
      await _host(tester, controller: c);
      c.show(const SileoOptions(title: 'Hi'));
      await _wait(tester, 1000);
      expect(tester.getSize(_painters).width, 350);
      await _host(tester, controller: c, size: const Size(300, 800));
      await _wait(tester, 100);
      expect(tester.getSize(_painters).width, closeTo(276, 0.01));
      await end(tester);
    });

    testWidgets('positions are independent viewports', (tester) async {
      await _host(tester, controller: c);
      c
        ..show(const SileoOptions(title: 'A', id: 'a'))
        ..show(
          const SileoOptions(
            title: 'B',
            id: 'b',
            position: SileoPosition.bottomLeft,
          ),
        );
      await _wait(tester, 1000);
      expect(_pill(tester, id: 'a').top, closeTo(12, 0.01));
      expect(_pill(tester, id: 'a').right, closeTo(388, 0.01));
      expect(_pill(tester, id: 'b', top: false).bottom, closeTo(788, 0.01));
      expect(_pill(tester, id: 'b', top: false).left, closeTo(12, 0.01));
      await end(tester);
    });
  });

  group('stack order', () {
    // Visual gap is 12 between pills (40 + 12 = 52 apart), on both edges.
    // Mutation: order not reversed for top; gap not compensated for the
    // 4 dp tap extensions.
    testWidgets('top: newest first, 12 dp apart', (tester) async {
      await _host(tester, controller: c);
      c
        ..show(const SileoOptions(title: 'A', id: 'a'))
        ..show(const SileoOptions(title: 'B', id: 'b'));
      await _wait(tester, 1000);
      expect(_pill(tester, id: 'b').top, closeTo(12, 0.01));
      expect(_pill(tester, id: 'a').top, closeTo(12 + 40 + 12, 0.01));
      await end(tester);
    });

    testWidgets('bottom: newest last, 12 dp apart', (tester) async {
      await _host(tester, controller: c, position: SileoPosition.bottomRight);
      c
        ..show(const SileoOptions(title: 'A', id: 'a'))
        ..show(const SileoOptions(title: 'B', id: 'b'));
      await _wait(tester, 1000);
      expect(_pill(tester, id: 'b', top: false).bottom, closeTo(788, 0.01));
      expect(
        _pill(tester, id: 'a', top: false).bottom,
        closeTo(788 - 40 - 12, 0.01),
      );
      await end(tester);
    });

    testWidgets('three toasts keep the order', (tester) async {
      await _host(tester, controller: c);
      c
        ..show(const SileoOptions(title: 'A', id: 'a'))
        ..show(const SileoOptions(title: 'B', id: 'b'))
        ..show(const SileoOptions(title: 'C', id: 'c'));
      await _wait(tester, 1000);
      final ys = [
        for (final id in ['c', 'b', 'a']) _pill(tester, id: id).top,
      ];
      expect(ys[0], lessThan(ys[1]));
      expect(ys[1], lessThan(ys[2]));
      await end(tester);
    });

    testWidgets('same id replaces in place: still one toast', (tester) async {
      await _host(tester, controller: c);
      c
        ..show(const SileoOptions(title: 'A'))
        ..show(const SileoOptions(title: 'B'));
      await _wait(tester, 1000);
      expect(_painters, findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      await end(tester);
    });

    testWidgets('a removed toast leaves no viewport; none renders child only', (
      tester,
    ) async {
      await _host(tester, controller: c);
      expect(_painters, findsNothing);
      c.show(const SileoOptions(title: 'A', duration: Duration(seconds: 1)));
      await _wait(tester, 500);
      expect(_painters, findsOneWidget);
      await _wait(tester, 1500);
      expect(_painters, findsNothing);
      await end(tester);
    });
  });

  group('scope and controller ownership', () {
    testWidgets('Sileo.of / maybeOf resolve the passed controller', (
      tester,
    ) async {
      SileoController? seen;
      SileoController? maybe;
      await _host(
        tester,
        controller: c,
        child: Builder(
          builder: (context) {
            seen = Sileo.of(context);
            maybe = Sileo.maybeOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(seen, same(c));
      expect(maybe, same(c));
      await end(tester);
    });

    testWidgets('maybeOf is null and of asserts without a toaster', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      );
      expect(Sileo.maybeOf(ctx), isNull);
      expect(() => Sileo.of(ctx), throwsAssertionError);
      await end(tester);
    });

    // Mutation: host disposes a controller it does not own.
    testWidgets('a passed controller survives the host', (tester) async {
      await _host(tester, controller: c);
      await tester.pumpWidget(const SizedBox());
      c.show(const SileoOptions(title: 'After'));
      expect(c.items, hasLength(1));
      c.dispose();
    });

    // Mutation: host never disposes the controller it created.
    testWidgets('an owned controller is disposed with the host', (
      tester,
    ) async {
      late SileoController owned;
      await _host(
        tester,
        child: Builder(
          builder: (context) {
            owned = Sileo.of(context);
            return const SizedBox();
          },
        ),
      );
      owned.show(const SileoOptions(title: 'Live', id: 'a'));
      await _wait(tester, 100);
      expect(_painters, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      final before = owned.items.length;
      owned.show(const SileoOptions(title: 'Late', id: 'b'));
      expect(owned.items.length, before, reason: 'dispose makes show a no-op');
    });

    testWidgets('toaster position and options become controller defaults', (
      tester,
    ) async {
      await _host(
        tester,
        controller: c,
        position: SileoPosition.bottomLeft,
        options: const SileoOptions(title: 'Default title'),
      );
      expect(c.defaultPosition, SileoPosition.bottomLeft);
      c.show(const SileoOptions(id: 'x'));
      expect(c.items.single.position, SileoPosition.bottomLeft);
      expect(c.items.single.options.title, 'Default title');
      await _wait(tester, 500);
      expect(find.text('Default title'), findsOneWidget);
      await end(tester);
    });
  });

  group('theme fills', () {
    Future<Color> fillOf(
      WidgetTester tester, {
      SileoThemeMode? theme,
      Brightness b = Brightness.light,
      Color? override,
    }) async {
      await _host(tester, controller: c, theme: theme, brightness: b);
      c.show(SileoOptions(title: 'Hi', fill: override));
      await _wait(tester, 500);
      final fill = _shape(tester).fill;
      c.clear();
      await _wait(tester, 800);
      return fill;
    }

    // Mutation: light/dark swapped (the toast is inverted on purpose).
    testWidgets('light -> #1A1A1A, dark -> #F2F2F2, none -> #FFFFFF', (
      tester,
    ) async {
      expect(
        await fillOf(tester, theme: SileoThemeMode.light),
        const Color(0xFF1A1A1A),
      );
      expect(
        await fillOf(tester, theme: SileoThemeMode.dark),
        const Color(0xFFF2F2F2),
      );
      expect(await fillOf(tester), const Color(0xFFFFFFFF));
      await end(tester);
    });

    testWidgets('system follows the platform brightness', (tester) async {
      expect(
        await fillOf(tester, theme: SileoThemeMode.system, b: Brightness.dark),
        const Color(0xFFF2F2F2),
      );
      await end(tester);
    });

    testWidgets('a per-toast fill wins over the theme', (tester) async {
      expect(
        await fillOf(
          tester,
          theme: SileoThemeMode.light,
          override: const Color(0xFF123456),
        ),
        const Color(0xFF123456),
      );
      await end(tester);
    });
  });

  group('pointer pass-through', () {
    // Mutation: the host's full-screen layer swallows taps.
    testWidgets('taps on empty space reach the app below', (tester) async {
      var taps = 0;
      await _host(
        tester,
        controller: c,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const SizedBox.expand(),
        ),
      );
      c.show(const SileoOptions(title: 'Hi', persistent: true));
      await _wait(tester, 1000);
      await tester.tapAt(const Offset(200, 500));
      expect(taps, 1);
      await tester.tapAt(const Offset(30, 30)); // empty left of the pill
      expect(taps, 2);
      await end(tester);
    });

    testWidgets('a tap on the toast does not reach the app below', (
      tester,
    ) async {
      var taps = 0;
      await _host(
        tester,
        controller: c,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const SizedBox.expand(),
        ),
      );
      c.show(const SileoOptions(title: 'Hi', persistent: true));
      await _wait(tester, 1000);
      await tester.tapAt(_pill(tester).center);
      expect(taps, 0);
      await end(tester);
    });
  });

  group('host disposed', () {
    // Spec §10: pending promise, no notify after dispose, no throw.
    testWidgets('host removed mid-promise: settling does not throw', (
      tester,
    ) async {
      late SileoController owned;
      await _host(
        tester,
        child: Builder(
          builder: (context) {
            owned = Sileo.of(context);
            return const SizedBox();
          },
        ),
      );
      final completer = Completer<int>();
      final result = owned.promise<int>(
        completer.future,
        SileoPromiseOptions<int>(
          loading: const SileoOptions(title: 'Loading'),
          success: (d) => SileoOptions(title: 'Done $d'),
          error: (e) => SileoOptions(title: 'Failed $e'),
        ),
      );
      await _wait(tester, 100);
      expect(find.text('Loading'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      completer.complete(7);
      expect(await result, 7);
      await _wait(tester, 100);
      expect(tester.takeException(), isNull);
    });

    testWidgets('host removed mid-promise: failure still reaches the caller', (
      tester,
    ) async {
      late SileoController owned;
      await _host(
        tester,
        child: Builder(
          builder: (context) {
            owned = Sileo.of(context);
            return const SizedBox();
          },
        ),
      );
      final completer = Completer<int>();
      final result = owned.promise<int>(
        completer.future,
        SileoPromiseOptions<int>(
          loading: const SileoOptions(title: 'Loading'),
          success: (d) => const SileoOptions(),
          error: (e) => const SileoOptions(title: 'Failed'),
        ),
      );
      final expectation = expectLater(result, throwsA('boom'));
      await tester.pumpWidget(const SizedBox());
      completer.completeError('boom');
      await expectation;
      expect(tester.takeException(), isNull);
    });

    testWidgets('promise morphs the same toast loading -> success', (
      tester,
    ) async {
      await _host(tester, controller: c);
      final completer = Completer<int>();
      unawaited(
        c.promise<int>(
          completer.future,
          SileoPromiseOptions<int>(
            loading: const SileoOptions(title: 'Loading'),
            success: (d) => SileoOptions(title: 'Done $d'),
            error: (e) => const SileoOptions(title: 'Failed'),
          ),
        ),
      );
      await _wait(tester, 800);
      expect(find.text('Loading'), findsOneWidget);
      completer.complete(3);
      await _wait(tester, 1000);
      expect(find.text('Done 3'), findsOneWidget);
      expect(_painters, findsOneWidget);
      await end(tester);
    });
  });

  group('text above the Navigator (MaterialApp.builder)', () {
    const family = 'SileoTestFamily';
    const base = TextStyle(
      fontFamily: family,
      color: Color(0xFF123456),
      fontSize: 15,
    );

    Future<void> app(
      WidgetTester tester, {
      SileoThemeMode? theme,
      TextStyle? textStyle = base,
    }) async {
      tester.view
        ..physicalSize = const Size(400, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder:
              (context, child) => SileoToaster(
                controller: c,
                theme: theme,
                textStyle: textStyle,
                child: Stack(
                  children: [
                    child!,
                    const Positioned(bottom: 300, child: Text('control')),
                  ],
                ),
              ),
          home: const SizedBox.expand(),
        ),
      );
    }

    // Mutation: toast text not wrapped in its own DefaultTextStyle ->
    // MaterialApp's error style (yellow double underline) leaks in.
    testWidgets('title, description and button have no decoration', (
      tester,
    ) async {
      await app(tester);
      c.show(
        SileoOptions(
          title: 'Saved',
          description: const Text('Body'),
          button: SileoButton(title: 'Undo', onPressed: () {}),
        ),
      );
      await _wait(tester, 1500);
      expect(
        _styleOf(tester, 'control').decoration,
        isNot(TextDecoration.none),
      );
      for (final t in ['Saved', 'Body', 'Undo']) {
        expect(_styleOf(tester, t).decoration, TextDecoration.none, reason: t);
      }
      await end(tester);
    });

    testWidgets('all toast text uses the textStyle family', (tester) async {
      await app(tester);
      c.show(
        SileoOptions(
          title: 'Saved',
          description: const Text('Body'),
          button: SileoButton(title: 'Undo', onPressed: () {}),
        ),
      );
      await _wait(tester, 1500);
      for (final t in ['Saved', 'Body', 'Undo']) {
        expect(_styleOf(tester, t).fontFamily, family, reason: t);
      }
      await end(tester);
    });

    testWidgets('without textStyle a neutral style is used, no decoration', (
      tester,
    ) async {
      await app(tester, textStyle: null);
      c.show(const SileoOptions(title: 'Saved', description: Text('Body')));
      await _wait(tester, 1500);
      expect(_styleOf(tester, 'Saved').decoration, TextDecoration.none);
      expect(_styleOf(tester, 'Body').decoration, TextDecoration.none);
      await end(tester);
    });

    // Mutation: theme description color ignored / textStyle color ignored.
    testWidgets('description color: theme light gives white 50%', (
      tester,
    ) async {
      await app(tester, theme: SileoThemeMode.light);
      c.show(const SileoOptions(title: 'Saved', description: Text('Body')));
      await _wait(tester, 1500);
      final color = _styleOf(tester, 'Body').color!;
      expect(color.toARGB32() & 0xFFFFFF, 0xFFFFFF);
      expect(color.a, closeTo(0.5, 0.01));
      await end(tester);
    });

    testWidgets('description color: no theme inherits the textStyle color', (
      tester,
    ) async {
      await app(tester);
      c.show(const SileoOptions(title: 'Saved', description: Text('Body')));
      await _wait(tester, 1500);
      expect(_styleOf(tester, 'Body').color, const Color(0xFF123456));
      await end(tester);
    });

    // Spec is inconsistent on the size (IconTheme 14 vs badge icon 16): not
    // asserted, see report.
    // Mutation: IconTheme missing -> custom icon keeps the ambient color.
    for (final e
        in {
          SileoState.success: const Color(0xFF22C55E),
          SileoState.error: const Color(0xFFEF4444),
          SileoState.action: const Color(0xFF3B82F6),
        }.entries) {
      testWidgets('custom Icon takes the ${e.key.name} tone', (tester) async {
        await app(tester);
        c.show(
          SileoOptions(
            title: 'Saved',
            type: e.key,
            icon: const Icon(IconData(0x41, fontFamily: family)),
          ),
        );
        await _wait(tester, 1000);
        final theme = IconTheme.of(tester.element(find.byType(Icon)));
        expect(theme.color, e.value);
        await end(tester);
      });
    }

    testWidgets('title takes the state tone', (tester) async {
      await app(tester);
      c.show(const SileoOptions(title: 'Oops', type: SileoState.error));
      await _wait(tester, 1000);
      expect(_styleOf(tester, 'Oops').color, const Color(0xFFEF4444));
      await end(tester);
    });
  });
}
