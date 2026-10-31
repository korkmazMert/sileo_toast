// Spec: plan §7.1 "Analytic path" and §9 "Shape".
// Hand-computed geometry: toast width 350, header 40, roundness 16, so the
// fillet radius is 16 * 0.5 = 8 and a fillet at a pill side x=s sits on the
// body top edge (y=40) with its circle centre at (s -+ 8, 32).
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sileo_toast/src/sileo_shape_painter.dart';

Path _path({
  double pillX = 100,
  double pillWidth = 150,
  double body = 100,
  double roundness = 16,
}) => SileoShapePainter.buildPath(
  width: 350,
  pillX: pillX,
  pillWidth: pillWidth,
  headerHeight: 40,
  bodyHeight: body,
  roundness: roundness,
);

class _Recording implements Canvas {
  final calls = <Symbol>[];
  final paints = <Paint>[];
  List<int> get argb => [for (final p in paints) p.color.toARGB32()];

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

SileoShapePainter _painter({
  double body = 100,
  double opacity = 1,
  bool flipped = false,
  double inset = 0,
  Color fill = const Color(0xFF1A1A1A),
}) => SileoShapePainter(
  fill: fill,
  roundness: 16,
  width: 350,
  headerHeight: 40,
  pillX: const AlwaysStoppedAnimation(100),
  pillWidth: const AlwaysStoppedAnimation(150),
  bodyHeight: AlwaysStoppedAnimation(body),
  bodyOpacity: AlwaysStoppedAnimation(opacity),
  toastHeight: AlwaysStoppedAnimation(40 + body),
  flipped: flipped,
  verticalInset: inset,
);

SileoShapePainter _neckPainter({
  Rect? neck = const Rect.fromLTRB(135, -50, 215, -13),
}) => SileoShapePainter(
  fill: const Color(0xFF000000),
  roundness: 16,
  width: 350,
  headerHeight: 40,
  pillX: const AlwaysStoppedAnimation(100),
  pillWidth: const AlwaysStoppedAnimation(150),
  bodyHeight: const AlwaysStoppedAnimation(100),
  bodyOpacity: const AlwaysStoppedAnimation(1),
  toastHeight: const AlwaysStoppedAnimation(140),
  neck: neck,
  neckHeight: const AlwaysStoppedAnimation(50),
);

void main() {
  group('body under 0.5 dp -> pill rrect only', () {
    // Mutation: epsilon comparison inverted/removed -> body bleeds in.
    test('0.4 dp body: bounds are the pill and nothing below it', () {
      final p = _path(body: 0.4);
      expect(p.getBounds(), const Rect.fromLTRB(100, 0, 250, 40));
      expect(p.contains(const Offset(175, 20)), isTrue);
      expect(p.contains(const Offset(50, 41)), isFalse);
      expect(p.contains(const Offset(175, 41)), isFalse);
    });

    test('0.5 dp body: path includes the body (boundary)', () {
      final p = _path(body: 0.5);
      expect(p.getBounds().bottom, closeTo(40.5, 1e-6));
      expect(p.getBounds().left, closeTo(0, 1e-3));
      expect(p.getBounds().right, closeTo(350, 1e-3));
    });

    test('pill corner is rounded: its corner point is outside', () {
      final p = _path(body: 0);
      expect(p.contains(const Offset(100.5, 0.5)), isFalse);
      expect(p.contains(const Offset(110, 20)), isTrue);
    });
  });

  group('concave fillets', () {
    // Fillet circle centre (92, 32) r 8. (99, 39) is 9.9 from it -> filled
    // by the fillet; (93, 39) is 7.07 from it -> carved out.
    // Mutation: fillet removed -> (99, 39) is empty (square corner above the
    // body, outside the pill). Fillet convex -> (93, 39) filled.
    test('left side meets the body with a concave fillet', () {
      final p = _path();
      expect(p.contains(const Offset(99, 39)), isTrue);
      expect(p.contains(const Offset(93, 39)), isFalse);
      expect(p.contains(const Offset(96, 36)), isFalse);
      // Beside the pill, above the fillet zone: still outside.
      expect(p.contains(const Offset(92, 20)), isFalse);
    });

    // Right pill edge x=250, circle centre (258, 32).
    test('right side meets the body with a concave fillet', () {
      final p = _path();
      expect(p.contains(const Offset(251, 39)), isTrue);
      expect(p.contains(const Offset(257, 39)), isFalse);
    });

    // Mutation: radius not clamped by body height -> radius 8 instead of 5.
    // body 10 -> fillet r = min(8, 5) = 5, centre (95, 35).
    test('fillet radius is clamped to half the body height', () {
      final p = _path(body: 10);
      expect(p.contains(const Offset(99, 39)), isTrue); // 5.66 > 5
      expect(p.contains(const Offset(97, 39)), isFalse); // 4.47 < 5
    });

    // gap 4 -> fillet r = min(8, 50, 4) = 4, centre (0, 36).
    test('fillet radius is clamped to the gap to the body edge', () {
      final p = _path(pillX: 4);
      expect(p.contains(const Offset(3.5, 39.5)), isTrue); // 4.95 > 4
      expect(p.contains(const Offset(1.5, 39)), isFalse); // 3.35 < 4
    });

    // Mutation: fillet ignores roundness (blurRatio) -> roundness 0 still
    // fills (99, 39).
    test('roundness 0 gives no fillet', () {
      final p = _path(roundness: 0);
      expect(p.contains(const Offset(99, 39)), isFalse);
    });
  });

  group('flush side has no fillet', () {
    // pill 200..350 is flush right: the pill edge runs straight into the
    // body edge, so the pill's own bottom-right corner is not rounded.
    // Mutation: fillet/round corner applied on a flush side -> (349.9, 39)
    // falls outside.
    test('flush right: right edge is straight, left still has a fillet', () {
      final p = _path(pillX: 200);
      expect(p.getBounds().right, 350);
      expect(p.contains(const Offset(349.9, 39)), isTrue);
      expect(p.contains(const Offset(349.9, 41)), isTrue);
      // Left fillet: circle centre (192, 32).
      expect(p.contains(const Offset(199, 39)), isTrue);
      expect(p.contains(const Offset(193, 39)), isFalse);
    });

    test('flush left: left edge is straight, right still has a fillet', () {
      final p = _path(pillX: 0);
      expect(p.getBounds().left, 0);
      expect(p.contains(const Offset(0.1, 39)), isTrue);
      // Right pill edge x=150, circle centre (158, 32).
      expect(p.contains(const Offset(151, 39)), isTrue);
      expect(p.contains(const Offset(157, 39)), isFalse);
    });

    test('full-width pill is flush on both sides', () {
      final p = _path(pillX: 0, pillWidth: 350);
      expect(p.getBounds(), const Rect.fromLTRB(0, 0, 350, 140));
      expect(p.contains(const Offset(0.1, 39)), isTrue);
      expect(p.contains(const Offset(349.9, 39)), isTrue);
    });
  });

  group('paint', () {
    // Mutation: any saveLayer / ImageFilter / MaskFilter in the painter.
    test('uses no saveLayer, image filter or mask filter', () {
      for (final p in [
        _painter(),
        _painter(opacity: 0.5),
        _painter(flipped: true, inset: 4),
        _painter(body: 0),
      ]) {
        final canvas = _Recording();
        p.paint(canvas, const Size(350, 148));
        expect(canvas.calls, isNot(contains(#saveLayer)));
        expect(canvas.calls, contains(#drawPath));
        for (final paint in canvas.paints) {
          expect(paint.imageFilter, isNull);
          expect(paint.maskFilter, isNull);
        }
      }
    });

    test('paints the fill color', () {
      final canvas = _Recording();
      _painter().paint(canvas, const Size(350, 140));
      expect(canvas.argb.single, 0xFF1A1A1A);
    });

    // Mutation: pill fades with the body.
    test('fading body keeps the pill opaque', () {
      final canvas = _Recording();
      _painter(opacity: 0.5).paint(canvas, const Size(350, 140));
      expect(canvas.paints, hasLength(2));
      expect(canvas.argb.first, 0xFF1A1A1A);
      expect(canvas.paints.last.color.a, closeTo(0.5, 0.01));
    });

    test('no body: only the pill is painted, opaque', () {
      final canvas = _Recording();
      _painter(body: 0, opacity: 0).paint(canvas, const Size(350, 40));
      expect(canvas.paints, hasLength(1));
      expect(canvas.argb.single, 0xFF1A1A1A);
    });

    // Rasterize for real (a recording canvas can't see geometry): the body
    // grows downward on top toasts and upward on flipped (bottom) ones.
    test('flipped paints the body above the pill', () async {
      Future<ui.Image> render(SileoShapePainter p) {
        final rec = ui.PictureRecorder();
        p.paint(ui.Canvas(rec), const Size(350, 140));
        return rec.endRecording().toImage(350, 140);
      }

      Future<int> alphaAt(ui.Image img, int x, int y) async {
        final data = (await img.toByteData())!;
        return data.getUint8((y * 350 + x) * 4 + 3);
      }

      final top = await render(_painter());
      final bottom = await render(_painter(flipped: true));
      // Body area: far left, below the pill row (top) / above it (flipped).
      expect(await alphaAt(top, 20, 100), 255);
      expect(await alphaAt(top, 20, 10), 0);
      expect(await alphaAt(bottom, 20, 40), 255);
      expect(await alphaAt(bottom, 20, 130), 0);
    });
  });

  group('hitTest is limited to the path', () {
    // Body 0, inset 4: pill occupies y 4..44, hit zone reaches 4 further.
    // Mutation: hitTest always true -> the empty space reacts.
    test('inside the pill hits, empty space beside it does not', () {
      final p = _painter(body: 0, inset: 4);
      expect(p.hitTest(const Offset(175, 24)), isTrue);
      expect(p.hitTest(const Offset(20, 24)), isFalse);
    });

    // Mutation: inset not honoured -> the 48 dp tap box shrinks to 40.
    test('reaches the 4 dp tap extension above and below', () {
      final p = _painter(body: 0, inset: 4);
      expect(p.hitTest(const Offset(175, 1)), isTrue);
      expect(p.hitTest(const Offset(175, 47)), isTrue);
      expect(p.hitTest(const Offset(175, 49)), isFalse);
    });

    test('flipped hit test follows the flipped shape', () {
      // Body 100: shape box 140 tall, body occupies the top 100 when flipped.
      final p = _painter(flipped: true);
      expect(p.hitTest(const Offset(20, 20)), isTrue);
      expect(p.hitTest(const Offset(20, 130)), isFalse);
      final top = _painter();
      expect(top.hitTest(const Offset(20, 130)), isTrue);
      expect(top.hitTest(const Offset(20, 20)), isFalse);
    });
  });

  group('island neck (spec §7.3 Shape)', () {
    // Frame: pill top at y 0, neck above it (negative y). Neck rect 135..215
    // wide, 37 tall (capsule radius 18.5), full height 50 above the pill.
    // Pill 100..250, roundness 16 -> fillet 8. Left gap 35, right gap 35.
    const island = Rect.fromLTRB(135, -50, 215, -13);
    Path neckPath({
      Rect? neck = island,
      double nh = 50,
      double pillX = 100,
      double pillWidth = 150,
      double body = 100,
    }) => SileoShapePainter.buildPath(
      width: 350,
      pillX: pillX,
      pillWidth: pillWidth,
      headerHeight: 40,
      bodyHeight: body,
      roundness: 16,
      neck: neck,
      neckHeight: nh,
    );

    // Golden lengths/bounds captured from the pre-neck implementation.
    // Mutation: the shared join changes a single op for neck == null.
    test('null neck gives the pre-neck path exactly', () {
      double len(Path p) => p.computeMetrics().fold(0, (a, e) => a + e.length);
      const gold = <List<double>, double>{
        [100, 150, 100, 16]: 930.7955,
        [100, 150, 0.4, 16]: 351.8831,
        [0, 150, 100, 16]: 941.3392,
        [200, 150, 100, 16]: 941.3392,
        [0, 350, 100, 16]: 951.8831,
        [4, 150, 10, 16]: 774.6792,
        [100, 150, 100, 0]: 980.0,
      };
      gold.forEach((c, want) {
        final p = SileoShapePainter.buildPath(
          width: 350,
          pillX: c[0],
          pillWidth: c[1],
          headerHeight: 40,
          bodyHeight: c[2],
          roundness: c[3],
        );
        expect(len(p), closeTo(want, 1e-3), reason: '$c');
      });
    });

    test('zero neck height equals no neck', () {
      expect(neckPath(nh: 0).getBounds(), neckPath(neck: null).getBounds());
    });

    test('neck spans island top to the pill and the pill stays', () {
      final p = neckPath();
      expect(p.getBounds(), const Rect.fromLTRB(0, -50, 350, 140));
      expect(p.contains(const Offset(175, -30)), isTrue);
      expect(p.contains(const Offset(175, -49)), isTrue);
      expect(p.contains(const Offset(175, -52)), isFalse);
      expect(p.contains(const Offset(175, 20)), isTrue);
      // Beside the neck, above the pill: empty.
      expect(p.contains(const Offset(120, -30)), isFalse);
      expect(p.contains(const Offset(230, -30)), isFalse);
      // Capsule top corner is rounded.
      expect(p.contains(const Offset(136, -49)), isFalse);
    });

    // Left fillet circle centre (127, -8) r 8; (134, -1) is 9.9 away -> filled,
    // (128, -1) is 7.07 away -> carved. Mutation: no fillet / convex fillet.
    test('neck meets the pill top with concave fillets', () {
      final p = neckPath();
      expect(p.contains(const Offset(134, -1)), isTrue);
      expect(p.contains(const Offset(128, -1)), isFalse);
      expect(p.contains(const Offset(216, -1)), isTrue);
      expect(p.contains(const Offset(222, -1)), isFalse);
      // Pill top edge outside the fillet zone stays flat.
      expect(p.contains(const Offset(120, -1)), isFalse);
      expect(p.contains(const Offset(120, 1)), isTrue);
    });

    test('body fillets still exist next to the neck', () {
      final p = neckPath();
      expect(p.contains(const Offset(99, 39)), isTrue);
      expect(p.contains(const Offset(93, 39)), isFalse);
    });

    // Neck left edge flush with the pill: straight edge, no fillet or
    // rounded pill corner there; right side still has its fillet.
    test('flush side has no fillet', () {
      final p = neckPath(neck: const Rect.fromLTRB(100, -50, 215, -13));
      expect(p.getBounds().left, 0); // body, not the neck
      expect(p.contains(const Offset(100.5, 0.5)), isTrue);
      expect(p.contains(const Offset(100.5, -10)), isTrue);
      expect(p.contains(const Offset(99, -1)), isFalse);
      expect(p.contains(const Offset(216, -1)), isTrue);
      expect(p.contains(const Offset(222, -1)), isFalse);
    });

    // Gap 5 -> fillet r 5, centre (100, -5): (104.5, -0.5) filled (6.4 > 5),
    // (102, -1) carved (4.5 < 5). Mutation: radius not clamped by the gap.
    test('fillet radius is clamped to the gap to the pill edge', () {
      final p = neckPath(neck: const Rect.fromLTRB(105, -50, 215, -13));
      expect(p.contains(const Offset(104.5, -0.5)), isTrue);
      expect(p.contains(const Offset(102, -1)), isFalse);
    });

    test('neck on a bare pill (no body) is one closed shape', () {
      final p = neckPath(body: 0);
      expect(p.getBounds(), const Rect.fromLTRB(100, -50, 250, 40));
      expect(p.contains(const Offset(175, -30)), isTrue);
      expect(p.contains(const Offset(175, 30)), isTrue);
      expect(p.contains(const Offset(134, -1)), isTrue);
      expect(p.contains(const Offset(128, -1)), isFalse);
    });

    test('hitTest reaches the neck', () {
      final p = _neckPainter();
      expect(p.hitTest(const Offset(175, -30)), isTrue);
      expect(p.hitTest(const Offset(120, -30)), isFalse);
    });

    test('paint: no saveLayer, filter, or mask filter with a neck', () {
      final canvas = _Recording();
      _neckPainter().paint(canvas, const Size(350, 200));
      expect(canvas.calls, isNot(contains(#saveLayer)));
      expect(canvas.calls, contains(#drawPath));
      for (final paint in canvas.paints) {
        expect(paint.imageFilter, isNull);
        expect(paint.maskFilter, isNull);
      }
    });

    test('shouldRepaint compares the neck fields', () {
      final a = _neckPainter();
      expect(a.shouldRepaint(_neckPainter()), isFalse);
      expect(a.shouldRepaint(_neckPainter(neck: null)), isTrue);
      expect(
        a.shouldRepaint(_neckPainter(neck: const Rect.fromLTWH(0, 0, 9, 9))),
        isTrue,
      );
    });
  });

  test('shouldRepaint reacts to fill and flip changes only', () {
    const v = AlwaysStoppedAnimation<double>(1);
    SileoShapePainter make({
      Color fill = const Color(0xFF1A1A1A),
      bool f = false,
    }) => SileoShapePainter(
      fill: fill,
      roundness: 16,
      width: 350,
      headerHeight: 40,
      pillX: v,
      pillWidth: v,
      bodyHeight: v,
      bodyOpacity: v,
      toastHeight: v,
      flipped: f,
    );
    final a = make();
    expect(a.shouldRepaint(make()), isFalse);
    expect(a.shouldRepaint(make(fill: const Color(0xFFFFFFFF))), isTrue);
    expect(a.shouldRepaint(make(f: true)), isTrue);
  });
}
