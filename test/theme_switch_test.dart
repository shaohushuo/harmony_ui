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

    // 以墨水屏初始化时，第一次 toggle 直接走「切回普通」那条分支，拿的是
    // 构造函数播种的「普通」一侧 —— 这一侧必须自己带上 fontFamily、且档位
    // 必须真的是用户上次的彩屏档位。用字段初始化器写死 `OhosThemeData.light()`
    // 会让整个字阶掉回系统字体（example 默认就停在 ink，点一下就能触发）。
    test('以墨水屏初始化时，toggle 回彩屏仍保留档位与字体族', () {
      final OhosThemeController controller = OhosThemeController(
        initialMode: OhosThemeMode.ink,
        fontFamily: 'HarmonyOS Sans',
      );
      expect(controller.isInk, isTrue);

      controller.toggle();

      expect(controller.mode, OhosThemeMode.light);
      expect(controller.themeData.isDark, isFalse);
      expect(
        controller.themeData.typography.fontFamily,
        'HarmonyOS Sans',
        reason: 'toggle 回彩屏不能丢掉 fontFamily，否则 13 个 TextStyle 全部回落',
      );
    });

    test('以深色墨水屏策略初始化时，toggle 回彩屏同样带字体族', () {
      final OhosThemeController controller = OhosThemeController(
        initialMode: OhosThemeMode.ink,
        fontFamily: 'HarmonyOS Sans',
      );
      // 先切到深色，再进墨水屏，再回来 —— 应当回到深色
      controller.setColorMode(OhosThemeMode.dark);
      controller.toggle();
      expect(controller.isInk, isTrue);
      controller.toggle();

      expect(controller.mode, OhosThemeMode.dark);
      expect(controller.themeData.typography.fontFamily, 'HarmonyOS Sans');
    });

    // 自定义主题本身就是「普通」那一侧：从它切到墨水屏再切回来，回到的必须
    // 是那份自定义主题，而不是内置浅色。
    test('custom() 进墨水屏再 toggle 回来，回到那份自定义主题', () {
      final OhosThemeData brand = OhosThemeData.light().copyWith(
        id: 'brand',
        highlightColor: const Color(0xFF7B3FF2),
      );
      final OhosThemeController controller = OhosThemeController.custom(
        brand,
        fontFamily: 'HarmonyOS Sans',
      );
      expect(controller.mode, isNull);

      controller.mode = OhosThemeMode.ink;
      expect(controller.isInk, isTrue);

      controller.toggle();

      expect(controller.themeData.highlightColor, const Color(0xFF7B3FF2));
      expect(controller.themeData.id, 'brand');
      expect(controller.mode, isNull, reason: '自定义主题没有档位');
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

  // 这一组守的是「策略化改造时最容易丢的那一维」：把三分支条件压成一次
  // `policy.tint(...)` 调用，逻辑上看是「统一交给策略」，实际上把某个分支
  // 专有的前提（enabled / 黑色基准 / 实色 vs 量化）一起丢了。这些回归全在
  // 彩屏档位，墨屏因为策略兜底反而正常，所以只测墨水屏是测不出来的。
  group('策略化没有改变彩屏的既有观感', () {
    /// 取一个组件渲染出的 `BoxDecoration.color`。
    Color fillOf(WidgetTester tester, Finder finder) {
      final AnimatedContainer box = tester.widget<AnimatedContainer>(
        finder,
      );
      return (box.decoration! as BoxDecoration).color!;
    }

    Widget wrap(Widget child, {OhosThemeData? theme}) => OhosTheme(
      data: theme ?? OhosThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

    testWidgets('启用但未勾选的复选框保持透明，不铺 15% 灰底',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(OhosCheckbox(value: false, onChanged: (_) {})),
      );
      expect(
        fillOf(tester, find.byType(AnimatedContainer).first).a,
        0,
        reason: '铺了灰底会削弱与选中态实心色的对比度',
      );
    });

    testWidgets('禁用且未勾选的复选框仍然铺 15% 灰底',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const OhosCheckbox(value: false)));
      expect(
        fillOf(tester, find.byType(AnimatedContainer).first).a,
        closeTo(0.15, 0.01),
      );
    });

    testWidgets('plain 按钮禁用态在浅色底上是「黑 8%」而不是「白 8%」',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosButton(
            style: OhosButtonStyle.plain,
            onPressed: null,
            child: Text('x'),
          ),
        ),
      );
      final Material material = tester.widget<Material>(
        find.byType(Material).first,
      );
      final Color background = material.color!;
      // 白 8% 铺在白页面上等于没有；基准必须是黑，才在浅底上留得下一块灰。
      expect(background.a, closeTo(0.08, 0.01));
      expect(
        background.r,
        closeTo(0, 0.001),
        reason: '基准色是黑，不是 cardColor（浅色档下即纯白）',
      );
    });
  });

  // 「点亮」与「量化」是两件事：量化只负责去掉半透明，它按感知明度取灰，
  // 高亮黄的明度落在中间调，结果比未激活态还淡 —— 语义直接反转。
  group('点亮态的对比方向', () {
    const Color litYellow = Color(0xFFF7CE00);

    test('彩屏原样保留那抹亮色', () {
      expect(const ColorVisualPolicy().litFill(litYellow), litYellow);
    });

    test('墨水屏点亮态必须比未激活态更暗（白纸上）', () {
      final OhosThemeData ink = OhosThemeData.ink();
      final Color lit = const InkVisualPolicy().litFill(litYellow);
      final Color idle = ink.textTertiaryColor;

      expect(lit.a, 1.0, reason: '灰阶屏没有半透明，必须是实色');
      expect(
        lit.computeLuminance(),
        lessThan(idle.computeLuminance()),
        reason: '点亮态比未激活态更淡的话，读者以为根本没点亮',
      );
    });

    test('量化本身会给出更淡的灰 —— 这就是不能用它的原因', () {
      const InkVisualPolicy ink = InkVisualPolicy();
      // 记录这个反例：如果谁把 litFill 改回 quantize / line，这条会解释代价
      expect(ink.quantize(litYellow), ink.line(litYellow, 1));
      expect(
        ink.quantize(litYellow).computeLuminance(),
        greaterThan(ink.litFill(litYellow).computeLuminance()),
      );
    });

    test('深色墨水屏反向：点亮态取纯白', () {
      const InkVisualPolicy darkInk = InkVisualPolicy(
        paper: Color(0xFF1A1A1A),
      );
      final Color lit = darkInk.litFill(litYellow);
      expect(lit, const Color(0xFFFFFFFF));
      expect(lit.computeLuminance(), greaterThan(darkInk.paper.computeLuminance()));
    });
  });
}