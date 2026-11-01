import 'package:flutter/widgets.dart';
import 'package:sileo_toast/src/constants.dart';

/// The Lucide icons Sileo uses.
enum SileoIcon {
  /// Check.
  check,

  /// X.
  x,

  /// Circle alert.
  circleAlert,

  /// Life buoy.
  lifeBuoy,

  /// Arrow right.
  arrowRight,

  /// Loader circle (arc).
  loaderCircle,
}

/// Paints a [SileoIcon] stroked in [color], scaled from the 24-unit viewBox.
class SileoIconPainter extends CustomPainter {
  /// Creates a painter.
  const SileoIconPainter({required this.icon, required this.color});

  /// Icon to draw.
  final SileoIcon icon;

  /// Stroke color.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const box = SileoConstants.iconViewBox;
    canvas
      ..scale(size.width / box, size.height / box)
      ..drawPath(
        _path(icon),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = SileoConstants.iconStroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
  }

  @override
  bool shouldRepaint(SileoIconPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color;

  // Path data copied from Sileo's `icons.tsx` (Lucide, 24-unit viewBox).
  static Path _path(SileoIcon icon) {
    final p = Path();
    switch (icon) {
      case SileoIcon.check:
        p
          ..moveTo(20, 6)
          ..lineTo(9, 17)
          ..relativeLineTo(-5, -5);
      case SileoIcon.x:
        p
          ..moveTo(18, 6)
          ..lineTo(6, 18)
          ..moveTo(6, 6)
          ..relativeLineTo(12, 12);
      case SileoIcon.circleAlert:
        p
          ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 10))
          ..moveTo(12, 8)
          ..lineTo(12, 12)
          ..moveTo(12, 16)
          ..lineTo(12.01, 16);
      case SileoIcon.lifeBuoy:
        p
          ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 10))
          ..moveTo(4.93, 4.93)
          ..relativeLineTo(4.24, 4.24)
          ..moveTo(14.83, 9.17)
          ..relativeLineTo(4.24, -4.24)
          ..moveTo(14.83, 14.83)
          ..relativeLineTo(4.24, 4.24)
          ..moveTo(9.17, 14.83)
          ..relativeLineTo(-4.24, 4.24)
          ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 4));
      case SileoIcon.arrowRight:
        p
          ..moveTo(5, 12)
          ..relativeLineTo(14, 0)
          ..moveTo(12, 5)
          ..relativeLineTo(7, 7)
          ..relativeLineTo(-7, 7);
      case SileoIcon.loaderCircle:
        p
          ..moveTo(21, 12)
          ..arcToPoint(
            const Offset(14.781, 3.44),
            radius: const Radius.circular(9),
            largeArc: true,
          );
    }
    return p;
  }
}
