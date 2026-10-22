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
    this.monochrome = false,
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

  /// True for the e-ink preset (see [OhosThemeData.ink]).
  ///
  /// An e-ink theme is [Brightness.light] — black text on white paper — so
  /// components must read **this** flag, not [isDark], when deciding whether to
  /// composite: no `BackdropFilter` blur, no ripples, no shadows, 1px black
  /// borders instead. Reusing [isDark] would also block a future second
  /// monochrome preset (e.g. dark-paper e-ink).
  final bool monochrome;

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

  /// Monochrome preset for e-ink panels (e.g. Huawei MatePad Paper).
  ///
  /// Pure black on pure white with **no mid-tones**: a 16-level gray panel
  /// cannot resolve `#F1F3F5` against white, and the light preset's `10%`
  /// dividers / `20%` highlights simply disappear. Boundaries therefore come
  /// from 1px black lines (`dividerColor` is pure black here) rather than from
  /// layered surfaces and shadows.
  ///
  /// [brightness] stays [Brightness.light] (black on white) so existing
  /// `isDark` branches keep working; detect this preset with [monochrome].
  ///
  /// Colors are copied from the reference implementation in issue feedback:
  /// tertiary text keeps `#767676` because it also drives hint text — pure
  /// black would make "not yet typed" look identical to "typed", while
  /// `#767676` still sits on level 9 of 16.
  factory OhosThemeData.ink({String? fontFamily}) {
    return OhosThemeData(
      brightness: Brightness.light,
      monochrome: true,
      highlightColor: OhosColors.inkForeground,
      onHighlightColor: OhosColors.inkBackground,
      highlightTextColor: OhosColors.inkForeground,
      backgroundColor: OhosColors.inkBackground,
      backgroundSecondaryColor: OhosColors.inkBackground,
      backgroundTertiaryColor: OhosColors.inkBackground,
      cardColor: OhosColors.inkBackground,
      compBackgroundPrimaryColor: OhosColors.inkBackground,
      compBackgroundGrayColor: OhosColors.inkBackground,
      popupColor: OhosColors.inkBackground,
      textPrimaryColor: OhosColors.inkForeground,
      textSecondaryColor: OhosColors.inkForeground,
      textTertiaryColor: const Color(0xFF767676),
      textFourthColor: OhosColors.inkInteractive,
      multiColors: OhosColors.multiInk,
      // 功能色也压成黑：红色在 16 级灰上变中灰，与正文糊在一起，
      // 不如「黑字 + 文案说清楚」，需要强调时加粗或加图标。
      successColor: OhosColors.inkForeground,
      warningColor: OhosColors.inkForeground,
      dangerColor: OhosColors.inkForeground,
      emphasizeSecondaryColor: OhosColors.inkInteractive,
      emphasizeTertiaryColor: const Color(0x1F000000),
      // 水波纹 / hover / focus 在墨水屏上是半透明灰块且刷新慢，全部关掉；
      // 点按反馈只留选中态（实心 20% 黑）。
      interactiveHoverColor: Colors.transparent,
      interactivePressedColor: Colors.transparent,
      interactiveFocusColor: Colors.transparent,
      interactiveSelectColor: OhosColors.inkInteractive,
      // 关键：light 预设用 10% 黑做分隔线，墨水屏上等于没有。
      dividerColor: OhosColors.inkForeground,
      scrimColor: const Color(0x80000000),
      // light 的字阶是 90% 黑（0xE6000000），在 16 级灰上会淡成中灰，与「纯黑
      // + 纯白」的目标不符 —— 凡是没自己 copyWith 颜色的地方（AppBar 标题、
      // 裸 OhosText）都会露出来，所以这里换纯黑字阶。
      typography: OhosTypography.monochrome(fontFamily: fontFamily),
    );
  }

  /// Returns a copy with the given fields replaced.
  OhosThemeData copyWith({
    Brightness? brightness,
    bool? monochrome,
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
      monochrome: monochrome ?? this.monochrome,
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
    properties.add(FlagProperty('monochrome', value: monochrome, ifTrue: 'ink'));
    properties.add(ColorProperty('highlightColor', highlightColor));
  }
}
