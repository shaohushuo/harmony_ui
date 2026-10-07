import 'package:flutter/material.dart';
import 'package:ohos_icons/ohos_icons.dart';
import 'package:ohos_ui_kit/ohos_ui_kit.dart';

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
          description: 'ULTRA_THIN 顶部悬浮 + 渐变模糊，THIN 底部悬浮，THICK 弹层。',
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
    return OhosGrid(
      children: <Widget>[
        for (int i = 0; i < 8; i++)
          OhosGridItem(
            columnSpan: 2,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: i.isEven
                    ? OhosColors.compBackgroundGray
                    : OhosColors.emphasizeTertiary,
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
    return OhosResponsiveBuilder(
      builder: (BuildContext context, OhosWindowSize size) {
        final int columns = size.columns;
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: OhosColors.compBackgroundGray,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    '${size.type.name} · ${size.width.round()}vp',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$columns 列',
                    style: const TextStyle(
                      color: OhosColors.textSecondaryLight,
                    ),
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
                            color: const Color(
                              0xFF0A59F7,
                            ).withValues(alpha: 0.08 + (i % 3) * 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '内容',
                            style: TextStyle(
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
    return Column(
      children: <Widget>[
        Stack(
          children: <Widget>[
            Container(
              height: 150,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
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
            const Positioned(
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
                    children: <Widget>[
                      Icon(OhosIcons.music_fill, size: 22),
                      SizedBox(width: 8),
                      Text('底部悬浮 · THIN 材质'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const OhosLightMaterial(
          level: OhosLightMaterialLevel.thick,
          borderRadius: BorderRadius.all(Radius.circular(16)),
          child: SizedBox(
            height: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(OhosIcons.plus, color: OhosColors.highlight),
                SizedBox(width: 8),
                Text('任意位置弹层 · THICK 材质'),
              ],
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
  int? _opened;

  @override
  Widget build(BuildContext context) {
    final List<(int, Color, String)> cards = <(int, Color, String)>[
      (0, const Color(0xFF0A59F7), '共享元素'),
      (1, const Color(0xFF64BB5C), '共享容器'),
      (2, const Color(0xFFED6F21), '共享动势'),
    ];
    if (_opened != null) {
      final (int index, Color color, String label) = cards[_opened!];
      return Center(
        child: GestureDetector(
          onTap: () => setState(() => _opened = null),
          child: AnimatedContainer(
            duration: OhosGeometry.durationLong,
            curve: OhosGeometry.sharedElement,
            width: 260,
            height: 160,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const <BoxShadow>[
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
                Icon(OhosIcons.arrow_left, color: Colors.white, size: 28),
                const SizedBox(height: 8),
                Text(
                  '返回 · $label',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Row(
      children: <Widget>[
        for (final (int index, Color color, String label) in cards)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => setState(() => _opened = index),
                child: AnimatedContainer(
                  duration: OhosGeometry.durationShort,
                  curve: OhosGeometry.easeOut,
                  height: 96,
                  decoration: BoxDecoration(
                    color: color,
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
      ],
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
              color: OhosColors.compBackgroundGray,
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
                    decoration: const BoxDecoration(
                      color: OhosColors.highlight,
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
                    style: const TextStyle(
                      color: OhosColors.textSecondaryLight,
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
          _curveBar(curve, duration, label),
      ],
    );
  }

  Widget _curveBar(Curve curve, Duration duration, String label) {
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
                style: const TextStyle(
                  color: OhosColors.textSecondaryLight,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: OhosColors.compBackgroundGray,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _pressed ? eased : 0.3,
                  child: Container(
                    decoration: BoxDecoration(
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
