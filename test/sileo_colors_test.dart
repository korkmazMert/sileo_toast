// Spec: plan §7.1 Colors and Theme fills; §9 "Theme and constants".
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sileo_toast/sileo_toast.dart';

int _rgb(Color c) => c.toARGB32() & 0xFFFFFF;

void main() {
  group('state colors', () {
    const defaults = SileoStateColors();

    // Mutation: any hex changed -> that row fails.
    test('defaults equal the spec hexes', () {
      expect(defaults.success, const Color(0xFF22C55E));
      expect(defaults.loading, const Color(0xFF737373));
      expect(defaults.error, const Color(0xFFEF4444));
      expect(defaults.warning, const Color(0xFFEAB308));
      expect(defaults.info, const Color(0xFF0EA5E9));
      expect(defaults.action, const Color(0xFF3B82F6));
    });

    // Mutation: two switch arms swapped in of() -> fails.
    test('of(state) maps each state to its own tone', () {
      expect(defaults.of(SileoState.success), const Color(0xFF22C55E));
      expect(defaults.of(SileoState.loading), const Color(0xFF737373));
      expect(defaults.of(SileoState.error), const Color(0xFFEF4444));
      expect(defaults.of(SileoState.warning), const Color(0xFFEAB308));
      expect(defaults.of(SileoState.info), const Color(0xFF0EA5E9));
      expect(defaults.of(SileoState.action), const Color(0xFF3B82F6));
    });

    test('copyWith replaces only the given tone', () {
      const red = Color(0xFFFF0000);
      final custom = defaults.copyWith(info: red);
      expect(custom.of(SileoState.info), red);
      expect(custom.of(SileoState.success), defaults.success);
      expect(custom, isNot(defaults));
    });
  });

  group('theme fills', () {
    // Mutation: light/dark arms swapped (Sileo inverts: light app, dark toast).
    test('light -> #1A1A1A fill, white 50% description', () {
      final f = SileoFill.resolve(SileoThemeMode.light, Brightness.dark);
      expect(f.fill, const Color(0xFF1A1A1A));
      expect(_rgb(f.description!), 0xFFFFFF);
      expect(f.description!.a, closeTo(0.5, 0.01));
    });

    test('dark -> #F2F2F2 fill, black 50% description', () {
      final f = SileoFill.resolve(SileoThemeMode.dark, Brightness.light);
      expect(f.fill, const Color(0xFFF2F2F2));
      expect(_rgb(f.description!), 0x000000);
      expect(f.description!.a, closeTo(0.5, 0.01));
    });

    test('no theme -> #FFFFFF fill and no description color', () {
      final f = SileoFill.resolve(null, Brightness.dark);
      expect(f.fill, const Color(0xFFFFFFFF));
      expect(f.description, isNull);
    });

    // Mutation: system ignores the platform brightness.
    test('system follows the platform brightness', () {
      expect(
        SileoFill.resolve(SileoThemeMode.system, Brightness.dark).fill,
        const Color(0xFFF2F2F2),
      );
      expect(
        SileoFill.resolve(SileoThemeMode.system, Brightness.light).fill,
        const Color(0xFF1A1A1A),
      );
    });
  });

  group('package purity', () {
    // Mutation: any lib file imports material/cupertino -> fails.
    test('lib imports no material or cupertino', () {
      final offenders =
          Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .where((f) {
                final src = f.readAsStringSync();
                return src.contains('flutter/material') ||
                    src.contains('flutter/cupertino') ||
                    src.contains('material_ui') ||
                    src.contains('cupertino_ui');
              })
              .map((f) => f.path)
              .toList();
      expect(offenders, isEmpty);
    });
  });
}
