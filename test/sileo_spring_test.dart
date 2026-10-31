// Spec: plan §7.1 Constants (physics spring, close spring, CSS spring curve);
// §9 "Theme and constants".
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sileo_toast/sileo_toast.dart';

void main() {
  group('sileoSpring (Motion findSpring(600, 0.25))', () {
    final sim = SpringSimulation(sileoSpring, 0, 1, 0);

    // Mutation: SpringDescription.withDurationAndBounce (peaks ~453 ms) or
    // other stiffness/damping -> peak value or time misses the window.
    test('peaks at 1.028 +-0.002 at 304 +-5 ms', () {
      var peak = 0.0;
      var peakMs = 0;
      for (var ms = 0; ms <= 1500; ms++) {
        final x = sim.x(ms / 1000);
        if (x > peak) {
          peak = x;
          peakMs = ms;
        }
      }
      expect(peak, closeTo(1.028, 0.002));
      expect(peakMs, closeTo(304, 5));
    });

    test('is within 0.005 of 1 from 600 ms on', () {
      for (var ms = 600; ms <= 3000; ms += 10) {
        expect(sim.x(ms / 1000), closeTo(1, 0.005), reason: '$ms ms');
      }
    });

    test('starts at 0 and is still far from 1 at 100 ms', () {
      expect(sim.x(0), 0);
      expect(sim.x(0.1), lessThan(0.6));
    });
  });

  group('sileoCloseSpring (Motion findSpring(600, 0))', () {
    final sim = SpringSimulation(sileoCloseSpring, 0, 1, 0);

    // Mutation: an under-damped close spring overshoots 1.
    test('never overshoots (critically damped)', () {
      for (var ms = 0; ms <= 2000; ms += 5) {
        expect(sim.x(ms / 1000), lessThanOrEqualTo(1.0 + 1e-9));
      }
    });

    test('settles within 0.002 of 1 by 600 ms', () {
      expect(sim.x(0.6), closeTo(1, 0.002));
    });
  });

  group('sileoSpringCurve (Sileo linear() table)', () {
    // Mutation: any table value altered or a stop dropped.
    test('returns Sileo stops exactly', () {
      expect(sileoSpringCurve.transform(0.45), closeTo(1.038, 1e-9));
      expect(sileoSpringCurve.transform(0.137), closeTo(0.467, 1e-9));
    });

    test('starts at 0 and ends at 1', () {
      expect(sileoSpringCurve.transform(0), 0);
      expect(sileoSpringCurve.transform(1), 1);
    });

    // Hand-computed: halfway between stops (0.45, 1.038) and (0.501, 1.035).
    test('interpolates linearly between stops', () {
      expect(sileoSpringCurve.transform(0.4755), closeTo(1.0365, 1e-9));
    });

    test('overshoots 1 around 45% and returns to 1', () {
      expect(sileoSpringCurve.transform(0.45), greaterThan(1));
      expect(sileoSpringCurve.transform(0.9), closeTo(1, 0.002));
    });
  });
}
