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
