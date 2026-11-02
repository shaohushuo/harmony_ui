import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harmony_ui/harmony_ui.dart';

/// WCAG 相对亮度：**不做** sRGB 线性化。
///
/// 用直接加权而不是 `computeLuminance()`：那个会做线性化，把 `#CCCCCC` 算成
/// 0.60 而不是 0.80，用它算对比度会整体偏乐观。这里要做的是「同一块面板上
/// 两个色差了多远」的粗判，直接加权更贴近 16 级灰的观感。
double _lum(Color c) => c.r * 0.299 + c.g * 0.587 + c.b * 0.114;

double _contrast(Color fg, Color bg) {
  final double a = _lum(fg);
  final double b = _lum(bg);
  final double hi = a > b ? a : b;
  final double lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // 深色墨水屏是这次改造的**真正目标**：`brightness` 语义拆开之前，
  // `OhosThemeData.ink()` 恒为 light，`isDark` 恒假，做不出深底浅字的电子纸。
  // 这一组守的是「拆开之后真的能用」，不是「多了一个枚举值」。
  group('深色墨水屏', () {
    final OhosThemeData darkInk = OhosThemeData.ink(
      brightness: Brightness.dark,
    );

    test('两个语义维各自成立：是深色令牌，同时是灰阶策略', () {
      // 拆开之前这两条只能同时为 false —— 那正是「深色墨水屏」做不出来的原因
      expect(darkInk.isDark, isTrue, reason: '令牌是深底浅字');
      expect(darkInk.monochrome, isTrue, reason: '策略是灰阶屏');
      expect(darkInk.usesOutlines, isTrue);
      expect(darkInk.outlineWidth, 1);
    });

    test('白纸墨水屏仍是不折不扣的浅色主题，没被顺手改成深色', () {
      final OhosThemeData whiteInk = OhosThemeData.ink();
      expect(whiteInk.isDark, isFalse);
      expect(whiteInk.monochrome, isTrue);
    });

    test('策略的纸色跟着翻，量化不会偏向白纸那一侧', () {
      final InkVisualPolicy policy = darkInk.policy as InkVisualPolicy;
      expect(policy.paper, OhosColors.inkBackgroundDark);
      expect(policy.paper.computeLuminance(), lessThan(0.05));

      // 同一层 50% 黑：白纸上合成成中灰，深色纸上必须几乎不可见
      final Color onWhite = const InkVisualPolicy().quantize(
        const Color(0x80000000),
      );
      final Color onDark = policy.quantize(const Color(0x80000000));
      expect(_lum(onDark), lessThan(_lum(onWhite)));
    });

    test('正文对比度达标：白字压深色纸', () {
      final double ratio = _contrast(
        darkInk.textPrimaryColor,
        darkInk.backgroundColor,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: '深色纸上正文对比度只有 $ratio —— 这是「能不能看」的下限',
      );
    });

    test('三级文字仍读得出，且不抢正文层级', () {
      final double tert = _contrast(
        darkInk.textTertiaryColor,
        darkInk.backgroundColor,
      );
      final double primary = _contrast(
        darkInk.textPrimaryColor,
        darkInk.backgroundColor,
      );
      // 4.5 是「正文」的标准；三级文字是明确弱化的层级，按 3.0（大字号 /
      // 非关键文本的下限）要求，再断言它确实低于正文。
      expect(tert, greaterThanOrEqualTo(3.0), reason: '约 $tert');
      expect(tert, lessThan(primary), reason: '三级文字不能比正文还亮');
    });

    // 这是最容易漏的一处：`ink()` 换色值时如果只换 color 字段、没换
    // `typography`，字阶仍是 `OhosTypography.monochrome()` 的纯黑 ——
    // 于是「黑字压 #1A1A1A 纸」，对比度 1.1:1，正文整段消失。
    // AppBar 标题、裸 OhosText 这些不自己 copyWith 颜色的地方全中招。
    test('字阶跟着翻到纯白 —— 漏掉它就是黑字压黑纸', () {
      final Color? scaleColor = darkInk.typography.bodyLarge?.color;
      expect(scaleColor, OhosTypography.textPrimaryMonochromeDark);
      expect(scaleColor, const Color(0xFFFFFFFF));

      final double ratio = _contrast(scaleColor!, darkInk.backgroundColor);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: '字阶色 $scaleColor 压在 ${darkInk.backgroundColor} 上只有 $ratio',
      );
    });

    test('白纸侧字阶仍是纯黑，没被反向污染', () {
      expect(
        OhosThemeData.ink().typography.bodyLarge?.color,
        OhosTypography.textPrimaryMonochrome,
      );
    });

    // 禁用态「比纸亮」比「看不见」更糟：读者会去点它。
    test('禁用灰比纸面亮、比正文暗，不会让人以为它可用', () {
      final InkVisualPolicy policy = darkInk.policy as InkVisualPolicy;
      final Color disabled = policy.disabledFill(darkInk.textTertiaryColor);

      expect(
        _lum(disabled),
        greaterThan(_lum(darkInk.backgroundColor)),
        reason: '比纸还暗就等于不存在，和「禁用"整块消失"是同一个失败',
      );
      expect(
        _lum(disabled),
        lessThan(_lum(darkInk.textPrimaryColor)),
        reason: '和正文一样亮会让禁用态看起来可用',
      );
    });

    // litFill 的两端必须跟着纸色走，否则「已选中」比「未选中」还淡。
    test('点亮态取纯白（纸面的反面），语义方向没有反转', () {
      final InkVisualPolicy policy = darkInk.policy as InkVisualPolicy;
      final Color lit = policy.litFill(const Color(0xFFF7CE00));
      expect(lit, const Color(0xFFFFFFFF));
      expect(_lum(lit), greaterThan(_lum(darkInk.textTertiaryColor)));
    });

    test('多色系统仍是 11 位，且下标含义没反转', () {
      expect(darkInk.multiColors.length, OhosColors.multiLight.length);
      // 白纸侧 10 号是纯白（正文极端）；深色侧 1 号是纯白。
      // 关键是 0 号在两侧都指向「最极端的深」，按下标取色语义不变。
      expect(darkInk.multiColors.first, const Color(0xFF000000));
      expect(OhosColors.multiInk.first, const Color(0xFF000000));
    });

    test('id 可区分，能直接拿去持久化', () {
      expect(darkInk.id, 'ink_dark');
      expect(OhosThemeData.ink().id, 'ink');
    });

    test('两份深色墨水屏值相等，且与白纸墨水屏不相等', () {
      expect(
        OhosThemeData.ink(brightness: Brightness.dark),
        OhosThemeData.ink(brightness: Brightness.dark),
      );
      expect(
        OhosThemeData.ink(brightness: Brightness.dark) == OhosThemeData.ink(),
        isFalse,
      );
    });
  });

  // `copyWith` 是「拼自定义主题」的公开入口。它必须能把白纸墨水屏翻成
  // 深色纸的，否则上面那个工厂就成了唯一通路，扩展性承诺打折。
  group('copyWith 也能拼出深色墨水屏', () {
    test('只换 brightness 与 policy，语义两维各自独立', () {
      final OhosThemeData theme = OhosThemeData.ink().copyWith(
        brightness: Brightness.dark,
        policy: const InkVisualPolicy(paper: Color(0xFF202020)),
        backgroundColor: const Color(0xFF202020),
        textPrimaryColor: const Color(0xFFFFFFFF),
        typography: OhosTypography.monochrome(brightness: Brightness.dark),
      );
      expect(theme.isDark, isTrue);
      expect(theme.monochrome, isTrue);
      expect(theme.id, 'ink', reason: 'copyWith 继承原预设 id，需自行覆盖');
    });

    test('字号字重不变，只有颜色翻', () {
      final OhosThemeData white = OhosThemeData.ink();
      final OhosThemeData dark = OhosThemeData.ink(
        brightness: Brightness.dark,
      );
      expect(dark.typography.bodyLarge?.fontSize, white.typography.bodyLarge?.fontSize);
      expect(
        dark.typography.bodyLarge?.fontWeight,
        white.typography.bodyLarge?.fontWeight,
      );
      expect(dark.typography.bodyLarge?.height, white.typography.bodyLarge?.height);
    });
  });

  group('深色墨水屏在组件层生效', () {
    Widget probe(OhosThemeData theme) => OhosTheme(
      data: theme,
      child: MaterialApp(
        home: OhosScaffold(
          appBar: OhosAppBar(title: const Text('电子纸')),
          body: Column(
            children: <Widget>[
              OhosButton(onPressed: () {}, child: const Text('主按钮')),
              OhosButton(onPressed: null, child: const Text('禁用按钮')),
              const OhosCard(child: Text('卡片')),
              OhosSwitch(value: true, onChanged: (_) {}),
            ],
          ),
        ),
      ),
    );

    testWidgets('整套组件能渲染，不因 brightness 与 policy 不同步而崩',
        (WidgetTester tester) async {
      await tester.pumpWidget(probe(OhosThemeData.ink(brightness: Brightness.dark)));
      await tester.pumpAndSettle();

      expect(find.text('主按钮'), findsOneWidget);
      expect(find.text('卡片'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('页面底色真的是深色纸', (WidgetTester tester) async {
      await tester.pumpWidget(probe(OhosThemeData.ink(brightness: Brightness.dark)));
      await tester.pumpAndSettle();

      final OhosThemeData applied = OhosTheme.of(
        tester.element(find.text('主按钮')),
      );
      expect(applied.backgroundColor, OhosColors.inkBackgroundDark);
      // `#1A1A1A` 的直接加权亮度约 0.10 —— 阈值写 0.05 会把它误判成「不够深」。
      // 真正的判据是它明显暗于白纸侧，而不是一个绝对数字。
      expect(_lum(applied.backgroundColor), lessThan(0.15));
      expect(
        _lum(applied.backgroundColor),
        lessThan(_lum(OhosThemeData.ink().backgroundColor) - 0.5),
      );
    });

    testWidgets('光效整层不画 —— 灰阶屏上没有「光」这回事',
        (WidgetTester tester) async {
      final OhosThemeData theme = OhosThemeData.ink(
        brightness: Brightness.dark,
      );
      expect(theme.policy.allowsGlow, isFalse);
      expect(theme.policy.allowsShadow, isFalse);
      expect(theme.policy.allowsBlur, isFalse);
      expect(theme.policy.allowsRipple, isFalse);
    });
  });
}