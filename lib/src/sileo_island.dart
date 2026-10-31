import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/widgets.dart';
import 'package:sileo_toast/src/constants.dart';

/// Returns the camera cutout rect in logical pixels, or null for "no island".
typedef SileoIslandResolver = Rect? Function(MediaQueryData data);

/// Island geometry from [MediaQueryData] alone (no platform channels).
abstract final class SileoIsland {
  /// Android: a top-centered cutout from `displayFeatures`. iOS: a portrait
  /// table lookup by (`viewPadding.top`, screen size). Otherwise null.
  static Rect? detect(MediaQueryData data) {
    final size = data.size;
    if (data.displayFeatures.isNotEmpty) {
      for (final f in data.displayFeatures) {
        final b = f.bounds;
        if (f.type == DisplayFeatureType.cutout &&
            b.top < data.padding.top &&
            (b.center.dx - size.width / 2).abs() <=
                SileoConstants.islandCenterTolerance &&
            b.width <= SileoConstants.islandMaxWidth) {
          return b;
        }
      }
      return null;
    }
    if (size.height <= size.width) return null;
    const tol = SileoConstants.islandKeyTolerance;
    for (final (top, w, h, iw, ih, it) in SileoConstants.islandTable) {
      if ((data.viewPadding.top - top).abs() <= tol &&
          (size.width - w).abs() <= tol &&
          (size.height - h).abs() <= tol) {
        return Rect.fromLTWH((size.width - iw) / 2, it, iw, ih);
      }
    }
    return null;
  }
}
