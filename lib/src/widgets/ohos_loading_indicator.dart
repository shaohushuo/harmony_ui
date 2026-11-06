import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// HarmonyOS 加载动效，对应 ArkUI 的 `LoadingProgress`。
///
/// 与 [OhosProgressIndicator] 的分工值得先说清，否则很容易「用错但都能转」：
///
/// - `Progress` 有 `value` / `total`，能被驱动到某个百分比 —— 它回答「完成
///   了多少」；
/// - `LoadingProgress` **没有 value**，只有一个循环动效 —— 它回答「还在转，
///   但不知道还要多久」。
///
/// 所以组件的全部 API 只有三项：颜色、显不显示、多大。想表达「进度 40%」
/// 请用 `OhosProgressIndicator.ring(value: 0.4)`；想表达「正在加载」用本组件。
///
/// 形态是**彗星形**（官方 `LoadingProgressStyle.Orbital`）：单个弧段绕圆周
/// 匀速旋转，首端粗、尾端渐隐。这不是一个可有可无的细节 —— 官方从 API 8
/// 起把默认样式固定为彗星形，`Default` / `Circular` 两个枚举值明确标注了
/// 「API version 8 及以后不支持设置」。本库因此不提供形态开关：那三个值
/// 现在都拨不动。
class OhosLoadingIndicator extends StatefulWidget {
  const OhosLoadingIndicator({
    super.key,
    this.color,
    this.size = OhosLoadingIndicatorMetrics.size,
    this.enableLoading = true,
    this.strokeWidth = OhosLoadingIndicatorMetrics.strokeWidth,
    this.duration = OhosLoadingIndicatorMetrics.period,
  });

  /// 前景色。null 取主题提示色。
  ///
  /// 官方默认值是 `#ff666666` —— 一档**中性灰**，不是品牌色。这一点容易
  /// 想当然：加载态在绝大多数设计体系里用主色，而官方把它当成一种「状态
  /// 指示」而非「品牌露出」。本库尊重这个默认值：换成品牌蓝会让每个列表的
  /// 加载行都变成视觉焦点。
  final Color? color;

  /// 组件边长，默认 32vp（`ohos_id_default_progress_diameter`）。
  ///
  /// 官方专门提示过「组件应设置合理的宽高，当组件宽高设置过大时加载动效
  /// 可能不符合预期效果」—— 弧形是按边长比例算的，放大到几百像素后弧长
  /// 变成一条长带，看起来就不再是「转圈」了。
  final double size;

  /// 是否显示动效。false 时**仍然占位**（官方 `enableLoading`）。
  ///
  /// 与 `Visibility.hidden` 的区别正是官方特意写下的：后者连 border、
  /// padding 一起隐藏，前者只停动效。占位很重要 —— 加载完成后把它设成
  /// false 而保留尺寸，列表不会因为这一行突然收缩而跳一下。
  final bool enableLoading;

  /// 彗星弧的线宽。文档没有给这个值，按 32vp 边长的比例取 3。
  final double strokeWidth;

  /// 转一圈的时长。
  ///
  /// 官方没有公开这个数值，2 秒是加载动效的常见量级（`progress_modifier.cpp`
  /// 里 `LOADING_ANIMATION_DURATION` 与 `TIME_2000` 都是 2000ms，虽然那两处
  /// 服务的是 `Progress` 的扫光，节奏一致并非巧合）。
  ///
  /// 墨水屏上整段动画会被策略压成零时长 —— 需要调用方自己保证「转不转」不
  /// 承载信息，见 `_showsMotion`。
  final Duration duration;

  @override
  State<OhosLoadingIndicator> createState() => _OhosLoadingIndicatorState();
}

class _OhosLoadingIndicatorState extends State<OhosLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didUpdateWidget(OhosLoadingIndicator old) {
    super.didUpdateWidget(old);
    if (old.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    _syncAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 按「该不该转」启停控制器。
  ///
  /// 两件事决定不转：[OhosLoadingIndicator.enableLoading] 为 false，或者
  /// 策略把动效压成了零时长（墨水屏）。
  ///
  /// 第二件事看着像多余的保护，其实不是：墨水屏上每帧都是一次真实刷新，
  /// 一个 2 秒的循环动画会让整块屏持续闪烁。停掉之后组件仍然画出**静止的
  /// 彗星弧**，读者看到的是「一个加载符号」，而不是一块空白。
  void _syncAnimation() {
    final bool allowed =
        widget.enableLoading &&
        OhosTheme.of(context).policy.scaleMotion(widget.duration) !=
            Duration.zero;
    if (allowed && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!allowed && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // 官方 API 11 起的默认色。留 `theme.textTertiaryColor` 作兜底而不是
    // 硬写 `#ff666666`：这套色板的提示色就是这个量级，换主题时跟着走才对。
    final Color active = widget.color ?? theme.textTertiaryColor;
    final Duration scaled = theme.policy.scaleMotion(widget.duration);
    final bool animating = widget.enableLoading && scaled != Duration.zero;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: animating
          ? AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  painter: _CometPainter(
                    progress: _controller.value,
                    color: active,
                    strokeWidth: widget.strokeWidth,
                  ),
                );
              },
            )
          // 不转时仍画一帧静止的彗星弧：`enableLoading: false` 的语义是
          // 「不动」，不是「消失」—— 后者官方点名说要换 `Visibility`。
          : CustomPaint(
              painter: _CometPainter(
                progress: 0,
                color: active,
                strokeWidth: widget.strokeWidth,
              ),
            ),
    );
  }
}

/// `OhosLoadingIndicator` 的默认几何。
///
/// [size] 是资源表里的 `ohos_id_default_progress_diameter` = 32vp。
/// 100% 会被 `DefaultTextStyle` 之类吞掉，所以它必须是一个真实的常量。
class OhosLoadingIndicatorMetrics {
  const OhosLoadingIndicatorMetrics._();

  /// 默认边长。
  static const double size = 32;

  /// 彗星弧线宽。
  ///
  /// 文档未给。按 14vp 周长比取 3 —— 官方 LoadingProgress 的截图里弧线明显
  /// 比 4vp 的 `Progress` 细一档，而它默认小一半的尺寸乘同一个比例正好落在
  /// 这附近。
  static const double strokeWidth = 3;

  /// 转一圈的时长。
  static const Duration period = Duration(milliseconds: 2000);
}

/// 彗星形加载弧。
///
/// 用多段描边拼出「头粗尾细」的渐隐，而不是给 `Paint` 加 `SweepGradient`：
/// 渐变的颜色在弧的两个端点之间还需要 alpha 一路降到 0，而 `SweepGradient`
/// 的 stop 是按角度均分的，末端那段仍是实色 —— 拼出来是一条突然被切断的弧。
/// 分段绘制让每一段自己的 alpha 独立，尾巴能真的淡出去。
class _CometPainter extends CustomPainter {
  const _CometPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  /// 0–1 的动画相位。
  final double progress;
  final Color color;
  final double strokeWidth;

  /// 弧的固定长度（占整圈的比例）。
  ///
  /// 官方是「一个弧段绕圈」，弧长不随动画变化 —— 变化的是位置。做成「弧越
  /// 来越长」看起来像在推进进度，与「不知道还要多久」的语义相反。
  static const double _arcFraction = 0.3;

  /// 渐隐分几段。段数太少能看到接缝，太多则每段短到亚像素、抗锯齿会糊。
  static const int _segments = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = math.min(size.width, size.height) / 2;
    final double ringRadius = radius - strokeWidth / 2;
    if (ringRadius <= 0) {
      return;
    }
    final Rect rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: ringRadius,
    );
    // 起点在 12 点，顺时针转。
    final double startBase = -math.pi / 2 + progress * 2 * math.pi;
    final double segSweep = _arcFraction * 2 * math.pi / _segments;
    for (int i = 0; i < _segments; i++) {
      // 头部（i = 0）最实，尾部逐段淡出。用平方衰减而不是线性：线性衰减在
      // 视觉上会显得尾巴「一半长」，平方更接近彗尾的实际观感。
      final double t = 1 - i / _segments;
      canvas.drawArc(
        rect,
        startBase + segSweep * i,
        // 每段多画一点点，相邻段重叠半个弧度以内可以盖住抗锯齿留下的缝；
        // 画成精确相等会在弧上看到一圈极细的虚线。
        segSweep * 1.02,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt
          ..color = color.withValues(alpha: (t * t).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_CometPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
