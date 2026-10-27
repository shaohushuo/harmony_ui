import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// 实际绘制用的颜色：`Text` 会把 `DefaultTextStyle` 合并进自己的 `RichText`，
/// 只查 `Text.style` 会漏掉「靠主题字阶上色」的场合（AppBar 标题等）。
Color? paintedColor(WidgetTester tester, String label) {
  final RichText rich = tester.widget<RichText>(
    find.descendant(of: find.text(label), matching: find.byType(RichText)),
  );
  return (rich.text as TextSpan).style?.color;
}

void _noop() {}

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

    test('ink preset is pure black on pure white, without mid-tones', () {
      final OhosThemeData ink = OhosThemeData.ink();
      expect(ink.monochrome, isTrue);
      // 墨水屏仍是「白纸黑字」，不能走 isDark 分支
      expect(ink.isDark, isFalse);
      expect(ink.brightness, Brightness.light);
      expect(ink.backgroundColor, Colors.white);
      expect(ink.cardColor, Colors.white);
      expect(ink.popupColor, Colors.white);
      expect(ink.textPrimaryColor, Colors.black);
      expect(ink.textSecondaryColor, Colors.black);
      // 三级色留给 hint：必须明显淡于正文，否则「未输入」与「已输入」同色
      expect(ink.textTertiaryColor, const Color(0xFF767676));
      // 功能色压成黑：红色在 16 级灰上是中灰，会和正文糊在一起
      expect(ink.successColor, Colors.black);
      expect(ink.warningColor, Colors.black);
      expect(ink.dangerColor, Colors.black);
      // 水波纹 / hover / focus 会留半透明灰块且刷新慢 → 全关
      expect(ink.interactiveHoverColor, Colors.transparent);
      expect(ink.interactivePressedColor, Colors.transparent);
      expect(ink.interactiveFocusColor, Colors.transparent);
      expect(ink.interactiveSelectColor, const Color(0x33000000));
      // 关键：light 预设的 10% 黑分隔线在墨水屏上等于没有
      expect(ink.dividerColor, Colors.black);
      expect(ink.multiColors.length, 11);
      expect(ink.multiColors.first, Colors.black);
      expect(ink.multiColors.last, Colors.white);
    });

    test('copyWith keeps monochrome, light/dark presets stay colorful', () {
      expect(OhosThemeData.light().monochrome, isFalse);
      expect(OhosThemeData.dark().monochrome, isFalse);
      expect(OhosThemeData.light().copyWith(monochrome: true).monochrome, isTrue);
      expect(
        OhosThemeData.ink().copyWith(highlightColor: Colors.grey).monochrome,
        isTrue,
      );
    });

    test('ink 字阶是纯黑：light 的 90% 黑在 16 级灰上会淡成中灰', () {
      final OhosTypography ink = OhosThemeData.ink().typography;
      expect(ink.bodyMedium?.color, Colors.black);
      expect(ink.titleMedium?.color, Colors.black);
      expect(ink.labelSmall?.color, Colors.black);
      expect(ink.headlineMedium?.color, Colors.black);
      // 彩屏仍用官方字阶（90% / 85% 黑）
      expect(
        OhosThemeData.light().typography.bodyMedium?.color,
        OhosTypography.textPrimary,
      );
    });

    testWidgets('ink 下没自己指定颜色的 AppBar 标题 / OhosText 渲染成纯黑', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: const MaterialApp(
            home: Scaffold(
              appBar: OhosAppBar(title: Text('标题')),
              body: Center(child: OhosText('正文')),
            ),
          ),
        ),
      );

      expect(paintedColor(tester, '标题'), Colors.black);
      expect(paintedColor(tester, '正文'), Colors.black);
    });

    // `MaterialApp` 提供 Directionality / Navigator，组件本身不再包一层。
    Widget themed(OhosThemeData data, Widget child) {
      return OhosTheme(
        data: data,
        child: MaterialApp(home: OhosScaffold(body: child)),
      );
    }

    testWidgets('ink 主题下 OhosLightMaterial 不再整层模糊', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        themed(
          OhosThemeData.ink(),
          const OhosLightMaterial(
            level: OhosLightMaterialLevel.ultraThick,
            child: SizedBox(width: 120, height: 48),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);

      // 彩屏仍然走模糊
      await tester.pumpWidget(
        themed(
          OhosThemeData.light(),
          const OhosLightMaterial(
            level: OhosLightMaterialLevel.ultraThick,
            child: SizedBox(width: 120, height: 48),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('ink 主题下输入框错误态读 theme.dangerColor，不再是硬编码红', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        themed(
          OhosThemeData.ink(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: OhosTextField(errorText: '必填'),
          ),
        ),
      );

      final InputDecoration decoration =
          tester.widget<TextField>(find.byType(TextField)).decoration!;
      final UnderlineInputBorder errorBorder =
          decoration.errorBorder! as UnderlineInputBorder;
      expect(errorBorder.borderSide.color, Colors.black);
    });

    testWidgets('ink 主题下弹层补 1px 黑描边，不靠 scrim 才分得清边界', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        themed(
          OhosThemeData.ink(),
          OhosButton(onPressed: () {}, child: const Text('打开')),
        ),
      );

      final BuildContext context = tester.element(find.text('打开'));
      showOhosDialog<void>(
        context: context,
        title: '标题',
        content: '内容',
        actions: <OhosDialogAction>[
          OhosDialogAction(
            label: '好',
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ],
      );
      await tester.pumpAndSettle();

      final Dialog dialog = tester.widget<Dialog>(find.byType(Dialog));
      final RoundedRectangleBorder shape =
          dialog.shape! as RoundedRectangleBorder;
      expect(shape.side.color, Colors.black);
      expect(shape.side.width, 1);
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

    testWidgets('窄容器里的长标签不溢出，标签默认单行省略', (
      WidgetTester tester,
    ) async {
      const String label = '这是一个非常长的按钮文案';
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 120,
            child: OhosButton(onPressed: () {}, child: const Text(label)),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final DefaultTextStyle style = tester.widget<DefaultTextStyle>(
        find.ancestor(of: find.text(label), matching: find.byType(DefaultTextStyle)).first,
      );
      expect(style.maxLines, 1);
      expect(style.overflow, TextOverflow.ellipsis);
    });

    testWidgets('ink 主题下按钮不闪水波纹', (WidgetTester tester) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosButton(
                  onPressed: () {},
                  child: const Text('确定'),
                ),
              ),
            ),
          ),
        ),
      );

      final InkWell ink = tester.widget<InkWell>(find.byType(InkWell).first);
      expect(ink.splashColor, Colors.transparent);
    });
  });

  group('OhosDivider', () {
    testWidgets('默认 indent 0，与 Material Divider 版式一致', (
      WidgetTester tester,
    ) async {
      double lineWidth() => tester
          .getSize(
            find.descendant(
              of: find.byType(OhosDivider),
              matching: find.byType(Container),
            ),
          )
          .width;

      await tester.pumpWidget(
        wrap(const SizedBox(width: 200, child: OhosDivider())),
      );
      expect(lineWidth(), 200);

      await tester.pumpWidget(
        wrap(const SizedBox(width: 200, child: OhosDivider(indent: 16))),
      );
      expect(lineWidth(), 184);
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

    testWidgets('平铺栏标签默认钳到 1.15x，maxTextScaleFactor: null 时跟随系统', (
      WidgetTester tester,
    ) async {
      Widget host(OhosNavigationBar bar) {
        return MaterialApp(
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: OhosTheme(
            data: OhosThemeData.light(),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(width: 360, child: bar),
              ),
            ),
          ),
        );
      }

      const List<OhosNavigationDestination> destinations =
          <OhosNavigationDestination>[
            OhosNavigationDestination(icon: Icon(Icons.home), label: '首页'),
            OhosNavigationDestination(icon: Icon(Icons.person), label: '我的'),
          ];

      TextScaler scalerOf(String label) => tester
          .widget<RichText>(
            find.descendant(
              of: find.text(label),
              matching: find.byType(RichText),
            ),
          )
          .textScaler;

      await tester.pumpWidget(
        host(
          OhosNavigationBar(
            currentIndex: 0,
            onDestinationSelected: (_) {},
            destinations: destinations,
          ),
        ),
      );
      // 48vp 栏高装不下 1.3x，默认钳制到 1.15x
      expect(scalerOf('首页').scale(10), moreOrLessEquals(11.5));

      // 关掉钳制 + 抬高栏高：低视力用户能真的拿到 1.3x
      await tester.pumpWidget(
        host(
          OhosNavigationBar(
            currentIndex: 0,
            height: 64,
            maxTextScaleFactor: null,
            onDestinationSelected: (_) {},
            destinations: destinations,
          ),
        ),
      );
      expect(scalerOf('首页').scale(10), moreOrLessEquals(13));
      expect(tester.takeException(), isNull);
    });
  });

  group('OhosDataPanel', () {
    Widget host({required double textScale, required double width}) {
      return MaterialApp(
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: OhosTheme(
          data: OhosThemeData.light(),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: const OhosDataPanel(
                  title: '统计',
                  entries: <String, num>{'这是一个很长很长会溢出的标签': 12345, '短标签': 1},
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('长标签在 1.3x 字号下：标签仍被放大并省略，不是整格缩小', (
      WidgetTester tester,
    ) async {
      const String label = '这是一个很长很长会溢出的标签';

      await tester.pumpWidget(host(textScale: 1, width: 320));
      final double labelAt1x = tester.getSize(find.text(label)).height;
      final double valueAt1x = tester.getSize(find.text('12345')).height;
      // 标签被约束在单元内并省略，而不是拿无界宽度（那样省略号根本不生效）
      expect(tester.getSize(find.text(label)).width, lessThanOrEqualTo(155));

      await tester.pumpWidget(host(textScale: 1.3, width: 320));
      expect(tester.takeException(), isNull);

      final double labelAt13x = tester.getSize(find.text(label)).height;
      final double valueAt13x = tester.getSize(find.text('12345')).height;

      // 整格塞进 FittedBox 时这两项都会被缩回（0.68x 甚至更小）
      expect(labelAt13x, greaterThan(labelAt1x * 1.2));
      expect(valueAt13x, greaterThan(valueAt1x * 1.2));
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

    testWidgets('filled 变体给灰底圆角块；墨水屏上退回透明底 + 1px 线', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const OhosTextField(
            hintText: '姓名',
            variant: OhosTextFieldVariant.filled,
          ),
        ),
      );
      InputDecoration decoration =
          tester.widget<TextField>(find.byType(TextField)).decoration!;
      expect(decoration.filled, isTrue);
      expect(decoration.fillColor, isNotNull);

      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: const MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosTextField(
                  hintText: '姓名',
                  variant: OhosTextFieldVariant.filled,
                ),
              ),
            ),
          ),
        ),
      );
      decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      // 墨水屏上「填充色 = 背景色」，靠 1px 线而不是靠底色分层
      expect(decoration.filled, isFalse);
      expect(
        (decoration.enabledBorder! as OutlineInputBorder).borderSide.width,
        1,
      );
    });

    testWidgets('suffixIcon 与外部 focusNode 生效', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        wrap(
          OhosTextField(
            hintText: '密码',
            focusNode: node,
            suffixIcon: const Icon(Icons.visibility_off),
          ),
        ),
      );
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode,
        same(node),
      );

      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
    });

    testWidgets('换 focusNode 后立刻用新节点，旧的外部节点不被销毁', (
      WidgetTester tester,
    ) async {
      final FocusNode first = FocusNode();
      final FocusNode second = FocusNode();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      await tester.pumpWidget(
        wrap(OhosTextField(hintText: '姓名', focusNode: first)),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode,
        same(first),
      );

      await tester.pumpWidget(
        wrap(OhosTextField(hintText: '姓名', focusNode: second)),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode,
        same(second),
      );
      // 换下来的外部节点仍归调用方：还能继续挂监听（抛异常即说明被误 dispose）
      first.addListener(() {});
    });

    testWidgets('外部节点换成 null 后再销毁组件，不 dispose 外部节点', (
      WidgetTester tester,
    ) async {
      final FocusNode external = FocusNode();
      addTearDown(external.dispose);

      await tester.pumpWidget(
        wrap(OhosTextField(hintText: '姓名', focusNode: external)),
      );
      await tester.pumpWidget(wrap(const OhosTextField(hintText: '姓名')));
      await tester.pumpWidget(wrap(const SizedBox.shrink()));

      // 原来按 `widget.focusNode == null` 判断所有权，会把外部节点一并 dispose，
      // 调用方随后 addListener 会抛 "A FocusNode was used after being disposed"。
      external.addListener(() {});
    });

    testWidgets('内部创建的节点在换成外部节点时被销毁（不泄漏）', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const OhosTextField(hintText: '姓名')));
      final FocusNode internal = tester
          .widget<TextField>(find.byType(TextField))
          .focusNode!;

      final FocusNode external = FocusNode();
      addTearDown(external.dispose);
      await tester.pumpWidget(
        wrap(OhosTextField(hintText: '姓名', focusNode: external)),
      );

      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode,
        same(external),
      );
      expect(() => internal.addListener(() {}), throwsFlutterError);
    });

    testWidgets('换 controller 后组件用新实例，外部 controller 不被销毁', (
      WidgetTester tester,
    ) async {
      final TextEditingController external = TextEditingController(text: 'a');
      addTearDown(external.dispose);

      await tester.pumpWidget(
        wrap(OhosTextField(hintText: '姓名', controller: external)),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller,
        same(external),
      );

      await tester.pumpWidget(wrap(const OhosTextField(hintText: '姓名')));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller,
        isNot(same(external)),
      );
      external.addListener(() {});
    });
  });

  group('OhosSearchBar', () {
    testWidgets('清空键回调 onClear，空态占位与清空键同宽（32vp）', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController(
        text: 'abc',
      );
      addTearDown(controller.dispose);
      int cleared = 0;

      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 320,
            child: OhosSearchBar(
              controller: controller,
              onChanged: (String value) {},
              onClear: () => cleared++,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.cancel_rounded));
      await tester.pumpAndSettle();

      expect(controller.text, isEmpty);
      expect(cleared, 1);
      final SizedBox placeholder = tester.widget<SizedBox>(
        find.byKey(const ValueKey<String>('empty')),
      );
      // 空态与清空键同宽，输入区宽度不会在空↔有字之间跳 20vp
      expect(placeholder.width, 32);
    });

    testWidgets('聚焦时出现「取消」，点击清空并回调 onCancel', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController(
        text: 'abc',
      );
      addTearDown(controller.dispose);
      int cancelled = 0;

      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 360,
            child: OhosSearchBar(
              controller: controller,
              onCancel: () => cancelled++,
            ),
          ),
        ),
      );
      expect(find.text('取消'), findsNothing);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(find.text('取消'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(cancelled, 1);
    });

    testWidgets('换 focusNode 后「取消」按新节点的真实焦点显示', (
      WidgetTester tester,
    ) async {
      final FocusNode first = FocusNode();
      final FocusNode second = FocusNode();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      Widget host(FocusNode node) => wrap(
        SizedBox(
          width: 360,
          child: OhosSearchBar(focusNode: node, onCancel: () {}),
        ),
      );

      await tester.pumpWidget(host(first));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(find.text('取消'), findsOneWidget);

      // 换到未聚焦的新节点：按钮必须立刻消失。
      // 原来 didUpdateWidget 只换节点、不重算 _focused，按钮会一直挂着。
      await tester.pumpWidget(host(second));
      expect(second.hasFocus, isFalse);
      expect(find.text('取消'), findsNothing);
    });

    testWidgets('新节点带着焦点请求换进来时，「取消」自动出现', (
      WidgetTester tester,
    ) async {
      final FocusNode first = FocusNode();
      final FocusNode second = FocusNode();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      // 换入前就请求焦点：挂到树上时立即生效
      second.requestFocus();

      Widget host(FocusNode node) => wrap(
        SizedBox(
          width: 360,
          child: OhosSearchBar(focusNode: node, onCancel: () {}),
        ),
      );

      await tester.pumpWidget(host(first));
      expect(find.text('取消'), findsNothing);

      await tester.pumpWidget(host(second));
      await tester.pump();
      expect(second.hasFocus, isTrue);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('「取消」是按钮：够大的命中区 + button 语义', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 360,
            child: OhosSearchBar(
              autofocus: true,
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSemantics(find.text('取消')),
        matchesSemantics(
          isButton: true,
          // TextButton 同时可聚焦、有 enabled 状态（键盘 / 无障碍都能激活）
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: '取消',
        ),
      );
      final Size size = tester.getSize(find.byType(TextButton));
      // 裸 GestureDetector 只有文字那么大；按钮至少 40vp 高、48vp 宽
      expect(size.height, greaterThanOrEqualTo(40));
      expect(size.width, greaterThanOrEqualTo(48));
      handle.dispose();
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

    testWidgets('contentWidget 可放输入框，且优先于 content', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OhosAlertDialog(
            title: '重命名',
            content: '这段文字应被忽略',
            contentWidget: const OhosTextField(hintText: '新名称'),
            actions: <OhosDialogAction>[
              OhosDialogAction(label: '好', onPressed: () {}),
            ],
          ),
        ),
      );

      expect(find.byType(OhosTextField), findsOneWidget);
      expect(find.text('这段文字应被忽略'), findsNothing);
    });

    testWidgets('窄屏 + 大字号下，多字段表单的 contentWidget 改为滚动而不是溢出', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: OhosTheme(
            data: OhosThemeData.light(),
            child: Scaffold(
              body: Center(
                child: OhosAlertDialog(
                  title: '编辑信息',
                  contentWidget: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int i = 0; i < 8; i++)
                        OhosTextField(hintText: '字段 $i'),
                    ],
                  ),
                  actions: const <OhosDialogAction>[
                    OhosDialogAction(label: '取消', onPressed: _noop),
                    OhosDialogAction(label: '保存', onPressed: _noop),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(OhosAlertDialog),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(OhosAlertDialog)).height,
        lessThanOrEqualTo(640),
      );
    });
  });

  group('OhosListTile', () {
    double titleSizeOf(WidgetTester tester, String label) {
      final DefaultTextStyle style = tester.widget<DefaultTextStyle>(
        find
            .ancestor(of: find.text(label), matching: find.byType(DefaultTextStyle))
            .first,
      );
      return style.style.fontSize!;
    }

    testWidgets('regular / compact 两档行高与字阶（对应 ListTile.dense）', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Column(
            children: <Widget>[
              const OhosListTile(title: Text('常规')),
              const OhosListTile(
                density: OhosListTileDensity.compact,
                title: Text('紧凑'),
              ),
            ],
          ),
        ),
      );

      expect(titleSizeOf(tester, '常规'), 16);
      expect(titleSizeOf(tester, '紧凑'), 14);
      expect(
        tester.getSize(find.byType(OhosListTile).last).height,
        lessThan(tester.getSize(find.byType(OhosListTile).first).height),
      );
    });
  });

  group('showOhosBottomSheet', () {
    testWidgets('ink 主题下退化成纯色面板，不再做整层模糊', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: Builder(
                  builder: (BuildContext context) {
                    return OhosButton(
                      onPressed: () => showOhosBottomSheet(
                        context: context,
                        title: '分享',
                        content: const SizedBox(height: 120),
                      ),
                      child: const Text('打开面板'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开面板'));
      await tester.pumpAndSettle();

      expect(find.text('分享'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('lightMaterial: false 时彩屏也不铺光感', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: Builder(
                  builder: (BuildContext context) {
                    return OhosButton(
                      onPressed: () => showOhosBottomSheet(
                        context: context,
                        title: '分享',
                        lightMaterial: false,
                        content: const SizedBox(height: 120),
                      ),
                      child: const Text('打开面板'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开面板'));
      await tester.pumpAndSettle();

      expect(find.text('分享'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('showOhosSnackBar', () {
    testWidgets('customMessenger 决定提示挂在哪一层', (WidgetTester tester) async {
      final GlobalKey<ScaffoldMessengerState> innerMessenger =
          GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: ScaffoldMessenger(
              key: innerMessenger,
              child: OhosScaffold(
                body: Center(
                  child: Builder(
                    builder: (BuildContext context) {
                      return OhosButton(
                        onPressed: () => showOhosSnackBar(
                          context,
                          message: '已删除 1 个文件',
                          customMessenger: innerMessenger.currentState,
                        ),
                        child: const Text('删除'),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('删除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 提示挂在内层 messenger 的子树里，而不是就近/外层的 Scaffold
      expect(
        find.descendant(
          of: find.byKey(innerMessenger),
          matching: find.text('已删除 1 个文件'),
        ),
        findsOneWidget,
      );
    });
  });

  group('挂在根 Overlay 上的提示文本', () {
    /// `OverlayEntry` 的祖先链里没有 `Material`，`MaterialApp` 会给这种位置
    /// 兜底一个带 `TextDecorationStyle.double`（两道横线）的 `DefaultTextStyle`。
    /// 提示自己只覆盖了颜色/字号，`decoration` 会漏下来，文字下面于是多两条线。
    TextStyle? painted(WidgetTester tester, String label) {
      final RichText rich = tester.widget<RichText>(
        find.descendant(of: find.text(label), matching: find.byType(RichText)),
      );
      return (rich.text as TextSpan).style;
    }

    testWidgets('Toast 用主题字体，不带兜底双下划线', (WidgetTester tester) async {
      late BuildContext host;
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(fontFamily: 'HarmonyOS Sans'),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: Builder(
                  builder: (BuildContext context) {
                    host = context;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );

      showOhosToast(host, '选中 I');
      await tester.pump();
      expect(painted(tester, '选中 I')?.decoration, TextDecoration.none);
      // 之前这里漏成兜底的 `monospace`（真机上 `I` 是上下两横的等宽字形）。
      expect(painted(tester, '选中 I')?.fontFamily, 'HarmonyOS Sans');

      // 让 toast 自己摘掉，别把 2s 定时器留给下一条用例。
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('气泡提示不带兜底双下划线', (WidgetTester tester) async {
      final GlobalKey target = GlobalKey();
      late BuildContext host;
      await tester.pumpWidget(
        wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Builder(
                builder: (BuildContext context) {
                  host = context;
                  return const SizedBox(width: 40, height: 40);
                },
              ),
              SizedBox(key: target, width: 40, height: 40),
            ],
          ),
        ),
      );

      showOhosPopup(
        context: host,
        content: '长按扫码支付',
        targetKey: target,
      );
      await tester.pump();
      expect(painted(tester, '长按扫码支付')?.decoration, TextDecoration.none);
      expect(painted(tester, '长按扫码支付')?.fontFamily, isNot('monospace'));

      await tester.pump(const Duration(seconds: 2));
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

  group('OhosMagnifier', () {
    const Size screen = Size(400, 800);
    const Size bubble = Size.square(48);

    OhosMagnifierPlacement place(
      Offset anchor, {
      OhosMagnifierSide side = OhosMagnifierSide.auto,
      EdgeInsets safe = EdgeInsets.zero,
      Size screenSize = screen,
      Size bubbleSize = bubble,
      double gap = 8,
    }) {
      return OhosMagnifierPosition.resolve(
        anchor: anchor,
        bubble: bubbleSize,
        safe: safe,
        screen: screenSize,
        side: side,
        gap: gap,
      );
    }

    test('默认落在手指的右上角：纵向、横向各留一个 gap', () {
      final OhosMagnifierPlacement p = place(const Offset(100, 300));
      expect(p.offset, const Offset(108, 244));
      expect(p.side, OhosMagnifierSide.aboveRight);
      // 底边距手指 8vp、左边距手指 8vp —— 是「右上角」，不是「正上方」
      expect(300 - (p.offset.dy + p.size.height), 8);
      expect(p.offset.dx - 100, 8);
    });

    test('右半屏落左上：横向在手指左侧留 gap', () {
      final OhosMagnifierPlacement p = place(const Offset(350, 300));
      expect(p.offset, const Offset(294, 244));
      expect(p.side, OhosMagnifierSide.aboveLeft);
      expect(350 - (p.offset.dx + p.size.width), 8);
    });

    test('顶部放不下时掉到下面一行（左下/右下）', () {
      final OhosMagnifierPlacement p = place(const Offset(100, 20));
      expect(p.offset, const Offset(108, 28));
      expect(p.side, OhosMagnifierSide.belowRight);
    });

    test('贴左边缘时翻到同一个角的另一侧', () {
      // 左上：5 - 8 - 48 = -51 放不下 → 右上：13
      final OhosMagnifierPlacement p = place(
        const Offset(5, 300),
        side: OhosMagnifierSide.aboveLeft,
      );
      expect(p.offset, const Offset(13, 244));
      expect(p.side, OhosMagnifierSide.aboveRight);
    });

    test('贴右边缘时翻到同一个角的另一侧', () {
      // 右上：380 + 8 = 388 → +48 越界 → 左上：324
      final OhosMagnifierPlacement p = place(
        const Offset(380, 300),
        side: OhosMagnifierSide.aboveRight,
      );
      expect(p.offset, const Offset(324, 244));
      expect(p.side, OhosMagnifierSide.aboveLeft);
    });

    test('显式角落优先于 auto', () {
      expect(
        place(const Offset(300, 300), side: OhosMagnifierSide.aboveRight).offset,
        const Offset(308, 244),
      );
      expect(place(const Offset(300, 300)).offset, const Offset(244, 244));
    });

    test('四个角都放不下时夹进安全区', () {
      // 100vp 宽的屏放不下「gap + 48vp 泡泡」：退到首选角后硬夹到屏幕边
      // 指定左侧：50 - 8 - 48 = -6 → 夹到 0
      final OhosMagnifierPlacement left = place(
        const Offset(50, 300),
        side: OhosMagnifierSide.aboveLeft,
        screenSize: const Size(100, 800),
      );
      expect(left.offset, const Offset(0, 244));
      expect(left.side, OhosMagnifierSide.aboveLeft);
      // 指定右侧：50 + 8 = 58 → 右边留 48 只剩 52
      final OhosMagnifierPlacement right = place(
        const Offset(50, 300),
        side: OhosMagnifierSide.aboveRight,
        screenSize: const Size(100, 800),
      );
      expect(right.offset, const Offset(52, 244));
      expect(right.side, OhosMagnifierSide.aboveRight);
      // 夹紧后仍不盖住手指
      expect(right.offset.dx >= 50, isTrue);
      expect(left.offset.dx + left.size.width <= 50, isTrue);
    });

    test('夹紧改变了落点方向时 side 跟着最终矩形走', () {
      // 请求「手指下方」，但底部放不下 → 夹到安全区内后被压到手指上方，
      // 此时 side 必须报 aboveLeft，否则调用方会朝错误方向画箭头/尾巴。
      final OhosMagnifierPlacement p = place(
        const Offset(50, 380),
        side: OhosMagnifierSide.belowLeft,
        screenSize: const Size(100, 400),
      );
      expect(p.offset, const Offset(0, 352));
      expect(p.side, OhosMagnifierSide.aboveLeft);
      // 换行是被夹出来的，泡泡此时确实盖住手指（气泡底边贴屏幕底）
      expect(p.offset.dy + p.size.height, 400);
    });

    test('窄屏把宽度压到可用宽度的一半以内', () {
      final OhosMagnifierPlacement p = place(
        const Offset(100, 300),
        screenSize: const Size(300, 800),
        bubbleSize: const Size(200, 48),
      );
      expect(p.size.width, 150);
    });

    test('泡泡比可用高度还高时压进安全区', () {
      final OhosMagnifierPlacement p = place(
        const Offset(100, 100),
        screenSize: const Size(400, 200),
        bubbleSize: const Size(48, 300),
        safe: const EdgeInsets.only(top: 24, bottom: 16),
      );
      expect(p.size.height, 160);
      expect(p.offset.dy, 24);
    });

    testWidgets('泡泡按默认口径绘制：48vp 圆 + 卡片底色 + hairline 描边', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(const Center(child: OhosMagnifier(text: 'A', animate: false))),
      );
      expect(
        tester.getSize(find.byType(OhosMagnifier)),
        const Size.square(48),
      );
      expect(find.text('A'), findsOneWidget);
      final Container box = tester.widget<Container>(
        find.descendant(
          of: find.byType(OhosMagnifier),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration decoration = box.decoration! as BoxDecoration;
      final OhosThemeData theme = OhosThemeData.light();
      expect(decoration.color, theme.cardColor);
      expect(
        (decoration.border! as Border).top.color,
        theme.textTertiaryColor.withValues(alpha: 0.3),
      );
    });

    testWidgets('挂在根 Overlay 里（无 Material 祖先）时字母不带双下划线', (
      WidgetTester tester,
    ) async {
      // `MaterialApp` 在没有 `Material` 的祖先处把 `_errorTextStyle`（黄色
      // `TextDecorationStyle.double`）当 `DefaultTextStyle`。气泡正是挂在那里，
      // 之前字母下面会多出两条线 —— 这条用例钉住 `decoration`。
      late BuildContext host;
      final OhosMagnifierController controller = OhosMagnifierController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (BuildContext context) {
              host = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      TextStyle? painted() {
        final RichText rich = tester.widget<RichText>(
          find.descendant(
            of: find.byType(OhosMagnifier),
            matching: find.byType(RichText),
          ),
        );
        return (rich.text as TextSpan).style;
      }

      controller.show(host, anchor: const Offset(200, 300), text: 'A');
      await tester.pumpAndSettle();
      expect(painted()?.decoration, TextDecoration.none);
      // 兜底样式同时带 `fontFamily: 'monospace'`，也是从外层继承下来的。
      expect(painted()?.fontFamily, isNot('monospace'));

      // `child` 分支同样可能塞进裸 `Text`，一并钉住。
      controller.update(
        const Offset(200, 300),
        child: const Text('B'),
      );
      await tester.pumpAndSettle();
      expect(painted()?.decoration, TextDecoration.none);
      expect(painted()?.decorationStyle, isNot(TextDecorationStyle.double));
      expect(painted()?.fontFamily, isNot('monospace'));
    });

    testWidgets('show / update / hide：泡泡进 Overlay 并跟随锚点', (
      WidgetTester tester,
    ) async {
      late BuildContext host;
      final OhosMagnifierController controller = OhosMagnifierController();
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (BuildContext context) {
              host = context;
              return const SizedBox(width: 10, height: 10);
            },
          ),
        ),
      );

      expect(
        controller.show(host, anchor: const Offset(200, 300), text: 'A'),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(find.byType(OhosMagnifier), findsOneWidget);
      final Offset before = tester.getTopLeft(find.byType(OhosMagnifier));

      controller.update(const Offset(200, 340), text: 'B');
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(OhosMagnifier)).dy,
        before.dy + 40,
        reason: '泡泡跟着锚点下移',
      );

      controller.hide();
      await tester.pumpAndSettle();
      expect(find.byType(OhosMagnifier), findsNothing);
      controller.dispose();
    });

    testWidgets('anchor 是全局坐标：嵌套 Overlay 的原点不参与平移', (
      WidgetTester tester,
    ) async {
      late BuildContext inner;
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              // 原点不在 (0,0) 的嵌套 Overlay：取「最近的 Overlay」会把全局
              // anchor 当成它的局部坐标，泡泡整体偏移 (100,120)。
              child: Padding(
                padding: const EdgeInsets.only(left: 100, top: 120),
                child: SizedBox(
                  width: 200,
                  height: 300,
                  child: Overlay(
                    initialEntries: <OverlayEntry>[
                      OverlayEntry(
                        builder: (BuildContext context) {
                          inner = context;
                          return const SizedBox.expand();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final OhosMagnifierController controller = OhosMagnifierController();
      addTearDown(controller.dispose);
      // 手指在全局 (150,200) = 该 Overlay 局部 (50,80)；泡泡落在右上角，
      // 全局左上角 = (100 + 50 + 12, 120 + 80 - 12 - 48) = (162,140)。
      expect(
        controller.show(inner, anchor: const Offset(150, 200), text: 'A'),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(OhosMagnifier)),
        const Offset(162, 140),
      );
    });

    testWidgets('没有 Overlay 时不显示也不抛（show 返回 false）', (
      WidgetTester tester,
    ) async {
      bool? shown;
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (BuildContext context) {
                shown = OhosMagnifierController().show(
                  context,
                  anchor: const Offset(10, 10),
                  text: 'A',
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(shown, isFalse);
      expect(find.byType(OhosMagnifier), findsNothing);
    });

    testWidgets('自建 Overlay 但没有 MediaQuery 时也不抛（裸树可优雅退让）', (
      WidgetTester tester,
    ) async {
      late BuildContext inner;
      // 裸树：只有 Directionality + Overlay（`Overlay` 不要求 MediaQuery）。
      // 注：flutter_test 的宿主总会注入一个 MediaQuery，所以这条用例锁的是
      // 「裸树可用、不抛」这条契约，而不是复现 `MediaQuery.of` 的崩溃。
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Overlay(
              initialEntries: <OverlayEntry>[
                OverlayEntry(
                  builder: (BuildContext context) {
                    inner = context;
                    return const SizedBox(width: 300, height: 400);
                  },
                ),
              ],
            ),
          ),
        ),
      );
      final OhosMagnifierController controller = OhosMagnifierController();
      addTearDown(controller.dispose);
      expect(
        controller.show(inner, anchor: const Offset(150, 200), text: 'A'),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(OhosMagnifier), findsOneWidget);
    });

    testWidgets('墨水屏：1px 纯黑描边，且不做入场动画', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: const MaterialApp(
            home: Center(child: OhosMagnifier(text: 'A')),
          ),
        ),
      );
      final Container box = tester.widget<Container>(
        find.descendant(
          of: find.byType(OhosMagnifier),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration decoration = box.decoration! as BoxDecoration;
      expect((decoration.border! as Border).top.color, Colors.black);
      expect(
        find.descendant(
          of: find.byType(OhosMagnifier),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

  });

  group('OhosAlphabetIndexer', () {
    const List<String> letters = <String>['#', 'A', 'B', 'C', 'D'];

    Widget host(ValueChanged<String> onSelected) {
      return wrap(
        OhosAlphabetIndexer(
          indexer: letters,
          size: const Size(24, 160),
          onSelected: onSelected,
        ),
      );
    }

    testWidgets('点当前高亮的字母也会回调（不再「点不动」）', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      await tester.pumpWidget(host(picked.add));
      // 初值就是 indexer[0]，这一下以前被 `index != _current` 吞掉了。
      await tester.tap(find.text('#'));
      await tester.pump();
      expect(picked, <String>['#']);
    });

    testWidgets('连点同一个字母，每次都回调', (WidgetTester tester) async {
      final List<String> picked = <String>[];
      await tester.pumpWidget(host(picked.add));
      await tester.tap(find.text('#'));
      await tester.pump();
      await tester.tap(find.text('#'));
      await tester.pump();
      expect(picked, <String>['#', '#']);
    });

    testWidgets('条内留白也参与命中，不再漏给下层', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      await tester.pumpWidget(host(picked.add));
      final Offset topLeft = tester.getTopLeft(
        find.byType(OhosAlphabetIndexer),
      );
      // x=2 落在字形之外（24vp 的条，字形约 12vp 居中），以前直接漏掉。
      await tester.tapAt(topLeft + const Offset(2, 10));
      await tester.pump();
      expect(picked, <String>['#']);
    });

    testWidgets('selectedIndex 变化写回内部高亮（代码定位）', (
      WidgetTester tester,
    ) async {
      final OhosThemeData theme = OhosThemeData.light();
      Widget controlled(int? index) {
        return wrap(
          OhosAlphabetIndexer(
            indexer: letters,
            size: const Size(24, 160),
            selectedIndex: index,
            onSelected: (String _) {},
          ),
        );
      }

      await tester.pumpWidget(controlled(4));
      expect(paintedColor(tester, 'D'), theme.highlightColor);
      expect(paintedColor(tester, '#'), theme.textSecondaryColor);

      // 代码定位到别处后重算高亮：不需要手指碰过索引条。
      await tester.pumpWidget(controlled(1));
      expect(paintedColor(tester, 'A'), theme.highlightColor);
      expect(paintedColor(tester, 'D'), theme.textSecondaryColor);
    });

    testWidgets('受控高亮下点同一个字母，回调照旧触发', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      await tester.pumpWidget(
        wrap(
          OhosAlphabetIndexer(
            indexer: letters,
            size: const Size(24, 160),
            selectedIndex: 4,
            onSelected: picked.add,
          ),
        ),
      );
      // 外部高亮 = D（已回写 `_current`）：点它仍要回调，不能被"没变化"吞掉。
      await tester.tap(find.text('D'));
      await tester.pump();
      expect(picked, <String>['D']);
    });

    testWidgets('受控高亮下拖动，画面跟着手指走', (WidgetTester tester) async {
      final OhosThemeData theme = OhosThemeData.light();
      final List<String> picked = <String>[];
      await tester.pumpWidget(
        wrap(
          OhosAlphabetIndexer(
            indexer: letters,
            size: const Size(24, 160),
            selectedIndex: 0,
            // 泡泡里也会画同一个字母，关掉以免 find.text 命中两处。
            showMagnifier: false,
            onSelected: picked.add,
          ),
        ),
      );
      final Offset topLeft = tester.getTopLeft(
        find.byType(OhosAlphabetIndexer),
      );
      final TestGesture gesture = await tester.startGesture(
        topLeft + const Offset(12, 16),
      );
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      // 槽位 32：y = 16 + 20 + 40 = 76 → 第 2 格（B）。
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      // 外部 selectedIndex 一直是 0，但画面必须跟随手指：绘制只读 `_current`。
      expect(paintedColor(tester, 'B'), theme.highlightColor);
      expect(paintedColor(tester, '#'), theme.textSecondaryColor);
      await gesture.up();
      await tester.pump();
      expect(picked, contains('B'));
    });

    testWidgets('selectedIndex 越界在 debug 下断言', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosAlphabetIndexer(
            indexer: letters,
            size: const Size(24, 160),
            selectedIndex: 99,
            onSelected: (String _) {},
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('槽位与命中同源：点渲染出来的字母就是它自己', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      await tester.pumpWidget(
        wrap(
          OhosAlphabetIndexer(
            indexer: const <String>['#', 'A', 'B', 'C'],
            size: const Size(24, 160),
            onSelected: picked.add,
          ),
        ),
      );
      // 修复前命中用默认 itemHeight = 20：点 A 会报 B（floor(55 / 20) = 2）。
      for (final String letter in <String>['#', 'A', 'B', 'C']) {
        picked.clear();
        await tester.tap(find.text(letter));
        await tester.pump();
        expect(picked, <String>[letter]);
      }
    });

    testWidgets('按 size.height 平摊槽位（每格等高）', (WidgetTester tester) async {
      await tester.pumpWidget(host((String _) {}));
      // 5 个字母摊在 160vp 上 → 每格 32vp
      final double top = tester.getCenter(find.text('A')).dy;
      final double next = tester.getCenter(find.text('B')).dy;
      expect(next - top, 32);
    });

    testWidgets('父级压到 size.height 以下时跟着缩，不溢出', (WidgetTester tester) async {
      const List<String> many = <String>[
        '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', //
        'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U',
      ];
      final List<String> picked = <String>[];
      await tester.pumpWidget(
        wrap(
          SizedBox(
            height: 130,
            child: OhosAlphabetIndexer(
              indexer: many,
              size: const Size(24, 420),
              onSelected: picked.add,
            ),
          ),
        ),
      );
      // 修复前按 size.height 算槽位：22 × 19 = 418 > 130，直接
      // `RenderFlex overflowed by 290 pixels`（0.3.0 靠约束现算字号能缩进去）。
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(OhosAlphabetIndexer)).height, 130);
      // 命中映射同样来自约束：点渲染出来的字母还是它自己。
      picked.clear();
      await tester.tap(find.text('A'));
      await tester.pump();
      expect(picked, <String>['A']);
    });

    testWidgets('高度无界时退回 size.height', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              OhosAlphabetIndexer(
                indexer: letters,
                size: const Size(24, 360),
                onSelected: (String _) {},
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(OhosAlphabetIndexer)).height, 360);
    });

    testWidgets('字母继承外层字体家族（golden 里不再画成实心方块）', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          DefaultTextStyle(
            style: const TextStyle(fontFamily: 'ProbeFamily'),
            child: OhosAlphabetIndexer(
              indexer: letters,
              size: const Size(24, 160),
              onSelected: (String _) {},
            ),
          ),
        ),
      );
      final RichText rich = tester.widget<RichText>(
        find.descendant(of: find.text('A'), matching: find.byType(RichText)),
      );
      // 修复前是 null：flutter_tester 的 null 家族 = Ahem，整列实心块。
      expect((rich.text as TextSpan).style?.fontFamily, 'ProbeFamily');
    });

    testWidgets('外层没有字体家族时退到主题口径', (WidgetTester tester) async {
      const List<String> letters = <String>['#', 'A', 'B', 'C', 'D'];
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(fontFamily: 'ThemeFamily'),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: DefaultTextStyle(
                  // 只有字号、没有家族：组件要自己兜住（修复前 fontFamily 为 null）。
                  style: const TextStyle(fontSize: 14),
                  child: OhosAlphabetIndexer(
                    indexer: letters,
                    size: const Size(24, 160),
                    onSelected: (String _) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final RichText rich = tester.widget<RichText>(
        find.descendant(of: find.text('A'), matching: find.byType(RichText)),
      );
      expect((rich.text as TextSpan).style?.fontFamily, 'ThemeFamily');
    });

    testWidgets('高度缩小后字号立刻生效，不再等 200ms 追上来', (
      WidgetTester tester,
    ) async {
      const List<String> many = <String>[
        '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', //
        'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U',
      ];
      final ValueNotifier<double> height = ValueNotifier<double>(420);
      await tester.pumpWidget(
        wrap(
          ValueListenableBuilder<double>(
            valueListenable: height,
            builder: (BuildContext _, double h, Widget? __) {
              return OhosAlphabetIndexer(
                indexer: many,
                size: Size(24, h),
                onSelected: (String _) {},
              );
            },
          ),
        ),
      );
      // 模拟拖分隔条缩到最矮：420 → 130，只推一帧。
      height.value = 130;
      await tester.pump(const Duration(milliseconds: 16));
      final RichText rich = tester.widget<RichText>(
        find.descendant(of: find.text('A'), matching: find.byType(RichText)),
      );
      // 130 / 22 × 0.95 ≈ 5.61。修复前字号走 200ms 动画，此时还停在 11.vp 上，
      // 22 个字母互相压住（0.3.0 里更是直接 `RenderFlex overflowed`）。
      expect((rich.text as TextSpan).style?.fontSize, closeTo(5.61, 0.01));
    });

    testWidgets('默认拖动：途中不断回调，松手时 onSelectEnd 报最终字母', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      final List<String> ended = <String>[];
      await tester.pumpWidget(
        wrap(
          OhosAlphabetIndexer(
            indexer: letters,
            size: const Size(24, 160),
            onSelected: picked.add,
            onSelectEnd: ended.add,
          ),
        ),
      );
      final Offset topLeft = tester.getTopLeft(
        find.byType(OhosAlphabetIndexer),
      );
      final TestGesture gesture = await tester.startGesture(
        topLeft + const Offset(12, 16),
      );
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 88));
      await tester.pump();
      expect(ended, isEmpty, reason: '拖动过程中不报结束');
      await gesture.up();
      await tester.pump();
      expect(picked.last, 'D');
      expect(ended, <String>['D']);
    });

    testWidgets('拖动中字母表变短：抬手不越界，回调落在新表内', (
      WidgetTester tester,
    ) async {
      // 拖到末格（_current = 25）后把表缩到 10 个字母，父级 selectedIndex
      // 没变 —— 旧实现在 didUpdateWidget 里会早退，_current 停在 25，
      // 抬手走到 _selectEnd 的 widget.indexer[25] 直接 RangeError。
      List<String> current = List<String>.generate(
        26,
        (int i) => String.fromCharCode(65 + i),
      );
      final List<String> ended = <String>[];
      late StateSetter rebuild;
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              rebuild = setState;
              return OhosAlphabetIndexer(
                indexer: current,
                size: const Size(24, 260),
                onSelected: (_) {},
                onSelectEnd: ended.add,
              );
            },
          ),
        ),
      );

      final Rect rect = tester.getRect(find.byType(OhosAlphabetIndexer));
      final TestGesture gesture = await tester.startGesture(rect.center);
      await gesture.moveTo(Offset(rect.center.dx, rect.bottom - 2));
      await tester.pump();
      expect(find.text('Z'), findsWidgets, reason: '已经拖到末格');

      rebuild(() {
        current = List<String>.generate(
          10,
          (int i) => String.fromCharCode(65 + i),
        );
      });
      await tester.pump();

      // 夹紧不只防越界：高亮也得落到新表的末格，否则整列都没有高亮。
      expect(paintedColor(tester, 'J'), OhosThemeData.light().highlightColor);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(ended.single, 'J', reason: '夹到新表的末格，而不是越界');
    });

    testWidgets('同一格内拖动不重复回调，跨格才回调', (WidgetTester tester) async {
      final List<String> picked = <String>[];
      await tester.pumpWidget(
        wrap(
          OhosAlphabetIndexer(
            indexer: letters,
            size: const Size(24, 160),
            onSelected: picked.add,
          ),
        ),
      );
      final Offset topLeft = tester.getTopLeft(
        find.byType(OhosAlphabetIndexer),
      );
      final TestGesture gesture = await tester.startGesture(
        topLeft + const Offset(12, 16),
      );
      // 第一次移动只越过 slop → drag start，还没有 drag update。
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      // 两次小位移都停在 A 的槽位（32..64）里：drag update 有两帧，回调只该有一次。
      await gesture.moveBy(const Offset(0, 4));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 4));
      await tester.pump();
      expect(
        picked.where((String l) => l == 'A').length,
        1,
        reason: '逐帧 update ≠ 逐帧回调',
      );
      // 跨到下一格（64..96 = B）才再通知一次。
      await gesture.moveBy(const Offset(0, 32));
      await tester.pump();
      expect(picked.last, 'B');
      await gesture.up();
      await tester.pump();
    });

    testWidgets('点击也报 onSelectEnd：抬手一次，且在 onSelected 之后', (
      WidgetTester tester,
    ) async {
      final List<String> order = <String>[];
      await tester.pumpWidget(
        wrap(
          OhosAlphabetIndexer(
            indexer: letters,
            size: const Size(24, 160),
            onSelected: (String l) => order.add('selected:$l'),
            onSelectEnd: (String l) => order.add('end:$l'),
          ),
        ),
      );
      await tester.tap(find.text('B'));
      await tester.pump();
      // 落指（过程）先到，抬手（结果）后到：只订阅 onSelectEnd 也能定位。
      expect(order, <String>['selected:B', 'end:B']);
    });

    testWidgets('拖动取消也报 onSelectEnd', (WidgetTester tester) async {
      final List<String> ended = <String>[];
      await tester.pumpWidget(
        wrap(
          OhosAlphabetIndexer(
            indexer: letters,
            size: const Size(24, 160),
            onSelected: (String _) {},
            onSelectEnd: ended.add,
          ),
        ),
      );
      final Offset topLeft = tester.getTopLeft(
        find.byType(OhosAlphabetIndexer),
      );
      final TestGesture gesture = await tester.startGesture(
        topLeft + const Offset(12, 16),
      );
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.cancel();
      await tester.pump();
      expect(ended, <String>['B']);
    });

    testWidgets('拖动时出现放大镜，字母跟随，抬手消失', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host((String _) {}));
      final Offset topLeft = tester.getTopLeft(
        find.byType(OhosAlphabetIndexer),
      );
      final TestGesture gesture = await tester.startGesture(
        topLeft + const Offset(12, 16),
      );
      // 第一次移动只够越过 slop（触发 onVerticalDragStart），第二次才产生
      // onVerticalDragUpdate —— 泡泡在这时出现并按新字母刷新。
      await gesture.moveBy(const Offset(0, 20));
      await tester.pumpAndSettle();
      await gesture.moveBy(const Offset(0, 20));
      await tester.pumpAndSettle();
      expect(find.byType(OhosMagnifier), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(OhosMagnifier),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );

      await gesture.moveBy(const Offset(0, 60));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(OhosMagnifier),
          matching: find.text('C'),
        ),
        findsOneWidget,
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(OhosMagnifier), findsNothing);
    });

    testWidgets('泡泡与手指在两个轴上都留够指肚的余量', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host((String _) {}));
      final Offset topLeft = tester.getTopLeft(
        find.byType(OhosAlphabetIndexer),
      );
      final TestGesture gesture = await tester.startGesture(
        topLeft + const Offset(12, 16),
      );
      await gesture.moveBy(const Offset(0, 20));
      await tester.pumpAndSettle();
      await gesture.moveBy(const Offset(0, 20));
      await tester.pumpAndSettle();

      // 最后一次 onVerticalDragUpdate 的落点（越过 slop 后再移动 40）。
      final Offset finger = topLeft + const Offset(12, 56);
      final Rect rect = tester.getRect(find.byType(OhosMagnifier));
      final double horizontal = rect.left >= finger.dx
          ? rect.left - finger.dx
          : finger.dx - rect.right;
      final double vertical = rect.top >= finger.dy
          ? rect.top - finger.dy
          : finger.dy - rect.bottom;
      // 指肚接触半径约 30vp：小于它就会被手指压掉一角。
      expect(horizontal, greaterThanOrEqualTo(32));
      expect(vertical, greaterThanOrEqualTo(32));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('点击不显示放大镜', (WidgetTester tester) async {
      await tester.pumpWidget(host((String _) {}));
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      expect(find.byType(OhosMagnifier), findsNothing);
    });

    testWidgets('showMagnifier: false 时拖动也不显示', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OhosAlphabetIndexer(
            indexer: letters,
            size: const Size(24, 160),
            showMagnifier: false,
            onSelected: (String _) {},
          ),
        ),
      );
      final Offset topLeft = tester.getTopLeft(
        find.byType(OhosAlphabetIndexer),
      );
      final TestGesture gesture = await tester.startGesture(
        topLeft + const Offset(12, 16),
      );
      await gesture.moveBy(const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(find.byType(OhosMagnifier), findsNothing);
      await gesture.up();
    });

    testWidgets('magnifierBuilder 可换成自定义内容', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OhosAlphabetIndexer(
            indexer: letters,
            size: const Size(24, 160),
            magnifierBuilder: (BuildContext context, String letter) {
              return Text('放大$letter');
            },
            onSelected: (String _) {},
          ),
        ),
      );
      final Offset topLeft = tester.getTopLeft(
        find.byType(OhosAlphabetIndexer),
      );
      final TestGesture gesture = await tester.startGesture(
        topLeft + const Offset(12, 16),
      );
      await gesture.moveBy(const Offset(0, 20));
      await tester.pumpAndSettle();
      await gesture.moveBy(const Offset(0, 20));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(OhosMagnifier),
          matching: find.text('放大A'),
        ),
        findsOneWidget,
      );
      await gesture.up();
    });

    testWidgets('从留白处按下去也能拖动整条', (WidgetTester tester) async {
      final List<String> picked = <String>[];
      await tester.pumpWidget(host(picked.add));
      final Offset topLeft = tester.getTopLeft(
        find.byType(OhosAlphabetIndexer),
      );
      final TestGesture gesture = await tester.startGesture(
        topLeft + const Offset(2, 10),
      );
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      // 以前命不中字形，手势根本进不了 GestureDetector，picked 为空。
      expect(picked, isNotEmpty);
      expect(picked.last, 'D');
    });
  });

  group('OhosAppBar', () {
    /// OpenHarmony 上应用基本都是沉浸式（edge-to-edge），状态栏直接压在顶栏上。
    /// `Scaffold` 给 `appBar` 槽位预留的高度是
    /// `preferredSize.height + MediaQuery.padding.top`，所以组件自己把这段内边距
    /// 算进去就够了 —— 调用方不需要再包 `SafeArea`，`preferredSize` 也不用改。
    // 测试画布默认 800vp 宽，`MediaQuery.size` 只改数据、不改布局约束，
    // 所以用 `SizedBox(width:)` 真正把栏宽定成 360vp，横向断言才有意义。
    Widget host({
      required double topPadding,
      required OhosAppBar bar,
      double width = 360,
    }) {
      return OhosTheme(
        data: OhosThemeData.light(),
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              padding: EdgeInsets.only(top: topPadding),
            ),
            // `home` 拿到的是路由给的紧约束，直接套 `SizedBox(width:)` 会被无视，
            // 先用 `Align` 松开约束再把栏宽定成 360vp。
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: Scaffold(appBar: bar, body: const SizedBox.expand()),
              ),
            ),
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

    testWidgets('statusBarBackgroundColor 只给状态栏那条上色，栏高与标题位置不变', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          topPadding: 24,
          bar: const OhosAppBar(
            title: Text('标题'),
            statusBarBackgroundColor: Color(0xFF102030),
          ),
        ),
      );
      expect(tester.getSize(find.byType(OhosAppBar)).height, 56 + 24);
      expect(tester.getCenter(find.text('标题')).dy, 52);
      final Finder band = find.descendant(
        of: find.byType(OhosAppBar),
        matching: find.byType(ColoredBox),
      );
      expect(tester.getSize(band).height, 24);
      // 宽度也得铺满：`Column` 默认 `center` 给子节点松约束，无 child 的
      // `ColoredBox` 会缩成 `constraints.smallest`（宽 0），色带整条看不见。
      expect(tester.getSize(band).width, 360);
      expect(tester.widget<ColoredBox>(band).color, const Color(0xFF102030));
    });

    testWidgets('不给 statusBarBackgroundColor 时不拆段（0.3.0 观感不变）', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(topPadding: 24, bar: const OhosAppBar(title: Text('标题'))),
      );
      expect(tester.getSize(find.byType(OhosAppBar)).height, 56 + 24);
      expect(
        find.descendant(
          of: find.byType(OhosAppBar),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });

    testWidgets('OhosScaffold 下状态栏色带仍有高度（不再被 SafeArea 清零）', (
      WidgetTester tester,
    ) async {
      // `OhosScaffold` 曾把整棵 `Stack`（含 appBar）包进 `SafeArea`，后代的
      // `MediaQuery.padding.top` 被摘成 0，栏里的 topInset 随之变 0 —— README
      // 推荐的 `OhosScaffold + OhosAppBar` 组合下 `statusBarBackgroundColor`
      // 的色带永远是 0 高。既有用例都挂在 Material `Scaffold` 的 `appBar`
      // 槽位上，所以没抓到。
      const Color band = Color(0xFF102030);
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                padding: EdgeInsets.only(top: 24),
              ),
              child: OhosScaffold(
                appBar: const OhosAppBar(
                  statusBarBackgroundColor: band,
                  title: Text('标题'),
                ),
                body: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      final Finder bandBox = find.byWidgetPredicate(
        (Widget w) => w is ColoredBox && w.color == band,
      );
      expect(bandBox, findsOneWidget, reason: '色带仍然存在');
      expect(tester.getSize(bandBox).height, 24, reason: '色带高度 = 状态栏内边距');
      expect(
        tester.getSize(find.byType(OhosAppBar)).height,
        24 + 56,
        reason: '总高 = 内边距 + 栏高',
      );
    });

    testWidgets('heightOf 与 Scaffold 预留的高度一致（bottom + 状态栏内边距）', (
      WidgetTester tester,
    ) async {
      const PreferredSizeWidget tabs = PreferredSize(
        preferredSize: Size.fromHeight(40),
        child: SizedBox.shrink(),
      );
      double? withInset;
      double? withoutInset;
      double? plain;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
          child: Builder(
            builder: (BuildContext context) {
              withInset = OhosAppBar.heightOf(
                context,
                height: 48,
                bottom: tabs,
              );
              withoutInset = OhosAppBar.heightOf(
                context,
                height: 48,
                bottom: tabs,
                primary: false,
              );
              plain = OhosAppBar.heightOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(withInset, 48 + 40 + 24);
      expect(withoutInset, 48 + 40);
      expect(plain, 56 + 24);
    });

    testWidgets('leading / 标题 / actions 单行排布，标题不会压到右侧动作上',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          topPadding: 0,
          bar: OhosAppBar(
            leading: OhosIconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () {},
            ),
            title: const Text('标题'),
            actions: <Widget>[
              OhosIconButton(icon: const Icon(Icons.search), onPressed: () {}),
            ],
          ),
        ),
      );

      final Rect leading = tester.getRect(
        find.widgetWithIcon(OhosIconButton, Icons.arrow_back_ios_new_rounded),
      );
      final Rect title = tester.getRect(find.text('标题'));
      final Rect actions = tester.getRect(
        find.widgetWithIcon(OhosIconButton, Icons.search),
      );

      // 三段从左到右依次占位，谁也不叠在谁上面
      expect(leading.right, lessThanOrEqualTo(title.left));
      expect(title.right, lessThanOrEqualTo(actions.left));
      // 同一行：三者的垂直中心都落在 56vp 工具栏的正中
      expect(leading.center.dy, moreOrLessEquals(28, epsilon: 0.5));
      expect(title.center.dy, moreOrLessEquals(28, epsilon: 0.5));
      expect(actions.center.dy, moreOrLessEquals(28, epsilon: 0.5));
    });

    testWidgets('只有 actions 时标题居中于「剩余空间」而不是整栏中轴',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          topPadding: 0,
          bar: OhosAppBar(
            title: const Text('标题'),
            actions: <Widget>[
              OhosIconButton(
                icon: const Icon(Icons.search),
                size: 40,
                iconSize: 20,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      // 360vp 宽的栏，右侧动作占 40 + 4(Row 尾部留白) + 4(右边距) = 48vp，
      // 标题在剩下的 0…312 里居中。
      expect(tester.getCenter(find.text('标题')).dx, moreOrLessEquals(156));
    });

    testWidgets('长标题被约束在剩余空间内，不溢出也不盖住动作',
        (WidgetTester tester) async {
      const String long = '这是一条很长的标题文字用于检查排布';
      await tester.pumpWidget(
        host(
          topPadding: 0,
          bar: OhosAppBar(
            leading: OhosIconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () {},
            ),
            title: const Text(long),
            actions: <Widget>[
              OhosIconButton(icon: const Icon(Icons.search), onPressed: () {}),
            ],
          ),
        ),
      );

      final Rect title = tester.getRect(find.text(long));
      final Rect actions = tester.getRect(
        find.widgetWithIcon(OhosIconButton, Icons.search),
      );
      // 标题只拿到 leading 与 actions 之间的宽度（52…304，去掉左右 8vp 内边距）
      expect(title.width, lessThanOrEqualTo(304 - 52 - 16));
      expect(title.right, lessThanOrEqualTo(actions.left));
      expect(tester.takeException(), isNull);
    });

    testWidgets('titleAlignment.start 让标题贴在 leading 之后，不再强制居中',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          topPadding: 0,
          bar: OhosAppBar(
            titleAlignment: OhosAppBarTitleAlignment.start,
            leading: OhosIconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () {},
            ),
            titlePadding: const EdgeInsets.symmetric(horizontal: 12),
            title: const Text('仓库'),
          ),
        ),
      );

      final Rect leading = tester.getRect(
        find.widgetWithIcon(OhosIconButton, Icons.arrow_back_ios_new_rounded),
      );
      final Rect title = tester.getRect(find.text('仓库'));
      expect(title.left, moreOrLessEquals(leading.right + 12));
      expect(title.center.dy, moreOrLessEquals(28, epsilon: 0.5));
    });

    testWidgets('titlePadding 可收紧：窄容器里标题能拿到更多宽度',
        (WidgetTester tester) async {
      const String long = '很长很长很长的标题';
      await tester.pumpWidget(
        host(
          topPadding: 0,
          bar: OhosAppBar(
            titleAlignment: OhosAppBarTitleAlignment.start,
            titlePadding: EdgeInsets.zero,
            leading: OhosIconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () {},
            ),
            title: const Text(long),
          ),
        ),
      );

      final Rect leading = tester.getRect(
        find.widgetWithIcon(OhosIconButton, Icons.arrow_back_ios_new_rounded),
      );
      final Rect title = tester.getRect(find.text(long));
      expect(title.left, moreOrLessEquals(leading.right));
      // 单行放得下：52…360 共 308vp，足够这句 9 个汉字
      expect(title.width, lessThanOrEqualTo(360 - 52));
      expect(tester.takeException(), isNull);
    });

    testWidgets('leadingWidth 固定左侧槽宽，leading 在槽内居中',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          topPadding: 0,
          bar: OhosAppBar(
            leadingWidth: 96,
            leading: OhosIconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () {},
            ),
            title: const Text('标题'),
          ),
        ),
      );

      final Rect leading = tester.getRect(
        find.widgetWithIcon(OhosIconButton, Icons.arrow_back_ios_new_rounded),
      );
      expect(leading.center.dx, moreOrLessEquals(48));
      // 标题的可用区从 96 起算，而不是 52
      expect(
        tester.getCenter(find.text('标题')).dx,
        moreOrLessEquals((96 + 360) / 2),
      );
    });

    testWidgets('bottom 并入 preferredSize，工具栏高度不变', (WidgetTester tester) async {
      const PreferredSize bottom = PreferredSize(
        preferredSize: Size.fromHeight(40),
        child: SizedBox(height: 40, child: Text('标签')),
      );
      const OhosAppBar bar = OhosAppBar(title: Text('标题'), bottom: bottom);
      expect(bar.preferredSize, const Size.fromHeight(96));

      await tester.pumpWidget(host(topPadding: 0, bar: bar));
      expect(tester.getSize(find.byType(OhosAppBar)).height, 96);
      // 标题仍在 56vp 的工具栏里，不会被 bottom 挤下去
      expect(tester.getCenter(find.text('标题')).dy, 28);
      expect(tester.getRect(find.text('标签')).top, greaterThanOrEqualTo(56));
    });

    testWidgets('systemOverlayStyle 通过 AnnotatedRegion 交给系统状态栏',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          topPadding: 0,
          bar: const OhosAppBar(
            title: Text('标题'),
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
        ),
      );

      final AnnotatedRegion<SystemUiOverlayStyle> region = tester
          .widget(find.byType(AnnotatedRegion<SystemUiOverlayStyle>));
      expect(region.value, SystemUiOverlayStyle.light);
    });

    testWidgets('带状态栏色带时 systemOverlayStyle 仍然覆盖到状态栏那一段', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          topPadding: 24,
          bar: const OhosAppBar(
            title: Text('标题'),
            statusBarBackgroundColor: Color(0xFF102030),
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
        ),
      );
      final Finder region = find.byType(AnnotatedRegion<SystemUiOverlayStyle>);
      expect(region, findsOneWidget);
      // 系统在**屏幕顶端中点**采样状态栏图标明暗（`findAnnotations` at
      // (width/2, 0)）：注解若只盖住工具栏，那一点采不到样式，等同于没传。
      expect(tester.getRect(region).top, 0);
      expect(tester.getSize(region).height, 56 + 24);
    });

    testWidgets('带色带 + lightMaterial 时栏体仍有确定高度', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          topPadding: 24,
          bar: const OhosAppBar(
            title: Text('标题'),
            lightMaterial: true,
            statusBarBackgroundColor: Color(0xFF102030),
          ),
        ),
      );
      final Finder glow = find.byType(OhosLightMaterial);
      expect(glow, findsOneWidget);
      // 包色带的 `Column` 给子节点的是无界高度约束；这里钉住栏体（现在由
      // `SizedBox(height: preferredSize.height)` 定高）尺寸不被压成 0。
      expect(tester.getSize(glow), const Size(360, 56));
    });

    testWidgets('toolbarHeight 是 height 的别名（对齐 kToolbarHeight 命名）',
        (WidgetTester tester) async {
      const OhosAppBar bar = OhosAppBar(title: Text('t'), height: 48);
      expect(bar.toolbarHeight, 48);
      expect(bar.toolbarHeight, bar.height);
    });

    testWidgets('自动返回键用鸿蒙风格的粗箭头', (WidgetTester tester) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(
                          appBar: OhosAppBar(title: Text('详情')),
                          body: SizedBox.expand(),
                        ),
                      ),
                    ),
                    child: const Text('进入'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('进入'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    });

    testWidgets('没显式传 controller 时退回 PrimaryScrollController',
        (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: PrimaryScrollController(
              controller: controller,
              child: const Scaffold(
                appBar: OhosAppBar(
                  title: Text('标题'),
                  scrollEffect: OhosAppBarScrollEffectOptions(
                    effect: OhosAppBarScrollEffectType.commonBlur,
                  ),
                ),
                body: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
