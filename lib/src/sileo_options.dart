import 'package:flutter/widgets.dart';
import 'package:sileo_toast/src/sileo_position.dart';
import 'package:sileo_toast/src/sileo_state.dart';

/// Autopilot: auto-expand then auto-collapse a toast with a finite duration.
@immutable
class SileoAutopilot {
  /// Creates autopilot settings; null delays use Sileo's defaults.
  const new({this.enabled = true, this.expand, this.collapse});

  /// Autopilot disabled.
  static const off = SileoAutopilot(enabled: false);

  /// Whether autopilot runs.
  final bool enabled;

  /// Delay before expanding.
  final Duration? expand;

  /// Delay before collapsing.
  final Duration? collapse;

  @override
  bool operator ==(Object other) =>
      other is SileoAutopilot &&
      other.enabled == enabled &&
      other.expand == expand &&
      other.collapse == collapse;

  @override
  int get hashCode => Object.hash(enabled, expand, collapse);
}

/// The action button of a toast.
@immutable
class SileoButton {
  /// Creates a button.
  const new({required this.title, required this.onPressed});

  /// Label.
  final String title;

  /// Tap callback.
  final VoidCallback onPressed;
}

/// Toast scale.
enum SileoSize {
  /// The classic small pill.
  compact,

  /// Bigger pill that opens into a full-width card.
  large,
}

/// Per-part style overrides; merged per field.
@immutable
class SileoStyles {
  /// Creates overrides.
  const new({
    this.title,
    this.description,
    this.badgeBackground,
    this.badgeForeground,
    this.buttonForeground,
    this.buttonBackground,
    this.buttonPressedBackground,
  });

  /// Title text style.
  final TextStyle? title;

  /// Description text style.
  final TextStyle? description;

  /// Badge background.
  final Color? badgeBackground;

  /// Badge icon color.
  final Color? badgeForeground;

  /// Button label color.
  final Color? buttonForeground;

  /// Button background.
  final Color? buttonBackground;

  /// Pressed button background.
  final Color? buttonPressedBackground;

  /// Fields set here win; the rest come from [defaults].
  SileoStyles mergeWith(SileoStyles? defaults) => SileoStyles(
    title: title ?? defaults?.title,
    description: description ?? defaults?.description,
    badgeBackground: badgeBackground ?? defaults?.badgeBackground,
    badgeForeground: badgeForeground ?? defaults?.badgeForeground,
    buttonForeground: buttonForeground ?? defaults?.buttonForeground,
    buttonBackground: buttonBackground ?? defaults?.buttonBackground,
    buttonPressedBackground:
        buttonPressedBackground ?? defaults?.buttonPressedBackground,
  );
}

/// Options of one toast. Immutable.
@immutable
class SileoOptions {
  /// Creates options. A [duration] of zero or less means persistent.
  const new({
    this.title,
    this.description,
    this.type,
    this.position,
    this.duration,
    this.persistent = false,
    this.icon,
    this.styles,
    this.fill,
    this.roundness,
    this.autopilot = const SileoAutopilot(),
    this.button,
    this.id,
    this.size,
    this.trailing,
    this.secondaryButton,
  });

  /// Wraps a plain string as a description.
  static Widget text(String value) => Text(value);

  /// Title; the capitalized state name when null.
  final String? title;

  /// Description shown when expanded.
  final Widget? description;

  /// Kind of toast.
  final SileoState? type;

  /// Viewport; the controller default when null.
  final SileoPosition? position;

  /// Auto-dismiss delay; null means the default.
  final Duration? duration;

  /// Never auto-dismiss (Sileo's `duration: null`).
  final bool persistent;

  /// Custom badge icon; takes the tone through `IconTheme`.
  final Widget? icon;

  /// Style overrides.
  final SileoStyles? styles;

  /// Fill override.
  final Color? fill;

  /// Corner roundness override.
  final double? roundness;

  /// Autopilot settings.
  final SileoAutopilot autopilot;

  /// Optional action button.
  final SileoButton? button;

  /// Toast id; toasts with the same id morph into each other.
  final String? id;

  /// Scale; the toaster default, then compact, when null.
  final SileoSize? size;

  /// Large-size thumbnail, clipped to a square; compact ignores it.
  final Widget? trailing;

  /// Large-size secondary action (left of [button]); compact ignores it.
  final SileoButton? secondaryButton;

  /// Copy with fields replaced; null arguments keep the current value.
  SileoOptions copyWith({
    String? title,
    Widget? description,
    SileoState? type,
    SileoPosition? position,
    Duration? duration,
    bool? persistent,
    Widget? icon,
    SileoStyles? styles,
    Color? fill,
    double? roundness,
    SileoAutopilot? autopilot,
    SileoButton? button,
    String? id,
    SileoSize? size,
    Widget? trailing,
    SileoButton? secondaryButton,
  }) => SileoOptions(
    title: title ?? this.title,
    description: description ?? this.description,
    type: type ?? this.type,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    persistent: persistent ?? this.persistent,
    icon: icon ?? this.icon,
    styles: styles ?? this.styles,
    fill: fill ?? this.fill,
    roundness: roundness ?? this.roundness,
    autopilot: autopilot ?? this.autopilot,
    button: button ?? this.button,
    id: id ?? this.id,
    size: size ?? this.size,
    trailing: trailing ?? this.trailing,
    secondaryButton: secondaryButton ?? this.secondaryButton,
  );

  /// Fields set here win; the rest come from [defaults]. Styles merge per
  /// field; autopilot falls back to the defaults while it is untouched.
  SileoOptions mergeWith(SileoOptions? defaults) {
    if (defaults == null) return this;
    return SileoOptions(
      title: title ?? defaults.title,
      description: description ?? defaults.description,
      type: type ?? defaults.type,
      position: position ?? defaults.position,
      duration: duration ?? defaults.duration,
      persistent: persistent || defaults.persistent,
      icon: icon ?? defaults.icon,
      styles: styles == null
          ? defaults.styles
          : styles!.mergeWith(defaults.styles),
      fill: fill ?? defaults.fill,
      roundness: roundness ?? defaults.roundness,
      autopilot: autopilot == const SileoAutopilot()
          ? defaults.autopilot
          : autopilot,
      button: button ?? defaults.button,
      id: id ?? defaults.id,
      size: size ?? defaults.size,
      trailing: trailing ?? defaults.trailing,
      secondaryButton: secondaryButton ?? defaults.secondaryButton,
    );
  }
}

/// Options for `SileoController.promise`.
@immutable
class SileoPromiseOptions<T> {
  /// Creates promise options.
  const new({
    required this.loading,
    required this.success,
    required this.error,
    this.action,
  });

  /// Shown while pending (persistent).
  final SileoOptions loading;

  /// Shown on success, unless [action] is set.
  final SileoOptions Function(T data) success;

  /// Shown on failure.
  final SileoOptions Function(Object error) error;

  /// When set, shown instead of [success] on success.
  final SileoOptions Function(T data)? action;
}
