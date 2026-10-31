import 'package:flutter/widgets.dart';

/// Every Sileo number, in one place (parity with `constants.ts`/`styles.css`).
abstract final class SileoConstants {
  // Toast size.
  /// Pill and header height.
  static const double height = 40;

  /// Maximum toast width (`min(width, available - 2 * viewportPadding)`).
  static const double width = 350;

  /// Default corner roundness.
  static const double defaultRoundness = 16;

  // Durations.
  /// Spring and transition duration.
  static const Duration duration = Duration(milliseconds: 600);

  /// Default auto-dismiss delay.
  static const Duration defaultToastDuration = Duration(milliseconds: 6000);

  /// Time an exiting toast stays before removal.
  static const Duration exitDuration = Duration(milliseconds: 600);

  /// Default autopilot expand delay.
  static const Duration autoExpandDelay = Duration(milliseconds: 150);

  /// Default autopilot collapse delay.
  static const Duration autoCollapseDelay = Duration(milliseconds: 4000);

  /// Collapse time before a same-id morph swaps content.
  static const Duration swapCollapse = Duration(milliseconds: 200);

  /// Previous header layer exit time.
  static const Duration headerExit = Duration(milliseconds: 420);

  /// Entry/exit transition (opacity, scale, translate).
  static const Duration entryDuration = Duration(milliseconds: 396);

  /// Content fade-in when opening.
  static const Duration contentOpenFade = Duration(milliseconds: 360);

  /// Content fade-in delay when opening.
  static const Duration contentOpenDelay = Duration(milliseconds: 180);

  /// Content fade-out when closing.
  static const Duration contentCloseFade = Duration(milliseconds: 48);

  /// Content fade-out delay when closing.
  static const Duration contentCloseDelay = Duration(milliseconds: 24);

  /// One turn of the loading spinner.
  static const Duration spinnerTurn = Duration(seconds: 1);

  // Springs: Motion `findSpring`, mass 1.
  /// Stiffness of `findSpring(duration: 600ms, bounce: 0.25)`.
  static const double springStiffness = 244.29;

  /// Damping of `findSpring(duration: 600ms, bounce: 0.25)`.
  static const double springDamping = 23.44;

  /// Stiffness of `findSpring(duration: 600ms, bounce: 0)`.
  static const double closeSpringStiffness = 236.82;

  /// Damping of `findSpring(duration: 600ms, bounce: 0)`.
  static const double closeSpringDamping = 30.78;

  /// Mass of both springs.
  static const double springMass = 1;

  /// Sileo's `--sileo-spring-easing` `linear()` stops as (progress, value).
  static const List<(double, double)> springCurveStops = [
    (0, 0),
    (0.006, 0.002),
    (0.012, 0.007),
    (0.018, 0.015),
    (0.024, 0.026),
    (0.031, 0.041),
    (0.038, 0.06),
    (0.053, 0.108),
    (0.066, 0.157),
    (0.08, 0.214),
    (0.137, 0.467),
    (0.163, 0.577),
    (0.177, 0.631),
    (0.191, 0.682),
    (0.205, 0.73),
    (0.218, 0.771),
    (0.231, 0.808),
    (0.245, 0.844),
    (0.258, 0.874),
    (0.272, 0.903),
    (0.286, 0.928),
    (0.301, 0.952),
    (0.316, 0.972),
    (0.331, 0.988),
    (0.357, 1.01),
    (0.385, 1.025),
    (0.416, 1.034),
    (0.45, 1.038),
    (0.501, 1.035),
    (0.642, 1.012),
    (0.73, 1.003),
    (0.837, 0.999),
    (1, 1),
  ];

  // Shape.
  /// Fillet radius = roundness * blurRatio.
  static const double blurRatio = 0.5;

  /// Extra pill width beyond the header row.
  static const double pillPadding = 10;

  /// Expanded height is at least height * minExpandRatio.
  static const double minExpandRatio = 2.25;

  /// Below this the body is treated as absent or a side as flush (dp).
  static const double shapeEpsilon = 0.5;

  // Swipe.
  /// Drag distance that dismisses.
  static const double swipeDismiss = 30;

  /// Drag follow clamp.
  static const double swipeMax = 20;

  // Viewport.
  /// Distance from the safe area edge.
  static const double viewportPadding = 12;

  /// Visual gap between stacked toasts.
  static const double viewportGap = 12;

  /// Minimum interactive target.
  static const double minTapTarget = 48;

  /// Gesture box extension above and below a toast.
  static const double tapExtension = 4;

  // Header.
  /// Header horizontal padding.
  static const double headerPadding = 8;

  /// Gap between badge and title.
  static const double headerGap = 8;

  /// Header layer translateY while crossfading.
  static const double headerTranslate = 3;

  /// Header layer scale while crossfading.
  static const double headerScale = 0.9;

  /// Header blur radius, in and out.
  static const double headerBlur = 6;

  // Entry/exit.
  /// Scale of a toast before it is ready.
  static const double entryScale = 0.95;

  /// TranslateY of a toast before it is ready.
  static const double entryTranslate = 6;

  // Badge.
  /// Badge size.
  static const double badgeSize = 24;

  /// Badge padding.
  static const double badgePadding = 2;

  /// Badge icon size.
  static const double badgeIconSize = 16;

  /// Icon viewBox edge (Lucide).
  static const double iconViewBox = 24;

  /// Icon stroke width in viewBox units.
  static const double iconStroke = 2;

  // Typography.
  /// Title font size.
  static const double titleFontSize = 13.2;

  /// Title line height.
  static const double titleLineHeight = 16;

  /// Title weight.
  static const FontWeight titleWeight = FontWeight.w500;

  /// Description font size.
  static const double descriptionFontSize = 14;

  /// Description line height.
  static const double descriptionLineHeight = 20;

  /// Description padding.
  static const double descriptionPadding = 16;

  // Button.
  /// Button pill height.
  static const double buttonHeight = 28;

  /// Button horizontal padding.
  static const double buttonHPadding = 10;

  /// Button top margin.
  static const double buttonMarginTop = 12;

  /// Button label font size.
  static const double buttonFontSize = 12;

  /// Button label weight.
  static const FontWeight buttonWeight = FontWeight.w500;

  /// Keyboard focus ring width on the action button.
  static const double focusRingWidth = 2;

  /// Button background color transition.
  static const Duration buttonFade = Duration(milliseconds: 150);

  /// Hit box padding above and below the button pill (hit box is
  /// [minTapTarget] tall); the button margins are cut by this much.
  static const double buttonHitMargin = (minTapTarget - buttonHeight) / 2;

  // Alphas.
  /// Badge background alpha.
  static const double badgeAlpha = 0.20;

  /// Button background alpha.
  static const double buttonAlpha = 0.15;

  /// Pressed button background alpha.
  static const double buttonPressedAlpha = 0.25;

  /// Description alpha on theme fills.
  static const double descriptionAlpha = 0.5;

  // State colors (Sileo's oklch converted to sRGB).
  /// Success tone.
  static const Color success = Color(0xFF22C55E);

  /// Loading tone.
  static const Color loading = Color(0xFF737373);

  /// Error tone.
  static const Color error = Color(0xFFEF4444);

  /// Warning tone.
  static const Color warning = Color(0xFFEAB308);

  /// Info tone.
  static const Color info = Color(0xFF0EA5E9);

  /// Action tone.
  static const Color action = Color(0xFF3B82F6);

  // Fills.
  /// Fill of the `light` theme (inverted, as in Sileo).
  static const Color lightFill = Color(0xFF1A1A1A);

  /// Fill of the `dark` theme.
  static const Color darkFill = Color(0xFFF2F2F2);

  /// Fill when no theme is set.
  static const Color defaultFill = Color(0xFFFFFFFF);

  /// Description base color on the `light` fill.
  static const Color lightDescription = Color(0xFFFFFFFF);

  /// Description base color on the `dark` fill.
  static const Color darkDescription = Color(0xFF000000);

  // Large size.
  /// Closed large pill and header height floor.
  static const double largeHeight = 56;

  /// Large badge diameter.
  static const double largeBadgeSize = 32;

  /// Large badge icon size.
  static const double largeIconSize = 20;

  /// Large title font size.
  static const double largeTitleFontSize = 17;

  /// Large title line height in logical pixels.
  static const double largeTitleLineHeight = 22;

  /// Maximum width of an open large toast (tablets, desktop).
  static const double largeMaxWidth = 520;

  /// Padding of the large body.
  static const double largeBodyPadding = 16;

  /// Gap between the description and trailing, and between buttons.
  static const double largeButtonGap = 12;

  /// Large button height (its own hit box).
  static const double largeButtonHeight = 48;

  /// Large button label font size.
  static const double largeButtonFontSize = 15;

  /// Large trailing thumbnail side.
  static const double largeTrailingSize = 64;

  /// Large trailing thumbnail corner radius.
  static const double largeTrailingRadius = 12;

  /// Default corner roundness of the large body.
  static const double largeRoundness = 24;

  /// Secondary button background alpha (white on the fill).
  static const double largeSecondaryAlpha = 0.12;

  // Island.
  /// Black of the island presentation, whatever the theme.
  static const Color islandFill = Color(0xFF000000);

  /// Inflation of the neck so it covers the cutout's anti-aliased edge.
  static const double islandBleed = 1.5;

  /// Max distance of an Android cutout center from the screen center.
  static const double islandCenterTolerance = 1;

  /// Widest Android cutout still treated as a camera island.
  static const double islandMaxWidth = 200;

  /// Tolerance when matching a table key against padding and size.
  static const double islandKeyTolerance = 0.5;

  /// iOS Dynamic Island rows: (viewPadding.top, screen width, screen height,
  /// island width, island height, island top), all logical points.
  ///
  /// Screen sizes are Apple's published logical resolutions. The 59 pt rows
  /// use the MIT-licensed `sole_toast` geometry (126 x 37 at top 11.6). The
  /// 62 pt rows were measured from iOS 26 simulator screenshots (iPhone 17
  /// Pro and 17 Pro Max: 126 x 37 centered, top 14.0); the 16 Pro and 16 Pro
  /// Max share those screen sizes. iPhone Air (68 pt) is not measured, so it
  /// falls back to a normal top toast; hosts can supply their own rect through
  /// `SileoToaster.island`.
  static const List<(double, double, double, double, double, double)>
  islandTable = [
    // 14 Pro, 15, 15 Pro, 16.
    (59, 393, 852, 126, 37, 11.6),
    // 14 Pro Max, 15 Plus, 15 Pro Max, 16 Plus.
    (59, 430, 932, 126, 37, 11.6),
    // 16 Pro, 17, 17 Pro (measured on the 17 Pro simulator).
    (62, 402, 874, 126, 37, 14),
    // 16 Pro Max, 17 Pro Max (measured on the 17 Pro Max simulator).
    (62, 440, 956, 126, 37, 14),
  ];

  // Text.
  /// Toast text style when the toaster supplies none.
  static const TextStyle neutralText = TextStyle(
    inherit: false,
    color: Color(0xFF000000),
    fontSize: descriptionFontSize,
    decoration: TextDecoration.none,
  );
}
