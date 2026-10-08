import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// Immersive-light blur levels, mirroring the official `BlurStyle`
/// enumeration from「沉浸光感」: ULTRA_THIN … ULTRA_THICK.
///
/// Flutter has no native layered-material blur, so each level maps to a
/// Gaussian blur sigma (see [OhosGeometry.lightBlurUltraThin] …) plus a set of
/// material layers (surface fill, light pools, specular, shadow, scatter) that
/// approximate the HarmonyOS layered material look.
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

/// Multipliers for tuning the simulated material without changing its level.
///
/// Mirrors the official idea that users can switch 强/均衡/弱 three strengths:
/// everything is expressed as fractions of the selected [OhosLightMaterialLevel]
/// and can be scaled here per-widget.
@immutable
class OhosLightEffectTuning {
  const OhosLightEffectTuning({
    this.blurScale = 1,
    this.surfaceScale = 1,
    this.glowScale = 1,
    this.shadowScale = 1,
    this.specularScale = 1,
    this.scatterScale = 0,
  }) : assert(blurScale >= 0),
       assert(surfaceScale >= 0),
       assert(glowScale >= 0),
       assert(shadowScale >= 0),
       assert(specularScale >= 0),
       assert(scatterScale >= 0);

  /// Multiplier for the backdrop blur sigma.
  final double blurScale;

  /// Multiplier for the translucent base fill opacity.
  final double surfaceScale;

  /// Multiplier for the colored light pools behind the surface.
  final double glowScale;

  /// Multiplier for the drop shadow under the surface.
  final double shadowScale;

  /// Multiplier for the specular / rim highlight on the surface.
  final double specularScale;

  /// Multiplier for the backdrop scatter (magnified refraction bands).
  /// Defaults to 0 (off) to keep raster cost low; enable it for the
  /// 「光感漫射」look on pages where the material sits over rich content.
  final double scatterScale;

  OhosLightEffectTuning copyWith({
    double? blurScale,
    double? surfaceScale,
    double? glowScale,
    double? shadowScale,
    double? specularScale,
    double? scatterScale,
  }) {
    return OhosLightEffectTuning(
      blurScale: blurScale ?? this.blurScale,
      surfaceScale: surfaceScale ?? this.surfaceScale,
      glowScale: glowScale ?? this.glowScale,
      shadowScale: shadowScale ?? this.shadowScale,
      specularScale: specularScale ?? this.specularScale,
      scatterScale: scatterScale ?? this.scatterScale,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OhosLightEffectTuning &&
            other.blurScale == blurScale &&
            other.surfaceScale == surfaceScale &&
            other.glowScale == glowScale &&
            other.shadowScale == shadowScale &&
            other.specularScale == specularScale &&
            other.scatterScale == scatterScale;
  }

  @override
  int get hashCode => Object.hash(
        blurScale,
        surfaceScale,
        glowScale,
        shadowScale,
        specularScale,
        scatterScale,
      );
}

/// Color recipe used by [OhosLightMaterial].
@immutable
class OhosLightPalette {
  const OhosLightPalette({
    this.surfaceTint,
    this.edgeHighlight = const Color(0xE6FFFFFF),
    this.edgeShadow = const Color(0x24000000),
    this.glowColors = const <Color>[
      Color(0xFF5EA9FF),
      Color(0xFF7C8DF7),
      Color(0xFF62E0C9),
    ],
  });

  /// The translucent base color of the material sheet; defaults to the theme
  /// surface tint (white in light mode, black in dark mode).
  final Color? surfaceTint;

  /// Light stroke painted on the upper and outer edges.
  final Color edgeHighlight;

  /// Subtle lower-edge and drop shadow color.
  final Color edgeShadow;

  /// Light pools blended behind the material.
  final List<Color> glowColors;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OhosLightPalette &&
            other.surfaceTint == surfaceTint &&
            other.edgeHighlight == edgeHighlight &&
            other.edgeShadow == edgeShadow &&
            listEquals(other.glowColors, glowColors);
  }

  @override
  int get hashCode => Object.hash(
        surfaceTint,
        edgeHighlight,
        edgeShadow,
        Object.hashAll(glowColors),
      );
}

/// Per-level material parameters for [OhosLightMaterialLevel].
class _OhosLightLevelSpec {
  const _OhosLightLevelSpec({
    required this.blurSigma,
    required this.fillOpacity,
    required this.glowOpacity,
    required this.shadowOpacity,
    required this.specularOpacity,
    required this.scatterOpacity,
    required this.shadowBlur,
  });

  final double blurSigma;
  final double fillOpacity;
  final double glowOpacity;
  final double shadowOpacity;
  final double specularOpacity;
  final double scatterOpacity;
  final double shadowBlur;
}

const Map<OhosLightMaterialLevel, _OhosLightLevelSpec> _kLevelSpecs =
    <OhosLightMaterialLevel, _OhosLightLevelSpec>{
  OhosLightMaterialLevel.ultraThin: _OhosLightLevelSpec(
    blurSigma: OhosGeometry.lightBlurUltraThin,
    fillOpacity: 0.55,
    glowOpacity: 0.12,
    shadowOpacity: 0.10,
    specularOpacity: 0.30,
    scatterOpacity: 0.05,
    shadowBlur: 12,
  ),
  OhosLightMaterialLevel.thin: _OhosLightLevelSpec(
    blurSigma: OhosGeometry.lightBlurThin,
    fillOpacity: 0.45,
    glowOpacity: 0.18,
    shadowOpacity: 0.13,
    specularOpacity: 0.36,
    scatterOpacity: 0.08,
    shadowBlur: 16,
  ),
  OhosLightMaterialLevel.regular: _OhosLightLevelSpec(
    blurSigma: OhosGeometry.lightBlurRegular,
    fillOpacity: 0.38,
    glowOpacity: 0.22,
    shadowOpacity: 0.16,
    specularOpacity: 0.42,
    scatterOpacity: 0.10,
    shadowBlur: 20,
  ),
  OhosLightMaterialLevel.thick: _OhosLightLevelSpec(
    blurSigma: OhosGeometry.lightBlurThick,
    fillOpacity: 0.32,
    glowOpacity: 0.26,
    shadowOpacity: 0.20,
    specularOpacity: 0.48,
    scatterOpacity: 0.14,
    shadowBlur: 24,
  ),
  OhosLightMaterialLevel.ultraThick: _OhosLightLevelSpec(
    blurSigma: OhosGeometry.lightBlurUltraThick,
    fillOpacity: 0.26,
    glowOpacity: 0.30,
    shadowOpacity: 0.24,
    specularOpacity: 0.55,
    scatterOpacity: 0.18,
    shadowBlur: 28,
  ),
};

/// The HarmonyOS immersive-light surface (沉浸光感材质).
///
/// The backplate is assembled from the same layers the official「沉浸光感」
/// chapter describes:
///
/// - a Gaussian backdrop blur (ULTRA_THIN … ULTRA_THICK);
/// - colored light pools (`OhosLightPalette.glowColors`) that travel with
///   [glowAlignment] — the "光在介质表面漫溢" look;
/// - a specular sweep and rim highlight on the upper edge;
/// - a translucent base fill and a soft drop shadow;
/// - an optional backdrop [OhosLightEffectTuning.scatterScale] magnifying
///   refraction bands, plus an optional [gradientFade] to dissolve the blur
///   into the page edge.
///
/// ```dart
/// OhosLightMaterial(
///   level: OhosLightMaterialLevel.ultraThin,
///   gradientFade: OhosLightFade.top,
///   child: OhosAppBar(title: Text('标题')),
/// )
/// ```
///
/// The layered-material technique is adapted from the MIT-licensed
/// `harmony_immersive_glow_tabbar` (GitCode) and `liquid_glass_widgets`
/// (pub.dev) packages.
class OhosLightMaterial extends StatelessWidget {
  const OhosLightMaterial({
    super.key,
    required this.child,
    this.level = OhosLightMaterialLevel.thin,
    this.tintOpacity,
    this.gradientFade = OhosLightFade.none,
    this.gradientExtent = 64,
    this.borderRadius,
    this.glowAlignment = Alignment.center,
    this.animationValue = 0.5,
    this.palette = const OhosLightPalette(),
    this.effectTuning = const OhosLightEffectTuning(),
    this.showShadow = true,
  });

  /// The surface painted behind [child].
  final Widget child;

  /// Blur level: ULTRA_THIN … ULTRA_THICK.
  final OhosLightMaterialLevel level;

  /// Opacity of the translucent base fill; when null, uses the per-level
  /// [OhosLightMaterialLevel] value scaled by
  /// [OhosLightEffectTuning.surfaceScale].
  final double? tintOpacity;

  /// Where a gradient mask fades the effect (extending the content area).
  final OhosLightFade gradientFade;

  /// Height of the gradient fade zone in logical pixels.
  final double gradientExtent;

  /// Optional corner radius applied to the blurred backplate.
  final BorderRadius? borderRadius;

  /// Center of the most intense light pool; move it (e.g. to the selected tab)
  /// to make the light "follow" the interaction.
  final Alignment glowAlignment;

  /// A normalized value (0..1) that drives the specular sweep. A fixed value
  /// keeps the highlight steady; animate it while interacting for a sweeping
  /// light reflection.
  final double animationValue;

  /// Color recipe of the material.
  final OhosLightPalette palette;

  /// Multipliers for the simulated material.
  final OhosLightEffectTuning effectTuning;

  /// Whether to paint the soft drop shadow below the surface.
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final _OhosLightLevelSpec spec = _kLevelSpecs[level]!;
    final OhosLightEffectTuning tuning = effectTuning;
    final Color tint =
        palette.surfaceTint ??
        (theme.isDark ? Colors.black : Colors.white);
    final double fillOpacity =
        (tintOpacity ?? spec.fillOpacity * tuning.surfaceScale).clamp(0.0, 1.0);
    final double glowOpacity =
        (spec.glowOpacity * tuning.glowScale).clamp(0.0, 1.0);
    final double shadowOpacity =
        (spec.shadowOpacity * tuning.shadowScale).clamp(0.0, 1.0);
    final double specularOpacity =
        (spec.specularOpacity * tuning.specularScale).clamp(0.0, 1.0);
    final double scatterIntensity =
        (spec.scatterOpacity * tuning.scatterScale).clamp(0.0, 2.0);
    final double blurSigma = spec.blurSigma * tuning.blurScale;
    final BorderRadius border = borderRadius ?? BorderRadius.zero;

    final Widget backplate = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: border,
        boxShadow: showShadow && shadowOpacity > 0
            ? <BoxShadow>[
                BoxShadow(
                  color: palette.edgeShadow.withValues(alpha: shadowOpacity),
                  blurRadius: spec.shadowBlur * tuning.shadowScale,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: border,
        child: Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            if (scatterIntensity > 0)
              Positioned.fill(
                child: _OhosBackdropScatter(
                  borderRadius: border,
                  intensity: scatterIntensity,
                  blurSigma: blurSigma,
                  glowAlignment: glowAlignment,
                ),
              ),
            CustomPaint(
              painter: _OhosGlowMaterialPainter(
                borderRadius: border,
                fillOpacity: fillOpacity,
                glowOpacity: glowOpacity,
                specularOpacity: specularOpacity,
                tint: tint,
                palette: palette,
                glowAlignment: glowAlignment,
                animationValue: animationValue,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: child,
              ),
            ),
          ],
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

/// Magnified backdrop bands that simulate light refraction (光感漫射).
class _OhosBackdropScatter extends StatelessWidget {
  const _OhosBackdropScatter({
    required this.borderRadius,
    required this.intensity,
    required this.blurSigma,
    required this.glowAlignment,
  });

  final BorderRadius borderRadius;
  final double intensity;
  final double blurSigma;
  final Alignment glowAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
        );
        if (size.isEmpty) {
          return const SizedBox.shrink();
        }
        final double clamped = intensity.clamp(0.0, 2.0);
        final Offset center = glowAlignment.alongSize(size);
        return ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _FilteredBackdrop(
                filter: ui.ImageFilter.matrix(
                  _centerScaleMatrix(
                    size,
                    scaleX: 1 + .035 * clamped,
                    scaleY: 1 + .012 * clamped,
                    translateX: (center.dx - size.width / 2) * .018 * clamped,
                    translateY: (center.dy - size.height / 2) * .01 * clamped,
                  ),
                  filterQuality: FilterQuality.medium,
                ),
                tintOpacity: .028 * clamped,
              ),
              Transform.translate(
                offset: Offset(-9 * clamped, 0),
                child: _FilteredBackdrop(
                  filter: ui.ImageFilter.blur(
                    sigmaX: (blurSigma * (.65 + clamped * .32)).clamp(0, 42),
                    sigmaY: (blurSigma * (.18 + clamped * .08)).clamp(0, 16),
                  ),
                  tintOpacity: .018 * clamped,
                ),
              ),
              Transform.translate(
                offset: Offset(9 * clamped, 0),
                child: _FilteredBackdrop(
                  filter: ui.ImageFilter.blur(
                    sigmaX:
                        (blurSigma * (.65 + clamped * .32)).clamp(0, 42) * .78,
                    sigmaY:
                        (blurSigma * (.18 + clamped * .08)).clamp(0, 16) * .9,
                  ),
                  tintOpacity: .014 * clamped,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Float64List _centerScaleMatrix(
    Size size, {
    required double scaleX,
    required double scaleY,
    required double translateX,
    required double translateY,
  }) {
    final double tx = size.width * (1 - scaleX) / 2 + translateX;
    final double ty = size.height * (1 - scaleY) / 2 + translateY;
    return Float64List.fromList(<double>[
      scaleX, 0, 0, 0, //
      0, scaleY, 0, 0, //
      0, 0, 1, 0, //
      tx, ty, 0, 1, //
    ]);
  }
}

class _FilteredBackdrop extends StatelessWidget {
  const _FilteredBackdrop({required this.filter, required this.tintOpacity});

  final ui.ImageFilter filter;
  final double tintOpacity;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: filter,
      child: ColoredBox(
        color: Colors.white.withValues(alpha: tintOpacity.clamp(0.0, 1.0)),
      ),
    );
  }
}

class _OhosGlowMaterialPainter extends CustomPainter {
  const _OhosGlowMaterialPainter({
    required this.borderRadius,
    required this.fillOpacity,
    required this.glowOpacity,
    required this.specularOpacity,
    required this.tint,
    required this.palette,
    required this.glowAlignment,
    required this.animationValue,
  });

  final BorderRadius borderRadius;
  final double fillOpacity;
  final double glowOpacity;
  final double specularOpacity;
  final Color tint;
  final OhosLightPalette palette;
  final Alignment glowAlignment;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rrect = borderRadius.toRRect(rect);
    final List<Color> colors = palette.glowColors.isEmpty
        ? const <Color>[Color(0xFF5EA9FF)]
        : palette.glowColors;

    // Translucent base fill.
    canvas.drawRRect(rrect, Paint()..color = tint.withValues(alpha: fillOpacity));

    // Light pools (光池): soft colored glows blended behind the surface.
    final Offset center = glowAlignment.alongSize(size);
    final double largest = math.max(size.width, size.height);
    for (int i = 0; i < colors.length; i++) {
      final double phase = (animationValue + i / colors.length) * math.pi * 2;
      final Offset offset = Offset(
        math.cos(phase) * size.width * .09,
        math.sin(phase) * size.height * .12,
      );
      final double radius = largest * (.55 + i * .08);
      final Rect glowRect =
          Rect.fromCircle(center: center + offset, radius: radius);
      final Paint paint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            colors[i].withValues(alpha: (glowOpacity * .38).clamp(0.0, 1.0)),
            colors[i].withValues(alpha: (glowOpacity * .1).clamp(0.0, 1.0)),
            Colors.transparent,
          ],
          stops: const <double>[0, .42, 1],
        ).createShader(glowRect)
        ..blendMode = BlendMode.plus;
      canvas.drawOval(glowRect, paint);
    }

    // Specular sweep (镜面高光): a wide white reflection traveling with
    // [animationValue].
    final double sweepX = (animationValue * 2 - .5) * size.width;
    final Rect specularRect = Rect.fromLTWH(
      sweepX,
      -size.height * .35,
      size.width * .68,
      size.height * 1.5,
    );
    canvas.drawOval(
      specularRect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: specularOpacity.clamp(0.0, 1.0)),
            Colors.white.withValues(alpha: (specularOpacity * .55).clamp(0.0, 1.0)),
            Colors.white.withValues(alpha: (specularOpacity * .2).clamp(0.0, 1.0)),
            Colors.transparent,
          ],
        ).createShader(specularRect)
        ..blendMode = BlendMode.screen,
    );

    // Rim highlight: bright on the upper edge, deepening into a soft shadow
    // at the lower edge.
    final Paint edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          palette.edgeHighlight.withValues(alpha: .9),
          palette.edgeHighlight.withValues(alpha: .2),
          palette.edgeShadow.withValues(alpha: .26),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect.deflate(.6), edgePaint);

    final Paint topLine = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          Colors.transparent,
          palette.edgeHighlight.withValues(alpha: .7),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 1));
    canvas.drawLine(
      const Offset(12, 1),
      Offset(size.width - 12, 1),
      topLine,
    );
  }

  @override
  bool shouldRepaint(covariant _OhosGlowMaterialPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.fillOpacity != fillOpacity ||
        oldDelegate.glowOpacity != glowOpacity ||
        oldDelegate.specularOpacity != specularOpacity ||
        oldDelegate.tint != tint ||
        oldDelegate.palette != palette ||
        oldDelegate.glowAlignment != glowAlignment ||
        oldDelegate.animationValue != animationValue;
  }
}
