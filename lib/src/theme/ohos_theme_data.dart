import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ohos_colors.dart';
import 'ohos_typography.dart';

/// Immutable set of HarmonyOS design tokens, the `ohos_ui` counterpart of
/// Flutter's [ThemeData] / `CupertinoThemeData`.
///
/// Obtain the current data with [OhosTheme.of]. The color fields mirror the
/// official token tables (基础/通用语义 Token)：background layers, component
/// surfaces, emphasize levels, interactive states and text levels.
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
    this.backgroundSecondaryColor,
    this.backgroundTertiaryColor,
    this.compBackgroundPrimaryColor,
    this.compBackgroundGrayColor,
    this.emphasizeSecondaryColor,
    this.emphasizeTertiaryColor,
    this.interactiveHoverColor,
    this.interactivePressedColor,
    this.interactiveFocusColor,
    this.interactiveSelectColor,
    this.textFourthColor,
  });

  /// Whether this theme targets a light or dark interface.
  final Brightness brightness;

  /// Brand / system highlight color (light: #0A59F7, dark: #317AF7).
  final Color highlightColor;

  /// Text / icons placed on [highlightColor].
  final Color onHighlightColor;

  /// Highlighted text color (dark mode uses a lighter blue).
  final Color highlightTextColor;

  /// Page background color (`background_secondary` in light mode).
  final Color backgroundColor;

  /// Secondary page background (`background_primary` related layer).
  final Color? backgroundSecondaryColor;

  /// Tertiary page background (`background_tertiary`).
  final Color? backgroundTertiaryColor;

  /// Card and list-item surface color.
  final Color cardColor;

  /// Component primary background (`comp_background_primary`).
  final Color? compBackgroundPrimaryColor;

  /// Component gray background (`comp_background_gray`).
  final Color? compBackgroundGrayColor;

  /// Popup / dialog / menu surface color.
  final Color popupColor;

  /// Primary text color (90% opacity).
  final Color textPrimaryColor;

  /// Secondary text color (60% opacity).
  final Color textSecondaryColor;

  /// Tertiary text color (40% opacity).
  final Color textTertiaryColor;

  /// Fourth-level text color (20% opacity, `font_fourth`).
  final Color? textFourthColor;

  /// The 11-color HarmonyOS multi-color system.
  final List<Color> multiColors;

  /// Success functional color.
  final Color successColor;

  /// Warning functional color.
  final Color warningColor;

  /// Danger functional color.
  final Color dangerColor;

  /// 20% brand highlight background (`comp_emphasize_secondary`), used by
  /// selected / emphasized control states.
  final Color? emphasizeSecondaryColor;

  /// 10% brand highlight background (`comp_emphasize_tertiary`).
  final Color? emphasizeTertiaryColor;

  /// Hover interaction color (`interactive_hover`).
  final Color? interactiveHoverColor;

  /// Pressed interaction color (`interactive_pressed`).
  final Color? interactivePressedColor;

  /// Focus interaction color (`interactive_focus`).
  final Color? interactiveFocusColor;

  /// Selected interaction color (`interactive_select`).
  final Color? interactiveSelectColor;

  /// Hairline color separating list items (`comp_divider`).
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
      backgroundSecondaryColor: OhosColors.background,
      backgroundTertiaryColor: OhosColors.backgroundTertiary,
      cardColor: OhosColors.card,
      compBackgroundPrimaryColor: OhosColors.compBackgroundPrimary,
      compBackgroundGrayColor: OhosColors.compBackgroundGray,
      popupColor: OhosColors.popup,
      textPrimaryColor: OhosColors.textPrimaryLight,
      textSecondaryColor: OhosColors.textSecondaryLight,
      textTertiaryColor: OhosColors.textTertiaryLight,
      textFourthColor: OhosColors.textFourthLight,
      multiColors: OhosColors.multiLight,
      successColor: OhosColors.success,
      warningColor: OhosColors.warning,
      dangerColor: OhosColors.danger,
      emphasizeSecondaryColor: OhosColors.emphasizeSecondary,
      emphasizeTertiaryColor: OhosColors.emphasizeTertiary,
      interactiveHoverColor: OhosColors.interactiveHover,
      interactivePressedColor: OhosColors.interactivePressed,
      interactiveFocusColor: OhosColors.interactiveFocus,
      interactiveSelectColor: OhosColors.interactiveSelect,
      dividerColor: OhosColors.interactivePressed,
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
      backgroundSecondaryColor: OhosColors.backgroundDark,
      backgroundTertiaryColor: OhosColors.backgroundTertiaryDark,
      cardColor: OhosColors.compBackgroundPrimaryDark,
      compBackgroundPrimaryColor: OhosColors.compBackgroundPrimaryDark,
      compBackgroundGrayColor: OhosColors.compBackgroundGrayDark,
      popupColor: OhosColors.compBackgroundPrimaryDark,
      textPrimaryColor: OhosColors.textPrimaryDark,
      textSecondaryColor: OhosColors.textSecondaryDark,
      textTertiaryColor: OhosColors.textTertiaryDark,
      textFourthColor: OhosColors.textFourthDark,
      multiColors: OhosColors.multiDark,
      successColor: OhosColors.successDark,
      warningColor: OhosColors.warningDark,
      dangerColor: OhosColors.dangerDark,
      emphasizeSecondaryColor: OhosColors.emphasizeSecondaryDark,
      emphasizeTertiaryColor: OhosColors.emphasizeTertiaryDark,
      interactiveHoverColor: OhosColors.interactiveHoverDark,
      interactivePressedColor: OhosColors.interactivePressedDark,
      interactiveFocusColor: OhosColors.interactiveFocusDark,
      interactiveSelectColor: OhosColors.interactiveSelectDark,
      dividerColor: OhosColors.interactivePressedDark,
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
    Color? backgroundSecondaryColor,
    Color? backgroundTertiaryColor,
    Color? cardColor,
    Color? compBackgroundPrimaryColor,
    Color? compBackgroundGrayColor,
    Color? popupColor,
    Color? textPrimaryColor,
    Color? textSecondaryColor,
    Color? textTertiaryColor,
    Color? textFourthColor,
    List<Color>? multiColors,
    Color? successColor,
    Color? warningColor,
    Color? dangerColor,
    Color? emphasizeSecondaryColor,
    Color? emphasizeTertiaryColor,
    Color? interactiveHoverColor,
    Color? interactivePressedColor,
    Color? interactiveFocusColor,
    Color? interactiveSelectColor,
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
      backgroundSecondaryColor:
          backgroundSecondaryColor ?? this.backgroundSecondaryColor,
      backgroundTertiaryColor:
          backgroundTertiaryColor ?? this.backgroundTertiaryColor,
      cardColor: cardColor ?? this.cardColor,
      compBackgroundPrimaryColor:
          compBackgroundPrimaryColor ?? this.compBackgroundPrimaryColor,
      compBackgroundGrayColor:
          compBackgroundGrayColor ?? this.compBackgroundGrayColor,
      popupColor: popupColor ?? this.popupColor,
      textPrimaryColor: textPrimaryColor ?? this.textPrimaryColor,
      textSecondaryColor: textSecondaryColor ?? this.textSecondaryColor,
      textTertiaryColor: textTertiaryColor ?? this.textTertiaryColor,
      textFourthColor: textFourthColor ?? this.textFourthColor,
      multiColors: multiColors ?? this.multiColors,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      dangerColor: dangerColor ?? this.dangerColor,
      emphasizeSecondaryColor:
          emphasizeSecondaryColor ?? this.emphasizeSecondaryColor,
      emphasizeTertiaryColor:
          emphasizeTertiaryColor ?? this.emphasizeTertiaryColor,
      interactiveHoverColor:
          interactiveHoverColor ?? this.interactiveHoverColor,
      interactivePressedColor:
          interactivePressedColor ?? this.interactivePressedColor,
      interactiveFocusColor:
          interactiveFocusColor ?? this.interactiveFocusColor,
      interactiveSelectColor:
          interactiveSelectColor ?? this.interactiveSelectColor,
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
