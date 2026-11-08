import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harmony_ui/harmony_ui.dart';

/// 一个**仓库里不存在**的第四种主题：高对比模式。
///
/// 全部定义都写在这个测试文件里 —— 不碰 `lib/` 的任何一行源码。如果扩展性
/// 成立，那么「加一种屏幕」的成本就是这份策略 + 一份色值，组件层零改动。
///
/// 它的规则和已有的两种都不同：
/// - 不是灰阶（[isMonochrome] 为 false），但也不靠分层 —— 它靠 2px 粗线；
/// - 保留阴影（高对比需要更强的边界），但关掉模糊（模糊会糊掉边缘）；
/// - 所有填充都提到 30% 以上，因为 20% 的底在低对比面板上同样会消失。
class HighContrastPolicy extends OhosVisualPolicy {
  const HighContrastPolicy();

  @override
  bool get isMonochrome => false;

  @override
  Color tint(Color base, double alpha) {
    // 不管调用方要多少，最低给 0.30：这块屏的诉求就是把形体顶出来。
    final double boosted = alpha < 0.30 ? 0.30 : alpha;
    return base.withValues(alpha: boosted);
  }

  @override
  Color line(Color base, double alpha) => base;

  @override
  Color quantize(Color color) => color;

  @override
  double? get outlineWidth => 2;

  @override
  bool get allowsShadow => true;

  @override
  bool get allowsBlur => false;

  @override
  bool get allowsRipple => true;

  @override
  Duration scaleMotion(Duration base) => base;

  @override
  Color disabledFill(Color base) => base.withValues(alpha: 0.30);

  @override
  bool operator ==(Object other) => other is HighContrastPolicy;

  @override
  int get hashCode => (HighContrastPolicy).hashCode;
}

OhosThemeData highContrastTheme() => OhosThemeData.light().copyWith(
  policy: const HighContrastPolicy(),
  id: 'high_contrast',
  // 高对比要的是更黑的字、更硬的分隔线，其余沿用浅色令牌。
  textPrimaryColor: const Color(0xFF000000),
  dividerColor: const Color(0xFF000000),
);

/// 一套最小的 widget 样机，覆盖会读 policy 的几个关键组件。
Widget probe(OhosThemeData theme) => OhosTheme(
  data: theme,
  child: MaterialApp(
    home: OhosScaffold(
      appBar: OhosAppBar(title: const Text('探针')),
      body: Column(
        children: <Widget>[
          OhosButton(onPressed: () {}, child: const Text('主按钮')),
          OhosButton(onPressed: null, child: const Text('禁用按钮')),
          const OhosCard(child: Text('卡片')),
          OhosSwitch(value: true, onChanged: (_) {}),
          OhosSlider(value: 30, onChanged: (_) {}),
        ],
      ),
    ),
  ),
);

void main() {
  group('新增主题不需要改 widget', () {
    testWidgets('一份自定义策略就能驱动全部组件，且能正常渲染', (WidgetTester tester) async {
      await tester.pumpWidget(probe(highContrastTheme()));
      await tester.pumpAndSettle();

      // 组件没有因为「不认识这个主题」而崩溃或退化
      expect(find.text('主按钮'), findsOneWidget);
      expect(find.text('卡片'), findsOneWidget);

      // 组件确实在用新策略：描边宽度变成 2（已有的两种是 null 与 1）
      final OhosThemeData applied = OhosTheme.of(
        tester.element(find.text('主按钮')),
      );
      expect(applied.usesOutlines, isTrue);
      expect(applied.outlineWidth, 2);
      expect(applied.policy, const HighContrastPolicy());
    });

    testWidgets('新策略的 tint 提升生效 —— 填充不再走原 alpha', (WidgetTester tester) async {
      await tester.pumpWidget(probe(highContrastTheme()));
      await tester.pumpAndSettle();

      const OhosVisualPolicy policy = HighContrastPolicy();
      // 调用方要 12%，这块屏给 30%
      expect(
        policy.tint(const Color(0xFF000000), 0.12).a,
        closeTo(0.30, 0.005),
      );
      // 要 60% 就还是 60%，只抬地板不压天花板
      expect(
        policy.tint(const Color(0xFF000000), 0.60).a,
        closeTo(0.60, 0.005),
      );
    });

    testWidgets('第四种主题能和已有三种一起被切换，不需要改 controller', (
      WidgetTester tester,
    ) async {
      final OhosThemeController controller = OhosThemeController.custom(
        highContrastTheme(),
      );

      await tester.pumpWidget(
        OhosThemeSwitcher(
          controller: controller,
          builder: (BuildContext context, ThemeData material) =>
              MaterialApp(theme: material, home: const SizedBox()),
        ),
      );

      expect(controller.themeData.id, 'high_contrast');

      // 从自定义主题切到墨水屏
      controller.toggle();
      expect(controller.isInk, isTrue);
      expect(controller.themeData.id, 'ink');

      // 再切回来，回到的是那份自定义主题，而不是内置浅色
      controller.toggle();
      expect(controller.isInk, isFalse);
      expect(controller.themeData.id, 'high_contrast');
      expect(controller.themeData.policy, const HighContrastPolicy());
    });

    testWidgets('自定义主题下切换按钮仍可用，不因没有档位而崩', (WidgetTester tester) async {
      final OhosThemeController controller = OhosThemeController.custom(
        highContrastTheme(),
      );

      await tester.pumpWidget(
        OhosThemeSwitcher(
          controller: controller,
          builder: (BuildContext context, ThemeData material) => MaterialApp(
            theme: material,
            home: OhosScaffold(
              appBar: OhosAppBar(
                title: const Text('页'),
                actions: <Widget>[
                  OhosThemeToggleButton(controller: controller),
                ],
              ),
              body: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 没有档位，图标按策略兜底（有描边 → 对比度图标），不抛异常
      expect(find.byIcon(Icons.contrast_rounded), findsOneWidget);

      // 点按仍然能切到墨水屏并切回来
      await tester.tap(find.byIcon(Icons.contrast_rounded));
      await tester.pumpAndSettle();
      expect(controller.isInk, isTrue);

      await tester.tap(find.byIcon(Icons.contrast_rounded));
      await tester.pumpAndSettle();
      expect(controller.themeData.id, 'high_contrast');
    });
  });

  group('主题值的相等性（决定要不要重建）', () {
    test('字段完全相同的两份主题相等', () {
      expect(OhosThemeData.light(), OhosThemeData.light());
      expect(OhosThemeData.light().hashCode, OhosThemeData.light().hashCode);
    });

    test('只改一个字段就不相等', () {
      final OhosThemeData base = OhosThemeData.light();
      expect(base == base.copyWith(), isTrue);
      expect(
        base == base.copyWith(textPrimaryColor: const Color(0xFF010101)),
        isFalse,
      );
    });

    test('换策略算不同主题', () {
      expect(
        OhosThemeData.light() ==
            OhosThemeData.light().copyWith(policy: const InkVisualPolicy()),
        isFalse,
      );
    });

    test('同纸色的墨水屏策略相等，换纸色就不相等', () {
      expect(const InkVisualPolicy(), const InkVisualPolicy());
      expect(
        const InkVisualPolicy() ==
            const InkVisualPolicy(paper: Color(0xFF202020)),
        isFalse,
      );
    });

    test('传同一份主题不会触发重建', () {
      final OhosThemeController controller = OhosThemeController();
      int notifications = 0;
      controller.addListener(() => notifications++);

      // 初始是 light。传一份字段完全相同的**新实例**：不该通知。
      controller.useTheme(OhosThemeData.light());
      expect(notifications, 0, reason: '值相等就不该通知');

      // 真的换成墨水屏：通知一次。
      controller.useTheme(OhosThemeData.ink());
      expect(notifications, 1);

      // 再传一份相同的墨屏：不该再通知。
      controller.useTheme(OhosThemeData.ink());
      expect(notifications, 1, reason: '重复设置同一主题是空操作');
    });
  });

  group('深色墨水屏（纸色可配）', () {
    test('量化以自定义纸色为底，不再写死纯白', () {
      const InkVisualPolicy white = InkVisualPolicy();
      const InkVisualPolicy dark = InkVisualPolicy(paper: Color(0xFF202020));

      // 50% 的黑压在白纸上应该是中灰，压在深色纸上应该明显更黑
      final Color onWhite = white.quantize(const Color(0x80000000));
      final Color onDark = dark.quantize(const Color(0x80000000));

      expect(
        onDark.computeLuminance(),
        lessThan(onWhite.computeLuminance()),
        reason: '深色纸上的同一层黑必须更黑',
      );
      // 白纸上 50% 黑 ≈ #808080，深色纸上 ≈ #101010
      expect(onWhite.computeLuminance(), greaterThan(0.2));
      expect(onDark.computeLuminance(), lessThan(0.02));

      // 纸色只影响合成，不影响「必须是不透明的灰」这条铁律
      expect((onDark.a * 255).round(), 255);
      expect((onDark.r * 255).round(), (onDark.g * 255).round());
    });

    test('深色墨水屏主题可以纯靠 copyWith 拼出来', () {
      final OhosThemeData theme = OhosThemeData.ink().copyWith(
        policy: const InkVisualPolicy(paper: Color(0xFF202020)),
        id: 'ink_dark',
      );
      expect(theme.usesOutlines, isTrue);
      expect(theme.outlineWidth, 1);
      expect(theme.id, 'ink_dark');
    });
  });

  // 「自定义主题」与「墨水屏策略」是两个正交维度：前者回答「什么颜色」，
  // 后者回答「在这块屏上怎么写」。组合起来必须同时成立 —— 品牌色 + 灰阶
  // 表现规则，是真实存在的需求（企业定制电子纸阅读器）。
  group('自定义主题 × 墨水屏策略', () {
    /// 品牌色 + 灰阶：色值自己给，表现规则用 InkVisualPolicy。
    OhosThemeData brandInk() => OhosThemeData.light().copyWith(
      id: 'brand_ink',
      policy: const InkVisualPolicy(),
      highlightColor: OhosColors.inkForeground,
      backgroundColor: OhosColors.inkBackground,
      cardColor: OhosColors.inkBackground,
      popupColor: OhosColors.inkBackground,
      textPrimaryColor: OhosColors.inkForeground,
      textTertiaryColor: const Color(0xFF767676),
      dividerColor: OhosColors.inkForeground,
      typography: OhosTypography.monochrome(),
    );

    test('两维各自成立：不是内置 id，但是灰阶', () {
      final OhosThemeData theme = brandInk();
      expect(theme.id, 'brand_ink');
      expect(theme.monochrome, isTrue);
      expect(theme.usesOutlines, isTrue);
      // 自定义主题的亮度由自己声明，不受 policy 影响
      expect(theme.isDark, isFalse);
    });

    test('custom() 构造的控制器能识别它是墨水屏', () {
      final OhosThemeController controller = OhosThemeController.custom(
        brandInk(),
      );
      expect(controller.mode, isNull, reason: '自定义主题没有档位');
      expect(
        controller.isInk,
        isTrue,
        reason: 'isInk 读的是 policy，不是枚举 —— 自定义灰阶主题同样为 true',
      );
    });

    test('从品牌墨水屏 toggle 出来，落到彩屏而不是原地空转', () {
      final OhosThemeController controller = OhosThemeController.custom(
        brandInk(),
      );
      // 已经在墨屏，toggle 应该切到「普通」侧 —— 也就是彩屏
      controller.toggle();
      expect(
        controller.isInk,
        isFalse,
        reason:
            '若把这份墨屏主题自己当作「普通」侧，toggle 会切到墨屏上，'
            '按钮看起来完全失灵',
      );
      expect(controller.themeData.monochrome, isFalse);
    });

    test('品牌彩屏 → 墨水屏 → 回来，品牌色没丢', () {
      final OhosThemeData brandColor = OhosThemeData.light().copyWith(
        id: 'brand',
        highlightColor: const Color(0xFF7B3FF2),
      );
      final OhosThemeController controller = OhosThemeController.custom(
        brandColor,
      );

      controller.toggle();
      expect(controller.isInk, isTrue);
      expect(controller.themeData.id, 'ink', reason: 'toggle 进的是内置墨屏');

      controller.toggle();
      expect(controller.themeData.id, 'brand');
      expect(controller.themeData.highlightColor, const Color(0xFF7B3FF2));
    });

    testWidgets('自定义墨屏主题能驱动组件，走的是策略而非枚举', (WidgetTester tester) async {
      final OhosThemeData theme = brandInk();
      await tester.pumpWidget(
        OhosTheme(
          data: theme,
          child: MaterialApp(
            home: OhosScaffold(
              appBar: OhosAppBar(title: const Text('品牌墨屏')),
              body: Column(
                children: <Widget>[
                  OhosButton(onPressed: () {}, child: const Text('按钮')),
                  const OhosCard(child: Text('卡片')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final OhosThemeData applied = OhosTheme.of(
        tester.element(find.text('按钮')),
      );
      expect(applied.policy, const InkVisualPolicy());
      expect(applied.usesOutlines, isTrue);
      expect(tester.takeException(), isNull);
    });

    // 高对比主题自己声明了 allowsBlur = false 但没声明 allowsGlow —— 那是个
    // 有效的自定义策略，不该因为库里多了一个能力声明就编译失败或行为突变。
    test('老的自定义策略不覆写 allowsGlow 时默认保留光效', () {
      const OhosVisualPolicy policy = HighContrastPolicy();
      expect(policy.allowsGlow, isTrue, reason: '基类给默认 true，外部已有策略无需改动');
    });
  });
}
