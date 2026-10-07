import 'package:flutter/material.dart';

/// HarmonyOS design token colors.
///
/// The palette follows the official HarmonyOS design guideline
/// (华为鸿蒙设计规范「色彩」):
///
/// - 主题色彩: system highlight, page background, card background, text levels.
/// - 系统多彩色: the 11-color multi-color system used for apps, symbols and
///   semantic states, with both light and dark variants.
/// - 功能色: success / warning / danger states.
///
/// Field values map 1:1 to the official token table (系统 Token 表), keeping
/// the ARGB order `0xAARRGGBB`. Component-level tokens follow the "控件通用
/// Token" set: `comp_background_*`, `comp_emphasize_*` and `interactive_*`.
///
/// See [OhosThemeData] for the theme that assembles these tokens, and
/// [OhosColors.highlight] for the brand color.
@immutable
class OhosColors {
  const OhosColors._();

  /// Brand / system highlight color in light mode (`brand` 浅色).
  static const Color highlight = Color(0xFF0A59F7);

  /// Brand / system highlight color in dark mode (`brand` 深色).
  static const Color highlightDark = Color(0xFF317AF7);

  /// Highlighted text in dark mode.
  static const Color highlightTextDark = Color(0xFF5291FF);

  /// Page background color in light mode (`background_secondary` 浅色).
  static const Color background = Color(0xFFF1F3F5);

  /// Page background color in dark mode (`background_primary` 深色资源，
  /// 深色模式下 Primary 与 Secondary 默认都为黑色).
  static const Color backgroundDark = Color(0xFF000000);

  /// Tertiary page background (`background_tertiary`, 浅色).
  static const Color backgroundTertiary = Color(0xFFE5E5EA);

  /// Tertiary page background (`background_tertiary`, 深色).
  static const Color backgroundTertiaryDark = Color(0xFF202224);

  /// Card / list-item surface color in light mode.
  static const Color card = Color(0xFFFFFFFF);

  /// Card / list-item surface color in dark mode.
  static const Color cardDark = Color(0xFF303030);

  /// Popup / dialog / menu surface color in light mode.
  static const Color popup = Color(0xFFFFFFFF);

  /// Popup / dialog / menu surface color in dark mode.
  static const Color popupDark = Color(0xFF363636);

  /// Component primary background (`comp_background_primary`, 浅色).
  static const Color compBackgroundPrimary = Color(0xFFFFFFFF);

  /// Component primary background (`comp_background_primary`, 深色).
  static const Color compBackgroundPrimaryDark = Color(0xFF202224);

  /// Component gray background (`comp_background_gray`, 浅色).
  static const Color compBackgroundGray = Color(0xFFF1F3F5);

  /// Component gray background (`comp_background_gray`, 深色).
  static const Color compBackgroundGrayDark = Color(0xFFE5E5EA);

  /// 20% brand highlight background (`comp_emphasize_secondary`, 浅色),
  /// used for the filled / high-brightness state of controls.
  static const Color emphasizeSecondary = Color(0x330A59F7);
  static const Color emphasizeSecondaryDark = Color(0x331F71FF);

  /// 10% brand highlight background (`comp_emphasize_tertiary`, 浅色),
  /// used for hover / lightweight emphasis surfaces.
  static const Color emphasizeTertiary = Color(0x190A59F7);
  static const Color emphasizeTertiaryDark = Color(0x191F71FF);

  /// Hover interaction color (`interactive_hover`, 浅色).
  static const Color interactiveHover = Color(0x0C000000);
  static const Color interactiveHoverDark = Color(0x0CFFFFFF);

  /// Pressed/click interaction color (`interactive_pressed`, 浅色).
  static const Color interactivePressed = Color(0x19000000);
  static const Color interactivePressedDark = Color(0x19FFFFFF);

  /// Focus interaction color (`interactive_focus`, 浅色).
  static const Color interactiveFocus = Color(0xFF0A59F7);
  static const Color interactiveFocusDark = Color(0xFF317AF7);

  /// Selected interaction color (`interactive_select`, 浅色).
  static const Color interactiveSelect = Color(0x330A59F7);
  static const Color interactiveSelectDark = Color(0x33317AF7);

  /// Primary text / icon color (`font_primary` / `icon_primary`, 90%).
  static const Color textPrimaryLight = Color(0xE6000000);
  static const Color textPrimaryDark = Color(0xE5FFFFFF);

  /// Secondary text / icon color (`font_secondary` / `icon_secondary`, 60%).
  static const Color textSecondaryLight = Color(0x99000000);
  static const Color textSecondaryDark = Color(0x99FFFFFF);

  /// Tertiary text / icon color (`font_tertiary` / `icon_tertiary`, 40%).
  static const Color textTertiaryLight = Color(0x66000000);
  static const Color textTertiaryDark = Color(0x66FFFFFF);

  /// Fourth-level text / icon color (`font_fourth` / `icon_fourth`, 20%).
  static const Color textFourthLight = Color(0x33000000);
  static const Color textFourthDark = Color(0x33FFFFFF);

  /// The 11-color HarmonyOS multi-color system, light mode.
  static const List<Color> multiLight = <Color>[
    Color(0xFF64BB5C), // green
    Color(0xFFA5D61D), // lime
    Color(0xFFF7CE00), // yellow
    Color(0xFFF9A01E), // orange
    Color(0xFFED6F21), // deep orange
    Color(0xFFE84026), // red
    Color(0xFFE55392), // magenta
    Color(0xFFA12DF7), // purple
    Color(0xFF4B48F7), // indigo
    Color(0xFF46B1E3), // blue
    Color(0xFF61CFBE), // teal
  ];

  /// The 11-color HarmonyOS multi-color system, dark mode.
  static const List<Color> multiDark = <Color>[
    Color(0xFF5BA854), // green
    Color(0xFF86AD53), // lime
    Color(0xFFD1A738), // yellow
    Color(0xFFE08C3A), // orange
    Color(0xFFDB6B42), // deep orange
    Color(0xFFD94838), // red
    Color(0xFFCC5286), // magenta
    Color(0xFF8C55C2), // purple
    Color(0xFF6259DE), // indigo
    Color(0xFF4694C2), // blue
    Color(0xFF5AADA0), // teal
  ];

  /// Success color.
  static const Color success = Color(0xFF64BB5C);

  /// Success color in dark mode.
  static const Color successDark = Color(0xFF5BA854);

  /// Warning color.
  static const Color warning = Color(0xFFED6F21);

  /// Warning color in dark mode.
  static const Color warningDark = Color(0xFFDB6B42);

  /// Danger color.
  static const Color danger = Color(0xFFE84026);

  /// Danger color in dark mode.
  static const Color dangerDark = Color(0xFFD94838);

  /// Scrim color used behind dialogs and popups.
  static const Color scrim = Color(0x66000000);
}
