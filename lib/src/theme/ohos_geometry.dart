import 'package:flutter/material.dart';

/// HarmonyOS spacing scale, corner radii and motion tokens.
///
/// Spacing follows an 8vp-friendly scale on top of a 4vp base; corner radii
/// match the ArkUI design: 8/16/24 with a fully-rounded capsule shape used by
/// buttons and search bars. Motion curves use the springy
/// `cubicOut`-style response that HarmonyOS applies to pressed states.
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

  /// Soft spring used for pressed / released feedback.
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1);

  /// Standard interface transition curve.
  static const Curve easeOut = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Short press feedback duration (90ms, close to ArkUI button feedback).
  static const Duration durationPress = Duration(milliseconds: 90);

  /// Standard transition duration (200ms).
  static const Duration durationShort = Duration(milliseconds: 200);

  /// Medium transition duration (300ms).
  static const Duration durationMedium = Duration(milliseconds: 300);
}
