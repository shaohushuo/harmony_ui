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

  /// 前景色。null 取主题的次级文字色。
  ///
  /// 官方默认值是 `#ff666666` —— 一档**中性灰**，不是品牌色。这一点容易
  /// 想当然：加载态在绝大多数设计体系里用主色，而官方把它当成一种「状态
  /// 指示」而非「品牌露出」。本库尊重这个默认值：换成品牌蓝会让每个列表的
  /// 加载行都变成视觉焦点。
  ///
  /// 落到色板上，`#ff666666` 正好是**60% 黑**：`textSecondaryColor`
  /// (`0x99000000`) 叠白就是它。这里早先用的是 `textTertiaryColor`
  /// （40% 黑 → `#999999`），彗星弧整条偏淡一档，与官方截图对不上。
  ///
  /// 传进来的颜色**自带 alpha 是有意义的**：彗星弧的弧头取它的 alpha，沿弧
  /// 递减到 0，不会被这里再乘一遍（见 [_CometPainter]）。
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
  /// 策略把**状态动效**压成了零时长。
  ///
  /// 第二件事用的是 [OhosVisualPolicy.statusMotion] 而不是 `scaleMotion`：
  /// 墨水屏把装饰动效全关了，但加载符号属于「不动就等于没在加载」的那类 ——
  /// 静止的彗星弧只有一个位置，读者分不清它是在转还是转完了。停掉之后的
  /// 兜底仍然保留（自定义策略可以继续压成零），那时画的是**静止的彗星弧**，
  /// 读者看到的至少是「一个加载符号」，而不是一块空白。
  void _syncAnimation() {
    final bool allowed =
        widget.enableLoading &&
        OhosTheme.of(context).policy.statusMotion(widget.duration) !=
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
    // 官方 API 11 起的默认色 `#ff666666` = 60% 黑，对应色板的次级文字色
    // （`0x99000000` 叠白正好是 `#666666`）。不硬写死色值：换主题时跟着走。
    final Color active = widget.color ?? theme.textSecondaryColor;
    // 与 _syncAnimation 同一条判据：加载是状态动效，墨水屏也要转
    final Duration scaled = theme.policy.statusMotion(widget.duration);
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

  /// 彗星弧沿弧长的 alpha 曲线：1 → 0，按 (1-t)² 衰减。
  ///
  /// 返回的 5 个色值对应弧长的 0 / 25% / 50% / 75% / 100%。每一档都是**乘在
  /// `base.a` 上**，不是直接替换 alpha —— 早先用 `withValues(alpha: 0.5625)`
  /// 覆盖，颜色自带 alpha（主题的次级色是 0.6）时第 2 档反而比弧头更亮，弧上
  /// 冒出一个「亮肩」、彗星头被削平，整条弧读起来就是一条淡灰带。
  ///
  /// 抽成公开静态方法是给用例看曲线用的：绘制走私有 painter，测试只能到这里
  /// 断言「弧头最亮、沿弧单调递减」。
  @visibleForTesting
  static List<Color> cometFadeColors(Color base) => <Color>[
    for (final double factor in _cometFadeFactors)
      base.withValues(alpha: base.a * factor),
  ];

  /// 弧长 0 / 25% / 50% / 75% / 100% 处的 alpha 系数。
  static const List<double> _cometFadeFactors = <double>[
    1,
    0.5625,
    0.25,
    0.0625,
    0,
  ];

  /// 铺进 `SweepGradient` 的色值（**按 stop 递增顺序**，即弧尾 → 弧头）。
  ///
  /// 方向很容易搞反，所以单独抽出来守：[drawArc] 的正角度与 `SweepGradient` 的
  /// stop 都沿**顺时针**增长，而弧是自己顺时针转的 —— 弧上角度越大的那一端
  /// 越靠前。因此 stop 0（startAngle 处）是**弧尾**，末位才是弧头。
  ///
  /// 早先按「stop 0 = 弧头」铺，真机上看到的是浅色尾巴在前面跑、深色脑袋
  /// 拖在后面，整个反了。末位多挂一格是给 `stop = 1` 用的：弧长之外保持弧头
  /// 色并不会露出（那里没有笔画），只是把渐变闭合掉。
  @visibleForTesting
  static List<Color> cometSweepColors(Color base) {
    final List<Color> headToTail = cometFadeColors(base);
    return <Color>[...headToTail.reversed, headToTail.first];
  }
}

/// 彗星形加载弧。
///
/// 一条弧 + `SweepGradient` 画完：沿弧长的 alpha 从**弧尾的 0** 连续升到
/// **弧头的颜色自带 alpha**。方向按「越靠前越亮」铺 —— 见
/// [OhosLoadingIndicatorMetrics.cometSweepColors]。
///
/// 早先用 24 段描边逐段改 alpha，两头的尺寸都不对：
/// - 大尺寸：每段落到 2 物理像素以上，24 级台阶肉眼可见，弧的前 1/3 全亮、
///   尾端骤降，读起来和 Material 的等宽弧几乎一样；
/// - 小尺寸：每段不到 1 物理像素，抗锯齿把台阶糊掉，12vp 只剩一个色的团块。
/// 渐变 shader 由 GPU 连续插值，与尺寸无关，也不会在段间留下抗锯齿缝。
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
  ///
  /// 取 0.6 是看着真机调出来的：官方点阵名义上只铺 57°，但它的尾巴一直保持
  /// 到 2.3% 的 alpha，画到 28vp 上是「一条明显的弧」；换算成单弧 + 平方衰减
  /// 后，0.3 那档在真机上只剩半条能看见，比系统加载圈细一圈。0.6 补回来的正是
  /// 淡到看不见的那一段。
  static const double _arcFraction = 0.6;

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
    final double startAngle = -math.pi / 2 + progress * 2 * math.pi;
    // alpha 走 (1-t)²：t = 0.25 / 0.5 / 0.75 时分别是 0.5625 / 0.25 / 0.0625，
    // 比线性衰减更接近彗尾的观感（线性会让尾巴显得「一半长」）。
    // 注意顺序是「尾 → 头」：弧顺时针转，stop 越大越靠前（见 cometSweepColors）。
    final SweepGradient gradient = SweepGradient(
      colors: OhosLoadingIndicatorMetrics.cometSweepColors(color),
      stops: <double>[
        0,
        _arcFraction * 0.25,
        _arcFraction * 0.5,
        _arcFraction * 0.75,
        _arcFraction,
        1,
      ],
      transform: GradientRotation(startAngle),
    );
    canvas.drawArc(
      rect,
      startAngle,
      _arcFraction * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        // alpha 必须置 1：Skia 会拿 paint 的 alpha 去调制 shader 输出，颜色
        // 自带 0.6 时整条弧再乘一遍就淡成了 #C7C7C7（实测峰值 alpha 只有
        // 0.22）。渐变里的 alpha 已经由 `cometFadeColors` 算好，这里只留色相。
        ..color = color.withValues(alpha: 1)
        ..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_CometPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
