import 'package:flutter/material.dart';

import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';

/// 滑块与轨道的三种关系，对应 `SliderStyle` 枚举。
enum OhosSliderStyle {
  /// 滑块骑在轨道上（默认）。轨道粗 **4**、滑块 **16**、左右各留 **8**
  /// （滑块直径的一半）—— 所以拖到两端时滑块圆心正好落在轨道端点上。
  outset,

  /// 滑块包在轨道内。轨道粗 **20**、滑块 **12**，轨道本身就是一条粗块。
  inset,

  /// 无滑块。只能点按轨道定位，适合空间紧张或只做进度展示的场景。
  ///
  /// 轨道粗 **4**（与 outset 相同），命中区仍有 40 —— 没有可见滑块不等于
  /// 没有可操作区域。
  none,
}

/// A HarmonyOS slider with a value-bubble tooltip (滑动条 in the guideline).
///
/// 数值全部取自《Slider》参考文档与系统资源表：
///
/// | 项 | outset | inset | none | 依据 |
/// | --- | --- | --- | --- | --- |
/// | 轨道粗细 | **4** | **20** | **4** | `slider_*_track_thickness` |
/// | 滑块直径 | **16** | **12** | — | `slider_outset_block_size` → `ohos_id_outset_block_size` / `slider_inset_block_size` |
/// | 命中区 | **40** | **32** | **40** | `slider_*_block_hot_region_size` |
/// | 轨道圆角 | **2** | **10** | 跟随 | 文档 `trackBorderRadius` |
/// | 轨道与两端距离 | **8**（=半径） | **6** | — | 文档「左右间距」段 |
/// | 刻度点直径 | **4** | **4** | **4** | `stepSize` 默认 `4vp`，取值上限 = 轨道粗细 |
///
/// **不做双值 `RangeSlider`。** ArkUI 里根本没有 RangeSlider；官方 `slideRange`
/// 是「设置**有效滑动区间**」（限制单滑块的可达范围），本库已通过
/// [OhosSlider.slideRange] 支持，见 [OhosSlideRange]。这条区分记在
/// `ROADMAP-0.6.md` §0.1。
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
    this.style = OhosSliderStyle.outset,
    this.showSteps = false,
    this.stepSize = 4,
    this.prefix,
    this.suffix,
    this.slideRange,
  });

  /// Current value.
  final double value;

  /// Called continuously while dragging.
  final ValueChanged<double> onChanged;

  /// Minimum value.
  final double min;

  /// Maximum value.
  final double max;

  /// 离散分段数：把 [min]..[max] 区间**等分**成多少段，滑动时取值吸附到最近的
  /// 分点。
  ///
  /// 注意它是「段数」而不是步长：每段间隔 = `(max - min) / divisions`，
  /// 分点共 `divisions + 1` 个（含两端）。例如 `min: 0, max: 100, divisions: 10`
  /// 的可选值是 0、10、20 … 100。这与官方 `Slider` 的 `step` 参数互为换算：
  /// `step = (max - min) / divisions` —— 这里沿用 Flutter `Slider.divisions` 的
  /// 口径，没有直接搬 `step`，是为了让底层 `Slider` 原样吸附。
  ///
  /// 为 `null`（默认）时是连续滑条，取值不吸附、可停在任意位置。[showSteps]
  /// 为 `true` 时，刻度点就画在这些分点上；没有 `divisions` 便不知道点落在哪，
  /// 此时 `showSteps` 不生效。
  final int? divisions;

  /// Label shown in the bubble.
  final String? label;

  /// Track color; defaults to the theme highlight color.
  final Color? activeColor;

  /// When false the slider is disabled.
  final bool enabled;

  /// Whether to show the value bubble above the thumb.
  final bool showValueBubble;

  /// 滑块与轨道的关系，见 [OhosSliderStyle]。
  final OhosSliderStyle style;

  /// 是否显示步长刻度点（`showSteps`，默认 `false`）。
  ///
  /// **没有 [divisions] 时不起作用**：官方把刻度点画在 `step` 的整数倍位置，
  /// 不给步长就不知道该在哪画。这里同理 —— 用 `divisions` 表达步长，因为
  /// Flutter 的 `Slider` 本来就按它吸附。
  final bool showSteps;

  /// 刻度点直径（`stepSize`，默认 **4**）。
  ///
  /// 官方的取值范围是 `[0, trackThickness)`；`0` 表示不显示，负数取默认值。
  /// 超过轨道粗细时往回夹 —— 4 直径的点画在 4 粗的轨道上刚好齐边，再大就
  /// 会溢出成「一串珠子」。
  final double stepSize;

  /// 轨道起点前的自定义前缀（`prefix`，API 20+）。
  final Widget? prefix;

  /// 轨道终点后的自定义后缀（`suffix`，API 20+）。
  final Widget? suffix;

  /// 有效滑动区间（官方 `slideRange`，API 12+）。
  ///
  /// 传入后滑块被限制在 [OhosSlideRange.from] / [OhosSlideRange.to] 之间，
  /// 区间外的点击与手势不触发；初始 value 超出区间会夹到边界。null 表示不限制。
  final OhosSlideRange? slideRange;

  @override
  State<OhosSlider> createState() => _OhosSliderState();
}

/// 有效滑动区间，对应官方 `SlideRange` 对象（API 12+）。
///
/// [from] / [to] 都可空：只设一个时另一个边界取 Slider 的 min/max。
/// 仅当 `min <= from <= to <= max` 时整体生效，否则该区间被忽略 —— 与官方
/// 「仅当 min<=from<=to<=max 时生效」一致。
class OhosSlideRange {
  const OhosSlideRange({this.from, this.to});

  /// 区间起点；null 时取 Slider 的 min。
  final double? from;

  /// 区间终点；null 时取 Slider 的 max。
  final double? to;

  /// 在给定 [min]/[max] 下校验并返回生效的边界。
  ///
  /// 返回 `(double from, double to)`；不满足 `min <= from <= to <= max` 时
  /// 返回 null（调用方按无区间处理）。
  (double, double)? resolve(double min, double max) {
    final double f = from ?? min;
    final double t = to ?? max;
    if (min <= f && f <= t && t <= max) {
      return (f, t);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is OhosSlideRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'OhosSlideRange(from: $from, to: $to)';
}

class _OhosSliderState extends State<OhosSlider> {
  double? _dragValue;

  /// 刻度点的叠色不透明度：官方 `stepColor` 的默认值来自
  /// `sys.color.ohos_id_alpha_normal_bg`，资源表里就是 **0.1**。
  ///
  /// 这个数不能凭观感调大：0.1 叠出来的对比度是「轨道 229 → 刻度 205」
  /// （Δ24），与官方配图 `slider_10.png` 逐像素一致；调到 0.2 就变成 191，
  /// 刻度点会比官方明显一档，看起来像「一串珠子」。
  static const double _tickAlpha = 0.1;

  double get _display => _dragValue ?? widget.value;

  String get _bubble =>
      widget.label ?? _display.toStringAsFixed(_isInteger(widget.max) ? 0 : 1);

  bool _isInteger(double v) => v == v.roundToDouble();

  /// 当前形态的轨道粗细。
  double get _trackThickness => widget.style == OhosSliderStyle.inset ? 20 : 4;

  /// 当前形态的滑块直径。`none` 没有滑块，但命中区仍要 40。
  double get _thumbDiameter => switch (widget.style) {
    OhosSliderStyle.outset => 16,
    OhosSliderStyle.inset => 12,
    OhosSliderStyle.none => 0,
  };

  /// 当前形态的命中区尺寸。
  double get _hotRegion => switch (widget.style) {
    OhosSliderStyle.outset => 40,
    OhosSliderStyle.inset => 32,
    OhosSliderStyle.none => 40,
  };

  /// 有效刻度直径：`<= 0` 不画；超过轨道粗细时夹到轨道粗细。
  ///
  /// 官方写「取值范围 [0, trackThickness)」。用 `<=` 而不是 `<`：直径正好
  /// 等于轨道粗细时点与轨道齐边，仍能看出是独立的一颗；再大才溢出。
  double get _effectiveStepSize {
    if (widget.stepSize <= 0) {
      return 0;
    }
    return widget.stepSize > _trackThickness
        ? _trackThickness
        : widget.stepSize;
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final OhosVisualPolicy policy = theme.policy;
    final Color active = widget.activeColor ?? theme.highlightColor;
    final bool showBubble = widget.showValueBubble && _dragValue != null;

    // 有效滑动区间：不合法的 slideRange 被 resolve 判 null，按无区间处理。
    final (double, double)? range = widget.slideRange?.resolve(
      widget.min,
      widget.max,
    );
    final double effectiveMin = range?.$1 ?? widget.min;
    final double effectiveMax = range?.$2 ?? widget.max;

    // 刻度点的颜色官方给了明确的默认值，不是「取背景色」：
    //
    // > 刻度颜色。默认值：混入 `sys.color.ohos_id_alpha_normal_bg` 透明度的
    // > `sys.color.ohos_id_color_foreground` 颜色。
    //
    // 即**前景色以 10% 不透明度叠在轨道上**（`ohos_id_alpha_normal_bg` =
    // 0.1），结果比轨道深一档，而不是比它浅。实测官方配图
    // `slider_10.png`（2880×1440，轨道 `rgb(229,229,229)`）的刻度点正是
    // `rgb(205,205,205)`：`229 × 0.9 + 0 × 0.1 = 206.1` —— 与「前景色 10%
    // 压在轨道上」逐位吻合。
    //
    // 早前这里取 `theme.popupColor`（页面底色，白），等于把点画成比轨道
    // **更亮**的白点，方向正好相反：用户看到的是「轨道上戳了一排亮孔」，
    // 而官方是「轨道里嵌了一排暗点」。用 `alpha: 0.1` 的 textPrimaryColor
    // 叠上去，深浅方向与官方一致；墨屏上 10% 叠不出来（16 级灰分不开），
    // 策略会把这一档换成实线描边色，仍保持「比轨道深」的方向。
    final Color tickColor =
        theme.policy.tint(theme.textPrimaryColor, _tickAlpha) ==
            Colors.transparent
        // 墨屏：10% 的叠色在灰阶上等于没画，改取比轨道深一档的实色。
        ? theme.textTertiaryColor
        : theme.textPrimaryColor.withValues(alpha: _tickAlpha);

    final Widget slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: active,
        // 15% 的未走轨道在灰阶屏上看不见，滑块会悬在半空中；策略判成
        // 透明后换成提示色实线，白滑块靠两侧的黑 / 灰分界读出来。
        inactiveTrackColor: policy.tint(active, 0.15) == Colors.transparent
            ? theme.textTertiaryColor
            : active.withValues(alpha: 0.15),
        thumbColor: widget.style == OhosSliderStyle.inset
            ? theme.cardColor
            : Colors.white,
        // 点按后的半透明灰块会留一整块，且刷新慢
        overlayColor: policy.allowsRipple
            ? active.withValues(alpha: 0.12)
            : Colors.transparent,
        trackHeight: _trackThickness,
        // 官方 `trackBorderRadius`：outset 2vp / inset 10vp，两者都正好是
        // 轨道粗细的一半 —— 所以直接画全圆角端头即可，不必再算。
        trackShape: const RoundedRectSliderTrackShape(),
        // 墨屏下没有阴影可画，白滑块贴在白页面上等于没有滑块 —— 自己画
        // 一条落在圆内的描边（`RoundSliderThumbShape` 只有 elevation）。
        // 禁用态：滑块变灰实心、轨道降一档灰，一眼看出拖不动
        disabledActiveTrackColor: theme.usesOutlines
            ? theme.textTertiaryColor
            : null,
        disabledInactiveTrackColor: theme.usesOutlines
            ? policy.disabledFill(theme.textTertiaryColor)
            : null,
        // `none` 形态：滑块整体不画，但 Slider 仍按 0 半径处理 —— 官方
        // 明确 `blockSize` 在 NONE 下「此字段不生效」，等价于没有滑块。
        thumbShape: widget.style == OhosSliderStyle.none
            ? const _NoThumbShape()
            : OhosSliderThumbShape(
                radius: _thumbDiameter / 2,
                outlineColor: theme.usesOutlines ? theme.dividerColor : null,
                outlineWidth: ohosStrokeWidth(context, theme.outlineWidth),
                // 不能跟 `disabledActiveTrackColor` 取同一个灰：拇指左半边会和
                // 已走轨道彻底同色，只剩右半圈轮廓，读不出拇指中心落在哪。
                disabledFillColor: theme.usesOutlines
                    ? policy.disabledFill(theme.textTertiaryColor)
                    : null,
                elevation: policy.allowsShadow ? 3 : 0,
              ),
        overlayShape: RoundSliderOverlayShape(overlayRadius: _hotRegion / 2),
        tickMarkShape: _effectiveStepSize > 0 && widget.showSteps
            ? OhosTickMarkShape(diameter: _effectiveStepSize, color: tickColor)
            : SliderTickMarkShape.noTickMark,
        // Material 自己还会画一个 value indicator（`divisions` + `label`
        // 时默认 onlyForDiscrete）：灰阶屏下它是白底、没有描边，贴在白页面
        // 上整个消失，而且跟上面自绘的气泡重影。只在用描边的主题关掉，
        // 彩屏保持 Material 的默认 —— 离散滑条在彩屏上仍要那块数值反馈。
        showValueIndicator: theme.usesOutlines
            ? ShowValueIndicator.never
            : ShowValueIndicator.onlyForDiscrete,
      ),
      child: Slider(
        // 收窄到有效区间：Material Slider 自身的手势与点击就不会越过边界，
        // 区间外的点按自然不触发。value 超出区间夹到边界。
        value: _display.clamp(effectiveMin, effectiveMax),
        min: effectiveMin,
        max: effectiveMax,
        // `showSteps` 只决定画不画刻度点，吸附步长始终由 `divisions` 决定 ——
        // 官方把两件事也分开了：`step` 是步长、`showSteps` 只控制刻度可见性。
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
    );

    final Widget bubble = Container(
      key: const ValueKey<String>('bubble'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.popupColor,
        borderRadius: BorderRadius.circular(16),
        // 墨屏：气泡与页面同为纯白，用实线代替看不见的浅阴影。
        border: theme.usesOutlines
            ? Border.all(
                color: theme.dividerColor,
                width: ohosStrokeWidth(context, theme.outlineWidth),
              )
            : null,
        boxShadow: policy.allowsShadow
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Text(
        _bubble,
        style: theme.typography.labelMedium?.copyWith(
          color: theme.textPrimaryColor,
        ),
      ),
    );

    // 前缀 / 后缀贴轨道两端，与轨道同高居中。给 `SizedBox` 而不是让
    // 它们各自撑高：不固定高度时，一个大字号后缀会把整条滑条顶高。
    final Widget row = Row(
      children: <Widget>[
        if (widget.prefix != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              height: _hotRegion,
              child: Center(child: widget.prefix),
            ),
          ),
        Expanded(child: slider),
        if (widget.suffix != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: SizedBox(
              height: _hotRegion,
              child: Center(child: widget.suffix),
            ),
          ),
      ],
    );

    // **气泡不参与布局高度。** 官方原文：「气泡提示的绘制区域为 Slider 自身
    // 节点的 overlay」—— 它浮在滑条之上，不撑高、不挤占兄弟节点。
    //
    // 早前把气泡当成 `Column` 的第一项，`showValueBubble` + `divisions`
    // 一给，拖动时气泡出现 → 整条滑条连同页面下方所有内容被推下去 6 + 气泡
    // 高，松手又弹回来。用户报的正是这条：「滑动时界面往下掉，应该固定不动」。
    //
    // 用 `Stack` 把气泡叠在轨道**行**上，行的高度由 `row` 自己决定（
    // `Slider` 的固有高 = 命中区 40 / 32），气泡只是多画一层、不参与测量。
    //
    // `Stack` 默认按子节点最大者撑高：`row` 有确定高度，`Positioned` 的子节点
    // 不参与测量，所以整体高度仍是 `row` 的高度 —— 拖动过程中恒定。
    // `clipBehavior: Clip.none` 允许气泡画到 `Stack` 边界之外（往上溢出）。
    //
    // 气泡**水平跟着滑块**走（官方「蓝色条和气泡都会跟手运动」），用
    // `Alignment` 按 `_display` 在有效区间内的比例定位，与 `Slider` 同一套
    // 归一化。
    final Widget stack = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // `Stack` 在**松散**约束下会被撑到父级允许的最大尺寸（实测
        // `Center` 里直接给 600 高），必须先钉住这一行的高度。`row` 自己
        // 是「命中区高」的 `Row`，`SizedBox` 只复述这个高度、不改变它。
        SizedBox(height: _hotRegion, width: double.infinity, child: row),
        if (showBubble)
          Positioned(
            // 气泡底边距轨道中线 = 轨道半高 + 间距；`bottom` 相对 `Stack`
            // 底边，`Stack` 高 = `_hotRegion`，故减掉半个命中区。
            bottom: _hotRegion / 2 + _trackThickness / 2 + 6,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment(_bubbleAlignment * 2 - 1, 0),
              child: bubble,
            ),
          ),
      ],
    );

    // `none` 形态没有可见滑块，给整条一个最小高度，否则父容器按 0 高测量
    // 之后连轨道都画不出来。
    return widget.style == OhosSliderStyle.none
        ? ConstrainedBox(
            constraints: BoxConstraints(minHeight: _hotRegion),
            child: Center(child: stack),
          )
        : stack;
  }

  /// 气泡（与滑块）在轨道上的相对位置，0 = 最左、1 = 最右。
  ///
  /// 用 `value` 在本条滑条的**有效区间**内归一化，与 `Slider` 的滑块位置
  /// 同一套算法；区间退化（min == max）时贴左，避免除零。
  double get _bubbleAlignment {
    final (double, double)? range = widget.slideRange?.resolve(
      widget.min,
      widget.max,
    );
    final double lo = range?.$1 ?? widget.min;
    final double hi = range?.$2 ?? widget.max;
    if (hi <= lo) {
      return 0;
    }
    return ((_display.clamp(lo, hi) - lo) / (hi - lo)).clamp(0.0, 1.0);
  }
}

/// `SliderStyle.NONE` 用的空滑块形状。
class _NoThumbShape extends SliderComponentShape {
  const _NoThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.zero;

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
  }) {}
}

/// 圆形刻度点。
///
/// Material 的 `RoundSliderTickMarkShape` 半径固定取 `trackHeight / 4`，
/// 而且必须传 `tickMarkRadius` 才能改 —— 那个字段本身没问题，但它把半径
/// 写在 shape 上，这里要的是**直径**（官方 `stepSize` 以直径计）。多一层
/// 换算不如直接画：口径对不上的时候，少一次除法就少一个错。
///
/// 颜色不用 Material 的 active / inactive 两档：官方刻度点只有一种颜色，
/// 已走过与未走过都画同一个，靠轨道自身的明度变化区分区间。
///
/// 公开（而非 `_` 私有）是因为测试要断言它的 `color`：刻度点的颜色方向
/// （比轨道深还是浅）是用户直接能看出来的观感问题，只能靠读字段验。
class OhosTickMarkShape extends SliderTickMarkShape {
  const OhosTickMarkShape({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    required bool isEnabled,
  }) => Size.fromRadius(diameter / 2);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    required bool isEnabled,
  }) {
    context.canvas.drawCircle(center, diameter / 2, Paint()..color = color);
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
      // 描边始终用 `outlineColor`，禁用态也不往填充色上收敛：禁用拇指的灰
      // 必然与轨道某一档重合（已走 #767676 / 未走 #BFBFBF），轮廓一旦跟着
      // 变成同色，拇指就只剩半圈，看不出位置。
      canvas.drawCircle(
        center,
        radius - outlineWidth / 2,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth,
      );
    }
  }
}
