import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// 进度条形态，对应 ArkUI 的 `ProgressType`。
///
/// 五型不是「同一个环的五种画法」，而是三条不同的几何：
///
/// - [linear] / [capsule] 沿主轴推进，进度是**长度**；
/// - [ring] / [scaleRing] 沿圆周推进，进度是**角度**；
/// - [eclipse] 两者都不是：它填的是一个**面积**，靠两条弧的非零环绕
///   （non-zero winding）相减出月牙。用「画一段弧」的思路做不出月牙，
///   这也是它必须单独实现的原因。
enum OhosProgressIndicatorVariant {
  /// 线性进度条。
  linear,

  /// 环形无刻度。
  ring,

  /// 月相：从无到左半圆再到满圆。
  eclipse,

  /// 环形带刻度。**进度靠刻度换色表达，不靠增减刻度。**
  scaleRing,

  /// 胶囊：两端圆弧的表现同 [eclipse]，中段同 [linear]。
  capsule,
}

/// `OhosProgressIndicator` 里那些「官方给了具体值」的几何常量。
///
/// 数值出处分两类，混在一起会看不出哪些是能核对的：
///
/// - 系统资源表（`doc/reference/resources/float.json`）：
///   [thickness] = `ohos_id_progress_thickness`、
///   [linearWidth] = `ohos_id_progress_default_width`、
///   [diameter] = `ohos_id_progress_default_diameter`、
///   [scaleCount] = `ohos_id_progress_scale_number`、
///   [scaleWidth] = `ohos_id_progress_scale_width`、
///   [capsuleBorderWidth] = `ohos_id_float_progress_border_width`；
/// - 参考文档正文：`strokeWidth` 默认 4.0vp、`scaleWidth` 默认 2.0vp、
///   ScaleRing「默认情况下宽高最小为 77vp」、Capsule 的 `borderColor`
///   API 11+ 为 `#33007dff`、`font` 12fp、`fontColor` `#ff182431`。
///
/// [capsuleBorderWidth] 容易被当成 0：`progress_modifier.cpp` 里确有
/// `DEFAULT_CAPSULE_BORDER_WIDTH = 0.0`，但那是**绘制函数参数**的兜底，
/// 进到组件里的默认值来自主题的 `progress_border_width` 令牌，即 1vp。
/// 两者名字相近、取值相反，照前者写会让胶囊少一圈内描边。
class OhosProgressMetrics {
  const OhosProgressMetrics._();

  /// 轨道 / 环形厚度，也是 ScaleRing 的**刻度径向长度**。
  static const double thickness = 4;

  /// 线性进度条在无父约束时的默认宽度。
  static const double linearWidth = 300;

  /// 圆型三档（ring / eclipse）的默认直径。
  static const double diameter = 72;

  /// ScaleRing 的直径下界（官方「默认情况下宽高最小为 77vp」）。
  ///
  /// 比 [diameter] 大 5vp 不是随手取的：`scaleCount` 的取值范围是
  /// `[2, min(w,h) / scaleWidth / 2 / π]`，直径 72、刻度宽 2 时上限约 5.7 ——
  /// 连 6 个刻度都画不下，默认的 120 会直接触发退化、退成无刻度环。
  static const double scaleRingDiameter = 77;

  /// 环形总刻度数。
  static const int scaleCount = 120;

  /// 刻度粗细（径向的宽度，不是长度）。
  static const double scaleWidth = 2;

  /// 胶囊内描边宽度。
  static const double capsuleBorderWidth = 1;

  /// 胶囊内描边颜色（API 11 及以上）。
  static const Color capsuleBorderColor = Color(0x33007DFF);

  /// 胶囊上的文字大小。
  static const double capsuleTextSize = 12;

  /// 胶囊上的文字颜色。
  static const Color capsuleTextColor = Color(0xFF182431);
}

/// 度 → 弧度。
///
/// ArkUI 的 `DrawArc` / `Path.addArc` 与 Flutter 同一套坐标（0 弧度在 3 点钟、
/// 顺时针为正），`progress_modifier.cpp` 里的 `ANGLE_90 / 180 / 270` 直接就是
/// 这套值。所以这里**只换单位、不减 90** —— 与 `ohos_arc.dart` 的
/// `ohosCanvasAngle` 不同，那个服务的是 Gauge 的「钟面 0 点在 12 点」语义。
double _rad(double degrees) => degrees * math.pi / 180;

/// WCAG 2.x 的对比度（1:1 ~ 21:1），用相对亮度线性化后的比值。
///
/// 只用来判「这行字压在填充上还能不能读」，不参与配色决策。
double _contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// 月相（Eclipse）的形状。
///
/// 算法照 `progress_modifier.cpp` 的 `PaintMoon`，因为它不是「画个扇形」：
///
/// 1. 先描出**左半圆**轮廓（6 点 → 9 点 → 12 点）；
/// 2. 再从 12 点描一条**宽度可变**的椭圆弧。`value ≤ 0.5` 时逆时针（与第 1 条
///    反向 ⇒ 相减），`value > 0.5` 时顺时针（与第 1 条同向 ⇒ 相加）；
/// 3. 两条子路径交给非零环绕填充，围出的就是月牙。
///
/// 三档端点因此各不相同，写成「按角度画扇形」会全错：
///
/// - `value = 0`：椭圆与整圆等宽，两弧完全重合反向 ⇒ 面积为 0；
/// - `value = 0.5`：椭圆退化成中轴线，两弧围出**整个左半圆**（不是零）；
/// - `value = 1`：顺时针弧补上右半圆，与左半圆拼成满圆。
///
/// [value] 在内部夹到 `[0, 1]`：官方是 `value / total`，越界值在入口就夹掉了。
Path ohosEclipsePath(Rect rect, double value) {
  final double radius = math.min(rect.width, rect.height) / 2;
  final Offset center = rect.center;
  final double v = value.clamp(0.0, 1.0);
  final Path path = Path();
  // 第 1 条：整圆的左半圆，作为外边界。
  path.addArc(
    Rect.fromCircle(center: center, radius: radius),
    _rad(90),
    _rad(180),
  );
  // 第 2 条：宽度 2 * offset 的椭圆弧，中点始终落在圆心水平线上。
  final double offset = v <= 0.5
      ? radius - radius * v / 0.5
      : radius * (v - 0.5) / 0.5;
  path.moveTo(center.dx, center.dy - radius);
  path.addArc(
    Rect.fromLTRB(
      center.dx - offset,
      center.dy - radius,
      center.dx + offset,
      center.dy + radius,
    ),
    _rad(270),
    _rad(v <= 0.5 ? -180 : 180),
  );
  return path;
}

/// 胶囊已完成部分的形状。
///
/// 官方三档分流（`PaintCapsuleRightBorder`）不是性能优化，而是**三种不同的
/// 几何**，缺一档就会露馅：
///
/// - `progressWidth < borderRadius`：右端画一条反向椭圆弧，与左半圆相减
///   ⇒ 表现为月牙 —— 这就是文档「头尾两端圆弧处的进度展示效果与 Eclipse
///   相同」的落地方式；
/// - `progressWidth >= width - borderRadius`：补中段矩形 + 右半圆
///   ⇒ 收口，否则快满时右边缺一个角；
/// - 其余：只有中段矩形 ⇒ 表现为 Linear。
///
/// [borderRadius] 夹到 `[0, height / 2]`（官方 `borderRadius` 的取值范围），
/// 默认就是 `height / 2`，此时两端是正半圆。
Path ohosCapsuleProgressPath({
  required Size size,
  required double value,
  required double borderRadius,
}) {
  final double w = size.width;
  final double h = size.height;
  if (w <= 0 || h <= 0) {
    return Path();
  }
  final double r = borderRadius.clamp(0.0, h / 2);
  final double progress = value.clamp(0.0, 1.0) * w;
  final Path path = Path();
  // 左端：默认档（r == h/2）画正半圆；把圆角调小过则画圆角矩形。
  if (r >= h / 2) {
    path.addArc(Rect.fromLTRB(0, 0, r * 2, h), _rad(90), _rad(180));
  } else {
    path.addRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(0, 0, r, h),
        topLeft: Radius.circular(r),
        bottomLeft: Radius.circular(r),
      ),
    );
  }
  if (progress < r) {
    // 月牙档：右边界是 2r 处的椭圆。
    path.addArc(
      Rect.fromLTRB(progress, 0, math.max(progress, r * 2 - progress), h),
      _rad(270),
      _rad(-180),
    );
  } else if (progress >= w - r) {
    path.addRect(Rect.fromLTRB(r, 0, w - r, h));
    path.addArc(Rect.fromLTRB(w - r * 2, 0, w, h), _rad(270), _rad(180));
  } else {
    path.addRect(Rect.fromLTRB(r, 0, progress, h));
  }
  return path;
}

/// ScaleRing 在当前尺寸下会不会退化成无刻度环。
///
/// 退化条件在 `progress_modifier.cpp` 里只有一行，但它是**两个方向**的：
/// 刻度画得比间距还宽（`scaleWidth > 2πr / scaleCount`）时直接转去画环。
/// 文档把同一个不等式写成了刻度数的上界
/// `min(width, height) / scaleWidth / 2 / π`。
///
/// 抽成纯函数是为了让测试能直接钉住那条边界 —— 退化本身是有意为之的官方
/// 行为（刻度太密会连成一圈糊住环），不是降级。
bool ohosScaleRingDegrades({
  required double radius,
  required int scaleCount,
  required double scaleWidth,
}) {
  if (scaleCount < 2 || radius <= 0) {
    return true;
  }
  final double spacing = 2 * math.pi * radius / scaleCount;
  return scaleWidth > spacing;
}

/// HarmonyOS 进度条，对应 ArkUI 的 `Progress`。
///
/// 五型共用一套字段，但每种形态**只读自己要的那几个**（其余为 null 时走
/// 默认值，给了也不报错）：
///
/// ```dart
/// OhosProgressIndicator.linear(value: 0.4)      // 线性
/// OhosProgressIndicator.ring(value: 0.7)        // 环形
/// OhosProgressIndicator.eclipse(value: 0.55)    // 月相
/// OhosProgressIndicator.scaleRing(value: 0.6)   // 带刻度
/// OhosProgressIndicator.capsule(value: 0.35, content: '安装中')
/// ```
///
/// [value] 是 `0.0`–`1.0` 的比例，不是官方的 `value` / `total` 双字段。
/// 官方把两者分开，是因为 ArkTS 需要一个可写的总数；Flutter 侧让调用方自己
/// 算比例是一件事，多一个 `total` 只会在两处同时越界时打架。
class OhosProgressIndicator extends StatelessWidget {
  /// 环形（无刻度）。名称沿用旧版 `circular`，与 `ProgressType.Ring` 对应。
  const OhosProgressIndicator.circular({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.size,
    this.strokeWidth,
  }) : variant = OhosProgressIndicatorVariant.ring,
       trackHeight = null,
       shadow = false,
       scaleCount = OhosProgressMetrics.scaleCount,
       scaleWidth = OhosProgressMetrics.scaleWidth,
       capsuleBorderRadius = null,
       borderColor = null,
       content = null,
       showDefaultPercentage = false;

  /// 环形无刻度。等价于 [OhosProgressIndicator.circular]，多一个 [shadow]。
  const OhosProgressIndicator.ring({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.size,
    this.strokeWidth,
    this.shadow = false,
  }) : variant = OhosProgressIndicatorVariant.ring,
       trackHeight = null,
       scaleCount = OhosProgressMetrics.scaleCount,
       scaleWidth = OhosProgressMetrics.scaleWidth,
       capsuleBorderRadius = null,
       borderColor = null,
       content = null,
       showDefaultPercentage = false;

  /// 线性。
  const OhosProgressIndicator.linear({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.trackHeight,
  }) : variant = OhosProgressIndicatorVariant.linear,
       size = null,
       strokeWidth = null,
       shadow = false,
       scaleCount = OhosProgressMetrics.scaleCount,
       scaleWidth = OhosProgressMetrics.scaleWidth,
       capsuleBorderRadius = null,
       borderColor = null,
       content = null,
       showDefaultPercentage = false;

  /// 月相。
  const OhosProgressIndicator.eclipse({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.size,
  }) : variant = OhosProgressIndicatorVariant.eclipse,
       trackHeight = null,
       strokeWidth = null,
       shadow = false,
       scaleCount = OhosProgressMetrics.scaleCount,
       scaleWidth = OhosProgressMetrics.scaleWidth,
       capsuleBorderRadius = null,
       borderColor = null,
       content = null,
       showDefaultPercentage = false;

  /// 环形带刻度。
  const OhosProgressIndicator.scaleRing({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.size,
    this.strokeWidth,
    this.scaleCount = OhosProgressMetrics.scaleCount,
    this.scaleWidth = OhosProgressMetrics.scaleWidth,
  }) : variant = OhosProgressIndicatorVariant.scaleRing,
       trackHeight = null,
       shadow = false,
       capsuleBorderRadius = null,
       borderColor = null,
       content = null,
       showDefaultPercentage = false;

  /// 胶囊。
  const OhosProgressIndicator.capsule({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.trackHeight,
    this.capsuleBorderRadius,
    this.borderColor,
    this.content,
    this.showDefaultPercentage = false,
  }) : variant = OhosProgressIndicatorVariant.capsule,
       size = null,
       strokeWidth = null,
       shadow = false,
       scaleCount = OhosProgressMetrics.scaleCount,
       scaleWidth = OhosProgressMetrics.scaleWidth;

  /// 进度的视觉形态。
  final OhosProgressIndicatorVariant variant;

  /// 已完成比例 `0.0`–`1.0`；null 表示不确定态。
  ///
  /// 只有 [OhosProgressIndicatorVariant.linear] 与
  /// [OhosProgressIndicatorVariant.ring] 有不确定态动画 —— 官方的不确定态是
  /// `ProgressStatus.LOADING`，而它只挂在 `RingStyleOptions` 上。Eclipse /
  /// ScaleRing / Capsule 收到 null 一律按 0 画，不凭空造一种官方没有的动效。
  ///
  /// 这两种的动画由组件自己驱动（2000ms 一轮，官方 `TIME_2000`），调用方不用
  /// 另外接 `AnimationController`；墨水屏策略把动画时长压成 0 时自动停在静态中位。
  final double? value;

  /// 已完成部分的颜色。null 取主题品牌色。
  final Color? color;

  /// 未完成部分（轨道）的颜色。null 按品牌色 15% 叠底；灰阶屏上叠底会消失，
  /// 自动改画一条实线（见 `_TrackStyle`）。
  final Color? backgroundColor;

  /// 圆型两档（ring / eclipse）的直径。null 取形态默认值（72 / 77）。
  final double? size;

  /// 环形厚度，同时是 ScaleRing 的**刻度径向长度**。默认 4vp。
  ///
  /// 官方这条夹取值得抄下来：厚度 + 阴影偏移 ≥ 半径时，厚度被压成半径的一半。
  /// 不留这道夹取，小尺寸 + 粗环会画出一个实心圆。
  final double? strokeWidth;

  /// 线性 / 胶囊的轨道高度。默认 4vp（胶囊的默认高度由父容器给）。
  final double? trackHeight;

  /// ScaleRing 的总刻度数。默认 120。
  final int scaleCount;

  /// ScaleRing 的刻度粗细。默认 2vp。
  final double scaleWidth;

  /// 胶囊圆角。null 取 `height / 2`（正胶囊）。
  final double? capsuleBorderRadius;

  /// 胶囊的内描边颜色。null 取 `#33007dff`。
  final Color? borderColor;

  /// 胶囊上显示的文本。给了 [content] 后 [showDefaultPercentage] 不生效
  /// （官方：「设置了 content 属性时该属性不生效」）。
  final String? content;

  /// 不传 [content] 时是否显示百分比文本。默认 false。
  final bool showDefaultPercentage;

  /// 环形阴影（官方 `RingStyleOptions.shadow`）。半径 ≤ 10 时不画
  /// （「没有足够空间同时画环和阴影」）。
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color active = color ?? theme.highlightColor;
    final _TrackStyle track = _TrackStyle.of(theme, backgroundColor);
    switch (variant) {
      case OhosProgressIndicatorVariant.linear:
        return _buildLinear(theme, active, track);
      case OhosProgressIndicatorVariant.ring:
        return _buildRing(theme, active, track);
      case OhosProgressIndicatorVariant.eclipse:
        return _buildEclipse(theme, active, track);
      case OhosProgressIndicatorVariant.scaleRing:
        return _buildScaleRing(theme, active, track);
      case OhosProgressIndicatorVariant.capsule:
        return _buildCapsule(context, theme, active, track);
    }
  }

  Widget _buildLinear(OhosThemeData theme, Color active, _TrackStyle track) {
    final double height = trackHeight ?? OhosProgressMetrics.thickness;
    // 线性进度条只吃高度，宽度由父容器给。无界时退回官方默认宽度 ——
    // 不判 `hasBoundedWidth` 的话，`SizedBox(height:)` 会拿到 `width: Infinity`,
    // 崩在布局阶段（静态分析看不出来）。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : OhosProgressMetrics.linearWidth;
        return SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            // 圆角取轨道粗细的一半：`ohos_id_corner_radius_progress_bar` 在
            // 4vp 轨道下正好同值，写成一半是为了粗轨道不变成方角。
            borderRadius: BorderRadius.circular(height / 2),
            child: _IndeterminateCycle(
              enabled: value == null,
              builder: (Animation<double>? phase) => CustomPaint(
                painter: _LinearPainter(
                  value: value,
                  color: active,
                  track: track,
                  indeterminate: value == null,
                  policy: theme.policy,
                  phase: phase,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRing(OhosThemeData theme, Color active, _TrackStyle track) {
    final double diameter = size ?? OhosProgressMetrics.diameter;
    final double thickness = strokeWidth ?? OhosProgressMetrics.thickness;
    final double radius = diameter / 2;
    // 阴影偏移取 `thickness / 2 + max(offsetX, offsetY)`；官方两个偏移都是
    // 经验值 3，与模糊半径分开，这里沿用同一组合。
    final bool wantShadow = shadow && radius > 10;
    final double shadowOffset = wantShadow ? thickness / 2 + 3 : 0;
    final double effective = thickness + shadowOffset >= radius
        ? radius / 2
        : thickness;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: _IndeterminateCycle(
        enabled: value == null,
        builder: (Animation<double>? phase) => CustomPaint(
          painter: _RingPainter(
            value: value,
            color: active,
            track: track,
            thickness: effective,
            shadow: wantShadow,
            policy: theme.policy,
            indeterminate: value == null,
            phase: phase,
          ),
        ),
      ),
    );
  }

  Widget _buildEclipse(OhosThemeData theme, Color active, _TrackStyle track) {
    final double diameter = size ?? OhosProgressMetrics.diameter;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(
        painter: _EclipsePainter(
          value: value ?? 0,
          color: active,
          track: track,
        ),
      ),
    );
  }

  Widget _buildScaleRing(OhosThemeData theme, Color active, _TrackStyle track) {
    final double diameter = size ?? OhosProgressMetrics.scaleRingDiameter;
    final double thickness = strokeWidth ?? OhosProgressMetrics.thickness;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(
        painter: _ScaleRingPainter(
          value: value ?? 0,
          color: active,
          track: track,
          thickness: thickness,
          scaleCount: scaleCount,
          scaleWidth: scaleWidth,
        ),
      ),
    );
  }

  Widget _buildCapsule(
    BuildContext context,
    OhosThemeData theme,
    Color active,
    _TrackStyle track,
  ) {
    // 胶囊的默认高度：官方示例全写 `.height(50)`，文档没有默认值 ——
    // 这里取 40（与本库其它「单行控件」同高），显式传 `trackHeight` 可覆盖。
    final double height = trackHeight ?? 40;
    final String? label = _capsuleLabel;
    final double strokeWidth = ohosProgressStrokeWidth(context);
    final double fill = value ?? 0;
    // 两段字色：轨道上照官方的深色，填充上在同色时才换成反白色
    // （见 _capsuleOnFillColor）。
    const Color onTrack = OhosProgressMetrics.capsuleTextColor;
    final Color onFill = _capsuleOnFillColor(theme, active);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : OhosProgressMetrics.linearWidth;
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _CapsulePainter(
                    value: fill,
                    color: active,
                    track: track,
                    borderRadius: capsuleBorderRadius ?? height / 2,
                    borderColor:
                        borderColor ?? OhosProgressMetrics.capsuleBorderColor,
                    strokeWidth: strokeWidth,
                  ),
                ),
              ),
              if (label != null) _capsuleLabelWidget(theme, label, onTrack),
              // 填充与官方字色几乎同色时才叠第二层：只保留填充区那一段的
              // 反白字。整段换色不行 —— 文字跨在填充边界上（如 `52%`）时，
              // 落在轨道上的那半个字形会跟着变白、直接消失。
              if (label != null && onFill != onTrack)
                Positioned.fill(
                  child: ClipRect(
                    clipper: _CapsuleFillClipper(fill * width),
                    child: Center(
                      child: _capsuleLabelWidget(theme, label, onFill),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 胶囊文字落在**填充**上时该用的颜色。
  ///
  /// 官方给的 `capsuleTextColor`（`#ff182431`）是深色：压在彩屏的蓝填充
  /// （`#0A59F7`）上约 2.8:1，是官方自己认可的观感；但墨屏的
  /// `highlightColor` 是纯黑，深色字压上去只剩 **1.3:1** —— 文字整段消失。
  /// 所以这一档按对比度兜底：低于 2:1（＝两者几乎同色）
  /// 换成主题现成的 [OhosThemeData.onHighlightColor]（白纸墨屏 = 纸白，
  /// 深色墨屏 = 纸黑）。阈值取 2 而不是 WCAG 的 3，正是因为官方彩屏本身
  /// 就站在 2.8 —— 抬到 3 会把彩屏一起改掉，偏离官方。
  Color _capsuleOnFillColor(OhosThemeData theme, Color active) {
    const Color official = OhosProgressMetrics.capsuleTextColor;
    return _contrastRatio(official, active) < 2
        ? theme.onHighlightColor
        : official;
  }

  /// 胶囊上的文字，只上色不做定位 —— 居中由调用方的 `Stack` / `Center` 负责。
  Widget _capsuleLabelWidget(
    OhosThemeData theme,
    String label,
    Color color,
  ) {
    return Padding(
      // 官方 `progress_text_margin` = 8vp：文字与端头弧线之间留出一个圆角的
      // 距离，否则 100% 时数字会顶到弧上。
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontSize: OhosProgressMetrics.capsuleTextSize,
          color: color,
          // 官方 `font` 的其余参数「跟随 Text 组件的主题值」，
          // 所以字重交给主题排版，只钉死字号与颜色。
          fontFamily: theme.typography.fontFamily,
        ),
      ),
    );
  }

  /// 胶囊上要显示的文本：显式 [content] 优先，否则按 [showDefaultPercentage]。
  String? get _capsuleLabel {
    if (content != null) {
      return content;
    }
    if (!showDefaultPercentage) {
      return null;
    }
    // 官方显示整数百分比（示例里是 `100%`）。用 `round` 而不是
    // `toStringAsFixed`：0.999 直接截断会显示成「99%」，与视觉上的满格矛盾。
    return '${((value ?? 0).clamp(0.0, 1.0) * 100).round()}%';
  }
}

/// 给不确定态提供相位：时间轴由本库自己接管。
///
/// 官方的不确定态（Linear 的 `StartLinearSweepingAnimation`、Ring 的
/// `ProgressStatus.LOADING`）都是 2000ms 一轮、循环往复。周期先过一遍
/// [OhosVisualPolicy.scaleMotion]：墨水屏策略把它压成 0，这时回调拿到 null，
/// 画笔退回静态中位 —— 「该不该动」由策略层判断，组件不自己认屏幕。
///
/// 相位通过 `CustomPainter(repaint:)` 直达画布，走的是重绘而不是每帧重建。
class _IndeterminateCycle extends StatefulWidget {
  const _IndeterminateCycle({required this.enabled, required this.builder});

  /// 只有不确定态（`value == null`）才需要转。
  final bool enabled;

  /// 参数为相位；null 表示「别动，画静态中位」。
  final Widget Function(Animation<double>? phase) builder;

  @override
  State<_IndeterminateCycle> createState() => _IndeterminateCycleState();
}

class _IndeterminateCycleState extends State<_IndeterminateCycle>
    with SingleTickerProviderStateMixin {
  /// 官方 `TIME_2000`：一轮 2000ms。
  static const Duration _cycle = Duration(milliseconds: 2000);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_IndeterminateCycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final Duration scaled = OhosTheme.of(context).policy.scaleMotion(_cycle);
    if (!widget.enabled || scaled == Duration.zero) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      return;
    }
    // 时长变了才替换，避免每次依赖变化都重置相位
    if (_controller.duration != scaled) {
      _controller.duration = scaled;
    }
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(_controller.isAnimating ? _controller : null);
}

/// 进度条描边的实际线宽，取整到整数设备像素。
///
/// 1vp 的内描边在 1.5 倍屏上会被栅格化成两行灰，本就细，糊掉就完全看不见。
double ohosProgressStrokeWidth(BuildContext context) {
  final double? ratio = MediaQuery.maybeDevicePixelRatioOf(context);
  if (ratio == null || ratio <= 0) {
    return OhosProgressMetrics.capsuleBorderWidth;
  }
  final double px = (OhosProgressMetrics.capsuleBorderWidth * ratio)
      .roundToDouble();
  return (px < 1 ? 1.0 : px) / ratio;
}

/// 轨道（未完成部分）在当前屏幕上的落地方式。
///
/// 三档而不是两档：彩屏铺 15% 的底、灰阶屏改画一条实线、显式给了颜色就照用。
/// 判据不是「是不是墨水屏」，而是 `policy.tint` 返回不返回透明 —— 20% 以下的
/// 浅底在 16 级灰上留不住形体，这是策略已经知道的事实，组件不必再判一次。
@immutable
class _TrackStyle {
  const _TrackStyle({required this.color, required this.outline});

  factory _TrackStyle.of(OhosThemeData theme, Color? override) {
    if (override != null) {
      return _TrackStyle(color: override, outline: false);
    }
    final Color tinted = theme.policy.tint(theme.highlightColor, 0.15);
    if (tinted.a == 0) {
      return _TrackStyle(
        color: theme.policy.line(theme.textTertiaryColor, 1),
        outline: true,
      );
    }
    return _TrackStyle(color: tinted, outline: false);
  }

  /// 铺底用的颜色。
  final Color color;

  /// true 表示「铺底无效，改画线」。
  final bool outline;
}

/// 线性进度条。
///
/// 没用 `LinearProgressIndicator`：它的不确定态动画、圆角、轨道都在 Material
/// 侧固定，而官方要求进度条两端**平齐**（扫光才是另一种效果），圆头要靠外层
/// `ClipRRect` 包出来 —— 包完就再也改不动端头了。
class _LinearPainter extends CustomPainter {
  const _LinearPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.indeterminate,
    required this.policy,
    this.phase,
  }) : super(repaint: phase);

  final double? value;
  final Color color;
  final _TrackStyle track;
  final bool indeterminate;
  final OhosVisualPolicy policy;

  /// 不确定态的相位（0→1 循环），由 [_IndeterminateCycle] 提供。
  ///
  /// null 表示「不该动」：墨水屏策略把动画时长压成 0 时就是这一档，
  /// 此时画静态中位，与没有动画的版本一致。
  final Animation<double>? phase;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    if (track.outline) {
      // 灰阶屏：轨道画成空心描边，否则「已走 / 未走」只能靠一档灰区分。
      canvas.drawRect(
        rect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = track.color,
      );
    } else {
      canvas.drawRect(rect, Paint()..color = track.color);
    }
    if (indeterminate) {
      // 不确定态：一段 30% 的游标在轨道上扫过，官方 `Linear` 的这一档由
      // `StartLinearSweepingAnimation` 驱动，时长 2000ms、循环往复。
      // 相位由 [_IndeterminateCycle] 给：有了它就从左外侧扫入、右外侧扫出；
      // 为 null（墨水屏等把时长压成 0 的场景）时停在静态中位。
      final double seg = size.width * 0.3;
      final double? p = phase?.value;
      final double left = p == null
          ? size.width * 0.35
          : (size.width + seg) * p - seg;
      canvas.drawRect(
        Rect.fromLTWH(left, 0, seg, size.height),
        Paint()..color = color,
      );
      return;
    }
    final double v = (value ?? 0).clamp(0.0, 1.0);
    if (v <= 0) {
      return;
    }
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width * v, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_LinearPainter old) =>
      old.value != value ||
      old.color != color ||
      old.indeterminate != indeterminate ||
      old.track.color != track.color ||
      old.phase != phase;
}

/// 环形无刻度。
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.thickness,
    required this.shadow,
    required this.policy,
    this.indeterminate = false,
    this.phase,
  }) : super(repaint: phase);

  final double? value;
  final Color color;
  final _TrackStyle track;
  final double thickness;
  final bool shadow;
  final OhosVisualPolicy policy;

  /// 不确定态的相位（0→1 循环）：弧绕圈转。null = 停在静态中位。
  final Animation<double>? phase;
  final bool indeterminate;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = math.min(size.width, size.height) / 2;
    // 厚度以中心线为基准对称展开，半径要让出半个环厚，否则外沿被裁掉。
    final double ringRadius = radius - thickness / 2;
    if (ringRadius <= 0) {
      return;
    }
    final Rect rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: ringRadius,
    );
    final Paint pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (track.outline) {
      // 灰阶屏：整圈画成 1px 实线环，让「还有多少没走完」有个可见的终点。
      canvas.drawCircle(
        rect.center,
        ringRadius,
        pen
          ..color = track.color
          ..strokeWidth = policy.outlineWidth ?? 1,
      );
    } else {
      canvas.drawCircle(
        rect.center,
        ringRadius,
        pen
          ..color = track.color
          ..strokeWidth = thickness,
      );
    }
    double v;
    if (indeterminate) {
      // 不确定态：一段 90° 的游标，按官方 `PaintTrailing` 的做法画。
      v = 0.25;
    } else {
      v = (value ?? 0).clamp(0.0, 1.0);
    }
    if (v <= 0) {
      return;
    }
    final double sweep = 360 * v;
    // 起点 12 点：源码在 `PaintWhole` 里 `Rotate(-90 - additionalAngle)`，
    // 即整条弧从 12 点起顺时针铺。
    //
    // 不确定态：`ProgressStatus.LOADING` 下这段 90° 游标绕圈转（2000ms 一轮），
    // 相位由 [_IndeterminateCycle] 给；null 时停在 `PaintTrailing` 的静态落点。
    final double? phaseValue = indeterminate ? phase?.value : null;
    final double start = _rad(
      indeterminate ? -90 + 135 + 360 * (phaseValue ?? 0) : -90,
    );
    if (shadow && policy.allowsShadow) {
      // 阴影取环色本身（官方「阴影颜色与圆环颜色一致」），靠 blur 实现，
      // 不用第二套色 —— 换主题时两者不会分家。
      canvas.drawArc(
        rect,
        start,
        _rad(sweep),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = thickness
          ..color = color.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.drawArc(
      rect,
      start,
      _rad(sweep),
      false,
      pen
        ..color = color
        ..strokeWidth = thickness,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.thickness != thickness ||
      old.indeterminate != indeterminate ||
      old.track.color != track.color ||
      old.phase != phase;
}

/// 月相。
class _EclipsePainter extends CustomPainter {
  const _EclipsePainter({
    required this.value,
    required this.color,
    required this.track,
  });

  final double value;
  final Color color;
  final _TrackStyle track;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = math.min(size.width, size.height) / 2;
    final Offset center = size.center(Offset.zero);
    // 官方先铺满整个圆作背景。灰阶屏上这层铺底会消失，改画一圈 1px 实线 ——
    // 月牙只占一块面积，没有轮廓时读者会以为进度是「凭空浮现」的。
    if (track.outline) {
      canvas.drawCircle(
        center,
        radius - 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = track.color,
      );
    } else {
      canvas.drawCircle(center, radius, Paint()..color = track.color);
    }
    if (value <= 0) {
      return;
    }
    canvas.drawPath(
      ohosEclipsePath(Offset.zero & size, value),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_EclipsePainter old) =>
      old.value != value ||
      old.color != color ||
      old.track.color != track.color;
}

/// 环形带刻度。
class _ScaleRingPainter extends CustomPainter {
  const _ScaleRingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.thickness,
    required this.scaleCount,
    required this.scaleWidth,
  });

  final double value;
  final Color color;
  final _TrackStyle track;
  final double thickness;
  final int scaleCount;
  final double scaleWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = math.min(size.width, size.height) / 2;
    if (ohosScaleRingDegrades(
      radius: radius,
      scaleCount: scaleCount,
      scaleWidth: scaleWidth,
    )) {
      // 官方在这里直接转去画无刻度环。刻度太密会连成一圈糊住，不如给个干净环。
      // 注意「退化」用的是**画环**而不是「不画」—— 空画布会被读成渲染失败。
      _paintFallbackRing(canvas, size, radius);
      return;
    }
    // 刻度是沿半径方向的短棒：长度 = thickness，粗细 = scaleWidth。
    //
    // 官方用 `PathDashEffect` 把短棒贴在半径为 radius 的路径上，短棒因此以
    // 半径为中心向内外各伸 thickness/2。这里把刻度整体内移半个棒长，落在
    // [radius - thickness, radius] 之内 —— 代价是向外少探 2vp，换来的是任何
    // 尺寸都不越界（Flutter 这一层没有 ArkUI 那样的额外裁剪）。
    final double outer = radius;
    final double inner = math.max(0.0, radius - thickness);
    final Offset center = size.center(Offset.zero);
    final Paint paint = Paint()
      ..strokeWidth = scaleWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // 官方先整圈用背景色画一遍，再用前景色覆盖前 angle 弧度 ——
    // **进度靠刻度换色表达，不是靠刻度变多**。这条最容易做反：照「线性条沿
    // 长度填色」的直觉做，会画出一条越来越长的弧。
    final int done = (value.clamp(0.0, 1.0) * scaleCount).floor();
    for (int i = 0; i < scaleCount; i++) {
      final double angle = _rad(-90 + 360 * i / scaleCount);
      final double cosA = math.cos(angle);
      final double sinA = math.sin(angle);
      canvas.drawLine(
        center + Offset(cosA * inner, sinA * inner),
        center + Offset(cosA * outer, sinA * outer),
        paint..color = i < done ? color : track.color,
      );
    }
    if (track.outline) {
      // 灰阶屏：未完成的刻度是同一档灰、与背景分不开 —— 补一圈细环定形。
      canvas.drawCircle(
        center,
        radius - 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = track.color,
      );
    }
  }

  void _paintFallbackRing(Canvas canvas, Size size, double radius) {
    final double ringRadius = radius - thickness / 2;
    if (ringRadius <= 0) {
      return;
    }
    final Rect rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: ringRadius,
    );
    final Paint pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = track.outline ? 1 : thickness;
    canvas.drawCircle(rect.center, ringRadius, pen..color = track.color);
    final double v = value.clamp(0.0, 1.0);
    if (v <= 0) {
      return;
    }
    canvas.drawArc(
      rect,
      _rad(-90),
      _rad(360 * v),
      false,
      pen
        ..color = color
        ..strokeWidth = track.outline ? math.max(1, thickness) : thickness,
    );
  }

  @override
  bool shouldRepaint(_ScaleRingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.scaleCount != scaleCount ||
      old.scaleWidth != scaleWidth ||
      old.thickness != thickness ||
      old.track.color != track.color;
}

/// 胶囊。
class _CapsulePainter extends CustomPainter {
  const _CapsulePainter({
    required this.value,
    required this.color,
    required this.track,
    required this.borderRadius,
    required this.borderColor,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final _TrackStyle track;
  final double borderRadius;
  final Color borderColor;

  /// 已经过设备像素取整的内描边宽度。
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double r = borderRadius.clamp(0.0, size.height / 2);
    final RRect outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(r),
    );
    if (!track.outline) {
      canvas.drawRRect(outer, Paint()..color = track.color);
    }
    // 内描边：官方是一条独立的 1vp 线（`progress_border_width`），画在底板
    // **之内**，所以半径跟着缩半个线宽，否则四角会露到外面。
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(strokeWidth / 2),
        Radius.circular(math.max(0, r - strokeWidth / 2)),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        // 灰阶屏上这圈线同时承担「底板轮廓」，因此用轨道色而不是品牌蓝。
        ..color = track.outline ? track.color : borderColor,
    );
    if (value <= 0) {
      return;
    }
    canvas.drawPath(
      ohosCapsuleProgressPath(size: size, value: value, borderRadius: r),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_CapsulePainter old) =>
      old.value != value ||
      old.color != color ||
      old.borderRadius != borderRadius ||
      old.borderColor != borderColor ||
      old.strokeWidth != strokeWidth ||
      old.track.color != track.color;
}

/// 只保留胶囊左侧「已填充」那一段的裁切器。
///
/// 用来叠第二层反白文字：填充区里的字用反白色、轨道区里的字保持官方深色，
/// 文字跨在边界上时两半都还在。
class _CapsuleFillClipper extends CustomClipper<Rect> {
  const _CapsuleFillClipper(this.right);

  /// 填充右边界（相对胶囊左端的像素宽度）。
  final double right;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, right, size.height);

  @override
  bool shouldReclip(_CapsuleFillClipper oldClipper) =>
      oldClipper.right != right;
}
