import 'package:flutter/animation.dart';
import 'package:sileo_toast/src/constants.dart';

/// Morph spring: Motion's `findSpring({duration: 600, bounce: 0.25})`.
///
/// With mass 1 and a 0.001 envelope: zeta = 0.75, omega = 15.63, so
/// stiffness = omega^2 = 244.29 and damping = 2 * zeta * omega = 23.44.
/// Peaks at 1.028 at ~304 ms. Not `SpringDescription.withDurationAndBounce`
/// (SwiftUI's perceptual duration, ~1.7x slower).
const sileoSpring = SpringDescription(
  mass: SileoConstants.springMass,
  stiffness: SileoConstants.springStiffness,
  damping: SileoConstants.springDamping,
);

/// Body-close spring: Motion's `findSpring({duration: 600, bounce: 0})`.
///
/// Critically damped: (1 + omega*t) * exp(-omega*t) = 0.001 gives
/// omega*t = 9.2334, omega = 15.389, so stiffness = omega^2 = 236.82 and
/// damping = 2 * omega = 30.78.
const sileoCloseSpring = SpringDescription(
  mass: SileoConstants.springMass,
  stiffness: SileoConstants.closeSpringStiffness,
  damping: SileoConstants.closeSpringDamping,
);

/// Sileo's `--sileo-spring-easing` as a piecewise-linear [Curve].
const Curve sileoSpringCurve = _SileoSpringCurve();

class _SileoSpringCurve extends Curve {
  const _SileoSpringCurve();

  @override
  double transformInternal(double t) {
    const stops = SileoConstants.springCurveStops;
    for (var i = 1; i < stops.length; i++) {
      final (x1, y1) = stops[i];
      if (t <= x1) {
        final (x0, y0) = stops[i - 1];
        return y1 - (y1 - y0) * (x1 - t) / (x1 - x0);
      }
    }
    return stops.last.$2;
  }
}
