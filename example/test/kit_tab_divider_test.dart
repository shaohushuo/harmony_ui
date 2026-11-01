import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmony_ui/harmony_ui.dart';
import 'package:ohos_ui_example/pages/kit_page.dart';

/// 「子页签分割线」示例：三个页面各自滚动，切页签时 `TabBarView` 会同时挂着
/// 相邻两页 —— 共用一份 `ScrollController` 会在切换瞬间抛
/// "ScrollController attached to multiple scroll views"，debug 下表现为红屏闪烁。
void main() {
  testWidgets('切换页签不抛 ScrollController 冲突', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OhosTheme(
        data: OhosThemeData.light(),
        child: const MaterialApp(home: KitPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 这个示例在页面靠下，外层是可滚动体，先把它滚进视口
    await tester.dragUntilVisible(
      find.text('关注'),
      find.byType(Scrollable).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('关注').first);
    await tester.pumpAndSettle();

    // 确认真的切到了第二页（只切成功时才会滚出「第 1 页」的条目），
    // 否则下面的「无异常」会因为压根没触发切换而假通过。
    expect(find.textContaining('第 1 页'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('横滑切页不会撞 ScrollController', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OhosTheme(
        data: OhosThemeData.light(),
        child: const MaterialApp(home: KitPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('关注'),
      find.byType(Scrollable).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    // 横滑时 TabBarView 会同时挂着相邻两页 —— 三页共用一份 ScrollController
    // 就会在这里抛 "attached to multiple scroll views"。
    await tester.drag(find.byType(TabBarView), const Offset(-320, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
