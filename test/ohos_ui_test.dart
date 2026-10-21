import 'package:flutter/material.dart';
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
    Widget host({required double topPadding, required OhosAppBar bar}) {
      return OhosTheme(
        data: OhosThemeData.light(),
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 800),
              padding: EdgeInsets.only(top: topPadding),
            ),
            child: Scaffold(appBar: bar, body: const SizedBox.expand()),
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
  });
}
