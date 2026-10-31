part of 'sileo_toast_view.dart';

const Color _secondaryTone = Color(0xFFFFFFFF);

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
                  ExcludeSemantics(
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
                        tone: _secondaryTone,
                        styles: null,
                        pillHeight: SileoConstants.largeButtonHeight,
                        fontSize: SileoConstants.largeButtonFontSize,
                        maxLines: 2,
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
                        maxLines: 2,
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
