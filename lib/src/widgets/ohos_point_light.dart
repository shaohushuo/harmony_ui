import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// 受光类型 of an illuminated surface (点光源效果).
///
/// Mirrors `hdsEffect.PointLightIlluminatedType`:
/// - [none]: no illumination.
/// - [border]: only the edge facing the light is lit.
/// - [content]: the surface body receives a soft light pool.
/// - [borderContent]: both the lit edge and the light pool are drawn.
/// - [defaultFeatheringBorder]: a wider, feathered border glow.
enum OhosPointLightIlluminatedType { none, border, content, borderContent, defaultFeatheringBorder }

/// Options of a point light source, mirroring `hdsEffect.pointLight({options})`.
class OhosPointLightOptions {
  const OhosPointLightOptions({
    this.color = Colors.white,
    this.intensity = 10,
    this.height = 150,
  });

  /// Color of the emitted light.
  final Color color;

  /// Relative intensity; higher values make the light brighter and wider.
  final double intensity;

  /// Distance from the surface to the light source; larger heights spread
  /// the light pool wider and softer.
  final double height;
}

/// A self-luminous light source (发光源), the counterpart of the ArkUI
/// `pointLight({ options })` single-source mode.
///
/// Paints a bright orb with an additive halo; the halo radius is driven by
/// [options.height] and the peak alpha by [options.intensity] so placing the
/// widget above other [OhosIlluminated] surfaces makes them look lit.
class OhosLightSource extends StatelessWidget {
  const OhosLightSource({
    super.key,
    this.size = 48,
    this.options = const OhosPointLightOptions(),
  });

  /// Diameter of the light orb.
  final double size;

  /// Light parameters (color / intensity / height).
  final OhosPointLightOptions options;

  @override
  Widget build(BuildContext context) {
    final Color color = options.color;
    final double intensity = options.intensity.clamp(0, 100).toDouble();
    final double halo = size * (0.9 + options.height / 80);
    return SizedBox(
      width: halo,
      height: halo,
      child: CustomPaint(
        painter: _LightSourcePainter(
          coreRadius: size / 2,
          coreColor: Colors.white.withValues(alpha: 1),
          lightColor: color,
          intensity: intensity,
        ),
      ),
    );
  }
}

class _LightSourcePainter extends CustomPainter {
  const _LightSourcePainter({
    required this.coreRadius,
    required this.coreColor,
    required this.lightColor,
    required this.intensity,
  });

  final double coreRadius;
  final Color coreColor;
  final Color lightColor;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double peak = (0.20 + intensity * 0.006).clamp(0.0, 0.85).toDouble();
    final double mid = (0.08 + intensity * 0.003).clamp(0.0, 0.45).toDouble();
    final double maxRadius = size.width / 2;
    // Outer halo (additive).
    final Rect haloRect = Rect.fromCircle(center: center, radius: maxRadius);
    canvas.drawCircle(
      center,
      maxRadius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            lightColor.withValues(alpha: mid),
            lightColor.withValues(alpha: mid * 0.4),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.55, 1],
        ).createShader(haloRect)
        ..blendMode = BlendMode.plus,
    );
    // Soft body glow.
    final Rect bodyRect = Rect.fromCircle(
      center: center,
      radius: coreRadius * 2.6,
    );
    canvas.drawCircle(
      center,
      coreRadius * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            lightColor.withValues(alpha: peak * 0.7),
            Colors.transparent,
          ],
        ).createShader(bodyRect)
        ..blendMode = BlendMode.plus,
    );
    // White-hot core.
    final Rect coreRect = Rect.fromCircle(center: center, radius: coreRadius);
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            coreColor,
            lightColor.withValues(alpha: peak),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.55, 1],
        ).createShader(coreRect),
    );
  }

  @override
  bool shouldRepaint(covariant _LightSourcePainter oldDelegate) {
    return oldDelegate.coreRadius != coreRadius ||
        oldDelegate.coreColor != coreColor ||
        oldDelegate.lightColor != lightColor ||
        oldDelegate.intensity != intensity;
  }
}

/// An illuminated surface (受光面), the counterpart of ArkUI
/// `visualEffect(pointLight({ illuminatedType }))`.
///
/// Wraps [child] and paints the received light on its body / edge. The light
/// is assumed to come from [lightAlignment] (e.g. `Alignment.centerRight`
/// when the light source sits on the right), so content pools and edge
/// crescents are drawn on the facing region.
class OhosIlluminated extends StatelessWidget {
  const OhosIlluminated({
    super.key,
    required this.child,
    this.illuminatedType = OhosPointLightIlluminatedType.none,
    this.lightAlignment = Alignment.center,
    this.options = const OhosPointLightOptions(),
    this.borderRadius = BorderRadius.zero,
    this.clipContent = true,
  });

  /// The surface content.
  final Widget child;

  /// How the surface receives light.
  final OhosPointLightIlluminatedType illuminatedType;

  /// Direction the light comes from, used to place the light pool / edge
  /// crescent. Pass the normalized vector from the light source to the
  /// surface center.
  final Alignment lightAlignment;

  /// Parameters of the illuminating light source.
  final OhosPointLightOptions options;

  /// Corner radius of the surface (for rectangular surfaces).
  final BorderRadius borderRadius;

  /// When true the surface background clips the child.
  final bool clipContent;

  @override
  Widget build(BuildContext context) {
    if (illuminatedType == OhosPointLightIlluminatedType.none) {
      return child;
    }
    final OhosThemeData theme = OhosTheme.of(context);
    final double intensity = options.intensity.clamp(0, 100).toDouble();
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        if (clipContent) ClipRRect(borderRadius: borderRadius, child: child) else child,
        IgnorePointer(
          child: CustomPaint(
            painter: _IlluminationPainter(
              type: illuminatedType,
              alignment: lightAlignment,
              lightColor: options.color,
              intensity: intensity,
              radius: borderRadius.topLeft.x,
              background: theme.backgroundColor,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _IlluminationPainter extends CustomPainter {
  const _IlluminationPainter({
    required this.type,
    required this.alignment,
    required this.lightColor,
    required this.intensity,
    required this.radius,
    required this.background,
  });

  final OhosPointLightIlluminatedType type;
  final Alignment alignment;
  final Color lightColor;
  final double intensity;
  final double radius;
  final Color background;

  bool get _hasContent =>
      type == OhosPointLightIlluminatedType.content ||
      type == OhosPointLightIlluminatedType.borderContent;

  bool get _hasBorder =>
      type == OhosPointLightIlluminatedType.border ||
      type == OhosPointLightIlluminatedType.borderContent ||
      type == OhosPointLightIlluminatedType.defaultFeatheringBorder;

  @override
  void paint(Canvas canvas, Size size) {
    // Move the light position along the alignment axis: -1..1 of the
    // surface radius.
    final Offset center = size.center(Offset.zero);
    final double spread = size.shortestSide / 2;
    final Offset lightPos = center + Offset(alignment.x, alignment.y) * spread * 0.62;

    if (_hasContent) {
      final double peak = (0.10 + intensity * 0.012).clamp(0.0, 0.55).toDouble();
      final double poolRadius = size.longestSide * (0.55 + intensity / 240);
      final Rect poolRect = Rect.fromCircle(
        center: lightPos,
        radius: poolRadius,
      );
      canvas.drawOval(
        poolRect,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              lightColor.withValues(alpha: peak),
              lightColor.withValues(alpha: peak * 0.25),
              Colors.transparent,
            ],
            stops: const <double>[0, 0.45, 1],
          ).createShader(poolRect)
          ..blendMode = BlendMode.plus,
      );
    }

    if (_hasBorder) {
      // Crescent edge glow on the lit side.
      final double stroke =
          type == OhosPointLightIlluminatedType.defaultFeatheringBorder
              ? 10
              : 4;
      final double peak = (0.25 + intensity * 0.02).clamp(0.0, 0.95).toDouble();
      final Paint borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..shader = LinearGradient(
          begin: alignment,
          end: Alignment(-alignment.x, -alignment.y),
          colors: <Color>[
            lightColor.withValues(alpha: peak),
            lightColor.withValues(alpha: peak * 0.15),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.4, 1],
        ).createShader(Offset.zero & size);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IlluminationPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.alignment != alignment ||
        oldDelegate.lightColor != lightColor ||
        oldDelegate.intensity != intensity ||
        oldDelegate.radius != radius;
  }
}
