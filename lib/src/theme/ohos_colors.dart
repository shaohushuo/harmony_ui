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
  ///
  /// **刻意偏离官方 token 表**。官方深色值是 `#FFE5E5EA` —— 一块接近白的
  /// 浅灰面。那个值在 ArkUI 的语境里成立（它的作为「灰色背景」配的是
  /// `comp_foreground_primary` 深色档 `#FFE5E5E5`，也就是深色**字**），但本库
  /// 把这个 token 当作输入框 / chip 的**填充面**，上面画的是
  /// `textPrimaryColor`（深色档为 `0xE5FFFFFF` 半透明白）。白字落在这块浅灰
  /// 上，实测对比度只有 1.23:1，整块输入内容不可读 —— 这是深色档最容易被
  /// 漏掉、也最影响可用性的一处，由 test/dark_contrast_audit_test.dart 兜住。
  ///
  /// 取值对齐深色档的 `cardColor`（`#202224`）：填充控件与卡片同层，既比
  /// 页面底（纯黑）亮一档分得出轮廓，又足够暗以承载浅色文字。
  static const Color compBackgroundGrayDark = Color(0xFF202224);

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

  // ---------------------------------------------------------------------------
  // E-ink (ink) preset
  // ---------------------------------------------------------------------------

  /// E-ink foreground: pure black.
  ///
  /// A 16-level gray panel turns `black87` text into a mid-tone that reads as
  /// smudged and refreshes slowly, so the ink preset uses pure black instead of
  /// the 90% / 60% / 40% opacity ladder of the light preset.
  static const Color inkForeground = Color(0xFF000000);

  /// E-ink background: pure white, shared by page / card / popup surfaces.
  ///
  /// Layering by mid-tone is impossible on e-ink — every surface is the same
  /// white, and boundaries come from 1px black lines instead of shadows.
  static const Color inkBackground = Color(0xFFFFFFFF);

  /// The only mid-tone kept in the ink preset: selection / pressed feedback.
  ///
  /// 20% black survives on a 16-level panel; the light preset's 10%
  /// (`interactivePressed`) flattens into the background.
  static const Color inkInteractive = Color(0x33000000);

  /// Fill of a disabled shape on the ink preset: 25% black.
  ///
  /// [OhosColors.inkForeground] carries shapes that must stay loud, and
  /// `textTertiaryColor` (50% black) the "present but muted" ones such as the
  /// unplayed part of a slider track. A *disabled* track needs one step weaker
  /// still: it keeps its outline on the 16-level panel without merging into
  /// the muted step above it.
  static const Color inkDisabled = Color(0xFFBFBFBF);

  // --- 深色纸墨水屏 ---------------------------------------------------------
  //
  // 同一套「纯底 + 两极」的规则，只是把极端翻过来。这些值不能靠上面那批
  // 反相算出来：纸色 #1A1A1A 反转得到 #E5E5E5，那是一块接近白的面，
  // 在 ambiente 光下比纸本身还刺眼，而墨水屏没有背光可以压住它。

  /// 深色纸墨水屏的纸面：`#1A1A1A`。
  ///
  /// 不用纯黑 —— 纯黑面板在环境光下的反射几乎为零，读者会觉得「屏幕没开」，
  /// 而 `#1A1A1A` 保留一点点面板本身的灰，仍落在 16 级灰的第 1～2 级。
  static const Color inkBackgroundDark = Color(0xFF1A1A1A);

  /// 深色纸墨水屏的正文极端：纯白。与 [inkForeground] 对称。
  static const Color inkForegroundDark = Color(0xFFFFFFFF);

  /// 深色纸上「存在但不强调」的那一档：`#999999`。
  ///
  /// 对纸面 `#1A1A1A` 的对比度约 4.3:1（按 sRGB 直接加权算），比白纸侧的
  /// `#767676`（约 2.1:1）**高得多** —— 这个不对称是故意的，不是配错：
  /// 深色纸上要把弱化文字压到 2:1 需要 `#434343` 这种几乎不可见的灰，
  /// 而低对比正文在环境光下本来就更易糊。所以深色侧的下限抬一档，仍比
  /// 正文（约 6.9:1）低一截，层级分得开。
  ///
  /// 用 `#8C8C8C` 时实测只有 3.9:1，压着「弱化但读得出」的边界，故调亮一档。
  static const Color inkTertiaryDark = Color(0xFF999999);

  /// 深色纸上唯一的中间调：20% 白。
  ///
  /// 与 [inkInteractive] 成对，只是把「压一层黑」换成「提一层白」—— 深色纸
  /// 上 20% 黑等于不存在，而 20% 白刚好落在第 2～3 级，看得见又不刺眼。
  static const Color inkInteractiveDark = Color(0x33FFFFFF);

  /// 深色纸上禁用形状的实灰：`#4D4D4D`。
  ///
  /// [inkDisabled] 的 `#BFBFBF` 挪到深色纸上会变成「禁用态比可用态更亮」，
  /// 读者会去点它。这里取一档比纸面亮、比正文暗的灰。
  static const Color inkDisabledDark = Color(0xFF4D4D4D);

  /// 11-step grayscale for the multi-color system, one slot per [multiLight]
  /// entry so indices keep their meaning.
  static const List<Color> multiInk = <Color>[
    Color(0xFF000000),
    Color(0xFF1A1A1A),
    Color(0xFF333333),
    Color(0xFF4D4D4D),
    Color(0xFF666666),
    Color(0xFF808080),
    Color(0xFF999999),
    Color(0xFFB3B3B3),
    Color(0xFFCCCCCC),
    Color(0xFFE6E6E6),
    Color(0xFFFFFFFF),
  ];

  /// [multiInk] 在深色纸上的版本：同一根 11 级灰轴，方向反过来。
  ///
  /// 下标含义必须和 [multiInk] 一致（第 0 位都是「最极端的深」），所以这里
  /// 不是简单倒序 —— 倒序会让 `multiColors[0]` 在白纸侧是最深、在深色纸侧
  /// 变成最浅，任何按下标取色（如用 `multiColors[0]` 当强调色）的地方都会
  /// 静默反转语义。
  ///
  /// 因此取值是「把每个灰按纸面反相」的结果，两端仍锚在最极端：0 号纯黑
  /// 不翻（在深色纸上纯黑是「比纸更暗」的一端，仍可用于压深），10 号纯白
  /// 是正文极端。中间七级的明暗顺序与白纸侧**一致**，只是整体抬高 —— 深色纸
  /// 上第 4 级 `#666666` 与纸面几乎同色，必须提到 `#B3B3B3` 才看得见。
  static const List<Color> multiInkDark = <Color>[
    Color(0xFF000000),
    Color(0xFFFFFFFF),
    Color(0xFFF2F2F2),
    Color(0xFFE6E6E6),
    Color(0xFFD9D9D9),
    Color(0xFFCCCCCC),
    Color(0xFFBFBFBF),
    Color(0xFFB3B3B3),
    Color(0xFFA6A6A6),
    Color(0xFF999999),
    Color(0xFF8C8C8C),
  ];
}
