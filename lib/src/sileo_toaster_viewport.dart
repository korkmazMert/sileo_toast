part of 'sileo_toaster.dart';

/// The viewport of every position that has toasts. Mounted only while there
/// are any, and the only reader of the safe area: with no toast shown, a safe
/// area that changes (the keyboard covering the home indicator) rebuilds
/// nothing.
class _Viewports extends StatelessWidget {
  const _Viewports({
    required this.items,
    required this.offset,
    required this.fill,
    required this.textStyle,
    required this.activeId,
    required this.persist,
    required this.onDismiss,
    required this.onEngaged,
  });

  final List<SileoItem> items;
  final EdgeInsets offset;
  final SileoFill fill;
  final TextStyle? textStyle;
  final String? activeId;
  final bool persist;
  final void Function(String id) onDismiss;
  final void Function(String id, {required bool engaged}) onEngaged;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;
    const pad = SileoConstants.viewportPadding;
    const ext = SileoConstants.tapExtension;
    final inset = EdgeInsets.fromLTRB(
      safe.left + offset.left + pad,
      safe.top + offset.top + pad - ext,
      safe.right + offset.right + pad,
      safe.bottom + offset.bottom + pad - ext,
    );
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
                  textStyle: textStyle,
                  activeId: activeId,
                  persist: persist,
                  onDismiss: onDismiss,
                  onEngaged: onEngaged,
                ),
          ],
        );
      },
    );
  }
}

class _Viewport extends StatelessWidget {
  const _Viewport({
    required this.position,
    required this.inset,
    required this.items,
    required this.width,
    required this.largeWidth,
    required this.fill,
    required this.textStyle,
    required this.activeId,
    required this.persist,
    required this.onDismiss,
    required this.onEngaged,
  });

  final SileoPosition position;
  final EdgeInsets inset;
  final List<SileoItem> items;
  final double width;
  final double largeWidth;
  final SileoFill fill;
  final TextStyle? textStyle;
  final String? activeId;
  final bool persist;
  final void Function(String id) onDismiss;
  final void Function(String id, {required bool engaged}) onEngaged;

  @override
  Widget build(BuildContext context) {
    // Top: newest first. Bottom: newest last. Each view is 8 dp taller than
    // its toast, so the 12 dp gap shrinks by the same amount.
    final ordered = position.isTop ? items.reversed.toList() : items;
    return Positioned.fill(
      child: Padding(
        padding: inset,
        child: Align(
          alignment: position.pillAlign,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // Toasts of different sizes keep the viewport's alignment.
            crossAxisAlignment: switch (position.pillAlign.x) {
              < 0 => CrossAxisAlignment.start,
              > 0 => CrossAxisAlignment.end,
              _ => CrossAxisAlignment.center,
            },
            children: [
              for (var n = 0; n < ordered.length; n++) ...[
                if (n > 0)
                  const SizedBox(
                    height:
                        SileoConstants.viewportGap -
                        2 * SileoConstants.tapExtension,
                  ),
                SileoToastView(
                  key: ValueKey(ordered[n].id),
                  item: ordered[n],
                  width: width,
                  largeWidth: largeWidth,
                  fill: ordered[n].options.fill ?? fill.fill,
                  descriptionColor: fill.description,
                  textStyle: textStyle,
                  canExpand: ordered[n].id == activeId,
                  persistWhenAccessibleNavigation: persist,
                  onDismiss: () => onDismiss(ordered[n].id),
                  onEngagedChanged: (e) => onEngaged(ordered[n].id, engaged: e),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
