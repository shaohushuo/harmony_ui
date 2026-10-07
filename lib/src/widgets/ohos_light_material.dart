import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// Immersive-light blur levels, mirroring the official `BlurStyle`
/// enumeration from「沉浸光感」: ULTRA_THIN … ULTRA_THICK.
///
/// Flutter has no native layered-material blur, so each level maps to a
/// Gaussian blur sigma (see [OhosGeometry.lightBlurUltraThin] …) plus a
/// theme-aware tint overlay that keeps foreground content readable.
enum OhosLightMaterialLevel {
  /// ULTRA_THIN — recommended for components floating at the top of a page
  /// (combine with a gradient blur that fades the top edge).
  ultraThin,

  /// THIN — recommended for components floating at the bottom of a page.
  thin,

  /// REGULAR — balanced blur used as a general surface.
  regular,

  /// THICK — recommended for popups / overlays that can appear anywhere.
  thick,

  /// ULTRA_THICK — recommended for half-sheets and full dialogs.
  ultraThick,
}

/// Direction of the gradient fade used by [OhosLightMaterial]. A top fade
/// extends the space above a floating bar; a bottom fade extends the space
/// below it.
enum OhosLightFade {
  /// No gradient — a uniform frosted backplate.
  none,

  /// Fade the top edge (used by top-floating bars).
  top,

  /// Fade the bottom edge (used by bottom-floating bars).
  bottom,
}

/// The HarmonyOS immersive-light surface (沉浸光感材质): a frosted-glass
/// backplate built from a [BackdropFilter] blur plus a translucent tint and an
/// optional gradient mask.
///
/// Wrap any floating control with it — an app bar, a bottom navigation bar, a
/// half-sheet — and the content scrolling underneath is softly blurred,
/// matching the official "薄雾般轻盈悬浮于内容之上" look.
///
/// ```dart
/// OhosLightMaterial(
///   level: OhosLightMaterialLevel.ultraThin,
///   gradientFade: OhosLightFade.top,
///   child: OhosAppBar(title: Text('标题')),
/// )
/// ```
class OhosLightMaterial extends StatelessWidget {
  const OhosLightMaterial({
    super.key,
    required this.child,
    this.level = OhosLightMaterialLevel.thin,
    this.tintOpacity,
    this.gradientFade = OhosLightFade.none,
    this.gradientExtent = 64,
    this.borderRadius,
  });

  /// The surface painted behind [child].
  final Widget child;

  /// Blur level: ULTRA_THIN … ULTRA_THICK.
  final OhosLightMaterialLevel level;

  /// Opacity of the theme-aware tint overlay; defaults per [level].
  final double? tintOpacity;

  /// Where a gradient mask fades the effect (extending the content area).
  final OhosLightFade gradientFade;

  /// Height of the gradient fade zone in logical pixels.
  final double gradientExtent;

  /// Optional corner radius applied to the blurred backplate.
  final BorderRadius? borderRadius;

  /// Blur sigma for [level].
  double get _sigma => switch (level) {
    OhosLightMaterialLevel.ultraThin => OhosGeometry.lightBlurUltraThin,
    OhosLightMaterialLevel.thin => OhosGeometry.lightBlurThin,
    OhosLightMaterialLevel.regular => OhosGeometry.lightBlurRegular,
    OhosLightMaterialLevel.thick => OhosGeometry.lightBlurThick,
    OhosLightMaterialLevel.ultraThick => OhosGeometry.lightBlurUltraThick,
  };

  double get _defaultTintOpacity => switch (level) {
    OhosLightMaterialLevel.ultraThin => 0.72,
    OhosLightMaterialLevel.thin => 0.78,
    OhosLightMaterialLevel.regular => 0.84,
    OhosLightMaterialLevel.thick => 0.90,
    OhosLightMaterialLevel.ultraThick => 0.94,
  };

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color tint = theme.isDark ? Colors.black : Colors.white;
    final double opacity = tintOpacity ?? _defaultTintOpacity;
    final Widget backplate = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(color: tint.withValues(alpha: opacity)),
          child: child,
        ),
      ),
    );
    if (gradientFade == OhosLightFade.none || gradientExtent <= 0) {
      return backplate;
    }
    final Alignment begin = gradientFade == OhosLightFade.top
        ? Alignment.topCenter
        : Alignment.bottomCenter;
    final Alignment end = gradientFade == OhosLightFade.top
        ? Alignment.bottomCenter
        : Alignment.topCenter;
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        final double fadeEnd = bounds.height.clamp(0.0, gradientExtent);
        final Gradient gradient = LinearGradient(
          begin: begin,
          end: end,
          colors: const <Color>[Colors.transparent, Colors.white],
          stops: <double>[0, fadeEnd / bounds.height],
        );
        return gradient.createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: backplate,
    );
  }
}
