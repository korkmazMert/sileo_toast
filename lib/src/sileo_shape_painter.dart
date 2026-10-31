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

  /// The outline in a top-edge frame: pill at y 0..[headerHeight], body
  /// below it. Just the pill rrect while the body is under half a dp.
  static Path buildPath({
    required double width,
    required double pillX,
    required double pillWidth,
    required double headerHeight,
    required double bodyHeight,
    required double roundness,
    Path? into,
  }) {
    final path = (into?..reset()) ?? Path();
    const eps = SileoConstants.shapeEpsilon;
    final left = _atLeast0(pillX);
    final right = math.min(width, pillX + pillWidth);
    final pill = _atLeast0(right - left);
    final r = _atLeast0(roundness);
    final pr = math.min(r, math.min(pill, headerHeight) / 2);
    if (bodyHeight < eps) {
      return path..addRRect(
        RRect.fromLTRBR(left, 0, right, headerHeight, Radius.circular(pr)),
      );
    }

    final gapL = left;
    final gapR = width - right;
    final flushL = gapL < eps;
    final flushR = gapR < eps;
    final fillet = r * SileoConstants.blurRatio;
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

    // Clockwise from the pill top edge.
    path
      ..moveTo(left + pr, 0)
      ..lineTo(right - pr, 0)
      ..arcToPoint(Offset(right, pr), radius: Radius.circular(pr));
    if (flushR) {
      path
        ..lineTo(right, bottom - rb)
        ..arcToPoint(Offset(right - rb, bottom), radius: Radius.circular(rb));
    } else {
      path
        ..lineTo(right, headerHeight - fR)
        ..arcToPoint(
          Offset(right + fR, headerHeight),
          radius: Radius.circular(fR),
          clockwise: false,
        )
        ..lineTo(width - rtR, headerHeight);
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
    if (flushL) {
      path.lineTo(left, pr);
    } else {
      path.lineTo(0, headerHeight + rtL);
      if (rtL > 0) {
        path.arcToPoint(
          Offset(rtL, headerHeight),
          radius: Radius.circular(rtL),
        );
      }
      path
        ..lineTo(left - fL, headerHeight)
        ..arcToPoint(
          Offset(left, headerHeight - fL),
          radius: Radius.circular(fL),
          clockwise: false,
        )
        ..lineTo(left, pr);
    }
    return path
      ..arcToPoint(Offset(left + pr, 0), radius: Radius.circular(pr))
      ..close();
  }

  // One path and two paints per painter, reused every frame. The faded pill
  // and the body need separate paints because a recording canvas keeps them.
  final Path _shape = Path();
  final Paint _pillPaint = Paint();
  final Paint _bodyPaint = Paint();

  Path _path({double? body}) => buildPath(
    into: _shape,
    width: width,
    pillX: pillX.value,
    pillWidth: pillWidth.value,
    headerHeight: headerHeight,
    bodyHeight: body ?? bodyHeight.value,
    roundness: roundness,
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
      oldDelegate.pillX != pillX ||
      oldDelegate.pillWidth != pillWidth ||
      oldDelegate.bodyHeight != bodyHeight ||
      oldDelegate.bodyOpacity != bodyOpacity ||
      oldDelegate.toastHeight != toastHeight;
}
