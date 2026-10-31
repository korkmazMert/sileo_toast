part of 'sileo_toast_view.dart';

/// A value on a spring. Retargeting keeps the current velocity.
class _SpringValue {
  new(TickerProvider vsync, double initial)
    : controller = AnimationController.unbounded(vsync: vsync, value: initial),
      target = initial;

  final AnimationController controller;
  double target;

  double get value => controller.value;

  void moveTo(
    double next, {
    required SpringDescription spring,
    required bool animate,
  }) {
    if (!animate) {
      target = next;
      controller.value = next; // also stops a running simulation
      return;
    }
    if (next == target) return;
    target = next;
    controller.animateWith(
      SpringSimulation(
        spring,
        controller.value,
        next,
        controller.velocity,
        snapToEnd: true,
      ),
    );
  }

  void dispose() => controller.dispose();
}

/// A value Sileo animates with a CSS transition: restarts from its current
/// value when retargeted, optionally after a delay.
class _CssValue extends Animation<double>
    with AnimationWithParentMixin<double> {
  new(TickerProvider vsync, double initial)
    : _controller = AnimationController(vsync: vsync, value: 1),
      _from = initial,
      _to = initial;

  final AnimationController _controller;
  double _from;
  double _to;
  Curve _curve = sileoSpringCurve;
  Timer? _delay;

  @override
  Animation<double> get parent => _controller;

  @override
  double get value =>
      _from + (_to - _from) * _curve.transform(_controller.value);

  void moveTo(
    double next, {
    required bool animate,
    Duration duration = SileoConstants.duration,
    Duration delay = Duration.zero,
    Curve curve = sileoSpringCurve,
  }) {
    if (next == _to) return;
    _delay?.cancel();
    if (!animate) {
      _from = _to = next;
      _controller.value = 1;
      return;
    }
    _from = value;
    _to = next;
    _curve = curve;
    _controller
      ..duration = duration
      ..value = 0;
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      _delay = Timer(delay, _controller.forward);
    }
  }

  void dispose() {
    _delay?.cancel();
    _controller.dispose();
  }
}

/// Reports its child's size from layout. The owner must not `setState`
/// from [onSize]; it records the size and retargets after the frame.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const new({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSizeReporter renderObject,
  ) => renderObject.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  new(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size != _last) {
      _last = size;
      onSize(size);
    }
  }
}

/// All animated values of one toast.
class _ToastMotion {
  new(TickerProvider vsync)
    : pillX = _SpringValue(vsync, 0),
      pillWidth = _SpringValue(vsync, SileoConstants.height),
      bodyHeight = _SpringValue(vsync, 0),
      bodyOpacity = _SpringValue(vsync, 0),
      toastHeight = _SpringValue(vsync, SileoConstants.height),
      drag = _SpringValue(vsync, 0),
      neckHeight = _SpringValue(vsync, 0),
      presence = _CssValue(vsync, 0),
      headerLeft = _CssValue(vsync, 0),
      headerWidth = _CssValue(vsync, SileoConstants.height),
      headerOpen = _CssValue(vsync, 0),
      contentOpacity = _CssValue(vsync, 0);

  // Sileo's motion.rect values, on the morph spring.
  final _SpringValue pillX;
  final _SpringValue pillWidth;
  final _SpringValue bodyHeight;
  final _SpringValue bodyOpacity;
  final _SpringValue toastHeight;
  final _SpringValue drag;

  // Island neck length above the pill top.
  final _SpringValue neckHeight;

  // Values Sileo animates with CSS transitions.
  final _CssValue presence;
  final _CssValue headerLeft;
  final _CssValue headerWidth;
  final _CssValue headerOpen;
  final _CssValue contentOpacity;

  late final Animation<double> scale = presence.drive(
    Tween<double>(begin: SileoConstants.entryScale, end: 1),
  );
  late final Listenable repaint = Listenable.merge([
    pillX.controller,
    pillWidth.controller,
    bodyHeight.controller,
    bodyOpacity.controller,
    toastHeight.controller,
    neckHeight.controller,
  ]);
  late final Listenable headerAnimation = Listenable.merge([
    headerLeft,
    headerWidth,
    headerOpen,
  ]);

  /// Points everything at its target. Closing the body uses the
  /// critically damped spring; the rest use the morph spring.
  void retarget({
    required bool animate,
    required bool open,
    required double header,
    required double expanded,
    required double pillX,
    required double pillWidth,
    required double neckHeight,
    required bool animateNeck,
  }) {
    final bodySpring = open ? sileoSpring : sileoCloseSpring;
    this.pillX.moveTo(pillX, spring: sileoSpring, animate: animate);
    this.pillWidth.moveTo(pillWidth, spring: sileoSpring, animate: animate);
    this.neckHeight.moveTo(
      neckHeight,
      spring: sileoSpring,
      animate: animateNeck,
    );
    bodyHeight.moveTo(
      open ? math.max(0, expanded - header) : 0,
      spring: bodySpring,
      animate: animate,
    );
    bodyOpacity.moveTo(open ? 1 : 0, spring: bodySpring, animate: animate);
    toastHeight.moveTo(
      open ? expanded : header,
      spring: sileoSpring,
      animate: animate,
    );
    headerLeft.moveTo(pillX, animate: animate);
    headerWidth.moveTo(pillWidth, animate: animate);
    headerOpen.moveTo(open ? 1 : 0, animate: animate);
    contentOpacity.moveTo(
      open ? 1 : 0,
      animate: animate,
      duration: open
          ? SileoConstants.contentOpenFade
          : SileoConstants.contentCloseFade,
      delay: open
          ? SileoConstants.contentOpenDelay
          : SileoConstants.contentCloseDelay,
      curve: Curves.ease,
    );
  }

  void dispose() {
    for (final v in [
      pillX,
      pillWidth,
      bodyHeight,
      bodyOpacity,
      toastHeight,
      drag,
      neckHeight,
    ]) {
      v.dispose();
    }
    for (final v in [
      presence,
      headerLeft,
      headerWidth,
      headerOpen,
      contentOpacity,
    ]) {
      v.dispose();
    }
  }
}
