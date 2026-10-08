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
    testWidgets('does not throw on press and releases', (WidgetTester tester) async {
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
        Offset(pickerRect.left + pickerRect.width * 0.7, pickerRect.bottom - 90),
      );
      await tester.pump();
      expect(picked, isNotEmpty);
    });
  });
}
