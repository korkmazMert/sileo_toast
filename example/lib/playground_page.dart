import 'package:material_ui/material_ui.dart';
import 'package:sileo_toast/sileo_toast.dart';

import 'package:sileo_toast_example/playground_choices.dart';
import 'package:sileo_toast_example/playground_controls.dart';
import 'package:sileo_toast_example/playground_fire.dart';

/// Every option of a toast, then the buttons that fire one through
/// `Sileo.of`. The settings are this page's own state.
class PlaygroundPage extends StatefulWidget {
  const new({super.key});

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  var _settings = const PlaygroundSettings();
  var _counter = 0;

  String _nextId() =>
      _settings.separateId ? 'sileo-play-${_counter++}' : morphId;

  // Read before any async work; never touch `context` after an await.
  SileoController get _controller => Sileo.of(context);

  void _fire(
    String title,
    String Function(SileoController, SileoOptions) show, {
    Widget? icon,
    bool? button,
  }) => fireToast(
    _controller,
    _settings,
    title,
    show,
    id: _nextId(),
    trailing: _settings.trailing ? const TrailingArt() : null,
    icon: icon,
    button: button,
  );

  void _promise() => firePromise(
    _controller,
    _settings,
    id: _nextId(),
    trailing: _settings.trailing ? const TrailingArt() : null,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('sileo_toast')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Sileo is a physics-based, gooey toast. Tap or hover a '
                  'toast to expand it, swipe it away to dismiss it.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const _Heading('Settings'),
              SettingsSection(
                settings: _settings,
                onChanged: (s) => setState(() => _settings = s),
              ),
              const _Heading('Types'),
              _Buttons(
                children: [
                  FilledButton.tonal(
                    onPressed: () =>
                        _fire('Changes saved', (c, o) => c.success(o)),
                    child: const Text('Success'),
                  ),
                  FilledButton.tonal(
                    onPressed: () =>
                        _fire('Something went wrong', (c, o) => c.error(o)),
                    child: const Text('Error'),
                  ),
                  FilledButton.tonal(
                    onPressed: () =>
                        _fire('Low disk space', (c, o) => c.warning(o)),
                    child: const Text('Warning'),
                  ),
                  FilledButton.tonal(
                    onPressed: () =>
                        _fire('Did you know?', (c, o) => c.info(o)),
                    child: const Text('Info'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _fire(
                      'Update available',
                      (c, o) => c.action(o),
                      button: true,
                    ),
                    child: const Text('Action'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _fire(
                      'Parcel on its way',
                      (c, o) => c.show(o),
                      icon: const Icon(Icons.local_shipping_rounded),
                    ),
                    child: const Text('Custom icon'),
                  ),
                  FilledButton.tonal(
                    onPressed: _promise,
                    child: const Text('Promise'),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Promise outcome'),
                    for (final o in OutcomeChoice.values)
                      ChoiceChip(
                        label: Text(o.label),
                        selected: o == _settings.outcome,
                        onSelected: (_) => setState(
                          () => _settings = _settings.copyWith(outcome: o),
                        ),
                      ),
                  ],
                ),
              ),
              const _Heading('Actions'),
              _Buttons(
                children: [
                  OutlinedButton(
                    onPressed: () => dismissLatest(_controller),
                    child: const Text('Dismiss latest'),
                  ),
                  OutlinedButton(
                    onPressed: _controller.clear,
                    child: const Text('Clear all'),
                  ),
                  OutlinedButton(
                    onPressed: () => _controller.clear(_settings.position),
                    child: const Text('Clear this position'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _Buttons extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(spacing: 8, runSpacing: 8, children: children),
    );
  }
}

/// The built-in stand-in for a trailing image of a large toast.
class TrailingArt extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C4DFF), Color(0xFF00B8D4)],
        ),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Center(child: Icon(Icons.image_rounded, color: Color(0xFFFFFFFF))),
    );
  }
}
