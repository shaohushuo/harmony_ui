import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmony_ui/harmony_ui.dart';
import 'package:ohos_ui_example/main.dart';
import 'package:ohos_ui_example/theme_switch.dart';

/// 顶栏主题切换：点按在 浅色 → 深色 → 墨水屏 之间循环、长按列出全部档位
/// （含深色墨水屏）、切完页面的组件主题真的换了，而且不会把人从当前演示页
/// 弹回首页（`MaterialApp` 是原地重建，Navigator 的 State 复用）。
///
/// 这里刻意钉住「深色是一等对照项」：早期实现（直接用库的
/// `OhosThemeToggleButton`）点按是「彩屏 ↔ 墨水屏」翻转，深色只能进长按菜单，
/// 结果就是从浅色点一下直接跳到黑底白字的电子纸，深色档走不到。
void main() {
  OhosThemeData themeOf(WidgetTester tester) =>
      OhosTheme.of(tester.element(find.byType(HomePage).first));

  /// 每个用例都从浅色起步，避免全局单例把上一例的终点带进来。
  void resetTheme() {
    galleryTheme.useMode(OhosThemeMode.light);
  }

  setUp(resetTheme);
  tearDown(resetTheme);

  /// 把默认平台换成 iOS 再跑测试体。
  ///
  /// 不是为了让测试「能在 mac 上跑」—— 是因为 Material 在 **Android** 平台默认
  /// 用水波纹 `InkSparkle`，它第一次被画出来时去加载
  /// `shaders/ink_sparkle.frag`；本仓库的 `flutter_tester` 解析那个 asset 会抛
  /// `manifest could not be decoded`（既有环境问题，与主题无关 —— 切到墨水屏
  /// 同样会触发）。iOS 的水波纹是 `InkRipple`，纯 Dart 实现，不碰 shader。
  ///
  /// 覆盖必须发生在 `runTest` 内部、并在**测试体退出前**复原：`addTearDown`
  /// 排在 `_verifyInvariants` 之后，用它复原会被判成「测试结束时调试变量未复原」。
  Future<void> onIOS(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets(
    '点一下从浅色进深色',
    (WidgetTester tester) => onIOS(() async {
      await tester.pumpWidget(const OhosUiGalleryApp());
      await tester.pumpAndSettle();

      expect(themeOf(tester).brightness, Brightness.light);
      expect(themeOf(tester).monochrome, isFalse);

      await tester.tap(find.byType(ThemeSwitchButton));
      await tester.pumpAndSettle();

      expect(galleryTheme.mode, OhosThemeMode.dark);
      expect(themeOf(tester).brightness, Brightness.dark);
      // 深色是彩屏档位，不该顺带把表现规则换成墨水屏
      expect(themeOf(tester).monochrome, isFalse);
      // 只改档位而不改色值会渲染成「深色模式却还是白底」，这里一并钉住
      expect(
        themeOf(tester).backgroundColor,
        isNot(OhosThemeData.light().backgroundColor),
      );
    }),
  );

  testWidgets(
    '再点一下进墨水屏，第三次回到浅色',
    (WidgetTester tester) => onIOS(() async {
      await tester.pumpWidget(const OhosUiGalleryApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ThemeSwitchButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ThemeSwitchButton));
      await tester.pumpAndSettle();

      expect(galleryTheme.mode, OhosThemeMode.ink);
      expect(themeOf(tester).monochrome, isTrue);
      // 浅色墨水屏是白纸黑字
      expect(themeOf(tester).brightness, Brightness.light);

      await tester.tap(find.byType(ThemeSwitchButton));
      await tester.pumpAndSettle();

      expect(galleryTheme.mode, OhosThemeMode.light);
      expect(themeOf(tester).monochrome, isFalse);
    }),
  );

  testWidgets(
    '从深色进墨水屏再 toggle 回来，回到的是深色而不是浅色',
    (WidgetTester tester) => onIOS(() async {
      await tester.pumpWidget(const OhosUiGalleryApp());
      await tester.pumpAndSettle();

      // 浅色 -> 深色 -> 墨水屏
      await tester.tap(find.byType(ThemeSwitchButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ThemeSwitchButton));
      await tester.pumpAndSettle();
      expect(galleryTheme.mode, OhosThemeMode.ink);

      // 这里刻意用 controller 的 toggle 而不是按钮的循环：两者不是同一件事。
      // 按钮循环是「往前走一格」（墨屏的下一格是浅色），toggle 才是「回到离开时
      // 那个彩屏主题」。要验证的是后者有没有记住深色。
      galleryTheme.toggle();
      await tester.pumpAndSettle();

      expect(themeOf(tester).monochrome, isFalse);
      expect(themeOf(tester).brightness, Brightness.dark);
    }),
  );

  testWidgets(
    '长按弹出全部档位菜单，选深色后主题跟着换',
    (WidgetTester tester) => onIOS(() async {
      await tester.pumpWidget(const OhosUiGalleryApp());
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(ThemeSwitchButton));
      await tester.pumpAndSettle();

      expect(find.text('浅色'), findsOneWidget);
      expect(find.text('深色'), findsOneWidget);
      expect(find.text('墨水屏'), findsOneWidget);
      // 深色墨水屏不在枚举里，但画廊要能在菜单里选到
      expect(find.text('深色墨水屏'), findsOneWidget);

      await tester.tap(find.text('深色'));
      await tester.pumpAndSettle();

      expect(galleryTheme.mode, OhosThemeMode.dark);
      expect(themeOf(tester).brightness, Brightness.dark);
      expect(themeOf(tester).monochrome, isFalse);
    }),
  );

  testWidgets(
    '菜单里能选到深色墨水屏（黑纸白字）',
    (WidgetTester tester) => onIOS(() async {
      await tester.pumpWidget(const OhosUiGalleryApp());
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(ThemeSwitchButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('深色墨水屏'));
      await tester.pumpAndSettle();

      // 墨屏 + 深色纸：两个维度同时成立，正是 brightness 语义拆开后才表达得出的
      expect(themeOf(tester).monochrome, isTrue);
      expect(themeOf(tester).brightness, Brightness.dark);
      expect(themeOf(tester).id, 'ink_dark');
    }),
  );

  testWidgets(
    '停在深色墨水屏时点按能走出来（自定义主题没有档位）',
    (WidgetTester tester) => onIOS(() async {
      await tester.pumpWidget(const OhosUiGalleryApp());
      await tester.pumpAndSettle();

      showDarkInk();
      await tester.pumpAndSettle();
      expect(galleryTheme.mode, OhosThemeMode.ink);
      expect(themeOf(tester).id, 'ink_dark');

      // 自定义主题下点按不能是空操作，否则按钮看起来失灵
      await tester.tap(find.byType(ThemeSwitchButton));
      await tester.pumpAndSettle();
      expect(galleryTheme.mode, OhosThemeMode.light);
      expect(themeOf(tester).monochrome, isFalse);
    }),
  );

  testWidgets(
    '在演示页里切主题不会把人弹回首页',
    (WidgetTester tester) => onIOS(() async {
      await tester.pumpWidget(const OhosUiGalleryApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('导航类'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsNothing);

      // 演示页共用 `DemoScaffold`，按钮也在它的顶栏上
      await tester.tap(find.byType(ThemeSwitchButton));
      await tester.pumpAndSettle();

      // 深层页面里也能切换主题
      expect(galleryTheme.mode, OhosThemeMode.dark);
      // 还在导航类页面：首页的分类列表没有回来
      expect(find.byType(HomePage), findsNothing);
      expect(find.text('UI Design Kit'), findsNothing);
    }),
  );
}
