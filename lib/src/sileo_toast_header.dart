part of 'sileo_toast_view.dart';

/// What the toast currently shows; swapped as a whole on a same-id morph.
@immutable
class _View {
  const new({
    required this.title,
    required this.description,
    required this.state,
    required this.icon,
    required this.styles,
    required this.button,
  });

  factory of(SileoOptions o) {
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
    );
  }

  final String title;
  final Widget? description;
  final SileoState state;
  final Widget? icon;
  final SileoStyles? styles;
  final SileoButton? button;

  bool get hasContent => description != null || button != null;

  /// Header layers are keyed by this; a change plays the crossfade.
  String get headerKey => '${state.name}-$title';
}

enum _Transition { none, enter, exit }

/// One header layer: badge and title, fading and un-blurring in or out.
class _HeaderLayer extends StatefulWidget {
  const new({
    required this.view,
    required this.tone,
    required this.transition,
    this.onRowSize,
    super.key,
  });

  final _View view;
  final Color tone;
  final _Transition transition;
  final ValueChanged<Size>? onRowSize;

  @override
  State<_HeaderLayer> createState() => _HeaderLayerState();
}

class _HeaderLayerState extends State<_HeaderLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _opacity;

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
    final title = base
        .copyWith(
          fontSize: SileoConstants.titleFontSize,
          height: SileoConstants.titleLineHeight / SileoConstants.titleFontSize,
          fontWeight: SileoConstants.titleWeight,
          color: widget.tone,
        )
        .merge(view.styles?.title);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Badge(view: view, tone: widget.tone),
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
          return ImageFiltered(
            enabled: sigma > 0,
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: child,
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const new({required this.view, required this.tone});

  final _View view;
  final Color tone;

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
        data: IconThemeData(
          color: foreground,
          size: SileoConstants.badgeIconSize,
        ),
        child: custom,
      );
    } else if (view.state == SileoState.loading) {
      icon = _Spinner(color: foreground);
    } else {
      icon = SizedBox.square(
        dimension: SileoConstants.badgeIconSize,
        child: CustomPaint(
          painter: SileoIconPainter(icon: _icon(view.state), color: foreground),
        ),
      );
    }
    return SizedBox.square(
      dimension: SileoConstants.badgeSize,
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
  const new({required this.color});

  final Color color;

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
  Widget build(BuildContext context) => RotationTransition(
    turns: _c,
    child: RepaintBoundary(
      child: SizedBox.square(
        dimension: SileoConstants.badgeIconSize,
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
