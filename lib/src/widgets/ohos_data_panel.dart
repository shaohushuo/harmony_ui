import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_arc.dart';

/// How an [OhosDataPanel] lays out its data proportions.
enum OhosDataPanelType {
  /// Horizontal bar; segments run left to right.
  line,

  /// Ring; segments run clockwise from 12 o'clock.
  circle,
}

/// One segment colour of an [OhosDataPanel].
///
/// Accepts a solid colour or a two-stop gradient, mirroring
/// `Array<ResourceColor | LinearGradient>`. A single class with a nullable
/// [endColor] rather than two sub-types: at the call site a solid colour and a
/// gradient differ by one optional argument, and the painter branches on the
/// same field either way.
@immutable
class OhosDataPanelColor {
  /// Solid colour.
  const OhosDataPanelColor.solid(this.color) : endColor = null;

  /// Gradient from [color] to [endColor].
  const OhosDataPanelColor.gradient(this.color, this.endColor);

  /// Colour at the start of the segment.
  final Color color;

  /// Colour at the end of the segment; null keeps the segment solid.
  final Color? endColor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OhosDataPanelColor &&
          other.color == color &&
          other.endColor == endColor);

  @override
  int get hashCode => Object.hash(color, endColor);

  @override
  String toString() => 'OhosDataPanelColor($color, $endColor)';
}

/// Shadow behind an [OhosDataPanel].
///
/// Counterpart of `DataPanelShadowOptions`, which extends `MultiShadowOptions`.
/// [colors] defaults to the panel's own segment colours — the shadow is a
/// coloured copy of the chart, not a black drop shadow.
@immutable
class OhosDataPanelShadow {
  const OhosDataPanelShadow({
    this.radius = 20,
    this.offsetX = 5,
    this.offsetY = 5,
    this.colors,
  });

  /// Blur radius. Zero draws a hard offset copy.
  final double radius;

  /// Horizontal displacement of the shadow.
  final double offsetX;

  /// Vertical displacement of the shadow.
  final double offsetY;

  /// Per-segment shadow colours. Null reuses the panel's own colours.
  ///
  /// Fewer entries than segments leave the remaining segments without a
  /// shadow; more entries are truncated — "若设置的投影颜色的个数少于数据段个数时，
  /// 则显示的投影颜色的个数和设置的投影颜色个数一致".
  final List<OhosDataPanelColor>? colors;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OhosDataPanelShadow &&
          other.radius == radius &&
          other.offsetX == offsetX &&
          other.offsetY == offsetY &&
          _listEquals(other.colors, colors));

  @override
  int get hashCode => Object.hash(
    radius,
    offsetX,
    offsetY,
    colors == null ? null : Object.hashAll(colors!),
  );

  static bool _listEquals(
    List<OhosDataPanelColor>? a,
    List<OhosDataPanelColor>? b,
  ) {
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
  String toString() => 'OhosDataPanelShadow($radius, $offsetX, $offsetY)';
}

/// A data proportion chart (数据面板 in the HarmonyOS guideline), the
/// counterpart of ArkUI's `DataPanel`.
///
/// Splits a set of values into proportional ring segments or bar segments.
/// This is **not** a progress indicator: the values do not have to sum to
/// [max], and whatever is left over simply stays as track background — that
/// is how the official example renders "75% used" with `values: [50, 12, 8, 5]`
/// and `max: 100`.
///
/// ```dart
/// OhosDataPanel(
///   values: <double>[50, 12, 8, 5],
///   max: 100,
///   strokeWidth: 24,
///   child: Text('75%'),
/// )
/// ```
class OhosDataPanel extends StatelessWidget {
  const OhosDataPanel({
    super.key,
    required this.values,
    this.max = 100,
    this.type = OhosDataPanelType.circle,
    this.strokeWidth = 24,
    this.trackBackgroundColor,
    this.valueColors,
    this.trackShadow = const OhosDataPanelShadow(),
    this.closeEffect = false,
    this.child,
  });

  /// Data values, one per segment.
  ///
  /// Only the first nine are drawn ("最多包含9个数据，大于9个数据则取前9个数据");
  /// negative values become zero.
  final List<double> values;

  /// Denominator of the proportions.
  ///
  /// - `max > 0`: an absolute scale. `[50, 12, 8, 5]` against `100` fills 75%
  ///   of the chart and leaves the rest as track.
  /// - `max <= 0`: the values' own sum, i.e. "display proportionally". The
  ///   segments then always fill the whole chart.
  ///
  /// Default `100`. The two branches are why this cannot be a plain
  /// `max(scale, sum)` — they answer different questions.
  final double max;

  /// Ring or bar. ArkUI documents this as not dynamically changeable; in
  /// Flutter a rebuild with a new type is fine, so the constraint is
  /// deliberately not enforced here.
  final OhosDataPanelType type;

  /// Ring thickness in vp, default 24. Ignored for [OhosDataPanelType.line].
  ///
  /// `<= 0` falls back to 24; larger than the radius collapses to 12% of the
  /// radius rather than painting outside the box — the documented behaviour,
  /// and the reason an over-thick value makes the ring *thinner* rather than
  /// vanishing.
  final double strokeWidth;

  /// Track colour behind the segments.
  ///
  /// Defaults to `#08182431` — a 3%-opacity near-black, i.e. a barely-visible
  /// groove. On ink screens a 3% fill is below the panel's first visible grey
  /// level, so the policy substitutes a hairline outline; without it the
  /// "how much is left" information disappears entirely.
  final Color? trackBackgroundColor;

  /// Per-segment colours. Null uses the official nine-step gradient ramp.
  final List<OhosDataPanelColor>? valueColors;

  /// Coloured shadow behind the chart. Ink screens drop it.
  final OhosDataPanelShadow? trackShadow;

  /// Turns off the entrance rotation and the shadow in one switch.
  ///
  /// Shadow handled directly; the rotation is the arc easing into place. Ink
  /// screens skip both regardless of this flag, see [OhosVisualPolicy].
  final bool closeEffect;

  /// Content centred on the chart (ArkUI has no child here — the official
  /// examples stack a `Text` on top with `Stack`, and this is the same thing
  /// without the wrapper).
  final Widget? child;

  /// Official default segment colours: nine two-stop gradients.
  static const List<OhosDataPanelColor> defaultColors = <OhosDataPanelColor>[
    OhosDataPanelColor.gradient(Color(0xFFF7CE00), Color(0xFFF99B11)),
    OhosDataPanelColor.gradient(Color(0xFFF76223), Color(0xFFF2400A)),
    OhosDataPanelColor.gradient(Color(0xFFF772AC), Color(0xFFE65392)),
    OhosDataPanelColor.gradient(Color(0xFFA575EB), Color(0xFFA12DF7)),
    OhosDataPanelColor.gradient(Color(0xFF7B79F7), Color(0xFF4B48F7)),
    OhosDataPanelColor.gradient(Color(0xFF4B8AF3), Color(0xFF007DFF)),
    OhosDataPanelColor.gradient(Color(0xFF73C1E6), Color(0xFF4FB4E3)),
    OhosDataPanelColor.gradient(Color(0xFFA5D61D), Color(0xFF69D14F)),
    OhosDataPanelColor.gradient(Color(0xFFA2A2B0), Color(0xFF8E8E93)),
  ];

  /// Official default track colour, `#08182431` (ARGB).
  static const Color defaultTrackColor = Color(0x08182431);

  /// Maximum number of segments drawn.
  static const int maxSegments = 9;

  /// Effective ring thickness after the documented fallbacks.
  ///
  /// [radius] is needed because the over-thick rule is relative to it; callers
  /// without a layout can pass 0 to get the default branch only.
  double effectiveStrokeWidth(double radius) {
    if (strokeWidth <= 0) {
      return 24;
    }
    if (radius > 0 && strokeWidth > radius) {
      return radius * 0.12;
    }
    return strokeWidth;
  }

  /// Values actually drawn: negatives zeroed, capped at nine.
  List<double> get effectiveValues => values
      .take(maxSegments)
      .map((double v) => v.isFinite && v > 0 ? v : 0.0)
      .toList(growable: false);

  /// Denominator the segments are measured against.
  ///
  /// `max <= 0` means "sum the values", so an all-zero panel has a zero
  /// denominator — the painter then draws track only instead of dividing by
  /// zero.
  double get effectiveMax {
    if (max > 0) {
      return max;
    }
    return effectiveValues.fold<double>(0, (double sum, double v) => sum + v);
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final List<double> data = effectiveValues;
    // 分段色同样要过 policy：`track` 一直走了 `quantize`，而这里漏了 ——
    // 于是墨屏上环是「灰底 + 九段彩色」，整块图形比彩屏还刺眼。这是库的缺陷，
    // 不是调用方该自己处理的事：调用方传进来的是一份**配色**，不是「这台屏
    // 上就该显示这些 RGB」。
    final List<OhosDataPanelColor> palette = <OhosDataPanelColor>[
      for (final OhosDataPanelColor c in _resolvedColors(data.length))
        if (c.endColor == null)
          OhosDataPanelColor.solid(theme.policy.quantize(c.color))
        else
          OhosDataPanelColor.gradient(
            theme.policy.quantize(c.color),
            theme.policy.quantize(c.endColor!),
          ),
    ];
    final Color track =
        trackBackgroundColor ?? theme.policy.quantize(defaultTrackColor);
    final bool animate =
        !closeEffect &&
        theme.policy.allowsShadow &&
        theme.policy.scaleMotion(const Duration(milliseconds: 400)) >
            Duration.zero;

    final Widget chart = CustomPaint(
      painter: _OhosDataPanelPainter(
        values: data,
        max: effectiveMax,
        type: type,
        strokeWidth: strokeWidth,
        trackColor: track,
        colors: palette,
        // 投影默认取「分段色」的副本。它必须跟着分段色一起过 policy ——
        // 上面把 `colors` 量化了、这里仍用未处理的副本的话，墨屏上会看到
        // 「灰环 + 一圈彩色投影」，比不量化还怪（而且投影是 `saveLayer` 模糊
        // 出来的大块，像素判据里它比环本身更显眼）。
        shadow: _quantizedShadow(trackShadow, theme),
        showsShadow: !closeEffect,
        outlines: theme.usesOutlines,
        outlineColor: theme.outlineColor,
        outlineWidth: theme.outlineWidth,
      ),
      child: child == null ? null : Center(child: child),
    );

    if (!animate) {
      return _sized(chart);
    }
    // Entrance: the arcs settle into place from a quarter turn back. The doc
    // says only "旋转动效" — no angle and no duration — so the numbers here are
    // ours and stated as such; what matters is that `closeEffect` really does
    // remove the motion, and that the end state is identical either way.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: theme.policy.scaleMotion(const Duration(milliseconds: 400)),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? child) {
        return Transform.rotate(angle: (1 - t) * -math.pi / 2, child: child);
      },
      child: _sized(chart),
    );
  }

  /// 给图表一个确定尺寸，但**不在无界方向强行 expand**。
  ///
  /// 这里原来两处都是裸的 `SizedBox.expand`。`SizedBox.expand` 等于
  /// `width: infinity, height: infinity`，父级没有高度约束时会拿到
  /// `BoxConstraints(w=…, h=Infinity)` 并在 `performLayout` 里直接抛
  /// 「BoxConstraints forces an infinite height」—— 放在 `Column` / `ListView`
  /// 这类纵轴无界的容器里就会炸（example 的 display 页正是这样）。
  ///
  /// 官方文档对 DataPanel 的尺寸一个字都没写：它不吃 `width` / `height`，
  /// 由父容器决定。所以本库的正确行为是「跟着父级走」：
  /// - 两个方向都有约束 → 撑满（与 `expand` 原意一致）；
  /// - 某方向无界 → 该方向退回 [strokeWidth] 的 2 倍（环的直径下限，也是
  ///   线形条最矮的可读高度），让组件至少能画出来而不是崩。
  Widget _sized(Widget chart) {
    final double fallback = (strokeWidth <= 0 ? 24 : strokeWidth) * 2;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SizedBox(
          width: constraints.hasBoundedWidth ? null : fallback,
          height: constraints.hasBoundedHeight ? null : fallback,
          child: SizedBox.expand(child: chart),
        );
      },
    );
  }

  /// Palette aligned to the number of drawn segments.
  ///
  /// Excess entries are dropped and missing ones cycle through the default
  /// ramp — ArkUI requires a colour per segment, and silently painting
  /// uncoloured segments would be worse than reusing the brand ramp.
  List<OhosDataPanelColor> _resolvedColors(int count) {
    final List<OhosDataPanelColor> source = valueColors ?? defaultColors;
    if (source.isEmpty) {
      return const <OhosDataPanelColor>[];
    }
    return <OhosDataPanelColor>[
      for (int i = 0; i < count; i++) source[i % source.length],
    ];
  }

  /// 把投影的配色也过一遍 [OhosVisualPolicy.quantize]。
  ///
  /// `colors` 为 null 时投影直接复用分段色（见 [_OhosDataPanelPainter]），
  /// 那种情况交给 painter 用已经量化过的 `colors`，这里无需再动。
  OhosDataPanelShadow? _quantizedShadow(
    OhosDataPanelShadow? source,
    OhosThemeData theme,
  ) {
    final List<OhosDataPanelColor>? own = source?.colors;
    if (source == null || own == null) {
      return source;
    }
    return OhosDataPanelShadow(
      radius: source.radius,
      offsetX: source.offsetX,
      offsetY: source.offsetY,
      colors: <OhosDataPanelColor>[
        for (final OhosDataPanelColor c in own)
          if (c.endColor == null)
            OhosDataPanelColor.solid(theme.policy.quantize(c.color))
          else
            OhosDataPanelColor.gradient(
              theme.policy.quantize(c.color),
              theme.policy.quantize(c.endColor!),
            ),
      ],
    );
  }
}

class _OhosDataPanelPainter extends CustomPainter {
  _OhosDataPanelPainter({
    required this.values,
    required this.max,
    required this.type,
    required this.strokeWidth,
    required this.trackColor,
    required this.colors,
    required this.shadow,
    required this.showsShadow,
    required this.outlines,
    required this.outlineColor,
    required this.outlineWidth,
  });

  final List<double> values;
  final double max;
  final OhosDataPanelType type;
  final double strokeWidth;
  final Color trackColor;
  final List<OhosDataPanelColor> colors;
  final OhosDataPanelShadow? shadow;
  final bool showsShadow;
  final bool outlines;
  final Color outlineColor;
  final double outlineWidth;

  /// Corner radius of the bar form (`datapanel_corner_radius` →
  /// `ohos_id_corner_radius_default_xs` = 4vp).
  static const double _barRadius = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || colors.isEmpty) {
      return;
    }
    // Fraction of the chart each segment occupies. `max` is already resolved
    // by the widget: an absolute scale when positive, the values' own sum
    // otherwise. A zero sum (every value zero) has nothing to draw — painting
    // track only is the honest result, and it avoids a 0/0 NaN.
    final List<double> fractions = max > 0
        ? <double>[for (final double v in values) (v / max).clamp(0.0, 1.0)]
        : <double>[for (final double _ in values) 0.0];
    switch (type) {
      case OhosDataPanelType.circle:
        _paintCircle(canvas, size, fractions);
      case OhosDataPanelType.line:
        _paintLine(canvas, size, fractions);
    }
  }

  void _paintCircle(Canvas canvas, Size size, List<double> fractions) {
    final double side = math.min(size.width, size.height);
    final double radius = side / 2;
    if (radius <= 0) {
      return;
    }
    double thickness = strokeWidth <= 0 ? 24 : strokeWidth;
    if (thickness > radius) {
      thickness = radius * 0.12;
    }
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double midRadius = radius - thickness / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: midRadius);

    _paintTrack(canvas, rect, thickness, isCircle: true);

    if (showsShadow) {
      _paintShadow(canvas, rect, thickness, fractions, isCircle: true);
    }

    double cursor = ohosCanvasAngle(0);
    for (int i = 0; i < fractions.length; i++) {
      final double sweep = fractions[i] * 2 * math.pi;
      if (sweep <= 0) {
        continue;
      }
      _paintSpan(
        canvas,
        rect,
        thickness,
        cursor,
        sweep,
        colors[i],
        isCircle: true,
      );
      cursor += sweep;
    }
  }

  void _paintLine(Canvas canvas, Size size, List<double> fractions) {
    final RRect bar = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_barRadius),
    );
    canvas.save();
    canvas.clipRRect(bar);

    _paintTrack(canvas, Offset.zero & size, size.height, isCircle: false);

    if (showsShadow) {
      _paintShadow(
        canvas,
        Offset.zero & size,
        size.height,
        fractions,
        isCircle: false,
      );
    }

    double cursor = 0;
    for (int i = 0; i < fractions.length; i++) {
      final double width = fractions[i] * size.width;
      if (width <= 0) {
        continue;
      }
      final Rect segment = Rect.fromLTWH(cursor, 0, width, size.height);
      _paintSpan(
        canvas,
        segment,
        size.height,
        0,
        0,
        colors[i],
        isCircle: false,
      );
      cursor += width;
    }
    canvas.restore();

    if (outlines) {
      // 3% 的轨道在灰阶屏上落在第 0 级，与纸面不可分 —— 底槽改画 1px 实线，
      // 否则「还剩多少」这条信息整块消失。
      canvas.drawRRect(
        bar.deflate(outlineWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth
          ..color = outlineColor,
      );
    }
  }

  void _paintTrack(
    Canvas canvas,
    Rect rect,
    double thickness, {
    required bool isCircle,
  }) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = trackColor;
    if (isCircle) {
      canvas.drawArc(
        Rect.fromCircle(center: rect.center, radius: rect.width / 2),
        0,
        2 * math.pi,
        false,
        paint,
      );
    } else {
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(_barRadius)),
      );
      canvas.drawRect(rect, paint..style = PaintingStyle.fill);
      canvas.restore();
    }
  }

  void _paintShadow(
    Canvas canvas,
    Rect rect,
    double thickness,
    List<double> fractions, {
    required bool isCircle,
  }) {
    final OhosDataPanelShadow? options = shadow;
    if (options == null) {
      return;
    }
    // `colors` defaults to the panel's own colours, but only the entries the
    // caller actually supplied get a shadow — a shorter list means the trailing
    // segments have none.
    final List<OhosDataPanelColor> shadowColors = options.colors ?? colors;
    final double? sigma = options.radius > 0 ? options.radius / 2 : null;

    canvas.save();
    canvas.translate(options.offsetX, options.offsetY);
    if (isCircle) {
      double cursor = ohosCanvasAngle(0);
      for (int i = 0; i < fractions.length && i < shadowColors.length; i++) {
        final double sweep = fractions[i] * 2 * math.pi;
        if (sweep > 0) {
          _paintSpan(
            canvas,
            rect,
            thickness,
            cursor,
            sweep,
            shadowColors[i],
            isCircle: true,
            blurSigma: sigma,
          );
        }
        cursor += sweep;
      }
    } else {
      double cursor = 0;
      for (int i = 0; i < fractions.length && i < shadowColors.length; i++) {
        final double width = fractions[i] * rect.width;
        if (width > 0) {
          _paintSpan(
            canvas,
            Rect.fromLTWH(cursor, 0, width, rect.height),
            thickness,
            0,
            0,
            shadowColors[i],
            isCircle: false,
            blurSigma: sigma,
          );
        }
        cursor += width;
      }
    }
    canvas.restore();
  }

  void _paintSpan(
    Canvas canvas,
    Rect rect,
    double thickness,
    double startRad,
    double sweepRad,
    OhosDataPanelColor color, {
    required bool isCircle,
    double? blurSigma,
  }) {
    final Paint paint = Paint()
      ..style = isCircle ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;
    if (blurSigma != null) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    }
    if (color.endColor == null) {
      paint.color = color.color;
    } else if (isCircle) {
      paint.shader = ohosArcShader(
        rect: rect,
        startRad: startRad,
        sweepRad: sweepRad,
        colors: <Color>[color.color, color.endColor!],
      );
    } else {
      paint.shader = LinearGradient(
        colors: <Color>[color.color, color.endColor!],
      ).createShader(rect);
    }

    if (isCircle) {
      canvas.drawArc(
        Rect.fromCircle(center: rect.center, radius: rect.width / 2),
        startRad,
        sweepRad,
        false,
        paint,
      );
    } else {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OhosDataPanelPainter oldDelegate) {
    return oldDelegate.max != max ||
        oldDelegate.type != type ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.shadow != shadow ||
        oldDelegate.showsShadow != showsShadow ||
        oldDelegate.outlines != outlines ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.outlineWidth != outlineWidth ||
        !_listEquals(oldDelegate.values, values) ||
        !_listEquals(oldDelegate.colors, colors);
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
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
