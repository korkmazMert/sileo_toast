import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sileo_toast/sileo_toast.dart';

MediaQueryData _ios(double top, double w, double h) => MediaQueryData(
  size: Size(w, h),
  padding: EdgeInsets.only(top: top),
  viewPadding: EdgeInsets.only(top: top),
);

MediaQueryData _android(List<Rect> holes, {Size size = const Size(412, 915)}) =>
    MediaQueryData(
      size: size,
      padding: const EdgeInsets.only(top: 40),
      displayFeatures: [
        for (final r in holes)
          DisplayFeature(
            bounds: r,
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
      ],
    );

void main() {
  group('iOS table', () {
    const rows = <(String, double, double, double)>[
      ('14 Pro / 15 / 16', 59, 393, 852),
      ('Pro Max / Plus', 59, 430, 932),
      ('16 Pro / 17 Pro', 62, 402, 874),
      ('16 Pro Max / 17 Pro Max', 62, 440, 956),
    ];
    for (final (name, top, w, h) in rows) {
      test('row $name', () {
        final r = SileoIsland.detect(_ios(top, w, h));
        expect(r, isNotNull);
        expect(r!.center.dx, closeTo(w / 2, 0.01));
        expect(r.width, greaterThan(100));
        expect(r.top, greaterThan(5));
        expect(r.top, lessThan(top));
        expect(r.bottom, lessThan(top + 10));
      });
    }

    test('59 pt row is 126x37 at 11.6', () {
      final r = SileoIsland.detect(_ios(59, 393, 852))!;
      expect(r, const Rect.fromLTWH(133.5, 11.6, 126, 37));
    });

    test('62 pt rows are 126x37 at 14, centered', () {
      expect(
        SileoIsland.detect(_ios(62, 402, 874)),
        const Rect.fromLTWH(138, 14, 126, 37),
      );
      expect(
        SileoIsland.detect(_ios(62, 440, 956)),
        const Rect.fromLTWH(157, 14, 126, 37),
      );
    });

    test('unmeasured iPhone Air (68 pt) falls back to null', () {
      expect(SileoIsland.detect(_ios(68, 420, 912)), isNull);
    });

    test('landscape is null', () {
      expect(SileoIsland.detect(_ios(59, 852, 393)), isNull);
    });

    test('unknown size (Display Zoom) is null', () {
      expect(SileoIsland.detect(_ios(59, 375, 667)), isNull);
      expect(SileoIsland.detect(_ios(59, 320, 693)), isNull);
    });

    test('notch tops 47/48/50 are null', () {
      for (final t in [47.0, 48.0, 50.0]) {
        expect(SileoIsland.detect(_ios(t, 393, 852)), isNull);
        expect(SileoIsland.detect(_ios(t, 430, 932)), isNull);
      }
    });

    test('iPad is null', () {
      expect(SileoIsland.detect(_ios(24, 820, 1180)), isNull);
    });

    test('non-empty displayFeatures skip the table', () {
      final data = _ios(59, 393, 852).copyWith(
        displayFeatures: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 0, 10, 10),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );
      expect(SileoIsland.detect(data), isNull);
    });
  });

  group('Android cutout', () {
    test('centered hole returns bounds', () {
      const hole = Rect.fromLTWH(186, 8, 40, 40);
      expect(SileoIsland.detect(_android([hole])), hole);
    });

    test('corner hole is null', () {
      expect(
        SileoIsland.detect(_android([const Rect.fromLTWH(20, 8, 40, 40)])),
        isNull,
      );
    });

    test('two cutouts: picks the centered one', () {
      const hole = Rect.fromLTWH(186, 8, 40, 40);
      expect(
        SileoIsland.detect(
          _android([const Rect.fromLTWH(20, 8, 40, 40), hole]),
        ),
        hole,
      );
    });

    test('two off-center cutouts is null', () {
      expect(
        SileoIsland.detect(
          _android([
            const Rect.fromLTWH(20, 8, 40, 40),
            const Rect.fromLTWH(350, 8, 40, 40),
          ]),
        ),
        isNull,
      );
    });

    test('too wide is null', () {
      expect(
        SileoIsland.detect(_android([const Rect.fromLTWH(56, 8, 300, 40)])),
        isNull,
      );
    });

    test('cutout not above the status bar is null', () {
      expect(
        SileoIsland.detect(_android([const Rect.fromLTWH(186, 60, 40, 40)])),
        isNull,
      );
    });
  });

  group('options', () {
    test('size/trailing/secondaryButton merge per field', () {
      const t = SizedBox();
      final b = SileoButton(title: 'x', onPressed: () {});
      final merged = const SileoOptions().mergeWith(
        SileoOptions(size: SileoSize.large, trailing: t, secondaryButton: b),
      );
      expect(merged.size, SileoSize.large);
      expect(merged.trailing, t);
      expect(merged.secondaryButton, b);
      expect(
        const SileoOptions(size: SileoSize.compact)
            .mergeWith(const SileoOptions(size: SileoSize.large))
            .size,
        SileoSize.compact,
      );
      expect(merged.copyWith(size: SileoSize.compact).secondaryButton, b);
    });

    test('island position is top and top-centered', () {
      expect(SileoPosition.island.isTop, isTrue);
      expect(SileoPosition.island.pillAlign, Alignment.topCenter);
    });
  });
}
