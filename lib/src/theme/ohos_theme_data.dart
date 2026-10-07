import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ohos_colors.dart';
import 'ohos_typography.dart';

/// Immutable set of HarmonyOS design tokens, the `ohos_ui` counterpart of
/// Flutter's [ThemeData] / `CupertinoThemeData`.
///
/// Obtain the current data with [OhosTheme.of].
@immutable
class OhosThemeData with Diagnosticable {
  const OhosThemeData({
    required this.brightness,
    required this.highlightColor,
    required this.highlightTextColor,
    required this.backgroundColor,
    required this.cardColor,
    required this.popupColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.textTertiaryColor,
    required this.multiColors,
    required this.successColor,
    required this.warningColor,
    required this.dangerColor,
    required this.onHighlightColor,
    required this.dividerColor,
    required this.scrimColor,
    required this.typography,
  });

  /// Whether this theme targets a light or dark interface.
  final Brightness brightness;

  /// Brand / system highlight color (light: #0A59F7, dark: #317AF7).
  final Color highlightColor;

  /// Text / icons placed on [highlightColor].
  final Color onHighlightColor;

  /// Highlighted text color (dark mode uses a lighter blue).
  final Color highlightTextColor;

  /// Page background color.
  final Color backgroundColor;

  /// Card and list-item surface color.
  final Color cardColor;

  /// Popup / dialog / menu surface color.
  final Color popupColor;

  /// Primary text color (90% opacity in light mode).
  final Color textPrimaryColor;

  /// Secondary text color (60% opacity).
  final Color textSecondaryColor;

  /// Tertiary text color (40% opacity).
  final Color textTertiaryColor;

  /// The 11-color HarmonyOS multi-color system.
  final List<Color> multiColors;

  /// Success functional color.
  final Color successColor;

  /// Warning functional color.
  final Color warningColor;

  /// Danger functional color.
  final Color dangerColor;

  /// Hairline color separating list items.
  final Color dividerColor;

  /// Scrim color behind dialogs / popups.
  final Color scrimColor;

  /// HarmonyOS typography tokens.
  final OhosTypography typography;

  /// True when [brightness] is [Brightness.dark].
  bool get isDark => brightness == Brightness.dark;

  /// Standard light theme assembled from official HarmonyOS tokens.
  factory OhosThemeData.light({String? fontFamily}) {
    return OhosThemeData(
      brightness: Brightness.light,
      highlightColor: OhosColors.highlight,
      onHighlightColor: Colors.white,
      highlightTextColor: OhosColors.highlight,
      backgroundColor: OhosColors.background,
      cardColor: OhosColors.card,
      popupColor: OhosColors.popup,
      textPrimaryColor: OhosColors.textPrimaryLight,
      textSecondaryColor: OhosColors.textSecondaryLight,
      textTertiaryColor: OhosColors.textTertiaryLight,
      multiColors: OhosColors.multiLight,
      successColor: OhosColors.success,
      warningColor: OhosColors.warning,
      dangerColor: OhosColors.danger,
      dividerColor: const Color(0x14000000),
      scrimColor: OhosColors.scrim,
      typography: OhosTypography.light(fontFamily: fontFamily),
    );
  }

  /// Standard dark theme assembled from official HarmonyOS tokens.
  factory OhosThemeData.dark({String? fontFamily}) {
    return OhosThemeData(
      brightness: Brightness.dark,
      highlightColor: OhosColors.highlightDark,
      onHighlightColor: Colors.white,
      highlightTextColor: OhosColors.highlightTextDark,
      backgroundColor: OhosColors.backgroundDark,
      cardColor: OhosColors.cardDark,
      popupColor: OhosColors.popupDark,
      textPrimaryColor: OhosColors.textPrimaryDark,
      textSecondaryColor: OhosColors.textSecondaryDark,
      textTertiaryColor: OhosColors.textTertiaryDark,
      multiColors: OhosColors.multiDark,
      successColor: OhosColors.successDark,
      warningColor: OhosColors.warningDark,
      dangerColor: OhosColors.dangerDark,
      dividerColor: const Color(0x29FFFFFF),
      scrimColor: OhosColors.scrim,
      typography: OhosTypography.dark(fontFamily: fontFamily),
    );
  }

  /// Returns a copy with the given fields replaced.
  OhosThemeData copyWith({
    Brightness? brightness,
    Color? highlightColor,
    Color? onHighlightColor,
    Color? highlightTextColor,
    Color? backgroundColor,
    Color? cardColor,
    Color? popupColor,
    Color? textPrimaryColor,
    Color? textSecondaryColor,
    Color? textTertiaryColor,
    List<Color>? multiColors,
    Color? successColor,
    Color? warningColor,
    Color? dangerColor,
    Color? dividerColor,
    Color? scrimColor,
    OhosTypography? typography,
  }) {
    return OhosThemeData(
      brightness: brightness ?? this.brightness,
      highlightColor: highlightColor ?? this.highlightColor,
      onHighlightColor: onHighlightColor ?? this.onHighlightColor,
      highlightTextColor: highlightTextColor ?? this.highlightTextColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      cardColor: cardColor ?? this.cardColor,
      popupColor: popupColor ?? this.popupColor,
      textPrimaryColor: textPrimaryColor ?? this.textPrimaryColor,
      textSecondaryColor: textSecondaryColor ?? this.textSecondaryColor,
      textTertiaryColor: textTertiaryColor ?? this.textTertiaryColor,
      multiColors: multiColors ?? this.multiColors,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      dangerColor: dangerColor ?? this.dangerColor,
      dividerColor: dividerColor ?? this.dividerColor,
      scrimColor: scrimColor ?? this.scrimColor,
      typography: typography ?? this.typography,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Brightness>('brightness', brightness));
    properties.add(ColorProperty('highlightColor', highlightColor));
  }
}
