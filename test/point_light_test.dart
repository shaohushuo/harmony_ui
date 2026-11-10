import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harmony_ui/harmony_ui.dart';

/// 点光源：光的落点必须由**光源的实际位置**决定。
///
/// ## 为什么需要这组用例
///
/// 这套效果早先的 API 要求调用方传 `lightAlignment`（「光从哪个方向来」），
/// 再据此在固定的一侧画光池与月牙。那是凭空猜的方向 —— 光源一挪，画出来的
/// 光与真实位置就脱钩了。官方（`hdsEffect.pointLight`）根本没有这个参数：
/// 光源是容器里的一个组件，位置对引擎来说是已知量。
///
/// 所以验收标准不是「画了点什么」，而是 **光源挪了，亮的地方跟着挪**。
void main() {
  setUp(() {
    resetResolvedLightCenters();
  });

  Widget wrap(Widget child, {OhosThemeData? theme}) {
    return OhosTheme(
      data: theme ?? OhosThemeData.light(),
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: child),
        ),
      ),
    );
  }

  /// 把受光面的 painter 真跑一遍，读出它解析到的光源位置。
  ///
  /// 走 `CustomPaint.painter.paint()` 而不是读 widget 字段：位置在**绘制时**
  /// 才求值（build 阶段 sibling 还没布局完），所以只有真跑一遍才能拿到。
  List<Offset> resolveCenters(WidgetTester tester, Size surface) {
    final Iterable<CustomPaint> paints = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(OhosIlluminated),
            matching: find.byType(CustomPaint),
          ),
        )
        .where(
          (CustomPaint w) =>
              w.painter != null &&
              w.painter.runtimeType.toString().startsWith('_'),
        );
    expect(paints, isNotEmpty, reason: 'OhosIlluminated 里没有找到自绘 painter');
    resetResolvedLightCenters();
    paints.first.painter!.paint(_NullCanvas(), surface);
    return lastResolvedLightCenters;
  }

  /// 光源在某个位置时，受光面解析到的光源中心。
  Future<Offset> centerWithSourceAt(
    WidgetTester tester,
    Alignment sourceAlignment,
  ) async {
    await tester.pumpWidget(
      wrap(
        OhosPointLightScope(
          child: SizedBox(
            width: 320,
            height: 200,
            child: Stack(
              children: <Widget>[
                Align(
                  alignment: sourceAlignment,
                  child: const OhosLightSource(
                    sourceType: OhosPointLightSourceType.none,
                    options: OhosPointLightOptions(intensity: 30),
                    child: SizedBox(width: 16, height: 16),
                  ),
                ),
                Center(
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: OhosIlluminated(
                      illuminatedType:
                          OhosPointLightIlluminatedType.borderContent,
                      borderRadius: BorderRadius.circular(16),
                      child: const ColoredBox(color: Color(0xFF202020)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final List<Offset> centers = resolveCenters(tester, const Size(120, 120));
    expect(centers, hasLength(1), reason: '应当解析到 1 个光源');
    return centers.first;
  }

  testWidgets('光源在右，解析出的光源中心落在受光面右侧；换到左侧则相反', (WidgetTester tester) async {
    // 这是核心。旧实现里受光面只认 `lightAlignment`，光源位置怎么变都不影响
    // 绘制 —— 那条老 API 里根本没有「解析出的位置」这个概念。
    final Offset right = await centerWithSourceAt(
      tester,
      Alignment.centerRight,
    );
    final Offset left = await centerWithSourceAt(tester, Alignment.centerLeft);

    // 受光面本地坐标系：0..120，中心 60。
    expect(right.dx, greaterThan(60), reason: '光源在右，中心应当落在右半');
    expect(left.dx, lessThan(60), reason: '光源在左，中心应当落在左半');
    expect(
      (right.dx - left.dx).abs(),
      greaterThan(100),
      reason: '光源从容器最右移到最左，受光面里的落点也必须跟着横跨整个面',
    );
    // 垂直方向两次都居中（光源与受光面同一水平线）。
    expect(right.dy, closeTo(60, 1));
    expect(left.dy, closeTo(60, 1));
  });

  testWidgets('光源在正上方时，落点在受光面上方', (WidgetTester tester) async {
    // 只验左右会漏掉「把 dy 写死成 center」的实现。
    final Offset top = await centerWithSourceAt(tester, Alignment.topCenter);
    expect(top.dy, lessThan(60));
    expect(top.dx, closeTo(60, 1));
  });

  testWidgets('离得越远，解析中心离受光面越远', (WidgetTester tester) async {
    Future<double> distanceAt(double gap) async {
      await tester.pumpWidget(
        wrap(
          OhosPointLightScope(
            child: SizedBox(
              width: 700,
              height: 160,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 420 + gap,
                    top: 70,
                    child: const OhosLightSource(
                      sourceType: OhosPointLightSourceType.none,
                      child: SizedBox(width: 16, height: 16),
                    ),
                  ),
                  const Positioned(
                    left: 20,
                    top: 20,
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: OhosIlluminated(
                        illuminatedType:
                            OhosPointLightIlluminatedType.borderContent,
                        child: ColoredBox(color: Color(0xFF202020)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final List<Offset> centers = resolveCenters(tester, const Size(120, 120));
      expect(centers, hasLength(1));
      // 距受光面中心（60, 60）的距离。
      return (centers.first - const Offset(60, 60)).distance;
    }

    final double near = await distanceAt(0);
    final double far = await distanceAt(300);
    expect(far, greaterThan(near), reason: '光源越远，落点也越远');
  });

  testWidgets('光源自己发光时才画 bloom，intensity = 0 完全不亮', (
    WidgetTester tester,
  ) async {
    Future<int> layers(double intensity) async {
      await tester.pumpWidget(
        wrap(
          OhosLightSource(
            options: OhosPointLightOptions(intensity: intensity),
            child: const ColoredBox(color: Color(0xFF3A4148)),
          ),
        ),
      );
      final Iterable<CustomPaint> paints = tester.widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(OhosLightSource),
          matching: find.byType(CustomPaint),
        ),
      );
      return paints.where((CustomPaint p) => p.painter != null).length;
    }

    // intensity = 0 是官方示例里「关灯」用的取值。
    expect(await layers(0), 0);
    expect(await layers(10), 1);
  });

  testWidgets('NONE 不挂任何绘制层', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 80,
          height: 80,
          child: OhosIlluminated(
            illuminatedType: OhosPointLightIlluminatedType.none,
            child: ColoredBox(color: Color(0xFF808080)),
          ),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(OhosIlluminated),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
      reason: 'NONE 不该挂任何绘制层',
    );
  });

  testWidgets('没有 scope 时受光面照常渲染，只是不画光', (WidgetTester tester) async {
    // 官方语义里光源与受光面必然在同一个父容器。漏了 scope 是用法错误，
    // 但**不能因此崩掉**：宁可少一层光，也不能让整块页面红屏。
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 80,
          height: 80,
          child: OhosIlluminated(
            illuminatedType: OhosPointLightIlluminatedType.borderContent,
            child: ColoredBox(color: Color(0xFF808080)),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(ColoredBox), findsWidgets);
  });

  testWidgets('墨屏（allowsGlow = false）不画光，但内容还在', (WidgetTester tester) async {
    // 灰阶屏上没有「光」这个隐喻：白晕叠上去只是一块浅灰，压在纯黑底上像
    // 蒙了一层雾。这条与 OhosLightMaterial / OhosPressShadow 同一条判据。
    await tester.pumpWidget(
      wrap(
        OhosPointLightScope(
          child: SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              children: <Widget>[
                const Align(
                  alignment: Alignment.topCenter,
                  child: OhosLightSource(
                    child: SizedBox(width: 20, height: 20),
                  ),
                ),
                Center(
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: OhosIlluminated(
                      illuminatedType:
                          OhosPointLightIlluminatedType.borderContent,
                      child: const ColoredBox(color: Color(0xFF808080)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        theme: OhosThemeData.ink(),
      ),
    );

    expect(OhosThemeData.ink().policy.allowsGlow, isFalse);
    final Iterable<CustomPaint> paints = tester.widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(OhosIlluminated),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(paints.where((CustomPaint p) => p.painter != null), isEmpty);
    // 内容仍在。
    expect(find.byType(ColoredBox), findsWidgets);
  });

  testWidgets('单个受光面最多解析 12 个光源（官方约束）', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        OhosPointLightScope(
          child: SizedBox(
            width: 400,
            height: 400,
            child: Stack(
              children: <Widget>[
                for (int i = 0; i < 15; i++)
                  Positioned(
                    left: 10.0 + i * 25,
                    top: 178,
                    child: const OhosLightSource(
                      sourceType: OhosPointLightSourceType.none,
                      options: OhosPointLightOptions(intensity: 30),
                      child: SizedBox(width: 12, height: 12),
                    ),
                  ),
                const Center(
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: OhosIlluminated(
                      illuminatedType: OhosPointLightIlluminatedType.content,
                      child: ColoredBox(color: Color(0xFF202020)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 15 个光源进注册表，受光面只解析前 12 个。
    final List<Offset> centers = resolveCenters(tester, const Size(80, 80));
    expect(centers, hasLength(12));
    expect(ohosPointLightMaxSources, 12);
  });
}

/// 什么都不画的画布：只为了让 `paint()` 跑到解析光源那一步。
class _NullCanvas implements Canvas {
  @override
  void noSuchMethod(Invocation invocation) {}
}
