import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// HarmonyOS typography tokens.
///
/// Type scale and weights follow the HarmonyOS font system; the preferred
/// family is `HarmonyOS Sans` (built into HarmonyOS/OpenHarmony devices and
/// optionally bundled by embedders). On other platforms Flutter falls back to
/// the default platform font automatically.
@immutable
class OhosTypography with Diagnosticable {
  const OhosTypography({
    this.fontFamily,
    this.displayLarge,
    this.displayMedium,
    this.headlineLarge,
    this.headlineMedium,
    this.titleLarge,
    this.titleMedium,
    this.titleSmall,
    this.bodyLarge,
    this.bodyMedium,
    this.bodySmall,
    this.labelLarge,
    this.labelMedium,
    this.labelSmall,
  });

  /// Font family used across the theme, usually `HarmonyOS Sans`.
  final String? fontFamily;

  /// 36sp display, used by large-first screens.
  final TextStyle? displayLarge;

  /// 32sp display.
  final TextStyle? displayMedium;

  /// 28sp headline.
  final TextStyle? headlineLarge;

  /// 24sp headline.
  final TextStyle? headlineMedium;

  /// 20sp title; primary page titles.
  final TextStyle? titleLarge;

  /// 17sp title.
  final TextStyle? titleMedium;

  /// 16sp title.
  final TextStyle? titleSmall;

  /// 16sp body.
  final TextStyle? bodyLarge;

  /// 15sp body.
  final TextStyle? bodyMedium;

  /// 14sp body; also used for list items.
  final TextStyle? bodySmall;

  /// 16sp medium label, used by buttons.
  final TextStyle? labelLarge;

  /// 14sp label.
  final TextStyle? labelMedium;

  /// 12sp caption / footnote.
  final TextStyle? labelSmall;

  /// Resolves lightweight copy of this typography with [fontFamily] merged
  /// into every style that does not define its own family.
  OhosTypography merge(String? family) {
    if (family == null || family == fontFamily) {
      return this;
    }
    TextStyle? apply(TextStyle? style) {
      if (style == null) {
        return null;
      }
      return style.copyWith(fontFamily: style.fontFamily ?? family);
    }

    return OhosTypography(
      fontFamily: family,
      displayLarge: apply(displayLarge),
      displayMedium: apply(displayMedium),
      headlineLarge: apply(headlineLarge),
      headlineMedium: apply(headlineMedium),
      titleLarge: apply(titleLarge),
      titleMedium: apply(titleMedium),
      titleSmall: apply(titleSmall),
      bodyLarge: apply(bodyLarge),
      bodyMedium: apply(bodyMedium),
      bodySmall: apply(bodySmall),
      labelLarge: apply(labelLarge),
      labelMedium: apply(labelMedium),
      labelSmall: apply(labelSmall),
    );
  }

  /// The light-mode HarmonyOS typography.
  static OhosTypography light({String? fontFamily}) {
    return _build(fontFamily, textPrimary);
  }

  /// The dark-mode HarmonyOS typography.
  static OhosTypography dark({String? fontFamily}) {
    return _build(fontFamily, textPrimaryDark);
  }

  /// The monochrome (e-ink) typography: one solid tone, no alpha.
  ///
  /// The light preset uses `90%` black (`0xE6000000`), which a 16-level gray
  /// panel renders as a lighter gray and blurs the "pure black on pure white,
  /// no mid-tones" goal — most visibly on component defaults that do not
  /// `copyWith` a color themselves (app bar titles, plain `OhosText`).
  ///
  /// [brightness] 决定这套字阶取哪个极端，**必须与主题的
  /// `OhosThemeData.brightness` 一致**：白纸给纯黑，深色纸给纯白。
  ///
  /// 为什么需要这个参数：纯黑字阶压在深色墨水屏的纸上（如 `#1A1A1A`）是
  /// 「黑字压黑纸」，对比度接近 1:1，正文直接消失。深色墨水屏靠
  /// `copyWith(brightness: Brightness.dark)` 拼出来时，色值能换、字阶换不了
  /// —— 字阶是 13 个 `TextStyle`，调用方不会去逐个改。所以第二个极端只能
  /// 从这里给。
  ///
  /// 不自动跟随 `brightness`：`copyWith` 是字段替换，不做派生；而且「只改
  /// 明暗语义、暂时沿用原字阶」是合法需求，替调用方猜会变成魔法。
  static OhosTypography monochrome({
    String? fontFamily,
    Brightness brightness = Brightness.light,
  }) {
    return _build(
      fontFamily,
      brightness == Brightness.dark
          ? textPrimaryMonochromeDark
          : textPrimaryMonochrome,
    );
  }

  static const Color textPrimary = Color(0xE6000000);
  static const Color textPrimaryDark = Color(0xDBFFFFFF);

  /// 白纸墨水屏的字阶：纯黑。
  static const Color textPrimaryMonochrome = Color(0xFF000000);

  /// 深色纸墨水屏的字阶：纯白（与 [textPrimaryMonochrome] 对称的另一个极端）。
  ///
  /// 不用 [textPrimaryDark]（`0xDBFFFFFF`，86% 白）：16 级灰上 86% 白落在
  /// 第 14 级，和纯白的第 15 级只差一档，省下这点「柔和」换来的是「正文不够
  /// 亮」—— 墨水屏没有背光，读者已经在借环境光，不该再削明度。
  static const Color textPrimaryMonochromeDark = Color(0xFFFFFFFF);

  static OhosTypography _build(String? fontFamily, Color color) {
    return OhosTypography(
      fontFamily: fontFamily,
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.3,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.3,
      ),
      headlineLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.3,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.4,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.4,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
      ),
    );
  }

  /// 按值比较。
  ///
  /// `OhosThemeData` 的 `==` 会往下比到排版，而 [light] / [dark] 每次调用都
  /// 新建 13 个 `TextStyle`：不在这里比出值相等的话，`OhosThemeData.light()
  /// == OhosThemeData.light()` 恒为 false，主题的「没变就不重建」就失效了。
  /// `TextStyle` 自身实现了 `==`，逐字段比即可。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is OhosTypography &&
        other.fontFamily == fontFamily &&
        other.displayLarge == displayLarge &&
        other.displayMedium == displayMedium &&
        other.headlineLarge == headlineLarge &&
        other.headlineMedium == headlineMedium &&
        other.titleLarge == titleLarge &&
        other.titleMedium == titleMedium &&
        other.titleSmall == titleSmall &&
        other.bodyLarge == bodyLarge &&
        other.bodyMedium == bodyMedium &&
        other.bodySmall == bodySmall &&
        other.labelLarge == labelLarge &&
        other.labelMedium == labelMedium &&
        other.labelSmall == labelSmall;
  }

  @override
  int get hashCode => Object.hash(
    fontFamily,
    displayLarge,
    displayMedium,
    headlineLarge,
    headlineMedium,
    titleLarge,
    titleMedium,
    titleSmall,
    bodyLarge,
    bodyMedium,
    bodySmall,
    labelLarge,
    labelMedium,
    labelSmall,
  );
}
