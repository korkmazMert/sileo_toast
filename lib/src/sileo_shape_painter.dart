import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sileo_toast/src/constants.dart';

double _atLeast0(double v) => v < 0 ? 0 : v;

double _unless(bool flush, double v) => flush ? 0 : v;

/// Paints the gooey toast outline: the pill and the body as one closed path
/// with concave fillets where the pill sides meet the body top edge.
///
/// Analytic, so there is no blur, no `saveLayer` and no `ImageFilter`. The
/// animated values repaint it directly through [Listenable.merge], or
/// through a prebuilt `repaint` the owner builds once.
class SileoShapePainter extends CustomPainter {
  /// Creates a painter. Bottom toasts pass [flipped] so the body grows up.
  new({
    required this.fill,
    required this.roundness,
    required this.width,
    required this.headerHeight,
    required this.pillX,
    required this.pillWidth,
    required this.bodyHeight,
    required this.bodyOpacity,
    required this.toastHeight,
    this.flipped = false,
    this.verticalInset = 0,
    this.neck,
    this.neckHeight,
    Listenable? repaint,
  }) : super(
         repaint:
             repaint ??
             Listenable.merge([
               pillX,
               pillWidth,
               bodyHeight,
               bodyOpacity,
               toastHeight,
               ?neckHeight,
             ]),
       );

  /// Toast fill.
  final Color fill;

  /// Corner roundness.
  final double roundness;

  /// Toast width.
  final double width;

  /// Pill height (the text-scaled header height).
  final double headerHeight;

  /// Pill left edge.
  final Animation<double> pillX;

  /// Pill width.
  final Animation<double> pillWidth;

  /// Body height below the pill.
  final Animation<double> bodyHeight;

  /// Body fill opacity.
  final Animation<double> bodyOpacity;

  /// Height of the toast box without the inset; used to flip.
  final Animation<double> toastHeight;

  /// Grow upward from the bottom edge.
  final bool flipped;

  /// Empty space above and below the shape. Hit testing reaches this far
  /// past the path, which is how the 48 dp tap target is made.
  final double verticalInset;

  /// Island rect for the neck capsule, in the shape frame (pill top at y 0,
  /// so it sits at negative y; paint is not clipped to the box). Null: no
  /// neck, and the outline is exactly the plain pill and body.
  final Rect? neck;

  /// Neck height above the pill top; with [neck] null it is ignored.
  final Animation<double>? neckHeight;

  /// The outline in a top-edge frame: pill at y 0..[headerHeight], body
  /// below it. Just the pill rrect while the body is under half a dp.
  ///
  /// With a [neck] (the island rect) the outline also holds a capsule above
  /// the pill: it spans the rect's left/right, is as tall as the rect for
  /// its corner radius, and runs from `-neckHeight` down to the pill top
  /// (y 0), so it reaches into negative y. It joins the pill with the same
  /// concave fillets as the pill joins the body.
  static Path buildPath({
    required double width,
    required double pillX,
    required double pillWidth,
    required double headerHeight,
    required double bodyHeight,
    required double roundness,
    Rect? neck,
    double neckHeight = 0,
  }) => _build(
    Path(),
    width: width,
    pillX: pillX,
    pillWidth: pillWidth,
    headerHeight: headerHeight,
    bodyHeight: bodyHeight,
    roundness: roundness,
    neck: neck,
    neckHeight: neckHeight,
  );

  /// Concave fillet where the vertical edge at [x] meets the horizontal edge
  /// at [y]: used for neck to pill and pill to body, on either side.
  static void _join(
    Path path,
    double x,
    double y,
    double f, {
    required bool right,
  }) {
    if (right) {
      path
        ..lineTo(x, y - f)
        ..arcToPoint(
          Offset(x + f, y),
          radius: Radius.circular(f),
          clockwise: false,
        );
    } else {
      path
        ..lineTo(x - f, y)
        ..arcToPoint(
          Offset(x, y - f),
          radius: Radius.circular(f),
          clockwise: false,
        );
    }
  }

  /// Writes the outline into [path] (reset first), so painters reuse one.
  static Path _build(
    Path path, {
    required double width,
    required double pillX,
    required double pillWidth,
    required double headerHeight,
    required double bodyHeight,
    required double roundness,
    Rect? neck,
    double neckHeight = 0,
  }) {
    path.reset();
    const eps = SileoConstants.shapeEpsilon;
    final left = _atLeast0(pillX);
    final right = math.min(width, pillX + pillWidth);
    final pill = _atLeast0(right - left);
    final r = _atLeast0(roundness);
    final pr = math.min(r, math.min(pill, headerHeight) / 2);
    final fillet = r * SileoConstants.blurRatio;

    // Neck: capsule x range clamped to the pill, radius, fillets, and the
    // pill's top corner radii (shrunk when the gap is tight).
    final nl = neck == null ? 0.0 : math.max(neck.left, left);
    final nr = neck == null ? 0.0 : math.min(neck.right, right);
    final hasNeck = neck != null && neckHeight >= eps && nr - nl > eps;
    final nh = neckHeight;
    final rn = hasNeck
        ? _atLeast0(math.min(neck.height / 2, math.min((nr - nl) / 2, nh)))
        : 0.0;
    final gapNL = nl - left;
    final gapNR = right - nr;
    final flushNL = gapNL < eps;
    final flushNR = gapNR < eps;
    final room = _atLeast0(nh - rn);
    final fnL = _unless(flushNL, math.min(fillet, math.min(gapNL, room)));
    final fnR = _unless(flushNR, math.min(fillet, math.min(gapNR, room)));
    final ptL = hasNeck && !flushNL ? _atLeast0(math.min(pr, gapNL - fnL)) : pr;
    final ptR = hasNeck && !flushNR ? _atLeast0(math.min(pr, gapNR - fnR)) : pr;

    if (bodyHeight < eps && !hasNeck) {
      return path..addRRect(
        RRect.fromLTRBR(left, 0, right, headerHeight, Radius.circular(pr)),
      );
    }

    // Clockwise from the top edge (the neck's, or the pill's without one).
    if (hasNeck) {
      path
        ..moveTo(nl + rn, -nh)
        ..lineTo(nr - rn, -nh)
        ..arcToPoint(Offset(nr, rn - nh), radius: Radius.circular(rn));
      if (flushNR) {
        path.lineTo(right, pr);
      } else {
        _join(path, nr, 0, fnR, right: true);
        path
          ..lineTo(right - ptR, 0)
          ..arcToPoint(Offset(right, ptR), radius: Radius.circular(ptR));
      }
    } else {
      path
        ..moveTo(left + pr, 0)
        ..lineTo(right - pr, 0)
        ..arcToPoint(Offset(right, pr), radius: Radius.circular(pr));
    }

    if (bodyHeight < eps) {
      // Neck on a bare pill.
      path
        ..lineTo(right, headerHeight - pr)
        ..arcToPoint(
          Offset(right - pr, headerHeight),
          radius: Radius.circular(pr),
        )
        ..lineTo(left + pr, headerHeight)
        ..arcToPoint(
          Offset(left, headerHeight - pr),
          radius: Radius.circular(pr),
        );
    } else {
      _body(path, width, left, right, headerHeight, bodyHeight, r, fillet);
    }
    return _closeTop(
      path,
      hasNeck: hasNeck,
      left: left,
      pr: pr,
      ptL: ptL,
      flushNL: flushNL,
      nl: nl,
      fnL: fnL,
      rn: rn,
      nh: nh,
    );
  }

  /// Pill right side, the body and the pill left side, up to the pill's top
  /// left; the path ends at the start of the left top corner.
  static void _body(
    Path path,
    double width,
    double left,
    double right,
    double headerHeight,
    double bodyHeight,
    double r,
    double fillet,
  ) {
    const eps = SileoConstants.shapeEpsilon;
    final gapL = left;
    final gapR = width - right;
    final flushL = gapL < eps;
    final flushR = gapR < eps;
    final fL = _unless(
      flushL,
      math.min(fillet, math.min(bodyHeight / 2, gapL)),
    );
    final fR = _unless(
      flushR,
      math.min(fillet, math.min(bodyHeight / 2, gapR)),
    );
    final bottom = headerHeight + bodyHeight;
    final rb = math.min(r, math.min(width / 2, bodyHeight / 2));
    // Body top corners must not run into the fillets.
    final rtL = _unless(flushL, _atLeast0(math.min(rb, gapL - fL)));
    final rtR = _unless(flushR, _atLeast0(math.min(rb, gapR - fR)));

    if (flushR) {
      path
        ..lineTo(right, bottom - rb)
        ..arcToPoint(Offset(right - rb, bottom), radius: Radius.circular(rb));
    } else {
      _join(path, right, headerHeight, fR, right: true);
      path.lineTo(width - rtR, headerHeight);
      if (rtR > 0) {
        path.arcToPoint(
          Offset(width, headerHeight + rtR),
          radius: Radius.circular(rtR),
        );
      }
      path
        ..lineTo(width, bottom - rb)
        ..arcToPoint(Offset(width - rb, bottom), radius: Radius.circular(rb));
    }
    path
      ..lineTo(rb, bottom)
      ..arcToPoint(Offset(0, bottom - rb), radius: Radius.circular(rb));
    if (!flushL) {
      path.lineTo(0, headerHeight + rtL);
      if (rtL > 0) {
        path.arcToPoint(
          Offset(rtL, headerHeight),
          radius: Radius.circular(rtL),
        );
      }
      _join(path, left, headerHeight, fL, right: false);
    }
  }

  /// Left side up to the top, around the neck when there is one.
  static Path _closeTop(
    Path path, {
    required bool hasNeck,
    required double left,
    required double pr,
    required double ptL,
    required bool flushNL,
    required double nl,
    required double fnL,
    required double rn,
    required double nh,
  }) {
    if (!hasNeck) {
      return path
        ..lineTo(left, pr)
        ..arcToPoint(Offset(left + pr, 0), radius: Radius.circular(pr))
        ..close();
    }
    if (flushNL) {
      path.lineTo(left, rn - nh);
    } else {
      path
        ..lineTo(left, ptL)
        ..arcToPoint(Offset(left + ptL, 0), radius: Radius.circular(ptL));
      _join(path, nl, 0, fnL, right: false);
      path.lineTo(nl, rn - nh);
    }
    return path
      ..arcToPoint(Offset(nl + rn, -nh), radius: Radius.circular(rn))
      ..close();
  }

  // One path and two paints per painter, reused every frame. The faded pill
  // and the body need separate paints because a recording canvas keeps them.
  final Path _shape = Path();
  final Paint _pillPaint = Paint();
  final Paint _bodyPaint = Paint();

  Path _path({double? body}) => _build(
    _shape,
    width: width,
    pillX: pillX.value,
    pillWidth: pillWidth.value,
    headerHeight: headerHeight,
    bodyHeight: body ?? bodyHeight.value,
    roundness: roundness,
    neck: neck,
    neckHeight: neckHeight?.value ?? 0,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(0, verticalInset);
    if (flipped) {
      canvas
        ..translate(0, toastHeight.value)
        ..scale(1, -1);
    }
    final hasBody = bodyHeight.value >= SileoConstants.shapeEpsilon;
    final opacity = bodyOpacity.value.clamp(0, 1.0);
    if (hasBody && opacity < 1) {
      // The pill stays opaque while the body fades.
      canvas.drawPath(_path(body: 0), _pillPaint..color = fill);
    }
    final color = hasBody ? fill.withValues(alpha: fill.a * opacity) : fill;
    canvas
      ..drawPath(_path(), _bodyPaint..color = color)
      ..restore();
  }

  @override
  bool? hitTest(Offset position) {
    var y = position.dy - verticalInset;
    if (flipped) y = toastHeight.value - y;
    final path = _path();
    for (final dy in [0, -verticalInset, verticalInset]) {
      if (path.contains(Offset(position.dx, y + dy))) return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(SileoShapePainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.roundness != roundness ||
      oldDelegate.width != width ||
      oldDelegate.headerHeight != headerHeight ||
      oldDelegate.flipped != flipped ||
      oldDelegate.verticalInset != verticalInset ||
      oldDelegate.neck != neck ||
      oldDelegate.neckHeight != neckHeight ||
      oldDelegate.pillX != pillX ||
      oldDelegate.pillWidth != pillWidth ||
      oldDelegate.bodyHeight != bodyHeight ||
      oldDelegate.bodyOpacity != bodyOpacity ||
      oldDelegate.toastHeight != toastHeight;
}
