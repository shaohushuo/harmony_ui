import 'package:flutter/material.dart';

import '../theme/ohos_colors.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';

/// A HarmonyOS slider with a value-bubble tooltip (滑动条 in the guideline).
class OhosSlider extends StatefulWidget {
  const OhosSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.divisions,
    this.label,
    this.activeColor,
    this.enabled = true,
    this.showValueBubble = false,
  });

  /// Current value.
  final double value;

  /// Called continuously while dragging.
  final ValueChanged<double> onChanged;

  /// Minimum value.
  final double min;

  /// Maximum value.
  final double max;

  /// Snap divisions; when set the value snaps to discrete steps.
  final int? divisions;

  /// Label shown in the bubble.
  final String? label;

  /// Track color; defaults to the theme highlight color.
  final Color? activeColor;

  /// When false the slider is disabled.
  final bool enabled;

  /// Whether to show the value bubble above the thumb.
  final bool showValueBubble;

  @override
  State<OhosSlider> createState() => _OhosSliderState();
}

class _OhosSliderState extends State<OhosSlider> {
  double? _dragValue;

  double get _display => _dragValue ?? widget.value;

  String get _bubble =>
      widget.label ?? _display.toStringAsFixed(_isInteger(widget.max) ? 0 : 1);

  bool _isInteger(double v) => v == v.roundToDouble();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color active = widget.activeColor ?? theme.highlightColor;
    final bool showBubble = widget.showValueBubble && _dragValue != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showBubble)
          Container(
            key: const ValueKey<String>('bubble'),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.popupColor,
              borderRadius: BorderRadius.circular(16),
              // 墨水屏：气泡与页面同为纯白，用 1px 黑边代替看不见的浅阴影。
              border: theme.monochrome
                  ? Border.all(
                      color: theme.dividerColor,
                      width: ohosStrokeWidth(context),
                    )
                  : null,
              boxShadow: theme.monochrome
                  ? null
                  : <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Text(
              _bubble,
              style: theme.typography.labelMedium?.copyWith(
                color: theme.textPrimaryColor,
              ),
            ),
          ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: active,
            // 墨水屏：15% 的未走轨道看不见，滑块就悬在半空中；换成实色
            // #767676，白色滑块靠两侧的黑 / 灰分界读出来。elevation 也不再
            // 有阴影可画，归零省一次刷新。
            inactiveTrackColor: theme.monochrome
                ? theme.textTertiaryColor
                : active.withValues(alpha: 0.15),
            thumbColor: Colors.white,
            // 墨水屏：点按后的半透明灰块会留一整块，且刷新慢
            overlayColor: theme.monochrome
                ? Colors.transparent
                : active.withValues(alpha: 0.12),
            trackHeight: 4,
            // 墨水屏下没有阴影可画，白滑块贴在白页面上等于没有滑块 —— 自己画
            // 一条落在圆内的描边（`RoundSliderThumbShape` 只有 elevation）。
            // 禁用态：滑块变灰实心、轨道降一档灰，一眼看出拖不动
            disabledActiveTrackColor: theme.monochrome
                ? theme.textTertiaryColor
                : null,
            disabledInactiveTrackColor: theme.monochrome
                ? OhosColors.inkDisabled
                : null,
            thumbShape: OhosSliderThumbShape(
              outlineColor: theme.monochrome ? theme.dividerColor : null,
              outlineWidth: ohosStrokeWidth(context),
              disabledFillColor: theme.monochrome
                  ? theme.textTertiaryColor
                  : null,
              elevation: theme.monochrome ? 0 : 3,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            // Material 自己还会画一个 value indicator（`divisions` + `label`
            // 时默认 onlyForDiscrete）：墨屏下它是白底、没有描边，贴在白页面上
            // 整个消失，而且跟上面自绘的气泡重影。只在墨屏关掉，彩屏保持
            // Material 的默认 —— 离散滑条在彩屏上仍要那块数值反馈。
            showValueIndicator: theme.monochrome
                ? ShowValueIndicator.never
                : ShowValueIndicator.onlyForDiscrete,
          ),
          child: Slider(
            value: _display.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: _bubble,
            onChanged: widget.enabled
                ? (double v) {
                    setState(() => _dragValue = v);
                    widget.onChanged(v);
                  }
                : null,
            onChangeEnd: widget.enabled
                ? (double v) {
                    setState(() => _dragValue = null);
                    widget.onChanged(v);
                  }
                : null,
          ),
        ),
      ],
    );
  }
}

/// 滑动条滑块：白圆 + 可选的、完全落在圆内的描边。
///
/// `RoundSliderThumbShape` 只能靠 `elevation` 的阴影把白圆从背景里托出来，墨水屏
/// 上阴影不存在、白圆贴在白页面上等于没有滑块。这里自己画描边，并让描边整体落在
/// 圆内（描边圆心半径 = `radius - width / 2`），四边一样粗 —— 与
/// `BorderSide.strokeAlignInside` 同一套几何。
class OhosSliderThumbShape extends SliderComponentShape {
  const OhosSliderThumbShape({
    this.radius = 10,
    this.outlineColor,
    this.outlineWidth = 1,
    this.disabledFillColor,
    this.elevation = 0,
    this.shadowColor = const Color(0x33000000),
  });

  /// 滑块半径。
  final double radius;

  /// 描边颜色；null 表示不描边（彩屏靠 [elevation] 的阴影分层）。
  final Color? outlineColor;

  /// 描边宽度。
  final double outlineWidth;

  /// 禁用态的填充色；null 表示沿用 `SliderTheme.disabledThumbColor`。
  ///
  /// 墨水屏下「白圆 + 黑环」在禁用时读起来仍然可拖，所以禁用态换成灰色实心
  /// （描边随填充同色，等于没有），一眼就能看出拖不动。
  final Color? disabledFillColor;

  /// 阴影高度，0 表示不画（墨水屏没有阴影可画）。
  final double elevation;

  /// 阴影颜色。
  final Color shadowColor;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    // enableAnimation：0 = 禁用、1 = 启用，与 RoundSliderThumbShape 同一套约定
    final double t = enableAnimation.value;
    final Color enabledFill = sliderTheme.thumbColor ?? Colors.white;
    final Color disabledFill =
        disabledFillColor ?? sliderTheme.disabledThumbColor ?? enabledFill;
    final Color fill = Color.lerp(disabledFill, enabledFill, t)!;
    if (elevation > 0) {
      canvas.drawShadow(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
        shadowColor,
        elevation,
        false,
      );
    }
    canvas.drawCircle(center, radius, Paint()..color = fill);
    final Color? outline = outlineColor;
    if (outline != null && outlineWidth > 0) {
      // 禁用时描边收敛到填充色，视觉上就是「灰实心」，不必再写一条分支
      final Color stroke = Color.lerp(disabledFill, outline, t)!;
      canvas.drawCircle(
        center,
        radius - outlineWidth / 2,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth,
      );
    }
  }
}
