// 三个由下游实测反馈的问题（issue #2 / #3 / #4）的回归约束。
//
// 它们的共同点：都不是「某处写错一个值」，而是**同一件事在两处各写了一遍，
// 只改了一处**。所以这里的断言尽量钉在「组件真的画出来了」而不是「组件里
// 有这个字段」—— 字段存在但没被用上，正是这三个 bug 的形态。
//
// - #2：深色档的填充面令牌取了浅色，浅底配浅字
// - #3：ChipGroup 自己搭容器，漏了 OhosChip 那套 policy 描边
// - #4：SearchBar 只写 border，漏了 Material 的状态槽位与 filled

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmony_ui/harmony_ui.dart';

/// 读 [OhosChip] 的底板装饰。
///
/// 0.6 起芯片不再套 `Material(color: bg)`：Material 那层会顺带带来从触点
/// 扩散的圆形高光，在胶囊形状上按下去露出一圈与圆角对不上的弧。底色 / 描边
/// 改由 `DecoratedBox` 自己画，所以断言也得跟着读 `BoxDecoration`。
BoxDecoration _chipDeco(WidgetTester tester) {
  return tester
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
}

/// WCAG 2.1 相对亮度。
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// 半透明前景先合成再算，否则 `0x99FFFFFF` 会被当成纯白，高估对比度。
double _contrast(Color fg, Color bg) {
  final Color solid = Color.alphaBlend(fg, bg);
  final double a = _luminance(solid);
  final double b = _luminance(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

Widget _themed(OhosThemeData data, Widget child, {ThemeData? materialTheme}) {
  return OhosTheme(
    data: data,
    child: MaterialApp(
      theme: materialTheme,
      home: OhosScaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  // -------------------------------------------------------------------------
  // issue #2：深色档的「组件灰底 + 次要色文字」
  // -------------------------------------------------------------------------
  group('issue #2 深色档填充面', () {
    // 原来 `compBackgroundGrayDark` 抄的是官方 token 表的 #E5E5EA。那个值在
    // ArkUI 语境里成立（配的是深色**字** #FFE5E5E5），而本库把它当输入框 /
    // chip 的**填充面**，上面画的是 textPrimaryColor（深色档 0xE5FFFFFF 半透明白）。
    // 白字落在这块浅灰上实测 1.23:1 —— token 抄对 ≠ 用对。
    final OhosThemeData dark = OhosThemeData.dark();

    test('填充面亮度低于 0.25（不能是浅色块）', () {
      final Color fill = dark.compBackgroundGrayColor!;
      expect(
        _luminance(fill),
        lessThan(0.25),
        reason:
            '深色档 compBackgroundGrayColor 亮度 '
            '${_luminance(fill).toStringAsFixed(3)} 偏高',
      );
    });

    test('一级 / 二级文字落在填充面上达到 AA 4.5:1', () {
      final Color fill = dark.compBackgroundGrayColor!;
      for (final MapEntry<String, Color> e in <String, Color>{
        '一级文字': dark.textPrimaryColor,
        '二级文字': dark.textSecondaryColor,
      }.entries) {
        final double ratio = _contrast(e.value, fill);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '深色档${e.key}落在填充面上对比度 '
              '${ratio.toStringAsFixed(2)}:1',
        );
      }
    });

    test('深浅两档的同名面令牌不近似同值', () {
      // issue 建议的那条自检。只扫**面**令牌（xxxColor 在主题里的实际取值），
      // 不扫彩色令牌 —— 深色档的品牌色 / 交互色本来就该提亮，
      // 按「深色必须更暗」一刀切会把正确设计判成错误。
      final OhosThemeData light = OhosThemeData.light();
      final Map<String, (Color, Color)> surfaces = <String, (Color, Color)>{
        'backgroundColor': (light.backgroundColor, dark.backgroundColor),
        'cardColor': (light.cardColor, dark.cardColor),
        'popupColor': (light.popupColor, dark.popupColor),
        'compBackgroundPrimaryColor': (
          light.compBackgroundPrimaryColor!,
          dark.compBackgroundPrimaryColor!,
        ),
        'compBackgroundGrayColor': (
          light.compBackgroundGrayColor!,
          dark.compBackgroundGrayColor!,
        ),
        'backgroundTertiaryColor': (
          light.backgroundTertiaryColor!,
          dark.backgroundTertiaryColor!,
        ),
      };

      for (final MapEntry<String, (Color, Color)> e in surfaces.entries) {
        final double l = _luminance(e.value.$1);
        final double d = _luminance(e.value.$2);
        expect(
          d,
          lessThan(l),
          reason:
              '${e.key} 深色档亮度 ${d.toStringAsFixed(3)} '
              '不低于浅色档 ${l.toStringAsFixed(3)}，深色模式里会冒出一块浅色面',
        );
        expect(
          (l - d).abs(),
          greaterThan(0.05),
          reason:
              '${e.key} 深浅两档亮度只差 ${(l - d).abs().toStringAsFixed(3)}，'
              '近似同值 —— 很可能是深色档直接抄了浅色档的令牌',
        );
      }
    });

    testWidgets('填充式输入框的填充面取的是深色令牌', (WidgetTester tester) async {
      await tester.pumpWidget(
        _themed(
          dark,
          const SizedBox(
            width: 280,
            child: OhosTextField(
              hintText: '输入',
              variant: OhosTextFieldVariant.filled,
            ),
          ),
        ),
      );

      final TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(_luminance(field.decoration!.fillColor!), lessThan(0.25));
    });

    testWidgets('未选中 chip 的底色取的是深色令牌', (WidgetTester tester) async {
      await tester.pumpWidget(
        _themed(dark, OhosChip(label: const Text('标签'), onPressed: () {})),
      );

      expect(_luminance(_chipDeco(tester).color!), lessThan(0.25));
    });
  });

  // -------------------------------------------------------------------------
  // issue #3：墨屏下 ChipGroup 未选中芯片没有描边
  // -------------------------------------------------------------------------
  group('issue #3 ChipGroup 墨屏描边', () {
    const List<OhosChipItem> items = <OhosChipItem>[
      OhosChipItem(label: Text('全部')),
      OhosChipItem(label: Text('MIT')),
      OhosChipItem(label: Text('BSD')),
    ];

    /// 取第 [index] 颗芯片的容器装饰。
    BoxDecoration decorationOf(WidgetTester tester, int index) {
      final AnimatedContainer box = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(OhosChipGroup),
              matching: find.byType(AnimatedContainer),
            )
            .at(index),
      );
      return box.decoration! as BoxDecoration;
    }

    testWidgets('墨屏档：未选中芯片画出了实色描边', (WidgetTester tester) async {
      await tester.pumpWidget(
        _themed(
          OhosThemeData.ink(),
          const SizedBox(
            width: 360,
            child: OhosChipGroup(items: items, selectedIndex: 0),
          ),
        ),
      );

      // 第 0 颗是选中态，第 1、2 颗是未选中
      for (final int i in <int>[1, 2]) {
        final BoxDecoration box = decorationOf(tester, i);
        expect(
          box.border,
          isNotNull,
          reason: '墨屏下未选中芯片没有描边 —— 填充色就是纸色，芯片会整个消失',
        );
        final Border border = box.border! as Border;
        // 墨屏的 policy.line 丢 alpha 换实色，描边必须是完全不透明
        expect(
          border.top.color.a,
          closeTo(1.0, 0.01),
          reason: '墨屏的描边必须实色（半透明线会化进背景）',
        );
        expect(border.top.width, greaterThan(0));
      }
    });

    testWidgets('墨屏档：未选中芯片的描边颜色与 OhosChip 一致', (WidgetTester tester) async {
      final OhosThemeData ink = OhosThemeData.ink();
      await tester.pumpWidget(
        _themed(
          ink,
          const SizedBox(
            width: 360,
            child: OhosChipGroup(items: items, selectedIndex: 0),
          ),
        ),
      );
      final Border groupBorder = decorationOf(tester, 1).border! as Border;

      await tester.pumpWidget(
        _themed(ink, OhosChip(label: const Text('标签'), onPressed: () {})),
      );
      final BoxDecoration chip = _chipDeco(tester);

      // 两边都走 policy.line(textTertiary, 0.3)，墨屏下同一颗实色 ——
      // 这条断言就是「同一件事不要在两处各写一遍」的可验证形式
      expect(groupBorder.top.color, (chip.border! as Border).top.color);
    });

    testWidgets('彩屏档：描边淡成发丝线，观感不被打断', (WidgetTester tester) async {
      await tester.pumpWidget(
        _themed(
          OhosThemeData.light(),
          const SizedBox(
            width: 360,
            child: OhosChipGroup(items: items, selectedIndex: 0),
          ),
        ),
      );

      final Border border = decorationOf(tester, 1).border! as Border;
      // 彩屏保留 alpha（30% 提示色），不是实黑 —— 否则胶囊会显得比原来重
      expect(border.top.color.a, lessThan(0.5));
    });
  });

  // -------------------------------------------------------------------------
  // issue #4：宿主 inputDecorationTheme 渗进 SearchBar 的内部 TextField
  // -------------------------------------------------------------------------
  group('issue #4 SearchBar 边框泄漏', () {
    /// 宿主给全局输入框补描边的主题 —— 墨水屏上没有填充色可用，
    /// 只能用 1px 描边给输入框分层，这是很常见的配置。
    ThemeData hostTheme() => ThemeData(
      inputDecorationTheme: const InputDecorationThemeData(
        filled: true,
        fillColor: Colors.red,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );

    testWidgets('宿主配了 enabledBorder 时，内部 TextField 不画边', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          OhosThemeData.ink(),
          const SizedBox(width: 360, child: OhosSearchBar(hintText: '搜索组件名')),
          materialTheme: hostTheme(),
        ),
      );

      final TextField field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(OhosSearchBar),
          matching: find.byType(TextField),
        ),
      );
      final InputDecoration d = field.decoration!;

      // 六个状态槽位必须逐个为 none。只断言 `border` 不够 —— 它本来就没问题，
      // 出问题的是状态槽位被宿主的主题填上了。
      expect(d.border, InputBorder.none);
      expect(d.enabledBorder, InputBorder.none);
      expect(d.disabledBorder, InputBorder.none);
      expect(d.focusedBorder, InputBorder.none);
      expect(d.errorBorder, InputBorder.none);
      expect(d.focusedErrorBorder, InputBorder.none);
    });

    testWidgets('宿主的 filled 不会漏进搜索框', (WidgetTester tester) async {
      await tester.pumpWidget(
        _themed(
          OhosThemeData.ink(),
          const SizedBox(width: 360, child: OhosSearchBar(hintText: '搜索组件名')),
          materialTheme: hostTheme(),
        ),
      );

      final TextField field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(OhosSearchBar),
          matching: find.byType(TextField),
        ),
      );
      expect(field.decoration!.filled, isFalse);
    });

    testWidgets('组件自己的 decoration 能扛住宿主主题的合并', (WidgetTester tester) async {
      await tester.pumpWidget(
        _themed(
          OhosThemeData.ink(),
          const SizedBox(width: 360, child: OhosSearchBar(hintText: '搜索组件名')),
          materialTheme: hostTheme(),
        ),
      );

      final TextField field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(OhosSearchBar),
          matching: find.byType(TextField),
        ),
      );

      // 这一条是这个 bug 的核心。只断言「组件写的槽位是 none」不够稳 ——
      // 真正的风险在于 Material 会拿宿主主题把它**覆盖掉**。
      // `InputDecoration.applyDefaults(theme)` 就是 InputDecorator 内部做的那一步：
      //   enabledBorder: enabledBorder ?? theme.enabledBorder
      // 组件留 null（修复前）→ 拿到宿主的 OutlineInputBorder → 画第二道框；
      // 组件写 none（修复后）→ `_NoInputBorder` → 目的达成。
      final InputDecoration merged = field.decoration!.applyDefaults(
        hostTheme().inputDecorationTheme,
      );
      expect(
        merged.enabledBorder,
        isNot(isA<OutlineInputBorder>()),
        reason: '宿主主题的 enabledBorder 覆盖了搜索框自己的设置，真机上会叠出第二道框',
      );
      expect(
        merged.focusedBorder,
        isNot(isA<OutlineInputBorder>()),
        reason: '聚焦时同理',
      );
      expect(merged.filled, isFalse, reason: '宿主主题的 filled: true 漏进了胶囊');
    });
  });
}
