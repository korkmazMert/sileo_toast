import 'package:material_ui/material_ui.dart';
import 'package:sileo_toast/sileo_toast.dart';

import 'package:sileo_toast_example/playground_choices.dart';

/// Every option of a toast; changes go out as a whole new [PlaygroundSettings].
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.settings,
    required this.onChanged,
    super.key,
  });

  final PlaygroundSettings settings;
  final ValueChanged<PlaygroundSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final large = s.large;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChoiceGroup<SileoPosition>(
          label: 'Position',
          values: SileoPosition.values,
          labelOf: (v) => v.label,
          selected: s.position,
          onSelected: (v) => onChanged(s.copyWith(position: v)),
        ),
        _ChoiceGroup<SileoSize>(
          label: 'Size',
          values: SileoSize.values,
          labelOf: (v) => v.label,
          selected: s.size,
          onSelected: (v) => onChanged(s.copyWith(size: v)),
        ),
        _ChoiceGroup<FillChoice>(
          label: 'Fill',
          values: FillChoice.values,
          labelOf: (v) => v.label,
          selected: s.fill,
          onSelected: (v) => onChanged(s.copyWith(fill: v)),
        ),
        _ChoiceGroup<double>(
          label: 'Roundness',
          values: roundnessChoices,
          labelOf: (v) => v.toInt().toString(),
          selected: s.roundness,
          onSelected: (v) => onChanged(s.copyWith(roundness: v)),
        ),
        _ChoiceGroup<DurationChoice>(
          label: 'Duration',
          values: DurationChoice.values,
          labelOf: (v) => v.label,
          selected: s.duration,
          onSelected: (v) => onChanged(s.copyWith(duration: v)),
        ),
        _ChoiceGroup<AutopilotChoice>(
          label: 'Autopilot',
          values: AutopilotChoice.values,
          labelOf: (v) => v.label,
          selected: s.autopilot,
          onSelected: (v) => onChanged(s.copyWith(autopilot: v)),
        ),
        SwitchListTile(
          title: const Text('Description'),
          value: s.description,
          onChanged: (v) => onChanged(s.copyWith(description: v)),
        ),
        SwitchListTile(
          title: const Text('Button'),
          value: s.button,
          onChanged: (v) => onChanged(s.copyWith(button: v)),
        ),
        SwitchListTile(
          title: const Text('Trailing image'),
          subtitle: large ? null : const Text('Large size only'),
          value: s.trailing,
          onChanged: large ? (v) => onChanged(s.copyWith(trailing: v)) : null,
        ),
        SwitchListTile(
          title: const Text('Second button'),
          subtitle:
              !large
                  ? const Text('Large size only')
                  : s.button
                  ? null
                  : const Text('Turn on Button first'),
          value: s.secondButton,
          onChanged:
              large && s.button
                  ? (v) => onChanged(s.copyWith(secondButton: v))
                  : null,
        ),
        SwitchListTile(
          title: const Text('Separate id'),
          subtitle: const Text(
            'Off: a new toast morphs the visible one. '
            'On: toasts stack.',
          ),
          value: s.separateId,
          onChanged: (v) => onChanged(s.copyWith(separateId: v)),
        ),
      ],
    );
  }
}

/// A labelled wrap of single-choice chips.
class _ChoiceGroup<T> extends StatelessWidget {
  const _ChoiceGroup({
    required this.label,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                ChoiceChip(
                  label: Text(labelOf(v)),
                  selected: v == selected,
                  onSelected: (_) => onSelected(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
