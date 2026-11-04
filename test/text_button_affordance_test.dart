import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harmony_ui/harmony_ui.dart';

/// 某个样式到底有没有被划线。
///
/// 用 `contains` 而不是 `== TextDecoration.underline`：`TextDecoration` 是组合
/// 对象（可能同时有 underline 和 lineThrough），直接比相等会把「划线但还带了
/// 别的」漏判成没有。
bool hasUnderline(TextStyle style) =>
    style.decoration?.contains(TextDecoration.underline) ?? false;

/// 取某个文字按钮渲染出的实际样式。
///
/// 按钮把 `DefaultTextStyle` 传给子节点，所以从 `Text` 往上找一个
/// `DefaultTextStyle` 就是它实际生效的那个，比读 widget 参数更接近真相。
TextStyle styleOfLabel(WidgetTester tester, String label) {
  final Element textElement = tester.element(find.text(label));
  final DefaultTextStyle inherited = textElement
      .dependOnInheritedWidgetOfExactType<DefaultTextStyle>()!;
  return inherited.style;
}

/// 一个只放 `text` 按钮的最小页面。
Widget page(OhosThemeData theme) => OhosTheme(
  data: theme,
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: OhosButton(
        style: OhosButtonStyle.text,
        onPressed: () {},
        child: const Text('了解更多'),
      ),
    ),
  ),
);

void main() {
  group('文字按钮在灰阶屏上的可供性', () {
    testWidgets('墨水屏下 text 按钮自带下划线', (WidgetTester tester) async {
      await tester.pumpWidget(page(OhosThemeData.ink()));

      final TextStyle style = styleOfLabel(tester, '了解更多');
      expect(hasUnderline(style), isTrue);
      // 必须是实色：半透明的线在灰阶屏上会化进白底
      expect(style.decorationStyle, TextDecorationStyle.solid);
      // 下划线跟着文字走，不能是写死的某个灰
      expect(style.decorationColor, style.color);
    });

    testWidgets('彩屏下 text 按钮不加下划线（品牌蓝已足够）', (WidgetTester tester) async {
      await tester.pumpWidget(page(OhosThemeData.light()));

      expect(hasUnderline(styleOfLabel(tester, '了解更多')), isFalse);
    });

    testWidgets('深色主题同样不加', (WidgetTester tester) async {
      await tester.pumpWidget(page(OhosThemeData.dark()));
      expect(hasUnderline(styleOfLabel(tester, '了解更多')), isFalse);
    });

    // 这条是上面那个「显式写 TextDecoration.none」的回归护栏。
    // `DefaultTextStyle.merge` 只覆盖非 null 字段，一旦谁把非下划线分支改回
    // `decoration: null`，祖先的下划线就会漏到按钮文字上 —— 而 Material 3 的
    // 默认 DefaultTextStyle 恰好不带下划线，普通用例根本测不出来。
    testWidgets('祖先带下划线时，彩屏 text 按钮不被传染',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: DefaultTextStyle(
              style: const TextStyle(
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFFFF0000),
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: OhosButton(
                  style: OhosButtonStyle.text,
                  onPressed: () {},
                  child: const Text('了解更多'),
                ),
              ),
            ),
          ),
        ),
      );

      final TextStyle style = styleOfLabel(tester, '了解更多');
      expect(hasUnderline(style), isFalse, reason: '彩屏不该被祖先的下划线传染');
      // **不能只断言 `isNot(红)`**：`null` 也能通过那一条，而 `null` 恰恰就是
      // 缺陷形态（`merge` 不回填 null → 祖先的 decorationColor 被放行）。
      // 这里曾经就是 `isNot(const Color(0xFFFF0000))`，于是
      // `decorationColor: underline ? foreground : null` 这个写法全绿 ——
      // 而 flutter_test 的默认 `DefaultTextStyle` 带的是**纯黄** `#FFFF00`，
      // 墨屏对话框的标题与正文因此各带一条黄线（实测通道差 86）。
      expect(
        style.decorationColor,
        Colors.transparent,
        reason: '不画线时必须显式给中性值，否则祖先的颜色会漏下来',
      );
    });

    testWidgets('其他样式不受影响：filled / outlined 不加下划线',
        (WidgetTester tester) async {
      for (final OhosButtonStyle style in <OhosButtonStyle>[
        OhosButtonStyle.filled,
        OhosButtonStyle.tonal,
        OhosButtonStyle.outlined,
        OhosButtonStyle.plain,
      ]) {
        await tester.pumpWidget(
          OhosTheme(
            data: OhosThemeData.ink(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: OhosButton(
                  style: style,
                  onPressed: () {},
                  child: const Text('按钮'),
                ),
              ),
            ),
          ),
        );
        expect(
          hasUnderline(styleOfLabel(tester, '按钮')),
          isFalse,
          reason: '$style 有底或边框，不该再划线',
        );
      }
    });

    testWidgets('禁用态的 text 按钮不加下划线 —— 免得读起来还能点',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: OhosButton(
                style: OhosButtonStyle.text,
                onPressed: null,
                child: const Text('禁用'),
              ),
            ),
          ),
        ),
      );
      expect(
        hasUnderline(styleOfLabel(tester, '禁用')),
        isFalse,
      );
    });

    testWidgets('策略可覆盖：自定主题关掉下划线，即使它是灰阶',
        (WidgetTester tester) async {
      // 一个「有配色但仍是灰阶」的主题：isMonochrome 为真但决定不划线
      await tester.pumpWidget(
        page(
          OhosThemeData.ink().copyWith(
            policy: const _NoUnderlineInkPolicy(),
          ),
        ),
      );
      expect(
        hasUnderline(styleOfLabel(tester, '了解更多')),
        isFalse,
      );
    });
  });

  group('策略语义', () {
    test('默认跟随 isMonochrome', () {
      expect(const ColorVisualPolicy().underlinesTextActions, isFalse);
      expect(const InkVisualPolicy().underlinesTextActions, isTrue);
    });

    test('与描边宽度无关 —— 高对比主题不该被顺带划线', () {
      // 有 2px 描边但明确不需要下划线
      const OhosVisualPolicy contrast = _HighContrastNoUnderline();
      expect(contrast.outlineWidth, 2);
      expect(contrast.underlinesTextActions, isFalse);
    });
  });
}

/// 灰阶屏，但用别的方式（加粗）表达可供性，所以不划线。
class _NoUnderlineInkPolicy extends InkVisualPolicy {
  const _NoUnderlineInkPolicy();

  @override
  bool get underlinesTextActions => false;

  @override
  bool operator ==(Object other) => other is _NoUnderlineInkPolicy;

  @override
  int get hashCode => (_NoUnderlineInkPolicy).hashCode;
}

class _HighContrastNoUnderline extends OhosVisualPolicy {
  const _HighContrastNoUnderline();

  @override
  bool get isMonochrome => false;
  @override
  Color tint(Color base, double alpha) => base.withValues(alpha: alpha);
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
}