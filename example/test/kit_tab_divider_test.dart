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
    await _scrollIntoView(tester, '关注');

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

    await _scrollIntoView(tester, '关注');

    // 横滑时 TabBarView 会同时挂着相邻两页 —— 三页共用一份 ScrollController
    // 就会在这里抛 "attached to multiple scroll views"。
    await tester.drag(find.byType(TabBarView), const Offset(-320, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

/// 把含 [text] 的组件滚进视口，**不走 `tester.drag`**。
///
/// 原来这里用 `dragUntilVisible(find.text('关注'), find.byType(Scrollable).first,
/// Offset(0, -400))`，它按 `getCenter(Scrollable)` 的坐标按下 —— 而这一页的
/// 中心点会落在「横滑列表项 / 常驻通知」这类**自己吃手势**的控件上，外层垂直
/// 视口从此收不到拖动。实测滚到 800vp 就再也不动（`maxScrollExtent` 是 3463），
/// `dragUntilVisible` 穷尽迭代后仍找不到目标，最后在
/// `Scrollable.ensureVisible(element(finder))` 上抛 `Bad state: No element`。
///
/// 这条用例要验的是「切页签不撞 `ScrollController`」，滚动只是导航手段，
/// 所以直接改 `ScrollPosition.jumpTo`：确定、可控、不依赖任何控件的手势实现。
/// （`ink_no_color_test.dart` 里踩的是同一个坑，注释里记了同一类失败。）
Future<void> _scrollIntoView(WidgetTester tester, String text) async {
  final ScrollableState viewport = tester.state<ScrollableState>(
    find.byType(Scrollable).first,
  );
  for (int screen = 0; screen < 40; screen++) {
    if (find.text(text).evaluate().isNotEmpty) {
      // 元素存在不等于可见：`ListView` 的 `cacheExtent` 会提前构建屏外条目，
      // 直接 tap 会打在被裁剪掉的坐标上。`ensureVisible` 负责把它挪进视口。
      await Scrollable.ensureVisible(tester.element(find.text(text).first));
      await tester.pumpAndSettle();
      return;
    }
    final double next = viewport.position.pixels + 300;
    if (next > viewport.position.maxScrollExtent) {
      break;
    }
    viewport.position.jumpTo(next);
    await tester.pump();
  }
  fail('滚动 40 屏后仍未找到「$text」');
}
