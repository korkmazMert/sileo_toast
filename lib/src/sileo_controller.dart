import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:sileo_toast/src/constants.dart';
import 'package:sileo_toast/src/sileo_options.dart';
import 'package:sileo_toast/src/sileo_position.dart';
import 'package:sileo_toast/src/sileo_state.dart';

/// Id used when a toast is shown without one: it replaces the visible one.
const _defaultId = 'sileo-default';

/// One toast in the store. Immutable; the controller swaps instances.
@immutable
class SileoItem {
  /// Creates an item.
  const new({
    required this.id,
    required this.instanceId,
    required this.options,
    required this.position,
    this.exiting = false,
    this.autoExpandDelay,
    this.autoCollapseDelay,
  });

  /// Toast id; the same id morphs into the new toast.
  final String id;

  /// Changes on every replace/update, so views can tell a morph.
  final int instanceId;

  /// Options merged with the controller defaults.
  final SileoOptions options;

  /// Resolved viewport.
  final SileoPosition position;

  /// Dismissed and waiting for its exit animation to finish.
  final bool exiting;

  /// Autopilot expand delay; null when autopilot does not run.
  final Duration? autoExpandDelay;

  /// Autopilot collapse delay; null when autopilot does not run.
  final Duration? autoCollapseDelay;

  SileoItem _exit() => SileoItem(
    id: id,
    instanceId: instanceId,
    options: options,
    position: position,
    exiting: true,
    autoExpandDelay: autoExpandDelay,
    autoCollapseDelay: autoCollapseDelay,
  );
}

/// Store, timers and promise helper of the toasts. Pure logic, no widgets.
class SileoController extends ChangeNotifier {
  /// Where toasts without a position go; the toaster writes this.
  SileoPosition defaultPosition = SileoPosition.topRight;

  /// Options merged under every toast; the toaster writes this.
  SileoOptions? defaultOptions;

  /// While true no auto-dismiss timer is scheduled (accessible navigation);
  /// timers already running are left alone. The toaster writes this.
  bool suppressAutoDismiss = false;

  final List<SileoItem> _items = [];
  // Keyed `id:instanceId`, as in Sileo. Only these stop on [pause].
  final Map<String, Timer> _dismissTimers = {};
  final Map<String, Timer> _removeTimers = {};
  int _counter = 0;
  bool _paused = false;
  bool _disposed = false;

  /// Live and exiting toasts, oldest first. Read-only.
  List<SileoItem> get items => UnmodifiableListView(_items);

  /// Shows a toast (success when no type is set) and returns its id.
  String show(SileoOptions options) =>
      _put(options, options.type ?? SileoState.success);

  /// Shows a [SileoState.success] toast.
  String success(SileoOptions options) => _put(options, SileoState.success);

  /// Shows a [SileoState.error] toast.
  String error(SileoOptions options) => _put(options, SileoState.error);

  /// Shows a [SileoState.warning] toast.
  String warning(SileoOptions options) => _put(options, SileoState.warning);

  /// Shows a [SileoState.info] toast.
  String info(SileoOptions options) => _put(options, SileoState.info);

  /// Shows a [SileoState.action] toast.
  String action(SileoOptions options) => _put(options, SileoState.action);

  /// Shows a persistent loading toast, then morphs it into the result.
  /// Returns [future] itself, so errors still reach the caller.
  Future<T> promise<T>(Future<T> future, SileoPromiseOptions<T> options) {
    final id = options.loading.id ?? 'sileo-${_counter++}';
    _put(
      options.loading.copyWith(id: id, persistent: true),
      SileoState.loading,
    );
    unawaited(
      future.then<void>(
        (data) {
          final done = options.action;
          if (done != null) {
            _put(done(data).copyWith(id: id), SileoState.action);
          } else {
            _put(options.success(data).copyWith(id: id), SileoState.success);
          }
        },
        onError: (Object e) =>
            _put(options.error(e).copyWith(id: id), SileoState.error),
      ),
    );
    return future;
  }

  /// Morphs the toast [id] with [options] laid over its current ones.
  void update(String id, SileoOptions options) {
    if (_disposed) return;
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    _put(options.copyWith(id: id).mergeWith(_items[index].options), null);
  }

  /// Marks the toast exiting; it is removed once the exit animation is done.
  void dismiss(String id) {
    if (_disposed) return;
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0 || _items[index].exiting) return;
    final item = _items[index];
    final key = _key(item);
    _dismissTimers.remove(key)?.cancel();
    _items[index] = item._exit();
    _removeTimers[key] = Timer(SileoConstants.exitDuration, () {
      _removeTimers.remove(key);
      _items.removeWhere((i) => _key(i) == key);
      notifyListeners();
    });
    notifyListeners();
  }

  /// Removes toasts immediately; only those at [position] when given.
  void clear([SileoPosition? position]) {
    if (_disposed) return;
    final gone = _items
        .where((i) => position == null || i.position == position)
        .toList();
    if (gone.isEmpty) return;
    gone.forEach(_forget);
    _items.removeWhere(gone.contains);
    notifyListeners();
  }

  /// Stops auto-dismissal (hover/touch). Exit removals keep running.
  void pause() {
    if (_disposed) return;
    _paused = true;
    for (final t in _dismissTimers.values) {
      t.cancel();
    }
    _dismissTimers.clear();
  }

  /// Restarts the full duration of every live toast.
  void resume() {
    if (_disposed) return;
    _paused = false;
    _items.where((i) => !i.exiting).forEach(_scheduleDismiss);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final t in [..._dismissTimers.values, ..._removeTimers.values]) {
      t.cancel();
    }
    _dismissTimers.clear();
    _removeTimers.clear();
    super.dispose();
  }

  String _put(SileoOptions options, SileoState? type) {
    final id = options.id ?? defaultOptions?.id ?? _defaultId;
    if (_disposed) return id;
    var merged = options.mergeWith(defaultOptions).copyWith(id: id);
    if (type != null) merged = merged.copyWith(type: type);

    final duration = _autoDuration(merged);
    final expand = merged.autopilot.expand ?? SileoConstants.autoExpandDelay;
    final collapse =
        merged.autopilot.collapse ?? SileoConstants.autoCollapseDelay;
    final autopilot = merged.autopilot.enabled && duration != null;
    final item = SileoItem(
      id: id,
      instanceId: _counter++,
      options: merged,
      position: merged.position ?? defaultPosition,
      autoExpandDelay: autopilot ? _clamp(expand, duration) : null,
      autoCollapseDelay: autopilot ? _clamp(collapse, duration) : null,
    );

    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) {
      _items.add(item);
    } else {
      _forget(_items[index]);
      _items[index] = item;
    }
    _scheduleDismiss(item);
    notifyListeners();
    return id;
  }

  /// The auto-dismiss delay, or null when the toast is persistent.
  Duration? _autoDuration(SileoOptions o) {
    if (o.persistent) return null;
    final d = o.duration ?? SileoConstants.defaultToastDuration;
    return d > Duration.zero ? d : null;
  }

  void _scheduleDismiss(SileoItem item) {
    final duration = _autoDuration(item.options);
    if (_paused || suppressAutoDismiss || duration == null) return;
    final key = _key(item);
    _dismissTimers[key]?.cancel();
    _dismissTimers[key] = Timer(duration, () {
      _dismissTimers.remove(key);
      dismiss(item.id);
    });
  }

  void _forget(SileoItem item) {
    final key = _key(item);
    _dismissTimers.remove(key)?.cancel();
    _removeTimers.remove(key)?.cancel();
  }

  String _key(SileoItem i) => '${i.id}:${i.instanceId}';

  Duration _clamp(Duration d, Duration max) =>
      d < Duration.zero ? Duration.zero : (d > max ? max : d);
}
