import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmony_ui/harmony_ui.dart';
import 'package:ohos_ui_example/main.dart';
import 'package:ohos_ui_example/theme_switch.dart';

/// 顶栏主题切换：三档能互相切、切完页面的组件主题真的换了，而且不会把人
/// 从当前演示页弹回首页（`MaterialApp` 是原地重建，Navigator 的 State 复用）。
void main() {
  OhosThemeData themeOf(WidgetTester tester) =>
      OhosTheme.of(tester.element(find.byType(HomePage)));

  setUp(() => galleryTheme.value = GalleryTheme.ink);
  tearDown(() => galleryTheme.value = GalleryTheme.ink);

  testWidgets('默认停在墨主题，按钮把三档都列出来', (WidgetTester tester) async {
    await tester.pumpWidget(const OhosUiGalleryApp());
    await tester.pumpAndSettle();

    expect(themeOf(tester).monochrome, isTrue);

    await tester.tap(find.byType(ThemeSwitchButton));
    await tester.pumpAndSettle();
    expect(find.text('浅色'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
    expect(find.text('墨主题'), findsOneWidget);
  });

  testWidgets('选浅色后组件主题跟着换（monochrome 关掉）', (WidgetTester tester) async {
    await tester.pumpWidget(const OhosUiGalleryApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ThemeSwitchButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();

    expect(galleryTheme.value, GalleryTheme.light);
    expect(themeOf(tester).monochrome, isFalse);
    expect(themeOf(tester).brightness, Brightness.light);
  });

  testWidgets('在演示页里切主题不会把人弹回首页', (WidgetTester tester) async {
    await tester.pumpWidget(const OhosUiGalleryApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('导航类'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsNothing);

    // 演示页共用 `DemoScaffold`，按钮也在它的顶栏上
    await tester.tap(find.byType(ThemeSwitchButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(galleryTheme.value, GalleryTheme.dark);
    // 还在导航类页面：首页的分类列表没有回来
    expect(find.byType(HomePage), findsNothing);
    expect(find.text('UI Design Kit'), findsNothing);
  });
}
