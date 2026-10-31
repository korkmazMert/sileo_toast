import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sileo_toast/sileo_toast.dart';

import 'package:sileo_toast_example/playground_choices.dart';

const _descriptionAlpha = 0.75;

/// Builds the options for one toast from [settings].
///
/// Everything it needs is passed in, never read from a `BuildContext`: a
/// promise's callbacks and a leftover toast's button run after the page may
/// be gone.
SileoOptions buildOptions(
  PlaygroundSettings settings,
  String title, {
  required String id,
  required SileoController controller,
  Widget? trailing,
  Widget? icon,
  bool? button,
}) {
  final fill = settings.fill;
  final large = settings.large;
  final second = settings.secondButton && large;
  return SileoOptions(
    title: title,
    description: settings.description
        ? SileoOptions.text('This is the description of the toast.')
        : null,
    position: settings.position,
    duration: settings.duration.value,
    persistent: settings.duration == DurationChoice.persistent,
    icon: icon,
    fill: fill.fill,
    styles: fill.onFill == null
        ? null
        : SileoStyles(
            description: TextStyle(
              color: fill.onFill!.withValues(alpha: _descriptionAlpha),
            ),
          ),
    roundness: settings.roundness,
    autopilot: settings.autopilot.value,
    size: settings.size,
    trailing: large ? trailing : null,
    // A toast's buttons dismiss their own toast.
    secondaryButton: second
        ? SileoButton(title: 'Decline', onPressed: () => controller.dismiss(id))
        : null,
    button: (button ?? settings.button)
        ? SileoButton(
            title: second ? 'Accept' : 'Undo',
            onPressed: () => controller.dismiss(id),
          )
        : null,
    id: id,
  );
}

/// Shows the toast built by [show] with [title].
String fireToast(
  SileoController controller,
  PlaygroundSettings settings,
  String title,
  String Function(SileoController, SileoOptions) show, {
  required String id,
  Widget? trailing,
  Widget? icon,
  bool? button,
}) => show(
  controller,
  buildOptions(
    settings,
    title,
    id: id,
    controller: controller,
    trailing: trailing,
    icon: icon,
    button: button,
  ),
);

/// A loading toast that settles after [promiseDelay] as the chosen outcome.
void firePromise(
  SileoController controller,
  PlaygroundSettings settings, {
  required String id,
  Widget? trailing,
}) {
  final outcome = settings.outcome;
  SileoOptions options(String title, {bool? button}) => buildOptions(
    settings,
    title,
    id: id,
    controller: controller,
    trailing: trailing,
    button: button,
  );
  final future = Future<void>.delayed(
    promiseDelay,
    () => outcome == OutcomeChoice.error ? throw StateError('demo') : null,
  );
  unawaited(
    controller
        .promise<void>(
          future,
          SileoPromiseOptions(
            loading: options('Sending...'),
            success: (_) => options('Sent'),
            error: (_) => options('Send failed'),
            action: outcome == OutcomeChoice.action
                ? (_) => options('Update available', button: true)
                : null,
          ),
        )
        .catchError((Object _) {}),
  );
}

/// Dismisses the most recent toast that is not already leaving.
void dismissLatest(SileoController controller) {
  final live = controller.items.where((i) => !i.exiting);
  if (live.isNotEmpty) controller.dismiss(live.last.id);
}
