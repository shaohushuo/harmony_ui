import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harmony_ui/harmony_ui.dart';

/// 新版 `Color` 的 a/r/g/b 都是 0–1 的 double，断言前统一换算回 0–255。
int _alpha(Color c) => (c.a * 255).round();

int _channel(double v) => (v * 255).round();

void main() {
  group('OhosVisualPolicy', () {
    test('彩屏原样返回，不做量化', () {
      const OhosVisualPolicy policy = ColorVisualPolicy();
      const Color base = Color(0xFF0A59F7);
      expect(policy.tint(base, 0.12), base.withValues(alpha: 0.12));
      expect(policy.line(base, 0.4), base.withValues(alpha: 0.4));
      expect(policy.quantize(const Color(0xFF123456)), const Color(0xFF123456));
      expect(policy.outlineWidth, isNull);
      expect(policy.allowsShadow, isTrue);
      expect(policy.allowsBlur, isTrue);
      expect(policy.allowsRipple, isTrue);
    });

    test('墨水屏把 20% 及以下的底判成透明，好让调用方改画线', () {
      const OhosVisualPolicy policy = InkVisualPolicy();
      expect(_alpha(policy.tint(const Color(0xFF0A59F7), 0.06)), 0);
      expect(_alpha(policy.tint(const Color(0xFF0A59F7), 0.12)), 0);
      expect(_alpha(policy.tint(const Color(0xFF0A59F7), 0.20)), 0);
      // 21% 起开始留得住，并且是实色（灰阶屏上没有「叠一层」）
      expect(_alpha(policy.tint(const Color(0xFF000000), 0.25)), 255);
      expect(_alpha(policy.tint(const Color(0xFF000000), 0.90)), 255);
    });

    test('墨水屏丢掉线的 alpha，一律用实色', () {
      const OhosVisualPolicy policy = InkVisualPolicy();
      final Color faint = policy.line(const Color(0xFF000000), 0.2);
      final Color strong = policy.line(const Color(0xFF000000), 0.9);
      expect(_alpha(faint), 255);
      expect(faint, strong);
    });

    test('量化结果是实色灰：不再有半透明', () {
      const OhosVisualPolicy policy = InkVisualPolicy();
      for (final Color probe in <Color>[
        const Color(0xFF0A59F7),
        const Color(0xFFF7CE00),
        const Color(0x33000000),
        const Color(0xFF767676),
        const Color(0xFFFFFFFF),
        const Color(0xFF000000),
        const Color(0x800A59F7),
      ]) {
        final Color quantized = policy.quantize(probe);
        expect(_alpha(quantized), 255, reason: '$probe -> $quantized');
        final int red = _channel(quantized.r);
        expect(red, _channel(quantized.g), reason: '必须是灰：$quantized');
        expect(red, _channel(quantized.b), reason: '必须是灰：$quantized');
      }
    });

    test('量化保留色板原本挑好的灰，不做 16 级吸附', () {
      const OhosVisualPolicy policy = InkVisualPolicy();
      // #767676 / #CCCCCC 是色板为这块屏挑的，硬吸附到 level*17 会白白挪一档
      expect(policy.quantize(const Color(0xFF767676)), const Color(0xFF767676));
      expect(policy.quantize(const Color(0xFFCCCCCC)), const Color(0xFFCCCCCC));
      expect(policy.quantize(const Color(0xFF000000)), const Color(0xFF000000));
      expect(policy.quantize(const Color(0xFFFFFFFF)), const Color(0xFFFFFFFF));
    });

    test('墨水屏关掉阴影 / 模糊 / 水波纹，并冻结动画', () {
      const OhosVisualPolicy policy = InkVisualPolicy();
      expect(policy.outlineWidth, 1);
      expect(policy.allowsShadow, isFalse);
      expect(policy.allowsBlur, isFalse);
      expect(policy.allowsRipple, isFalse);
      expect(policy.scaleMotion(const Duration(milliseconds: 300)), Duration.zero);
    });

    test('monochrome 只是策略的另一面', () {
      expect(OhosThemeData.light().monochrome, isFalse);
      expect(OhosThemeData.dark().monochrome, isFalse);
      expect(OhosThemeData.ink().monochrome, isTrue);
      expect(OhosThemeData.ink().usesOutlines, isTrue);
      expect(OhosThemeData.light().usesOutlines, isFalse);
    });
  });

  group('OhosThemeController', () {
    test('toggle() 在普通主题与墨水屏之间来回', () {
      final OhosThemeController controller = OhosThemeController();
      expect(controller.mode, OhosThemeMode.light);

      controller.toggle();
      expect(controller.mode, OhosThemeMode.ink);
      expect(controller.themeData.monochrome, isTrue);
      expect(controller.isInk, isTrue);

      controller.toggle();
      expect(controller.mode, OhosThemeMode.light);
      expect(controller.themeData.monochrome, isFalse);
      expect(controller.isInk, isFalse);
    });

    test('从深色切到墨水屏再切回来，回到深色而不是浅色', () {
      final OhosThemeController controller = OhosThemeController(
        initialMode: OhosThemeMode.dark,
      );
      controller.toggle();
      expect(controller.mode, OhosThemeMode.ink);
      controller.toggle();
      expect(controller.mode, OhosThemeMode.dark);
    });

    test('档位没变时不通知，避免整个 MaterialApp 白重建一次', () {
      final OhosThemeController controller = OhosThemeController();
      int notifications = 0;
      controller.addListener(() => notifications++);

      controller.mode = OhosThemeMode.light;
      expect(notifications, 0);

      controller.mode = OhosThemeMode.ink;
      expect(notifications, 1);
    });

    test('materialTheme 的 brightness 跟着档位走，墨水屏算浅色', () {
      final OhosThemeController controller = OhosThemeController();
      expect(controller.materialTheme.brightness, Brightness.light);

      controller.mode = OhosThemeMode.dark;
      expect(controller.materialTheme.brightness, Brightness.dark);

      controller.mode = OhosThemeMode.ink;
      // 墨水屏是黑字白纸，不能落到 Material 的深色分支
      expect(controller.materialTheme.brightness, Brightness.light);
      expect(controller.themeData.isDark, isFalse);
    });

    test('字体族透传给两套主题', () {
      final OhosThemeController controller = OhosThemeController(
        fontFamily: 'HarmonyOS Sans',
      );
      expect(controller.themeData.typography.fontFamily, 'HarmonyOS Sans');
      expect(controller.materialTheme.textTheme.bodyMedium?.fontFamily,
          'HarmonyOS Sans');
    });
  });

  group('OhosThemeSwitcher', () {
    testWidgets('切换后子树拿到新主题', (WidgetTester tester) async {
      final OhosThemeController controller = OhosThemeController();

      await tester.pumpWidget(
        OhosThemeSwitcher(
          controller: controller,
          builder: (BuildContext context, ThemeData materialTheme) {
            return MaterialApp(
              theme: materialTheme,
              home: OhosScaffold(
                body: Builder(
                  builder: (BuildContext context) {
                    final OhosThemeData theme = OhosTheme.of(context);
                    return Text(
                      theme.monochrome ? 'ink' : 'color',
                      style: theme.typography.bodyLarge,
                    );
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('color'), findsOneWidget);

      controller.toggle();
      await tester.pumpAndSettle();

      expect(find.text('ink'), findsOneWidget);
      expect(find.text('color'), findsNothing);
    });

    testWidgets('切主题不会把用户从深层页面弹回首页', (WidgetTester tester) async {
      final OhosThemeController controller = OhosThemeController();

      await tester.pumpWidget(
        OhosThemeSwitcher(
          controller: controller,
          builder: (BuildContext context, ThemeData materialTheme) {
            return MaterialApp(
              theme: materialTheme,
              home: OhosScaffold(
                appBar: OhosAppBar(
                  title: const Text('首页'),
                  actions: <Widget>[
                    OhosThemeToggleButton(controller: controller),
                  ],
                ),
                body: Builder(
                  builder: (BuildContext context) => OhosButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            const OhosScaffold(body: Center(child: Text('二级页'))),
                      ),
                    ),
                    child: const Text('进入二级页'),
                  ),
                ),
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('进入二级页'));
      await tester.pumpAndSettle();
      expect(find.text('二级页'), findsOneWidget);

      // 在二级页里直接切主题（真实场景是宿主自己调 controller）
      controller.toggle();
      await tester.pumpAndSettle();

      // Navigator 的 State 被复用，页面不弹回
      expect(find.text('二级页'), findsOneWidget);
      expect(find.text('首页'), findsNothing);
    });
  });

  group('OhosThemeToggleButton', () {
    Widget host(OhosThemeController controller) {
      return OhosThemeSwitcher(
        controller: controller,
        builder: (BuildContext context, ThemeData materialTheme) {
          return MaterialApp(
            theme: materialTheme,
            home: OhosScaffold(
              appBar: OhosAppBar(
                title: const Text('标题'),
                actions: <Widget>[
                  OhosThemeToggleButton(controller: controller),
                ],
              ),
              body: const SizedBox.shrink(),
            ),
          );
        },
      );
    }

    testWidgets('点一下就切到墨水屏，再点一下回来', (WidgetTester tester) async {
      final OhosThemeController controller = OhosThemeController();
      await tester.pumpWidget(host(controller));

      expect(controller.mode, OhosThemeMode.light);

      await tester.tap(find.byType(OhosThemeToggleButton));
      await tester.pumpAndSettle();
      expect(controller.mode, OhosThemeMode.ink);

      await tester.tap(find.byType(OhosThemeToggleButton));
      await tester.pumpAndSettle();
      expect(controller.mode, OhosThemeMode.light);
    });

    testWidgets('图标跟着档位变', (WidgetTester tester) async {
      final OhosThemeController controller = OhosThemeController();
      await tester.pumpWidget(host(controller));

      Icon currentIcon() => tester.widget<Icon>(
        find.descendant(
          of: find.byType(OhosThemeToggleButton),
          matching: find.byType(Icon),
        ),
      );

      expect(currentIcon().icon, Icons.light_mode_outlined);

      controller.toggle();
      await tester.pumpAndSettle();
      expect(currentIcon().icon, Icons.contrast_rounded);
    });
  });
}