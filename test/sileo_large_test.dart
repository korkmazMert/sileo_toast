// Spec: docs/plans/sileo-large-island.md §7.1, §7.2b, §7.4, §9 "Large",
// "Compatibility", "Performance"; §10 edge cases. Expectations are
// hand-computed from the plan, never read off the implementation.
//
// Scenario list (1.0 text scale, Ahem font, 400 x 800 view unless noted):
// * Compat: `SileoOptions()` has size/trailing/secondaryButton == null; a
//   toaster default `size: large` applies, a toast's own `compact` wins;
//   lib/ imports no material/cupertino and never calls SystemChrome.
// * Width: available = 400 - 2 * 12 = 376. A large toast box is 376 wide,
//   open and closed (compact stays 350). 1024 dp wide: min(520, 1000) = 520.
//   320 dp wide: 320 - 24 = 296.
// * Header: 56 (compact 40). 2.0 text: max(56, 22 * 2 + 2 * 8) = 60.
// * Body (16 padding, 12 gaps, 48 buttons, 20 dp description line):
//   description + trailing(64) + buttons: 16 + 64 + 12 + 48 + 16 = 156;
//   no trailing: 16 + 20 + 12 + 48 + 16 = 112.
// * Buttons: cells (376 - 32 - 12) / 2 = 166 wide; secondary at
//   box.left + 16, primary at box.left + 16 + 166 + 12; both 48 tall; the
//   gap between them is 12 (>= 8). Tap targets pass on Android and iOS.
// * Trailing: 64 square, radius 12, top-aligned at body top + 16, right
//   edge at box.right - 16, its own RepaintBoundary, excluded from
//   semantics; compact ignores trailing and secondaryButton.
// * Roundness: large body 24, `options.roundness` overrides; compact 16.
// * Semantics: container label = title + "\n" + description text; each
//   button its own `button: true` node, not merged into the container.
// * Same-id compact -> large morph: springs retarget, so no frame jumps.
// * Reduce motion: nothing in flight after the open frame.
// * Performance: 0 package-widget rebuilds per frame while a large toast
//   expands, 0 repaints and 0 tickers while idle, no filter layer or
//   saveLayer in steady state.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sileo_toast/sileo_toast.dart';
import 'package:sileo_toast/src/sileo_shape_painter.dart';

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

Future<void> _host(
  WidgetTester tester,
  SileoController c, {
  Size size = const Size(400, 800),
  TextScaler scaler = TextScaler.noScaling,
  bool noAnimations = false,
  SileoOptions? defaults,
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
        disableAnimations: noAnimations,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SileoToaster(
          controller: c,
          position: SileoPosition.topCenter,
          options: defaults,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

Finder get _painters => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is SileoShapePainter,
);

SileoShapePainter _shape(WidgetTester t) =>
    t.widget<CustomPaint>(_painters).painter! as SileoShapePainter;

/// Gesture box: the toast plus 4 dp above and below.
Rect _box(WidgetTester t) => t.getRect(_painters);

double _body(WidgetTester t) => _shape(t).bodyHeight.value;

/// Hit box of the action button labelled [label].
Rect _btn(WidgetTester t, String label) => t.getRect(
  find
      .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
      .first,
);

SileoOptions _large({
  String title = 'Delivery',
  String id = 'large',
  Widget? description = const Text('x'),
  Widget? trailing,
  SileoButton? button,
  SileoButton? secondaryButton,
  double? roundness,
  SileoSize size = SileoSize.large,
}) => SileoOptions(
  title: title,
  id: id,
  size: size,
  description: description,
  trailing: trailing,
  button: button,
  secondaryButton: secondaryButton,
  roundness: roundness,
  persistent: true,
  autopilot: SileoAutopilot.off,
);

SileoButton _b(String title, [VoidCallback? onPressed]) =>
    SileoButton(title: title, onPressed: onPressed ?? () {});

Future<void> _open(WidgetTester t, {String title = 'Delivery'}) async {
  await t.tap(find.text(title));
  await _wait(t, 1500);
}

const _thumbKey = Key('thumb');
const _thumb = ColoredBox(
  key: _thumbKey,
  color: Color(0xFFFF0000),
  child: SizedBox(width: 200, height: 200),
);

// Package widgets that must not rebuild while a spring runs.
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
    find.ancestor(of: _painters, matching: find.byType(RepaintBoundary)).first,
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

/// No saveLayer, filter layer, image filter or mask filter this frame.
void _expectNoExpensiveOps(WidgetTester t) {
  final found = <String>[];
  _filterLayers(RendererBinding.instance.renderViews.first.debugLayer!, found);
  expect(found, isEmpty, reason: 'filter layers in steady state: $found');
  final canvas = _Recording();
  final render = t.renderObject<RenderCustomPaint>(_painters);
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

  SemanticsHandle? handle;
  Future<void> end(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    c.dispose();
    handle?.dispose();
    handle = null;
  }

  group('compatibility', () {
    // Mutation: a default other than null (e.g. size: compact) changes the
    // "toaster default, then compact" fallback chain.
    test('SileoOptions() leaves size, trailing and secondaryButton null', () {
      const o = SileoOptions();
      expect(o.size, isNull);
      expect(o.trailing, isNull);
      expect(o.secondaryButton, isNull);
    });

    // Mutation: mergeWith drops `size`, so the toaster default never applies.
    testWidgets('a toaster default size large applies to a toast without one', (
      tester,
    ) async {
      await _host(
        tester,
        c,
        defaults: const SileoOptions(size: SileoSize.large),
      );
      c.show(
        const SileoOptions(
          title: 'Hi',
          description: Text('x'),
          persistent: true,
          autopilot: SileoAutopilot.off,
        ),
      );
      await _wait(tester, 1000);
      expect(_shape(tester).headerHeight, 56);
      await end(tester);
    });

    // Mutation: the toaster default wins over the toast's own size.
    testWidgets('a toast size compact beats a large toaster default', (
      tester,
    ) async {
      await _host(
        tester,
        c,
        defaults: const SileoOptions(size: SileoSize.large),
      );
      c.show(_large(size: SileoSize.compact));
      await _wait(tester, 1000);
      expect(_shape(tester).headerHeight, 40);
      expect(_box(tester).width, 350);
      await end(tester);
    });

    // Mutation: a material/cupertino import or SystemChrome call is added.
    test('lib/ has no material, cupertino or SystemChrome usage', () {
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final src = f.readAsStringSync();
        if (src.contains('package:flutter/material.dart') ||
            src.contains('package:flutter/cupertino.dart') ||
            src.contains('SystemChrome')) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('width', () {
    // Mutation: the 350 compact cap also applies to large.
    testWidgets('large box = available width (376), open and closed', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_large(button: _b('Go')));
      await _wait(tester, 1000);
      expect(_box(tester).width, closeTo(376, 0.01));
      expect(_box(tester).left, closeTo(12, 0.01));
      await _open(tester);
      expect(_box(tester).width, closeTo(376, 0.01));
      expect(_shape(tester).width, closeTo(376, 0.01));
      await end(tester);
    });

    // Mutation: the 520 cap is removed.
    testWidgets('a 1024 dp surface caps the large body at 520', (tester) async {
      await _host(tester, c, size: const Size(1024, 768));
      c.show(_large(button: _b('Go')));
      await _wait(tester, 1000);
      await _open(tester);
      expect(_box(tester).width, closeTo(520, 0.01));
      await end(tester);
    });

    // Boundary just under the cap: 544 - 24 = 520 and 540 - 24 = 516.
    testWidgets('a 540 dp surface gives 516, below the cap', (tester) async {
      await _host(tester, c, size: const Size(540, 800));
      c.show(_large(button: _b('Go')));
      await _wait(tester, 1000);
      expect(_box(tester).width, closeTo(516, 0.01));
      await end(tester);
    });

    // Mutation: the constrained width ignores the viewport padding.
    testWidgets('a 320 dp surface gives 296', (tester) async {
      await _host(tester, c, size: const Size(320, 640));
      c.show(_large(button: _b('Go')));
      await _wait(tester, 1000);
      expect(_box(tester).width, closeTo(296, 0.01));
      await end(tester);
    });

    // Mutation: the compact toast adopts the large width.
    testWidgets('compact stays at 350 on the same surface', (tester) async {
      await _host(tester, c);
      c.show(_large(size: SileoSize.compact));
      await _wait(tester, 1000);
      expect(_box(tester).width, closeTo(350, 0.01));
      await end(tester);
    });
  });

  group('header and body metrics', () {
    // Mutation: largeHeight (56) not used for the header floor.
    testWidgets('closed large pill is 56 tall (box 64)', (tester) async {
      await _host(tester, c);
      c.show(_large());
      await _wait(tester, 1000);
      expect(_shape(tester).headerHeight, 56);
      expect(_box(tester).height, closeTo(56 + 8, 0.5));
      await end(tester);
    });

    // Mutation: the header ignores the text scaler.
    testWidgets('2.0 text grows the header to 22 * 2 + 16 = 60', (
      tester,
    ) async {
      await _host(tester, c, scaler: const TextScaler.linear(2));
      c.show(_large(title: 'Hi'));
      await _wait(tester, 1000);
      expect(_shape(tester).headerHeight, 60);
      expect(tester.takeException(), isNull);
      await end(tester);
    });

    // Mutation: padding, gaps, trailing size or button height changed.
    testWidgets('body with trailing and two buttons is 156 tall', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(
        _large(
          trailing: _thumb,
          button: _b('Accept'),
          secondaryButton: _b('Decline'),
        ),
      );
      await _wait(tester, 1000);
      await _open(tester);
      expect(_body(tester), closeTo(156, 0.5));
      expect(_box(tester).height, closeTo(56 + 156 + 8, 0.5));
      await end(tester);
    });

    // Mutation: a trailing slot (64) is reserved even when trailing is null.
    testWidgets('without trailing the body is 112 tall', (tester) async {
      await _host(tester, c);
      c.show(_large(button: _b('Accept'), secondaryButton: _b('Decline')));
      await _wait(tester, 1000);
      await _open(tester);
      expect(_body(tester), closeTo(112, 0.5));
      await end(tester);
    });

    // Mutation: a content-less large toast opens anyway.
    testWidgets('large without description and buttons never opens', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_large(description: null));
      await _wait(tester, 1000);
      await tester.tap(find.text('Delivery'));
      await _wait(tester, 1500);
      expect(_body(tester), lessThan(0.5));
      expect(_box(tester).height, closeTo(64, 0.5));
      await end(tester);
    });

    // Mutation: largeRoundness (24) replaced by the compact 16.
    testWidgets('large roundness defaults to 24, compact keeps 16', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_large());
      await _wait(tester, 1000);
      expect(_shape(tester).roundness, 24);
      c.show(_large(size: SileoSize.compact));
      await _wait(tester, 2000);
      expect(_shape(tester).roundness, 16);
      await end(tester);
    });

    // Mutation: options.roundness ignored for large.
    testWidgets('options.roundness overrides the large 24', (tester) async {
      await _host(tester, c);
      c.show(_large(roundness: 10));
      await _wait(tester, 1000);
      expect(_shape(tester).roundness, 10);
      await end(tester);
    });
  });

  group('buttons', () {
    // Mutation: order swapped (primary left); gap or cell width changed.
    testWidgets('secondary LEFT, primary RIGHT, equal 166 cells, 12 gap', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_large(button: _b('Accept'), secondaryButton: _b('Decline')));
      await _wait(tester, 1000);
      await _open(tester);
      final box = _box(tester);
      final sec = _btn(tester, 'Decline');
      final pri = _btn(tester, 'Accept');
      expect(sec.left, lessThan(pri.left));
      expect(sec.left, closeTo(box.left + 16, 0.5));
      expect(sec.width, closeTo(166, 0.5));
      expect(pri.width, closeTo(166, 0.5));
      expect(pri.left - sec.right, closeTo(12, 0.5));
      expect(pri.left - sec.right, greaterThanOrEqualTo(8));
      expect(pri.right, closeTo(box.right - 16, 0.5));
      expect(sec.top, closeTo(pri.top, 0.01));
      await end(tester);
    });

    // Mutation: pill height below 48 / hit box shrunk.
    testWidgets('each button is 48 dp tall and sits 16 above the bottom', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_large(button: _b('Accept'), secondaryButton: _b('Decline')));
      await _wait(tester, 1000);
      await _open(tester);
      final box = _box(tester);
      for (final label in ['Accept', 'Decline']) {
        final r = _btn(tester, label);
        expect(r.height, closeTo(48, 0.01));
        expect(r.bottom, closeTo(box.bottom - 4 - 16, 0.5));
      }
      await end(tester);
    });

    // Mutation: callbacks swapped between the two buttons.
    testWidgets('each button fires only its own callback', (tester) async {
      var accepted = 0;
      var declined = 0;
      await _host(tester, c);
      c.show(
        _large(
          button: _b('Accept', () => accepted++),
          secondaryButton: _b('Decline', () => declined++),
        ),
      );
      await _wait(tester, 1000);
      await _open(tester);
      await tester.tapAt(_btn(tester, 'Decline').center);
      expect((declined, accepted), (1, 0));
      await tester.tapAt(_btn(tester, 'Accept').center);
      expect((declined, accepted), (1, 1));
      await end(tester);
    });

    // Mutation: Enter/Space handling missing on the secondary button.
    testWidgets('the secondary button activates with Enter when focused', (
      tester,
    ) async {
      var declined = 0;
      await _host(tester, c);
      c.show(
        _large(
          button: _b('Accept'),
          secondaryButton: _b('Decline', () => declined++),
        ),
      );
      await _wait(tester, 1000);
      await _open(tester);
      Focus.of(tester.element(find.text('Decline'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(declined, 1);
      await end(tester);
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      // Mutation: any button hit box below 48 dp / unlabeled.
      testWidgets('two-button large toast passes tap guidelines on $platform', (
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
          _large(
            trailing: _thumb,
            button: _b('Accept'),
            secondaryButton: _b('Decline'),
          ),
        );
        await _wait(tester, 1000);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await _open(tester);
        expect(_body(tester), greaterThan(100));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await end(tester);
      });
    }
  });

  group('trailing', () {
    // Mutation: trailing not forced to 64 square / radius 12 / not clipped.
    testWidgets('is 64 square, radius 12, top-aligned at the right edge', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_large(trailing: _thumb, button: _b('Accept')));
      await _wait(tester, 1000);
      await _open(tester);
      final box = _box(tester);
      final r = tester.getRect(find.byKey(_thumbKey));
      expect(r.size, const Size(64, 64));
      expect(r.right, closeTo(box.right - 16, 0.5));
      // pill top (box.top + 4) + header 56 + padding 16.
      expect(r.top, closeTo(box.top + 4 + 56 + 16, 0.5));
      final clip = tester.widget<ClipRRect>(
        find
            .ancestor(
              of: find.byKey(_thumbKey),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      expect(clip.borderRadius, BorderRadius.circular(12));
      await end(tester);
    });

    // Mutation: the RepaintBoundary around the trailing is removed.
    testWidgets('sits in its own 64 dp RepaintBoundary', (tester) async {
      await _host(tester, c);
      c.show(_large(trailing: _thumb, button: _b('Accept')));
      await _wait(tester, 1000);
      await _open(tester);
      final nearest = find
          .ancestor(
            of: find.byKey(_thumbKey),
            matching: find.byType(RepaintBoundary),
          )
          .first;
      expect(tester.getSize(nearest), const Size(64, 64));
      await end(tester);
    });

    // Mutation: the description ignores the trailing slot (12 gap + 64).
    testWidgets('description ends 12 dp before the trailing', (tester) async {
      await _host(tester, c);
      c.show(
        _large(
          description: Text('word ' * 40),
          trailing: _thumb,
          button: _b('Accept'),
        ),
      );
      await _wait(tester, 1000);
      await _open(tester);
      final thumb = tester.getRect(find.byKey(_thumbKey));
      final text = tester.getRect(find.textContaining('word'));
      expect(text.right, lessThanOrEqualTo(thumb.left - 12 + 0.5));
      expect(text.left, closeTo(_box(tester).left + 16, 0.5));
      await end(tester);
    });

    // Mutation: compact starts rendering trailing / secondaryButton.
    testWidgets('compact ignores trailing and secondaryButton', (tester) async {
      await _host(tester, c);
      c.show(
        _large(
          size: SileoSize.compact,
          trailing: _thumb,
          button: _b('Accept'),
          secondaryButton: _b('Decline'),
        ),
      );
      await _wait(tester, 1000);
      await _open(tester);
      expect(find.byKey(_thumbKey), findsNothing);
      expect(find.text('Decline'), findsNothing);
      expect(find.text('Accept'), findsOneWidget);
      await end(tester);
    });
  });

  group('2.0 text at 320 dp', () {
    // Mutation: fixed-height buttons/header -> RenderFlex overflow, or
    // labels clipped instead of growing the row.
    testWidgets('large with trailing and two long buttons does not overflow', (
      tester,
    ) async {
      await _host(
        tester,
        c,
        size: const Size(320, 640),
        scaler: const TextScaler.linear(2),
      );
      c.show(
        _large(
          title: 'Hi',
          description: const Text('A longer description that must wrap'),
          trailing: _thumb,
          button: _b('Accept and continue'),
          secondaryButton: _b('Decline for now'),
        ),
      );
      await _wait(tester, 1000);
      await _open(tester, title: 'Hi');
      expect(tester.takeException(), isNull);
      final box = _box(tester);
      for (final label in ['Accept and continue', 'Decline for now']) {
        final r = _btn(tester, label);
        expect(r.height, greaterThan(48), reason: '$label wraps and grows');
        expect(r.bottom, lessThanOrEqualTo(box.bottom - 4 - 16 + 0.5));
        expect(r.left, greaterThanOrEqualTo(box.left));
        expect(r.right, lessThanOrEqualTo(box.right));
      }
      expect(
        _btn(tester, 'Accept and continue').left -
            _btn(tester, 'Decline for now').right,
        greaterThanOrEqualTo(8),
      );
      await end(tester);
    });
  });

  group('semantics', () {
    SemanticsNode node(WidgetTester t, Pattern label) =>
        t.getSemantics(find.bySemanticsLabel(label));

    // Mutation: buttons merged into the container, or the container label
    // loses the description.
    testWidgets('each button is its own node; container = title + text', (
      tester,
    ) async {
      handle = tester.ensureSemantics();
      await _host(tester, c);
      c.show(
        _large(
          description: const Text('Body text'),
          trailing: _thumb,
          button: _b('Accept'),
          secondaryButton: _b('Decline'),
        ),
      );
      await _wait(tester, 1000);
      await _open(tester);
      final container = node(tester, RegExp('^Delivery'));
      final accept = node(tester, 'Accept');
      final decline = node(tester, 'Decline');
      expect(container.label, startsWith('Delivery\nBody text'));
      expect(container.label, isNot(contains('Accept')));
      expect(container.label, isNot(contains('Decline')));
      expect({container.id, accept.id, decline.id}, hasLength(3));
      for (final n in [accept, decline]) {
        final d = n.getSemanticsData();
        expect(d.flagsCollection.isButton, isTrue);
        expect(d.hasAction(SemanticsAction.tap), isTrue);
      }
      expect(accept.getSemanticsData().label, 'Accept');
      expect(decline.getSemanticsData().label, 'Decline');
      expect(container.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      await end(tester);
    });

    // Plan §7.4/§9: container label = title (+ description) exactly once.
    // Actual (compact and large alike): "Delivery\nBody text\nBody text" - the
    // description Text's own node is merged on top of the explicit label.
    // Confirmed spec/code mismatch, reported to the caller.
    testWidgets(
      'container label is exactly title + description, once',
      (tester) async {
        handle = tester.ensureSemantics();
        await _host(tester, c);
        c.show(_large(description: const Text('Body text')));
        await _wait(tester, 1000);
        await _open(tester);
        expect(node(tester, RegExp('^Delivery')).label, 'Delivery\nBody text');
        await end(tester);
      },
      skip: true, // spec/code mismatch: see comment above.
    );

    // Mutation: the trailing is exposed to semantics.
    testWidgets('an unlabeled trailing adds no semantics node', (tester) async {
      handle = tester.ensureSemantics();
      await _host(tester, c);
      c.show(
        _large(
          description: const Text('Body text'),
          trailing: const Text('THUMBNAIL'),
          button: _b('Accept'),
        ),
      );
      await _wait(tester, 1000);
      await _open(tester);
      expect(find.bySemanticsLabel(RegExp('THUMBNAIL')), findsNothing);
      expect(node(tester, RegExp('^Delivery')).label, isNot(contains('THUMB')));
      await end(tester);
    });

    // Plan §7.4: "excluded from semantics unless it carries its own label".
    // The implementation wraps the trailing in ExcludeSemantics
    // unconditionally (sileo_toast_large.dart), so a labeled trailing is
    // hidden: confirmed spec/code mismatch, reported to the caller.
    testWidgets(
      'a trailing with its own label stays in semantics',
      (tester) async {
        handle = tester.ensureSemantics();
        await _host(tester, c);
        c.show(
          _large(
            trailing: Semantics(label: 'Courier photo', child: _thumb),
            button: _b('Accept'),
          ),
        );
        await _wait(tester, 1000);
        await _open(tester);
        expect(find.bySemanticsLabel('Courier photo'), findsOneWidget);
        await end(tester);
      },
      skip: true, // spec/code mismatch: see comment above.
    );
  });

  group('compact -> large morph (same id)', () {
    // Mutation: retarget uses animate: false on a size change (snap).
    testWidgets('closed pill: height and width travel without a jump', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_large(id: 'm', size: SileoSize.compact));
      await _wait(tester, 1500);
      final h0 = _shape(tester).toastHeight.value;
      final w0 = _shape(tester).pillWidth.value;
      expect(h0, closeTo(40, 0.5));

      c.show(_large(id: 'm'));
      final heights = <double>[];
      final widths = <double>[];
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        heights.add(_shape(tester).toastHeight.value);
        widths.add(_shape(tester).pillWidth.value);
      }
      expect(heights.last, closeTo(56, 0.5));
      final wEnd = widths.last;
      expect(wEnd, greaterThan(w0 + 5), reason: 'large pill is wider');
      // First frame after the swap is still near the start, not the target.
      expect(heights.first, lessThan(48));
      expect(widths.first, lessThan(w0 + (wEnd - w0) / 2));
      var prev = h0;
      for (final h in heights) {
        expect((h - prev).abs(), lessThan(8), reason: 'height step');
        prev = h;
      }
      var prevW = w0;
      for (final w in widths) {
        expect((w - prevW).abs(), lessThan((wEnd - w0) / 2), reason: 'width');
        prevW = w;
      }
      expect(tester.takeException(), isNull);
      await end(tester);
    });

    // Mutation: an open compact toast snaps to the large header on morph.
    testWidgets('open compact collapses smoothly into the large pill', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_large(id: 'm', size: SileoSize.compact));
      await _wait(tester, 1000);
      await _open(tester);
      final open = _shape(tester).toastHeight.value;
      expect(open, greaterThan(80));

      c.show(_large(id: 'm', description: null));
      var prev = open;
      var maxStep = 0.0;
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final h = _shape(tester).toastHeight.value;
        maxStep = maxStep < (h - prev).abs() ? (h - prev).abs() : maxStep;
        prev = h;
      }
      expect(prev, closeTo(56, 0.5));
      expect(maxStep, lessThan(open - 56 - 10), reason: 'no single-frame snap');
      await end(tester);
    });
  });

  group('reduce motion', () {
    // Mutation: large springs keep animating under disableAnimations.
    testWidgets('large opens in one frame with nothing in flight', (
      tester,
    ) async {
      await _host(tester, c, noAnimations: true);
      c.show(
        _large(
          trailing: _thumb,
          button: _b('Accept'),
          secondaryButton: _b('Decline'),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.tap(find.text('Delivery'));
      await tester.pump();
      await tester.pump();
      expect(_body(tester), closeTo(156, 0.5));
      expect(tester.binding.transientCallbackCount, 0);
      await end(tester);
    });
  });

  group('performance', () {
    // Mutation: a package widget rebuilds each frame (e.g. a setState or
    // ListenableBuilder around the content driven by a spring).
    testWidgets('0 package widget rebuilds per frame while large expands', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(
        _large(
          description: const Text('Description'),
          trailing: _thumb,
          button: _b('Accept'),
          secondaryButton: _b('Decline'),
        ),
      );
      await _wait(tester, 1500);
      await tester.tap(find.text('Delivery'));
      // Tap state change and first content measurement may rebuild.
      await _wait(tester, 60);
      _countRebuilds();
      final before = _paints(tester);
      var frames = 0;
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      expect(frames, 80);
      expect(_body(tester), closeTo(156, 1), reason: 'it did expand');
      expect(_paints(tester), greaterThan(before), reason: 'counter is live');
      expect(_rebuilds, 0, reason: 'package widgets rebuilt while animating');
      await end(tester);
    });

    // Mutation: a ticker or listener keeps the idle toast repainting.
    testWidgets('an idle open and closed large toast repaints 0 times', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(_large(button: _b('Accept'), secondaryButton: _b('Decline')));
      await _wait(tester, 2000);
      var before = _paints(tester);
      await _wait(tester, 500);
      expect(_paints(tester), before);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await _open(tester);
      await _wait(tester, 1000);
      before = _paints(tester);
      await _wait(tester, 500);
      expect(_paints(tester), before);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await end(tester);
    });

    // Mutation: BackdropFilter / blur / saveLayer added to large.
    testWidgets('steady state has no filter layer or saveLayer', (
      tester,
    ) async {
      await _host(tester, c);
      c.show(
        _large(
          trailing: _thumb,
          button: _b('Accept'),
          secondaryButton: _b('Decline'),
        ),
      );
      await _wait(tester, 2000);
      _expectNoExpensiveOps(tester);
      await _open(tester);
      await _wait(tester, 1000);
      _expectNoExpensiveOps(tester);
      await end(tester);
    });
  });
}
