import 'package:flutter/widgets.dart';

/// Where a toast viewport sits. Physical, so it does not flip in RTL.
enum SileoPosition {
  /// Top, left edge.
  topLeft,

  /// Top, centered.
  topCenter,

  /// Top, right edge.
  topRight,

  /// Bottom, left edge.
  bottomLeft,

  /// Bottom, centered.
  bottomCenter,

  /// Bottom, right edge.
  bottomRight;

  /// Whether the viewport hugs the top edge.
  bool get isTop => switch (this) {
    topLeft || topCenter || topRight => true,
    bottomLeft || bottomCenter || bottomRight => false,
  };

  /// Where the pill sits inside the toast box.
  Alignment get pillAlign => switch (this) {
    topLeft => Alignment.topLeft,
    topCenter => Alignment.topCenter,
    topRight => Alignment.topRight,
    bottomLeft => Alignment.bottomLeft,
    bottomCenter => Alignment.bottomCenter,
    bottomRight => Alignment.bottomRight,
  };
}
