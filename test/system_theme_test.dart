import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harmony_ui/harmony_ui.dart';

/// 把系统亮度包到被测子树上面。
///
/// 真实场景里这层 `MediaQuery` 由 `View` 提供，`platformBrightness` 跟着
/// 系统设置变、并让依赖它的 widget 重建。测试里直接换 `MediaQueryData`，
/// 模拟同一个过程 —— 关键是验证「亮度从 context 流下来，主题跟着翻」，
/// 而不是验证 Flutter 自己会不会通知。
Widget hostBrightness(Brightness brightness, Widget child) {
  return MediaQuery(
    data: MediaQueryData(platformBrightness: brightness),
    child: child,
  );
}

void main() {
  // 这一组守的是「跟随系统」这一档真的能跟随。核心风险不是取不到亮度，
  // 而是**为了取亮度把值塞回 controller**，于是 build 期间 notifyListeners
  // 触发重建 —— 直接抛 `setState() or markNeedsBuild() called during build`。
  // 所以这里既断言结果，也断言过程中没有异常。
  group('跟随系统', () {
    test('枚举有 system 档，且它不属于灰阶屏', () {
      expect(OhosThemeMode.values, contains(OhosThemeMode.system));
      expect(OhosThemeMode.system.label, '跟随系统');
      expect(OhosThemeMode.system.followsSystem, isTrue);
      expect(
        OhosThemeMode.system.isMonochrome,
        isFalse,
        reason: '系统亮度是「颜色外观」维度，与是不是灰阶屏无关',
      );
      for (final OhosThemeMode other in OhosThemeMode.values) {
        if (other != OhosThemeMode.system) {
          expect(other.followsSystem, isFalse);
        }
      }
    });

    test('theme() 按传入亮度解析出对应预设', () {
      expect(
        OhosThemeMode.system.theme(systemBrightness: Brightness.dark).id,
        'dark',
      );
      expect(
        OhosThemeMode.system.theme(systemBrightness: Brightness.light).id,
        'light',
      );
    });

    test('不传亮度时给安全默认（浅色），不是抛异常', () {
      // 首帧拿不到亮度的场景不该崩，也不该莫名其妙地变深色
      expect(OhosThemeMode.system.theme().id, 'light');
    });

    test('resolveTheme 是纯函数：不写状态、不通知', () {
      final OhosThemeController controller = OhosThemeController(
        initialMode: OhosThemeMode.system,
      );
      int notifications = 0;
      controller.addListener(() => notifications++);

      // 反复解析不同亮度，一次都不该通知 —— 否则 Switcher 在 build 里调用
      // 它就是「build 期间 markNeedsBuild」的定时炸弹
      for (final Brightness probe in <Brightness>[
        Brightness.light,
        Brightness.dark,
        Brightness.light,
      ]) {
        controller.resolveTheme(systemBrightness: probe);
      }
      expect(notifications, 0);
      expect(controller.mode, OhosThemeMode.system, reason: '档位不该被写动');
    });

    test('resolveTheme 按亮度给出不同主题', () {
      final OhosThemeController controller = OhosThemeController(
        initialMode: OhosThemeMode.system,
      );
      expect(
        controller.resolveTheme(systemBrightness: Brightness.dark).isDark,
        isTrue,
      );
      expect(
        controller.resolveTheme(systemBrightness: Brightness.light).isDark,
        isFalse,
      );
    });

    // 非 system 档必须无视外部亮度，否则「我选了深色、系统是浅色」会被
    // 静默改回浅色 —— 用户的明确选择不该被系统事实覆盖。
    test('非 system 档忽略传入亮度', () {
      for (final OhosThemeMode mode in <OhosThemeMode>[
        OhosThemeMode.light,
        OhosThemeMode.dark,
        OhosThemeMode.ink,
      ]) {
        final OhosThemeController controller = OhosThemeController(
          initialMode: mode,
        );
        final OhosThemeData resolved = controller.resolveTheme(
          systemBrightness: Brightness.dark,
        );
        expect(
          resolved,
          controller.themeData,
          reason: '$mode 不该被系统亮度改写',
        );
      }
    });

    test('materialThemeOf 与 resolveTheme 的亮度保持一致', () {
      final OhosThemeController controller = OhosThemeController(
        initialMode: OhosThemeMode.system,
      );
      for (final Brightness probe in Brightness.values) {
        expect(
          controller.materialThemeOf(systemBrightness: probe).brightness,
          controller.resolveTheme(systemBrightness: probe).brightness,
          reason: '两套主题对不齐时，Scaffold 底色会和组件色打架',
        );
      }
    });

    // 从 system 档进墨水屏再回来，必须回到「离开时那个具体明暗」，而不是
    // 停在 system 上 —— 后者会让 toggle 变成一个单向门：进去再出来就再也
    // 回不到手上这档，且 _lastColorMode 永远读不回具体值。
    test('system 档进墨水屏再切回，落在离开时的具体档位', () {
      final OhosThemeController controller = OhosThemeController(
        initialMode: OhosThemeMode.system,
        systemBrightness: Brightness.dark,
      );
      expect(controller.mode, OhosThemeMode.system, reason: '初始仍是跟随系统');

      controller.toggle();
      expect(controller.isInk, isTrue);

      controller.toggle();
      expect(
        controller.mode,
        OhosThemeMode.dark,
        reason: '在深色系统下离开的，回来应是深色档而不是 system 档',
      );
      expect(controller.themeData.isDark, isTrue);
    });

    test('以 system + 深色初始化时，toggle 回来仍保留深色', () {
      final OhosThemeController controller = OhosThemeController(
        initialMode: OhosThemeMode.system,
        systemBrightness: Brightness.dark,
        fontFamily: 'HarmonyOS Sans',
      );
      // 构造函数按播种亮度解析，识别得到深色
      expect(controller.themeData.isDark, isTrue);
      expect(controller.themeData.typography.fontFamily, 'HarmonyOS Sans');

      controller.toggle();
      controller.toggle();

      expect(controller.themeData.isDark, isTrue);
      expect(controller.themeData.typography.fontFamily, 'HarmonyOS Sans');
    });
  });

  group('OhosThemeSwitcher 跟随系统亮度', () {
    Widget app(OhosThemeController controller) => OhosThemeSwitcher(
      controller: controller,
      builder: (BuildContext context, ThemeData material) => MaterialApp(
        theme: material,
        home: OhosScaffold(
          body: Builder(
            builder: (BuildContext context) {
              final OhosThemeData theme = OhosTheme.of(context);
              return Text(theme.isDark ? 'dark' : 'light');
            },
          ),
        ),
      ),
    );

    testWidgets('首帧按系统亮度出主题（深色）', (WidgetTester tester) async {
      final OhosThemeController controller = OhosThemeController(
        initialMode: OhosThemeMode.system,
      );
      await tester.pumpWidget(
        hostBrightness(Brightness.dark, app(controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('dark'), findsOneWidget);
    });

    testWidgets('首帧按系统亮度出主题（浅色）', (WidgetTester tester) async {
      final OhosThemeController controller = OhosThemeController(
        initialMode: OhosThemeMode.system,
      );
      await tester.pumpWidget(
        hostBrightness(Brightness.light, app(controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('light'), findsOneWidget);
    });

    // 这是「跟随系统」的核心验收：系统切深色，界面自动翻，用户什么都没点。
    testWidgets('系统亮度变化后主题自动跟着翻，且不抛 build 期异常',
        (WidgetTester tester) async {
      final OhosThemeController controller = OhosThemeController(
        initialMode: OhosThemeMode.system,
      );

      Widget build(Brightness brightness) =>
          hostBrightness(brightness, app(controller));

      await tester.pumpWidget(build(Brightness.light));
      await tester.pumpAndSettle();
      expect(find.text('light'), findsOneWidget);

      // 换一层 MediaQuery：platformBrightness 变了，Switcher 应当重建
      await tester.pumpWidget(build(Brightness.dark));
      await tester.pumpAndSettle();
      expect(find.text('dark'), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: '在 build 里 notifyListeners 会抛 '
            'setState() or markNeedsBuild() called during build',
      );

      // 再翻回来
      await tester.pumpWidget(build(Brightness.light));
      await tester.pumpAndSettle();
      expect(find.text('light'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Material 主题同步跟随，Scaffold 不会闪错色',
        (WidgetTester tester) async {
      final OhosThemeController controller = OhosThemeController(
        initialMode: OhosThemeMode.system,
      );

      Brightness? materialBrightness;
      await tester.pumpWidget(
        hostBrightness(
          Brightness.dark,
          OhosThemeSwitcher(
            controller: controller,
            builder: (BuildContext context, ThemeData material) {
              materialBrightness = material.brightness;
              return MaterialApp(theme: material, home: const SizedBox());
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(materialBrightness, Brightness.dark);
    });

    // 用户显式选深色，系统是浅色 —— 必须尊重用户，不能跟随系统。
    testWidgets('非 system 档下系统亮度变化不影响主题', (WidgetTester tester) async {
      final OhosThemeController controller = OhosThemeController(
        initialMode: OhosThemeMode.dark,
      );

      Widget build(Brightness brightness) =>
          hostBrightness(brightness, app(controller));

      await tester.pumpWidget(build(Brightness.light));
      await tester.pumpAndSettle();
      expect(find.text('dark'), findsOneWidget);

      await tester.pumpWidget(build(Brightness.light));
      await tester.pumpAndSettle();
      expect(find.text('dark'), findsOneWidget);
    });

    testWidgets('切到墨水屏后，系统亮度变化不会把墨屏改掉',
        (WidgetTester tester) async {
      final OhosThemeController controller = OhosThemeController(
        initialMode: OhosThemeMode.system,
      );

      Widget build(Brightness brightness) => hostBrightness(
        brightness,
        OhosThemeSwitcher(
          controller: controller,
          builder: (BuildContext context, ThemeData material) => MaterialApp(
            theme: material,
            home: OhosScaffold(
              body: Builder(
                builder: (BuildContext context) {
                  final OhosThemeData theme = OhosTheme.of(context);
                  return Text('${theme.monochrome}-${theme.isDark}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(Brightness.light));
      await tester.pumpAndSettle();
      expect(find.text('false-false'), findsOneWidget);

      controller.toggle();
      await tester.pumpAndSettle();
      expect(find.text('true-false'), findsOneWidget);

      // 停在墨屏期间系统切深色
      await tester.pumpWidget(build(Brightness.dark));
      await tester.pumpAndSettle();
      expect(
        find.text('true-false'),
        findsOneWidget,
        reason: '墨水屏是用户显式选择，不该被系统亮度推翻',
      );
    });
  });

  // 组件的分支必须走策略，不能读「这是哪一档」。否则给枚举加一档就要改组件，
  // 「加主题不改 widget」这个承诺当场失效。
  group('组件层不判断具体主题类型', () {
    /// 剥掉注释再扫。
    ///
    /// 不剥的话，`ohos_text_field.dart` 里那句
    /// 「On an e-ink theme (`OhosThemeData.monochrome`) the fill ...」的**文档
    /// 注释**会被误判成分支。注释解释不了行为，只有代码才会 —— 这个测试守的
    /// 是行为约束，所以只该看代码。
    String stripComments(String source) {
      // 先块注释再行注释：块注释里可能含 `//`，反过来会切坏代码
      return source
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
          .replaceAll(RegExp(r'//[^\n]*'), '');
    }

    test('lib/src/widgets 下没有按档位分支的代码', () {
      // 用字符串拼出来，避免本行自己被扫到
      const List<String> forbidden = <String>[
        'OhosThemeMode.',
        'isMonochrome',
        '.monochrome',
      ];
      // 主题切换按钮是唯一例外：它的职责就是「显示并修改当前档位」
      final RegExp exempt = RegExp(r'ohos_theme_toggle_button\.dart$');

      final Iterable<File> files = Directory('lib/src/widgets')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .where((File f) => !exempt.hasMatch(f.path));

      final List<String> offenders = <String>[];
      for (final File file in files) {
        final String source = stripComments(file.readAsStringSync());
        for (final String token in forbidden) {
          if (source.contains(token)) {
            offenders.add('${file.path}: $token');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '组件按主题类型分支会让「新增一种屏」变成改 52 个文件：\n'
            '${offenders.join('\n')}',
      );
    });

    test('剥注释的逻辑本身可靠 —— 别让它把代码也剥掉', () {
      expect(stripComments('// a\nfinal x = 1;'), contains('final x = 1;'));
      expect(stripComments('/* a */ final x = 1;'), contains('final x = 1;'));
      expect(
        stripComments('/// 文档提到 monochrome\nfinal y = 2;'),
        isNot(contains('monochrome')),
      );
      // 真代码必须留下
      expect(
        stripComments('final isInk = theme.policy.isMonochrome;'),
        contains('isMonochrome'),
      );
    });
  });
}