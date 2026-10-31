part of 'sileo_toast_view.dart';

/// Hides an unlabeled trailing from semantics. A top-level `Semantics` is the
/// caller's own label: it stays, as its own node.
class _TrailingSlot extends StatelessWidget {
  const new({required this.trailing, required this.child});

  final Widget trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => trailing is Semantics
      ? Semantics(container: true, child: child)
      : ExcludeSemantics(child: child);
}

/// Large body: description and trailing thumbnail, then the buttons row.
class _LargeBody extends StatelessWidget {
  const new({
    required this.view,
    required this.tone,
    required this.descriptionColor,
    required this.padding,
  });

  final _View view;
  final Color tone;
  final Color? descriptionColor;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final description = view.description;
    final trailing = view.trailing;
    final primary = view.button;
    final secondary = view.secondaryButton;
    const gap = SileoConstants.largeButtonGap;
    // Reads on every fill: the theme's description color (opaque), else the
    // ambient text color.
    final secondaryTone =
        (descriptionColor ??
                DefaultTextStyle.of(context).style.color ??
                SileoConstants.lightDescription)
            .withValues(alpha: 1);
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (description != null || trailing != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: description == null
                      ? const SizedBox.shrink()
                      : DefaultTextStyle.merge(
                          style: TextStyle(
                            fontSize: SileoConstants.descriptionFontSize,
                            height:
                                SileoConstants.descriptionLineHeight /
                                SileoConstants.descriptionFontSize,
                            color: descriptionColor,
                          ).merge(view.styles?.description),
                          child: description,
                        ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: gap),
                  _TrailingSlot(
                    trailing: trailing,
                    child: RepaintBoundary(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(SileoConstants.largeTrailingRadius),
                        ),
                        child: SizedBox.square(
                          dimension: SileoConstants.largeTrailingSize,
                          child: trailing,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          if (primary != null || secondary != null)
            Padding(
              padding: EdgeInsets.only(
                top: description != null || trailing != null ? gap : 0,
              ),
              child: Row(
                children: [
                  if (secondary != null)
                    Expanded(
                      child: _ActionButton(
                        button: secondary,
                        tone: secondaryTone,
                        styles: null,
                        pillHeight: SileoConstants.largeButtonHeight,
                        fontSize: SileoConstants.largeButtonFontSize,
                        idleAlpha: SileoConstants.largeSecondaryAlpha,
                      ),
                    ),
                  if (secondary != null && primary != null)
                    const SizedBox(width: gap),
                  if (primary != null)
                    Expanded(
                      child: _ActionButton(
                        button: primary,
                        tone: tone,
                        styles: view.styles,
                        pillHeight: SileoConstants.largeButtonHeight,
                        fontSize: SileoConstants.largeButtonFontSize,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
