part of 'sileo_toast_view.dart';

/// Entry/exit (opacity, scale, translate) and the swipe offset.
class _ToastEntry extends StatelessWidget {
  const _ToastEntry({
    required this.presence,
    required this.scale,
    required this.drag,
    required this.isTop,
    required this.child,
  });

  final Animation<double> presence;
  final Animation<double> scale;
  final Animation<double> drag;
  final bool isTop;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: presence,
    alwaysIncludeSemantics: true,
    child: ScaleTransition(
      scale: scale,
      child: AnimatedBuilder(
        animation: presence,
        child: AnimatedBuilder(
          animation: drag,
          child: child,
          builder:
              (context, child) => Transform.translate(
                offset: Offset(0, drag.value),
                child: child,
              ),
        ),
        builder:
            (context, child) => Transform.translate(
              offset: Offset(
                0,
                (isTop ? -1 : 1) *
                    SileoConstants.entryTranslate *
                    (1 - presence.value),
              ),
              child: child,
            ),
      ),
    ),
  );
}

/// Sizes the toast to its animated height without rebuilding the subtree.
class _ToastBox extends StatelessWidget {
  const _ToastBox({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final Animation<double> height;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: height,
    child: child,
    builder:
        (context, child) => SizedBox(
          width: width,
          height: math.max(0, height.value) + 2 * SileoConstants.tapExtension,
          child: child,
        ),
  );
}

/// The gooey outline. Springs repaint it directly; it never rebuilds.
class _ToastShape extends StatelessWidget {
  const _ToastShape({
    required this.fill,
    required this.roundness,
    required this.width,
    required this.headerHeight,
    required this.flipped,
    required this.pillX,
    required this.pillWidth,
    required this.bodyHeight,
    required this.bodyOpacity,
    required this.toastHeight,
    required this.repaint,
  });

  final Color fill;
  final double roundness;
  final double width;
  final double headerHeight;
  final bool flipped;
  final Animation<double> pillX;
  final Animation<double> pillWidth;
  final Animation<double> bodyHeight;
  final Animation<double> bodyOpacity;
  final Animation<double> toastHeight;
  final Listenable repaint;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: SileoShapePainter(
          fill: fill,
          roundness: roundness,
          width: width,
          headerHeight: headerHeight,
          pillX: pillX,
          pillWidth: pillWidth,
          bodyHeight: bodyHeight,
          bodyOpacity: bodyOpacity,
          toastHeight: toastHeight,
          repaint: repaint,
          flipped: flipped,
          verticalInset: SileoConstants.tapExtension,
        ),
      ),
    ),
  );
}

/// Description and button; fades with the CSS curve, ignored while closed.
class _ToastContent extends StatelessWidget {
  const _ToastContent({
    required this.view,
    required this.tone,
    required this.descriptionColor,
    required this.opacity,
    required this.open,
    required this.isTop,
    required this.headerHeight,
    required this.metrics,
    required this.onSize,
  });

  final _View view;
  final Color tone;
  final Color? descriptionColor;
  final Animation<double> opacity;
  final bool open;
  final bool isTop;
  final double headerHeight;
  final _Metrics metrics;
  final ValueChanged<Size> onSize;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: isTop ? headerHeight : 0,
    child: FadeTransition(
      opacity: opacity,
      child: ExcludeSemantics(
        excluding: !open,
        child: IgnorePointer(
          ignoring: !open,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            fit: OverflowBoxFit.deferToChild,
            minHeight: 0,
            maxHeight: double.infinity,
            child: _SizeReporter(
              onSize: onSize,
              child: _ContentBody(
                view: view,
                tone: tone,
                descriptionColor: descriptionColor,
                metrics: metrics,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The header: positioned at the pill, clipped to its (lagging) width, and
/// scaled/shifted while the body is open.
class _ToastHeader extends StatelessWidget {
  const _ToastHeader({
    required this.animation,
    required this.left,
    required this.width,
    required this.open,
    required this.current,
    required this.prev,
    required this.toneOf,
    required this.isTop,
    required this.height,
    required this.metrics,
    required this.maxRowWidth,
    required this.onRowSize,
  });

  final Listenable animation;
  final Animation<double> left;
  final Animation<double> width;
  final Animation<double> open;
  final _View current;
  final _View? prev;
  final Color Function(SileoState) toneOf;
  final bool isTop;
  final double height;
  final _Metrics metrics;
  final double maxRowWidth;
  final ValueChanged<Size> onRowSize;

  @override
  Widget build(BuildContext context) {
    final previous = prev;
    return AnimatedBuilder(
      animation: animation,
      child: ExcludeSemantics(
        child: ClipRect(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SileoConstants.headerPadding,
            ),
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: maxRowWidth,
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [
                  _HeaderLayer(
                    key: ValueKey('current-${current.headerKey}'),
                    view: current,
                    tone: toneOf(current.state),
                    transition:
                        previous == null ? _Transition.none : _Transition.enter,
                    metrics: metrics,
                    onRowSize: onRowSize,
                  ),
                  if (previous != null)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: 1,
                        child: _HeaderLayer(
                          key: ValueKey('prev-${previous.headerKey}'),
                          view: previous,
                          tone: toneOf(previous.state),
                          transition: _Transition.exit,
                          metrics: metrics,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      builder: (context, child) {
        final t = open.value;
        return Positioned(
          left: left.value,
          top: isTop ? 0 : null,
          bottom: isTop ? null : 0,
          width: math.max(0, width.value),
          height: height,
          child: Transform.translate(
            offset: Offset(
              0,
              (isTop ? 1 : -1) * SileoConstants.headerTranslate * t,
            ),
            child: Transform.scale(
              scale: 1 - (1 - SileoConstants.headerScale) * t,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
