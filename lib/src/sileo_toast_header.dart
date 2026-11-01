part of 'sileo_toast_view.dart';

/// What the toast currently shows; swapped as a whole on a same-id morph.
@immutable
class _View {
  const _View({
    required this.title,
    required this.description,
    required this.state,
    required this.icon,
    required this.styles,
    required this.button,
    required this.size,
    required this.trailing,
    required this.secondaryButton,
  });

  factory _View.of(SileoOptions o) {
    final state = o.type ?? SileoState.success;
    return _View(
      // Only the fallback is capitalized: Sileo's CSS `capitalize` would turn
      // a Turkish `i...` into `I...`.
      title:
          o.title ?? '${state.name[0].toUpperCase()}${state.name.substring(1)}',
      description: o.description,
      state: state,
      icon: o.icon,
      styles: o.styles,
      button: o.button,
      size: o.size ?? SileoSize.compact,
      trailing: o.trailing,
      secondaryButton: o.secondaryButton,
    );
  }

  final String title;
  final Widget? description;
  final SileoState state;
  final Widget? icon;
  final SileoStyles? styles;
  final SileoButton? button;
  final SileoSize size;
  final Widget? trailing;
  final SileoButton? secondaryButton;

  /// Compact ignores [trailing] and [secondaryButton].
  bool get hasContent =>
      description != null ||
      button != null ||
      (size == SileoSize.large && secondaryButton != null);

  /// Header layers are keyed by this; a change plays the crossfade.
  String get headerKey => '${state.name}-$title';
}

enum _Transition { none, enter, exit }

/// One header layer: badge and title, fading and un-blurring in or out.
class _HeaderLayer extends StatefulWidget {
  const _HeaderLayer({
    required this.view,
    required this.tone,
    required this.transition,
    required this.metrics,
    this.onRowSize,
    super.key,
  });

  final _View view;
  final Color tone;
  final _Transition transition;
  final _Metrics metrics;
  final ValueChanged<Size>? onRowSize;

  @override
  State<_HeaderLayer> createState() => _HeaderLayerState();
}

class _HeaderLayerState extends State<_HeaderLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _opacity;
  final GlobalKey _rowKey = GlobalKey();

  bool get _exit => widget.transition == _Transition.exit;

  @override
  void initState() {
    super.initState();
    final animated = widget.transition != _Transition.none;
    _c = AnimationController(
      vsync: this,
      duration: _exit ? SileoConstants.headerExit : SileoConstants.duration,
      value: animated ? 0 : 1,
    );
    final curve = CurveTween(curve: _exit ? Curves.ease : sileoSpringCurve);
    _opacity = _c.drive(
      Tween<double>(begin: _exit ? 1 : 0, end: _exit ? 0 : 1).chain(curve),
    );
    if (animated) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _sigma {
    final t = (_exit ? Curves.ease : sileoSpringCurve).transform(_c.value);
    return SileoConstants.headerBlur * (_exit ? t : 1 - t).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final base = DefaultTextStyle.of(context).style;
    final metrics = widget.metrics;
    final title = base
        .copyWith(
          fontSize: metrics.titleSize,
          height: metrics.titleLine / metrics.titleSize,
          fontWeight: SileoConstants.titleWeight,
          color: widget.tone,
        )
        .merge(view.styles?.title);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Badge(view: view, tone: widget.tone, metrics: metrics),
        const SizedBox(width: SileoConstants.headerGap),
        Flexible(
          child: Text(
            view.title,
            style: title,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    final onSize = widget.onRowSize;
    return FadeTransition(
      opacity: _opacity,
      child: AnimatedBuilder(
        animation: _c,
        child: onSize == null ? row : _SizeReporter(onSize: onSize, child: row),
        builder: (context, child) {
          final sigma = _sigma;
          // Keyed so the badge (spinner) keeps its state when the filter
          // wrapper comes and goes.
          final row = KeyedSubtree(key: _rowKey, child: child!);
          if (sigma <= 0) return row;
          return ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: row,
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.view, required this.tone, required this.metrics});

  final _View view;
  final Color tone;
  final _Metrics metrics;

  static SileoIcon _icon(SileoState s) => switch (s) {
    SileoState.success => SileoIcon.check,
    SileoState.loading => SileoIcon.loaderCircle,
    SileoState.error => SileoIcon.x,
    SileoState.warning => SileoIcon.circleAlert,
    SileoState.info => SileoIcon.lifeBuoy,
    SileoState.action => SileoIcon.arrowRight,
  };

  @override
  Widget build(BuildContext context) {
    final styles = view.styles;
    final foreground = styles?.badgeForeground ?? tone;
    final custom = view.icon;
    final Widget icon;
    if (custom != null) {
      icon = IconTheme(
        data: IconThemeData(color: foreground, size: metrics.icon),
        child: custom,
      );
    } else if (view.state == SileoState.loading) {
      icon = _Spinner(color: foreground, size: metrics.icon);
    } else {
      icon = SizedBox.square(
        dimension: metrics.icon,
        child: CustomPaint(
          painter: SileoIconPainter(icon: _icon(view.state), color: foreground),
        ),
      );
    }
    return SizedBox.square(
      dimension: metrics.badge,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const CircleBorder(),
          color:
              styles?.badgeBackground ??
              tone.withValues(alpha: SileoConstants.badgeAlpha),
        ),
        child: Padding(
          padding: const EdgeInsets.all(SileoConstants.badgePadding),
          child: Center(child: icon),
        ),
      ),
    );
  }
}

/// The loading icon: one turn per second, still under reduce motion.
class _Spinner extends StatefulWidget {
  const _Spinner({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: SileoConstants.spinnerTurn,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: RotationTransition(
      turns: _c,
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: SileoIconPainter(
            icon: SileoIcon.loaderCircle,
            color: widget.color,
          ),
        ),
      ),
    ),
  );
}
