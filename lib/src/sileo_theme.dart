// Brightness is re-exported by widgets.dart only on newer Flutter; keep the
// import so older supported versions compile.
// ignore: unnecessary_import
import 'dart:ui' show Brightness;

import 'package:flutter/widgets.dart';
import 'package:sileo_toast/src/constants.dart';
import 'package:sileo_toast/src/sileo_state.dart';

/// Which Sileo fill a toast uses. `light` gives a dark toast and vice versa.
enum SileoThemeMode {
  /// Dark toast fill, for light apps.
  light,

  /// Light toast fill, for dark apps.
  dark,

  /// Follows [MediaQuery.platformBrightnessOf].
  system,
}

/// Tone color per [SileoState].
@immutable
class SileoStateColors {
  /// Creates a palette; defaults are Sileo's.
  const SileoStateColors({
    this.success = SileoConstants.success,
    this.loading = SileoConstants.loading,
    this.error = SileoConstants.error,
    this.warning = SileoConstants.warning,
    this.info = SileoConstants.info,
    this.action = SileoConstants.action,
  });

  /// Success tone.
  final Color success;

  /// Loading tone.
  final Color loading;

  /// Error tone.
  final Color error;

  /// Warning tone.
  final Color warning;

  /// Info tone.
  final Color info;

  /// Action tone.
  final Color action;

  /// The tone for [state].
  Color of(SileoState state) => switch (state) {
    SileoState.success => success,
    SileoState.loading => loading,
    SileoState.error => error,
    SileoState.warning => warning,
    SileoState.info => info,
    SileoState.action => action,
  };

  /// Copy with some tones replaced.
  SileoStateColors copyWith({
    Color? success,
    Color? loading,
    Color? error,
    Color? warning,
    Color? info,
    Color? action,
  }) => SileoStateColors(
    success: success ?? this.success,
    loading: loading ?? this.loading,
    error: error ?? this.error,
    warning: warning ?? this.warning,
    info: info ?? this.info,
    action: action ?? this.action,
  );

  @override
  bool operator ==(Object other) =>
      other is SileoStateColors &&
      other.success == success &&
      other.loading == loading &&
      other.error == error &&
      other.warning == warning &&
      other.info == info &&
      other.action == action;

  @override
  int get hashCode =>
      Object.hash(success, loading, error, warning, info, action);
}

/// Resolved toast fill and description color.
@immutable
class SileoFill {
  /// Creates a fill.
  const SileoFill({required this.fill, this.description});

  /// Resolves [mode] against [platformBrightness] (used by `system`).
  ///
  /// A null [mode] gives the white fill and no description color, so the
  /// description inherits the toaster's text style.
  factory SileoFill.resolve(
    SileoThemeMode? mode,
    Brightness platformBrightness,
  ) {
    final resolved =
        mode == SileoThemeMode.system
            ? (platformBrightness == Brightness.dark
                ? SileoThemeMode.dark
                : SileoThemeMode.light)
            : mode;
    return switch (resolved) {
      SileoThemeMode.light => SileoFill(
        fill: SileoConstants.lightFill,
        description: SileoConstants.lightDescription.withValues(
          alpha: SileoConstants.descriptionAlpha,
        ),
      ),
      SileoThemeMode.dark => SileoFill(
        fill: SileoConstants.darkFill,
        description: SileoConstants.darkDescription.withValues(
          alpha: SileoConstants.descriptionAlpha,
        ),
      ),
      _ => const SileoFill(fill: SileoConstants.defaultFill),
    };
  }

  /// Toast background.
  final Color fill;

  /// Description color, or null to inherit.
  final Color? description;

  @override
  bool operator ==(Object other) =>
      other is SileoFill &&
      other.fill == fill &&
      other.description == description;

  @override
  int get hashCode => Object.hash(fill, description);
}
