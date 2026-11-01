import 'dart:math' as math;
// Brightness is re-exported by widgets.dart only on newer Flutter; keep the
// import so older supported versions compile.
// ignore: unnecessary_import
import 'dart:ui' show Brightness;

import 'package:flutter/widgets.dart';
import 'package:sileo_toast/src/constants.dart';
import 'package:sileo_toast/src/sileo_controller.dart';
import 'package:sileo_toast/src/sileo_options.dart';
import 'package:sileo_toast/src/sileo_position.dart';
import 'package:sileo_toast/src/sileo_theme.dart';
import 'package:sileo_toast/src/sileo_toast_view.dart';

part 'sileo_toaster_viewport.dart';

/// Reads the [SileoController] of the nearest [SileoToaster].
abstract final class Sileo {
  /// The nearest controller; asserts when there is no [SileoToaster].
  static SileoController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No SileoToaster found in the widget tree.');
    return controller!;
  }

  /// The nearest controller, or null.
  static SileoController? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_SileoScope>()
          ?.notifier
          ?.controller;
}

class _SileoScope extends InheritedNotifier<_ScopeNotifier> {
  const _SileoScope({
    required _ScopeNotifier super.notifier,
    required super.child,
  });

  @override
  bool updateShouldNotify(_SileoScope oldWidget) =>
      oldWidget.notifier?.controller != notifier?.controller;
}

// Holder so the scope notifies on controller identity only.
class _ScopeNotifier extends ChangeNotifier {
  _ScopeNotifier(this.controller);
  final SileoController controller;
}

/// Hosts toasts above [child]. Put it above the Navigator (for example in
/// `MaterialApp.builder`); it is a plain [Stack], not an Overlay.
class SileoToaster extends StatefulWidget {
  /// Creates a toaster.
  const SileoToaster({
    required this.child,
    this.controller,
    this.position = SileoPosition.topRight,
    this.offset,
    this.options,
    this.theme,
    this.textStyle,
    this.persistWhenAccessibleNavigation = true,
    super.key,
  });

  /// The app below the toasts.
  final Widget child;

  /// Controller to use. When null the toaster owns one; a passed controller
  /// belongs to the caller and is never disposed here.
  final SileoController? controller;

  /// Where toasts without their own position go.
  final SileoPosition position;

  /// Extra distance from the safe area edges.
  final EdgeInsets? offset;

  /// Options merged under every toast.
  final SileoOptions? options;

  /// Toast fill theme; white fill when null.
  final SileoThemeMode? theme;

  /// Base toast text style; pass the app theme's. Neutral when null.
  final TextStyle? textStyle;

  /// With accessible navigation on, toasts never auto-dismiss.
  final bool persistWhenAccessibleNavigation;

  @override
  State<SileoToaster> createState() => _SileoToasterState();
}

class _SileoToasterState extends State<SileoToaster> {
  late SileoController _controller;
  late bool _owned;
  late _ScopeNotifier _scope;
  // Hovered or touch-expanded toast ids, oldest first.
  final Set<String> _engaged = {};

  @override
  void initState() {
    super.initState();
    _adopt();
  }

  @override
  void didUpdateWidget(SileoToaster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final old = _controller;
      final oldScope = _scope;
      final wasOwned = _owned;
      _adopt();
      oldScope.dispose();
      _engaged.clear();
      if (wasOwned) old.dispose();
    } else {
      _syncDefaults();
    }
  }

  @override
  void dispose() {
    if (_owned) _controller.dispose();
    _scope.dispose();
    super.dispose();
  }

  void _adopt() {
    _owned = widget.controller == null;
    _controller = widget.controller ?? SileoController();
    _scope = _ScopeNotifier(_controller);
    _syncDefaults();
  }

  void _syncDefaults() {
    _controller
      ..defaultPosition = widget.position
      ..defaultOptions = widget.options;
  }

  void _onEngaged(String id, {required bool engaged}) {
    if (!mounted) return;
    setState(() {
      if (engaged) {
        _engaged
          ..remove(id)
          ..add(id);
      } else {
        _engaged.remove(id);
      }
    });
    if (_engaged.isEmpty) {
      _controller.resume();
    } else {
      _controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    _controller.suppressAutoDismiss =
        widget.persistWhenAccessibleNavigation &&
        (MediaQuery.maybeAccessibleNavigationOf(context) ?? false);
    final fill = SileoFill.resolve(
      widget.theme,
      MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light,
    );
    final safe = MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;
    final offset = widget.offset ?? EdgeInsets.zero;
    const pad = SileoConstants.viewportPadding;
    const ext = SileoConstants.tapExtension;
    final inset = EdgeInsets.fromLTRB(
      safe.left + offset.left + pad,
      safe.top + offset.top + pad - ext,
      safe.right + offset.right + pad,
      safe.bottom + offset.bottom + pad - ext,
    );

    return _SileoScope(
      notifier: _scope,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final items = _controller.items;
                if (items.isEmpty) return const SizedBox.shrink();
                final live = items.where((i) => !i.exiting);
                final active =
                    _engaged.isNotEmpty
                        ? _engaged.last
                        : (live.isEmpty ? null : live.last.id);
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width =
                        math
                            .max(
                              0,
                              math.min(
                                SileoConstants.width,
                                constraints.maxWidth - inset.horizontal,
                              ),
                            )
                            .toDouble();
                    final largeWidth =
                        math
                            .max(
                              0,
                              math.min(
                                SileoConstants.largeMaxWidth,
                                constraints.maxWidth - inset.horizontal,
                              ),
                            )
                            .toDouble();
                    return Stack(
                      children: [
                        for (final p in SileoPosition.values)
                          if (items.any((i) => i.position == p))
                            _Viewport(
                              position: p,
                              inset: inset,
                              items: [
                                for (final i in items)
                                  if (i.position == p) i,
                              ],
                              width: width,
                              largeWidth: largeWidth,
                              fill: fill,
                              textStyle: widget.textStyle,
                              activeId: active,
                              persist: widget.persistWhenAccessibleNavigation,
                              onDismiss: _controller.dismiss,
                              onEngaged: _onEngaged,
                            ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
