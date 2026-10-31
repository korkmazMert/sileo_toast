part of 'sileo_toaster.dart';

class _Viewport extends StatelessWidget {
  const new({
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
