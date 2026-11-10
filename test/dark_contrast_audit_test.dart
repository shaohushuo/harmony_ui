// 深色档的可读性审计：把「某块面 + 其上的字」配成对，算 WCAG 对比度。
//
// 为什么需要这个测试：彩屏浅色档的对比度靠人眼在截图里看就够了（黑字白底，
// 一眼能发现糊）。深色档不一样 —— 深色面上的半透明白字、深灰面配深灰字，
// 数值上可能只差一点点，截图缩到手机尺寸时反而看不出问题，等用户反馈就晚了。
//
// 这里不测组件渲染，只测 token 的组合。组件取哪两个 token 是组件的事，但只要
// 这份组合表里的对比度达标，配色本身就不会是根因。

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmony_ui/harmony_ui.dart';

/// WCAG 2.1 相对亮度。
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// 把带 alpha 的前景色合到背景上，再算对比度 —— 半透明白字落在深灰面上，
/// 直接拿 color 算会高估（0x99FFFFFF 不是白字）。
double _contrast(Color fg, Color bg) {
  final Color solid = Color.alphaBlend(fg, bg);
  final double a = _luminance(solid);
  final double b = _luminance(bg);
  final double hi = math.max(a, b);
  final double lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final OhosThemeData dark = OhosThemeData.dark();

  /// 正文级（≥ 4.5，WCAG AA）。标题、正文、按钮文字都在这一档。
  void expectAA(String what, Color fg, Color bg) {
    final double ratio = _contrast(fg, bg);
    expect(
      ratio,
      greaterThanOrEqualTo(4.5),
      reason: '$what 对比度 ${ratio.toStringAsFixed(2)}:1，低于 AA 要求的 4.5:1',
    );
  }

  /// 辅助级（≥ 3.0，WCAG AA 对大字号 / 非文本图形）。占位符、图标、描边。
  void expectAALarge(String what, Color fg, Color bg) {
    final double ratio = _contrast(fg, bg);
    expect(
      ratio,
      greaterThanOrEqualTo(3.0),
      reason: '$what 对比度 ${ratio.toStringAsFixed(2)}:1，低于 3.0:1',
    );
  }

  group('深色档：文字落在页面底上', () {
    test('三级文字在 backgroundDark 上', () {
      final Color bg = dark.backgroundColor;
      expectAA('一级文字', dark.textPrimaryColor, bg);
      expectAA('二级文字', dark.textSecondaryColor, bg);
      // 三级是提示/占位，按 AA 大字号档要求
      expectAALarge('三级文字', dark.textTertiaryColor, bg);
    });

    test('三级文字在卡片面上', () {
      final Color bg = dark.cardColor;
      expectAA('一级文字', dark.textPrimaryColor, bg);
      expectAA('二级文字', dark.textSecondaryColor, bg);
      expectAALarge('三级文字', dark.textTertiaryColor, bg);
    });
  });

  group('深色档：功能色', () {
    test('成功 / 警告 / 危险色在页面底和卡片上都读得出', () {
      for (final MapEntry<String, Color> e in <String, Color>{
        'success': dark.successColor,
        'warning': dark.warningColor,
        'danger': dark.dangerColor,
      }.entries) {
        // 功能色常用于小字状态标签，按 AA 大字号档
        expectAALarge('${e.key} on background', e.value, dark.backgroundColor);
        expectAALarge('${e.key} on card', e.value, dark.cardColor);
      }
    });

    test('品牌高亮色在页面底上读得出', () {
      expectAALarge(
        'highlight on background',
        dark.highlightColor,
        dark.backgroundColor,
      );
    });
  });

  group('深色档：输入类控件的填充面', () {
    // TextField 的 fillColor / Chip 的 idleFill 都取 compBackgroundGrayColor。
    // 这块面在深色档必须是「比页面亮一点的深灰」，不能是浅色 —— 否则深色
    // 页面里会冒出一块白，而且上面的浅色文字直接失去对比度。
    test('compBackgroundGrayColor 必须是深色面', () {
      final Color fill = dark.compBackgroundGrayColor!;
      expect(
        _luminance(fill),
        lessThan(0.25),
        reason:
            'compBackgroundGrayColor 亮度 ${_luminance(fill).toStringAsFixed(3)} '
            '偏高，深色档的填充控件会变成浅色块',
      );
    });

    test('填充面上的文字读得出', () {
      final Color fill = dark.compBackgroundGrayColor!;
      expectAA('一级文字', dark.textPrimaryColor, fill);
      expectAA('二级文字', dark.textSecondaryColor, fill);
      expectAALarge('三级文字（占位符）', dark.textTertiaryColor, fill);
    });
  });

  group('深色档：弹层', () {
    test('弹层上的文字读得出', () {
      final Color bg = dark.popupColor;
      expectAA('一级文字', dark.textPrimaryColor, bg);
      expectAA('二级文字', dark.textSecondaryColor, bg);
    });
  });

  group('深色档：组件实际取色', _widgetChecks);
}
// ---------------------------------------------------------------------------
// 下面是组件级的确认：token 对了不代表组件用对了。上面那组测的是配色表，
// 这一组测「组件真的取了那个 token」—— 防止将来有人在组件里另写一个浅色常量。
// ---------------------------------------------------------------------------

void _widgetChecks() {
  OhosThemeData dark() => OhosThemeData.dark();

  testWidgets('深色档：填充式输入框的底色不是浅色', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OhosTheme(
          data: dark(),
          child: Scaffold(
            body: OhosTextField(
              hintText: '输入',
              variant: OhosTextFieldVariant.filled,
            ),
          ),
        ),
      ),
    );

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    final Color fill = field.decoration!.fillColor!;
    expect(
      _luminance(fill),
      lessThan(0.25),
      reason: '深色档的填充输入框底色亮度 ${_luminance(fill).toStringAsFixed(3)} 偏高',
    );
  });

  testWidgets('深色档：chip 未选中态底色不是浅色', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OhosTheme(
          data: dark(),
          child: Scaffold(
            body: OhosChip(label: const Text('标签'), onPressed: () {}),
          ),
        ),
      ),
    );

    // 0.6 起 chip 不再套 `Material(color: bg)`（那层会带 Material 的水波纹），
    // 底色改由 `DecoratedBox` 的 `BoxDecoration` 画，断言跟着读装饰。
    final BoxDecoration deco =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(OhosChip),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(
      _luminance(deco.color!),
      lessThan(0.25),
      reason:
          '深色档未选中 chip 的底色亮度 ${_luminance(deco.color!).toStringAsFixed(3)} 偏高',
    );
  });
}
