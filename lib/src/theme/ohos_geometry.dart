import 'package:flutter/material.dart';

/// HarmonyOS spacing scale, corner radii, breakpoints and motion tokens.
///
/// Spacing follows an 8vp-friendly scale on top of a 4vp base; corner radii
/// match the ArkUI design: 8/16/24 with a fully-rounded capsule shape used by
/// buttons and search bars. The breakpoint / grid constants come from the
/// official「布局基础」chapter (600/840vp breakpoints, 4/8/12 columns), and the
/// motion curves from the「转场动效」chapter (springy response curves with
/// fade-through transitions).
@immutable
class OhosGeometry {
  const OhosGeometry._();

  /// 4vp base spacing.
  static const double spaceXxs = 4;

  /// 8vp spacing.
  static const double spaceXs = 8;

  /// 12vp spacing.
  static const double spaceSm = 12;

  /// 16vp spacing.
  static const double spaceMd = 16;

  /// 24vp spacing.
  static const double spaceLg = 24;

  /// 32vp spacing.
  static const double spaceXl = 32;

  /// Small corner radius (8vp).
  static const double radiusSmall = 8;

  /// Medium corner radius (16vp).
  static const double radiusMedium = 16;

  /// Large corner radius (24vp), used by cards and dialogs.
  static const double radiusLarge = 24;

  /// Capsule radius for fully rounded controls.
  static const double radiusCapsule = 999;

  // ---- Responsive breakpoints (窗口断点) ----

  /// Width breakpoint between the phone (4-column) and foldable / tablet
  /// (8-column) grid: `0 <= vp < 600`.
  static const double breakpointCompact = 600;

  /// Width breakpoint above which the 12-column grid and side tabs apply:
  /// `840 <= vp`.
  static const double breakpointMedium = 840;

  /// Maximum content width of the grid layout (栅格最大使用宽度).
  static const double gridMaxWidth = 2220;

  /// Grid margin per width range: <600 → 16vp, <840 → 24vp, >=840 → 32vp.
  static const double gridMarginCompact = 16;
  static const double gridMarginMedium = 24;
  static const double gridMarginLarge = 32;

  /// Grid gutter per width range (8/12/16vp; 20vp is optional on large
  /// screens).
  static const double gridGutterCompact = 8;
  static const double gridGutterMedium = 12;
  static const double gridGutterLarge = 16;

  /// Column count per width range: 4 / 8 / 12.
  static const int gridColumnsCompact = 4;
  static const int gridColumnsMedium = 8;
  static const int gridColumnsLarge = 12;

  // ---- Motion (动效) ----

  /// Soft spring used for pressed / released feedback.
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1);

  /// Standard interface transition curve.
  static const Curve easeOut = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Standard fade-through curve used by page transitions
  /// (淡入淡出转场).
  static const Curve easeIn = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Curve for shared-element (一镜到底) transitions, gently accelerating
  /// into a long settle so the transition reads as one continuous motion.
  static const Curve sharedElement = Cubic(0.2, 0.0, 0.2, 1.0);

  /// Short press feedback duration (90ms, close to ArkUI button feedback).
  static const Duration durationPress = Duration(milliseconds: 90);

  /// Standard transition duration (200ms).
  static const Duration durationShort = Duration(milliseconds: 200);

  /// Medium transition duration (300ms).
  static const Duration durationMedium = Duration(milliseconds: 300);

  /// Long transition duration for page / container transitions (400ms).
  static const Duration durationLong = Duration(milliseconds: 400);

  // ---- Immersive light (沉浸光感) blur approximation in logical pixels ----
  //
  // ArkUI's blur styles are layered system materials; Flutter approximates
  // them with a Gaussian blur + tint overlay. The sigma values below map the
  // official levels ULTRA_THIN..ULTRA_THICK to increasingly strong blurs.

  /// Blur sigma for ULTRA_THIN (top floating bars).
  static const double lightBlurUltraThin = 8;

  /// Blur sigma for THIN (bottom floating bars).
  static const double lightBlurThin = 16;

  /// Blur sigma for REGULAR.
  static const double lightBlurRegular = 24;

  /// Blur sigma for THICK (popups / overlays).
  static const double lightBlurThick = 32;

  /// Blur sigma for ULTRA_THICK (half-sheets, dialogs).
  static const double lightBlurUltraThick = 40;
}
