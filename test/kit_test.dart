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
  group('OhosPressShadow', () {
    testWidgets('does not throw on press and releases', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OhosPressShadow(
            type: OhosPressShadowType.blendGradient,
            child: Container(width: 120, height: 80, color: Colors.blueGrey),
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(OhosPressShadow)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(30, 10));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('OhosSideMenu', () {
    testWidgets('expands sub items and reports selection', (
      WidgetTester tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 240,
            height: 320,
            child: OhosSideMenu(
              items: const <OhosSideMenuItem>[
                OhosSideMenuItem(label: '收件箱'),
                OhosSideMenuItem(
                  label: '消息',
                  subItems: <OhosSideMenuSubItem>[
                    OhosSideMenuSubItem(label: '短信'),
                    OhosSideMenuSubItem(label: '通知'),
                  ],
                ),
              ],
              onSelected: (String v) => selected = v,
            ),
          ),
        ),
      );
      expect(find.text('短信'), findsNothing);
      await tester.tap(find.text('消息'));
      await tester.pumpAndSettle();
      expect(find.text('短信'), findsOneWidget);
      await tester.tap(find.text('短信'));
      expect(selected, '短信');
    });

    // 选中背板只能有一块，且必须只在选中行上。
    //
    // 这条守的是一个真实踩过的坑：`emphasizeSecondaryColor` 本身就是 **20%
    // alpha 的品牌色**（不是「强调色的不透明版」），早先的判据只看了「墨屏
    // 是否透明」，漏掉 `selected`，于是同一块背板被铺到每一行上 —— 渲染出来
    // 整列全亮，反而看不出选的是哪一项。
    testWidgets('选中背板只有一块，且只在选中行', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 240,
            height: 320,
            child: OhosSideMenu(
              items: const <OhosSideMenuItem>[
                OhosSideMenuItem(label: '收件箱'),
                OhosSideMenuItem(label: '消息'),
                OhosSideMenuItem(label: '日程'),
              ],
              selectedValue: '消息',
            ),
          ),
        ),
      );
      final OhosThemeData theme = OhosThemeData.light();
      final Finder pills = find.byWidgetPredicate(
        (Widget w) =>
            w is DecoratedBox &&
            (w.decoration as BoxDecoration?)?.color ==
                theme.emphasizeSecondaryColor,
      );
      expect(pills, findsOneWidget, reason: '三行里只该有一块选中背板');
      // 背板必须落在「消息」那一行上
      final Rect pill = tester.getRect(pills);
      final Rect label = tester.getRect(find.text('消息'));
      expect(pill.top, lessThanOrEqualTo(label.top));
      expect(pill.bottom, greaterThanOrEqualTo(label.bottom));
    });

    // 药丸的左右内缩是官方 `pattern.sidebar_sidemenu_menuitem_padding_level8`
    // = 16vp。断「列表 padding 的实际值」，因为那才是内缩的来源 —— 曾经
    // `itemInset` 这个常量声明了 16 却没人用，实际走的是 `spaceSm = 12`，
    // 常量与生效值对不上。
    testWidgets('药丸左右内缩 = 官方 16vp', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 240,
            height: 320,
            child: OhosSideMenu(
              items: const <OhosSideMenuItem>[OhosSideMenuItem(label: '消息')],
              // 没有选中项就没有背板，几何断言无从下手
              selectedValue: '消息',
            ),
          ),
        ),
      );
      final ListView list = tester.widget<ListView>(find.byType(ListView));
      expect(
        list.padding,
        const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: OhosSideMenu.itemInset,
        ),
      );
      expect(OhosSideMenu.itemInset, 16);
      // 实际几何：背板左右各内缩 16 ⇒ 宽 240 − 32 = 208。
      //
      // **不能用 `pill.left` 直接比 16**：`wrap` 外面套着 `Center`，屏幕
      // 800 宽时 240 的面板从 x=280 起，`getRect` 给的是全局坐标，算出来
      // 296。宽度与父级无关，是这里唯一稳的量。
      final OhosThemeData theme = OhosThemeData.light();
      final Rect pill = tester.getRect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration?)?.color ==
                  theme.emphasizeSecondaryColor,
        ),
      );
      expect(pill.width, moreOrLessEquals(240 - 16 * 2, epsilon: 0.01));
    });

    // 展开 / 折叠必须有过渡：一级项下方的兄弟会在同一帧整体位移，没有动画
    // 就是内容瞬移。这里在动画中途取高度，它必须**严格介于** 0 与终值之间。
    testWidgets('展开有过渡：中途高度介于 0 与终值之间', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 240,
            height: 320,
            child: OhosSideMenu(
              items: const <OhosSideMenuItem>[
                OhosSideMenuItem(
                  label: '消息',
                  subItems: <OhosSideMenuSubItem>[
                    OhosSideMenuSubItem(label: '短信'),
                    OhosSideMenuSubItem(label: '通知'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      final Finder animated = find.byType(AnimatedSize);
      expect(animated, findsOneWidget);
      final double collapsed = tester.getSize(animated).height;
      expect(collapsed, 0);

      await tester.tap(find.text('消息'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final double mid = tester.getSize(animated).height;

      await tester.pumpAndSettle();
      final double expanded = tester.getSize(animated).height;
      expect(expanded, greaterThan(0));
      expect(mid, greaterThan(collapsed), reason: '动画中途必须已经开始长高');
      expect(mid, lessThan(expanded), reason: '中途不该已经是终值（那就没有动画）');
    });
  });

  group('OhosListItem', () {
    testWidgets('reveals swipe actions and fires their callback', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 320,
            height: 64,
            child: OhosListItem(
              actions: <OhosSwipeAction>[
                OhosSwipeAction(
                  icon: const Icon(Icons.delete_outline_rounded),
                  backgroundColor: Colors.red,
                  onTap: () => taps++,
                ),
              ],
              child: Container(height: 64, color: Colors.white),
            ),
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(OhosListItem)),
      );
      // Real drags arrive as many small deltas; make sure the row still opens.
      for (int i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      // The action cell is now on screen (72px wide at the row's right edge).
      final Rect rowRect = tester.getRect(find.byType(OhosListItem));
      await tester.tapAt(Offset(rowRect.right - 36, rowRect.top + 32));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('fullDelete fires only after dragging past the threshold', (
      WidgetTester tester,
    ) async {
      int deletes = 0;
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 320,
            height: 64,
            child: OhosListItem(
              fullDelete: true,
              onFullDelete: () => deletes++,
              actions: <OhosSwipeAction>[
                OhosSwipeAction(icon: const Icon(Icons.delete), onTap: () {}),
              ],
              child: Container(height: 64, color: Colors.white),
            ),
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(OhosListItem)),
      );
      for (int i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(deletes, 1);
    });

    testWidgets('isSelected 铺强调色 10% 背板，未选中不铺', (WidgetTester tester) async {
      Widget frame(bool selected) => wrap(
        SizedBox(
          width: 320,
          height: 64,
          child: OhosListItem(
            isSelected: selected,
            child: Container(height: 64, color: Colors.white),
          ),
        ),
      );

      await tester.pumpWidget(frame(true));
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(OhosListItem),
          matching: find.byType(DecoratedBox),
        ),
      );
      final Color expected = OhosThemeData.light().highlightColor.withValues(
        alpha: 0.1,
      );
      expect((box.decoration as BoxDecoration).color, expected);

      await tester.pumpWidget(frame(false));
      final DecoratedBox box2 = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(OhosListItem),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((box2.decoration as BoxDecoration).color, isNull);
    });

    testWidgets('墨屏下 isSelected 不铺透明底，改画 1px 实色描边', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  height: 64,
                  child: OhosListItem(
                    isSelected: true,
                    child: Container(height: 64, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final BoxDecoration decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(OhosListItem),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      // 10% 浅底在墨屏判透明，不铺；选中态靠 1px 实色描边承载。
      expect(decoration.color, isNull);
      expect(decoration.border, isNotNull);
      final BorderSide side = decoration.border!.top;
      expect(side.color.a, 1);
      expect(side.width, greaterThan(0));
    });

    testWidgets('墨屏选中描边不参与布局：切换选中时内容不位移', (WidgetTester tester) async {
      // 描边画在装饰层（`BoxDecoration`）里，不是 `Container` 的 padding，
      // 所以只影响绘制、不影响布局。这条用例盯的就是「别为了画这条线去加
      // padding」——那会让选中/取消时整行内容左右各跳 1vp。
      Widget build({required bool selected}) => OhosTheme(
        data: OhosThemeData.ink(),
        child: MaterialApp(
          home: OhosScaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 64,
                child: OhosListItem(
                  isSelected: selected,
                  child: Container(
                    key: const Key('row-content'),
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(selected: false));
      final Rect before = tester.getRect(find.byKey(const Key('row-content')));
      final BoxDecoration unselected =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(OhosListItem),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(unselected.border, isNull, reason: '未选中不该有描边');

      await tester.pumpWidget(build(selected: true));
      final Rect after = tester.getRect(find.byKey(const Key('row-content')));
      expect(after, before, reason: '选中只改绘制，不该挪动内容');
    });
  });

  group('OhosColorPicker', () {
    testWidgets('spectrum mode picks a color from the SV box', (
      WidgetTester tester,
    ) async {
      final List<Color> picked = <Color>[];
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 320,
            child: OhosColorPicker(
              colors: const <Color>[Color(0xFF0A59F7)],
              selectedColor: const Color(0xFF0A59F7),
              onChanged: picked.add,
              tabs: const <OhosColorPickerTab>[
                OhosColorPickerTab.grid,
                OhosColorPickerTab.spectrum,
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('光谱'));
      await tester.pumpAndSettle();
      expect(picked, isEmpty);
      // Tap inside the saturation/value box (lower half of the picker).
      final Rect pickerRect = tester.getRect(find.byType(OhosColorPicker));
      await tester.tapAt(
        Offset(
          pickerRect.left + pickerRect.width * 0.7,
          pickerRect.bottom - 90,
        ),
      );
      await tester.pump();
      expect(picked, isNotEmpty);
    });
  });
}
