import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_arc.dart';

/// A segment of an [OhosGauge] ring.
///
/// ArkUI's `colors` attribute takes `Array<[ResourceColor | LinearGradient, number]>`
/// — a colour and a *weight* per段. The weight is kept because a plain
/// `List<Color>` cannot say "this colour occupies a third of the ring": every
/// caller would be forced into equal splits.
@immutable
class OhosGaugeSegment {
  const OhosGaugeSegment({required this.color, this.endColor, this.weight = 1});

  /// Colour at the start of the segment (the only colour for a solid segment).
  final Color color;

  /// Colour at the end of the segment. Non-null turns this segment into a
  /// gradient along the arc; null keeps it solid.
  final Color? endColor;

  /// How much of the ring this segment takes, relative to the other segments.
  ///
  /// Weights are normalised over the *visible* segments, so `[1, 1]` and
  /// `[2, 2]` draw the same ring. A weight of `0` (or below) hides the segment
  /// entirely — that is documented behaviour, not an edge case: a zero-weight
  /// segment must not leave a hairline of arc behind either.
  final double weight;

  /// Whether this segment contributes any arc at all.
  bool get isVisible => weight > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OhosGaugeSegment &&
          other.color == color &&
          other.endColor == endColor &&
          other.weight == weight);

  @override
  int get hashCode => Object.hash(color, endColor, weight);

  @override
  String toString() => 'OhosGaugeSegment($color, $endColor, $weight)';
}

/// Drop shadow behind the gauge ring.
///
/// Counterpart of `GaugeShadowOptions`. The shadow takes the ring's own colour
/// ("阴影颜色与圆环颜色一致"), so a gradient ring casts a gradient shadow — that
/// is why the painter reuses the arc shader instead of drawing a black blur.
@immutable
class OhosGaugeShadow {
  const OhosGaugeShadow({this.radius = 5, this.offsetX = 5, this.offsetY = 5});

  /// Blur radius. Zero draws a hard copy of the ring.
  final double radius;

  /// Horizontal displacement of the shadow.
  final double offsetX;

  /// Vertical displacement of the shadow.
  final double offsetY;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OhosGaugeShadow &&
          other.radius == radius &&
          other.offsetX == offsetX &&
          other.offsetY == offsetY);

  @override
  int get hashCode => Object.hash(radius, offsetX, offsetY);

  @override
  String toString() => 'OhosGaugeShadow($radius, $offsetX, $offsetY)';
}

/// A ring gauge (数据量规图 in the HarmonyOS guideline), the counterpart of
/// ArkUI's `Gauge`.
///
/// The ring is static decoration; [value] only moves the pointer. Keeping that
/// split is what makes the component match the official examples — a
/// nine-colour ring with `value: 50` still shows every segment at its full
/// share. [segments] is the ring's *appearance*, not progress.
///
/// ```dart
/// OhosGauge(
///   value: 72,
///   min: 0,
///   max: 100,
///   startAngle: 225,
///   endAngle: 135,
///   strokeWidth: 18,
///   child: Text('72'),
/// )
/// ```
class OhosGauge extends StatelessWidget {
  const OhosGauge({
    super.key,
    required this.value,
    this.min,
    this.max,
    this.startAngle = 0,
    this.endAngle = 360,
    this.segments,
    this.strokeWidth = 4,
    this.showIndicator = true,
    this.indicatorSpace = 8,
    this.indicatorIcon,
    this.description,
    this.trackShadow = const OhosGaugeShadow(),
    this.child,
    this.size,
  });

  /// Current value, i.e. where the pointer sits.
  ///
  /// Out-of-range values fall back to [min] rather than being clamped to the
  /// nearest end. That is the documented rule ("value不在min和max范围内时使用
  /// min作为默认值") and it is visibly different: clamping would pin a bad value
  /// to the far end and keep the pointer looking plausible, while falling back
  /// to min always points at the start of the scale.
  final double value;

  /// Scale minimum, default `0`.
  ///
  /// Null means "not set", which [description] uses to decide whether to draw
  /// the min/max labels at all.
  final double? min;

  /// Scale maximum, default `100`. Null means "not set", see [min].
  final double? max;

  /// Angle of the first drawn pixel, in **clock degrees**: 0 is 12 o'clock,
  /// positive is clockwise, and values beyond ±360 wrap.
  final double startAngle;

  /// Angle of the last drawn pixel, same convention as [startAngle].
  ///
  /// The arc always runs clockwise, so `350 → 10` sweeps 20° and `0 → 360`
  /// sweeps a full turn.
  final double endAngle;

  /// Ring segments. Null draws the official default three-stop gradient ring
  /// (`#64BB5C → #F7CE00 → #E84026`).
  ///
  /// At most nine segments are drawn; the rest are dropped, matching
  /// "分段渐变环最大显示段数为 9 段".
  final List<OhosGaugeSegment>? segments;

  /// Ring thickness in vp, default 4.
  ///
  /// Values `<= 0` fall back to 4; anything larger than the radius is clamped
  /// to the radius, so the ring fills the circle instead of painting outside
  /// the box.
  final double strokeWidth;

  /// Whether the pointer is drawn. ArkUI turns it off with `indicator(null)`.
  final bool showIndicator;

  /// Gap between the pointer and the ring's outer edge, in vp, default 8.
  final double indicatorSpace;

  /// Replaces the built-in triangle pointer with a widget centred on the value
  /// angle, just outside the ring.
  ///
  /// ArkUI only accepts an SVG here. Flutter has no dependency-free SVG
  /// renderer, so a widget is the honest equivalent — pass an `Icon`,
  /// `OhosImage`, or anything else.
  final Widget? indicatorIcon;

  /// Content under the ring, at the bottom.
  ///
  /// When null the gauge falls back to the documented default: show the scale
  /// ends if [min] or [max] was given, and show nothing when neither was.
  final Widget? description;

  /// Shadow behind the ring.
  ///
  /// Ink screens drop it regardless — a blurred copy of the ring is a grey
  /// smear on a 16-level panel, and it costs a full-screen refresh.
  final OhosGaugeShadow? trackShadow;

  /// Content centred inside the ring, typically the current value.
  final Widget? child;

  /// Side length of the square the gauge occupies. Null fills the parent.
  final double? size;

  /// Official default ring colours, a single gradient across the whole arc.
  static const List<Color> defaultRingColors = <Color>[
    Color(0xFF64BB5C),
    Color(0xFFF7CE00),
    Color(0xFFE84026),
  ];

  /// Effective minimum after the documented defaults.
  ///
  /// `max < min` resets **both** ends to `0 … 100`, not just the maximum:
  /// keeping a caller's `min: 50` next to an implied `max: 100` would invent a
  /// scale the caller never asked for.
  double get effectiveMin => _inverted ? 0 : (min ?? 0);

  /// Effective maximum after the documented defaults, see [effectiveMin].
  double get effectiveMax => _inverted ? 100 : (max ?? 100);

  bool get _inverted => (max ?? 100) < (min ?? 0);

  /// Where [value] sits on the scale, as `0 … 1`.
  double get progress {
    final double lo = effectiveMin;
    final double hi = effectiveMax;
    if (hi == lo || value < lo || value > hi) {
      return 0;
    }
    return ((value - lo) / (hi - lo)).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _OhosGaugePainter(
          theme: theme,
          segments: _visibleSegments(),
          sweep: ohosSweepRadians(startAngle, endAngle),
          startRad: ohosCanvasAngle(startAngle),
          progress: progress,
          strokeWidth: strokeWidth,
          showIndicator: showIndicator && indicatorIcon == null,
          indicatorSpace: indicatorSpace,
          shadow: trackShadow,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double side = math.min(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            // Arc angular position → a point on the ring, shared by the custom
            // pointer and the description box.
            final double angle =
                ohosCanvasAngle(startAngle) +
                ohosSweepRadians(startAngle, endAngle) * progress;
            final double radius = side / 2 + indicatorSpace;
            final Offset iconCenter =
                Offset(side / 2, side / 2) +
                Offset(math.cos(angle), math.sin(angle)) * radius;
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (child != null) Center(child: child),
                if (indicatorIcon != null)
                  // Centre the widget on [iconCenter]; unconstrained so the
                  // caller's own size wins instead of being stretched to the
                  // gauge's box.
                  Positioned(
                    left: iconCenter.dx,
                    top: iconCenter.dy,
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, -0.5),
                      child: indicatorIcon,
                    ),
                  ),
                if (description != null || min != null || max != null)
                  _buildDescription(theme, side),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Segments that actually get drawn, capped at nine.
  List<OhosGaugeSegment> _visibleSegments() {
    final List<OhosGaugeSegment>? source = segments;
    if (source == null) {
      // A single three-stop span. Modelling the default as two adjacent
      // segments would put the inter-segment gap right in the middle of a
      // gradient that is supposed to be continuous.
      return const <OhosGaugeSegment>[];
    }
    return source
        .where((OhosGaugeSegment s) => s.isVisible)
        .take(9)
        .toList(growable: false);
  }

  Widget _buildDescription(OhosThemeData theme, double side) {
    final Widget content =
        description ??
        Text(
          '${ohosTrimNumber(effectiveMin)}   ${ohosTrimNumber(effectiveMax)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.labelSmall?.copyWith(
            // `limit_value_min_font_size` = 10vp — the scale labels are the
            // smallest text in the component, below the 12fp labelSmall.
            fontSize: 10,
            color: theme.textSecondaryColor,
          ),
        );
    // Official reference box for the description area: 44.4% × 25.4% of the
    // ring diameter, pinned to the bottom and horizontally centred. Ratios of
    // the diameter (not of each axis) so an unbounded side cannot collapse it.
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: side * 0.444,
        height: side * 0.254,
        child: Center(child: content),
      ),
    );
  }
}

class _OhosGaugePainter extends CustomPainter {
  _OhosGaugePainter({
    required this.theme,
    required this.segments,
    required this.sweep,
    required this.startRad,
    required this.progress,
    required this.strokeWidth,
    required this.showIndicator,
    required this.indicatorSpace,
    required this.shadow,
  });

  final OhosThemeData theme;

  /// Empty means "the default three-stop gradient ring".
  final List<OhosGaugeSegment> segments;
  final double sweep;
  final double startRad;
  final double progress;
  final double strokeWidth;
  final bool showIndicator;
  final double indicatorSpace;
  final OhosGaugeShadow? shadow;

  /// Gap between adjacent segments, in radians.
  ///
  /// `interval_ratio` = 0.008 is a ratio of the radius, and a gap whose arc
  /// length is `0.008 × r` subtends exactly 0.008 rad — so the angle is
  /// independent of the ring size.
  static const double _gapRad = 0.008;

  /// Triangle pointer size, as ratios of the ring radius
  /// (`indicator_width_ratio` / `indicator_height_ratio`).
  static const double _pointerWidthRatio = 0.135;
  static const double _pointerHeightRatio = 0.087;

  @override
  void paint(Canvas canvas, Size size) {
    final double side = math.min(size.width, size.height);
    if (side <= 0) {
      return;
    }
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double ringRadius = side / 2;
    // `strokeWidth <= 0` → default 4; over-thick → clamp to the radius so the
    // ring fills the circle instead of painting outside the box.
    double thickness = strokeWidth <= 0 ? 4 : strokeWidth;
    if (thickness > ringRadius) {
      thickness = ringRadius;
    }
    final double midRadius = ringRadius - thickness / 2;
    final List<_ArcSpan> spans = _spans();

    _paintShadow(canvas, center, midRadius, thickness, spans);
    _paintSegments(canvas, center, midRadius, thickness, spans);
    if (showIndicator) {
      _paintIndicator(canvas, center, ringRadius);
    }
  }

  void _paintShadow(
    Canvas canvas,
    Offset center,
    double midRadius,
    double thickness,
    List<_ArcSpan> spans,
  ) {
    final OhosGaugeShadow? options = shadow;
    if (options == null || !theme.policy.allowsShadow) {
      return;
    }
    canvas.save();
    canvas.translate(options.offsetX, options.offsetY);
    final double? sigma = options.radius > 0 ? options.radius / 2 : null;
    double cursor = startRad;
    for (final _ArcSpan span in spans) {
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.butt
        ..color = span.colors.last;
      if (sigma != null) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
      }
      final Rect rect = Rect.fromCircle(center: center, radius: midRadius);
      if (span.colors.length > 1) {
        paint.shader = ohosArcShader(
          rect: rect,
          startRad: cursor,
          sweepRad: span.sweep,
          colors: span.colors,
          stops: span.stops,
        );
      }
      canvas.drawArc(rect, cursor, span.sweep, false, paint);
      cursor += span.sweep;
    }
    canvas.restore();
  }

  void _paintSegments(
    Canvas canvas,
    Offset center,
    double midRadius,
    double thickness,
    List<_ArcSpan> spans,
  ) {
    final Rect rect = Rect.fromCircle(center: center, radius: midRadius);
    double cursor = startRad;
    for (final _ArcSpan span in spans) {
      ohosPaintArc(
        canvas,
        rect: rect,
        radius: midRadius,
        thickness: thickness,
        startRad: cursor,
        sweepRad: span.sweep,
        colors: span.colors,
        stops: span.stops,
      );
      cursor += span.sweep;
    }
  }

  /// Splits the total sweep into per-segment angles.
  List<_ArcSpan> _spans() {
    if (segments.isEmpty) {
      return <_ArcSpan>[
        _ArcSpan(
          sweep: sweep,
          colors: OhosGauge.defaultRingColors,
          stops: const <double>[0, 0.5, 1],
        ),
      ];
    }
    final double totalWeight = segments.fold<double>(
      0,
      (double sum, OhosGaugeSegment s) => sum + s.weight,
    );
    if (totalWeight <= 0) {
      // "若所有颜色比重均为 0，圆环不显示."
      return const <_ArcSpan>[];
    }
    // A single segment gets no gap: shrinking both ends by half a gap would
    // carve a visible notch at the ring's start/end point.
    final double gap = segments.length > 1 ? _gapRad : 0;
    return <_ArcSpan>[
      for (final OhosGaugeSegment segment in segments)
        _ArcSpan(
          sweep: math.max(0, sweep * segment.weight / totalWeight - gap),
          colors: <Color>[
            segment.color,
            if (segment.endColor != null) segment.endColor!,
          ],
        ),
    ];
  }

  void _paintIndicator(Canvas canvas, Offset center, double ringRadius) {
    final double angle = startRad + sweep * progress;
    final Offset direction = Offset(math.cos(angle), math.sin(angle));
    final Offset normal = Offset(-direction.dy, direction.dx);
    // The tip sits `indicatorSpace` outside the ring, pointing **in** at it;
    // the base is one pointer-height further out.
    final double tipRadius = ringRadius + indicatorSpace;
    final double baseRadius = tipRadius + ringRadius * _pointerHeightRatio;
    final double halfWidth = ringRadius * _pointerWidthRatio / 2;
    final Offset tip = center + direction * tipRadius;
    final Offset base = center + direction * baseRadius;
    final Path path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + normal.dx * halfWidth, base.dy + normal.dy * halfWidth)
      ..lineTo(
        base.dx - normal.dx * halfWidth,
        base.dy - normal.dy * halfWidth,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = theme.textPrimaryColor,
    );
  }

  @override
  bool shouldRepaint(covariant _OhosGaugePainter oldDelegate) {
    return oldDelegate.theme != theme ||
        oldDelegate.sweep != sweep ||
        oldDelegate.startRad != startRad ||
        oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.showIndicator != showIndicator ||
        oldDelegate.indicatorSpace != indicatorSpace ||
        oldDelegate.shadow != shadow ||
        !_listEquals(oldDelegate.segments, segments);
  }

  static bool _listEquals(List<OhosGaugeSegment> a, List<OhosGaugeSegment> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

/// One drawn arc: how far it sweeps, and which colours run along it.
class _ArcSpan {
  const _ArcSpan({required this.sweep, required this.colors, this.stops});

  final double sweep;
  final List<Color> colors;
  final List<double>? stops;
}