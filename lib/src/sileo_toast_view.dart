import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sileo_toast/src/constants.dart';
import 'package:sileo_toast/src/sileo_controller.dart';
import 'package:sileo_toast/src/sileo_icons.dart';
import 'package:sileo_toast/src/sileo_options.dart';
import 'package:sileo_toast/src/sileo_shape_painter.dart';
import 'package:sileo_toast/src/sileo_spring.dart';
import 'package:sileo_toast/src/sileo_state.dart';
import 'package:sileo_toast/src/sileo_theme.dart';

part 'sileo_toast_content.dart';
part 'sileo_toast_header.dart';
part 'sileo_toast_layers.dart';
part 'sileo_toast_motion.dart';

/// One toast: springs, header crossfade, gestures and semantics.
///
/// Internal: the toaster host (`SileoToaster`) builds one per [SileoItem].
///
/// Layout contract for the host:
/// * The view is [width] wide and `toast height + 2 * tapExtension` tall
///   (the extra 4 dp above and below is part of the 48 dp gesture box), so
///   the host subtracts `tapExtension` from the viewport edge padding and
///   `2 * tapExtension` from the gap to keep the visual 12 dp spacing.
/// * The view animates its own height; the host lets the column reflow.
/// * [onEngagedChanged] may fire in a post-frame callback after the view is
///   disposed (a hovered toast being removed): the host must tolerate that.
class SileoToastView extends StatefulWidget {
  /// Creates a toast view.
  const new({
    required this.item,
    required this.width,
    required this.fill,
    this.descriptionColor,
    this.textStyle,
    this.stateColors = const SileoStateColors(),
    this.canExpand = true,
    this.persistWhenAccessibleNavigation = true,
    this.onDismiss,
    this.onEngagedChanged,
    super.key,
  });

  /// The toast to show.
  final SileoItem item;

  /// Toast width: `min(350, available - 2 * 12)`, resolved by the host.
  final double width;

  /// Toast fill (option, else theme fill).
  final Color fill;

  /// Description color from the theme fill; null inherits [textStyle].
  final Color? descriptionColor;

  /// Base text style of the toast; a neutral one when null. The view always
  /// removes any decoration (the host above the Navigator would otherwise
  /// show `MaterialApp`'s error underline).
  final TextStyle? textStyle;

  /// Tone per state.
  final SileoStateColors stateColors;

  /// Whether this is the active toast (latest live one) and may auto-expand.
  final bool canExpand;

  /// With accessible navigation on, autopilot expands but never collapses.
  final bool persistWhenAccessibleNavigation;

  /// Called by a swipe past the threshold and by the semantic dismiss action.
  final VoidCallback? onDismiss;

  /// Called with true when the toast is hovered or touch-expanded (the host
  /// pauses the dismiss timers) and with false when that ends.
  final ValueChanged<bool>? onEngagedChanged;

  @override
  State<SileoToastView> createState() => _SileoToastViewState();
}

class _SileoToastViewState extends State<SileoToastView>
    with TickerProviderStateMixin {
  // Content shown; swapped after the collapse on a same-id morph.
  late _View _view = _View.of(widget.item.options);
  _View? _pending;
  // Header layers: the current one and, while crossfading, the previous.
  late _View _current = _view;
  _View? _prev;

  bool _isExpanded = false;
  bool _hovering = false;
  bool _touchHeld = false;
  bool _engaged = false;

  // Measured by `_SizeReporter`s.
  double _rowWidth = 0;
  double _contentHeight = 0;
  bool _measured = false;
  bool _retargetQueued = false;

  bool _initialized = false;
  double _headerHeight = SileoConstants.height;
  bool _reduceMotion = false;
  bool _accessibleNavigation = false;

  double _dragStartY = 0;
  double _dragDy = 0;

  Timer? _expandTimer;
  Timer? _collapseTimer;
  Timer? _swapTimer;
  Timer? _prevTimer;

  late final _m = _ToastMotion(this);

  bool get _hasContent => _view.hasContent;
  bool get _isLoading => _view.state == SileoState.loading;
  bool get _open => _hasContent && _isExpanded && !_isLoading;
  bool get _allowExpand => !_isLoading && widget.canExpand;
  bool get _exiting => widget.item.exiting;

  @override
  void initState() {
    super.initState();
    _m.toastHeight.controller.addStatusListener(_onToastHeightStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    _headerHeight = math.max(
      SileoConstants.height,
      scaler.scale(SileoConstants.titleLineHeight) +
          2 * SileoConstants.headerPadding,
    );
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final accessible = MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    final accessibleChanged = accessible != _accessibleNavigation;
    _accessibleNavigation = accessible;
    if (!_initialized) {
      _initialized = true;
      _m.presence.moveTo(_exiting ? 0 : 1, animate: !_reduceMotion);
      _scheduleAutopilot();
    } else if (accessibleChanged) {
      _scheduleAutopilot();
    }
    _retarget();
    _syncEngagedAfterFrame();
  }

  @override
  void didUpdateWidget(SileoToastView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.item;
    final item = widget.item;
    var reschedule =
        oldWidget.canExpand != widget.canExpand ||
        oldWidget.persistWhenAccessibleNavigation !=
            widget.persistWhenAccessibleNavigation ||
        old.autoExpandDelay != item.autoExpandDelay ||
        old.autoCollapseDelay != item.autoCollapseDelay;
    if (old.exiting != item.exiting) {
      _m.presence.moveTo(item.exiting ? 0 : 1, animate: !_reduceMotion);
      reschedule = true;
    }
    if (old.instanceId != item.instanceId) {
      _morph(_View.of(item.options));
      reschedule = _pending == null;
    }
    if (reschedule) _scheduleAutopilot();
    _retarget();
    _syncEngagedAfterFrame();
  }

  @override
  void dispose() {
    _expandTimer?.cancel();
    _collapseTimer?.cancel();
    _swapTimer?.cancel();
    _prevTimer?.cancel();
    if (_engaged) {
      final notify = widget.onEngagedChanged;
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => notify?.call(false),
      );
    }
    _m.toastHeight.controller.removeStatusListener(_onToastHeightStatus);
    _m.dispose();
    super.dispose();
  }

  // ------------------------------- Morphing --------------------------------

  /// Same-id replace: collapse, swap content after 200 ms or once the
  /// collapse settles, then autopilot runs again.
  void _morph(_View next) {
    _swapTimer?.cancel();
    _swapTimer = null;
    if (_open && !_reduceMotion) {
      _expandTimer?.cancel();
      _collapseTimer?.cancel();
      _pending = next;
      _expand(expanded: false);
      _swapTimer = Timer(SileoConstants.swapCollapse, _applyPending);
    } else {
      _pending = null;
      if (_open) _expand(expanded: false);
      _applyView(next);
    }
  }

  void _applyPending() {
    final next = _pending;
    _swapTimer?.cancel();
    _swapTimer = null;
    if (!mounted || next == null) return;
    _pending = null;
    setState(() => _applyView(next));
    _scheduleAutopilot();
    _retarget();
  }

  void _onToastHeightStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_open && _pending != null) {
      _applyPending();
    }
  }

  void _applyView(_View next) {
    _view = next;
    if (!next.hasContent) _contentHeight = 0;
    if (next.headerKey != _current.headerKey) {
      _prevTimer?.cancel();
      if (_reduceMotion) {
        _prev = null;
      } else {
        _prev = _current;
        _prevTimer = Timer(SileoConstants.headerExit, () {
          if (mounted) setState(() => _prev = null);
        });
      }
    }
    _current = next;
  }

  // ------------------------------- Autopilot -------------------------------

  void _expand({required bool expanded}) {
    _isExpanded = expanded;
    if (!expanded) _touchHeld = false;
  }

  void _scheduleAutopilot() {
    _expandTimer?.cancel();
    _collapseTimer?.cancel();
    if (!_hasContent || _pending != null) return;
    if (_exiting || !_allowExpand) {
      _expand(expanded: false);
      return;
    }
    final item = widget.item;
    if (_engaged ||
        (item.autoExpandDelay == null && item.autoCollapseDelay == null)) {
      return;
    }
    final expandDelay = item.autoExpandDelay ?? Duration.zero;
    final collapseDelay = item.autoCollapseDelay ?? Duration.zero;
    if (expandDelay > Duration.zero) {
      _expandTimer = Timer(expandDelay, () => _timerExpand(expanded: true));
    } else {
      _isExpanded = true;
    }
    final stayOpen =
        _accessibleNavigation && widget.persistWhenAccessibleNavigation;
    if (collapseDelay > Duration.zero && !stayOpen) {
      _collapseTimer = Timer(
        collapseDelay,
        () => _timerExpand(expanded: false),
      );
    }
  }

  void _timerExpand({required bool expanded}) {
    if (mounted) _update(() => _expand(expanded: expanded));
  }

  // ------------------------------ Interaction ------------------------------

  void _update(VoidCallback change) {
    setState(change);
    _syncEngaged();
    _retarget();
  }

  /// Hover or touch-expand pauses the host's dismiss timers.
  void _syncEngaged() {
    final engaged = _hovering || _touchHeld;
    if (engaged == _engaged) return;
    _engaged = engaged;
    if (engaged) {
      _expandTimer?.cancel();
      _collapseTimer?.cancel();
    }
    widget.onEngagedChanged?.call(engaged);
  }

  void _syncEngagedAfterFrame() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncEngaged();
    });
  }

  void _toggle() {
    if (!_hasContent || _isLoading || _exiting || !mounted) return;
    _update(() {
      final next = !_isExpanded;
      _isExpanded = next;
      _touchHeld = next;
    });
  }

  void _hover({required bool entered}) {
    if (!mounted) return;
    _update(() {
      _hovering = entered;
      if (entered) {
        if (_hasContent) _isExpanded = true;
      } else {
        _expand(expanded: false);
      }
    });
  }

  void _onDragDown(DragDownDetails details) {
    _dragStartY = details.globalPosition.dy;
    _dragDy = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragDy = details.globalPosition.dy - _dragStartY;
    _m.drag.moveTo(
      _dragDy.sign * math.min(_dragDy.abs(), SileoConstants.swipeMax),
      spring: sileoSpring,
      animate: false,
    );
  }

  void _endDrag({required bool released}) {
    final dismiss = released && _dragDy.abs() > SileoConstants.swipeDismiss;
    _dragDy = 0;
    _m.drag.moveTo(0, spring: sileoSpring, animate: !_reduceMotion);
    if (dismiss) widget.onDismiss?.call();
  }

  // ------------------------------ Measurements -----------------------------

  void _onRowSize(Size size) {
    if (size.width == _rowWidth) return;
    _rowWidth = size.width;
    _scheduleRetarget();
  }

  void _onContentSize(Size size) {
    if (size.height == _contentHeight) return;
    _contentHeight = size.height;
    _scheduleRetarget();
  }

  /// Layout must not touch the springs' listeners, so retarget after the frame.
  void _scheduleRetarget() {
    if (_retargetQueued) return;
    _retargetQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _retargetQueued = false;
      if (!mounted) return;
      _retarget();
      _measured = true;
    });
  }

  /// Points every animated value at its target. Nothing animates until the
  /// first measurement (Sileo's `ready` flag) or under reduce motion.
  void _retarget() {
    final animate = _measured && !_reduceMotion;
    final header = _headerHeight;
    final width = widget.width;
    final pill = _rowWidth <= 0
        ? header
        : math.max(
            header,
            math.min(
              width,
              _rowWidth +
                  2 * SileoConstants.headerPadding +
                  SileoConstants.pillPadding,
            ),
          );
    final pillX = (width - pill) * (widget.item.position.pillAlign.x + 1) / 2;
    final open = _open;
    final minExpanded = header * SileoConstants.minExpandRatio;
    final expanded = _hasContent
        ? math.max(minExpanded, header + _contentHeight)
        : minExpanded;

    _m.retarget(
      animate: animate,
      open: open,
      header: header,
      expanded: expanded,
      pillX: pillX,
      pillWidth: pill,
    );
  }

  // --------------------------------- Build ---------------------------------

  String get _semanticsLabel {
    final description = _view.description;
    final text = description is Text ? description.data : null;
    return text == null ? _view.title : '${_view.title}\n$text';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isTop = item.position.isTop;
    final exiting = _exiting;
    final canDrag = !exiting && widget.onDismiss != null;
    final style = (widget.textStyle ?? SileoConstants.neutralText).copyWith(
      decoration: TextDecoration.none,
    );
    final toneOf = widget.stateColors.of;

    final box = _ToastBox(
      width: widget.width,
      height: _m.toastHeight.controller,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _ToastShape(
            fill: widget.fill,
            roundness: math.max(
              0,
              item.options.roundness ?? SileoConstants.defaultRoundness,
            ),
            width: widget.width,
            headerHeight: _headerHeight,
            flipped: !isTop,
            pillX: _m.pillX.controller,
            pillWidth: _m.pillWidth.controller,
            bodyHeight: _m.bodyHeight.controller,
            bodyOpacity: _m.bodyOpacity.controller,
            toastHeight: _m.toastHeight.controller,
            repaint: _m.repaint,
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: SileoConstants.tapExtension,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (_hasContent)
                    _ToastContent(
                      view: _view,
                      tone: toneOf(_view.state),
                      descriptionColor: widget.descriptionColor,
                      opacity: _m.contentOpacity,
                      open: _open,
                      isTop: isTop,
                      headerHeight: _headerHeight,
                      onSize: _onContentSize,
                    ),
                  _ToastHeader(
                    animation: _m.headerAnimation,
                    left: _m.headerLeft,
                    width: _m.headerWidth,
                    open: _m.headerOpen,
                    current: _current,
                    prev: _prev,
                    toneOf: toneOf,
                    isTop: isTop,
                    height: _headerHeight,
                    maxRowWidth:
                        widget.width -
                        2 * SileoConstants.headerPadding -
                        SileoConstants.pillPadding,
                    onRowSize: _onRowSize,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return DefaultTextStyle(
      style: style,
      textAlign: TextAlign.left,
      child: RepaintBoundary(
        child: _ToastEntry(
          presence: _m.presence,
          scale: _m.scale,
          drag: _m.drag.controller,
          isTop: isTop,
          child: IgnorePointer(
            ignoring: exiting,
            child: Semantics(
              container: true,
              liveRegion: true,
              expanded: _hasContent ? _open : null,
              label: _semanticsLabel,
              onTap: _hasContent && !_isLoading && !exiting ? _toggle : null,
              onDismiss: exiting ? null : widget.onDismiss,
              child: MouseRegion(
                hitTestBehavior: HitTestBehavior.deferToChild,
                onEnter: (_) => _hover(entered: true),
                onExit: (_) => _hover(entered: false),
                child: GestureDetector(
                  excludeFromSemantics: true,
                  onTap: _toggle,
                  onVerticalDragDown: canDrag ? _onDragDown : null,
                  onVerticalDragUpdate: canDrag ? _onDragUpdate : null,
                  onVerticalDragEnd: canDrag
                      ? (_) => _endDrag(released: true)
                      : null,
                  onVerticalDragCancel: canDrag
                      ? () => _endDrag(released: false)
                      : null,
                  child: box,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
