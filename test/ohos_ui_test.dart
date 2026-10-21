import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harmony_ui/harmony_ui.dart';

Widget wrap(Widget child) {
  return OhosTheme(
    data: OhosThemeData.light(),
    child: MaterialApp(
      home: OhosScaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('OhosTheme', () {
    testWidgets('of() provides the theme to descendants', (
      WidgetTester tester,
    ) async {
      OhosThemeData? captured;
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.dark(),
          child: Builder(
            builder: (BuildContext context) {
              captured = OhosTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured, isNotNull);
      expect(captured!.isDark, isTrue);
      expect(captured!.highlightColor, const Color(0xFF317AF7));
    });

    test('light theme exposes official HarmonyOS tokens', () {
      final OhosThemeData theme = OhosThemeData.light();
      expect(theme.highlightColor, const Color(0xFF0A59F7));
      expect(theme.backgroundColor, const Color(0xFFF1F3F5));
      expect(theme.cardColor, Colors.white);
      expect(theme.multiColors.length, 11);
      expect(theme.dangerColor, const Color(0xFFE84026));
      expect(theme.typography.bodyLarge?.fontSize, 16);
    });

    test('ink preset is pure black on pure white, without mid-tones', () {
      final OhosThemeData ink = OhosThemeData.ink();
      expect(ink.monochrome, isTrue);
      // 墨水屏仍是「白纸黑字」，不能走 isDark 分支
      expect(ink.isDark, isFalse);
      expect(ink.brightness, Brightness.light);
      expect(ink.backgroundColor, Colors.white);
      expect(ink.cardColor, Colors.white);
      expect(ink.popupColor, Colors.white);
      expect(ink.textPrimaryColor, Colors.black);
      expect(ink.textSecondaryColor, Colors.black);
      // 三级色留给 hint：必须明显淡于正文，否则「未输入」与「已输入」同色
      expect(ink.textTertiaryColor, const Color(0xFF767676));
      // 功能色压成黑：红色在 16 级灰上是中灰，会和正文糊在一起
      expect(ink.successColor, Colors.black);
      expect(ink.warningColor, Colors.black);
      expect(ink.dangerColor, Colors.black);
      // 水波纹 / hover / focus 会留半透明灰块且刷新慢 → 全关
      expect(ink.interactiveHoverColor, Colors.transparent);
      expect(ink.interactivePressedColor, Colors.transparent);
      expect(ink.interactiveFocusColor, Colors.transparent);
      expect(ink.interactiveSelectColor, const Color(0x33000000));
      // 关键：light 预设的 10% 黑分隔线在墨水屏上等于没有
      expect(ink.dividerColor, Colors.black);
      expect(ink.multiColors.length, 11);
      expect(ink.multiColors.first, Colors.black);
      expect(ink.multiColors.last, Colors.white);
    });

    test('copyWith keeps monochrome, light/dark presets stay colorful', () {
      expect(OhosThemeData.light().monochrome, isFalse);
      expect(OhosThemeData.dark().monochrome, isFalse);
      expect(OhosThemeData.light().copyWith(monochrome: true).monochrome, isTrue);
      expect(
        OhosThemeData.ink().copyWith(highlightColor: Colors.grey).monochrome,
        isTrue,
      );
    });

    // `MaterialApp` 提供 Directionality / Navigator，组件本身不再包一层。
    Widget themed(OhosThemeData data, Widget child) {
      return OhosTheme(
        data: data,
        child: MaterialApp(home: OhosScaffold(body: child)),
      );
    }

    testWidgets('ink 主题下 OhosLightMaterial 不再整层模糊', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        themed(
          OhosThemeData.ink(),
          const OhosLightMaterial(
            level: OhosLightMaterialLevel.ultraThick,
            child: SizedBox(width: 120, height: 48),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);

      // 彩屏仍然走模糊
      await tester.pumpWidget(
        themed(
          OhosThemeData.light(),
          const OhosLightMaterial(
            level: OhosLightMaterialLevel.ultraThick,
            child: SizedBox(width: 120, height: 48),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('ink 主题下输入框错误态读 theme.dangerColor，不再是硬编码红', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        themed(
          OhosThemeData.ink(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: OhosTextField(errorText: '必填'),
          ),
        ),
      );

      final InputDecoration decoration =
          tester.widget<TextField>(find.byType(TextField)).decoration!;
      final UnderlineInputBorder errorBorder =
          decoration.errorBorder! as UnderlineInputBorder;
      expect(errorBorder.borderSide.color, Colors.black);
    });

    testWidgets('ink 主题下弹层补 1px 黑描边，不靠 scrim 才分得清边界', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        themed(
          OhosThemeData.ink(),
          OhosButton(onPressed: () {}, child: const Text('打开')),
        ),
      );

      final BuildContext context = tester.element(find.text('打开'));
      showOhosDialog<void>(
        context: context,
        title: '标题',
        content: '内容',
        actions: <OhosDialogAction>[
          OhosDialogAction(
            label: '好',
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ],
      );
      await tester.pumpAndSettle();

      final Dialog dialog = tester.widget<Dialog>(find.byType(Dialog));
      final RoundedRectangleBorder shape =
          dialog.shape! as RoundedRectangleBorder;
      expect(shape.side.color, Colors.black);
      expect(shape.side.width, 1);
    });
  });

  group('OhosButton', () {
    testWidgets('renders label and fires onPressed', (
      WidgetTester tester,
    ) async {
      int pressed = 0;
      await tester.pumpWidget(
        wrap(OhosButton(onPressed: () => pressed++, child: const Text('确定'))),
      );
      expect(find.text('确定'), findsOneWidget);
      await tester.tap(find.text('确定'));
      expect(pressed, 1);
    });

    testWidgets('disabled button does not fire', (WidgetTester tester) async {
      int pressed = 0;
      await tester.pumpWidget(
        wrap(OhosButton(onPressed: null, child: const Text('禁用'))),
      );
      await tester.tap(find.text('禁用'), warnIfMissed: false);
      expect(pressed, 0);
    });
  });

  group('OhosSwitch', () {
    testWidgets('toggles value through onChanged', (WidgetTester tester) async {
      bool value = false;
      await tester.pumpWidget(
        wrap(OhosSwitch(value: value, onChanged: (bool v) => value = v)),
      );
      await tester.tap(find.byType(OhosSwitch));
      await tester.pump();
      expect(value, isTrue);
    });
  });

  group('OhosNavigationBar', () {
    testWidgets('switches current index on tap', (WidgetTester tester) async {
      int index = 0;
      await tester.pumpWidget(
        wrap(
          OhosNavigationBar(
            currentIndex: index,
            onDestinationSelected: (int i) => index = i,
            destinations: const <OhosNavigationDestination>[
              OhosNavigationDestination(icon: Icon(Icons.home), label: '首页'),
              OhosNavigationDestination(icon: Icon(Icons.person), label: '我的'),
            ],
          ),
        ),
      );
      await tester.tap(find.text('我的'));
      await tester.pump();
      expect(index, 1);
    });
  });

  group('OhosTextField', () {
    testWidgets('accepts input and reports changes', (
      WidgetTester tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        wrap(
          OhosTextField(
            hintText: '输入内容',
            onChanged: (String text) => result = text,
          ),
        ),
      );
      await tester.enterText(find.byType(OhosTextField), 'hello');
      expect(result, 'hello');
      expect(find.text('输入内容'), findsOneWidget);
    });
  });

  group('OhosAlertDialog', () {
    testWidgets('shows dialog and resolves action result', (
      WidgetTester tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) {
                return Center(
                  child: OhosButton(
                    onPressed: () async {
                      result = await showOhosDialog<bool>(
                        context: context,
                        title: '标题',
                        content: '内容',
                        actions: <OhosDialogAction>[
                          OhosDialogAction(
                            label: '取消',
                            onPressed: () => Navigator.pop(context, false),
                          ),
                          OhosDialogAction(
                            label: '确认',
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ],
                      );
                    },
                    child: const Text('打开'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('标题'), findsOneWidget);
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('OhosChipGroup', () {
    testWidgets('single-select mode reports tapped index', (
      WidgetTester tester,
    ) async {
      int? selected;
      await tester.pumpWidget(
        wrap(
          OhosChipGroup(
            items: const <OhosChipItem>[
              OhosChipItem(label: Text('推荐')),
              OhosChipItem(label: Text('关注')),
              OhosChipItem(label: Text('热榜')),
            ],
            selectedIndex: 0,
            onSelected: (int i) => selected = i,
          ),
        ),
      );
      await tester.tap(find.text('关注'));
      expect(selected, 1);
    });

    testWidgets('multiple-select mode toggles a set', (
      WidgetTester tester,
    ) async {
      Set<int>? result;
      await tester.pumpWidget(
        wrap(
          OhosChipGroup(
            multiple: true,
            selectedIndexes: const <int>{0},
            onSelectionChanged: (Set<int> s) => result = s,
            items: const <OhosChipItem>[
              OhosChipItem(label: Text('A')),
              OhosChipItem(label: Text('B')),
            ],
          ),
        ),
      );
      await tester.tap(find.text('A'));
      expect(result, <int>{});
      await tester.tap(find.text('B'));
      expect(result, <int>{0, 1});
    });

    testWidgets('capsule tab bar switches pages', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          DefaultTabController(
            length: 2,
            child: Column(
              children: const <Widget>[
                OhosTabBar(
                  type: OhosTabBarType.capsule,
                  tabs: <Widget>[
                    Tab(text: '一'),
                    Tab(text: '二'),
                  ],
                ),
                SizedBox(
                  height: 80,
                  child: TabBarView(
                    children: <Widget>[Text('页面一'), Text('页面二')],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('二'));
      await tester.pumpAndSettle();
      expect(find.text('页面二'), findsOneWidget);
    });
  });

  group('OhosResponsiveBuilder', () {
    testWidgets('resolves breakpoints from window width', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      OhosWindowSize? size;
      await tester.pumpWidget(
        wrap(
          OhosResponsiveBuilder(
            builder: (BuildContext context, OhosWindowSize s) {
              size = s;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(size!.type, OhosWindowSizeType.compact);
      expect(size!.columns, 4);
      expect(size!.margin, 16);
      expect(size!.gutter, 8);
    });

    test('fromWidth maps official breakpoints', () {
      expect(OhosWindowSize.fromWidth(300).type, OhosWindowSizeType.compact);
      expect(OhosWindowSize.fromWidth(600).columns, 8);
      expect(OhosWindowSize.fromWidth(600).margin, 24);
      expect(OhosWindowSize.fromWidth(840).type, OhosWindowSizeType.large);
      expect(OhosWindowSize.fromWidth(840).columns, 12);
      expect(OhosWindowSize.fromWidth(840).margin, 32);
    });
  });

  group('OhosAppBar', () {
    /// OpenHarmony 上应用基本都是沉浸式（edge-to-edge），状态栏直接压在顶栏上。
    /// `Scaffold` 给 `appBar` 槽位预留的高度是
    /// `preferredSize.height + MediaQuery.padding.top`，所以组件自己把这段内边距
    /// 算进去就够了 —— 调用方不需要再包 `SafeArea`，`preferredSize` 也不用改。
    // 测试画布默认 800vp 宽，`MediaQuery.size` 只改数据、不改布局约束，
    // 所以用 `SizedBox(width:)` 真正把栏宽定成 360vp，横向断言才有意义。
    Widget host({
      required double topPadding,
      required OhosAppBar bar,
      double width = 360,
    }) {
      return OhosTheme(
        data: OhosThemeData.light(),
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              padding: EdgeInsets.only(top: topPadding),
            ),
            // `home` 拿到的是路由给的紧约束，直接套 `SizedBox(width:)` 会被无视，
            // 先用 `Align` 松开约束再把栏宽定成 360vp。
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: Scaffold(appBar: bar, body: const SizedBox.expand()),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('primary 默认吃掉状态栏内边距：栏高 = height + inset，标题下移',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          topPadding: 24,
          bar: const OhosAppBar(title: Text('标题')),
        ),
      );

      expect(tester.getSize(find.byType(OhosAppBar)).height, 56 + 24);
      // 标题仍在 56 的工具栏区域正中（24 + 28），不是被状态栏压到顶上
      expect(tester.getCenter(find.text('标题')).dy, 52);
    });

    testWidgets('状态栏为 0 时保持 56（桌面/无状态栏场景不变）',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(topPadding: 0, bar: const OhosAppBar(title: Text('标题'))),
      );
      expect(tester.getSize(find.byType(OhosAppBar)).height, 56);
    });

    testWidgets('primary: false 不吃内边距（调用方自己处理时用）',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          topPadding: 24,
          bar: const OhosAppBar(primary: false, title: Text('标题')),
        ),
      );
      expect(tester.getSize(find.byType(OhosAppBar)).height, 56);
    });

    test('preferredSize 不含状态栏：Scaffold 已经加过一次，重复加会多留一条',
        () {
      const OhosAppBar bar = OhosAppBar(title: Text('t'));
      expect(bar.preferredSize, const Size.fromHeight(56));
    });

    testWidgets('leading / 标题 / actions 单行排布，标题不会压到右侧动作上',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          topPadding: 0,
          bar: OhosAppBar(
            leading: OhosIconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () {},
            ),
            title: const Text('标题'),
            actions: <Widget>[
              OhosIconButton(icon: const Icon(Icons.search), onPressed: () {}),
            ],
          ),
        ),
      );

      final Rect leading = tester.getRect(
        find.widgetWithIcon(OhosIconButton, Icons.arrow_back_ios_new_rounded),
      );
      final Rect title = tester.getRect(find.text('标题'));
      final Rect actions = tester.getRect(
        find.widgetWithIcon(OhosIconButton, Icons.search),
      );

      // 三段从左到右依次占位，谁也不叠在谁上面
      expect(leading.right, lessThanOrEqualTo(title.left));
      expect(title.right, lessThanOrEqualTo(actions.left));
      // 同一行：三者的垂直中心都落在 56vp 工具栏的正中
      expect(leading.center.dy, moreOrLessEquals(28, epsilon: 0.5));
      expect(title.center.dy, moreOrLessEquals(28, epsilon: 0.5));
      expect(actions.center.dy, moreOrLessEquals(28, epsilon: 0.5));
    });

    testWidgets('只有 actions 时标题居中于「剩余空间」而不是整栏中轴',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          topPadding: 0,
          bar: OhosAppBar(
            title: const Text('标题'),
            actions: <Widget>[
              OhosIconButton(
                icon: const Icon(Icons.search),
                size: 40,
                iconSize: 20,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      // 360vp 宽的栏，右侧动作占 40 + 4(Row 尾部留白) + 4(右边距) = 48vp，
      // 标题在剩下的 0…312 里居中。
      expect(tester.getCenter(find.text('标题')).dx, moreOrLessEquals(156));
    });

    testWidgets('长标题被约束在剩余空间内，不溢出也不盖住动作',
        (WidgetTester tester) async {
      const String long = '这是一条很长的标题文字用于检查排布';
      await tester.pumpWidget(
        host(
          topPadding: 0,
          bar: OhosAppBar(
            leading: OhosIconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () {},
            ),
            title: const Text(long),
            actions: <Widget>[
              OhosIconButton(icon: const Icon(Icons.search), onPressed: () {}),
            ],
          ),
        ),
      );

      final Rect title = tester.getRect(find.text(long));
      final Rect actions = tester.getRect(
        find.widgetWithIcon(OhosIconButton, Icons.search),
      );
      // 标题只拿到 leading 与 actions 之间的宽度（52…304，去掉左右 8vp 内边距）
      expect(title.width, lessThanOrEqualTo(304 - 52 - 16));
      expect(title.right, lessThanOrEqualTo(actions.left));
      expect(tester.takeException(), isNull);
    });

    testWidgets('titleAlignment.start 让标题贴在 leading 之后，不再强制居中',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          topPadding: 0,
          bar: OhosAppBar(
            titleAlignment: OhosAppBarTitleAlignment.start,
            leading: OhosIconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () {},
            ),
            titlePadding: const EdgeInsets.symmetric(horizontal: 12),
            title: const Text('仓库'),
          ),
        ),
      );

      final Rect leading = tester.getRect(
        find.widgetWithIcon(OhosIconButton, Icons.arrow_back_ios_new_rounded),
      );
      final Rect title = tester.getRect(find.text('仓库'));
      expect(title.left, moreOrLessEquals(leading.right + 12));
      expect(title.center.dy, moreOrLessEquals(28, epsilon: 0.5));
    });

    testWidgets('titlePadding 可收紧：窄容器里标题能拿到更多宽度',
        (WidgetTester tester) async {
      const String long = '很长很长很长的标题';
      await tester.pumpWidget(
        host(
          topPadding: 0,
          bar: OhosAppBar(
            titleAlignment: OhosAppBarTitleAlignment.start,
            titlePadding: EdgeInsets.zero,
            leading: OhosIconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () {},
            ),
            title: const Text(long),
          ),
        ),
      );

      final Rect leading = tester.getRect(
        find.widgetWithIcon(OhosIconButton, Icons.arrow_back_ios_new_rounded),
      );
      final Rect title = tester.getRect(find.text(long));
      expect(title.left, moreOrLessEquals(leading.right));
      // 单行放得下：52…360 共 308vp，足够这句 9 个汉字
      expect(title.width, lessThanOrEqualTo(360 - 52));
      expect(tester.takeException(), isNull);
    });

    testWidgets('leadingWidth 固定左侧槽宽，leading 在槽内居中',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          topPadding: 0,
          bar: OhosAppBar(
            leadingWidth: 96,
            leading: OhosIconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () {},
            ),
            title: const Text('标题'),
          ),
        ),
      );

      final Rect leading = tester.getRect(
        find.widgetWithIcon(OhosIconButton, Icons.arrow_back_ios_new_rounded),
      );
      expect(leading.center.dx, moreOrLessEquals(48));
      // 标题的可用区从 96 起算，而不是 52
      expect(
        tester.getCenter(find.text('标题')).dx,
        moreOrLessEquals((96 + 360) / 2),
      );
    });

    testWidgets('bottom 并入 preferredSize，工具栏高度不变', (WidgetTester tester) async {
      const PreferredSize bottom = PreferredSize(
        preferredSize: Size.fromHeight(40),
        child: SizedBox(height: 40, child: Text('标签')),
      );
      const OhosAppBar bar = OhosAppBar(title: Text('标题'), bottom: bottom);
      expect(bar.preferredSize, const Size.fromHeight(96));

      await tester.pumpWidget(host(topPadding: 0, bar: bar));
      expect(tester.getSize(find.byType(OhosAppBar)).height, 96);
      // 标题仍在 56vp 的工具栏里，不会被 bottom 挤下去
      expect(tester.getCenter(find.text('标题')).dy, 28);
      expect(tester.getRect(find.text('标签')).top, greaterThanOrEqualTo(56));
    });

    testWidgets('systemOverlayStyle 通过 AnnotatedRegion 交给系统状态栏',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          topPadding: 0,
          bar: const OhosAppBar(
            title: Text('标题'),
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
        ),
      );

      final AnnotatedRegion<SystemUiOverlayStyle> region = tester
          .widget(find.byType(AnnotatedRegion<SystemUiOverlayStyle>));
      expect(region.value, SystemUiOverlayStyle.light);
    });

    testWidgets('没显式传 controller 时退回 PrimaryScrollController',
        (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: PrimaryScrollController(
              controller: controller,
              child: const Scaffold(
                appBar: OhosAppBar(
                  title: Text('标题'),
                  scrollEffect: OhosAppBarScrollEffectOptions(
                    effect: OhosAppBarScrollEffectType.commonBlur,
                  ),
                ),
                body: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
