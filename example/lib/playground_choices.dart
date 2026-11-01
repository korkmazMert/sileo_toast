import 'dart:ui' show Color;

import 'package:sileo_toast/sileo_toast.dart';

/// Every toast of the playground shares this id while "Separate id" is off,
/// so a new one morphs the visible one (a promise included).
const morphId = 'sileo-playground';

/// How long the demo promise takes to settle.
const promiseDelay = Duration(milliseconds: 2500);

/// Corner radii offered by the Roundness chips.
const roundnessChoices = [0.0, 8.0, 12.0, 16.0, 24.0];

const _customAutopilot = SileoAutopilot(
  expand: Duration(milliseconds: 500),
  collapse: Duration(seconds: 3),
);

/// Toast fills: the theme's own, Sileo's two documented ones, and a custom one.
enum FillChoice {
  standard('Default', null, null),
  sileoLight('Sileo light', Color(0xFF1A1A1A), Color(0xFFFFFFFF)),
  sileoDark('Sileo dark', Color(0xFFF2F2F2), Color(0xFF000000)),
  custom('Custom blue', Color(0xFF1E3A8A), Color(0xFFFFFFFF));

  const FillChoice(this.label, this.fill, this.onFill);

  final String label;

  /// Null keeps the toaster theme's fill.
  final Color? fill;

  /// The color that reads on [fill].
  final Color? onFill;
}

enum DurationChoice {
  short('2 s', Duration(seconds: 2)),
  long('6 s', Duration(seconds: 6)),
  persistent('Persistent', null);

  const DurationChoice(this.label, this.value);

  final String label;
  final Duration? value;
}

enum AutopilotChoice {
  standard('Default', SileoAutopilot()),
  off('Off', SileoAutopilot.off),
  custom('Custom (500 ms / 3 s)', _customAutopilot);

  const AutopilotChoice(this.label, this.value);

  final String label;
  final SileoAutopilot value;
}

/// How the demo promise settles.
enum OutcomeChoice {
  success('Success'),
  error('Error'),
  action('Action');

  const OutcomeChoice(this.label);

  final String label;
}

extension SileoPositionLabel on SileoPosition {
  String get label => switch (this) {
    SileoPosition.topLeft => 'Top left',
    SileoPosition.topCenter => 'Top center',
    SileoPosition.topRight => 'Top right',
    SileoPosition.bottomLeft => 'Bottom left',
    SileoPosition.bottomCenter => 'Bottom center',
    SileoPosition.bottomRight => 'Bottom right',
  };
}

extension SileoSizeLabel on SileoSize {
  String get label => switch (this) {
    SileoSize.compact => 'Compact',
    SileoSize.large => 'Large',
  };
}

/// The playground's options, replaced as a whole on every change.
class PlaygroundSettings {
  const PlaygroundSettings({
    this.position = SileoPosition.topRight,
    this.size = SileoSize.compact,
    this.description = true,
    this.button = false,
    this.trailing = false,
    this.secondButton = false,
    this.fill = FillChoice.standard,
    this.roundness = 16,
    this.duration = DurationChoice.long,
    this.autopilot = AutopilotChoice.standard,
    this.outcome = OutcomeChoice.success,
    this.separateId = false,
  });

  final SileoPosition position;
  final SileoSize size;
  final bool description;
  final bool button;
  final bool trailing;
  final bool secondButton;
  final FillChoice fill;
  final double roundness;
  final DurationChoice duration;
  final AutopilotChoice autopilot;
  final OutcomeChoice outcome;
  final bool separateId;

  bool get large => size == SileoSize.large;

  PlaygroundSettings copyWith({
    SileoPosition? position,
    SileoSize? size,
    bool? description,
    bool? button,
    bool? trailing,
    bool? secondButton,
    FillChoice? fill,
    double? roundness,
    DurationChoice? duration,
    AutopilotChoice? autopilot,
    OutcomeChoice? outcome,
    bool? separateId,
  }) {
    final nextButton = button ?? this.button;
    return PlaygroundSettings(
      position: position ?? this.position,
      size: size ?? this.size,
      description: description ?? this.description,
      button: nextButton,
      trailing: trailing ?? this.trailing,
      // A second button needs the first one.
      secondButton: nextButton && (secondButton ?? this.secondButton),
      fill: fill ?? this.fill,
      roundness: roundness ?? this.roundness,
      duration: duration ?? this.duration,
      autopilot: autopilot ?? this.autopilot,
      outcome: outcome ?? this.outcome,
      separateId: separateId ?? this.separateId,
    );
  }
}
