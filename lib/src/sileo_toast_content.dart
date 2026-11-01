part of 'sileo_toast_view.dart';

/// Description and action button, below (or above, for bottom toasts) the
/// header. Padding matches Sileo; the button's 48 dp hit box eats into the
/// margins so the visual spacing is unchanged.
class _ContentBody extends StatelessWidget {
  const _ContentBody({
    required this.view,
    required this.tone,
    required this.descriptionColor,
    required this.metrics,
  });

  final _View view;
  final Color tone;
  final Color? descriptionColor;
  final _Metrics metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.large) {
      return _LargeBody(
        view: view,
        tone: tone,
        descriptionColor: descriptionColor,
        padding: metrics.bodyPadding,
      );
    }
    final description = view.description;
    final button = view.button;
    const pad = SileoConstants.descriptionPadding;
    const hit = SileoConstants.buttonHitMargin;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        pad,
        pad,
        pad,
        button == null ? pad : pad - hit,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (description != null)
            DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: SileoConstants.descriptionFontSize,
                height:
                    SileoConstants.descriptionLineHeight /
                    SileoConstants.descriptionFontSize,
                color: descriptionColor,
              ).merge(view.styles?.description),
              child: description,
            ),
          if (button != null)
            Padding(
              padding: const EdgeInsets.only(
                top: SileoConstants.buttonMarginTop - hit,
              ),
              child: _ActionButton(
                button: button,
                tone: tone,
                styles: view.styles,
              ),
            ),
        ],
      ),
    );
  }
}

/// The action button: a 28 dp pill in a 48 dp hit box with its own gesture.
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.button,
    required this.tone,
    required this.styles,
    this.pillHeight = SileoConstants.buttonHeight,
    this.fontSize = SileoConstants.buttonFontSize,
    this.idleAlpha = SileoConstants.buttonAlpha,
  });

  final SileoButton button;
  final Color tone;
  final SileoStyles? styles;

  /// Pill height inside the 48 dp hit box.
  final double pillHeight;
  final double fontSize;

  /// Label line limit; also centers a wrapped label. Null: unlimited, as is.
  final double idleAlpha;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && _activators.contains(event.logicalKey)) {
      widget.button.onPressed();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static final Set<LogicalKeyboardKey> _activators = {
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
  };

  @override
  Widget build(BuildContext context) {
    final styles = widget.styles;
    final tone = widget.tone;
    final highlighted = _pressed || _hovered;
    final background =
        highlighted
            ? styles?.buttonPressedBackground ??
                tone.withValues(alpha: SileoConstants.buttonPressedAlpha)
            : styles?.buttonBackground ??
                tone.withValues(alpha: widget.idleAlpha);
    final fade =
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
            ? Duration.zero
            : SileoConstants.buttonFade;
    return Semantics(
      container: true,
      button: true,
      label: widget.button.title,
      onTap: widget.button.onPressed,
      excludeSemantics: true,
      child: Focus(
        onKeyEvent: _onKey,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: MouseRegion(
          hitTestBehavior: HitTestBehavior.deferToChild,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.button.onPressed,
            // Wins the arena over the toast's swipe, which ignores the button.
            onVerticalDragStart: (_) {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: SileoConstants.minTapTarget,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: widget.pillHeight),
                  child: AnimatedContainer(
                    duration: fade,
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(
                        side:
                            _focused
                                ? BorderSide(
                                  color: tone,
                                  width: SileoConstants.focusRingWidth,
                                )
                                : BorderSide.none,
                      ),
                      color: background,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: SileoConstants.buttonHPadding,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.button.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        fontWeight: SileoConstants.buttonWeight,
                        color: styles?.buttonForeground ?? tone,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
