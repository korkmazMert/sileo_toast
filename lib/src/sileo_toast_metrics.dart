part of 'sileo_toast_view.dart';

/// Every size-driven metric of a toast, resolved once per content or text
/// scale change so no widget branches on the size itself.
@immutable
class _Metrics {
  const new({
    required this.large,
    required this.header,
    required this.badge,
    required this.icon,
    required this.titleSize,
    required this.titleLine,
    required this.bodyPadding,
    required this.roundness,
  });

  factory of(SileoSize size, TextScaler scaler) {
    final large = size == SileoSize.large;
    final titleLine = large
        ? SileoConstants.largeTitleLineHeight
        : SileoConstants.titleLineHeight;
    return _Metrics(
      large: large,
      header: math.max(
        large ? SileoConstants.largeHeight : SileoConstants.height,
        scaler.scale(titleLine) + 2 * SileoConstants.headerPadding,
      ),
      badge: large ? SileoConstants.largeBadgeSize : SileoConstants.badgeSize,
      icon: large ? SileoConstants.largeIconSize : SileoConstants.badgeIconSize,
      titleSize: large
          ? SileoConstants.largeTitleFontSize
          : SileoConstants.titleFontSize,
      titleLine: titleLine,
      bodyPadding: large ? SileoConstants.largeBodyPadding : 0,
      roundness: large
          ? SileoConstants.largeRoundness
          : SileoConstants.defaultRoundness,
    );
  }

  final bool large;
  final double header;
  final double badge;
  final double icon;
  final double titleSize;
  final double titleLine;
  final double bodyPadding;
  final double roundness;
}
