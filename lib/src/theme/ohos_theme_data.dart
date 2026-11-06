import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ohos_colors.dart';
import 'ohos_typography.dart';
import 'ohos_visual_policy.dart';

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
    this.policy = const ColorVisualPolicy(),
    this.id,
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

  /// 这套**令牌**的明暗语义：浅底深字，还是深底浅字。
  ///
  /// 注意它回答的范围 —— **只描述令牌本身，不描述系统**：
  /// - 它**不**表示「用户开启了系统深色模式」；
  /// - 它**不**表示「这一档是 light / dark / system」；
  /// - 它**不**表示「是否跟随系统」。
  ///
  /// 后三件事属于 [OhosThemeMode] 与 [OhosThemeController]（用户选择），
  /// 以及 `MediaQuery.platformBrightnessOf`（系统事实）。把系统亮度塞进本字段
  /// 会让「深色墨水屏」这类组合失效 —— 那块屏 `brightness` 是 dark、`policy`
  /// 是墨水屏，两者互不干涉，正是本字段只谈令牌的价值。
  ///
  /// 判断「要不要做深色专用的取色」时读 [isDark]，此时它和
  /// [OhosVisualPolicy] 无关 —— 深色纸的墨水屏同样应当取浅色图标。
  final Brightness brightness;

  /// 这套主题的「表现规则」：彩屏靠分层，墨水屏靠描边。
  ///
  /// 组件的分支逻辑走这里（`theme.policy.tint(...)` /
  /// `theme.policy.allowsShadow`），而不是读 [monochrome]。
  final OhosVisualPolicy policy;

  /// True for the e-ink preset (see [OhosThemeData.ink]).
  ///
  /// An e-ink theme is [Brightness.light] — black text on white paper — so
  /// components must read **this** flag, not [isDark], when deciding whether to
  /// composite: no `BackdropFilter` blur, no ripples, no shadows, 1px black
  /// borders instead. Reusing [isDark] would also block a future second
  /// monochrome preset (e.g. dark-paper e-ink).
  ///
  /// **新代码请改用 [policy]**（`policy.isMonochrome` / `policy.tint` /
  /// `policy.allowsShadow`）。这两个字段是同一个事实的两面：只在这个判断
  /// 「整体是否为灰阶」、且与具体形状无关时才用本字段，其余场景一律交给
  /// 策略，否则新屏幕（高对比模式、深色墨水屏）又要回来改组件。
  bool get monochrome => policy.isMonochrome;

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

  /// 这套主题是否用**描边**（而非底色分层）表达边界。
  ///
  /// 墨水屏为 true：面与面之间没有明度差，边界只能靠线。组件里「要不要补一条
  /// 1px 实线」的判断都读这个，比 `policy.outlineWidth != null` 少一层字面量，
  /// 也不含「墨水屏」这个具体原因 —— 将来高对比模式同样为 true，组件不动。
  bool get usesOutlines => policy.outlineWidth != null;

  /// 这套主题下描边的宽度，见 [usesOutlines]。
  double get outlineWidth => policy.outlineWidth ?? 1;

  /// 两个等亮度面之间的分隔线颜色。
  ///
  /// 彩屏用一档很淡的提示色（靠「有一点点深」分开相邻的面）；用描边的主题
  /// 直接给纯黑 —— 淡线在灰阶屏上会化进背景，必须实色才读得出。
  ///
  /// 需要更淡 / 更深的线时不要改这里，用 `policy.line(base, alpha)`。
  Color get outlineColor =>
      usesOutlines ? dividerColor : textTertiaryColor.withValues(alpha: 0.3);

  /// Standard light theme assembled from official HarmonyOS tokens.
  factory OhosThemeData.light({String? fontFamily}) {
    return OhosThemeData(
      brightness: Brightness.light,
      id: 'light',
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
      policy: const ColorVisualPolicy(),
    );
  }

  /// Standard dark theme assembled from official HarmonyOS tokens.
  factory OhosThemeData.dark({String? fontFamily}) {
    return OhosThemeData(
      brightness: Brightness.dark,
      id: 'dark',
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
      policy: const ColorVisualPolicy(),
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
  /// 默认是白纸黑字，因此 [brightness] 为 [Brightness.light]，检测这一预设用
  /// [monochrome]（或 `policy.isMonochrome`）—— **不要**靠 [isDark] 判断是不是
  /// 墨水屏。
  ///
  /// **深色墨水屏**（黑底白字）传 `brightness: Brightness.dark` 即可 —— 纸色、
  /// 字阶、禁用灰、选中态全部一起翻到另一个极端：
  ///
  /// ```dart
  /// final darkInk = OhosThemeData.ink(brightness: Brightness.dark);
  /// // 此时 darkInk.isDark == true、darkInk.monochrome == true
  /// // policy.paper == #1A1A1A、字阶纯白、禁用灰 #4D4D4D
  /// ```
  ///
  /// 为什么需要这个参数而不是让调用方自己 `copyWith` 一批色值：一份可用的
  /// 深色墨水屏至少要同时改对 6 个色值（纸面 / 卡面 / 弹层 / 正文 / 三级文字 /
  /// 分隔线）+ 13 个 `TextStyle` + 策略里的 `paper`。少改任何一个都是「某处黑字
  /// 压黑纸」，而且窄到跑一遍看不出来。这些值之间有约束（见下），拆给调用方
  /// 逐字段拼就是在把约束泄露出去。
  ///
  /// `policy.paper` 必须跟着纸色走 —— [InkVisualPolicy] 靠它决定叠色该合成到
  /// 哪一层，也靠它判断 [OhosVisualPolicy.litFill] 与
  /// [OhosVisualPolicy.disabledFill] 该取黑还是取白。只改色值不改 `paper`，
  /// 量化出来的灰会全部偏向白纸那一侧。
  ///
  /// 需要别的纸色（如 `#202020`）时，用 [copyWith] 同时换 `brightness`、
  /// `policy` 与那一批色值；语义仍然成立，只是本工厂不再替你兜底。
  ///
  /// Colors are copied from the reference implementation in issue feedback:
  /// tertiary text keeps `#767676` because it also drives hint text — pure
  /// black would make "not yet typed" look identical to "typed", while
  /// `#767676` still sits on level 9 of 16. The type scale is
  /// [OhosTypography.monochrome] (pure black) instead of the light preset's
  /// `90%` black, so component defaults that do not pick a color themselves
  /// (app bar titles, plain `OhosText`) stay on level 16.
  ///
  /// **Coverage** — 这个预设只给值，行为差异全部由
  /// [InkVisualPolicy] 表达：关掉模糊 / 阴影 / 水波纹 / 光效、把浅底改画成实线、
  /// 把半透明线换成实色。组件层不出现「墨水屏」字样，因此新增一种屏只需要
  /// 新增一个 [OhosVisualPolicy] 子类 + 一份色值。
  ///
  /// The general rule for grey state fills: a translucent black below ~20%
  /// lands on level 0–3 of the 16-level panel, i.e. it does not exist. 策略因此
  /// 把 20% 以下的 [OhosVisualPolicy.tint] 判成透明，组件收到透明就改画实线 ——
  /// 涉及禁用按钮、勾选 / 单选描边、开关轨道与滑块、分段按钮轨道与选中片、
  /// 滑动条 / 进度轨道、chip 与状态按钮描边、输入框下划线。`cardColor` 与页面
  /// 同为纯白的面（`OhosCard`、`OhosSearchBar` 胶囊、半模态）也补一条实线；
  /// `OhosCard` 在调用方显式传 `color` 时不补。
  factory OhosThemeData.ink({
    String? fontFamily,
    Brightness brightness = Brightness.light,
  }) {
    if (brightness == Brightness.dark) {
      // 深色纸：把上面那套「纯底 + 两极」整体翻过来。每个值都有对应的
      // `inkXxxDark` 常量，两侧保持对称可读。
      return OhosThemeData(
        brightness: Brightness.dark,
        id: 'ink_dark',
        policy: const InkVisualPolicy(paper: OhosColors.inkBackgroundDark),
        highlightColor: OhosColors.inkForegroundDark,
        onHighlightColor: OhosColors.inkBackgroundDark,
        highlightTextColor: OhosColors.inkForegroundDark,
        backgroundColor: OhosColors.inkBackgroundDark,
        backgroundSecondaryColor: OhosColors.inkBackgroundDark,
        backgroundTertiaryColor: OhosColors.inkBackgroundDark,
        cardColor: OhosColors.inkBackgroundDark,
        compBackgroundPrimaryColor: OhosColors.inkBackgroundDark,
        compBackgroundGrayColor: OhosColors.inkBackgroundDark,
        popupColor: OhosColors.inkBackgroundDark,
        textPrimaryColor: OhosColors.inkForegroundDark,
        textSecondaryColor: OhosColors.inkForegroundDark,
        textTertiaryColor: OhosColors.inkTertiaryDark,
        textFourthColor: OhosColors.inkInteractiveDark,
        multiColors: OhosColors.multiInkDark,
        // 功能色同样压成白：理由与白纸侧一致 —— 色相在 16 级灰上留不住。
        successColor: OhosColors.inkForegroundDark,
        warningColor: OhosColors.inkForegroundDark,
        dangerColor: OhosColors.inkForegroundDark,
        emphasizeSecondaryColor: OhosColors.inkInteractiveDark,
        emphasizeTertiaryColor: const Color(0x1FFFFFFF),
        interactiveHoverColor: Colors.transparent,
        interactivePressedColor: Colors.transparent,
        interactiveFocusColor: Colors.transparent,
        interactiveSelectColor: OhosColors.inkInteractiveDark,
        dividerColor: OhosColors.inkForegroundDark,
        scrimColor: const Color(0x80000000),
        typography: OhosTypography.monochrome(
          fontFamily: fontFamily,
          brightness: Brightness.dark,
        ),
      );
    }
    return OhosThemeData(
      brightness: Brightness.light,
      id: 'ink',
      policy: const InkVisualPolicy(),
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
  ///
  /// [monochrome] 只能通过 [policy] 改：传 `true` 会换成 [InkVisualPolicy]，
  /// 传 `false` 换成 [ColorVisualPolicy]。保留这个写法是为了兼容旧调用点。
  OhosThemeData copyWith({
    Brightness? brightness,
    OhosVisualPolicy? policy,
    bool? monochrome,
    String? id,
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
      id: id ?? this.id,
      policy:
          policy ??
          (monochrome == null
              ? this.policy
              : monochrome
              ? const InkVisualPolicy()
              : const ColorVisualPolicy()),
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

  /// A short, stable identifier for persistence (e.g. `shared_preferences`).
  ///
  /// The core library deliberately does not depend on any storage plugin; this
  /// is just a string an app can save and read back. Custom themes built with
  /// [copyWith] inherit the id of the preset they were derived from, so callers
  /// that need a distinct key should override [id] themselves.
  final String? id;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is OhosThemeData &&
        other.brightness == brightness &&
        other.policy == policy &&
        other.id == id &&
        other.highlightColor == highlightColor &&
        other.onHighlightColor == onHighlightColor &&
        other.highlightTextColor == highlightTextColor &&
        other.backgroundColor == backgroundColor &&
        other.backgroundSecondaryColor == backgroundSecondaryColor &&
        other.backgroundTertiaryColor == backgroundTertiaryColor &&
        other.cardColor == cardColor &&
        other.compBackgroundPrimaryColor == compBackgroundPrimaryColor &&
        other.compBackgroundGrayColor == compBackgroundGrayColor &&
        other.popupColor == popupColor &&
        other.textPrimaryColor == textPrimaryColor &&
        other.textSecondaryColor == textSecondaryColor &&
        other.textTertiaryColor == textTertiaryColor &&
        other.textFourthColor == textFourthColor &&
        _listEquals(other.multiColors, multiColors) &&
        other.successColor == successColor &&
        other.warningColor == warningColor &&
        other.dangerColor == dangerColor &&
        other.emphasizeSecondaryColor == emphasizeSecondaryColor &&
        other.emphasizeTertiaryColor == emphasizeTertiaryColor &&
        other.interactiveHoverColor == interactiveHoverColor &&
        other.interactivePressedColor == interactivePressedColor &&
        other.interactiveFocusColor == interactiveFocusColor &&
        other.interactiveSelectColor == interactiveSelectColor &&
        other.dividerColor == dividerColor &&
        other.scrimColor == scrimColor &&
        other.typography == typography;
  }

  @override
  int get hashCode => Object.hash(
    // 字段超过 20 个，`Object.hash` 一次接不下，分两组再合成。
    Object.hash(
      brightness,
      policy,
      id,
      highlightColor,
      onHighlightColor,
      highlightTextColor,
      backgroundColor,
      backgroundSecondaryColor,
      backgroundTertiaryColor,
      cardColor,
      compBackgroundPrimaryColor,
      compBackgroundGrayColor,
      popupColor,
      textPrimaryColor,
      textSecondaryColor,
      textTertiaryColor,
      textFourthColor,
      Object.hashAll(multiColors),
    ),
    successColor,
    warningColor,
    dangerColor,
    emphasizeSecondaryColor,
    emphasizeTertiaryColor,
    interactiveHoverColor,
    interactivePressedColor,
    interactiveFocusColor,
    interactiveSelectColor,
    dividerColor,
    scrimColor,
    typography,
  );

  static bool _listEquals(List<Color>? a, List<Color>? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a == null || b == null || a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('id', id, defaultValue: null));
    properties.add(DiagnosticsProperty<Brightness>('brightness', brightness));
    properties.add(
      FlagProperty('monochrome', value: monochrome, ifTrue: 'ink'),
    );
    properties.add(DiagnosticsProperty<OhosVisualPolicy>('policy', policy));
    properties.add(ColorProperty('highlightColor', highlightColor));
  }
}
