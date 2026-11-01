import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmony_ui/harmony_ui.dart';
import 'package:ohos_ui_example/main.dart';
import 'package:ohos_ui_example/theme_switch.dart';

/// 顶栏主题切换：一键在普通主题与墨水屏之间切换、长按列出三档、切完页面的
/// 组件主题真的换了，而且不会把人从当前演示页弹回首页（`MaterialApp` 是原地
/// 重建，Navigator 的 State 复用）。
void main() {
  OhosThemeData themeOf(WidgetTester tester) =>
      OhosTheme.of(tester.element(find.byType(HomePage).first));

  // `galleryTheme` 是全局单例，会记住上一个用例停在哪个彩屏档位；先把它拨回
  // 浅色再进墨水屏，每个用例才有一样的起点。
  void resetTheme() {
    galleryTheme.setColorMode(OhosThemeMode.light);
    galleryTheme.mode = OhosThemeMode.ink;
  }

  setUp(resetTheme);
  tearDown(resetTheme);

  testWidgets('默认停在墨水屏，点一下回到普通主题', (WidgetTester tester) async {
    await tester.pumpWidget(const OhosUiGalleryApp());
    await tester.pumpAndSettle();

    expect(themeOf(tester).monochrome, isTrue);

    // 一键切换：不需要先开菜单
    await tester.tap(find.byType(ThemeSwitchButton));
    await tester.pumpAndSettle();

    expect(galleryTheme.mode, OhosThemeMode.light);
    expect(themeOf(tester).monochrome, isFalse);
  });

  testWidgets('再点一下回到墨水屏', (WidgetTester tester) async {
    await tester.pumpWidget(const OhosUiGalleryApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ThemeSwitchButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ThemeSwitchButton));
    await tester.pumpAndSettle();

    expect(galleryTheme.mode, OhosThemeMode.ink);
    expect(themeOf(tester).monochrome, isTrue);
  });

  testWidgets('长按弹出三档菜单，选深色后主题跟着换', (WidgetTester tester) async {
    await tester.pumpWidget(const OhosUiGalleryApp());
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(ThemeSwitchButton));
    await tester.pumpAndSettle();

    expect(find.text('浅色'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
    expect(find.text('墨水屏'), findsOneWidget);

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(galleryTheme.mode, OhosThemeMode.dark);
    expect(themeOf(tester).brightness, Brightness.dark);
    expect(themeOf(tester).monochrome, isFalse);
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

    // 直接翻转：墨水屏 -> 普通主题
    expect(galleryTheme.mode, OhosThemeMode.light);
    // 还在导航类页面：首页的分类列表没有回来
    expect(find.byType(HomePage), findsNothing);
    expect(find.text('UI Design Kit'), findsNothing);
  });
}