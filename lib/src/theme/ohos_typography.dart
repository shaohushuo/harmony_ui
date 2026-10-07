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

  static const Color textPrimary = Color(0xE6000000);
  static const Color textPrimaryDark = Color(0xDBFFFFFF);

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
}
