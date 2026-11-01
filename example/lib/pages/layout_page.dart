import 'package:flutter/material.dart';
import 'package:ohos_icons/ohos_icons.dart';
import 'package:harmony_ui/harmony_ui.dart';

import 'demo_scaffold.dart';

/// 布局与动效：栅格 / 响应式断点 / 沉浸光感 / 转场动效
class LayoutPage extends StatelessWidget {
  const LayoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: '布局与动效',
      children: const <Widget>[
        DemoSection(
          title: '栅格系统 OhosGrid',
          description: '4/8/12 列随断点切换，margin 16/24/32vp，gutter 8/12/16vp。',
          child: _GridDemo(),
        ),
        DemoSection(
          title: '响应式断点 OhosResponsiveBuilder',
          description:
              'compact(<600) 单列 / medium(600-840) 双列 / large(>=840) 四分栏。',
          child: _ResponsiveDemo(),
        ),
        DemoSection(
          title: '沉浸光感 OhosLightMaterial',
          description: '背景模糊 + 光池 + 边缘高光；顶部 ULTRA_THIN 渐变模糊、'
              '底部 THIN、弹层 THICK（含光感漫射）。',
          child: _LightDemo(),
        ),
        DemoSection(
          title: '转场动效 一镜到底',
          description: '共享元素：点击卡片后放大转场，使用 OhosGeometry.sharedElement 曲线。',
          child: _SharedElementDemo(),
        ),
        DemoSection(
          title: '动效曲线对比',
          description: '同一 AnimatedContainer 使用不同曲线与时长（90/200/300/400ms）。',
          child: _MotionCurveDemo(),
        ),
      ],
    );
  }
}

class _GridDemo extends StatelessWidget {
  const _GridDemo();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // 彩色屏的两级填充（浅灰 #F1F3F5 / 10% 品牌蓝）压到 16 级灰阶上都会落成
    // 白色，单元整块看不见。墨屏保留同样的形式（实心圆角块 + 两级交替），只把
    // 颜色换成灰阶里读得出来的两档；取值都是 17 的倍数，正好落在灰阶格子上。
    //
    // 填充是固定的浅 / 中灰，文字也就固定深色（`textPrimaryLight`），不跟
    // `theme.textPrimaryColor` 走 —— 深色主题下那个值接近纯白，压在这种浅底上
    // 对比度不到 1.2:1，格子里的数字会整片消失。
    final List<Color> fills = theme.monochrome
        ? const <Color>[Color(0xFFDDDDDD), Color(0xFFBBBBBB)]
        : const <Color>[
            OhosColors.compBackgroundGray,
            OhosColors.emphasizeTertiary,
          ];
    return OhosGrid(
      children: <Widget>[
        for (int i = 0; i < 8; i++)
          OhosGridItem(
            columnSpan: 2,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: fills[i % fills.length],
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '${i + 1}',
                style: const TextStyle(color: OhosColors.textPrimaryLight),
              ),
            ),
          ),
      ],
    );
  }
}

class _ResponsiveDemo extends StatelessWidget {
  const _ResponsiveDemo();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // 墨屏：底板与单元都换成灰阶填充，形式仍是「浅色底板 + 三级实心单元」，
    // 只是彩屏那套浅灰 / 半透明蓝在 16 级灰阶上等于白色。
    final Color panel = theme.monochrome
        ? const Color(0xFFEEEEEE)
        : OhosColors.compBackgroundGray;
    const List<Color> inkCells = <Color>[
      Color(0xFFCCCCCC),
      Color(0xFFBBBBBB),
      Color(0xFFAAAAAA),
    ];
    return OhosResponsiveBuilder(
      builder: (BuildContext context, OhosWindowSize size) {
        final int columns = size.columns;
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 用 Wrap 而不是 Row：窄屏 + 大字号时两段文字会超过一行宽度。
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    '${size.type.name} · ${size.width.round()}vp',
                    style: const TextStyle(
                      color: OhosColors.textPrimaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$columns 列',
                    style: TextStyle(color: theme.textSecondaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final int perRow = size.isLarge
                      ? 4
                      : size.isMedium
                      ? 2
                      : 1;
                  final double cell =
                      (constraints.maxWidth - 8 * (perRow - 1)) / perRow;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (int i = 0; i < 8; i++)
                        Container(
                          width: cell,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.monochrome
                                ? inkCells[i % inkCells.length]
                                : const Color(
                                    0xFF0A59F7,
                                  ).withValues(alpha: 0.08 + (i % 3) * 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '内容',
                            style: const TextStyle(
                              color: OhosColors.textPrimaryLight,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LightDemo extends StatelessWidget {
  const _LightDemo();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Column(
      children: <Widget>[
        Stack(
          children: <Widget>[
            Container(
              height: 150,
              decoration: BoxDecoration(
                // 墨屏没有中间调：粉紫蓝渐变压下来是一段没有意义的灰带，
                // 直接用一档深灰当「背景」，THIN 退化成纯白后仍然立得住。
                color: theme.monochrome ? const Color(0xFF333333) : null,
                gradient: theme.monochrome
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xFFE55392),
                          Color(0xFFA12DF7),
                          Color(0xFF4B48F7),
                        ],
                      ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: OhosLightMaterial(
                level: OhosLightMaterialLevel.thin,
                gradientFade: OhosLightFade.bottom,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const <Widget>[
                      Icon(OhosIcons.music_fill, size: 22),
                      SizedBox(width: 8),
                      // 320vp + 1.3x 字号下这行标题会超出，允许收缩
                      Flexible(
                        child: Text(
                          '底部悬浮 · THIN 材质',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 墨屏下 THICK 退化成一块纯白，与页面底色相同 —— 库的约定是「边界交给
        // 调用方自己的 1px 线」，这里补上，否则演示只剩一行没有载体的文字。
        //
        // 必须用 `foregroundDecoration`：那块白底不透明，画在 `decoration` 里的
        // 线会被同一个矩形的子节点整块盖住，真机上仍然看不到边界。
        Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: theme.monochrome
                ? Border.all(color: theme.dividerColor)
                : null,
          ),
          child: OhosLightMaterial(
            level: OhosLightMaterialLevel.thick,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            effectTuning: const OhosLightEffectTuning(scatterScale: 0.6),
            child: SizedBox(
              height: 72,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(OhosIcons.plus, color: theme.highlightColor),
                  const SizedBox(width: 8),
                  // 320vp 下这行标题会超出，允许它收缩换行
                  const Flexible(
                    child: Text(
                      '任意位置弹层 · THICK + 漫射',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SharedElementDemo extends StatefulWidget {
  const _SharedElementDemo();

  @override
  State<_SharedElementDemo> createState() => _SharedElementDemoState();
}

class _SharedElementDemoState extends State<_SharedElementDemo> {
  static const List<(int, Color, String)> _cards = <(int, Color, String)>[
    (0, Color(0xFF0A59F7), '共享元素'),
    (1, Color(0xFF64BB5C), '共享容器'),
    (2, Color(0xFFED6F21), '共享动势'),
  ];

  /// 墨屏的三档填充：这三个彩色压到 16 级灰阶后都是中灰，而标签是白字 ——
  /// 绿 / 橙两张卡会糊成一片，字基本读不出来。换成深灰阶（第 1/3/5 级），
  /// 白字对比度仍在 7:1 以上，形式与彩屏一致（实心圆角块 + 白字）。
  static const List<Color> _inkCards = <Color>[
    Color(0xFF111111),
    Color(0xFF333333),
    Color(0xFF555555),
  ];

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return SizedBox(
      height: 96,
      child: Row(
        children: <Widget>[
          for (final (int index, _, String label) in _cards)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Hero(
                  tag: 'shared-card-$index',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _open(context, index, _fill(theme, index)),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 96,
                        decoration: BoxDecoration(
                          color: _fill(theme, index),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _fill(OhosThemeData theme, int index) =>
      theme.monochrome ? _inkCards[index] : _cards[index].$2;

  /// Pushes a full-screen page with the same [Hero] tag, so Flutter morphs
  /// the small card into the large one (一镜到底) with the shared-element
  /// curve instead of an instant tree swap.
  void _open(BuildContext context, int index, Color color) {
    final String label = _cards[index].$3;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: OhosGeometry.durationLong,
        reverseTransitionDuration: OhosGeometry.durationMedium,
        pageBuilder:
            (BuildContext context, Animation<double> animation,
                Animation<double> secondaryAnimation) =>
                _SharedCardPage(
                  index: index,
                  color: color,
                  label: label,
                ),
        transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: OhosGeometry.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class _SharedCardPage extends StatelessWidget {
  const _SharedCardPage({
    required this.index,
    required this.color,
    required this.label,
  });

  final int index;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Scaffold(
      // 墨屏：35% 黑遮罩压成浅灰，深灰卡片仍立得住；彩屏保持原来的半透明黑。
      backgroundColor: theme.monochrome
          ? const Color(0xFFDDDDDD)
          : Colors.black.withValues(alpha: 0.35),
      body: Center(
        child: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Hero(
            tag: 'shared-card-$index',
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 260,
                height: 160,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(24),
                  // 阴影在白底上本来就看不见，墨屏更是一层噪点
                  boxShadow: theme.monochrome
                      ? null
                      : const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      OhosIcons.arrow_left,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '返回 · $label',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MotionCurveDemo extends StatefulWidget {
  const _MotionCurveDemo();

  @override
  State<_MotionCurveDemo> createState() => _MotionCurveDemoState();
}

class _MotionCurveDemoState extends State<_MotionCurveDemo> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final List<(Curve, Duration, String)> rows = <(Curve, Duration, String)>[
      (OhosGeometry.spring, OhosGeometry.durationPress, '按下反馈 · spring 90ms'),
      (
        OhosGeometry.easeOut,
        OhosGeometry.durationShort,
        '普通转场 · easeOut 200ms',
      ),
      (OhosGeometry.sharedElement, OhosGeometry.durationMedium, '共享转场 · 300ms'),
      (Curves.easeInOut, OhosGeometry.durationLong, '页面转场 · 400ms'),
    ];
    return Column(
      children: <Widget>[
        GestureDetector(
          onTap: () => setState(() => _pressed = !_pressed),
          child: Container(
            width: double.infinity,
            height: 96,
            decoration: BoxDecoration(
              // 灰底在墨屏上等于白纸，跑道整块消失；换一档读得出来的浅灰。
              color: theme.monochrome
                  ? const Color(0xFFEEEEEE)
                  : OhosColors.compBackgroundGray,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: <Widget>[
                AnimatedPositioned(
                  duration: OhosGeometry.durationMedium,
                  curve: OhosGeometry.easeOut,
                  top: _pressed ? 16 : 36,
                  left: _pressed ? 16 : 60,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.highlightColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Text(
                    '点击切换 · 位移+缩放（共享动势）',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textSecondaryColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final (Curve curve, Duration duration, String label) in rows)
          _curveBar(theme, curve, duration, label),
      ],
    );
  }

  Widget _curveBar(
    OhosThemeData theme,
    Curve curve,
    Duration duration,
    String label,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: _pressed ? duration : OhosGeometry.durationShort,
        builder: (BuildContext context, double value, Widget? child) {
          final double eased = _pressed
              ? curve.transform(value)
              : const Cubic(0.4, 0, 0.2, 1).transform(value);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: theme.textSecondaryColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: theme.monochrome
                      ? const Color(0xFFEEEEEE)
                      : OhosColors.compBackgroundGray,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _pressed ? eased : 0.3,
                  child: Container(
                    decoration: BoxDecoration(
                      // 55% 品牌蓝压到灰阶上是中灰，仍读得出来；留着反而与
                      // 彩屏版本对照最直观，所以只把轨道换成浅灰。
                      color: const Color(0xFF0A59F7).withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
