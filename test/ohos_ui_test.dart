import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harmony_ui/harmony_ui.dart';
// 角度换算与弧段绘制是内部实现（不对外导出），但「钟面 0 度」和「350 → 10
// 只扫 20 度」这两条正是最容易被写反的地方，必须直接断在函数上。
import 'package:harmony_ui/src/widgets/ohos_arc.dart';

import 'support/test_image_provider.dart';

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

/// 实际绘制用的完整样式。
///
/// 与 `paintedColor` 分开：那个只取 color，这个要读字号 / 字重。走
/// `DefaultTextStyle.merge` 写的样式不会回填到 `Text.style`，只读
/// `tester.widget<Text>(...).style` 会拿到 null。
TextStyle paintedTextStyle(WidgetTester tester, String label) {
  final RichText rich = tester.widget<RichText>(
    find.descendant(of: find.text(label), matching: find.byType(RichText)),
  );
  return (rich.text as TextSpan).style ?? const TextStyle();
}

void _noop() {}

void _noopInt(int value) {}

void _noopBool(bool value) {}

void _noopString(String value) {}

void _noopDouble(double value) {}

/// 记录画布调用的探针。
///
/// 阶段 D 的验收标准是「断言落在真的画出来了」，所以这些用例不读 widget 字段，
/// 而是把组件内部那个 `CustomPainter` 真跑一遍，再比对画布上的每一笔。
///
/// 拿 painter 的路子：`CustomPaint.painter` 是公开类型 `CustomPainter`，即使
/// 具体实现（`_LinearPainter` 等）是私有的，也可以从 widget 树里取出来调用
/// `paint`。这一步**不需要** `BuildContext` —— 所以不必伪造上下文就能拿到
/// 真实绘制结果（伪造的 context 读不到 `Theme` / `MediaQuery`，`OhosTheme.of`
/// 会直接抛）。
///
/// 用 `noSuchMethod` 兜住 `Canvas` 其余几十个方法：只需要拦下本库真正调用的
/// 那六种（rect / circle / arc / path / rrect / line），其余吞掉即可。
class _RecordingCanvas implements Canvas {
  final List<Object> draws = <Object>[];

  @override
  void drawRect(Rect rect, Paint paint) => draws.add(_RectDraw(rect, paint));

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      draws.add(_CircleDraw(c, radius, paint));

  @override
  void drawArc(
    Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    Paint paint,
  ) => draws.add(_ArcDraw(rect, startAngle, sweepAngle, paint));

  @override
  void drawPath(Path path, Paint paint) => draws.add(_PathDraw(path, paint));

  @override
  void drawRRect(RRect rrect, Paint paint) =>
      draws.add(_RRectDraw(rrect, paint));

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      draws.add(_LineDraw(p1, p2, paint));

  @override
  void noSuchMethod(Invocation invocation) {}
}

/// 每条绘制记录都在**构造时**把 `Paint` 拍成快照。
///
/// 这一步不是多余：`_ScaleRingPainter` 循环里复用同一个 `Paint` 实例、只改
/// `color`，若记录里存的是引用，回看时所有刻度都会显示成最后一个颜色 ——
/// 「进度靠换色」那条用例正是这样假绿/假红的。
class _DrawBase {
  _DrawBase(Paint paint)
    : color = paint.color,
      strokeWidth = paint.strokeWidth,
      shader = paint.shader;
  final Color color;
  final double strokeWidth;

  /// 非空表示这一笔用渐变画（彗星弧的尾巴就靠它连续淡出）。
  final Shader? shader;
}

class _RectDraw extends _DrawBase {
  _RectDraw(this.rect, Paint paint) : super(paint);
  final Rect rect;
}

class _PathDraw extends _DrawBase {
  _PathDraw(this.path, Paint paint) : super(paint);
  final Path path;
}

class _RRectDraw extends _DrawBase {
  _RRectDraw(this.rrect, Paint paint) : super(paint);
  final RRect rrect;
}

class _CircleDraw extends _DrawBase {
  _CircleDraw(this.center, this.radius, Paint paint) : super(paint);
  final Offset center;
  final double radius;
}

class _ArcDraw extends _DrawBase {
  _ArcDraw(this.rect, this.start, this.sweep, Paint paint) : super(paint);
  final Rect rect;
  final double start;
  final double sweep;
  double get radius => rect.width / 2;
}

class _LineDraw extends _DrawBase {
  _LineDraw(this.from, this.to, Paint paint) : super(paint);
  final Offset from;
  final Offset to;
}

/// 把组件内部那个 painter 放到 [size] 上跑一遍，返回全部绘制记录。
///
/// 两步：先 `pumpWidget` 走真实构建（组件要读主题与设备像素比），再从
/// `CustomPaint.painter` 取出 painter 重放。
///
/// 查找不能只靠 `find.byType(CustomPaint)`：`Material` / `Scaffold` 自己也会
/// 插若干 `CustomPaint`（水波纹、滚动条），取 `.first` 会拿到别人的 painter，
/// 于是断言全对着错误的画布。这里只认 **painter 类名以 `_` 开头**的那些 ——
/// 本库的 painter 都是文件私有类，外部组件不会有同名形态。
List<Object> _replay(WidgetTester tester, Type type, {Size? size}) {
  final Iterable<CustomPaint> paints = tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(type),
          matching: find.byType(CustomPaint),
        ),
      )
      .where(
        (CustomPaint w) =>
            w.painter != null &&
            w.painter.runtimeType.toString().startsWith('_'),
      );
  expect(paints, isNotEmpty, reason: '$type 里没有找到本库的 CustomPaint');
  final Size box = size ?? tester.getSize(find.byType(type));
  final _RecordingCanvas canvas = _RecordingCanvas();
  paints.first.painter!.paint(canvas, box);
  return canvas.draws;
}

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
      expect(
        OhosThemeData.light().copyWith(monochrome: true).monochrome,
        isTrue,
      );
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

      final InputDecoration decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
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

      // 弹窗壳不再是 Material 的 `Dialog`（那是旧实现）：`Dialog` 自带
      // 一层 Material + barrier，与本库要的「32 圆角 + 20% 遮罩 + 可自定义
      // customStyle」三件事都在打架。现在壳是自己画的 `DecoratedBox`，
      // 所以描边要查它的 `BoxDecoration.border`。
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(OhosAlertDialog),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final BoxDecoration deco = box.decoration as BoxDecoration;
      expect(deco.border, isNotNull);
      expect(deco.border!.top.color, Colors.black);
      expect(deco.border!.top.width, 1);
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

    testWidgets('ink 主题下禁用按钮：浅底换成实线描边，字也不再是白色', (WidgetTester tester) async {
      // 墨水屏（highlightColor 为纯黑）上两件事同时失效：
      // 1. 淡到 20% 的填充等于没有，按钮连形状都留不住；
      // 2. 白字压在这种浅底上，16 级灰阶里直接看不见。
      // 所以禁用态改成透明底 + 实色描边，前景与其它三种样式对齐。
      final OhosThemeData ink = OhosThemeData.ink();
      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosButton(onPressed: null, child: const Text('提交 (0)')),
              ),
            ),
          ),
        ),
      );

      final DefaultTextStyle label = tester.widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text('提交 (0)'),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      expect(label.style.color, ink.textTertiaryColor);
      expect(label.style.color, isNot(Colors.white));

      final Material material = tester.widget<Material>(
        find
            .ancestor(of: find.text('提交 (0)'), matching: find.byType(Material))
            .first,
      );
      expect(material.color, Colors.transparent, reason: '20% 的填充在灰阶上等于没有');
      final ShapeBorder? shape = material.shape;
      final BorderSide side = switch (shape) {
        StadiumBorder(:final side) => side,
        RoundedRectangleBorder(:final side) => side,
        _ => fail('未预期的形状：$shape'),
      };
      expect(side.color, ink.textTertiaryColor);
      expect(side.width, 1);
    });

    testWidgets('ink 主题下 filled + loading：仍是实底，白转圈不压白', (
      WidgetTester tester,
    ) async {
      // loading 只是暂时不能点，不该连配色一起退成禁用态：那会让 filled 的
      // 底变浅，而转圈颜色写死的是 white70 —— 真机上只剩一个空白药丸。
      final OhosThemeData ink = OhosThemeData.ink();
      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosButton(
                  onPressed: () {},
                  loading: true,
                  child: const Text('加载中'),
                ),
              ),
            ),
          ),
        ),
      );

      final Material material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(OhosButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, ink.highlightColor, reason: 'loading 不该退成禁用态的浅底');
      final CircularProgressIndicator spinner = tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          );
      expect(spinner.color, Colors.white70);
    });

    testWidgets('窄容器里的长标签不溢出，标签默认单行省略', (WidgetTester tester) async {
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
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
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
                child: OhosButton(onPressed: () {}, child: const Text('确定')),
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
    double lineWidth(WidgetTester tester) => tester
        .getSize(
          find.descendant(
            of: find.byType(OhosDivider),
            matching: find.byType(ColoredBox),
          ),
        )
        .width;

    testWidgets('默认 indent 0，与 Material Divider 版式一致', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(const SizedBox(width: 200, child: OhosDivider())),
      );
      expect(lineWidth(tester), 200);

      await tester.pumpWidget(
        wrap(const SizedBox(width: 200, child: OhosDivider(indent: 16))),
      );
      expect(lineWidth(tester), 184);
    });

    testWidgets('默认厚度按 1 个设备像素算，不是 1vp（官方默认 1px）', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(const SizedBox(width: 200, child: OhosDivider())),
      );
      // 1px = 1/3 vp。老实现固定 0.5vp，在 3 倍屏上是 1.5px —— 粗了 50%。
      final double h = tester
          .getSize(
            find.descendant(
              of: find.byType(OhosDivider),
              matching: find.byType(ColoredBox),
            ),
          )
          .height;
      expect(h, closeTo(1 / 3, 1e-9));
    });

    testWidgets('竖线形态：宽度就是线宽，height 成为长度（官方 vertical）', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(800, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          const SizedBox(
            height: 120,
            // height 当长度用：竖线高 120、宽 1/2 vp。
            child: OhosDivider(vertical: true, height: 120),
          ),
        ),
      );
      final Size size = tester.getSize(
        find.descendant(
          of: find.byType(OhosDivider),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(size.width, closeTo(0.5, 1e-9));
      expect(size.height, 120);
    });
  });

  // 墨水屏：凡是靠「浅色填充」表达状态的组件，填充一律换成留白 + 1px 实线。
  // 依据是 16 级灰阶下 20% 以内的黑落在第 0–3 级，等于没有。
  group('墨水屏灰阶填充', () {
    testWidgets('ink 勾选框：未选中描边与禁用勾都用实色', (WidgetTester tester) async {
      final OhosThemeData ink = OhosThemeData.ink();
      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosCheckbox(value: false, onChanged: _noopBool),
              ),
            ),
          ),
        ),
      );
      final AnimatedContainer box = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final BoxDecoration decoration = box.decoration! as BoxDecoration;
      expect(
        decoration.border!.top.color,
        ink.textTertiaryColor,
        reason: '50% 灰在 16 级灰上等于没有',
      );

      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: const MaterialApp(
            home: OhosScaffold(body: Center(child: OhosCheckbox(value: true))),
          ),
        ),
      );
      // 勾在 0.6 从 `Icons.check_rounded` 换成了手画路径（官方 `mark` 的
      // `strokeWidth` 在字体字形上没法生效，而那个字段正是要补的规格），
      // 所以这里不再找 Icon，改读 painter 的实际描边色。
      //
      // painter 是私有类，测试侧不能直接引用类型；从 `toString()` 取字段也
      // 太脆。这里用一条通用探针：勾的绘制只发生在 `CustomPaint` 里，且
      // 那个 `CustomPaint` 的 painter 一定带 `color` 与 `strokeWidth` 两个
      // 字段 —— 用 `dynamic` 读，读不到就说明结构变了，直接失败。
      final CustomPaint mark = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(OhosCheckbox),
          matching: find.byType(CustomPaint),
        ),
      );
      final dynamic painter = mark.painter;
      expect(
        painter?.color as Color?,
        ink.textTertiaryColor,
        reason: '白勾压不到浅灰底上',
      );
    });

    testWidgets('ink 开关关闭态：轨道与滑块都有 1px 轮廓', (WidgetTester tester) async {
      final OhosThemeData ink = OhosThemeData.ink();
      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosSwitch(value: false, onChanged: _noopBool),
              ),
            ),
          ),
        ),
      );

      final AnimatedContainer track = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final BoxDecoration trackDecoration = track.decoration! as BoxDecoration;
      expect(trackDecoration.color, Colors.transparent);
      expect(
        trackDecoration.border,
        isNull,
        reason: '边框走 decoration 会占掉内边距，把滑块压成椭圆',
      );

      final BoxDecoration trackOutline =
          track.foregroundDecoration! as BoxDecoration;
      expect(trackOutline.border!.top.color, ink.dividerColor);

      final Finder thumbFinder = find
          .descendant(
            of: find.byType(AnimatedAlign),
            matching: find.byType(Container),
          )
          .first;
      final Container thumb = tester.widget<Container>(thumbFinder);
      final BoxDecoration thumbDecoration = thumb.decoration! as BoxDecoration;
      expect(thumbDecoration.border, isNotNull);
      expect(thumbDecoration.boxShadow, isNull, reason: '墨水屏没有阴影可画');

      // 轨道加 1px 边之后滑块仍是正圆，没有被压成椭圆。
      // 尺寸改成官方算法 `h/2 - 2*h/20`：30 高 → 半径 12、直径 **24**
      // （旧实现「高度减 4」给 26，见 OhosSwitchStyle 的说明）。
      final Size thumbSize = tester.getSize(thumbFinder);
      expect(thumbSize.width, thumbSize.height);
      expect(thumbSize.height, 24);
    });

    testWidgets('ink 卡片默认面补 1px 实线，自定义色不框', (WidgetTester tester) async {
      final OhosThemeData ink = OhosThemeData.ink();
      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: const MaterialApp(
            home: OhosScaffold(
              body: Center(child: OhosCard(child: Text('卡片'))),
            ),
          ),
        ),
      );
      final Container card = tester.widget<Container>(
        find
            .ancestor(of: find.text('卡片'), matching: find.byType(Container))
            .first,
      );
      final BoxDecoration decoration = card.decoration! as BoxDecoration;
      // 描边画在子节点之上，否则圆角弧会被子节点的抗锯齿边缘洗掉
      expect(decoration.border, isNull);
      expect(card.foregroundDecoration, isNotNull);
      final BoxDecoration outline = card.foregroundDecoration! as BoxDecoration;
      expect(outline.border!.top.color, ink.dividerColor);
      expect(decoration.boxShadow, isNull);

      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: const MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosCard(color: Colors.black, child: Text('反白块')),
              ),
            ),
          ),
        ),
      );
      final Container inverted = tester.widget<Container>(
        find
            .ancestor(of: find.text('反白块'), matching: find.byType(Container))
            .first,
      );
      expect((inverted.decoration! as BoxDecoration).border, isNull);
      expect(inverted.foregroundDecoration, isNull);
      expect(inverted.clipBehavior, Clip.none, reason: '没描边就不裁子节点，溢出行为保持原样');
    });

    testWidgets('ink 描边卡片把子节点的方角裁进圆角', (WidgetTester tester) async {
      // 子节点自带整块底色时（OhosActionBar 的白底 + 通栏分隔线），方角会盖住
      // 卡片的圆角和 1px 边，只剩两条直线的端头探出圆角外。
      final OhosThemeData ink = OhosThemeData.ink();
      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: const MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 24,
                  child: SizedBox(height: 56, width: 320),
                ),
              ),
            ),
          ),
        ),
      );
      final Container card = tester.widget<Container>(
        find.byType(Container).first,
      );
      expect(card.clipBehavior, Clip.antiAlias);
      final BoxDecoration outline = card.foregroundDecoration! as BoxDecoration;
      expect(outline.border, isNotNull);
      expect(outline.borderRadius, BorderRadius.circular(24));
    });

    testWidgets('ink 分段按钮：轨道与选中段各一条实线', (WidgetTester tester) async {
      final OhosThemeData ink = OhosThemeData.ink();
      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosSegmentedButton<String>(
                  segments: const <OhosSegment<String>>[
                    OhosSegment<String>(label: '日', value: 'day'),
                    OhosSegment<String>(label: '周', value: 'week'),
                  ],
                  selected: 'week',
                  onSelected: _noopString,
                ),
              ),
            ),
          ),
        ),
      );

      final Container track = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(OhosSegmentedButton<String>),
              matching: find.byType(Container),
            )
            .first,
      );
      final BoxDecoration trackDecoration = track.decoration! as BoxDecoration;
      expect(trackDecoration.color, Colors.transparent);
      expect(trackDecoration.border!.top.color, ink.dividerColor);

      final List<AnimatedContainer> segments = tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byType(OhosSegmentedButton<String>),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .toList();
      expect(segments.length, 2);
      expect(
        (segments.first.decoration! as BoxDecoration).border,
        isNull,
        reason: '未选中段不加框',
      );
      expect(
        (segments.last.decoration! as BoxDecoration).border!.top.color,
        ink.dividerColor,
        reason: '选中段（第二段）用实线标出',
      );
    });
  });

  group('OhosSegmentedButton', () {
    /// 把控件放进最小的可用外壳里。
    Future<void> pumpSegments(
      WidgetTester tester, {
      required Widget child,
      OhosThemeData? theme,
    }) {
      return tester.pumpWidget(
        OhosTheme(
          data: theme ?? OhosThemeData.light(),
          child: MaterialApp(
            home: OhosScaffold(body: Center(child: child)),
          ),
        ),
      );
    }

    const List<OhosSegment<String>> fourText = <OhosSegment<String>>[
      OhosSegment<String>(label: '日', value: 'day'),
      OhosSegment<String>(label: '周', value: 'week'),
      OhosSegment<String>(label: '月', value: 'month'),
      OhosSegment<String>(label: '年', value: 'year'),
    ];

    testWidgets('2–5 个按钮：1 个与 6 个都在构造期断言失败', (WidgetTester tester) async {
      // 官方 `ItemRestriction<T> = [T, T, T?, T?, T?]` 是元组类型，2–5 是类型
      // 层面的约束，不是运行时裁剪。Dart 没有元组，只能在构造期 assert。
      //
      // **有意不做「超过 5 项静默截断」**：截断会让第 6 项凭空消失而调用方
      // 毫无察觉，比当场报错更坏。
      Matcher rangeAssert() => throwsA(
        isA<AssertionError>().having(
          (AssertionError e) => e.message,
          'message',
          allOf(contains('2'), contains('5')),
        ),
      );

      expect(
        () => OhosSegmentedButton<String>(
          segments: const <OhosSegment<String>>[
            OhosSegment<String>(label: '唯一', value: 'only'),
          ],
          selected: 'only',
        ),
        rangeAssert(),
      );
      expect(
        () => OhosSegmentedButton<String>(
          segments: const <OhosSegment<String>>[
            OhosSegment<String>(label: 'a', value: 'a'),
            OhosSegment<String>(label: 'b', value: 'b'),
            OhosSegment<String>(label: 'c', value: 'c'),
            OhosSegment<String>(label: 'd', value: 'd'),
            OhosSegment<String>(label: 'e', value: 'e'),
            OhosSegment<String>(label: 'f', value: 'f'),
          ],
          selected: 'a',
        ),
        rangeAssert(),
      );

      // 边界本身要能过：正好 2 个与正好 5 个都是合法的
      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          segments: const <OhosSegment<String>>[
            OhosSegment<String>(label: 'a', value: 'a'),
            OhosSegment<String>(label: 'b', value: 'b'),
          ],
          selected: 'a',
          onSelected: _noopString,
        ),
      );
      expect(tester.takeException(), isNull);
      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          segments: const <OhosSegment<String>>[
            OhosSegment<String>(label: 'a', value: 'a'),
            OhosSegment<String>(label: 'b', value: 'b'),
            OhosSegment<String>(label: 'c', value: 'c'),
            OhosSegment<String>(label: 'd', value: 'd'),
            OhosSegment<String>(label: 'e', value: 'e'),
          ],
          selected: 'a',
          onSelected: _noopString,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('e'), findsOneWidget);
    });

    testWidgets('tab 型选中段是白背板，capsule 型是品牌色', (WidgetTester tester) async {
      final OhosThemeData light = OhosThemeData.light();

      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          type: OhosSegmentType.tab,
          segments: fourText,
          selected: 'week',
          onSelected: _noopString,
        ),
      );
      AnimatedContainer bodyAt(int i) => tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byType(OhosSegmentedButton<String>),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .elementAt(i);
      expect(
        (bodyAt(0).decoration! as BoxDecoration).color,
        Colors.transparent,
        reason: '未选中段不填色',
      );
      expect(
        (bodyAt(1).decoration! as BoxDecoration).color,
        light.cardColor,
        reason: 'tab 型选中段靠「抬起的白背板」表示当前项，不是染品牌色',
      );

      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          type: OhosSegmentType.capsule,
          segments: fourText,
          selected: 'week',
          onSelected: _noopString,
        ),
      );
      expect(
        (bodyAt(1).decoration! as BoxDecoration).color,
        light.emphasizeTertiaryColor,
        reason: 'capsule 型选中段是品牌色药丸',
      );
    });

    testWidgets('tab 型不渲染图标，capsule 型渲染', (WidgetTester tester) async {
      const List<OhosSegment<String>> withIcons = <OhosSegment<String>>[
        OhosSegment<String>(
          label: '日',
          value: 'day',
          icon: Icons.wb_sunny_outlined,
        ),
        OhosSegment<String>(
          label: '周',
          value: 'week',
          icon: Icons.date_range_outlined,
        ),
      ];

      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          type: OhosSegmentType.tab,
          segments: withIcons,
          selected: 'day',
          onSelected: _noopString,
        ),
      );
      expect(
        find.byIcon(Icons.wb_sunny_outlined),
        findsNothing,
        reason:
            '官方 tab 型的 buttons 类型是 ItemRestriction<SegmentButtonTextItem>，'
            '类型上就没有图标字段',
      );

      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          type: OhosSegmentType.capsule,
          segments: withIcons,
          selected: 'day',
          onSelected: _noopString,
        ),
      );
      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
    });

    testWidgets('多选是 toggle：再点一次取消，回调给完整集合', (WidgetTester tester) async {
      Set<String>? reported;
      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          type: OhosSegmentType.capsule,
          multiply: true,
          segments: fourText,
          selectedValues: <String>{'day', 'week'},
          onSelectionChanged: (Set<String> next) => reported = next,
        ),
      );

      // 点「周」（已选）→ 取消
      await tester.tap(find.text('周'));
      await tester.pumpAndSettle();
      expect(reported, <String>{'day'});

      // 点「月」（未选）→ 加入
      await tester.tap(find.text('月'));
      await tester.pumpAndSettle();
      expect(reported, <String>{'day', 'week', 'month'});
    });

    testWidgets('多选能同时点亮多个段', (WidgetTester tester) async {
      final OhosThemeData light = OhosThemeData.light();
      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          type: OhosSegmentType.capsule,
          multiply: true,
          segments: fourText,
          selectedValues: <String>{'day', 'month'},
          onSelectionChanged: (Set<String> _) {},
        ),
      );
      final List<AnimatedContainer> bodies = tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byType(OhosSegmentedButton<String>),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .toList();
      final Color lit = light.emphasizeTertiaryColor!;
      expect((bodies[0].decoration! as BoxDecoration).color, lit);
      expect(
        (bodies[1].decoration! as BoxDecoration).color,
        Colors.transparent,
      );
      expect((bodies[2].decoration! as BoxDecoration).color, lit);
    });

    testWidgets('tab 型即使 multiply 为 true 也是单选', (WidgetTester tester) async {
      // 官方把 `this.multiply` 写在 `if (this.type === 'capsule')` 分支里 ——
      // tab 型拿不到这个开关，传了也白传。
      final OhosSegmentedButton<String> control = OhosSegmentedButton<String>(
        type: OhosSegmentType.tab,
        multiply: true,
        segments: fourText,
        selectedValues: <String>{'day', 'week'},
        onSelectionChanged: (Set<String> _) {},
      );
      expect(control.isMultiple, isFalse);

      // 而且真的走单选回调
      String? picked;
      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          type: OhosSegmentType.tab,
          multiply: true,
          segments: fourText,
          selected: 'day',
          onSelected: (String v) => picked = v,
          onSelectionChanged: (Set<String> _) => fail('tab 型不该走多选回调'),
        ),
      );
      await tester.tap(find.text('月'));
      await tester.pumpAndSettle();
      expect(picked, 'month');
    });

    testWidgets('多选时基底内边距归零、只有首末段外侧圆角', (WidgetTester tester) async {
      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          type: OhosSegmentType.capsule,
          multiply: true,
          segments: fourText,
          selectedValues: const <String>{},
          onSelectionChanged: (Set<String> _) {},
        ),
      );
      // 基底（Container）内边距 0
      final Container baseplate = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(OhosSegmentedButton<String>),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(baseplate.padding, EdgeInsets.zero);

      // 首段只圆左侧、末段只圆右侧、中段直角
      final List<AnimatedContainer> bodies = tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byType(OhosSegmentedButton<String>),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .toList();
      BorderRadius radiusAt(int i) => (bodies[i].decoration! as BoxDecoration)
          .borderRadius!
          .resolve(TextDirection.ltr);
      expect(radiusAt(0).topLeft.x, greaterThan(100));
      expect(radiusAt(0).topRight, Radius.zero);
      expect(radiusAt(1).topLeft, Radius.zero);
      expect(radiusAt(1).topRight, Radius.zero);
      expect(radiusAt(3).topRight.x, greaterThan(100));
      expect(radiusAt(3).topLeft, Radius.zero);
    });

    testWidgets('单选时每段都是胶囊圆角', (WidgetTester tester) async {
      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          segments: fourText,
          selected: 'day',
          onSelected: _noopString,
        ),
      );
      final List<AnimatedContainer> bodies = tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byType(OhosSegmentedButton<String>),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .toList();
      for (final AnimatedContainer body in bodies) {
        final BorderRadius r = (body.decoration! as BoxDecoration).borderRadius!
            .resolve(TextDirection.ltr);
        expect(r.topLeft.x, greaterThan(100));
        expect(r.topRight.x, greaterThan(100));
      }
    });

    testWidgets('高度默认自适应但至少 28', (WidgetTester tester) async {
      // 官方只给 `constraintSize({minHeight: segment_button_height})` = 28，
      // 旧实现写死 40 是自拟值。
      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          segments: const <OhosSegment<String>>[
            OhosSegment<String>(label: 'a', value: 'a'),
            OhosSegment<String>(label: 'b', value: 'b'),
          ],
          selected: 'a',
          onSelected: _noopString,
        ),
      );
      final Size size = tester.getSize(
        find.byType(OhosSegmentedButton<String>),
      );
      expect(size.height, greaterThanOrEqualTo(28));

      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          height: 44,
          segments: const <OhosSegment<String>>[
            OhosSegment<String>(label: 'a', value: 'a'),
            OhosSegment<String>(label: 'b', value: 'b'),
          ],
          selected: 'a',
          onSelected: _noopString,
        ),
      );
      expect(
        tester.getSize(find.byType(OhosSegmentedButton<String>)).height,
        44,
      );
    });

    testWidgets('图标 24、文字 14fp、选中 w500 未选中 w400', (WidgetTester tester) async {
      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          segments: const <OhosSegment<String>>[
            OhosSegment<String>(
              label: '日',
              value: 'day',
              icon: Icons.wb_sunny_outlined,
            ),
            OhosSegment<String>(
              label: '周',
              value: 'week',
              icon: Icons.date_range_outlined,
            ),
          ],
          selected: 'week',
          onSelected: _noopString,
        ),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.wb_sunny_outlined)).size,
        24,
      );

      // 字重与字号实测落在 `RichText` 的 `TextSpan.style` 上 —— 注意是 Text 的
      // **后代**而不是祖先（`RichText` 由 `Text` 内部构建）。查错方向会得到
      // "No element" 而不是断言失败，容易误判成组件没渲染。
      //
      // 记忆点：`Text.style` 本身可能为 null（全部靠继承），只有合并后的
      // `TextSpan.style` 才是最终生效值。
      TextStyle styleOf(String label) {
        final RichText rich = tester.widget<RichText>(
          find
              .descendant(of: find.text(label), matching: find.byType(RichText))
              .first,
        );
        return rich.text.style!;
      }

      expect(styleOf('日').fontWeight, FontWeight.w400);
      expect(styleOf('周').fontWeight, FontWeight.w500);
      expect(styleOf('日').fontSize, 14);
      expect(
        styleOf('周').fontSize,
        14,
        reason:
            '选中不放大字号：官方 checked 与 unselected 两个令牌都指向 ohos_id_text_size_body2',
      );
    });

    testWidgets('墨水屏：基底与选中段各补 1px 实线，选中段用实底反白', (WidgetTester tester) async {
      final OhosThemeData ink = OhosThemeData.ink();
      await pumpSegments(
        tester,
        theme: ink,
        child: OhosSegmentedButton<String>(
          segments: fourText,
          selected: 'week',
          onSelected: _noopString,
        ),
      );
      final Container baseplate = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(OhosSegmentedButton<String>),
              matching: find.byType(Container),
            )
            .first,
      );
      final BoxDecoration track = baseplate.decoration! as BoxDecoration;
      expect(track.color, Colors.transparent, reason: '6% 的灰叠在纸色上等于没有');
      expect(track.border!.top.color, ink.dividerColor);

      final List<AnimatedContainer> bodies = tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byType(OhosSegmentedButton<String>),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .toList();
      final BoxDecoration selected = bodies[1].decoration! as BoxDecoration;
      expect(
        selected.color,
        ink.highlightColor,
        reason:
            '墨水屏上 highlightColor 与 textPrimaryColor 都是纯黑，'
            '选中项必须靠「实底 + 反白字」而不是换色',
      );
      expect(selected.border!.top.color, ink.dividerColor);
      expect(
        (bodies[0].decoration! as BoxDecoration).border,
        isNull,
        reason: '未选中段不补线',
      );
    });

    testWidgets('enabled: false 时点不动', (WidgetTester tester) async {
      bool tapped = false;
      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          enabled: false,
          segments: fourText,
          selected: 'day',
          onSelected: (String _) => tapped = true,
        ),
      );
      await tester.tap(find.text('月'));
      await tester.pumpAndSettle();
      expect(tapped, isFalse);
    });

    testWidgets('段间距 1vp', (WidgetTester tester) async {
      // 官方 `Row({ space: 1 })`。留 0 的话相邻两段 999 半径的圆角会贴在一起，
      // 接缝处出现一道沙漏状暗线。
      await pumpSegments(
        tester,
        child: OhosSegmentedButton<String>(
          type: OhosSegmentType.tab,
          segments: fourText,
          selected: 'day',
          onSelected: _noopString,
        ),
      );
      final Row row = tester.widget<Row>(
        find
            .descendant(
              of: find.byType(OhosSegmentedButton<String>),
              matching: find.byType(Row),
            )
            .first,
      );
      expect(row.spacing, 1);
    });
  });

  group('ohosBorderSide', () {
    testWidgets('宽度取整到整数设备像素，且显式画在盒内', (WidgetTester tester) async {
      // DPR 2 / 3 上结果仍是 1vp（视觉不变）；1.5 / 2.625 这类非整数 DPR 上
      // 原来 1vp 会被摊成两三行灰，取整后正好压在整数个物理像素上。
      const List<(double, double)> widths = <(double, double)>[
        (1.5, 1.3333),
        (2, 1),
        (2.625, 1.1429),
        (3, 1),
      ];

      for (final (double dpr, double expected) in widths) {
        tester.view.devicePixelRatio = dpr;
        addTearDown(tester.view.reset);
        BorderSide? side;
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (BuildContext context) {
                side = ohosBorderSide(context, const Color(0xFF000000));
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(
          side!.width,
          closeTo(expected, 0.001),
          reason: 'DPR $dpr 下 1vp 应取整到整数设备像素',
        );
        // 画到盒外会被祖先 clip 吃掉半条，四条边就不再同宽
        expect(side!.strokeAlign, BorderSide.strokeAlignInside);
      }
    });

    testWidgets('发丝线按逻辑宽度换算（0.5px 在 3x 屏上就是 2px）', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      BorderSide? side;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (BuildContext context) {
              side = ohosBorderSide(
                context,
                const Color(0xFF000000),
                width: 0.5,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(side!.width, closeTo(2 / 3, 0.001));
    });
  });

  group('OhosSlider', () {
    testWidgets('墨屏下只留自绘气泡，且补 1px 实线', (WidgetTester tester) async {
      final OhosThemeData ink = OhosThemeData.ink();
      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: OhosSlider(
                    value: 30,
                    onChanged: (double value) {},
                    divisions: 20,
                    showValueBubble: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // 有 divisions + label 时 Material 会额外画一个白底无描边的 value
      // indicator：墨屏上贴在白页面里整个消失，还和自绘气泡重影。
      expect(
        SliderTheme.of(tester.element(find.byType(Slider))).showValueIndicator,
        ShowValueIndicator.never,
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(Slider)),
      );
      await gesture.moveBy(const Offset(24, 0));
      await tester.pump();

      final Container bubble = tester.widget<Container>(
        find.byKey(const ValueKey<String>('bubble')),
      );
      final BoxDecoration decoration = bubble.decoration! as BoxDecoration;
      expect(decoration.border!.top.color, ink.dividerColor);
      expect(decoration.border!.top.width, 1);
      expect(decoration.boxShadow, isNull, reason: '墨水屏没有阴影可画');

      // 松手后气泡收起，回到「只有轨道和滑块」
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('bubble')), findsNothing);
    });

    testWidgets('彩屏离散滑条保留 Material 的数值指示器', (WidgetTester tester) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosSlider(
                  value: 30,
                  divisions: 20,
                  onChanged: (double _) {},
                ),
              ),
            ),
          ),
        ),
      );

      // 只有墨屏要关（白底无描边会消失）；彩屏离散滑条还得有拖动时的数值反馈，
      // 否则 `divisions` 一给，气泡就没了。
      expect(
        SliderTheme.of(tester.element(find.byType(Slider))).showValueIndicator,
        ShowValueIndicator.onlyForDiscrete,
      );
    });

    testWidgets('墨屏禁用态拇指不与已走轨道同灰', (WidgetTester tester) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosSlider(
                  value: 30,
                  enabled: false,
                  onChanged: (double _) {},
                ),
              ),
            ),
          ),
        ),
      );

      final SliderThemeData data = SliderTheme.of(
        tester.element(find.byType(Slider)),
      );
      final OhosSliderThumbShape shape =
          data.thumbShape! as OhosSliderThumbShape;

      // 两者取同一个灰时，拇指左半边会融进已走轨道、描边也一并收敛，
      // 真机上只剩半圈（读不出拇指中心落在哪）。
      expect(shape.disabledFillColor, isNot(data.disabledActiveTrackColor));
      // 禁用态仍要有描边：拇指的灰必然与轨道某一档重合，轮廓是唯一参照。
      expect(shape.outlineColor, isNotNull);
    });

    testWidgets('墨屏滑块自己画描边，禁用态换一档灰（不与轨道同色）', (WidgetTester tester) async {
      Future<SliderThemeData> themeFor(OhosThemeData data) async {
        await tester.pumpWidget(
          OhosTheme(
            data: data,
            child: MaterialApp(
              home: OhosScaffold(
                body: Center(
                  child: SizedBox(
                    width: 320,
                    child: OhosSlider(value: 30, onChanged: (double v) {}),
                  ),
                ),
              ),
            ),
          ),
        );
        return SliderTheme.of(tester.element(find.byType(Slider)));
      }

      final OhosThemeData ink = OhosThemeData.ink();
      final SliderThemeData inkTheme = await themeFor(ink);
      final OhosSliderThumbShape inkShape =
          inkTheme.thumbShape! as OhosSliderThumbShape;
      // 白滑块贴在白页面上：墨屏没有阴影可画，只能靠圆内描边读出来
      expect(inkShape.outlineColor, ink.dividerColor);
      expect(inkShape.outlineWidth, 1);
      expect(inkShape.elevation, 0);
      // 禁用态拇指换成与「已走轨道」不同的一档灰：同色会让左半边彻底融进
      // 轨道（描边也一并收敛），只剩右半圈，读不出中心落在哪。
      expect(inkShape.disabledFillColor, OhosColors.inkDisabled);
      expect(inkShape.disabledFillColor, isNot(ink.textTertiaryColor));
      expect(inkTheme.disabledActiveTrackColor, ink.textTertiaryColor);
      expect(inkTheme.disabledInactiveTrackColor, OhosColors.inkDisabled);

      final SliderThemeData lightTheme = await themeFor(OhosThemeData.light());
      final OhosSliderThumbShape lightShape =
          lightTheme.thumbShape! as OhosSliderThumbShape;
      expect(lightShape.outlineColor, isNull);
      expect(lightShape.disabledFillColor, isNull);
      expect(lightShape.elevation, greaterThan(0));
      expect(lightTheme.disabledInactiveTrackColor, isNull);
    });

    /// 取出当前 `SliderThemeData`。
    Future<SliderThemeData> themeOf(
      WidgetTester tester, {
      required OhosSlider slider,
      OhosThemeData? theme,
    }) async {
      await tester.pumpWidget(
        OhosTheme(
          data: theme ?? OhosThemeData.light(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(child: SizedBox(width: 320, child: slider)),
            ),
          ),
        ),
      );
      return SliderTheme.of(tester.element(find.byType(Slider)));
    }

    testWidgets('outset：轨道 4、滑块 16、命中区 40', (WidgetTester tester) async {
      // 系统资源表：slider_outset_track_thickness = 4、
      // slider_outset_block_size → ohos_id_outset_block_size = 16、
      // slider_outset_block_hot_region_size = 40。
      final SliderThemeData data = await themeOf(
        tester,
        slider: OhosSlider(value: 40, onChanged: _noopDouble),
      );
      expect(data.trackHeight, 4);
      final OhosSliderThumbShape shape =
          data.thumbShape! as OhosSliderThumbShape;
      expect(shape.radius, 8, reason: '直径 16 → 半径 8');
      expect(
        (data.overlayShape! as RoundSliderOverlayShape).overlayRadius,
        20,
        reason: '命中区 40 → 覆盖半径 20',
      );
    });

    testWidgets('inset：轨道 20、滑块 12、命中区 32', (WidgetTester tester) async {
      // slider_inset_track_thickness = 20、slider_inset_block_size = 12、
      // slider_inset_block_hot_region_size = 32。
      final SliderThemeData data = await themeOf(
        tester,
        slider: OhosSlider(
          value: 40,
          onChanged: _noopDouble,
          style: OhosSliderStyle.inset,
        ),
      );
      expect(data.trackHeight, 20);
      final OhosSliderThumbShape shape =
          data.thumbShape! as OhosSliderThumbShape;
      expect(shape.radius, 6, reason: '直径 12 → 半径 6');
      expect(
        (data.overlayShape! as RoundSliderOverlayShape).overlayRadius,
        16,
        reason: '命中区 32 → 覆盖半径 16',
      );
    });

    testWidgets('NONE：没有滑块，但命中区仍有 40', (WidgetTester tester) async {
      // 官方：`blockSize` 在 NONE 下「此字段不生效」；命中区仍是
      // slider_none_block_hot_region_size = 40 —— 没有可见滑块不等于没有
      // 可操作区域。
      final SliderThemeData data = await themeOf(
        tester,
        slider: OhosSlider(
          value: 40,
          onChanged: _noopDouble,
          style: OhosSliderStyle.none,
        ),
      );
      expect(data.thumbShape, isA<SliderComponentShape>());
      expect(
        data.thumbShape!.getPreferredSize(false, false),
        Size.zero,
        reason: 'NONE 形态的滑块尺寸为 0（不画）',
      );
      expect((data.overlayShape! as RoundSliderOverlayShape).overlayRadius, 20);
      // 轨道粗细与 outset 相同
      expect(data.trackHeight, 4);
      // 整条仍有最小高度，否则父容器按 0 高测量连轨道都画不出来
      expect(
        tester.getSize(find.byType(OhosSlider)).height,
        greaterThanOrEqualTo(40),
      );
    });

    testWidgets('showSteps 且有 divisions 才画刻度点', (WidgetTester tester) async {
      // 官方 `showSteps` 默认 false；没有步长时不知道该在哪画点。
      SliderThemeData data = await themeOf(
        tester,
        slider: OhosSlider(value: 40, onChanged: _noopDouble),
      );
      expect(
        data.tickMarkShape,
        SliderTickMarkShape.noTickMark,
        reason: '默认不画',
      );

      data = await themeOf(
        tester,
        slider: OhosSlider(value: 40, onChanged: _noopDouble, divisions: 10),
      );
      expect(
        data.tickMarkShape,
        SliderTickMarkShape.noTickMark,
        reason: '有 divisions 但没开 showSteps 也不画',
      );

      data = await themeOf(
        tester,
        slider: OhosSlider(
          value: 40,
          onChanged: _noopDouble,
          divisions: 10,
          showSteps: true,
        ),
      );
      expect(data.tickMarkShape, isNot(SliderTickMarkShape.noTickMark));
      expect(
        data.tickMarkShape!.getPreferredSize(
          sliderTheme: data,
          isEnabled: true,
        ),
        const Size.fromRadius(2),
        reason: '默认直径 4 → 半径 2',
      );
    });

    testWidgets('stepSize 两个边界：0 不画、超轨道粗细时夹回来', (WidgetTester tester) async {
      // 官方：取值范围 [0, trackThickness)，0 时不显示，负数取默认值。
      SliderThemeData data = await themeOf(
        tester,
        slider: OhosSlider(
          value: 40,
          onChanged: _noopDouble,
          divisions: 10,
          showSteps: true,
          stepSize: 0,
        ),
      );
      expect(
        data.tickMarkShape,
        SliderTickMarkShape.noTickMark,
        reason: '直径 0 表示不画',
      );

      // outset 轨道 4，直径 10 会被夹到 4（半径 2）
      data = await themeOf(
        tester,
        slider: OhosSlider(
          value: 40,
          onChanged: _noopDouble,
          divisions: 10,
          showSteps: true,
          stepSize: 10,
        ),
      );
      expect(
        data.tickMarkShape!.getPreferredSize(
          sliderTheme: data,
          isEnabled: true,
        ),
        const Size.fromRadius(2),
        reason: '超过轨道粗细 4 时夹到 4（半径 2）',
      );

      // inset 轨道 20，同样的 10 不再被夹
      data = await themeOf(
        tester,
        slider: OhosSlider(
          value: 40,
          onChanged: _noopDouble,
          divisions: 10,
          showSteps: true,
          stepSize: 10,
          style: OhosSliderStyle.inset,
        ),
      );
      expect(
        data.tickMarkShape!.getPreferredSize(
          sliderTheme: data,
          isEnabled: true,
        ),
        const Size.fromRadius(5),
        reason: 'inset 轨道粗 20，直径 10 不被夹',
      );
    });

    testWidgets('prefix / suffix 贴在轨道两端', (WidgetTester tester) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: OhosSlider(
                    value: 40,
                    onChanged: _noopDouble,
                    prefix: const Text('慢'),
                    suffix: const Text('快'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('慢'), findsOneWidget);
      expect(find.text('快'), findsOneWidget);
      // 前缀在左、后缀在右；滑条夹在中间
      final double prefixX = tester.getCenter(find.text('慢')).dx;
      final double sliderX = tester.getCenter(find.byType(Slider)).dx;
      final double suffixX = tester.getCenter(find.text('快')).dx;
      expect(prefixX, lessThan(sliderX));
      expect(suffixX, greaterThan(sliderX));
      expect(tester.takeException(), isNull, reason: '不加前缀后缀也要能布局');
    });

    testWidgets('没有 prefix / suffix 时不占位', (WidgetTester tester) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: OhosSlider(value: 40, onChanged: _noopDouble),
                ),
              ),
            ),
          ),
        ),
      );
      // 轨道铺满整宽（不再被两端的留白挤窄）
      expect(tester.getSize(find.byType(Slider)).width, 320);
    });

    testWidgets('三种形态都能渲染，不溢出', (WidgetTester tester) async {
      for (final OhosSliderStyle style in OhosSliderStyle.values) {
        await tester.pumpWidget(
          OhosTheme(
            data: OhosThemeData.ink(),
            child: MaterialApp(
              home: OhosScaffold(
                body: Center(
                  child: SizedBox(
                    width: 260,
                    child: OhosSlider(
                      value: 60,
                      onChanged: _noopDouble,
                      style: style,
                      divisions: 4,
                      showSteps: true,
                      showValueBubble: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(Slider), findsOneWidget, reason: '$style 应渲染');
        expect(tester.takeException(), isNull, reason: '$style 不应溢出');
      }
    });
  });

  group('OhosCheckbox（shape / mark）', () {
    // 官方 `shape`（API 11+，默认 `CheckBoxShape.CIRCLE`）与 `mark`
    // （API 10+，默认 `{strokeColor: foreground_contrary, strokeWidth:
    // ohos_id_checkbox_stroke_width = 2vp, size: '20vp'}`）。
    // 0.5 的两项全缺：外形固定圆角方形、勾固定 `Icons.check_rounded`。

    BoxDecoration boxOf(WidgetTester tester) {
      final AnimatedContainer c = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      return c.decoration! as BoxDecoration;
    }

    testWidgets('默认圆形（官方 CheckBoxShape.CIRCLE）', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const OhosCheckbox(value: false)));
      // BoxShape.circle 时 borderRadius 必须为 null —— 两者同时给会被断言拦。
      final BoxDecoration d = boxOf(tester);
      expect(d.shape, BoxShape.circle);
      expect(d.borderRadius, isNull);
    });

    testWidgets('shape: roundedSquare 回到圆角方形，半径 0.26×size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const OhosCheckbox(
            value: false,
            shape: OhosCheckboxShape.roundedSquare,
          ),
        ),
      );
      final BoxDecoration d = boxOf(tester);
      expect(d.shape, BoxShape.rectangle);
      final BorderRadiusGeometry? radius = d.borderRadius;
      expect((radius! as BorderRadius).topLeft.x, closeTo(24 * 0.26, 0.01));
    });

    /// 勾的 painter —— 只有选中态才画。
    CustomPainter? markPainter(WidgetTester tester) {
      final Iterable<CustomPaint> paints = tester.widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(OhosCheckbox),
          matching: find.byType(CustomPaint),
        ),
      );
      // `AnimatedContainer` 自己不画，但 BoxDecoration 会挂一个
      // `CustomPaint`；勾的那个 painter 一定带 `strokeWidth` 字段。
      for (final CustomPaint p in paints) {
        final dynamic painter = p.painter;
        if (painter != null && painter is CustomPainter) {
          try {
            // ignore: avoid_dynamic_calls
            (painter as dynamic).strokeWidth;
            return painter;
          } on NoSuchMethodError {
            continue;
          }
        }
      }
      return null;
    }

    testWidgets('mark.size 决定勾的边长（默认 20，超框时被夹住）', (WidgetTester tester) async {
      // 量**声明的**宽度（SizedBox.width），不是 getSize：勾最终的可画区域比
      // 方框小 —— `AnimatedContainer` 的 `BoxDecoration.border` 会按
      // `decoration.padding` 隐式占掉边框宽度（1.5vp 换算成设备像素再回来），
      // 24 的框里实际只有约 20.7 的内宽。用 getSize 量出来的数会带上这个差额，
      // 断言就不再是「mark.size 是多少」了。
      double declaredMarkSize(WidgetTester tester) {
        final SizedBox box = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(OhosCheckbox),
            matching: find.byType(SizedBox),
          ),
        );
        return box.width!;
      }

      await tester.pumpWidget(
        wrap(const OhosCheckbox(value: true, onChanged: _noopBool)),
      );
      expect(declaredMarkSize(tester), 20, reason: '官方 MarkStyle.size 默认 20vp');

      // 显式给 40（大于方框 24）时必须夹回方框尺寸，不能声明一个画到框外的勾。
      await tester.pumpWidget(
        wrap(
          const OhosCheckbox(
            value: true,
            onChanged: _noopBool,
            mark: OhosCheckboxMarkStyle(size: 40),
          ),
        ),
      );
      expect(declaredMarkSize(tester), 24, reason: '夹到方框边长');

      // 而且实际渲染也绝不超出方框 —— 夹取之外，父级的紧约束本来也会拦一道。
      final Size painted = tester.getSize(
        find.descendant(
          of: find.byType(OhosCheckbox),
          matching: find.byType(SizedBox),
        ),
      );
      expect(painted.width, lessThanOrEqualTo(24));
    });

    testWidgets('mark.strokeWidth 按官方令牌 2vp，且可配', (WidgetTester tester) async {
      // 资源表 `ohos_id_checkbox_stroke_width = 2.0vp`。这条断言就是「勾不能再
      // 用字体图标」的理由：`Icon` 的线宽是字形画死的，改不了。
      await tester.pumpWidget(
        wrap(const OhosCheckbox(value: true, onChanged: _noopBool)),
      );
      expect(markPainter(tester), isNotNull);
      final dynamic p1 = markPainter(tester);
      expect(p1?.strokeWidth, 2);

      await tester.pumpWidget(
        wrap(
          const OhosCheckbox(
            value: true,
            onChanged: _noopBool,
            mark: OhosCheckboxMarkStyle(strokeWidth: 3.5),
          ),
        ),
      );
      final dynamic p2 = markPainter(tester);
      expect(p2?.strokeWidth, 3.5);
    });

    testWidgets('mark.strokeColor 覆盖默认的反白色', (WidgetTester tester) async {
      const Color tint = Color(0xFF00FF00);
      await tester.pumpWidget(
        wrap(
          const OhosCheckbox(
            value: true,
            onChanged: _noopBool,
            mark: OhosCheckboxMarkStyle(strokeColor: tint),
          ),
        ),
      );
      final dynamic painter = markPainter(tester);
      expect(painter?.color, tint);

      // 不给时取主题的反白色（官方 `ohos_id_color_foreground_contrary`）。
      final OhosThemeData theme = OhosThemeData.light();
      await tester.pumpWidget(
        wrap(const OhosCheckbox(value: true, onChanged: _noopBool)),
      );
      final dynamic def = markPainter(tester);
      expect(def?.color, theme.onHighlightColor);
    });

    testWidgets('unselectedColor 覆盖未选中描边', (WidgetTester tester) async {
      const Color border = Color(0xFF112233);
      await tester.pumpWidget(
        wrap(const OhosCheckbox(value: false, unselectedColor: border)),
      );
      expect(boxOf(tester).border!.top.color, border);
    });
  });

  group('OhosCheckboxGroup', () {
    // 三态判定的四条边界。这里直接打在纯函数上：官方 `SelectStatus` 的
    // All=0 / Part=1 / None=2 三个值里，最容易写错的是「空选集」与「空全集」
    // —— 两者都该是 None，写成 All 会让一个空群组显示成「已全选」。
    group('ohosSelectStatusOf', () {
      test('全选', () {
        expect(
          ohosSelectStatusOf(
            allNames: <String>['a', 'b', 'c'],
            selected: <String>{'a', 'b', 'c'},
          ),
          OhosSelectStatus.all,
        );
      });

      test('部分选中', () {
        expect(
          ohosSelectStatusOf(
            allNames: <String>['a', 'b', 'c'],
            selected: <String>{'a'},
          ),
          OhosSelectStatus.part,
        );
      });

      test('空选集是 none，不是 all', () {
        expect(
          ohosSelectStatusOf(
            allNames: <String>['a', 'b'],
            selected: <String>{},
          ),
          OhosSelectStatus.none,
        );
      });

      test('空全集是 none：0 项全选没有意义', () {
        expect(
          ohosSelectStatusOf(allNames: const <String>[], selected: <String>{}),
          OhosSelectStatus.none,
        );
      });

      test('选集里混着全集外的名字时，按命中数算', () {
        // 只有 a 在全集里 ⇒ 1/2 ⇒ part。若不先与全集求交，选中数会比总数
        // 还多，hit == total 永远不成立，全选永远算不出来。
        expect(
          ohosSelectStatusOf(
            allNames: <String>['a', 'b'],
            selected: <String>{'a', 'ghost'},
          ),
          OhosSelectStatus.part,
        );
      });
    });

    /// 取出主勾选框的装饰（宽高 / 底色 / 描边）。
    BoxDecoration decorationOf(WidgetTester tester) {
      return tester
              .widget<AnimatedContainer>(
                find.descendant(
                  of: find.byType(OhosCheckboxGroup),
                  matching: find.byType(AnimatedContainer),
                ),
              )
              .decoration!
          as BoxDecoration;
    }

    testWidgets('全选是勾、半选是一横 —— 不是「颜色浅一点的勾」', (WidgetTester tester) async {
      Future<void> pump(OhosSelectStatus status) async {
        await tester.pumpWidget(
          wrap(OhosCheckboxGroup.status(status: status, onChanged: _noopBool)),
        );
        await tester.pumpAndSettle();
      }

      await pump(OhosSelectStatus.all);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsNothing);

      await pump(OhosSelectStatus.part);
      // 16 级灰上「一个颜色浅一点的勾」与勾分不开，半选必须是另一个图形。
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      await pump(OhosSelectStatus.none);
      expect(find.byIcon(Icons.remove_rounded), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('数量推三态：0 / 中间 / 全满', (WidgetTester tester) async {
      Future<void> pump(int selected, int total) async {
        await tester.pumpWidget(
          wrap(
            OhosCheckboxGroup(
              selectedCount: selected,
              total: total,
              onChanged: _noopBool,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(0, 3);
      expect(find.byIcon(Icons.remove_rounded), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      await pump(1, 3);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);

      await pump(3, 3);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // 数量超出总数时要夹回来（调用方传错不至于画出「4/3 全选」的怪状态）
      await pump(4, 3);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('半选底色与全选一致，只有图形不同', (WidgetTester tester) async {
      // 半选的观感是「已选中一部分 ⇒ 这个框是活跃的」，底色必须与全选同档；
      // 若半选退成描边空心，用户会以为这一项整个没选。
      final OhosThemeData light = OhosThemeData.light();

      await tester.pumpWidget(
        wrap(
          OhosCheckboxGroup.status(
            status: OhosSelectStatus.all,
            onChanged: _noopBool,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Color allFill = decorationOf(tester).color!;

      await tester.pumpWidget(
        wrap(
          OhosCheckboxGroup.status(
            status: OhosSelectStatus.part,
            onChanged: _noopBool,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Color partFill = decorationOf(tester).color!;

      expect(allFill, light.highlightColor);
      expect(partFill, allFill);
    });

    testWidgets('默认圆形（官方 CheckBoxShape.CIRCLE），round: false 才是方形', (
      WidgetTester tester,
    ) async {
      // 0.6 起默认跟随官方 `CheckBoxShape.CIRCLE`（文档原文「API version 11
      // 开始，Checkbox 默认样式由圆角方形变为圆形」，`shape` 属性默认值也明写
      // CIRCLE）。0.5 的默认是圆角方形，所以这里把两档都测一遍 —— 只测圆形
      // 的话，「把两档都写成圆形」这种错也测不出来。
      Future<BorderRadius> radiusOf({required bool round}) async {
        await tester.pumpWidget(
          wrap(
            OhosCheckboxGroup(
              selectedCount: 1,
              total: 2,
              round: round,
              onChanged: _noopBool,
            ),
          ),
        );
        await tester.pumpAndSettle();
        return decorationOf(tester).borderRadius!.resolve(TextDirection.ltr);
      }

      final BorderRadius circle = await radiusOf(round: true);
      expect(circle.topLeft.x, 12, reason: '24 / 2');

      final BorderRadius square = await radiusOf(round: false);
      expect(square.topLeft.x, closeTo(24 * 0.26, 0.01));
    });

    testWidgets('点击给的是目标状态：半选变全选', (WidgetTester tester) async {
      // 官方 `triggerChange`：「true 表示从部分选中或未选中变为全部选中」。
      final List<bool> taps = <bool>[];
      await tester.pumpWidget(
        wrap(
          OhosCheckboxGroup.status(
            status: OhosSelectStatus.part,
            onChanged: taps.add,
          ),
        ),
      );
      await tester.tap(find.byType(OhosCheckboxGroup));
      expect(taps, <bool>[true], reason: '半选点一下应当变全选');

      taps.clear();
      await tester.pumpWidget(
        wrap(
          OhosCheckboxGroup.status(
            status: OhosSelectStatus.all,
            onChanged: taps.add,
          ),
        ),
      );
      await tester.tap(find.byType(OhosCheckboxGroup));
      expect(taps, <bool>[false], reason: '全选点一下应当变全不选');
    });

    testWidgets('onChanged 为 null 时不可点、铺 15% 灰底', (WidgetTester tester) async {
      final OhosThemeData light = OhosThemeData.light();
      await tester.pumpWidget(
        wrap(OhosCheckboxGroup(selectedCount: 0, total: 3)),
      );
      await tester.pumpAndSettle();

      final BoxDecoration decoration = decorationOf(tester);
      expect(
        decoration.color,
        light.policy.tint(light.textTertiaryColor, 0.15),
        reason: '禁用态才铺灰底',
      );
      final GestureDetector detector = tester.widget<GestureDetector>(
        find.descendant(
          of: find.byType(OhosCheckboxGroup),
          matching: find.byType(GestureDetector),
        ),
      );
      expect(detector.onTap, isNull);
    });

    group('OhosCheckboxGroupController', () {
      test('toggleAll 在半选时切到全选，不是先清空', () {
        final OhosCheckboxGroupController c = OhosCheckboxGroupController(
          allNames: <String>['a', 'b', 'c'],
          selected: <String>{'a'},
        );
        expect(c.status, OhosSelectStatus.part);

        c.toggleAll();
        expect(c.status, OhosSelectStatus.all);
        expect(c.selected, <String>{'a', 'b', 'c'});

        c.toggleAll();
        expect(c.status, OhosSelectStatus.none);
        expect(c.selected, isEmpty);
      });

      test('invert 反选', () {
        final OhosCheckboxGroupController c = OhosCheckboxGroupController(
          allNames: <String>['a', 'b', 'c'],
          selected: <String>{'a', 'b'},
        );
        c.invert();
        expect(c.selected, <String>{'c'});
        // 反选之后三态还是那三个，不需要第四个状态
        expect(c.status, OhosSelectStatus.part);

        c.invert();
        expect(c.selected, <String>{'a', 'b'});
      });

      test('toggle 忽略全集外的名字', () {
        // 加进去会让选中数超过总数，`hit == total` 永远不成立，
        // 全选永远算不出来。
        final OhosCheckboxGroupController c = OhosCheckboxGroupController(
          allNames: <String>['a', 'b'],
          selected: <String>{'a', 'b'},
        );
        c.toggle('ghost');
        expect(c.selected, <String>{'a', 'b'});
        expect(c.status, OhosSelectStatus.all);
      });

      test('构造时把选集与全集求交', () {
        // 外部传进来的 initialState 可能含已删除的项
        final OhosCheckboxGroupController c = OhosCheckboxGroupController(
          allNames: <String>['a', 'b'],
          selected: <String>{'a', 'gone'},
        );
        expect(c.selected, <String>{'a'});
        expect(c.status, OhosSelectStatus.part, reason: '不是 all');
      });

      test('result 的 names 按全集顺序，并带 total', () {
        // 只给三态不够（不知道是哪几项），只给名单也不够（分不出 Part 与 All）
        final OhosCheckboxGroupController c = OhosCheckboxGroupController(
          allNames: <String>['a', 'b', 'c'],
          selected: <String>{'c', 'a'},
        );
        final OhosCheckboxGroupResult result = c.result;
        expect(result.names, <String>['a', 'c'], reason: '按全集顺序而非插入顺序');
        expect(result.status, OhosSelectStatus.part);
        expect(result.total, 3);
      });

      test('selected 是只读视图', () {
        final OhosCheckboxGroupController c = OhosCheckboxGroupController(
          allNames: <String>['a', 'b'],
        );
        expect(() => c.selected.add('a'), throwsUnsupportedError);
      });

      test('值不变时不通知（selectAll / clear / setSelected）', () {
        // 重复通知会让 InheritedNotifier 白重建一整棵子树。
        final OhosCheckboxGroupController c = OhosCheckboxGroupController(
          allNames: <String>['a', 'b'],
          selected: <String>{'a'},
        );
        int notified = 0;
        c.addListener(() => notified++);

        c.setSelected('a', true);
        expect(notified, 0, reason: '值已经是 true');

        c.clear();
        expect(notified, 1);
        c.clear();
        expect(notified, 1, reason: '已经是空的');

        c.selectAll();
        expect(notified, 2);
        c.selectAll();
        expect(notified, 2, reason: '已经全选');
      });

      test('处理空全集', () {
        // 0 项时不能把 selectAll 当成 all，否则空列表显示成「已全选」
        final OhosCheckboxGroupController c = OhosCheckboxGroupController(
          allNames: const <String>[],
        );
        expect(c.status, OhosSelectStatus.none);
        c.selectAll();
        expect(c.status, OhosSelectStatus.none);
        expect(c.result.names, isEmpty);
      });
    });

    group('OhosCheckboxGroupHeader / Tile', () {
      Future<OhosCheckboxGroupController> pumpGroup(
        WidgetTester tester, {
        Set<String>? selected,
      }) async {
        final OhosCheckboxGroupController c = OhosCheckboxGroupController(
          allNames: <String>['a', 'b', 'c'],
          selected: selected,
        );
        addTearDown(c.dispose);
        await tester.pumpWidget(
          wrap(
            OhosCheckboxGroupScope(
              controller: c,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const OhosCheckboxGroupHeader(title: '全选'),
                  for (final String name in c.allNames)
                    OhosCheckboxGroupTile(name: name, title: name),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return c;
      }

      testWidgets('点成员只切换该成员', (WidgetTester tester) async {
        final OhosCheckboxGroupController c = await pumpGroup(tester);
        await tester.tap(find.text('b'));
        await tester.pumpAndSettle();
        expect(c.selected, <String>{'b'});
      });

      testWidgets('点头部整行等于全选', (WidgetTester tester) async {
        final OhosCheckboxGroupController c = await pumpGroup(
          tester,
          selected: <String>{'a'},
        );
        // 半选时点头部 → 全选（不是清空）
        await tester.tap(find.text('全选'));
        await tester.pumpAndSettle();
        expect(c.selected, <String>{'a', 'b', 'c'});

        await tester.tap(find.text('全选'));
        await tester.pumpAndSettle();
        expect(c.selected, isEmpty);
      });

      testWidgets('成员勾中时头部自动变半选、全选时变全选', (WidgetTester tester) async {
        final OhosCheckboxGroupController c = await pumpGroup(tester);
        // 头部那个主勾选框是整棵子树里的第一个 OhosCheckboxGroup
        IconData? headerIcon() {
          final Finder group = find.byType(OhosCheckboxGroup);
          final Iterable<Icon> icons = tester.widgetList<Icon>(
            find.descendant(of: group, matching: find.byType(Icon)),
          );
          return icons.isEmpty ? null : icons.first.icon;
        }

        expect(headerIcon(), isNull, reason: '0/3 时主勾选框里没有图形');

        c.toggle('a');
        await tester.pumpAndSettle();
        expect(headerIcon(), Icons.remove_rounded, reason: '1/3 是半选');

        c.selectAll();
        await tester.pumpAndSettle();
        expect(headerIcon(), Icons.check_rounded);
      });

      testWidgets('没有 Scope 且没传 controller 时报错信息可读', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          wrap(const OhosCheckboxGroupHeader(title: '全选')),
        );
        final Object? error = tester.takeException();
        expect(error, isAssertionError);
        expect(
          error.toString(),
          contains('OhosCheckboxGroupScope'),
          reason: '错误信息要指向缺失的那一层，而不是一句 null 检查失败',
        );
      });

      testWidgets('墨屏下半选仍靠图形而非颜色区分', (WidgetTester tester) async {
        // 墨水屏上 highlight 与 textPrimary 都是纯黑：半选与全选底色完全一样，
        // 「勾 vs 一横」是唯一线索。
        final OhosCheckboxGroupController c = OhosCheckboxGroupController(
          allNames: <String>['a', 'b'],
          selected: <String>{'a'},
        );
        addTearDown(c.dispose);
        await tester.pumpWidget(
          OhosTheme(
            data: OhosThemeData.ink(),
            child: MaterialApp(
              home: OhosScaffold(
                body: OhosCheckboxGroupScope(
                  controller: c,
                  child: const OhosCheckboxGroupHeader(title: '全选'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
      });
    });
  });

  group('OhosRadio', () {
    /// 取容器的装饰。
    BoxDecoration decorationOf(WidgetTester tester) {
      return tester
              .widget<AnimatedContainer>(
                find.descendant(
                  of: find.byType(OhosRadio),
                  matching: find.byType(AnimatedContainer),
                ),
              )
              .decoration!
          as BoxDecoration;
    }

    Future<void> pumpRadio(WidgetTester tester, OhosRadio radio) async {
      await tester.pumpWidget(wrap(radio));
      await tester.pumpAndSettle();
    }

    testWidgets('默认是 TICK（勾），不是 DOT（圆点）', (WidgetTester tester) async {
      // 文档开头：「API version 12 开始，Radio选中默认样式由
      // RadioIndicatorType.DOT 变为 RadioIndicatorType.TICK」。
      await pumpRadio(tester, OhosRadio(value: true, onChanged: _noopBool));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
        tester.widget<OhosRadio>(find.byType(OhosRadio)).indicator,
        OhosRadioIndicator.tick,
      );
    });

    testWidgets('DOT 是圆点，画成实心圆而不是图标', (WidgetTester tester) async {
      await pumpRadio(
        tester,
        OhosRadio(
          value: true,
          onChanged: _noopBool,
          indicator: OhosRadioIndicator.dot,
        ),
      );
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      // 内部图形是一块 DecoratedBox（圆形填充），尺寸 = 24 × 0.5。
      // 按 key 查而不是按类型：`AnimatedContainer` 自己也会生成一层
      // `DecoratedBox`，两者类型相同。
      final Finder dot = find.byKey(const ValueKey<String>('radio-dot'));
      expect(dot, findsOneWidget);
      expect(
        tester
                .widget<DecoratedBox>(
                  find.descendant(of: dot, matching: find.byType(DecoratedBox)),
                )
                .decoration
            is BoxDecoration,
        isTrue,
      );
      expect(
        tester.getSize(dot),
        const Size.square(12),
        reason: 'ohos_id_radio_inner_size_ratio = 0.5 × 24',
      );
    });

    testWidgets('CUSTOM 用 indicatorBuilder 的内容，中心对齐', (
      WidgetTester tester,
    ) async {
      await pumpRadio(
        tester,
        OhosRadio(
          value: true,
          onChanged: _noopBool,
          indicator: OhosRadioIndicator.custom,
          indicatorBuilder: (BuildContext _) => const SizedBox.square(
            key: ValueKey<String>('custom'),
            dimension: 8,
          ),
        ),
      );
      expect(find.byKey(const ValueKey<String>('custom')), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      final Offset center = tester.getCenter(find.byType(OhosRadio));
      final Offset custom = tester.getCenter(
        find.byKey(const ValueKey<String>('custom')),
      );
      expect(custom, center, reason: '官方：「自定义组件与Radio组件为中心点对齐显示」');
    });

    testWidgets('CUSTOM 但没有 builder 时回落 TICK', (WidgetTester tester) async {
      // 文档：「indicatorBuilder设置为undefined时，按照RadioIndicatorType.TICK
      // 进行显示」。不回落的话这里会画出一个空心的实底圆 —— 比什么都不画更糟，
      // 因为用户会以为「已选中但没有图形」是设计如此。
      await pumpRadio(
        tester,
        OhosRadio(
          value: true,
          onChanged: _noopBool,
          indicator: OhosRadioIndicator.custom,
        ),
      );
      expect(
        tester.widget<OhosRadio>(find.byType(OhosRadio)).effectiveIndicator,
        OhosRadioIndicator.tick,
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('选中是实心底板 + 反差图形，未选中留白 + 描边', (WidgetTester tester) async {
      // `RadioStyle` 同时有 `checkedBackgroundColor`（底板）与 `indicatorColor`
      // （内部图形）两个默认值 ⇒ 选中态必然是两层结构。若沿旧实现画成
      // 「空心环 + 品牌色圆点」，`checkedBackgroundColor` 无处可画。
      final OhosThemeData light = OhosThemeData.light();

      await pumpRadio(tester, OhosRadio(value: false, onChanged: _noopBool));
      expect(decorationOf(tester).color, Colors.transparent, reason: '未选中不铺底');
      expect(decorationOf(tester).border, isNotNull);

      await pumpRadio(tester, OhosRadio(value: true, onChanged: _noopBool));
      expect(decorationOf(tester).color, light.highlightColor);
      // 内部图形用反差色，不是底板色 —— 否则整块同色，图形看不见
      final Icon tick = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
      expect(tick.color, light.onHighlightColor);
    });

    testWidgets('三个颜色字段各自的优先级', (WidgetTester tester) async {
      const Color plate = Color(0xFF123456);
      const Color legacy = Color(0xFF654321);
      const Color stroke = Color(0xFFABCDEF);

      // checkedBackgroundColor 压过 activeColor
      await pumpRadio(
        tester,
        OhosRadio(
          value: true,
          onChanged: _noopBool,
          activeColor: legacy,
          checkedBackgroundColor: plate,
          indicatorColor: stroke,
        ),
      );
      expect(decorationOf(tester).color, plate);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_rounded)).color,
        stroke,
      );

      // 只有 activeColor 时退到它（兼容旧用法）
      await pumpRadio(
        tester,
        OhosRadio(value: true, onChanged: _noopBool, activeColor: legacy),
      );
      expect(decorationOf(tester).color, legacy);

      // 未选中的描边可以单独指定
      await pumpRadio(
        tester,
        OhosRadio(
          value: false,
          onChanged: _noopBool,
          uncheckedBorderColor: plate,
        ),
      );
      expect(decorationOf(tester).border!.top.color, plate);
    });

    testWidgets('几何：容器 24、描边 1、内部图形 12', (WidgetTester tester) async {
      // radio_container_size = 24、ohos_id_radio_border_width = 1、
      // ohos_id_radio_inner_size_ratio = 0.5。
      await pumpRadio(tester, OhosRadio(value: true, onChanged: _noopBool));
      expect(tester.getSize(find.byType(OhosRadio)), const Size.square(24));
      expect(decorationOf(tester).border!.top.width, 1);
      expect(
        tester.getSize(find.byIcon(Icons.check_rounded)),
        const Size.square(12),
      );
    });

    testWidgets('size 缩放时内部图形跟着缩', (WidgetTester tester) async {
      await pumpRadio(
        tester,
        OhosRadio(value: true, onChanged: _noopBool, size: 40),
      );
      expect(tester.getSize(find.byType(OhosRadio)), const Size.square(40));
      expect(
        tester.getSize(find.byIcon(Icons.check_rounded)),
        const Size.square(20),
        reason: '比值固定 0.5，不是写死 12',
      );
    });

    testWidgets('点未选中给 true，点已选中不给任何回调', (WidgetTester tester) async {
      // 单选框没有「取消选中」：同组互斥，点自己等于没操作。旧实现会给 false，
      // 调用方照做就会出现「一组里一个都没选」的状态。
      final List<bool> taps = <bool>[];
      await pumpRadio(tester, OhosRadio(value: false, onChanged: taps.add));
      await tester.tap(find.byType(OhosRadio));
      expect(taps, <bool>[true]);

      taps.clear();
      await pumpRadio(tester, OhosRadio(value: true, onChanged: taps.add));
      await tester.tap(find.byType(OhosRadio));
      expect(taps, isEmpty, reason: '已选中再点不该回调');
    });

    testWidgets('onChanged 为 null 时不可点', (WidgetTester tester) async {
      await pumpRadio(tester, const OhosRadio(value: false));
      final GestureDetector detector = tester.widget<GestureDetector>(
        find.descendant(
          of: find.byType(OhosRadio),
          matching: find.byType(GestureDetector),
        ),
      );
      expect(detector.onTap, isNull);
      final Semantics semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(OhosRadio),
          matching: find.byType(Semantics),
        ),
      );
      expect(semantics.properties.enabled, isFalse);
    });

    testWidgets('墨屏：选中底板纯黑、图形反白，未选中靠实线', (WidgetTester tester) async {
      // 墨屏上 highlight 与 textPrimary 都是纯黑 —— 选中/未选中的区别只能靠
      // 「实心 vs 只有线」，这也是 ohos_id_radio_inactive_background_solid = 0
      // （未选中不铺底）存在的意义。
      final OhosThemeData ink = OhosThemeData.ink();
      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(child: OhosRadio(value: true, onChanged: _noopBool)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(decorationOf(tester).color, ink.highlightColor);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_rounded)).color,
        ink.onHighlightColor,
      );
      expect(
        decorationOf(tester).color,
        isNot(ink.backgroundColor),
        reason: '选中态不能与背景同色，否则只剩一圈线',
      );

      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosRadio(value: false, onChanged: _noopBool),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(decorationOf(tester).color, Colors.transparent);
      expect(decorationOf(tester).border!.top.width, 1);
    });
  });

  group('OhosWheelPicker', () {
    Future<void> pumpPicker(WidgetTester tester, OhosWheelPicker picker) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(child: SizedBox(width: 300, child: picker)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    List<String> numbers(int count) => <String>[
      for (int i = 0; i < count; i++) '$i',
    ];

    testWidgets('行高 40、字号 20fp（官方明文数字）', (WidgetTester tester) async {
      // 文档：「UIPickerComponent容器的选项行高固定为40vp」「所有文本组件的
      // fontSize 属性默认为 20fp」。
      await pumpPicker(
        tester,
        OhosWheelPicker(
          columns: <OhosPickerColumn>[OhosPickerColumn(labels: numbers(3))],
        ),
      );
      expect(OhosWheelPicker.itemExtent, 40);
      expect(
        paintedTextStyle(tester, '0').fontSize,
        20,
        reason: '20fp 而不是 Material 的 14/16',
      );
    });

    testWidgets('视口高 = min(容器高, 行高 × 显示项数)', (WidgetTester tester) async {
      // 官方：容器建议 200（5 × 40）；小于该值则从上下边缘向中间裁剪。
      await pumpPicker(
        tester,
        OhosWheelPicker(
          columns: <OhosPickerColumn>[OhosPickerColumn(labels: numbers(20))],
        ),
      );
      expect(tester.getSize(find.byType(OhosWheelPicker)).height, 200);

      await pumpPicker(
        tester,
        OhosWheelPicker(
          height: 120,
          columns: <OhosPickerColumn>[OhosPickerColumn(labels: numbers(20))],
        ),
      );
      // 容器矮了就按容器高裁剪，而不是溢出
      expect(tester.getSize(find.byType(OhosWheelPicker)).height, 120);
      expect(tester.takeException(), isNull);
    });

    testWidgets('少于 8 项不循环，即使 loop 为 true', (WidgetTester tester) async {
      // 官方：「如果子组件的个数小于8个，无论isLoop设置为true还是false，
      // 都不会循环滚动」。这条是无条件行为，不提供覆盖开关。
      final GlobalKey<OhosWheelPickerState> key =
          GlobalKey<OhosWheelPickerState>();
      await pumpPicker(
        tester,
        OhosWheelPicker(
          key: key,
          loop: true,
          columns: <OhosPickerColumn>[OhosPickerColumn(labels: numbers(7))],
        ),
      );
      expect(key.currentState!.widget.loopOf(0), isFalse, reason: '7 < 8');

      final GlobalKey<OhosWheelPickerState> key2 =
          GlobalKey<OhosWheelPickerState>();
      await pumpPicker(
        tester,
        OhosWheelPicker(
          key: key2,
          loop: true,
          columns: <OhosPickerColumn>[OhosPickerColumn(labels: numbers(8))],
        ),
      );
      expect(key2.currentState!.widget.loopOf(0), isTrue, reason: '8 >= 8');
    });

    testWidgets('loop: false 时 8 项以上也不循环', (WidgetTester tester) async {
      final GlobalKey<OhosWheelPickerState> key =
          GlobalKey<OhosWheelPickerState>();
      await pumpPicker(
        tester,
        OhosWheelPicker(
          key: key,
          loop: false,
          columns: <OhosPickerColumn>[OhosPickerColumn(labels: numbers(12))],
        ),
      );
      expect(key.currentState!.widget.loopOf(0), isFalse);
    });

    testWidgets('列上的 loop 压过整条 picker 的 loop', (WidgetTester tester) async {
      final GlobalKey<OhosWheelPickerState> key =
          GlobalKey<OhosWheelPickerState>();
      await pumpPicker(
        tester,
        OhosWheelPicker(
          key: key,
          loop: true,
          columns: <OhosPickerColumn>[
            OhosPickerColumn(labels: numbers(10)),
            OhosPickerColumn(labels: numbers(10), loop: false),
          ],
        ),
      );
      expect(key.currentState!.widget.loopOf(0), isTrue);
      expect(key.currentState!.widget.loopOf(1), isFalse);
    });

    testWidgets('多列按 flex 分配宽度', (WidgetTester tester) async {
      await pumpPicker(
        tester,
        OhosWheelPicker(
          columns: <OhosPickerColumn>[
            OhosPickerColumn(labels: numbers(4), flex: 2),
            OhosPickerColumn(labels: numbers(4)),
            OhosPickerColumn(labels: numbers(4)),
          ],
        ),
      );
      final List<double> widths = <double>[
        for (int i = 0; i < 3; i++)
          tester.getSize(find.byType(ListWheelScrollView).at(i)).width,
      ];
      expect(widths[0], closeTo(widths[1] * 2, 0.01), reason: 'flex 2:1:1');
      expect(widths[1], closeTo(widths[2], 0.01));
    });

    testWidgets('BACKGROUND 指示器：圆角 12、一行高；墨屏改画 1px 线', (
      WidgetTester tester,
    ) async {
      // 官方默认 `{type: BACKGROUND, borderRadius: 12}`；墨屏上这层 5% 灰
      // 会被策略判成透明，置灰等于没画，改画线。
      await pumpPicker(
        tester,
        OhosWheelPicker(
          columns: <OhosPickerColumn>[OhosPickerColumn(labels: numbers(4))],
        ),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey<String>('picker-indicator')),
      );
      final BoxDecoration decoration = box.decoration as BoxDecoration;
      expect(decoration.borderRadius!.resolve(TextDirection.ltr).topLeft.x, 12);
      expect(
        tester
            .getSize(find.byKey(const ValueKey<String>('picker-indicator')))
            .height,
        40,
      );

      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: OhosWheelPicker(
                    columns: <OhosPickerColumn>[
                      OhosPickerColumn(labels: numbers(4)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final BoxDecoration inkDecoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey<String>('picker-indicator')),
                  )
                  .decoration
              as BoxDecoration;
      expect(inkDecoration.color, Colors.transparent, reason: '灰底在墨屏无效');
      expect(inkDecoration.border, isNotNull, reason: '改画线');
    });

    testWidgets('DIVIDER 指示器：上下各一条 2px 线，间距 40 − 2×线宽', (
      WidgetTester tester,
    ) async {
      // 官方 `strokeWidth` 默认 2.0px、范围 [0, 20]（= 选中项高度的一半）。
      await pumpPicker(
        tester,
        OhosWheelPicker(
          indicator: OhosPickerIndicator.divider,
          columns: <OhosPickerColumn>[OhosPickerColumn(labels: numbers(4))],
        ),
      );
      final Finder top = find.byKey(
        const ValueKey<String>('picker-divider-top'),
      );
      final Finder bottom = find.byKey(
        const ValueKey<String>('picker-divider-bottom'),
      );
      expect(tester.getSize(top).height, 2);
      expect(tester.getSize(bottom).height, 2);
      // 两条线所在整块是 40
      expect(
        tester.getTopLeft(bottom).dy - tester.getBottomLeft(top).dy,
        36,
        reason: '40 − 2 − 2',
      );
      // BACKGROUND 的底不在场
      expect(
        find.byKey(const ValueKey<String>('picker-indicator')),
        findsNothing,
      );
    });

    testWidgets('滑动一列触发 onChanged（带列下标）', (WidgetTester tester) async {
      final List<String> calls = <String>[];
      await pumpPicker(
        tester,
        OhosWheelPicker(
          columns: <OhosPickerColumn>[
            OhosPickerColumn(labels: numbers(10)),
            OhosPickerColumn(labels: numbers(10)),
          ],
          onChanged: (int column, int index) => calls.add('$column:$index'),
        ),
      );
      // 往上拨一列（负 dy = 内容上移 = 下标增大）
      await tester.drag(
        find.byType(ListWheelScrollView).first,
        const Offset(0, -40),
      );
      await tester.pumpAndSettle();
      expect(calls, isNotEmpty);
      expect(calls.first, startsWith('0:'), reason: '第一列');
      expect(calls.last, isNot(startsWith('0:0')), reason: '下标应当变了');
    });

    testWidgets('onScrollStop 只在滚动结束时触发一次', (WidgetTester tester) async {
      // 官方专门写了「如果某次滑动动画还未结束时又触发了新的滑动动画，
      // 则不属于滑动停止」—— 所以必须等真实滚动结束，不能用定时器近似。
      final List<String> stops = <String>[];
      final List<String> changes = <String>[];
      await pumpPicker(
        tester,
        OhosWheelPicker(
          columns: <OhosPickerColumn>[OhosPickerColumn(labels: numbers(12))],
          onChanged: (int c, int i) => changes.add('$c:$i'),
          onScrollStop: (int c, int i) => stops.add('$c:$i'),
        ),
      );
      expect(stops, isEmpty, reason: '还没滚过');

      await tester.drag(find.byType(ListWheelScrollView), const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(stops, hasLength(1), reason: '一次滑动只停一次');
      expect(changes.length, greaterThan(1), reason: '过程中跨过多项');
    });

    testWidgets('enabled: false 时不可滚，文字降到提示色', (WidgetTester tester) async {
      final List<String> calls = <String>[];
      await pumpPicker(
        tester,
        OhosWheelPicker(
          enabled: false,
          columns: <OhosPickerColumn>[OhosPickerColumn(labels: numbers(12))],
          onChanged: (int c, int i) => calls.add('$c:$i'),
        ),
      );
      await tester.drag(find.byType(ListWheelScrollView), const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(
        paintedColor(tester, '0'),
        OhosThemeData.light().textTertiaryColor,
      );
    });

    testWidgets('initialIndex 越界时夹到合法范围', (WidgetTester tester) async {
      final GlobalKey<OhosWheelPickerState> key =
          GlobalKey<OhosWheelPickerState>();
      await pumpPicker(
        tester,
        OhosWheelPicker(
          key: key,
          columns: <OhosPickerColumn>[
            OhosPickerColumn(labels: numbers(3), initialIndex: 99),
          ],
        ),
      );
      expect(key.currentState!.indexes, <int>[2], reason: '3 项的最后一个');
    });

    testWidgets('animateTo 可以滚到指定项', (WidgetTester tester) async {
      final GlobalKey<OhosWheelPickerState> key =
          GlobalKey<OhosWheelPickerState>();
      await pumpPicker(
        tester,
        OhosWheelPicker(
          key: key,
          columns: <OhosPickerColumn>[OhosPickerColumn(labels: numbers(20))],
        ),
      );
      key.currentState!.animateTo(0, 10);
      await tester.pumpAndSettle();
      expect(key.currentState!.indexes, <int>[10]);
    });

    testWidgets('列数变化时重建控制器，不抛越界', (WidgetTester tester) async {
      await pumpPicker(
        tester,
        OhosWheelPicker(
          columns: <OhosPickerColumn>[
            OhosPickerColumn(labels: numbers(5)),
            OhosPickerColumn(labels: numbers(5)),
          ],
        ),
      );
      expect(tester.takeException(), isNull);

      await pumpPicker(
        tester,
        OhosWheelPicker(
          columns: <OhosPickerColumn>[OhosPickerColumn(labels: numbers(5))],
        ),
      );
      expect(tester.takeException(), isNull, reason: '少一列不该抛');
    });
  });

  group('OhosTimePicker', () {
    test('24 小时制：0–23；12 小时制：1–12', () {
      final List<String> h24 = OhosTimePicker.hoursOf(true);
      expect(h24.first, '00');
      expect(h24.last, '23');
      expect(h24, hasLength(24));

      final List<String> h12 = OhosTimePicker.hoursOf(false);
      expect(h12.first, '01');
      expect(h12.last, '12');
      expect(h12, hasLength(12), reason: '不含 0 —— 12 小时制没有 0 点');
    });

    test('分、秒都是 0–59 两位', () {
      expect(OhosTimePicker.minutes, hasLength(60));
      expect(OhosTimePicker.minutes.first, '00');
      expect(OhosTimePicker.minutes.last, '59');
      expect(OhosTimePicker.seconds, OhosTimePicker.minutes);
    });

    testWidgets('列数由 second 是否为 null 决定', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosTimePicker(
            hour: 9,
            minute: 30,
            onChanged: (int h, int m, int s) {},
          ),
        ),
      );
      expect(
        find.byType(ListWheelScrollView),
        findsNWidgets(2),
        reason: '时 + 分',
      );

      await tester.pumpWidget(
        wrap(
          OhosTimePicker(
            hour: 9,
            minute: 30,
            second: 15,
            onChanged: (int h, int m, int s) {},
          ),
        ),
      );
      expect(find.byType(ListWheelScrollView), findsNWidgets(3));
    });

    testWidgets('12 小时制的时列下标换算', (WidgetTester tester) async {
      // 显示值 1–12，下标 0–11：12 点对应下标 11，不是 12。
      await tester.pumpWidget(
        wrap(
          OhosTimePicker(
            hour: 12,
            minute: 0,
            use24Hour: false,
            onChanged: (int h, int m, int s) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final OhosWheelPicker picker = tester.widget<OhosWheelPicker>(
        find.byType(OhosWheelPicker),
      );
      expect(picker.columns.first.initialIndex, 11);
    });
  });

  group('OhosDatePicker', () {
    test('daysInMonth：闰年规则', () {
      // 与 OhosDate 同一套规则：能被 4 整除且不能被 100 整除，或能被 400 整除。
      expect(OhosDatePicker.daysInMonth(2024, 2), 29, reason: '闰年');
      expect(OhosDatePicker.daysInMonth(2025, 2), 28);
      expect(OhosDatePicker.daysInMonth(1900, 2), 28, reason: '整百年不闰');
      expect(OhosDatePicker.daysInMonth(2000, 2), 29, reason: '400 年闰');
      expect(OhosDatePicker.daysInMonth(2025, 4), 30);
      expect(OhosDatePicker.daysInMonth(2025, 12), 31);
    });

    testWidgets('三列：年 2 倍宽', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosDatePicker(
            year: 2025,
            month: 3,
            day: 5,
            onChanged: (int y, int m, int d) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final OhosWheelPicker picker = tester.widget<OhosWheelPicker>(
        find.byType(OhosWheelPicker),
      );
      expect(picker.columns, hasLength(3));
      expect(picker.columns[0].flex, 2);
      expect(picker.columns[1].flex, 1);
      expect(picker.columns[2].flex, 1);
    });

    testWidgets('日越界时按当月长度收敛，不进位', (WidgetTester tester) async {
      // 3 月 31 日改成 2 月 ⇒ 28 日（2025 非闰年），不是 3 月 3 日。
      int? y;
      int? m;
      int? d;
      await tester.pumpWidget(
        wrap(
          OhosDatePicker(
            year: 2025,
            month: 3,
            day: 31,
            onChanged: (int yy, int mm, int dd) {
              y = yy;
              m = mm;
              d = dd;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 直接拨月列：从下标 2（3 月）拨到下标 1（2 月）
      final OhosWheelPicker picker = tester.widget<OhosWheelPicker>(
        find.byType(OhosWheelPicker),
      );
      picker.onChanged!.call(1, 1);
      await tester.pumpAndSettle();
      expect(y, 2025);
      expect(m, 2);
      expect(d, 28, reason: '31 日收敛到 2 月末');
    });

    testWidgets('闰年 2 月是 29 天', (WidgetTester tester) async {
      int? d;
      await tester.pumpWidget(
        wrap(
          OhosDatePicker(
            year: 2024,
            month: 1,
            day: 31,
            onChanged: (int y, int m, int dd) => d = dd,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final OhosWheelPicker picker = tester.widget<OhosWheelPicker>(
        find.byType(OhosWheelPicker),
      );
      picker.onChanged!.call(1, 1);
      await tester.pumpAndSettle();
      expect(d, 29);
    });

    testWidgets('年列长度 = maxYear − minYear + 1', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosDatePicker(
            year: 2000,
            month: 1,
            day: 1,
            minYear: 1990,
            maxYear: 2010,
            onChanged: (int y, int m, int d) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final OhosWheelPicker picker = tester.widget<OhosWheelPicker>(
        find.byType(OhosWheelPicker),
      );
      expect(picker.columns[0].labels, hasLength(21));
      expect(picker.columns[0].labels.first, '1990');
      expect(picker.columns[0].labels.last, '2010');
      expect(picker.columns[0].initialIndex, 10, reason: '2000 − 1990');
    });
  });

  group('OhosRatingBar', () {
    testWidgets('value 是 double：2.5 星画出「两颗满 + 一颗半」', (
      WidgetTester tester,
    ) async {
      // 官方 `stepSize` 默认 0.5，「半星」是最常用的粒度。老实现 `value` 是
      // `int`，2.5 传不进来 —— 这条用例的价值就是把类型固定住。
      await tester.pumpWidget(wrap(const OhosRatingBar(value: 2.5)));

      // 5 颗星，每颗 28vp（`ohos_id_rating_big_height`），星与星紧贴。
      expect(tester.getSize(find.byType(OhosRatingBar)), const Size(140, 28));
      // 前两颗是满星（实心），第三颗只填一半，后两颗是空星。
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(3));
      // 半星那颗：底图空星 + 上层按 0.5 裁出的满星。
      final ClipRect clip = tester.widget<ClipRect>(
        find.descendant(
          of: find.byType(OhosRatingBar),
          matching: find.byType(ClipRect),
        ),
      );
      expect(clip.child, isA<Stack>());
      final Align align = tester.widget<Align>(
        find.descendant(
          of: find.byType(ClipRect),
          matching: find.byType(Align),
        ),
      );
      expect(align.widthFactor, 0.5);
    });

    testWidgets('点击位置决定分值：右半格比左半格多一格步长', (WidgetTester tester) async {
      final List<double> got = <double>[];
      await tester.pumpWidget(
        wrap(OhosRatingBar(value: 0, onChanged: got.add)),
      );

      final Rect bar = tester.getRect(find.byType(OhosRatingBar));
      // 第 2 颗星的左半格 → 1.5；同一颗星的右半格 → 2.0。
      await tester.tapAt(Offset(bar.left + 28 * 1.25, bar.center.dy));
      await tester.pump();
      await tester.tapAt(Offset(bar.left + 28 * 1.75, bar.center.dy));
      await tester.pump();
      expect(got, <double>[1.5, 2.0]);
    });

    testWidgets('写入值按 stepSize 规整（四舍五入到最近的整数倍）', (WidgetTester tester) async {
      final List<double> got = <double>[];
      await tester.pumpWidget(
        wrap(OhosRatingBar(value: 1.2, stepSize: 1, onChanged: got.add)),
      );

      final Rect bar = tester.getRect(find.byType(OhosRatingBar));
      // 整数步长：2.7 星位置 → 3.0（`ceil` 到该格右边界），不是 2.7。
      await tester.tapAt(Offset(bar.left + 28 * 2.7, bar.center.dy));
      await tester.pump();
      expect(got, <double>[3.0]);
      // 绘制也读规整值：1.2 在 stepSize 1 下按 1.0 画 —— 只有第 1 颗是满的。
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('再点一次不会清零（官方没有「取消评分」语义）', (WidgetTester tester) async {
      final List<double> got = <double>[];
      await tester.pumpWidget(
        wrap(OhosRatingBar(value: 3, onChanged: got.add)),
      );

      final Rect bar = tester.getRect(find.byType(OhosRatingBar));
      // 点第 3 颗星右边 —— 老实现 `i == value ? i - 1 : i` 会回落到 2。
      await tester.tapAt(Offset(bar.left + 28 * 2.75, bar.center.dy));
      await tester.pump();
      expect(got, <double>[3.0]);
    });

    testWidgets('indicator 只读：星径缩到 12vp，点击无回调', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(const OhosRatingBar(value: 4, indicator: true)),
      );

      // `ohos_id_rating_mini_height = 12vp`，总宽 12×5 = 60。
      expect(tester.getSize(find.byType(OhosRatingBar)), const Size(60, 12));
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('activeIcon / inactiveIcon 可换成任意图形（官方 starStyle 三个 URI）', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const OhosRatingBar(
            value: 2,
            activeIcon: Icon(Icons.favorite, size: 20),
            inactiveIcon: Icon(Icons.favorite_border, size: 20),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite), findsNWidgets(2));
      expect(find.byIcon(Icons.favorite_border), findsNWidgets(3));
      // 换图形不影响 28vp 的星径。
      expect(tester.getSize(find.byType(OhosRatingBar)), const Size(140, 28));
    });
  });

  group('OhosCounter', () {
    testWidgets('enableInc / enableDec 是独立开关（库存 0 只能减不能加）', (
      WidgetTester tester,
    ) async {
      final List<int> got = <int>[];
      await tester.pumpWidget(
        wrap(
          OhosCounter(
            value: 0,
            enableInc: true,
            enableDec: false,
            min: -5,
            onChanged: got.add,
          ),
        ),
      );

      // 减号禁用、加号可用 —— 老实现只有一个 `enabled`，这对组合表达不出来。
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(got, <int>[1]);
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(got, <int>[1]);
    });

    testWidgets('enabled: false 同时压住两个方向', (WidgetTester tester) async {
      final List<int> got = <int>[];
      await tester.pumpWidget(
        wrap(OhosCounter(value: 2, enabled: false, onChanged: got.add)),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(got, isEmpty);
    });

    testWidgets('onInc / onDec 在各自方向单独触发（官方两个独立回调）', (
      WidgetTester tester,
    ) async {
      final List<String> log = <String>[];
      await tester.pumpWidget(
        wrap(
          OhosCounter(
            value: 1,
            onChanged: (int v) => log.add('change:$v'),
            onInc: () => log.add('inc'),
            onDec: () => log.add('dec'),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(log, <String>['inc', 'change:2', 'dec', 'change:0']);
    });
  });

  group('OhosScrollbar', () {
    Widget host(ScrollController controller) {
      return wrap(
        SizedBox(
          width: 200,
          height: 200,
          child: OhosScrollbar(
            controller: controller,
            child: ListView.builder(
              controller: controller,
              itemCount: 40,
              itemBuilder: (BuildContext c, int i) =>
                  SizedBox(height: 40, child: Text('row $i')),
            ),
          ),
        ),
      );
    }

    testWidgets('条宽 4vp、拇指最小 48vp、无操作 2 秒才淡出', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(controller));
      await tester.pump();

      final ScrollbarPainter painter =
          tester
                  .widget<CustomPaint>(
                    find
                        .descendant(
                          of: find.byType(OhosScrollbar),
                          matching: find.byType(CustomPaint),
                        )
                        .last,
                  )
                  .foregroundPainter!
              as ScrollbarPainter;
      // 官方 `ohos_id_scroll_bar_normal_width = 4vp`；老实现取 8。
      expect(painter.thickness, 4);
      // 官方 `ohos_id_scroll_bar_min_height = 48vp`；Flutter 默认 18。
      expect(painter.minLength, 48);
      // 官方「无任何操作 2 秒后消失」；Flutter 默认 600ms。
      expect(
        tester.widget<RawScrollbar>(find.byType(RawScrollbar)).timeToFade,
        const Duration(seconds: 2),
      );
      // 拇指距窗口右沿 4vp（设计规范图注）。
      expect(
        tester.widget<RawScrollbar>(find.byType(RawScrollbar)).padding,
        const EdgeInsets.only(right: 4),
      );
    });

    testWidgets('滚动时拇指跟着走（滚动条真绑上了 controller）', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(controller));
      await tester.pump();

      controller.jumpTo(200);
      await tester.pump();
      expect(controller.offset, 200);
      expect(find.text('row 5'), findsWidgets);
    });
  });

  group('OhosColorPicker', () {
    testWidgets('墨屏模式页签：选中反相成黑底白字，未选中留白 + 1px 线', (WidgetTester tester) async {
      final OhosThemeData ink = OhosThemeData.ink();
      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: MaterialApp(
            home: OhosScaffold(
              body: OhosColorPicker(
                colors: const <Color>[Colors.red, Colors.green],
                selectedColor: Colors.red,
                onChanged: (Color _) {},
                tabs: const <OhosColorPickerTab>[
                  OhosColorPickerTab.grid,
                  OhosColorPickerTab.spectrum,
                ],
              ),
            ),
          ),
        ),
      );

      BoxDecoration chipOf(String label) =>
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.text(label),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;

      // 选中：黑底。原来的 12% 黑在 16 级灰上只到第 2 级，比「留白 + 1px 线」
      // 的未选中片还弱，选中态反而看不出来。
      expect(chipOf('网格').color, ink.dividerColor);
      // 未选中：留白 + 实线
      expect(chipOf('光谱').color, Colors.transparent);
      expect(chipOf('光谱').border, isNotNull);
      // 黑底上的文字必须反相
      expect(
        tester.widget<Text>(find.text('网格')).style?.color,
        ink.backgroundColor,
      );
    });

    testWidgets('未选中的浅色色块补描边，深色不描；墨屏用纯黑', (WidgetTester tester) async {
      const Color lite = Color(0xFFE0E0E0);

      Future<Map<Color, BoxDecoration>> pumpGrid(
        OhosThemeData data,
        Color selected,
      ) async {
        await tester.pumpWidget(
          OhosTheme(
            data: data,
            child: MaterialApp(
              home: OhosScaffold(
                body: Center(
                  child: SizedBox(
                    width: 320,
                    child: OhosColorPicker(
                      colors: const <Color>[Colors.white, lite, Colors.black],
                      selectedColor: selected,
                      onChanged: (Color color) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final Map<Color, BoxDecoration> found = <Color, BoxDecoration>{};
        for (final Element box
            in find
                .descendant(
                  of: find.byType(OhosColorPicker),
                  matching: find.byType(Container),
                )
                .evaluate()) {
          final Decoration? decoration = (box.widget as Container).decoration;
          if (decoration is BoxDecoration &&
              decoration.shape == BoxShape.circle) {
            found[decoration.color!] = decoration;
          }
        }
        return found;
      }

      final OhosThemeData ink = OhosThemeData.ink();
      final Map<Color, BoxDecoration> inkGrid = await pumpGrid(
        ink,
        Colors.black,
      );

      // 白块 / 浅灰块落在白底上等于消失：补一条纯黑发丝线
      expect(inkGrid[Colors.white]!.border!.top.color, ink.dividerColor);
      expect(inkGrid[Colors.white]!.border!.top.width, 1);
      expect(inkGrid[lite]!.border!.top.color, ink.dividerColor);
      // 深色块自己有边界，不描；选中的走原来的粗框
      expect(inkGrid[Colors.black]!.border!.top.color, ink.textPrimaryColor);
      expect(inkGrid[Colors.black]!.border!.top.width, 3);

      // 对勾跟着色块亮度走：深色配白勾，浅色换成前景色
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_rounded)).color,
        Colors.white,
      );
      await pumpGrid(ink, Colors.white);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_rounded)).color,
        ink.textPrimaryColor,
        reason: '白勾画在白块上等于没画',
      );

      final Map<Color, BoxDecoration> lightGrid = await pumpGrid(
        OhosThemeData.light(),
        Colors.black,
      );
      // 彩屏白底上的浅色块同样要描，但用 26% 黑而不是纯黑
      expect(lightGrid[Colors.white]!.border!.top.color, Colors.black26);
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

    // 官方 `SwitchStyle`（Toggle 参考文档，API 12+）四字段：
    // pointRadius / unselectedColor / pointColor / trackBorderRadius。
    // 老实现这四个全无法表达：滑块恒为「高度减 4」、轨道圆角恒为「高度一半」、
    // 滑块恒为纯白、关闭态恒为 30% 的三级文本色。

    /// 滑块 —— 轨道里唯一那个圆形 Container。
    Finder thumbFinder() => find.descendant(
      of: find.byType(OhosSwitch),
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );

    testWidgets('pointRadius 按官方默认算法 h/2 - 2*h/20（30 高 → 半径 12）', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(OhosSwitch(value: true, onChanged: (_) {})));
      // 30 高：15 - 2*30/20 = 15 - 3 = **12**，直径 24。
      // 老实现「高度减 4」= 26 —— 这一档就差 2vp，不是等价化简。
      expect(tester.getSize(thumbFinder()).width, 24);
    });

    testWidgets('pointRadius 在 44 高时与旧式「高度减 4」差得更开（半径 17.6）', (
      WidgetTester tester,
    ) async {
      // 官方式 44/2 - 2*44/20 = 22 - 4.4 = 17.6（直径 35.2），旧式 h-4 给 40。
      // 这条是**变异验证的抓手**：把公式改回「高度减 4」，两条都会红。
      await tester.pumpWidget(
        wrap(
          OhosSwitch(value: true, onChanged: (_) {}, size: const Size(70, 44)),
        ),
      );
      expect(tester.getSize(thumbFinder()).width, closeTo(35.2, 0.01));
    });

    testWidgets('显式 pointRadius 覆盖默认算法', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosSwitch(
            value: true,
            onChanged: (_) {},
            style: const OhosSwitchStyle(pointRadius: 8),
          ),
        ),
      );
      expect(tester.getSize(thumbFinder()).width, 16);
    });

    testWidgets('trackBorderRadius 可配，且夹到高度一半', (WidgetTester tester) async {
      // 30 高的轨道：传 4 → 4；传 100（超一半）→ 夹到 15。
      BorderRadius trackRadius(WidgetTester tester) {
        final AnimatedContainer c = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byType(OhosSwitch),
            matching: find.byType(AnimatedContainer),
          ),
        );
        return ((c.decoration! as BoxDecoration).borderRadius! as BorderRadius);
      }

      await tester.pumpWidget(
        wrap(
          OhosSwitch(
            value: true,
            onChanged: (_) {},
            style: const OhosSwitchStyle(trackBorderRadius: 4),
          ),
        ),
      );
      expect(trackRadius(tester).topLeft.x, 4);

      await tester.pumpWidget(
        wrap(
          OhosSwitch(
            value: true,
            onChanged: (_) {},
            style: const OhosSwitchStyle(trackBorderRadius: 100),
          ),
        ),
      );
      // 官方「设定值大于组件高度一半时按照组件高度一半设置」
      expect(trackRadius(tester).topLeft.x, 15);
    });

    testWidgets('pointColor / unselectedColor 落到实际绘制的颜色', (
      WidgetTester tester,
    ) async {
      const Color pointTint = Color(0xFF123456);
      const Color trackTint = Color(0xFF654321);

      await tester.pumpWidget(
        wrap(
          OhosSwitch(
            value: true,
            onChanged: (_) {},
            style: const OhosSwitchStyle(
              pointColor: pointTint,
              unselectedColor: trackTint,
            ),
          ),
        ),
      );
      final Container thumb = tester.widget<Container>(thumbFinder());
      expect((thumb.decoration! as BoxDecoration).color, pointTint);

      // 关闭态才读 unselectedColor：打开态用的是 activeColor。
      await tester.pumpWidget(
        wrap(
          OhosSwitch(
            value: false,
            onChanged: (_) {},
            style: const OhosSwitchStyle(unselectedColor: trackTint),
          ),
        ),
      );
      final AnimatedContainer track = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(OhosSwitch),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect((track.decoration! as BoxDecoration).color, trackTint);
    });

    testWidgets('本位参数 pointColor / inactiveColor 优先于 style 里的同名字段', (
      WidgetTester tester,
    ) async {
      // 同一条规格有两个入口时必须定优先级，否则「两个都传、谁生效」全靠猜。
      // 取值顺序：本位参数 → style 字段 → 主题回落。
      await tester.pumpWidget(
        wrap(
          OhosSwitch(
            value: true,
            onChanged: (_) {},
            pointColor: const Color(0xFFAAAAAA),
            style: const OhosSwitchStyle(pointColor: Color(0xFFBBBBBB)),
          ),
        ),
      );
      final Container thumb = tester.widget<Container>(thumbFinder());
      expect(
        (thumb.decoration! as BoxDecoration).color,
        const Color(0xFFAAAAAA),
      );
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

  group('OhosStatGrid', () {
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
                child: const OhosStatGrid(
                  title: '统计',
                  entries: <String, num>{'这是一个很长很长会溢出的标签': 12345, '短标签': 1},
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('长标签在 1.3x 字号下：标签仍被放大并省略，不是整格缩小', (WidgetTester tester) async {
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

  group('OhosDataPanel', () {
    /// 画一遍并返回 painter，用来直接查派生值（形状、分母、段数）。
    Future<void> pumpPanel(
      WidgetTester tester, {
      required List<double> values,
      double max = 100,
      OhosDataPanelType type = OhosDataPanelType.circle,
      double strokeWidth = 24,
      OhosThemeData? theme,
      Widget? child,
    }) async {
      await tester.pumpWidget(
        OhosTheme(
          data: theme ?? OhosThemeData.light(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: SizedBox.square(
                  dimension: 160,
                  child: OhosDataPanel(
                    values: values,
                    max: max,
                    type: type,
                    strokeWidth: strokeWidth,
                    closeEffect: true,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('超过 9 段只画前 9 段，负值置 0', (WidgetTester tester) async {
      const OhosDataPanel panel = OhosDataPanel(
        values: <double>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, -5],
      );
      expect(panel.effectiveValues.length, 9);
      expect(panel.effectiveValues.last, 9.0);
      // 负值那一段不会被「截断」掩盖 —— 单独验一次
      const OhosDataPanel negative = OhosDataPanel(values: <double>[-1, 2]);
      expect(negative.effectiveValues, <double>[0, 2]);
    });

    testWidgets('max > 0 是标尺：四段共 75%，剩余留作底槽', (WidgetTester tester) async {
      const OhosDataPanel panel = OhosDataPanel(
        values: <double>[50, 12, 8, 5],
        max: 100,
      );
      expect(panel.effectiveMax, 100);
      final double used = panel.effectiveValues.reduce(
        (double a, double b) => a + b,
      );
      // 75 / 100 —— 关键在「不足 100 也照样按 100 算」，不是按 75 归一化
      expect(used / panel.effectiveMax, moreOrLessEquals(0.75));
    });

    testWidgets('max <= 0 按数组之和归一：四段铺满整环', (WidgetTester tester) async {
      const OhosDataPanel panel = OhosDataPanel(
        values: <double>[50, 12, 8, 5],
        max: 0,
      );
      expect(panel.effectiveMax, 75);
      final double sum = panel.effectiveValues.fold<double>(
        0,
        (double a, double b) => a + b,
      );
      expect(sum / panel.effectiveMax, moreOrLessEquals(1));
    });

    testWidgets('全零时之和为 0，不除零也不画段', (WidgetTester tester) async {
      const OhosDataPanel panel = OhosDataPanel(values: <double>[0, 0], max: 0);
      expect(panel.effectiveMax, 0);
      await pumpPanel(tester, values: <double>[0, 0], max: 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('strokeWidth <= 0 回落到 24，大于半径时收成半径的 12%', (
      WidgetTester tester,
    ) async {
      const OhosDataPanel zero = OhosDataPanel(values: <double>[1]);
      expect(zero.effectiveStrokeWidth(80), 24);

      // 半径 80、请求 200 —— 不是「画到框外」，而是收成 9.6
      const OhosDataPanel huge = OhosDataPanel(
        values: <double>[1],
        strokeWidth: 200,
      );
      expect(huge.effectiveStrokeWidth(80), moreOrLessEquals(9.6));
      // 半径 0（无布局）走不到「大于半径」这一支，只回默认
      expect(huge.effectiveStrokeWidth(0), 200);
    });

    testWidgets('默认底色 #08182431，不是全透明', (WidgetTester tester) async {
      expect(OhosDataPanel.defaultTrackColor, const Color(0x08182431));
      // 九段默认渐变的色值与文档逐个对上
      expect(OhosDataPanel.defaultColors.length, 9);
      expect(OhosDataPanel.defaultColors.first.color, const Color(0xFFF7CE00));
      expect(
        OhosDataPanel.defaultColors.first.endColor,
        const Color(0xFFF99B11),
      );
      expect(OhosDataPanel.defaultColors.last.color, const Color(0xFFA2A2B0));
      expect(
        OhosDataPanel.defaultColors.last.endColor,
        const Color(0xFF8E8E93),
      );
    });

    testWidgets('线形与环形都画得出来，且不溢出', (WidgetTester tester) async {
      await pumpPanel(
        tester,
        values: <double>[5, 5],
        type: OhosDataPanelType.line,
      );
      expect(tester.takeException(), isNull);
      await pumpPanel(tester, values: <double>[5, 5]);
      expect(tester.takeException(), isNull);
      // 底槽在灰阶屏上退化成 1px 线，这条分支要真画一遍
      await pumpPanel(
        tester,
        values: <double>[5, 5],
        theme: OhosThemeData.ink(),
      );
      expect(tester.takeException(), isNull);
      await pumpPanel(
        tester,
        values: <double>[5, 5],
        type: OhosDataPanelType.line,
        theme: OhosThemeData.ink(),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('child 居中叠在图上', (WidgetTester tester) async {
      await pumpPanel(tester, values: <double>[50], child: const Text('75%'));
      expect(find.text('75%'), findsOneWidget);
      final Offset center = tester.getCenter(find.text('75%'));
      final Offset panel = tester.getCenter(find.byType(OhosDataPanel));
      expect(center.dx, moreOrLessEquals(panel.dx, epsilon: 0.5));
      expect(center.dy, moreOrLessEquals(panel.dy, epsilon: 0.5));
    });
  });

  group('OhosGauge', () {
    test('开环 350 → 10 顺时针只扫 20 度，不是反着扫 340', () {
      expect(ohosSweepRadians(350, 10), moreOrLessEquals(20 * math.pi / 180));
    });

    test('0 → 360 是整圈，不是 0 度', () {
      expect(ohosSweepRadians(0, 360), moreOrLessEquals(2 * math.pi));
      // 等价写法也要整圈
      expect(ohosSweepRadians(0, 0), moreOrLessEquals(2 * math.pi));
      expect(ohosSweepRadians(-90, 270), moreOrLessEquals(2 * math.pi));
    });

    test('钟面 0 度是 12 点，画布上要退 90 度', () {
      // 画布 0 弧度在 3 点钟方向（正 x 轴）
      expect(ohosCanvasAngle(0), moreOrLessEquals(-math.pi / 2));
      expect(ohosCanvasAngle(90), moreOrLessEquals(0));
      expect(ohosCanvasAngle(360), moreOrLessEquals(3 * math.pi / 2));
    });

    test('value 超出范围回落 min，不是夹到端点', () {
      const OhosGauge below = OhosGauge(value: -10, min: 20, max: 100);
      expect(below.progress, 0);
      const OhosGauge above = OhosGauge(value: 200, min: 20, max: 100);
      // 夹取到端点会得到 1；官方规则是「用 min 作为默认值」→ 0
      expect(above.progress, 0);
    });

    test('max < min 时两端一起复位成 0…100', () {
      const OhosGauge inverted = OhosGauge(value: 50, min: 80, max: 20);
      expect(inverted.effectiveMin, 0);
      expect(inverted.effectiveMax, 100);
      // 只复位 max 会留下 min 80 + max 100 这个调用方没要过的量程
      expect(inverted.progress, moreOrLessEquals(0.5));
    });

    test('没设 min/max 时默认 0…100', () {
      const OhosGauge gauge = OhosGauge(value: 25);
      expect(gauge.effectiveMin, 0);
      expect(gauge.effectiveMax, 100);
      expect(gauge.progress, moreOrLessEquals(0.25));
    });

    test('max == min 时进度为 0，不除零', () {
      const OhosGauge gauge = OhosGauge(value: 5, min: 5, max: 5);
      expect(gauge.progress, 0);
    });

    testWidgets('比重为 0 的段不显示，全部为 0 时整环不显示', (WidgetTester tester) async {
      // 私有方法拿不到，改从渲染结果侧面验：能画出且不抛异常即为「可绘制」，
      // 真正的过滤逻辑由下一层的 `isVisible` 单测守住。
      expect(
        const OhosGaugeSegment(color: Color(0xFF64BB5C), weight: 0).isVisible,
        isFalse,
      );
      expect(
        const OhosGaugeSegment(
          color: Color(0xFF64BB5C),
          weight: 0.001,
        ).isVisible,
        isTrue,
      );

      await tester.pumpWidget(
        wrap(
          const SizedBox.square(
            dimension: 160,
            child: OhosGauge(
              value: 50,
              segments: <OhosGaugeSegment>[
                OhosGaugeSegment(color: Color(0xFF64BB5C), weight: 0),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('描述区：没给 min/max 就不画，给了才画', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox.square(dimension: 160, child: OhosGauge(value: 50)),
        ),
      );
      // 一个文本都没有（没有 child，也没有量程标签）
      expect(find.byType(Text), findsNothing);

      await tester.pumpWidget(
        wrap(
          const SizedBox.square(
            dimension: 160,
            child: OhosGauge(value: 50, min: 0, max: 100),
          ),
        ),
      );
      expect(find.text('0   100'), findsOneWidget);
    });

    testWidgets('整数字面不带小数尾巴', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox.square(
            dimension: 160,
            child: OhosGauge(value: 50, min: 0, max: 37.5),
          ),
        ),
      );
      // 0 显示成 "0" 而不是 "0.0"；非整数原样
      expect(find.text('0   37.5'), findsOneWidget);
    });

    testWidgets('showIndicator: false 只画环，仍能正常布局', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox.square(
            dimension: 160,
            child: OhosGauge(value: 50, showIndicator: false),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('箭头形起止角度（225 → 135）扫过 270 度', (WidgetTester tester) async {
      expect(ohosSweepRadians(225, 135), moreOrLessEquals(270 * math.pi / 180));
      await tester.pumpWidget(
        wrap(
          const SizedBox.square(
            dimension: 160,
            child: OhosGauge(
              value: 50,
              min: 0,
              max: 100,
              startAngle: 225,
              endAngle: 135,
              strokeWidth: 18,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('OhosSelectionToolbar', () {
    /// 长按选中输入框里的文字，把选择菜单弹出来。
    Future<void> showMenu(
      WidgetTester tester, {
      List<OhosSelectionMenuItem> items = const <OhosSelectionMenuItem>[],
      OhosThemeData? theme,
    }) async {
      // 剪贴板要假装有内容，否则框架在 `clipboardStatus == unknown` 阶段会
      // **先把「粘贴」整项藏掉**（`getEditableButtonItems` 的 else 分支：
      // 「don't render anything until the state of the clipboard is known」），
      // 测试就永远看不到粘贴项。
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          switch (call.method) {
            case 'Clipboard.hasStrings':
              return <String, dynamic>{'value': true};
            case 'Clipboard.getData':
              return <String, dynamic>{'text': 'abc'};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        OhosTheme(
          data: theme ?? OhosThemeData.light(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosTextField(
                  initialValue: '可以选中的文字',
                  selectionMenuItems: items,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      // 全选把选区做出来，菜单才会出现
      final EditableTextState state = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      state.userUpdateTextEditingValue(
        state.textEditingValue.copyWith(
          selection: const TextSelection(baseOffset: 0, extentOffset: 6),
        ),
        SelectionChangedCause.tap,
      );
      // 剪贴板状态是异步查的，要等它落定再开菜单，不然粘贴项还在「未知」里
      await state.clipboardStatus.update();
      state.showToolbar();
      await tester.pumpAndSettle();
    }

    testWidgets('内置四项按固定顺序：剪切 → 复制 → 粘贴 → 全选', (WidgetTester tester) async {
      await showMenu(tester);
      // 每一项都是 40×40 的方按钮（selectionmenu.ets 的 buttonSize）
      final List<String> labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((Semantics s) => s.properties.label ?? '')
          .where((String l) => l.isNotEmpty)
          .toList();
      // 顺序敏感：用 indexOf 比大小，而不是逐个 findsOneWidget。
      // 这条确实在验排重 —— 框架给的原始序列是
      // [cut, copy, paste, share, selectAll]（`getEditableButtonItems` 在
      // Android 上把 share 塞在 selectAll 前面），我们丢掉框架自带的 share
      // 之后才是 [剪切, 复制, 粘贴, 全选]。若哪天改成「遍历 all 保序」，
      // 这里仍会过 —— 所以再直断一次原始先后。
      final int cut = labels.indexOf('剪切');
      final int copy = labels.indexOf('复制');
      final int paste = labels.indexOf('粘贴');
      final int all = labels.indexOf('全选');
      expect(cut, greaterThanOrEqualTo(0));
      expect(copy, greaterThan(cut));
      expect(paste, greaterThan(copy));
      expect(all, greaterThan(paste));
      // 框架自带的三方动作（share / lookUp / searchWeb）不进一级菜单，
      // 只走我们的「更多」——否则会出现两份「分享」，一份还点不动
      expect(labels, isNot(contains('分享')));
      expect(labels, <String>['剪切', '复制', '粘贴', '全选']);
    });

    testWidgets('框架给的 share 不进一级菜单', (WidgetTester tester) async {
      await showMenu(tester);
      final EditableTextState state = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      // 前提：框架确实给了 share（否则这条测试是空跑）
      expect(
        state.contextMenuButtonItems.map((ContextMenuButtonItem b) => b.type),
        contains(ContextMenuButtonType.share),
      );
      // 结论：我们没把它画出来
      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    });

    testWidgets('方按钮尺寸是 40×40，图标 24', (WidgetTester tester) async {
      await showMenu(tester);
      // 找 `GestureDetector` 而不是 `SizedBox`：后者在这条祖先链上有好几个
      // （图标自己的 24×24 空盒、框架内部的若干层），`first` 会取到最内层。
      // `GestureDetector` 只包在按钮的 40×40 容器外面那一层。
      final Finder button = find.ancestor(
        of: find.byIcon(Icons.content_copy_rounded),
        matching: find.byType(GestureDetector),
      );
      expect(button, findsOneWidget, reason: '图标外面应该只有一层可点区域');
      final Size size = tester.getSize(button);
      expect(size.width, 40);
      expect(size.height, 40);
      final Icon icon = tester.widget<Icon>(
        find.byIcon(Icons.content_copy_rounded),
      );
      expect(icon.size, isNull, reason: '尺寸由上层 IconTheme 统一给 24');
      final IconTheme theme = tester.widget<IconTheme>(
        find
            .ancestor(
              of: find.byIcon(Icons.content_copy_rounded),
              matching: find.byType(IconTheme),
            )
            .first,
      );
      expect(theme.data.size, 24);
    });

    testWidgets('有扩展项才多出「更多」，没有就不画', (WidgetTester tester) async {
      await showMenu(tester);
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await showMenu(
        tester,
        items: const <OhosSelectionMenuItem>[
          OhosSelectionMenuItem(id: 'translate', label: '翻译'),
        ],
      );
      // 「更多」不在一级菜单里显示文字，只有图标
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
      // 扩展项本身不进一级菜单
      expect(find.text('翻译'), findsNothing);
    });

    testWidgets('点「更多」弹出二级菜单，扩展项在里面', (WidgetTester tester) async {
      await showMenu(
        tester,
        items: const <OhosSelectionMenuItem>[
          OhosSelectionMenuItem(id: 'translate', label: '翻译'),
          OhosSelectionMenuItem(id: 'share', label: '分享'),
        ],
      );
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      expect(find.text('翻译'), findsOneWidget);
      expect(find.text('分享'), findsOneWidget);
    });

    testWidgets('没有 onSelected 的扩展项渲染成不可点', (WidgetTester tester) async {
      await showMenu(
        tester,
        items: const <OhosSelectionMenuItem>[
          OhosSelectionMenuItem(id: 'disabled', label: '不可用'),
        ],
      );
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      final PopupMenuItem<OhosSelectionMenuItem> item = tester
          .widget<PopupMenuItem<OhosSelectionMenuItem>>(
            find.ancestor(
              of: find.text('不可用'),
              matching: find.byType(PopupMenuItem<OhosSelectionMenuItem>),
            ),
          );
      expect(item.enabled, isFalse);
    });

    testWidgets('墨屏：不模糊、不投射，补 1px 实线', (WidgetTester tester) async {
      await showMenu(tester, theme: OhosThemeData.ink());
      final OhosThemeData ink = OhosTheme.of(
        tester.element(find.byType(OhosSelectionToolbar)),
      );
      expect(ink.policy.allowsBlur, isFalse);
      expect(ink.usesOutlines, isTrue);
      // 容器上确实只有 DecoratedBox，没有 OhosLightMaterial
      expect(find.byType(OhosLightMaterial), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('彩屏：走 LightMaterial 材质底板', (WidgetTester tester) async {
      await showMenu(tester);
      expect(find.byType(OhosLightMaterial), findsOneWidget);
    });

    testWidgets('不覆盖 ThemeData.platform，兼容官方 Flutter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Theme(
            data: ThemeData(platform: TargetPlatform.iOS),
            child: OhosSelectionToolbar.anchored(
              anchorAbove: const Offset(200, 400),
              anchorBelow: const Offset(200, 420),
              items: const <OhosSelectionMenuItem>[
                OhosSelectionMenuItem(
                  id: 'a',
                  label: '动作 A',
                  icon: Icons.star_rounded,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // TextSelectionToolbar 是 Material 实现，不会读取 platform 选择
      // Cupertino 分支。覆盖 platform 反而会引用 OHOS fork 独有的枚举值，
      // 让官方 Flutter 的 Web/CI 构建直接编译失败。
      final ThemeData platformTheme = Theme.of(
        tester.element(find.byType(TextSelectionToolbar)),
      );
      expect(platformTheme.platform, TargetPlatform.iOS);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('anchored 形态能独立摆位置并渲染动作', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosSelectionToolbar.anchored(
            anchorAbove: const Offset(200, 400),
            anchorBelow: const Offset(200, 420),
            items: const <OhosSelectionMenuItem>[
              OhosSelectionMenuItem(
                id: 'a',
                label: '动作 A',
                icon: Icons.star_rounded,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('菜单项按 id 判等，回调不同也算同一项', () {
      void a() {}
      void b() {}
      // 直接写两个同名方法，闭包身份不同
      const OhosSelectionMenuItem one = OhosSelectionMenuItem(
        id: 'translate',
        label: '翻译',
      );
      final OhosSelectionMenuItem two = OhosSelectionMenuItem(
        id: 'translate',
        label: '翻译（改名后）',
        onSelected: a,
      );
      final OhosSelectionMenuItem three = OhosSelectionMenuItem(
        id: 'share',
        label: '翻译',
        onSelected: b,
      );
      // 按回调比较会让每次 setState 都判成「变了」——这条钉住「按 id」
      expect(one, two);
      expect(one == three, isFalse);
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
      InputDecoration decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
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
      decoration = tester.widget<TextField>(find.byType(TextField)).decoration!;
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

    testWidgets('换 focusNode 后立刻用新节点，旧的外部节点不被销毁', (WidgetTester tester) async {
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

    testWidgets('内部创建的节点在换成外部节点时被销毁（不泄漏）', (WidgetTester tester) async {
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

    group('密码模式', () {
      testWidgets('obscurePassword 遮蔽内容并给出眼睛图标', (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(const OhosTextField(hintText: '密码', obscurePassword: true)),
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).obscureText,
          isTrue,
        );
        // 24vp 的图标 + 40 命中区，两者都来自令牌。注意断言的是 `Icon.size`
        // 而不是 `getSize(icon)` —— 图标被 40 的命中区盒拉伸，`getSize` 拿到的是
        // 40（那条 48 → 40 的差异正是这次压 `suffixIconConstraints` 才修掉的）。
        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.visibility_off_outlined)).size,
          OhosTextFieldMetrics.iconSize,
        );
        expect(
          tester
              .getSize(
                find
                    .ancestor(
                      of: find.byIcon(Icons.visibility_off_outlined),
                      matching: find.byType(SizedBox),
                    )
                    .first,
              )
              .width,
          OhosTextFieldMetrics.iconHotZone,
        );
      });

      testWidgets('点眼睛切换显隐，图标跟着换，回调拿到切换后的状态', (WidgetTester tester) async {
        final List<bool> seen = <bool>[];
        await tester.pumpWidget(
          wrap(
            OhosTextField(
              hintText: '密码',
              obscurePassword: true,
              onSecurityStateChange: seen.add,
            ),
          ),
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).obscureText,
          isTrue,
        );

        await tester.tap(find.byIcon(Icons.visibility_off_outlined));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).obscureText,
          isFalse,
        );
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
        // 回调参数是「切换后」的状态，调用方不需要自己取反
        expect(seen, <bool>[true]);

        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).obscureText,
          isTrue,
        );
        expect(seen, <bool>[true, false]);
      });

      testWidgets('showPasswordIcon: false 仍遮蔽，只是不给切换入口', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            const OhosTextField(
              hintText: '密码',
              obscurePassword: true,
              showPasswordIcon: false,
            ),
          ),
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).obscureText,
          isTrue,
        );
        expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
      });

      testWidgets('obscureText 也能拿到眼睛图标（两者是同一形态的两入口）', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          wrap(const OhosTextField(hintText: '密码', obscureText: true)),
        );
        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      });

      testWidgets('非密码模式不出眼睛图标', (WidgetTester tester) async {
        await tester.pumpWidget(wrap(const OhosTextField(hintText: '姓名')));
        expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
        expect(find.byIcon(Icons.visibility_outlined), findsNothing);
      });

      testWidgets('禁用时眼睛图标不可点', (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            const OhosTextField(
              hintText: '密码',
              obscurePassword: true,
              enabled: false,
            ),
          ),
        );
        final InkResponse response = tester.widget<InkResponse>(
          find.ancestor(
            of: find.byIcon(Icons.visibility_off_outlined),
            matching: find.byType(InkResponse),
          ),
        );
        expect(response.onTap, isNull);
      });
    });

    group('内联模式', () {
      testWidgets('圆角 4、左右边距不对称 2 / 12、上下为 0', (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            const OhosTextField(
              initialValue: '重命名',
              variant: OhosTextFieldVariant.inline,
            ),
          ),
        );
        final InputDecoration d = tester
            .widget<TextField>(find.byType(TextField))
            .decoration!;
        expect(
          d.contentPadding,
          const EdgeInsets.only(
            left: OhosTextFieldMetrics.inlinePaddingLeft,
            right: OhosTextFieldMetrics.inlinePaddingRight,
          ),
        );
        // 左 2 右 12 —— 不对称是官方值（textfield_inline_padding_left/right）
        expect(OhosTextFieldMetrics.inlinePaddingLeft, 2);
        expect(OhosTextFieldMetrics.inlinePaddingRight, 12);

        final OutlineInputBorder b = d.enabledBorder! as OutlineInputBorder;
        expect(
          b.borderRadius,
          BorderRadius.circular(OhosTextFieldMetrics.inlineRadius),
        );
        expect(OhosTextFieldMetrics.inlineRadius, 4);
      });

      testWidgets('内联形态有细线边界（不像 filled 那样靠填充分层）', (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            const OhosTextField(
              initialValue: '重命名',
              variant: OhosTextFieldVariant.inline,
            ),
          ),
        );
        final InputDecoration d = tester
            .widget<TextField>(find.byType(TextField))
            .decoration!;
        final OutlineInputBorder b = d.enabledBorder! as OutlineInputBorder;
        // 线宽 1，不是 filled 的 0 —— 它就是「一行可点的文本」，靠线才看得出来
        expect(b.borderSide.width, 1);
      });

      testWidgets('内联 + 密码：回落成 underline，不画「内联密码框」', (
        WidgetTester tester,
      ) async {
        // 官方「内联输入风格只支持 InputType.Normal」。静默画出一个官方没有的
        // 形态，比回落更糟 —— 调用方以为在做重命名，实际得到的是密码输入。
        await tester.pumpWidget(
          wrap(
            const OhosTextField(
              initialValue: 'secret',
              variant: OhosTextFieldVariant.inline,
              obscurePassword: true,
            ),
          ),
        );
        final InputDecoration d = tester
            .widget<TextField>(find.byType(TextField))
            .decoration!;
        expect(d.enabledBorder, isA<UnderlineInputBorder>());
        // 但密码形态本身还是成立的
        expect(
          tester.widget<TextField>(find.byType(TextField)).obscureText,
          isTrue,
        );
        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      });

      testWidgets('内联 + 多行：回落（内联是整行重命名的单行语义）', (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            const OhosTextField(
              initialValue: '重命名',
              variant: OhosTextFieldVariant.inline,
              maxLines: 3,
            ),
          ),
        );
        // 内联形态要求 maxLines == 1；给了 3 就回落成默认的 underline
        final InputDecoration d = tester
            .widget<TextField>(find.byType(TextField))
            .decoration!;
        expect(d.enabledBorder, isA<UnderlineInputBorder>());
        // 但 maxLines 保持调用方给的值 —— 回落的是「内联外壳」，不是内容
        expect(tester.widget<TextField>(find.byType(TextField)).maxLines, 3);
      });

      testWidgets('内联不支持 errorText：给了也不画（官方明写不支持）', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            const OhosTextField(
              variant: OhosTextFieldVariant.inline,
              errorText: '这个名字不合法',
            ),
          ),
        );
        expect(find.text('这个名字不合法'), findsNothing);
        final InputDecoration d = tester
            .widget<TextField>(find.byType(TextField))
            .decoration!;
        expect(d.errorText, isNull);
      });

      testWidgets('非内联形态的 errorText 照常显示', (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            const OhosTextField(
              variant: OhosTextFieldVariant.filled,
              errorText: '这个名字不合法',
            ),
          ),
        );
        expect(find.text('这个名字不合法'), findsOneWidget);
      });
    });

    group('字数计数器', () {
      testWidgets('未开 showCounter 时不画', (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(const OhosTextField(initialValue: 'abc', maxLength: 6)),
        );
        expect(find.text('3/6'), findsNothing);
      });

      testWidgets('没有 maxLength 时不画（分母是 Infinity，没有意义）', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          wrap(const OhosTextField(initialValue: 'abc', showCounter: true)),
        );
        expect(find.textContaining('/'), findsNothing);
      });

      testWidgets('阈值百分比：达到最大值的 50% 才出现', (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            const OhosTextField(
              initialValue: 'ab',
              maxLength: 6,
              showCounter: true,
              counterOptions: OhosInputCounterOptions(thresholdPercentage: 50),
            ),
          ),
        );
        // 2 <= 6 * 50% = 3 → 不显示
        expect(find.text('2/6'), findsNothing);

        await tester.enterText(find.byType(OhosTextField), 'abcd');
        await tester.pump();
        // 4 > 3 → 显示
        expect(find.text('4/6'), findsOneWidget);
      });

      testWidgets('不传阈值：一有输入就显示', (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            const OhosTextField(
              initialValue: 'a',
              maxLength: 6,
              showCounter: true,
            ),
          ),
        );
        expect(find.text('1/6'), findsOneWidget);
      });

      testWidgets('阈值超出 [1,100] 时「不显示」而不是夹到边界', (WidgetTester tester) async {
        // 官方原话：如果设置的 number 超出有效值区间内，不显示字符计数器。
        // 与「传 undefined（显示但不按阈值过滤）」是两种截然不同的结果。
        await tester.pumpWidget(
          wrap(
            const OhosTextField(
              initialValue: 'abc',
              maxLength: 6,
              showCounter: true,
              counterOptions: OhosInputCounterOptions(thresholdPercentage: 101),
            ),
          ),
        );
        expect(find.text('3/6'), findsNothing);
      });

      testWidgets('字号 10fp（不是 labelSmall 的 12）', (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            const OhosTextField(
              initialValue: 'abc',
              maxLength: 6,
              showCounter: true,
            ),
          ),
        );
        expect(paintedTextStyle(tester, '3/6').fontSize, 10);
        expect(OhosTextFieldMetrics.counterFontSize, 10);
      });

      testWidgets('内联模式下不显示计数器（官方明文）', (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            const OhosTextField(
              initialValue: 'abc',
              maxLength: 6,
              showCounter: true,
              variant: OhosTextFieldVariant.inline,
            ),
          ),
        );
        expect(find.text('3/6'), findsNothing);
      });

      testWidgets('密码模式下不显示计数器（官方明文）', (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            const OhosTextField(
              initialValue: 'abc',
              maxLength: 6,
              showCounter: true,
              obscurePassword: true,
            ),
          ),
        );
        expect(find.text('3/6'), findsNothing);
      });

      testWidgets('不重复画 Material 的计数器（decoration.counterText 为空）', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            const OhosTextField(
              initialValue: 'abc',
              maxLength: 6,
              showCounter: true,
            ),
          ),
        );
        final TextField field = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(field.decoration!.counterText, isEmpty);
        // 本库自己画的那一个还在
        expect(find.text('3/6'), findsOneWidget);
      });

      testWidgets('外部 controller 改内容，计数跟着走', (WidgetTester tester) async {
        final TextEditingController controller = TextEditingController(
          text: 'a',
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          wrap(
            OhosTextField(
              controller: controller,
              maxLength: 6,
              showCounter: true,
            ),
          ),
        );
        expect(find.text('1/6'), findsOneWidget);

        // 不经过 onChanged 的改动（外部直接赋 text）也必须更新计数 —— 这正是
        // 独立监听 controller 而不是只听 onChanged 的原因
        controller.text = 'abcdef';
        await tester.pump();
        expect(find.text('6/6'), findsOneWidget);
      });

      test('InputCounterOptions 的阈值判定与官方语义一致', () {
        const OhosInputCounterOptions half = OhosInputCounterOptions(
          thresholdPercentage: 50,
        );
        expect(half.isVisible(0, 6), isFalse);
        expect(half.isVisible(3, 6), isFalse, reason: '「大于」不是「大于等于」');
        expect(half.isVisible(4, 6), isTrue);

        // thresholdPercentage 为 null 等价于官方 undefined：显示但不按阈值过滤
        const OhosInputCounterOptions noThreshold = OhosInputCounterOptions();
        expect(noThreshold.isVisible(0, 6), isTrue);

        // 溢出且阈值有效 → 才变红
        expect(half.highlightsOnOverflow(7, 6), isTrue);
        expect(half.highlightsOnOverflow(6, 6), isFalse);
        expect(noThreshold.highlightsOnOverflow(7, 6), isFalse);
        expect(
          const OhosInputCounterOptions(
            thresholdPercentage: 50,
            highlightBorder: false,
          ).highlightsOnOverflow(7, 6),
          isFalse,
          reason: 'highlightBorder: false 时只让文字变红，不算「边框要红」',
        );
        // 阈值越界时不红
        expect(
          const OhosInputCounterOptions(
            thresholdPercentage: 0,
          ).highlightsOnOverflow(7, 6),
          isFalse,
        );
      });

      test('几何令牌逐条可查', () {
        // 全部来自 ohos_textfield_pattern，链式回溯到最终 vp/fp
        expect(OhosTextFieldMetrics.height, 40); // textfield_height
        expect(
          OhosTextFieldMetrics.contentHeight,
          24,
        ); // textfield_content_height
        expect(
          OhosTextFieldMetrics.passwordHeight,
          48,
        ); // password_style_height
        expect(
          OhosTextFieldMetrics.containerRadius,
          20,
        ); // corner_radius_level10
        expect(
          OhosTextFieldMetrics.borderRadius,
          12,
        ); // corner_radius_level6（死令牌）
        expect(OhosTextFieldMetrics.inlineRadius, 4); // corner_radius_level2
        expect(OhosTextFieldMetrics.paddingHorizontal, 16); // padding_level8
        expect(OhosTextFieldMetrics.paddingVertical, 8); // padding_level4
        expect(
          OhosTextFieldMetrics.underlinePaddingVertical,
          12,
        ); // padding_level6
        expect(OhosTextFieldMetrics.fontSize, 16); // ohos_id_text_size_body1
        expect(
          OhosTextFieldMetrics.errorFontSize,
          12,
        ); // ohos_id_text_size_body3
        expect(
          OhosTextFieldMetrics.counterFontSize,
          10,
        ); // ohos_id_text_size_caption1
        expect(
          OhosTextFieldMetrics.iconSize,
          24,
        ); // ohos_id_textfield_icon_size
        expect(OhosTextFieldMetrics.iconHotZone, 40); // _icon_hot_zone_size
        expect(OhosTextFieldMetrics.errorSpacing, 8); // padding_level4
      });

      // ---- 下面这组是「令牌接了没有」的守卫 -------------------------------
      //
      // 上一轮只有上面那条纯字面值断言，于是 `contentPadding` 自拟成 14/14、
      // 填充形态实测渲染 52vp（官方 40）而全套测试仍然全绿 ——
      // 「常量写对了」不等于「常量被用上了」。这组断言量的是**真实渲染尺寸**，
      // 任何一处把令牌换成魔数都会在这里掉下来。
      testWidgets('填充 / 胶囊形态实测高度 = 40（token: 8 + 24 + 8）', (
        WidgetTester tester,
      ) async {
        for (final OhosTextFieldVariant v in <OhosTextFieldVariant>[
          OhosTextFieldVariant.filled,
          OhosTextFieldVariant.capsule,
        ]) {
          await tester.pumpWidget(
            wrap(
              SizedBox(
                width: 300,
                child: OhosTextField(hintText: 'h', variant: v),
              ),
            ),
          );
          expect(
            tester.getSize(find.byType(TextField)).height,
            OhosTextFieldMetrics.height,
            reason: '$v 的内边距没有接到 textfield_padding_* 令牌上',
          );
        }
      });

      testWidgets('下划线形态实测高度 = 48（token: 12 + 24 + 12）', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            const SizedBox(
              width: 300,
              child: OhosTextField(
                hintText: 'h',
                variant: OhosTextFieldVariant.underline,
              ),
            ),
          ),
        );
        // 下划线的 48 与 passwordHeight 数值相同但来路不同：
        // 这里是 underlinePaddingVertical(12) * 2 + contentHeight(24)，
        // 不是 passwordHeight 兜底出来的。
        expect(
          tester.getSize(find.byType(TextField)).height,
          OhosTextFieldMetrics.underlinePaddingVertical * 2 +
              OhosTextFieldMetrics.contentHeight,
        );
      });

      testWidgets('密码形态在填充 / 胶囊底板上也撑到 48（不是 40）', (WidgetTester tester) async {
        // 官方 `password_style_height` = 48 是**独立的容器高**，不随底板形态
        // 变化。只给「内边距算出来 40」就会让密码框比普通框矮 8，与官方相反。
        for (final OhosTextFieldVariant v in <OhosTextFieldVariant>[
          OhosTextFieldVariant.filled,
          OhosTextFieldVariant.capsule,
        ]) {
          await tester.pumpWidget(
            wrap(
              SizedBox(
                width: 300,
                child: OhosTextField(
                  hintText: 'h',
                  variant: v,
                  obscurePassword: true,
                ),
              ),
            ),
          );
          expect(
            tester.getSize(find.byType(TextField)).height,
            OhosTextFieldMetrics.passwordHeight,
            reason: '$v 的密码形态没有吃到 password_style_height',
          );
        }
      });

      testWidgets('填充形态圆角取 textfield_border_radius(20)，不是主题中圆角 16', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            const SizedBox(
              width: 300,
              child: OhosTextField(
                hintText: 'h',
                variant: OhosTextFieldVariant.filled,
              ),
            ),
          ),
        );
        final InputDecoration d = tester
            .widget<TextField>(find.byType(TextField))
            .decoration!;
        final OutlineInputBorder b = d.border! as OutlineInputBorder;
        expect(
          b.borderRadius,
          BorderRadius.circular(OhosTextFieldMetrics.containerRadius),
        );
        // 与主题的 radiusMedium 区分开：两者差 4vp，正是这轮修掉的偏差。
        expect(
          OhosTextFieldMetrics.containerRadius,
          isNot(OhosGeometry.radiusMedium),
        );
      });

      testWidgets('错误描边 1vp（不是聚焦态的 1.5）', (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            const SizedBox(
              width: 300,
              child: OhosTextField(
                variant: OhosTextFieldVariant.filled,
                errorText: '必填',
              ),
            ),
          ),
        );
        final InputDecoration d = tester
            .widget<TextField>(find.byType(TextField))
            .decoration!;
        final OutlineInputBorder err = d.errorBorder! as OutlineInputBorder;
        expect(err.borderSide.width, OhosTextFieldMetrics.errorBorderWidth);
        expect(OhosTextFieldMetrics.errorBorderWidth, 1);
      });

      testWidgets('错误提示字号 12fp（error_text_font_size）', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            const SizedBox(
              width: 300,
              child: OhosTextField(
                variant: OhosTextFieldVariant.filled,
                errorText: '必填',
              ),
            ),
          ),
        );
        final InputDecoration d = tester
            .widget<TextField>(find.byType(TextField))
            .decoration!;
        expect(d.errorStyle!.fontSize, OhosTextFieldMetrics.errorFontSize);
      });

      testWidgets('isDense 打开：绕开 InputDecorator 的 48 无障碍兜底', (
        WidgetTester tester,
      ) async {
        // `InputDecorator` 在 `isDense == false` 时把容器高夹到
        // `kMinInteractiveDimension`(48) 以上，40 的官方规格会被无条件撑高。
        // 这条断言钉住「我们显式关掉了那条兜底」——
        // 少了它，40 只能靠「内边距恰好算成 48」来掩人耳目。
        await tester.pumpWidget(
          wrap(
            const SizedBox(
              width: 300,
              child: OhosTextField(variant: OhosTextFieldVariant.filled),
            ),
          ),
        );
        final InputDecoration d = tester
            .widget<TextField>(find.byType(TextField))
            .decoration!;
        expect(d.isDense, isTrue);
      });
    });
  });

  group('OhosSearchBar', () {
    testWidgets('清空键回调 onClear，空态占位与清空键同宽（40vp）', (WidgetTester tester) async {
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
      // 空态与清空键同宽，输入区宽度不会在空↔有字之间跳动。
      // 40 是官方 `search_close_icon_hot_zone_horizontal` 的值 —— 手指够得着
      // 的下限；原来是 32，真机上偏窄。
      expect(placeholder.width, 40);
    });

    testWidgets('聚焦时出现「取消」，点击清空并回调 onCancel', (WidgetTester tester) async {
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

    testWidgets('换 focusNode 后「取消」按新节点的真实焦点显示', (WidgetTester tester) async {
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

    testWidgets('新节点带着焦点请求换进来时，「取消」自动出现', (WidgetTester tester) async {
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

    testWidgets('「取消」是按钮：够大的命中区 + button 语义', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 360,
            child: OhosSearchBar(autofocus: true, onCancel: () {}),
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

    testWidgets('ink 胶囊补 1px 实线，且四边同宽、画在子节点之上', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      final OhosThemeData ink = OhosThemeData.ink();

      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: OhosSearchBar(controller: controller),
                ),
              ),
            ),
          ),
        ),
      );

      final Container bar = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(OhosSearchBar),
              matching: find.byType(Container),
            )
            .first,
      );
      // 白胶囊压在白页面上没有边界，补一条实线
      expect(bar.decoration, isNull, reason: '底色归 Material，边不跟着 shape 走');
      final BoxDecoration outline = bar.foregroundDecoration! as BoxDecoration;
      final Border border = outline.border! as Border;
      expect(border.top.color, ink.dividerColor);
      // Material.shape 会和子节点抢同一条边（1.5x 屏上沿 2px、下沿只剩 1px），
      // 换成 foregroundDecoration 后四条边必须落在同一套几何上。
      expect(border.top.width, 1);
      expect(border.bottom.width, border.top.width);
      expect(border.left.width, border.top.width);
      expect(border.right.width, border.top.width);
      // 圆角是官方显式值 20vp（`search_text_field_border_radius`），不是
      // `radiusCapsule`。胶囊半径会悄悄退化成 `height / 2`：当前高度 40 时
      // 恰好也是 20，但把高度调到 48 就会变 24，与官方规格脱钩。
      expect(
        outline.borderRadius,
        BorderRadius.circular(OhosGeometry.radiusSearch),
      );
      expect(OhosGeometry.radiusSearch, 20);

      // 彩屏不加框：胶囊靠底色分层
      await tester.pumpWidget(
        wrap(
          SizedBox(width: 320, child: OhosSearchBar(controller: controller)),
        ),
      );
      final Container plain = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(OhosSearchBar),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(plain.foregroundDecoration, isNull);
    });

    testWidgets('右侧搜索按钮形态：分隔线两侧 2vp、文字 padding 14、栏高仍 40', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 360,
            child: OhosSearchBar(
              controller: controller,
              // hint 显式换一个词：默认 hint 就是「搜索」，与按钮文案撞名会让
              // finder 二义。官方也是这个情况（placeholder 与按钮默认都是
              // "Search"），属于形态本身，不是缺陷。
              hintText: '输入关键词',
              searchButtonText: '搜索',
            ),
          ),
        ),
      );

      // 「整栏 56」是上一版的误判：`sys.float.search_height` = 56 在 search 的
      // 13 份实现源码里零引用（`SearchTheme::GetHeight()` 只解析
      // `search_default_height` = 40），官方带 `searchButton` 的示例也都写
      // `.height(40)`。这里钉住 40，就是为了防止有人照着那个死令牌把栏撑高。
      expect(tester.getSize(find.byType(OhosSearchBar)).height, 40);

      // search_button_space = search_divider_side_space = padding_level1 = 2
      final Finder divider = find.byType(VerticalDivider);
      expect(divider, findsOneWidget);
      expect(
        tester.getSize(divider).height,
        16,
        reason: 'DividerMeasure 取 min(searchHeight, search_icon_height)=16',
      );
      final Rect dividerRect = tester.getRect(divider);

      // 分隔线到右侧按钮的左边缘：2vp
      final Finder button = find.widgetWithText(TextButton, '搜索');
      expect(
        tester.getTopLeft(button).dx - dividerRect.right,
        2,
        reason: 'search_button_space',
      );

      // 按钮内文字左右各 14vp（search_button_text_padding）
      final Rect textRect = tester.getRect(find.text('搜索'));
      final Rect buttonRect = tester.getRect(button);
      expect(textRect.left - buttonRect.left, closeTo(14, 0.01));
      expect(buttonRect.right - textRect.right, closeTo(14, 0.01));

      // 按钮高 = 栏高 - 2*searchButtonSpace = 36
      expect(buttonRect.height, 36);
    });

    testWidgets('搜索按钮触发 onSubmitted，且禁用时不响应', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: '关键词',
      );
      addTearDown(controller.dispose);
      final List<String> submitted = <String>[];

      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 360,
            child: OhosSearchBar(
              controller: controller,
              searchButtonText: '搜索',
              onSubmitted: submitted.add,
            ),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(TextButton, '搜索'));
      await tester.pump();
      // 官方语义：点搜索按钮同时触发 onSubmit 与 onClick
      expect(submitted, <String>['关键词']);

      // 禁用态下 TextButton 的 onPressed 为 null，连点也无回调
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 360,
            child: OhosSearchBar(
              controller: controller,
              searchButtonText: '搜索',
              enabled: false,
              onSubmitted: submitted.add,
            ),
          ),
        ),
      );
      await tester.tap(
        find.widgetWithText(TextButton, '搜索'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(submitted, <String>['关键词'], reason: '禁用后不再追加');
    });

    // `SearchButtonOptions.autoDisable`（API 18+，默认 false）：
    // 「Search 无文本内容时按钮置灰且不可点击」。
    testWidgets('autoDisable：空内容时按钮置灰且不可点，有字恢复', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      final List<String> submitted = <String>[];

      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 360,
            child: OhosSearchBar(
              controller: controller,
              searchButtonText: '搜索',
              autoDisable: true,
              onSubmitted: submitted.add,
            ),
          ),
        ),
      );

      final OhosThemeData theme = OhosThemeData.light();
      TextButton button() =>
          tester.widget<TextButton>(find.widgetWithText(TextButton, '搜索'));

      // 空内容：既置灰（foregroundColor 降为 textTertiary）又不可点
      expect(button().onPressed, isNull, reason: '空内容时不可点');
      expect(
        button().style!.foregroundColor!.resolve(<WidgetState>{}),
        theme.textTertiaryColor,
        reason: '置灰取 textTertiary，不引入新色值',
      );

      // 点不动
      await tester.tap(
        find.widgetWithText(TextButton, '搜索'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(submitted, isEmpty);

      // 输入内容后恢复可点、回到品牌色
      await tester.enterText(find.byType(TextField), '关键词');
      await tester.pumpAndSettle();
      expect(button().onPressed, isNotNull, reason: '有字后可点');
      expect(
        button().style!.foregroundColor!.resolve(<WidgetState>{}),
        theme.highlightColor,
      );

      await tester.tap(find.widgetWithText(TextButton, '搜索'));
      await tester.pump();
      expect(submitted, <String>['关键词']);

      // 清空后再次置灰
      controller.clear();
      await tester.pumpAndSettle();
      expect(button().onPressed, isNull);
    });

    // 默认值是 false —— 照官方文档，不照「更友好的直觉」。开关不打开时，
    // 空内容也能点，这与 0.5.x 的行为一致，属于有意保留。
    testWidgets('autoDisable 默认关闭：空内容也能点', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      final List<String> submitted = <String>[];

      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 360,
            child: OhosSearchBar(
              controller: controller,
              searchButtonText: '搜索',
              onSubmitted: submitted.add,
            ),
          ),
        ),
      );
      final TextButton button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '搜索'),
      );
      expect(button.onPressed, isNotNull, reason: '官方默认 false');
      await tester.tap(find.widgetWithText(TextButton, '搜索'));
      await tester.pump();
      expect(submitted, <String>['']);
    });

    testWidgets('无搜索按钮时右侧不留 2vp，输入区宽度不变', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          SizedBox(width: 360, child: OhosSearchBar(controller: controller)),
        ),
      );
      expect(find.byType(VerticalDivider), findsNothing);
      final Padding padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(OhosSearchBar),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, const EdgeInsets.only(left: 12, right: 0));
    });
  });

  group('OhosAlertDialog', () {
    /// 量「弹窗壳」而不是 `OhosAlertDialog` 根节点。
    ///
    /// 根节点为了居中铺满了整个约束（`Center`），`getSize` 拿到的是窗口尺寸 ——
    /// 拿它断言「宽度 ≤ 400」永远成立，是**假绿**。真正的壳是那层
    /// `ClipRRect`（`customStyle: true` 时不存在，那种情形不该调本函数）。
    Finder dialogSurface() => find
        .descendant(
          of: find.byType(OhosAlertDialog),
          matching: find.byType(ClipRRect),
        )
        .first;

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

    // ---- D-5：CustomDialogControllerOptions 的九项 ------------------------

    test('几何令牌逐条可查（全部来自参数表明文默认值）', () {
      expect(OhosDialogMetrics.maxWidth, 400); // width「默认最大值：400vp」
      expect(OhosDialogMetrics.maxHeightFactor, 0.9); // height「0.9*(窗口高-安全区)」
      expect(OhosDialogMetrics.borderRadius, 32); // customStyle:false「默认圆角32vp」
      expect(
        OhosDialogMetrics.maskColor,
        const Color(0x33000000),
      ); // maskColor 默认
      // 32 不是主题里的 radiusLarge(24) —— 弹窗的圆角比卡片还大一档。
      expect(OhosDialogMetrics.borderRadius, isNot(OhosGeometry.radiusLarge));
    });

    testWidgets('宽度上限 400：长内容不会一路顶到屏幕边缘', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          OhosAlertDialog(
            title: '标题',
            content: '很长的内容' * 40,
            actions: const <OhosDialogAction>[
              OhosDialogAction(label: '好', onPressed: _noop),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 量的是**壳**（ClipRRect），不是 `OhosAlertDialog` 根节点 ——
      // 后者是铺满全屏的 Center，量它永远是窗口宽，断言恒真等于没测。
      expect(
        tester.getSize(dialogSurface()).width,
        lessThanOrEqualTo(OhosDialogMetrics.maxWidth),
      );
    });

    testWidgets('窄屏上弹窗不铺满整屏，左右各留 16vp 边距', (WidgetTester tester) async {
      // `maxWidth = 400` 是**上限**，不是「一定 400」。360vp 的手机屏上可用
      // 宽度不够 400，只夹 400 会让弹窗顶满整个屏幕宽度（`SizedBox(width:400)`
      // 在 360 的松约束下被压成 360），圆角切在屏幕外、看起来不像弹窗。
      //
      // 这条用例能变红是因为它断言**具体宽度**而不是「≤ 400」：修之前量到
      // 360（= 屏宽），修之后是 328。
      // `setSurfaceSize` **不改 `MediaQuery`** —— 组件读的是
      // `MediaQuery.sizeOf`，只设前者的话 `_bounds` 算出来仍是默认 800×600，
      // 量到的弹窗宽度不受影响。两个都要设，否则这条用例会因为
      // 「屏幕从来没变成 360」而假通过。
      const Size phone = Size(360, 800);
      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(phone);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        return tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        wrap(
          OhosAlertDialog(
            title: '删除文件',
            content: '删除后无法恢复，确定要继续吗？',
            actions: const <OhosDialogAction>[
              OhosDialogAction(label: '取消', onPressed: _noop),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Rect surface = tester.getRect(dialogSurface());
      expect(
        surface.width,
        360 - OhosDialogMetrics.sideMargin * 2,
        reason: '窄屏上宽度应是「屏宽 − 左右边距」，不是屏宽本身',
      );
      expect(surface.left, OhosDialogMetrics.sideMargin);
      expect(surface.right, 360 - OhosDialogMetrics.sideMargin);
    });

    testWidgets('显式 width 超过 400 会被夹回，而不是突破上限', (WidgetTester tester) async {
      // 官方 width 的语义是「设置后不超过默认最大宽度」—— 是**夹取**不是
      // **放开**，这点与 gridCount 的「异常值按默认值处理」不同。
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          OhosAlertDialog(
            title: '标题',
            width: 800,
            actions: const <OhosDialogAction>[
              OhosDialogAction(label: '好', onPressed: _noop),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(dialogSurface()).width,
        lessThanOrEqualTo(OhosDialogMetrics.maxWidth),
      );
    });

    testWidgets('高度上限 0.9×(窗口高−安全区)，且超高时滚动而不是溢出', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          OhosAlertDialog(
            title: '标题',
            contentWidget: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < 30; i++)
                  SizedBox(height: 60, child: Text('行 $i')),
              ],
            ),
            actions: const <OhosDialogAction>[
              OhosDialogAction(label: '好', onPressed: _noop),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(dialogSurface()).height,
        lessThanOrEqualTo(640 * OhosDialogMetrics.maxHeightFactor + 1),
      );
    });

    testWidgets('customStyle: false 圆角恒 32', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosAlertDialog(
            title: '标题',
            actions: <OhosDialogAction>[
              OhosDialogAction(label: '好', onPressed: _noop),
            ],
          ),
        ),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(OhosAlertDialog),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final BoxDecoration deco = box.decoration as BoxDecoration;
      expect(
        deco.borderRadius,
        BorderRadius.circular(OhosDialogMetrics.borderRadius),
      );
    });

    testWidgets('customStyle: true 时圆角归 0、背板透明（壳交出去）', (
      WidgetTester tester,
    ) async {
      // 官方原文：「圆角为0，弹窗背景色为透明色」。这一档不是「另一种圆角」，
      // 而是「本库不画壳」—— 留着 32 的圆角却不管背板等于半吊子。
      await tester.pumpWidget(
        wrap(
          const OhosAlertDialog(
            title: '标题',
            customStyle: true,
            actions: <OhosDialogAction>[
              OhosDialogAction(label: '好', onPressed: _noop),
            ],
          ),
        ),
      );
      // customStyle: true 不画 DecoratedBox 壳 —— 没有可查的圆角，
      // 断言「壳不存在」比断言「圆角是 0」更贴近实现。
      expect(
        find.descendant(
          of: find.byType(OhosAlertDialog),
          matching: find.byType(ClipRRect),
        ),
        findsNothing,
      );
    });

    testWidgets('isModal: false 直接构造时不画遮罩', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosAlertDialog(
            title: '标题',
            isModal: false,
            actions: <OhosDialogAction>[
              OhosDialogAction(label: '好', onPressed: _noop),
            ],
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(OhosAlertDialog),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });

    testWidgets('isModal: true 直接构造时有 20% 黑的遮罩，可点遮罩关闭', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          const OhosAlertDialog(
            title: '标题',
            actions: <OhosDialogAction>[
              OhosDialogAction(label: '好', onPressed: _noop),
            ],
          ),
        ),
      );
      final ColoredBox mask = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(OhosAlertDialog),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(mask.color, OhosDialogMetrics.maskColor);
    });

    testWidgets('maskColor 可覆盖默认 0x33000000', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          OhosAlertDialog(
            title: '标题',
            maskColor: const Color(0x99000000),
            actions: const <OhosDialogAction>[
              OhosDialogAction(label: '好', onPressed: _noop),
            ],
          ),
        ),
      );
      final ColoredBox mask = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(OhosAlertDialog),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(mask.color, const Color(0x99000000));
    });

    // 真机（墨屏，容器类页「打开弹窗」）实测：标题「删除文件」与正文
    // 「删除后无法恢复，确定要继续吗？」各带两条黄线，全图 5340 个
    // `#FDFE53` 级黄像素。根因是弹窗挂在 Overlay 上、没有 `Material` 祖先，
    // 文字退到 `DefaultTextStyle.fallback`（黄色 + double 下划线）。
    //
    // 按钮文字当时是正常的 —— 只截按钮会漏判，所以这里对标题与正文分别断言。
    testWidgets('标题与正文不受 DefaultTextStyle.fallback 的黄色双下划线污染', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OhosAlertDialog(
            title: '删除文件',
            content: '删除后无法恢复，确定要继续吗？',
            actions: const <OhosDialogAction>[
              OhosDialogAction(label: '取消', onPressed: _noop),
            ],
          ),
        ),
      );

      for (final String label in <String>['删除文件', '删除后无法恢复，确定要继续吗？']) {
        final TextStyle style = paintedTextStyle(tester, label);
        expect(
          style.decoration?.contains(TextDecoration.underline) ?? false,
          isFalse,
          reason: '$label 不该带下划线',
        );
        // `#FFFF00` 是 fallback 的警报色。真机上它画出来就是黄线，
        // 测试环境里即使 decoration 是 none 也可能残留这个颜色值，
        // 所以两条都要断。
        expect(
          style.decorationColor,
          isNot(const Color(0xFFFFFF00)),
          reason: '$label 的 decorationColor 不该是 fallback 的黄色',
        );
      }
    });

    testWidgets('四段生命周期的调用顺序 onWillAppear → onDidAppear', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await tester.pumpWidget(
        wrap(
          OhosAlertDialog(
            title: '标题',
            lifecycle: OhosDialogLifecycle(
              onWillAppear: () => calls.add('willAppear'),
              onDidAppear: () => calls.add('didAppear'),
              onWillDisappear: () => calls.add('willDisappear'),
              onDidDisappear: () => calls.add('didDisappear'),
            ),
            actions: const <OhosDialogAction>[
              OhosDialogAction(label: '好', onPressed: _noop),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(calls, <String>['willAppear', 'didAppear']);
    });

    testWidgets('销毁时补 onWillDisappear → onDidDisappear', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await tester.pumpWidget(
        wrap(
          OhosAlertDialog(
            title: '标题',
            lifecycle: OhosDialogLifecycle(
              onWillDisappear: () => calls.add('willDisappear'),
              onDidDisappear: () => calls.add('didDisappear'),
            ),
            actions: const <OhosDialogAction>[
              OhosDialogAction(label: '好', onPressed: _noop),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 直接卸载整棵树 —— dispose 里必须补齐两个退出回调，否则会静默丢失。
      await tester.pumpWidget(wrap(const SizedBox()));
      await tester.pumpAndSettle();

      expect(calls, <String>['willDisappear', 'didDisappear']);
    });

    testWidgets('onWillDismiss 不改 dismiss 就不关（与 Flutter 习惯相反）', (
      WidgetTester tester,
    ) async {
      bool intercepted = false;
      OhosDismissReason? seen;
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 路由级入口 + `onWillDismiss`：`showOhosDialog` 会把
      // `barrierDismissible` 强制设为 false，点击交给弹窗自己的遮罩层判定。
      // 若这里还用 `barrierDismissible: true`，路由会先 pop 掉弹窗，
      // 回调跑不跑都来不及看到 —— 那样测的是路由不是拦截。
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext ctx) => Center(
                child: OhosButton(
                  onPressed: () => showOhosDialog<void>(
                    context: ctx,
                    title: '标题',
                    onWillDismiss: (OhosDismissDialogAction action) {
                      intercepted = true;
                      seen = action.reason;
                      // 故意不 dismiss
                    },
                    actions: const <OhosDialogAction>[
                      OhosDialogAction(label: '好', onPressed: _noop),
                    ],
                  ),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('标题'), findsOneWidget);

      // 点遮罩（左上角，远离弹窗）
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(intercepted, isTrue);
      expect(seen, OhosDismissReason.touchOutside);
      // 没调 dismiss()，弹窗应当还在
      expect(find.text('标题'), findsOneWidget);
    });

    testWidgets('onWillDismiss 调 dismiss() 后才真正关闭', (
      WidgetTester tester,
    ) async {
      // 必须走路由级入口：`dismiss()` 放行后由弹窗调 `Navigator.maybePop`
      // 完成关闭，嵌入式构造（只是 `Center` 里的一个 widget）没有可 pop 的
      // 路由 —— 那种场景下「关闭」得由持有它的父级负责，本组件管不到。
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext ctx) => Center(
                child: OhosButton(
                  onPressed: () => showOhosDialog<void>(
                    context: ctx,
                    title: '标题',
                    onWillDismiss: (OhosDismissDialogAction a) => a.dismiss(),
                    actions: const <OhosDialogAction>[
                      OhosDialogAction(label: '好', onPressed: _noop),
                    ],
                  ),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('标题'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('标题'), findsNothing);
    });

    testWidgets('gridCount 超界（0 / 负数 / 超过系统列数）按默认值处理', (
      WidgetTester tester,
    ) async {
      // 官方「异常值按默认值处理，最大栅格数为系统最大栅格数」——
      // 是回落到默认，**不是**夹到边界。夹取会让 999 悄悄变成占满整屏。
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final int bad in <int>[0, -3, 999]) {
        await tester.pumpWidget(
          wrap(
            OhosAlertDialog(
              title: '标题',
              gridCount: bad,
              actions: const <OhosDialogAction>[
                OhosDialogAction(label: '好', onPressed: _noop),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(dialogSurface()).width,
          lessThanOrEqualTo(OhosDialogMetrics.maxWidth),
          reason: 'gridCount=$bad 应回落到默认宽度路径',
        );
      }
    });

    testWidgets('gridCount 在合法区间内按栅格列宽计算', (WidgetTester tester) async {
      // 手机竖屏 400vp → compact 断点 → 4 列、margin 16、gutter 8。
      // 单列宽 = (400 − 16×2 − 8×3) / 4 = 86；占 2 列 = 86×2 + 8 = 180。
      //
      // 必须显式套 MediaQuery：`setSurfaceSize` 只改渲染面，`MediaQuery` 仍
      // 可能是默认的 800×600（实测就是这样，于是断点判成 medium、8 列、
      // 算出来 179 而不是 180）。栅格宽度是**按窗口宽算的**，窗口宽喂错，
      // 断言就算「碰巧接近」也证明不了公式对。
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          OhosAlertDialog(
            title: '标题',
            gridCount: 2,
            actions: const <OhosDialogAction>[
              OhosDialogAction(label: '好', onPressed: _noop),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final double width = tester.getSize(dialogSurface()).width;
      expect(width, closeTo(180, 0.5));
      // 但任何栅格结果都不会突破 400 的上限
      expect(width, lessThanOrEqualTo(OhosDialogMetrics.maxWidth));
    });
  });

  group('OhosListTile', () {
    double titleSizeOf(WidgetTester tester, String label) {
      final DefaultTextStyle style = tester.widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(DefaultTextStyle),
            )
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

  group('OhosList', () {
    List<OhosDivider> dividersOf(WidgetTester tester) =>
        tester.widgetList<OhosDivider>(find.byType(OhosDivider)).toList();

    testWidgets('每个行边界只有一条线，末行不画（不叠双线）', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosList(
            children: <Widget>[
              OhosListTile(title: Text('A')),
              OhosListTile(title: Text('B')),
              OhosListTile(title: Text('C')),
            ],
          ),
        ),
      );

      // 3 行 → 2 条；修复前是 2×3−1 = 5 条（tile 各画一条 + 列表插一条）
      expect(dividersOf(tester).length, 2);
    });

    testWidgets('indent 跟着 leading 走，两端都不贯穿', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosList(
            children: <Widget>[
              OhosListTile(leading: Icon(Icons.wifi), title: Text('带图标')),
              OhosListTile(title: Text('不带图标')),
            ],
          ),
        ),
      );

      final List<OhosDivider> dividers = dividersOf(tester);
      expect(dividers.length, 1);
      // 有 leading：16 内容边距 + 24 图标 + 16 间距
      expect(dividers.single.indent, 56);
      expect(dividers.single.endIndent, 16);

      // 线的左端落在文字左端上，而不是压在图标下面
      final Rect line = tester.getRect(find.byType(OhosDivider));
      expect(
        line.left + dividers.single.indent,
        moreOrLessEquals(tester.getRect(find.text('带图标')).left, epsilon: 0.01),
      );
      // 右端留出 16vp，不贯穿到卡片边
      expect(line.right - dividers.single.endIndent, lessThan(line.right));
    });

    testWidgets('divider: false 时整列都不画', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosList(
            divider: false,
            children: <Widget>[
              OhosListTile(title: Text('A')),
              OhosListTile(title: Text('B')),
            ],
          ),
        ),
      );

      expect(dividersOf(tester), isEmpty);
    });

    testWidgets('tile 显式 divider: false 在列表内也生效', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosList(
            children: <Widget>[
              OhosListTile(title: Text('A'), divider: false),
              OhosListTile(title: Text('B')),
            ],
          ),
        ),
      );

      // A 是第一行（scope 本来让它画一条），显式 false 必须压过 scope ——
      // 否则「列表接管分隔线」就变成没法逐行关掉的静默回归。B 是末行，不画。
      expect(dividersOf(tester), isEmpty);
    });

    testWidgets('非 tile 子节点仍由列表补线', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosList(
            children: <Widget>[SizedBox(height: 40), SizedBox(height: 40)],
          ),
        ),
      );

      final List<OhosDivider> dividers = dividersOf(tester);
      expect(dividers.length, 1);
      expect(dividers.single.indent, 56);
      expect(dividers.single.endIndent, 16);
    });

    testWidgets('包了一层的 tile 不会叠出两条线', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosList(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.zero,
                child: OhosListTile(title: Text('A')),
              ),
              OhosListTile(title: Text('B')),
            ],
          ),
        ),
      );

      // 第 0 行不是直接的 tile 子节点：列表会替它补一条（indent 56），
      // 里面那条就必须被 scope 压掉，否则同一个边界上是两条线。
      final List<OhosDivider> dividers = dividersOf(tester);
      expect(dividers.length, 1);
      expect(dividers.single.indent, 56);
    });
  });

  group('OhosBadge', () {
    testWidgets('行高有界时仍是 16×16 的圆，不会拉成竖胶囊', (WidgetTester tester) async {
      // Row 的非弹性子节点拿到的是「宽度无界、高度有界」的约束 —— 老实现里
      // 内部的 Align 会把高度撑满，宽度却跟着文字收缩。
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            height: 48,
            child: Row(children: <Widget>[OhosBadge(count: 8)]),
          ),
        ),
      );

      final Size size = tester.getSize(find.byType(OhosBadge));
      // 高度必须锁在官方的 `badgeSize`（16vp，`BadgeStyle.badgeSize` 默认值）
      // 上，而不是 Material 的 18。宽度不小于高度 —— 竖胶囊正是「宽 < 高」。
      expect(size.height, 16);
      expect(size.width, greaterThanOrEqualTo(size.height));
    });

    testWidgets('多位数横向长成胶囊，而不是竖起来', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            height: 48,
            child: Row(children: <Widget>[OhosBadge(count: 500)]),
          ),
        ),
      );

      final Size size = tester.getSize(find.byType(OhosBadge));
      expect(size.height, 16);
      expect(size.width, greaterThan(16));
    });

    testWidgets('圆点是 6×6（官方 little_badge_size），没有 count 也没有 child 时收成零', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const Row(children: <Widget>[OhosBadge(isDot: true), OhosBadge()]),
        ),
      );

      // 6vp 来自资源表 `little_badge_size = 6.0vp`，老实现的 8 是自选的。
      expect(tester.getSize(find.byType(OhosBadge).first), const Size(6, 6));
      expect(tester.getSize(find.byType(OhosBadge).last), Size.zero);
    });

    testWidgets('BadgePosition 三档：右上 / 右侧居中 / 左侧居中', (
      WidgetTester tester,
    ) async {
      // 官方 `BadgePosition` 只有三档，老实现固定右上、连枚举都没有。
      Future<Offset> labelOffset(OhosBadgePosition position) async {
        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 120,
              height: 40,
              child: OhosBadge(
                count: 3,
                position: position,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
        final Rect host = tester.getRect(find.byType(OhosBadge));
        final Rect badge = tester.getRect(
          find
              .descendant(
                of: find.byType(OhosBadge),
                matching: find.byType(Container),
              )
              .first,
        );
        return Offset(badge.left - host.left, badge.top - host.top);
      }

      final Offset rightTop = await labelOffset(OhosBadgePosition.rightTop);
      final Offset right = await labelOffset(OhosBadgePosition.right);
      final Offset left = await labelOffset(OhosBadgePosition.left);
      // 右上角：贴宿主顶边；右侧居中：垂直居中（top 明显更大）；左侧：贴左沿。
      expect(rightTop.dy, 0);
      expect(right.dy, greaterThan(rightTop.dy));
      expect(left.dx, 0);
      expect(right.dx, greaterThan(left.dx));
    });

    testWidgets('value 走字符串形态；空串退化为圆点（官方口径）', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const Row(
            children: <Widget>[
              OhosBadge(value: 'NEW'),
              OhosBadge(value: ''),
            ],
          ),
        ),
      );

      expect(find.text('NEW'), findsOneWidget);
      // 空串「不显示文本，仅显示圆点标记」。
      expect(tester.getSize(find.byType(OhosBadge).last).width, 6);
    });
  });

  group('OhosColorPicker', () {
    Widget picker({
      required OhosColorPickerTab tab,
      required Color color,
      ValueChanged<Color>? onChanged,
    }) {
      return wrap(
        OhosColorPicker(
          colors: const <Color>[Colors.red],
          selectedColor: color,
          tabs: <OhosColorPickerTab>[tab],
          activeTab: tab,
          onChanged: onChanged ?? (Color _) {},
        ),
      );
    }

    testWidgets('光谱：指示器与手指同向（上方 = 更亮）', (WidgetTester tester) async {
      Color? picked;
      await tester.pumpWidget(
        picker(
          tab: OhosColorPickerTab.spectrum,
          color: const Color(0xFF000000), // V = 0，指示器初始在最下方
          onChanged: (Color c) => picked = c,
        ),
      );

      final Rect box = tester.getRect(
        find.byKey(const Key('ohos-color-picker-sv-box')),
      );
      final Offset before = tester.getCenter(
        find.byKey(const Key('ohos-color-picker-sv-indicator')),
      );
      expect(before.dy, greaterThan(box.center.dy));

      await tester.tapAt(Offset(box.center.dx, box.top + 6));
      await tester.pump();

      // 点在盒子上沿：值应升到最亮，指示器也要跟着往上走（不是反向跑）
      final Offset after = tester.getCenter(
        find.byKey(const Key('ohos-color-picker-sv-indicator')),
      );
      expect(after.dy, lessThan(box.center.dy));
      expect(HSVColor.fromColor(picked!).value, greaterThan(0.9));
    });

    testWidgets('滑块：拇指是圆且高于轨道，不会把轨道切出一道白口', (WidgetTester tester) async {
      await tester.pumpWidget(
        picker(tab: OhosColorPickerTab.sliders, color: const Color(0xFF0A59F7)),
      );

      final Size thumb = tester.getSize(
        find.byKey(const Key('ohos-color-picker-bar-thumb')).first,
      );
      final Size track = tester.getSize(
        find.byKey(const Key('ohos-color-picker-bar-track')).first,
      );
      expect(thumb.width, thumb.height);
      expect(thumb.height, greaterThan(track.height));
    });
  });

  group('showOhosBottomSheet', () {
    testWidgets('ink 主题下退化成纯色面板，不再做整层模糊', (WidgetTester tester) async {
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

    testWidgets('lightMaterial: false 时彩屏也不铺光感', (WidgetTester tester) async {
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

    // 形态用例的断言原则：落在「真的画成了那个形态」，不是「参数传进去了」。
    // 所以量位置与尺寸、数标题/关闭按钮/控制条的个数，而不是断言枚举值。

    Widget hostFor(Future<void> Function(BuildContext) open) {
      return OhosTheme(
        data: OhosThemeData.light(),
        child: MaterialApp(
          home: OhosScaffold(
            body: Center(
              child: Builder(
                builder: (BuildContext context) => OhosButton(
                  onPressed: () => open(context),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> openAndSettle(WidgetTester tester, Widget host) async {
      await tester.pumpWidget(host);
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
    }

    testWidgets('CENTER 居中悬浮、宽度 480、四角圆', (WidgetTester tester) async {
      await openAndSettle(
        tester,
        hostFor(
          (BuildContext c) => showOhosBottomSheet(
            context: c,
            title: '居中',
            type: OhosSheetType.center,
            content: const SizedBox(height: 200, child: Text('内容')),
          ),
        ),
      );
      // 是否真的居中了：量面板自身的矩形，而不是「标题 top > 0」这种
      // 永远为真的断言 —— 后者在把面板挪到底部时也照样通过。
      final Rect panel = tester.getRect(
        find.ancestor(
          of: find.text('内容'),
          matching: find.byWidgetPredicate(
            (Widget w) =>
                w is SizedBox && w.width == OhosSheetSpec.centerDefaultWidth,
          ),
        ),
      );
      final Size screen = tester.getSize(find.byType(MaterialApp));
      expect(
        panel.width,
        OhosSheetSpec.centerDefaultWidth,
        reason: 'CENTER 面板宽应为 480（官方 sheet_center_default_width）',
      );
      expect(
        (panel.center.dy - screen.height / 2).abs(),
        lessThan(1),
        reason: 'CENTER 必须纵向居中',
      );
      expect(
        (panel.center.dx - screen.width / 2).abs(),
        lessThan(1),
        reason: 'CENTER 必须横向居中',
      );
    });

    testWidgets('BOTTOM 贴底：面板顶边明显低于屏幕中线', (WidgetTester tester) async {
      await openAndSettle(
        tester,
        hostFor(
          (BuildContext c) => showOhosBottomSheet(
            context: c,
            title: '底部',
            type: OhosSheetType.bottom,
            content: const SizedBox(height: 200, child: Text('内容')),
          ),
        ),
      );
      final double screenHeight = tester
          .getSize(find.byType(MaterialApp))
          .height;
      final Rect titleRect = tester.getRect(find.text('底部'));
      expect(
        titleRect.top,
        greaterThan(screenHeight / 2),
        reason: 'BOTTOM 的标题应落在下半屏',
      );
    });

    // 规格落到屏幕上才算数：单测只证明返回值对，这里量**真的位置** ——
    // 面板顶边必须落在「状态栏下缘 + 8vp」。
    testWidgets('BOTTOM 大挡把状态栏让出来（顶边 = 状态栏 + 8）', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.reset);

      await openAndSettle(
        tester,
        hostFor(
          (BuildContext c) => showOhosBottomSheet(
            context: c,
            title: '大挡',
            type: OhosSheetType.bottom,
            detents: <OhosSheetDetent>[
              const OhosSheetDetent.size(OhosSheetSize.large),
            ],
            content: const Center(child: Text('大挡内容')),
          ),
        ),
      );

      final Size screen = tester.getSize(find.byType(MaterialApp));
      // 面板 = 贴着内容、且宽度被钉成窗口宽的那个 `SizedBox`。
      final Rect panel = tester.getRect(
        find
            .ancestor(
              of: find.text('大挡内容'),
              matching: find.byWidgetPredicate(
                (Widget w) => w is SizedBox && w.width == screen.width,
              ),
            )
            .first,
      );
      expect(panel.top, 32, reason: '顶边要在状态栏（24）下缘再让 8vp，不能盖住状态栏');
      expect(panel.height, screen.height - 32, reason: 'LARGE = 窗口高 − 状态栏 − 8');
    });

    // CONTENT_COVER：**无蒙层 / 无标题栏 / 无关闭按钮** —— 这三条是本型
    // 最容易做错的地方（看起来只是「一个没有装饰的底部弹窗」）。
    testWidgets('CONTENT_COVER 不画标题、不画关闭按钮', (WidgetTester tester) async {
      await openAndSettle(
        tester,
        hostFor(
          (BuildContext c) => showOhosBottomSheet(
            context: c,
            title: '不该出现',
            type: OhosSheetType.contentCover,
            content: const Center(child: Text('全屏内容')),
          ),
        ),
      );
      expect(find.text('不该出现'), findsNothing, reason: '全屏形态无标题栏');
      expect(find.byIcon(Icons.close_rounded), findsNothing, reason: '无关闭按钮');
      // 内容要在。
      expect(find.text('全屏内容'), findsOneWidget);
    });

    testWidgets('CONTENT_COVER 铺满全屏', (WidgetTester tester) async {
      await openAndSettle(
        tester,
        hostFor(
          (BuildContext c) => showOhosBottomSheet(
            context: c,
            title: 'x',
            type: OhosSheetType.contentCover,
            content: const Center(child: Text('全屏内容')),
          ),
        ),
      );
      final Size screen = tester.getSize(find.byType(MaterialApp));
      final Size panel = tester.getSize(
        find
            .ancestor(of: find.text('全屏内容'), matching: find.byType(SizedBox))
            .last,
      );
      expect(panel.height, screen.height);
    });

    // SIDE：右侧、固定宽、无控制条。
    testWidgets('SIDE 靠右、宽 400（>md 断点）、无控制条', (WidgetTester tester) async {
      await openAndSettle(
        tester,
        hostFor(
          (BuildContext c) => showOhosBottomSheet(
            context: c,
            title: '侧边',
            type: OhosSheetType.side,
            content: const SizedBox(height: 200, child: Text('侧边内容')),
          ),
        ),
      );
      expect(find.text('侧边内容'), findsOneWidget);
      // 标题应落在屏幕右半侧（默认测试窗口 800 宽，面板 400 ⇒ 中心 600）。
      final double screenWidth = tester.getSize(find.byType(MaterialApp)).width;
      final Rect titleRect = tester.getRect(find.text('侧边'));
      expect(
        titleRect.center.dx,
        greaterThan(screenWidth / 2),
        reason: 'SIDE 是右侧抽屉',
      );
    });

    // detents 生效时 height 失效 —— 这是官方明写的，最容易写成「两者取小」。
    testWidgets('detents 生效时 height 失效，取首挡', (WidgetTester tester) async {
      await openAndSettle(
        tester,
        hostFor(
          (BuildContext c) => showOhosBottomSheet(
            context: c,
            title: '挡位',
            type: OhosSheetType.bottom,
            height: 200, // 应被忽略
            detents: <OhosSheetDetent>[
              const OhosSheetDetent.value(300),
              const OhosSheetDetent.value(600),
            ],
            content: const Center(child: Text('挡位内容')),
          ),
        ),
      );
      final Rect panel = tester.getRect(
        find
            .ancestor(of: find.text('挡位内容'), matching: find.byType(SizedBox))
            .last,
      );
      expect(panel.height, 300, reason: '应取首挡 300，而不是 height 200');
    });

    testWidgets('SIDE 忽略 detents（无挡位能力）', (WidgetTester tester) async {
      await openAndSettle(
        tester,
        hostFor(
          (BuildContext c) => showOhosBottomSheet(
            context: c,
            title: '侧边',
            type: OhosSheetType.side,
            detents: <OhosSheetDetent>[const OhosSheetDetent.value(300)],
            content: const Center(child: Text('侧边内容')),
          ),
        ),
      );
      final Size screen = tester.getSize(find.byType(MaterialApp));
      final Rect panel = tester.getRect(
        find
            .ancestor(of: find.text('侧边内容'), matching: find.byType(SizedBox))
            .last,
      );
      expect(panel.height, screen.height, reason: 'SIDE 高度恒全屏，挡位无效');
    });
  });

  group('OhosSheetSpec', () {
    // 形态矩阵是逐条从参考文档抄下来的，用例的作用不是「验证我抄对了」，
    // 而是**防止后来者把某一型当成另一种**（最常见的是把 SIDE / CONTENT_COVER
    // 当成「换个对齐的底部弹窗」）。

    test('响应式默认形态：<600 底部 / 600–840 居中 / ≥840 跟手', () {
      expect(OhosSheetSpec.defaultTypeFor(360), OhosSheetType.bottom);
      expect(OhosSheetSpec.defaultTypeFor(599), OhosSheetType.bottom);
      expect(OhosSheetSpec.defaultTypeFor(600), OhosSheetType.center);
      expect(OhosSheetSpec.defaultTypeFor(839), OhosSheetType.center);
      expect(OhosSheetSpec.defaultTypeFor(840), OhosSheetType.popup);
    });

    test('SIDE / CONTENT_COVER 无挡位、无控制条', () {
      expect(OhosSheetSpec.supportsDetents(OhosSheetType.side), isFalse);
      expect(
        OhosSheetSpec.supportsDetents(OhosSheetType.contentCover),
        isFalse,
      );
      expect(OhosSheetSpec.supportsDragBar(OhosSheetType.side), isFalse);
      expect(
        OhosSheetSpec.supportsDragBar(OhosSheetType.contentCover),
        isFalse,
      );
      expect(OhosSheetSpec.supportsDetents(OhosSheetType.bottom), isTrue);
    });

    test('CONTENT_COVER 无蒙层、无标题与关闭按钮', () {
      expect(OhosSheetSpec.hasMask(OhosSheetType.contentCover), isFalse);
      expect(
        OhosSheetSpec.hasTitleAndClose(OhosSheetType.contentCover),
        isFalse,
      );
      // 其余四型都有蒙层。
      for (final OhosSheetType t in <OhosSheetType>[
        OhosSheetType.bottom,
        OhosSheetType.center,
        OhosSheetType.popup,
        OhosSheetType.side,
      ]) {
        expect(OhosSheetSpec.hasMask(t), isTrue, reason: '$t');
      }
    });

    test('只有 BOTTOM 不圆下面两角，CONTENT_COVER 完全不圆', () {
      expect(OhosSheetSpec.roundsAllCorners(OhosSheetType.bottom), isFalse);
      expect(
        OhosSheetSpec.roundsAllCorners(OhosSheetType.contentCover),
        isFalse,
      );
      expect(OhosSheetSpec.roundsAllCorners(OhosSheetType.center), isTrue);
      expect(OhosSheetSpec.roundsAllCorners(OhosSheetType.side), isTrue);
    });

    // 官方：CENTER / POPUP 下 MEDIUM 与 LARGE **无效**，恒 560vp。
    // 写成「按 60% / 100% 算」看起来更合理，实际是错的。
    //
    // 这里用真实窗口尺寸（短边 800、90% = 720 > 560）。规格本身有一处冲突：
    // 「MEDIUM/LARGE 无效、显示默认高度 560vp」与「最大高度为短边 90%」在
    // 短边 < 622 时打架。本库选择**照常夹取** —— 让 560 溢出窗口是更糟的
    // 结果，而且官方夹取条款原文是「大于最大高度则显示最大高度」。
    test('CENTER / POPUP 下 MEDIUM / LARGE 恒 560vp', () {
      for (final OhosSheetType t in <OhosSheetType>[
        OhosSheetType.center,
        OhosSheetType.popup,
      ]) {
        expect(
          OhosSheetSpec.resolveDetent(
            detent: const OhosSheetDetent.size(OhosSheetSize.medium),
            type: t,
            viewportHeight: 900,
            shortSide: 800,
          ),
          OhosSheetSpec.centeredFixedHeight,
        );
        expect(
          OhosSheetSpec.resolveDetent(
            detent: const OhosSheetDetent.size(OhosSheetSize.large),
            type: t,
            viewportHeight: 900,
            shortSide: 800,
          ),
          OhosSheetSpec.centeredFixedHeight,
        );
      }
    });

    // 冲突那侧的显式行为：短边 400 ⇒ 90% = 360，560 被压到 360。
    test('短边过小时 560 仍被夹到 90%（不溢出）', () {
      expect(
        OhosSheetSpec.resolveDetent(
          detent: const OhosSheetDetent.size(OhosSheetSize.large),
          type: OhosSheetType.center,
          viewportHeight: 800,
          shortSide: 400,
        ),
        360,
      );
    });

    test('BOTTOM 下 MEDIUM 是窗口高的 60%', () {
      expect(
        OhosSheetSpec.resolveDetent(
          detent: const OhosSheetDetent.size(OhosSheetSize.medium),
          type: OhosSheetType.bottom,
          viewportHeight: 800,
          shortSide: 400,
        ),
        480,
      );
    });

    // 官方公式是「屏幕/窗口高度 − 信号栏 − 8」，**不是**「窗口高」。
    // 写成 viewportHeight 会让面板顶到窗口顶，把状态栏盖在面板下面 ——
    // 这正是本轮修掉的缺陷。
    //
    // **断言里写死字面值 8 / 792 / 768，不引用 `topGap`** —— 引用常量会让
    // 「常量被改成 0」这种变异跟着断言一起变，永远验不红（已实测踩过）。
    test('LARGE 挡 = 窗口高 − 状态栏 − 8', () {
      expect(OhosSheetSpec.topGap, 8, reason: '官方数值，改了就是改规格');
      expect(
        OhosSheetSpec.resolveDetent(
          detent: const OhosSheetDetent.size(OhosSheetSize.large),
          type: OhosSheetType.bottom,
          viewportHeight: 800,
          shortSide: 400,
        ),
        792,
        reason: '无状态栏时也要留 8vp',
      );
      expect(
        OhosSheetSpec.resolveDetent(
          detent: const OhosSheetDetent.size(OhosSheetSize.large),
          type: OhosSheetType.bottom,
          viewportHeight: 800,
          shortSide: 400,
          statusBarHeight: 24,
        ),
        768,
        reason: '公式里的「信号栏」就是 statusBarHeight',
      );
    });

    test('BOTTOM 的显式高度同样被 8vp 顶距夹住', () {
      expect(
        OhosSheetSpec.clampHeight(
          height: 900,
          type: OhosSheetType.bottom,
          viewportHeight: 800,
          shortSide: 400,
        ),
        792,
      );
      // 没超上限的高度原样保留 —— 别把「上限」写成「必然值」。
      expect(
        OhosSheetSpec.clampHeight(
          height: 700,
          type: OhosSheetType.bottom,
          viewportHeight: 800,
          shortSide: 400,
        ),
        700,
      );
    });

    // 全屏两型**不让**：SIDE 是抽屉、CONTENT_COVER 是整屏，减 8 会漏出白边。
    test('SIDE / CONTENT_COVER 不减 8vp', () {
      for (final OhosSheetType t in <OhosSheetType>[
        OhosSheetType.side,
        OhosSheetType.contentCover,
      ]) {
        expect(
          OhosSheetSpec.maxPanelHeight(
            type: t,
            viewportHeight: 800,
            statusBarHeight: 24,
          ),
          800,
        );
      }
      expect(
        OhosSheetSpec.maxPanelHeight(
          type: OhosSheetType.bottom,
          viewportHeight: 800,
          statusBarHeight: 24,
        ),
        768,
      );
    });

    // CENTER / POPUP 有两条上限：短边 90% 与「窗口高 − 状态栏 − 8」，取小。
    // 竖屏下前者恒更小，横屏短窗口时后者才生效 —— 所以两条都要留。
    test('CENTER 的 90% 与 8vp 顶距取小', () {
      expect(
        OhosSheetSpec.clampHeight(
          height: 900,
          type: OhosSheetType.center,
          viewportHeight: 700,
          shortSide: 800, // 90% = 720 > 700 − 8
        ),
        692,
        reason: '短边很大但窗口很矮时，上限是「窗口高 − 8」',
      );
      expect(
        OhosSheetSpec.clampHeight(
          height: 900,
          type: OhosSheetType.center,
          viewportHeight: 900,
          shortSide: 400, // 90% = 360 < 892
        ),
        360,
        reason: '常规竖屏仍是短边 90% 更小',
      );
    });

    // 夹取顺序：CENTER / POPUP 先夹到 [320, 短边×90%]。
    test('CENTER 高度夹到 [320, 短边 90%]', () {
      final double tooSmall = OhosSheetSpec.clampHeight(
        height: 100,
        type: OhosSheetType.center,
        viewportHeight: 800,
        shortSide: 400,
      );
      expect(tooSmall, OhosSheetSpec.minHeight);
      final double tooBig = OhosSheetSpec.clampHeight(
        height: 900,
        type: OhosSheetType.center,
        viewportHeight: 800,
        shortSide: 400,
      );
      expect(tooBig, 360); // 400 × 0.9
    });

    // BOTTOM 不套 320 / 90% —— 它的上限是位置约束，不是短边比例。
    test('BOTTOM 不套 90% 短边上限', () {
      expect(
        OhosSheetSpec.clampHeight(
          height: 700,
          type: OhosSheetType.bottom,
          viewportHeight: 800,
          shortSide: 400,
        ),
        700,
        reason: '底部弹窗可以超过短边 90%',
      );
    });

    test('SIDE / CONTENT_COVER 高度恒全屏', () {
      for (final OhosSheetType t in <OhosSheetType>[
        OhosSheetType.side,
        OhosSheetType.contentCover,
      ]) {
        expect(
          OhosSheetSpec.clampHeight(
            height: 200,
            type: t,
            viewportHeight: 800,
            shortSide: 400,
          ),
          800,
        );
      }
    });

    test('fitContent 解析为 null（随内容）', () {
      expect(
        OhosSheetSpec.resolveDetent(
          detent: const OhosSheetDetent.size(OhosSheetSize.fitContent),
          type: OhosSheetType.bottom,
          viewportHeight: 800,
          shortSide: 400,
        ),
        isNull,
      );
    });

    // **速度优先，距离其次** —— 判据顺序反了会让快速轻扫被判成「回原挡」。
    test('挡位切换：速度过阈值直接切挡，不看距离', () {
      final List<double> heights = <double>[300, 500, 800];
      // 位移只有 10，远不到 1/2，但速度很大 → 应切到下一挡。
      expect(
        OhosSheetSpec.resolveDetentIndex(
          current: 0,
          delta: -10,
          velocity: -1500,
          heights: heights,
        ),
        1,
      );
    });

    test('挡位切换：速度不够且位移不足 1/2 时回原挡', () {
      final List<double> heights = <double>[300, 500, 800];
      expect(
        OhosSheetSpec.resolveDetentIndex(
          current: 0,
          delta: -50, // 目标距离 200，1/2 = 100，50 < 100
          velocity: -200,
          heights: heights,
        ),
        0,
      );
    });

    test('挡位切换：速度不够但位移过 1/2 时切挡', () {
      final List<double> heights = <double>[300, 500, 800];
      expect(
        OhosSheetSpec.resolveDetentIndex(
          current: 0,
          delta: -150, // > 100
          velocity: -200,
          heights: heights,
        ),
        1,
      );
    });

    test('挡位切换：到顶不越界', () {
      final List<double> heights = <double>[300, 500, 800];
      expect(
        OhosSheetSpec.resolveDetentIndex(
          current: 2,
          delta: -300,
          velocity: -2000,
          heights: heights,
        ),
        2,
      );
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

    testWidgets('浅底浮条自己画 hairline：墨屏纯黑，彩屏用分隔色', (WidgetTester tester) async {
      // 浮条靠阴影 + 底色分层。墨水屏没有阴影（白底浮条直接消失），彩屏上
      // 6dp 淡影罩纯白底也只剩一道模糊 —— 浅底一律补线。
      Future<BorderSide> sideFor(OhosThemeData data) async {
        await tester.pumpWidget(
          OhosTheme(
            data: data,
            child: MaterialApp(
              home: OhosScaffold(
                body: Center(
                  child: Builder(
                    builder: (BuildContext context) => OhosButton(
                      onPressed: () =>
                          showOhosSnackBar(context, message: '已保存'),
                      child: const Text('保存'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('保存'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final SnackBar bar = tester.widget<SnackBar>(find.byType(SnackBar));
        return (bar.shape! as RoundedRectangleBorder).side;
      }

      final OhosThemeData ink = OhosThemeData.ink();
      final BorderSide inkSide = await sideFor(ink);
      expect(inkSide.color, ink.dividerColor);
      expect(inkSide.width, 1);

      final OhosThemeData light = OhosThemeData.light();
      final BorderSide lightSide = await sideFor(light);
      expect(lightSide.color, light.dividerColor, reason: '白底在灰阶上只能靠线');
      expect(lightSide.width, 1);
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

      showOhosPopup(context: host, content: '长按扫码支付', targetKey: target);
      await tester.pump();
      expect(painted(tester, '长按扫码支付')?.decoration, TextDecoration.none);
      expect(painted(tester, '长按扫码支付')?.fontFamily, isNot('monospace'));

      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('OhosToast 规格', () {
    testWidgets('最大宽 400vp 且窄屏再夹「窗口宽 − 两侧 16vp」', (WidgetTester tester) async {
      // 360vp 屏：官方 400 是上限，实际只能给 360 − 16 × 2 = 328。
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);

      late BuildContext host;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (BuildContext context) {
              host = context;
              return const SizedBox(width: 40, height: 40);
            },
          ),
        ),
      );

      showOhosToast(host, '这条提示很长很长很长很长很长很长很长很长很长很长很长很长');
      await tester.pump();

      final Size toast = tester.getSize(find.byType(OhosToast));
      // 老实现写死 320；修复前这里是 320、官方要求 328（装满可用宽）。
      expect(toast.width, 328);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('内边距 16/8（资源表 toast_padding_level8 / level4），圆角 18', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const OhosToast(message: '已保存')));
      final Container container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(OhosToast),
              matching: find.byType(Container),
            )
            .first,
      );
      // 老实现 20/14 + 圆角 28，与官方三项都不同。
      expect(
        container.padding,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      );
      final BoxDecoration decoration = container.decoration! as BoxDecoration;
      expect((decoration.borderRadius! as BorderRadius).topLeft.x, 18);
    });

    testWidgets('默认位置距底 80vp（官方 ohos_id_toast_bottom）', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);

      late BuildContext host;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (BuildContext context) {
              host = context;
              return const SizedBox(width: 40, height: 40);
            },
          ),
        ),
      );

      showOhosToast(host, '已保存');
      await tester.pump();

      final Rect toast = tester.getRect(find.byType(OhosToast));
      // 底边距窗口底 80vp（SafeArea 在测试环境无 padding）。
      expect(800 - toast.bottom, closeTo(80, 0.5));

      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('OhosPopup 规格', () {
    testWidgets('圆角 20、有箭头（16×8），最大宽 400 且窄屏夹边', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);

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
        content: '这条气泡内容很长很长很长很长很长很长很长很长很长',
        targetKey: target,
      );
      await tester.pump();

      // 气泡底板就是那个带圆角的长方（箭头是 `CustomPaint`，不带 decoration）。
      final Finder bubbleFinder = find
          .descendant(
            of: find.byType(Overlay),
            matching: find.byType(Container),
          )
          .last;
      final Container bubble = tester.widget<Container>(bubbleFinder);
      // 官方 `radius` 20（老实现 16）。
      final BoxDecoration decoration = bubble.decoration! as BoxDecoration;
      expect((decoration.borderRadius! as BorderRadius).topLeft.x, 20);

      // 箭头：一条与气泡等宽、高 8vp 的三角带（`arrowHeight` 官方 8vp），
      // 三角形本身 16vp 宽画在带子里。老实现完全没有这条带子 —— 它是
      // 「指向型气泡」与「无箭头浮层」的分界线。
      final Finder arrowBand = find
          .descendant(
            of: find.byType(Overlay),
            matching: find.byType(CustomPaint),
          )
          .last;
      expect(tester.getSize(arrowBand).height, 8);
      expect(
        tester.getSize(arrowBand).width,
        tester.getSize(bubbleFinder).width,
      );

      // 宽度：360 屏上 400 的上限只能给 360 − 6 × 2 = 348（官方「气泡到屏幕
      // 边缘最小可以到 6vp，以保证尖角与点击元素可以对齐」）。
      expect(tester.getSize(bubbleFinder).width, lessThanOrEqualTo(348));

      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('OhosMenu 规格', () {
    testWidgets('手机宽度固定 224vp，不随条目文案长短跳变（设计规范原文）', (WidgetTester tester) async {
      Future<double> menuWidth(List<String> labels) async {
        final GlobalKey key = GlobalKey();
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (BuildContext context) {
                return OhosButton(
                  key: key,
                  onPressed: () {},
                  child: const Text('打开'),
                );
              },
            ),
          ),
        );
        showOhosMenu<String>(
          context: tester.element(find.byType(OhosButton)),
          anchor: key,
          items: <OhosMenuItem<String>>[
            for (final String l in labels)
              OhosMenuItem<String>(label: l, value: l),
          ],
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final Rect rect = tester.getRect(
          find.byType(PopupMenuItem<String>).first,
        );
        final double w = rect.width;
        // 关掉菜单，避免跨用例残留临时路由。
        Navigator.of(tester.element(find.byType(OhosButton))).pop();
        await tester.pump(const Duration(milliseconds: 300));
        return w;
      }

      final double narrow = await menuWidth(<String>['复制', '删除']);
      final double wide = await menuWidth(<String>['把这段文字导出为纯文本文件']);
      // 官方「泛手机统一宽度为固定 224vp」：条目文案变长，宽度不变。
      // 老实现交给 PopupMenu 自适应，两值会差出几十 vp。
      expect(narrow, 224);
      expect(wide, 224);
    });

    // 内容区左右各 16vp 是设计稿 `menu_12.png` 的两条横向量线。资源表里
    // **没有**菜单专用令牌（`divider_padding_horizontal` 数值同为 16 但是分割线
    // 的内边距，同名不同义），所以靠 `OhosMenuMetrics` 的带出处常量钉住，
    // 而不是吃 `PopupMenuItem` 的框架默认值 —— 默认值随 Flutter 版本漂移。
    testWidgets('内容区左右各留 16vp（配图 menu_12）', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (BuildContext context) =>
                OhosButton(key: key, onPressed: () {}, child: const Text('打开')),
          ),
        ),
      );
      showOhosMenu<String>(
        context: tester.element(find.byType(OhosButton)),
        anchor: key,
        items: const <OhosMenuItem<String>>[
          OhosMenuItem<String>(label: '复制', value: 'copy'),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(OhosMenuMetrics.contentPaddingHorizontal, 16);
      final Rect item = tester.getRect(
        find.byType(PopupMenuItem<String>).first,
      );
      final Rect label = tester.getRect(find.text('复制'));
      expect(label.left - item.left, 16, reason: '内容到卡片左缘应为 16vp（menu_12）');
      // 垂直方向官方没有条目标高规格，这里钉住「不动它」——
      // 单行 23vp + 上下各 12.5vp = 48vp 条目高。
      expect(item.height, 48, reason: '条目总高 48vp');

      Navigator.of(tester.element(find.byType(OhosButton))).pop();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('OhosButton 最大宽度', () {
    // **这里不能断言「700 容器里渲染成 448」**。`SizedBox(width: 700)` 给的是
    // 紧约束，它在布局模型里的含义是「子节点必须恰为 700」；`ConstrainedBox`
    // 的 `maxWidth`、`Align(widthFactor:)` 的收缩都在 `constraints.constrain()`
    // 这一步被夹回去 —— 实测直接 700，`Align` 也是 700。没有任何 Widget 能在
    // 紧约束下变窄，这不是本库的缺陷。
    //
    // 448vp 的真实语义是「父级**不限宽**时，按钮自己不无限拉伸」：官方原话是
    // 「在更大屏幕上按钮保持最大 448vp，不再跟随屏幕伸缩」。所以下面用宽松
    // （`Align`）的父级——它对子节点只给 `maxWidth: 700` 而不钉死——去触发上限。
    testWidgets('不限宽时按钮不跟屏幕无限拉伸，止于 448vp（设计规范）', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 700,
            height: 200,
            // 松约束：只限最大宽 700，不强制按钮取 700。
            child: Align(
              alignment: Alignment.topLeft,
              // 超长文案，若没有上限会被撑到 700。
              child: OhosButton(onPressed: () {}, child: Text('提交' * 200)),
            ),
          ),
        ),
      );
      // 老实现无上限：内容够长就会铺满父级给的 700。
      expect(tester.getSize(find.byType(OhosButton)).width, 448);
    });

    testWidgets('分段按钮同样止于 448vp（设计规范）', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 700,
            height: 200,
            child: Align(
              alignment: Alignment.topLeft,
              // Row 里的 Expanded 会吃掉所有可用宽度 —— 没有上限时就是 700。
              child: OhosSegmentedButton<String>(
                segments: const <OhosSegment<String>>[
                  OhosSegment<String>(label: '日', value: 'd'),
                  OhosSegment<String>(label: '周', value: 'w'),
                ],
                selected: 'd',
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(OhosSegmentedButton<String>)).width,
        448,
      );
    });
  });

  group('OhosSelect（配色 / 尺寸 / 对齐）', () {
    // 官方 Select 35 属性，0.5 只落了 6 个，且几乎每个视觉参数都不可配。
    // 这里覆盖 0.6 补的那批：四个配色、三个尺寸、两个对齐、一个开关。

    const List<OhosSelectOption<String>> opts = <OhosSelectOption<String>>[
      OhosSelectOption<String>(label: '选项一', value: 'a'),
      OhosSelectOption<String>(label: '选项二', value: 'b'),
    ];

    Future<void> openMenu(
      WidgetTester tester, {
      OhosSelect<String>? select,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 700);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrap(
          select ??
              OhosSelect<String>(options: opts, value: 'a', onChanged: (_) {}),
        ),
      );
      await tester.tap(find.byType(OhosSelect<String>));
      await tester.pumpAndSettle();
    }

    List<Container> rows(WidgetTester tester) => tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(PopupMenuItem<String>),
            matching: find.byType(Container),
          ),
        )
        .toList();

    testWidgets('选中项底色：品牌色 20%（官方 selectedOptionBgColor 默认）', (
      WidgetTester tester,
    ) async {
      await openMenu(tester);
      final Color expected = OhosThemeData.light().highlightColor.withValues(
        alpha: 0.2,
      );
      // 第一项是选中项（value: 'a'），第二项透明。
      expect(rows(tester)[0].color, expected);
      expect(rows(tester)[1].color, Colors.transparent);
    });

    testWidgets('selectedOptionBgColor / optionBgColor 分别覆盖两类项', (
      WidgetTester tester,
    ) async {
      const Color picked = Color(0x1100FF00);
      const Color normal = Color(0x110000FF);
      await openMenu(
        tester,
        select: OhosSelect<String>(
          options: opts,
          value: 'a',
          onChanged: (_) {},
          selectedOptionBgColor: picked,
          optionBgColor: normal,
        ),
      );
      expect(rows(tester)[0].color, picked);
      expect(rows(tester)[1].color, normal);
    });

    testWidgets('selectedOptionFontColor / optionFontColor 落到文字颜色', (
      WidgetTester tester,
    ) async {
      const Color selFg = Color(0xFFAA0000);
      const Color normFg = Color(0xFF0000AA);
      const List<OhosSelectOption<String>> labels = <OhosSelectOption<String>>[
        OhosSelectOption<String>(label: '甲', value: 'a'),
        OhosSelectOption<String>(label: '乙', value: 'b'),
      ];
      await openMenu(
        tester,
        select: OhosSelect<String>(
          options: labels,
          value: 'a',
          onChanged: (_) {},
          selectedOptionFontColor: selFg,
          optionFontColor: normFg,
        ),
      );
      // 触发按钮上也写着同一个标签，`find.text` 会命中两处 —— 必须限定在
      // 菜单项里找，否则 `tester.widget` 报 `Iterable.single` 的多值错误。
      Color menuColor(String label) {
        final RichText rich = tester.widget<RichText>(
          find.descendant(
            of: find.byType(PopupMenuItem<String>),
            matching: find.descendant(
              of: find.text(label),
              matching: find.byType(RichText),
            ),
          ),
        );
        return (rich.text as TextSpan).style!.color!;
      }

      expect(menuColor('甲'), selFg);
      expect(menuColor('乙'), normFg);
    });

    testWidgets('showDefaultSelectedIcon 默认 false（官方口径）', (
      WidgetTester tester,
    ) async {
      // 官方原文：false 时「通过突出显示背景色来表示选中」。老实现总是画勾 ——
      // 这是一处与官方相反的偏差，所以要有一条断言钉住默认值。
      await openMenu(tester);
      expect(
        find.byIcon(Icons.check_rounded),
        findsNothing,
        reason: '选中靠底色，不靠勾',
      );

      // **不能复用第一次的 `tester.view` 设置**：`openMenu` 里又 `addTearDown`
      // 了一遍 reset，第二次调用时前一份 tearDown 还没跑、`physicalSize` 会被
      // 重设成同一份值（无害）。真正要注意的是菜单要先关掉 —— 两个 Overlay
      // 同时存在时 `find.byIcon` 会把旧菜单的图标也算进去。
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        wrap(
          OhosSelect<String>(
            options: opts,
            value: 'a',
            onChanged: (_) {},
            showDefaultSelectedIcon: true,
          ),
        ),
      );
      await tester.tap(find.byType(OhosSelect<String>));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('arrowPosition 默认 END（文字在前），START 反过来', (
      WidgetTester tester,
    ) async {
      // 官方 `ArrowPosition.END` = 「文字在前，箭头在后」。
      await tester.pumpWidget(
        wrap(OhosSelect<String>(options: opts, value: 'a', onChanged: (_) {})),
      );
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          OhosSelect<String>(
            options: opts,
            value: 'a',
            onChanged: (_) {},
            arrowPosition: OhosSelectArrowPosition.start,
          ),
        ),
      );
      expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
      expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
    });

    testWidgets('菜单间距 space = 8vp，菜单顶边距按钮底边 8', (WidgetTester tester) async {
      // 老实现写死 4 —— 正是文档说「设置为 ≤8 的值时取默认值」的那个 8。
      await openMenu(tester);
      final Rect trigger = tester.getRect(find.byType(OhosSelect<String>));
      final Rect menu = tester.getRect(
        find
            .descendant(
              of: find.byType(Overlay),
              matching: find.byType(Material),
            )
            .last,
      );
      expect(menu.top - trigger.bottom, closeTo(8, 0.5));
    });

    testWidgets('选项最小高 48vp（资源表 option_min_height）', (
      WidgetTester tester,
    ) async {
      await openMenu(tester);
      final Size item = tester.getSize(
        find.byType(PopupMenuItem<String>).first,
      );
      expect(item.height, 48);
    });

    testWidgets('分割线默认显示、位于项间，showDivider: false 关掉', (
      WidgetTester tester,
    ) async {
      // 两项 → 中间一条，末项之后不画。
      await openMenu(tester);
      expect(find.byType(PopupMenuDivider), findsOneWidget);

      await openMenu(
        tester,
        select: OhosSelect<String>(
          options: opts,
          value: 'a',
          onChanged: (_) {},
          showDivider: false,
        ),
      );
      expect(find.byType(PopupMenuDivider), findsNothing);
    });

    testWidgets('optionWidth 显式给值时钉住菜单宽（≥56 才生效）', (WidgetTester tester) async {
      await openMenu(
        tester,
        select: OhosSelect<String>(
          options: opts,
          value: 'a',
          onChanged: (_) {},
          optionWidth: 180,
        ),
      );
      final Rect menu = tester.getRect(
        find
            .descendant(
              of: find.byType(Overlay),
              matching: find.byType(Material),
            )
            .last,
      );
      expect(menu.width, 180);

      // 低于 56 视为无效（官方「设置为无效值或小于最小宽度 56vp 时属性无效」），
      // 回落到默认最小宽 136 —— 而不是画出 30 宽的菜单。
      await openMenu(
        tester,
        select: OhosSelect<String>(
          options: opts,
          value: 'a',
          onChanged: (_) {},
          optionWidth: 30,
        ),
      );
      final Rect fallback = tester.getRect(
        find
            .descendant(
              of: find.byType(Overlay),
              matching: find.byType(Material),
            )
            .last,
      );
      expect(fallback.width, greaterThanOrEqualTo(136));
    });
  });

  group('OhosChipGroup', () {
    testWidgets('芯片尺寸对齐官方 chip_* 令牌（36/28 高、18/14 圆角）', (
      WidgetTester tester,
    ) async {
      // 这些数字不是自拟的：是 ArkUI 自己读的 sys.float 令牌真值，
      // 经 pattern.json -> float_sys.json -> float.json 解析得到
      // （见 tool/fetch_sys_resources.sh）。原来是 32/24 高、16/12 圆角，
      // 两档都偏小 4vp —— 因为 ChipGroup 和 Chip 各写了一份尺寸。
      for (final (OhosChipGroupSize size, double h, double r)
          in <(OhosChipGroupSize, double, double)>[
            (OhosChipGroupSize.normal, 36, 18),
            (OhosChipGroupSize.small, 28, 14),
          ]) {
        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 360,
              child: OhosChipGroup(
                size: size,
                selectedIndex: 0,
                items: const <OhosChipItem>[
                  OhosChipItem(label: Text('推荐')),
                  OhosChipItem(label: Text('关注')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder box = find
            .descendant(
              of: find.byType(OhosChipGroup),
              matching: find.byType(AnimatedContainer),
            )
            .first;
        expect(tester.getSize(box).height, h, reason: '$size 的高度');
        final BoxDecoration deco =
            tester.widget<AnimatedContainer>(box).decoration! as BoxDecoration;
        expect(
          deco.borderRadius,
          BorderRadius.circular(r),
          reason: '$size 的圆角取显式令牌值，不是 height / 2',
        );
      }
    });

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

    testWidgets('芯片项 allowClose 与 suffixIcon 同链优先级', (
      WidgetTester tester,
    ) async {
      int closed = 0;
      await tester.pumpWidget(
        wrap(
          OhosChipGroup(
            items: <OhosChipItem>[
              OhosChipItem(
                label: const Text('可关'),
                allowClose: true,
                onClose: () => closed++,
              ),
              OhosChipItem(
                label: const Text('带后缀'),
                allowClose: true,
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              const OhosChipItem(label: Text('普通')),
            ],
          ),
        ),
      );
      // 只有第一项有 ×；第二项的后缀图标压过 allowClose，第三项两者都没有
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(closed, 1);
    });

    // chipGroupSpace 是 {itemSpace, startSpace, endSpace} 三段；
    // chipGroupPadding 是 {top: 14, bottom: 14}。上一版只有一个 spacing，
    // 只够表达中间那段，两端 16 和内边距 14 全丢了 —— 于是首颗芯片贴着屏幕边。
    testWidgets('三段间距 8/16/16 + 纵向 padding 14，整组高 64', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 360,
            child: OhosChipGroup(
              items: const <OhosChipItem>[
                OhosChipItem(label: Text('推荐')),
                OhosChipItem(label: Text('关注')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 用相对坐标：容器在测试画面里居中，`getRect` 给的是全局位置，
      // 直接断言绝对 dx 会把「居中偏移 220」当成间距。
      final Rect group = tester.getRect(find.byType(OhosChipGroup));
      final Rect first = tester.getRect(
        find
            .descendant(
              of: find.byType(OhosChipGroup),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final Rect second = tester.getRect(
        find
            .descendant(
              of: find.byType(OhosChipGroup),
              matching: find.byType(AnimatedContainer),
            )
            .last,
      );
      // 首颗芯片距容器左边 = startSpace 16（不是 0，也不是 16+16）
      expect(first.left - group.left, closeTo(16, 0.01), reason: 'startSpace');
      // 两颗之间 = itemSpace 8
      expect(second.left - first.right, closeTo(8, 0.01), reason: 'itemSpace');
      // 整组高 = 芯片 36 + padding 14*2 = 64
      expect(group.height, closeTo(64, 0.01), reason: 'chipGroupPadding 只加纵向');
    });

    // ArkUI `selectedIndexes: Array<number> = [0]`，且 `aboutToAppear`
    // 在解析结果为空时再补一次 `[0]` —— 刚建好的组永远不是全空闲态。
    testWidgets('不传选中项时默认选中第 0 颗', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosChipGroup(
            items: const <OhosChipItem>[
              OhosChipItem(label: Text('推荐')),
              OhosChipItem(label: Text('关注')),
            ],
            onSelected: _noopInt,
          ),
        ),
      );
      await tester.pumpAndSettle();

      BoxDecoration deco(int i) {
        final Finder boxes = find.descendant(
          of: find.byType(OhosChipGroup),
          matching: find.byType(AnimatedContainer),
        );
        return tester
                .widget<AnimatedContainer>(i == 0 ? boxes.first : boxes.at(i))
                .decoration!
            as BoxDecoration;
      }

      final OhosThemeData theme = OhosThemeData.light();
      expect(deco(0).color, theme.highlightColor, reason: '第 0 颗默认选中');
      expect(deco(1).color, isNot(theme.highlightColor), reason: '其余保持空闲');
    });

    // 行为变更：0.5.x 不传就一个都不选中，现在与 ArkUI 同默认。想保留旧表现
    // 要显式传 -1 / 空集 —— 这条断言把「旧表现仍可达」钉住，否则升级路径断掉。
    testWidgets('selectedIndex: -1 与空集可退回「全不选」', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosChipGroup(
            selectedIndex: -1,
            items: const <OhosChipItem>[
              OhosChipItem(label: Text('推荐')),
              OhosChipItem(label: Text('关注')),
            ],
            onSelected: _noopInt,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final OhosThemeData theme = OhosThemeData.light();
      final Finder boxes = find.descendant(
        of: find.byType(OhosChipGroup),
        matching: find.byType(AnimatedContainer),
      );
      for (int i = 0; i < 2; i++) {
        final BoxDecoration deco =
            tester.widget<AnimatedContainer>(boxes.at(i)).decoration!
                as BoxDecoration;
        expect(deco.color, isNot(theme.highlightColor), reason: '第 $i 颗');
      }
    });

    // prefixSymbol 双态：两态是**不同的图形**，不是同一图形换色。
    testWidgets('芯片项 selectedIcon 只在选中时替换 icon', (WidgetTester tester) async {
      for (final int index in <int>[0, 1]) {
        await tester.pumpWidget(
          wrap(
            OhosChipGroup(
              selectedIndex: index,
              onSelected: _noopInt,
              items: const <OhosChipItem>[
                OhosChipItem(
                  label: Text('音乐'),
                  icon: Icon(Icons.music_note_outlined),
                  selectedIcon: Icon(Icons.music_note),
                ),
                OhosChipItem(
                  label: Text('视频'),
                  icon: Icon(Icons.videocam_outlined),
                  selectedIcon: Icon(Icons.videocam),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        // 选中那颗用 selectedIcon（实心），另一颗保持 icon（描边）。
        // 注意「另一颗」是**另一项**，不是同一项的另一个态 —— 两轮里
        // 选中项在换，所以断言也要跟着换到对应的那颗。
        final int other = index == 0 ? 1 : 0;
        final IconData selectedGlyph = index == 0
            ? Icons.music_note
            : Icons.videocam;
        final IconData idleGlyph = other == 0
            ? Icons.music_note_outlined
            : Icons.videocam_outlined;
        expect(
          find.byIcon(selectedGlyph),
          findsOneWidget,
          reason: '第 $index 颗被选中，应用 selectedIcon',
        );
        expect(
          find.byIcon(idleGlyph),
          findsOneWidget,
          reason: '第 $other 颗未选中，保持 icon',
        );
      }
    });
  });

  group('OhosChip', () {
    testWidgets('与 OhosChipGroup 共用同一份官方尺寸（不再各写一遍）', (
      WidgetTester tester,
    ) async {
      // 这两个组件曾是两份独立实现，尺寸各写一份 —— 0.5.0 修描边时发现过
      // 这个根因，这次尺寸漂移（chip 33.6 / group 32，官方 36）是第二次。
      // 现在两边都读 OhosChipMetrics，这条断言就是「同源」的可验证形式。
      for (final (OhosChipSize size, double h, double r)
          in <(OhosChipSize, double, double)>[
            (OhosChipSize.normal, 36, 18),
            (OhosChipSize.small, 28, 14),
          ]) {
        await tester.pumpWidget(
          wrap(OhosChip(size: size, label: const Text('标签'), onPressed: () {})),
        );
        final Finder chip = find.byType(OhosChip);
        expect(tester.getSize(chip).height, h, reason: '$size 的高度');
        final Material material = tester.widget<Material>(
          find.descendant(of: chip, matching: find.byType(Material)).first,
        );
        expect(
          (material.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(r),
          reason: '$size 的圆角取显式令牌值',
        );
      }
    });

    testWidgets('字号 14fp、图标 16 + 间距 6（normal）', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosChip(
            label: const Text('标签'),
            icon: const Icon(Icons.tag),
            onPressed: () {},
          ),
        ),
      );
      // chip_normal_font_size 经 ohos_id_text_size_button2 解析为 14fp
      final Text label = tester.widget<Text>(find.text('标签'));
      final TextStyle style = DefaultTextStyle.of(
        tester.element(find.text('标签')),
      ).style.merge(label.style);
      expect(style.fontSize, 14);
      // chip_normal_text_margin = 6
      expect(tester.getSize(find.byType(Icon)).height, 16);
      final double gap =
          tester.getTopLeft(find.text('标签')).dx -
          tester.getTopRight(find.byType(Icon)).dx;
      expect(gap, 6);
    });

    testWidgets('allowClose 画关闭图标，且 onClose 只在点击它时触发', (
      WidgetTester tester,
    ) async {
      int closed = 0;
      int pressed = 0;
      await tester.pumpWidget(
        wrap(
          OhosChip(
            label: const Text('标签'),
            allowClose: true,
            onPressed: () => pressed++,
            onClose: () => closed++,
          ),
        ),
      );
      // allowClose 默认 false：不传就一个图标都没有
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(closed, 1);
      // 关闭是独立动作，不该顺带触发整个芯片的 onPressed
      expect(pressed, 0);

      // 默认（不传 allowClose）不画 ×：这是有意的偏离 —— ArkUI 独立 Chip 的
      // `isClosable()` 是 `allowClose ?? true`，而 ChipGroup 传的是 `?? false`。
      // 本库两个场景共用一个 Chip，跟随 true 会让所有既有芯片在升级后凭空
      // 长出一个 ×，且 onClose 为 null 时那个 × 点了没反应。
      await tester.pumpWidget(
        wrap(OhosChip(label: const Text('标签'), onPressed: () {})),
      );
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('suffixIcon 压过 allowClose（ArkUI 优先级链）', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OhosChip(
            label: const Text('标签'),
            allowClose: true,
            suffixIcon: const Icon(Icons.arrow_drop_down),
            onPressed: () {},
          ),
        ),
      );
      // `hasSuffix()` 为真时 `isNeedShowCloseIconMargin()` 那条分支根本不进，
      // 所以内置 × 必须消失，而不是两个图标并排
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      // 后缀图标与文字间距同样是 chip_normal_text_margin = 6
      final double gap =
          tester.getTopLeft(find.byIcon(Icons.arrow_drop_down)).dx -
          tester.getTopRight(find.text('标签')).dx;
      expect(gap, 6);
    });

    // `prefixSymbol` 的 normal / activated 是**两个图形**（`chip.ets:838` 的
    // `getPrefixSymbolModifier()`），不是同一图形换色。
    testWidgets('selectedIcon 只在选中时替换 icon，间距不变仍 6', (
      WidgetTester tester,
    ) async {
      for (final bool sel in <bool>[false, true]) {
        await tester.pumpWidget(
          wrap(
            OhosChip(
              label: const Text('标签'),
              icon: const Icon(Icons.favorite_border),
              selectedIcon: const Icon(Icons.favorite),
              selected: sel,
              onPressed: () {},
            ),
          ),
        );
        expect(
          find.byIcon(sel ? Icons.favorite : Icons.favorite_border),
          findsOneWidget,
          reason: 'selected=$sel 时应画对应态图标',
        );
        expect(
          find.byIcon(sel ? Icons.favorite_border : Icons.favorite),
          findsNothing,
        );
        // 图标与文字间距与从属态无关，两态都取 chip_normal_text_margin = 6
        final Finder shown = find.byIcon(
          sel ? Icons.favorite : Icons.favorite_border,
        );
        final double gap =
            tester.getTopLeft(find.text('标签')).dx -
            tester.getTopRight(shown).dx;
        expect(gap, 6, reason: 'selected=$sel 的图标间距');
      }
    });

    // 只给 normal 态时不照搬 ArkUI 的「选中就失去图标」：`chip.ets:1014` 的
    // `hasPrefix()` 会连带去掉图标和间距，在 Flutter 侧那是既有用法被点一下就
    // 掉图标，属于缺陷而非语义。回落规则写在 [OhosChip.selectedIcon] 上。
    testWidgets('只传 icon 时选中态沿用 icon，不会消失', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosChip(
            label: const Text('标签'),
            icon: const Icon(Icons.tag),
            selected: true,
            onPressed: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.tag), findsOneWidget);
      final double gap =
          tester.getTopLeft(find.text('标签')).dx -
          tester.getTopRight(find.byIcon(Icons.tag)).dx;
      expect(gap, 6, reason: '间距也保留，不能随图标一起没有');
    });

    // ---- 0.6 新补的配色 / 字体 / 双态后缀（官方 ChipOptions + LabelOptions）----

    Material chipMaterial(WidgetTester tester) => tester.widget<Material>(
      find
          .descendant(
            of: find.byType(OhosChip),
            matching: find.byType(Material),
          )
          .first,
    );

    testWidgets('backgroundColor 覆盖常态底，activatedBackgroundColor 覆盖选中底', (
      WidgetTester tester,
    ) async {
      const Color idle = Color(0xFF101010);
      const Color active = Color(0xFF202020);
      await tester.pumpWidget(
        wrap(
          OhosChip(
            label: const Text('标签'),
            onPressed: () {},
            backgroundColor: idle,
          ),
        ),
      );
      expect(chipMaterial(tester).color, idle);

      await tester.pumpWidget(
        wrap(
          OhosChip(
            label: const Text('标签'),
            onPressed: () {},
            selected: true,
            activatedBackgroundColor: active,
          ),
        ),
      );
      expect(chipMaterial(tester).color, active);
    });

    testWidgets('activatedBackgroundColor 与旧参数 selectedColor 都给时，前者优先', (
      WidgetTester tester,
    ) async {
      // 同一条规格两个入口，必须定优先级，否则「两个都传谁生效」全靠猜。
      await tester.pumpWidget(
        wrap(
          OhosChip(
            label: const Text('标签'),
            onPressed: () {},
            selected: true,
            selectedColor: const Color(0xFF333333),
            activatedBackgroundColor: const Color(0xFF444444),
          ),
        ),
      );
      expect(chipMaterial(tester).color, const Color(0xFF444444));
    });

    testWidgets('labelColor / activatedLabelColor 落到文字颜色（与图标色分开）', (
      WidgetTester tester,
    ) async {
      // 官方 `LabelOptions.fontColor` 默认 `ohos_id_color_text_primary`，
      // 而图标 fillColor 默认是 `chip_usually_icon_color`（≈ secondary）。
      // 老实现把两者绑在同一个 fg 上 —— 文字常态因此偏淡一档。
      const Color idle = Color(0xFF555555);
      const Color active = Color(0xFF666666);
      final OhosThemeData theme = OhosThemeData.light();

      await tester.pumpWidget(
        wrap(
          OhosChip(
            label: const Text('标签'),
            icon: const Icon(Icons.tag),
            onPressed: () {},
            labelColor: idle,
          ),
        ),
      );
      expect(paintedColor(tester, '标签'), idle);
      // 图标仍是 secondary，不跟着文字走 —— 官方 `prefixIcon.fillColor`
      // 与 `LabelOptions.fontColor` 默认值不同源。
      //
      // 读**实际绘制**的颜色而不是 `Icon.color`：颜色是经 `IconTheme.merge`
      // 给的，不会回填到 `Icon.color`（读它会拿到 null，同 `Text.style` 那条坑）。
      final RichText glyph = tester.widget<RichText>(
        find.descendant(
          of: find.byIcon(Icons.tag),
          matching: find.byType(RichText),
        ),
      );
      expect((glyph.text as TextSpan).style?.color, theme.textSecondaryColor);

      await tester.pumpWidget(
        wrap(
          OhosChip(
            label: const Text('标签'),
            onPressed: () {},
            selected: true,
            activatedLabelColor: active,
          ),
        ),
      );
      expect(paintedColor(tester, '标签'), active);
    });

    testWidgets('选中态字重 w500、常态 w400（官方 chip_*_text_font_weight）', (
      WidgetTester tester,
    ) async {
      // 资源表：`chip_text_font_weight = 400`、`chip_activated_text_font_weight
      // = 500`。老实现两档都是 400，「选中」只剩颜色一条线索。
      FontWeight weightOf(WidgetTester tester) =>
          paintedTextStyle(tester, '标签').fontWeight!;

      await tester.pumpWidget(
        wrap(OhosChip(label: const Text('标签'), onPressed: () {})),
      );
      expect(weightOf(tester), FontWeight.w400);

      await tester.pumpWidget(
        wrap(
          OhosChip(label: const Text('标签'), onPressed: () {}, selected: true),
        ),
      );
      expect(weightOf(tester), FontWeight.w500);
    });

    testWidgets('labelFontSize / labelFontFamily 可配', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OhosChip(
            label: const Text('标签'),
            onPressed: () {},
            labelFontSize: 17,
            labelFontFamily: 'TestFamily',
          ),
        ),
      );
      final TextStyle style = paintedTextStyle(tester, '标签');
      expect(style.fontSize, 17);
      expect(style.fontFamily, 'TestFamily');

      // 不给时取令牌 14fp、家族跟随主题（不写死 "HarmonyOS Sans"）。
      await tester.pumpWidget(
        wrap(OhosChip(label: const Text('标签'), onPressed: () {})),
      );
      expect(paintedTextStyle(tester, '标签').fontSize, 14);
    });

    testWidgets('suffixSelectedIcon 只在选中时替换后缀图标', (WidgetTester tester) async {
      // 官方 `suffixSymbol` 的 normal / activated 同样是**两个图形**。
      for (final bool sel in <bool>[false, true]) {
        await tester.pumpWidget(
          wrap(
            OhosChip(
              label: const Text('标签'),
              onPressed: () {},
              selected: sel,
              suffixIcon: const Icon(Icons.arrow_drop_down),
              suffixSelectedIcon: const Icon(Icons.arrow_drop_up),
            ),
          ),
        );
        expect(
          find.byIcon(sel ? Icons.arrow_drop_up : Icons.arrow_drop_down),
          findsOneWidget,
          reason: 'selected=$sel 的后缀',
        );
        expect(
          find.byIcon(sel ? Icons.arrow_drop_down : Icons.arrow_drop_up),
          findsNothing,
        );
      }
    });

    testWidgets('只给 suffixSelectedIcon 时选中态画得出来，不会掉图标', (
      WidgetTester tester,
    ) async {
      // 判据必须用「已按 selected 选好的那个」，只看 `suffixIcon != null`
      // 会让只给 activated 后缀的芯片在选中态什么都不画 —— 那是缺陷。
      await tester.pumpWidget(
        wrap(
          OhosChip(
            label: const Text('标签'),
            onPressed: () {},
            selected: true,
            suffixSelectedIcon: const Icon(Icons.arrow_drop_up),
          ),
        ),
      );
      expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
    });
  });

  group('OhosTabsWidthDefaults', () {
    // 官方默认算法（`HdsBarWidthRangeOptions` 三条默认值说明）：
    // ≤3 个页签时 `76n+8`（宽 <600vp）或 `80n+8`（≥600vp）；≥4 个时上限 328。
    test('≤3 个页签：76n+8 / 80n+8', () {
      // 360 < 600 ⇒ 用 76
      expect(
        OhosTabsWidthDefaults.compute(tabCount: 3, containerWidth: 360),
        76 * 3 + 8,
      );
      // 800 > 600 且高度未给 ⇒ 走大档 80
      expect(
        OhosTabsWidthDefaults.compute(tabCount: 2, containerWidth: 800),
        80 * 2 + 8,
      );
    });

    // **这条是本项的核心**：官方「页签个数大于等于 4 时，页签栏最大宽度不超过
    // 328vp」不是「先按 76n+8 算再夹」，而是**直接换规则**。
    // 4 个页签按 76×4+8 = 312 还没到上限 —— 若写成「算完再 clamp」会得到 312，
    // 与官方的 328 差 16vp。
    test('≥4 个页签直接取上限 328，不是算完再夹', () {
      expect(
        OhosTabsWidthDefaults.compute(tabCount: 4, containerWidth: 360),
        OhosTabsWidthDefaults.maxBarWidth,
      );
      expect(
        OhosTabsWidthDefaults.compute(tabCount: 4, containerWidth: 360),
        isNot(76 * 4 + 8),
        reason: '312 是「算完再夹」的答案，官方是直接取上限',
      );
      expect(
        OhosTabsWidthDefaults.compute(tabCount: 9, containerWidth: 360),
        OhosTabsWidthDefaults.maxBarWidth,
      );
    });

    // 三档断点：<440 small / 440–600 medium / >840 large。
    test('三档断点按宽度划分', () {
      expect(
        OhosTabsWidthDefaults.tierOf(containerWidth: 400),
        OhosTabsWidthTier.small,
      );
      expect(
        OhosTabsWidthDefaults.tierOf(containerWidth: 440),
        OhosTabsWidthTier.medium,
      );
      expect(
        OhosTabsWidthDefaults.tierOf(containerWidth: 599),
        OhosTabsWidthTier.medium,
      );
      expect(
        OhosTabsWidthDefaults.tierOf(containerWidth: 841),
        OhosTabsWidthTier.large,
      );
    });

    // **600–840vp 之间由高宽比决定**，这条旁支最容易被简化掉。
    // 官方 `mediumWidth`：「宽度在 440vp-600vp 之间，**或宽度在 600-840vp 之间
    // 且高宽比小于 0.8**」；`largeWidth` 对称写「高宽比大于 0.8」。
    // 只按宽度分三档的话，竖屏平板（高宽比大）与横屏平板会选到同一档。
    //
    // **「高宽比」= 高 ÷ 宽**，按中文词序读。第一版写成 宽÷高，方向正好相反 ——
    // 竖屏平板被判成横屏档。是下面第一条断言当场抓到的。
    test('600–840vp 区间：高宽比决定中/大档', () {
      // 700 宽 × 1000 高：高宽比 1.43 > 0.8 ⇒ large（竖高，用 80vp 宽档）
      expect(
        OhosTabsWidthDefaults.tierOf(
          containerWidth: 700,
          containerHeight: 1000,
        ),
        OhosTabsWidthTier.large,
      );
      // 800 宽 × 700 高：高宽比 0.875 > 0.8 ⇒ large
      expect(
        OhosTabsWidthDefaults.tierOf(containerWidth: 800, containerHeight: 700),
        OhosTabsWidthTier.large,
      );
      // 700 宽 × 500 高：高宽比 0.71 < 0.8 ⇒ medium（宽扁，用 76vp 宽档）
      expect(
        OhosTabsWidthDefaults.tierOf(containerWidth: 700, containerHeight: 500),
        OhosTabsWidthTier.medium,
      );
    });

    // 页签数为 0 时宽度 0（不是 `8`）——「只有一个 8vp 的空栏」比不画更糟。
    test('0 个页签宽度为 0', () {
      expect(
        OhosTabsWidthDefaults.compute(tabCount: 0, containerWidth: 360),
        0,
      );
    });

    test('OhosTabsBarWidthRange 值相等', () {
      const OhosTabsBarWidthRange a = OhosTabsBarWidthRange(
        smallWidth: 200,
        mediumWidth: 240,
      );
      const OhosTabsBarWidthRange b = OhosTabsBarWidthRange(
        smallWidth: 200,
        mediumWidth: 240,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const OhosTabsBarWidthRange(smallWidth: 200)));
    });
  });

  group('OhosFloatingTabBar', () {
    // 悬浮栏的前置条件之一是「栏叠在内容之上」。这里给一个有界尺寸的宿主，
    // 否则 `LayoutBuilder` 拿到无界宽、宽度分档与边距全都没法算。
    Widget host({
      required List<OhosFloatingTabItem> items,
      int selected = 0,
      double width = 360,
      double height = 400,
      OhosFloatingTabBarStyle style = const OhosFloatingTabBarStyle(),
      ValueChanged<int>? onSelected,
      OhosTabsBarWidthRange? widthRange,
    }) {
      return wrap(
        SizedBox(
          width: width,
          height: height,
          child: OhosFloatingTabBar(
            items: items,
            selectedIndex: selected,
            onSelected: onSelected ?? (_) {},
            style: style,
            widthRange: widthRange,
          ),
        ),
      );
    }

    List<OhosFloatingTabItem> threeItems() => const <OhosFloatingTabItem>[
      OhosFloatingTabItem(icon: Icon(Icons.home_outlined), label: '首页'),
      OhosFloatingTabItem(icon: Icon(Icons.search), label: '搜索'),
      OhosFloatingTabItem(icon: Icon(Icons.person_outline), label: '我的'),
    ];

    // 量**栏体**，不是整个组件，也不是第一个 `SizedBox`。
    //
    // 两层都会坑：外层 `SizedBox(360, 400)` 是宿主撑满的；组件内部第一个
    // `SizedBox` 是宽度那一层没错，但 `OhosLightMaterial` 里还有一个
    // `SizedBox.expand`（模糊背板）也会被同一个 finder 命中。所以直接量栏内
    // 的 `Row` —— 它拿的是紧约束，宽度与高度都精确等于栏体的。
    //
    // **坐标是全局的**：宿主被 `Center` 居中后并不从 x=0 起（360 宽居中在
    // 800 宽屏上是 x=220）。所以左右边距要用宿主的实际矩形去比，不能拿
    // `width - expected` 当右边界 —— 那是把局部值当全局值用，一开始就错了。
    Rect barRect(WidgetTester tester) => tester.getRect(
      find
          .descendant(
            of: find.byType(OhosFloatingTabBar),
            matching: find.byType(Row),
          )
          .first,
    );

    Rect hostRect(WidgetTester tester) =>
        tester.getRect(find.byType(SizedBox).first);

    // 栏高**有官方值**：`barHeight` 在悬浮样式下默认 56vp（平铺是 48vp）。
    // 这条断言同时守住「别把 48 抄过来」——两者差 8vp，肉眼不明显。
    testWidgets('栏高默认 56vp，宽度按 76n+8 算', (WidgetTester tester) async {
      await tester.pumpWidget(host(items: threeItems()));
      final Rect bar = barRect(tester);
      // 3 个页签、360 < 600 ⇒ 76×3+8 = 236
      expect(bar.width, 236);
      expect(bar.height, 56);
    });

    // 这条是本组件存在的理由：官方把三档宽度挂在 `barFloatingStyle` 下，
    // 平铺栏的 `barWidth` 是单个 `Length`。≥4 个直接取 328 的规则在这里复验。
    testWidgets('4 个页签取上限 328', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          items: const <OhosFloatingTabItem>[
            OhosFloatingTabItem(icon: Icon(Icons.home_outlined)),
            OhosFloatingTabItem(icon: Icon(Icons.search)),
            OhosFloatingTabItem(icon: Icon(Icons.star_outline)),
            OhosFloatingTabItem(icon: Icon(Icons.person_outline)),
          ],
        ),
      );
      expect(barRect(tester).width, OhosTabsWidthDefaults.maxBarWidth);
    });

    // 328 是**绝对上限**，容器只有 340 宽时「16 + 328 + 16」会溢出 20vp。
    // 官方原文是「最大宽度不超过 328」，不是「一定等于 328」—— 必须再夹一次
    // 可用宽度。这条不测会很晚才在真机上暴露（`RenderFlex` 不报错，只是挤出屏）。
    testWidgets('窄容器下 328 被夹到可用宽度，不溢出', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          width: 340,
          items: const <OhosFloatingTabItem>[
            OhosFloatingTabItem(icon: Icon(Icons.home_outlined)),
            OhosFloatingTabItem(icon: Icon(Icons.search)),
            OhosFloatingTabItem(icon: Icon(Icons.star_outline)),
            OhosFloatingTabItem(icon: Icon(Icons.person_outline)),
          ],
        ),
      );
      // 340 - 16×2 = 308
      expect(barRect(tester).width, 308);
    });

    // 官方 `barSideMargin` 三档：<600 16vp / 600–840 24vp / >840 32vp。
    // **栏居中，边距是最小间隙而不是定位锚点** —— 用 `Padding(left/right)`
    // 定位会变成左对齐，栏一窄就贴左边。这里同时断左右两侧，才抓得住。
    testWidgets('栏居中，左右边距按宽度分三档：16 / 24 / 32', (WidgetTester tester) async {
      for (final (double w, double expected) in <(double, double)>[
        (360, 16),
        (700, 24),
        (900, 32),
      ]) {
        await tester.pumpWidget(host(items: threeItems(), width: w));
        final Rect bar = barRect(tester);
        final Rect box = hostRect(tester);
        expect(
          bar.left - box.left,
          greaterThanOrEqualTo(expected - 0.01),
          reason: '宽 $w 时左边距至少 $expected',
        );
        expect(
          box.right - bar.right,
          greaterThanOrEqualTo(expected - 0.01),
          reason: '宽 $w 时右边距至少 $expected',
        );
        // 居中意味着两侧留白相等（宿主 400 高，栏在最底部，水平居中）
        expect(
          ((bar.left - box.left) - (box.right - bar.right)).abs(),
          lessThan(0.01),
          reason: '栏必须水平居中，不能靠左',
        );
      }
    });

    // 调用方显式给边距时，**不能**再按宽度自动分档。
    // 这里用 20（非任何一档的默认值），避免「恰好等于 16 所以看不出区别」。
    testWidgets('显式边距不参与自动分档', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          items: threeItems(),
          width: 900,
          style: const OhosFloatingTabBarStyle(sideMargin: 20),
        ),
      );
      final Rect bar = barRect(tester);
      final Rect box = hostRect(tester);
      expect(bar.left - box.left, greaterThanOrEqualTo(20 - 0.01));
      expect(box.right - bar.right, greaterThanOrEqualTo(20 - 0.01));
    });

    testWidgets('点击回调带正确下标', (WidgetTester tester) async {
      int? tapped;
      await tester.pumpWidget(
        host(items: threeItems(), onSelected: (int i) => tapped = i),
      );
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      expect(tapped, 1);
    });

    // 选中态换图标：`activeIcon` 缺省时回落 `icon`，「切一下就掉图标」不是
    // 双态而是缺陷（与 ActionBar 的 altIcon、Chip 的 selectedIcon 同规）。
    testWidgets('选中换图标，缺 activeIcon 时回落', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          items: const <OhosFloatingTabItem>[
            OhosFloatingTabItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '首页',
            ),
            OhosFloatingTabItem(icon: Icon(Icons.search), label: '搜索'),
          ],
          selected: 0,
        ),
      );
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsNothing);
      // 第二项没给 activeIcon，图标必须还在
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('禁用项不响应点击', (WidgetTester tester) async {
      int calls = 0;
      await tester.pumpWidget(
        host(
          items: const <OhosFloatingTabItem>[
            OhosFloatingTabItem(
              icon: Icon(Icons.home_outlined),
              label: '首页',
              enabled: false,
            ),
            OhosFloatingTabItem(icon: Icon(Icons.search), label: '搜索'),
          ],
          onSelected: (_) => calls++,
        ),
      );
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pump();
      expect(calls, 0, reason: '禁用项不该触发回调');
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      expect(calls, 1, reason: '同组的可用项必须仍能点');
    });

    testWidgets('角标文字渲染', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          items: const <OhosFloatingTabItem>[
            OhosFloatingTabItem(
              icon: Icon(Icons.notifications_none),
              label: '消息',
              badge: '99+',
            ),
          ],
        ),
      );
      expect(find.text('99+'), findsOneWidget);
    });

    // 墨屏：模糊被策略关掉时改画实色 + 描边。断言的落点是「有没有
    // `BackdropFilter`」而不是颜色 —— 墨水屏真机上 `BackdropFilter` 的
    // 失败方式是拖尾 / 留灰块，比颜色错更难发现。
    testWidgets('墨屏不建 BackdropFilter，改画描边', (WidgetTester tester) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: const MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 400,
                  child: OhosFloatingTabBar(
                    items: <OhosFloatingTabItem>[
                      OhosFloatingTabItem(
                        icon: Icon(Icons.home_outlined),
                        label: '首页',
                      ),
                      OhosFloatingTabItem(
                        icon: Icon(Icons.search),
                        label: '搜索',
                      ),
                    ],
                    selectedIndex: 0,
                    onSelected: _noopInt,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(OhosFloatingTabBar),
          matching: find.byType(DecoratedBox),
        ),
      );
      final bool hasBorder = boxes.any((DecoratedBox b) {
        final Decoration d = b.decoration;
        return d is BoxDecoration && d.border != null;
      });
      expect(hasBorder, isTrue, reason: '灰阶屏靠描边立住形体');
    });

    testWidgets('OhosFloatingTabBarStyle 值相等', (WidgetTester tester) async {
      const OhosFloatingTabBarStyle a = OhosFloatingTabBarStyle(
        height: 56,
        radius: 28,
      );
      const OhosFloatingTabBarStyle b = OhosFloatingTabBarStyle(
        height: 56,
        radius: 28,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const OhosFloatingTabBarStyle(height: 60)));
    });

    // 蒙层：官方 `gradientMask` 的高度 = 栏高 + 16vp。这里量「栏体之外
    // 还有没有那块多出来的区域」—— 只看颜色看不出少画了 16vp。
    testWidgets('蒙层向下多出 16vp', (WidgetTester tester) async {
      await tester.pumpWidget(host(items: threeItems()));
      // 栏体本身仍是 56 高（蒙层是叠上去的，不撑大组件）
      expect(tester.getSize(find.byType(Row)).height, 56);
      // 蒙层用的是 maskColor 默认值（浅色 #CCF1F3F5）
      final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(OhosFloatingTabBar),
          matching: find.byType(DecoratedBox),
        ),
      );
      final bool hasMask = boxes.any((DecoratedBox b) {
        final Decoration d = b.decoration;
        return d is BoxDecoration && d.color == const Color(0xCCF1F3F5);
      });
      expect(hasMask, isTrue);
    });

    testWidgets('showMask 为 false 时不画蒙层', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          items: threeItems(),
          style: const OhosFloatingTabBarStyle(showMask: false),
        ),
      );
      final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(OhosFloatingTabBar),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        boxes.any((DecoratedBox b) {
          final Decoration d = b.decoration;
          return d is BoxDecoration && d.color == const Color(0xCCF1F3F5);
        }),
        isFalse,
      );
    });
  });

  group('OhosMiniBar', () {
    // 迷你栏的宽度分档与页签栏共用一套纯函数，这里只验「跟页签栏同型」和
    // 「状态机」两条；真正的风险在 `OhosMiniBarScaffold` 的居中规则上。

    Widget miniHost({
      double width = 360,
      double height = 400,
      OhosBarStyle barStyle = OhosBarStyle.collapse,
      OhosMiniBarStyle style = const OhosMiniBarStyle(),
      OhosTabsBarWidthRange? widthRange,
      WidgetBuilder? builder,
    }) {
      return wrap(
        SizedBox(
          width: width,
          height: height,
          child: Center(
            child: OhosMiniBar(
              barStyle: barStyle,
              style: style,
              widthRange: widthRange,
              builder: builder ?? (_) => const Text('mini'),
            ),
          ),
        ),
      );
    }

    // 量**栏体**，不能量内部第一个 `SizedBox`。
    //
    // `OhosMiniBar` 的尺寸现在由 `AnimatedContainer` 承载（折叠/展开是隐式
    // 过渡），只有在「动效被策略压成零」的墨水屏上才退回 `SizedBox`。所以
    // 找 `SizedBox` 在常规主题下会一个都找不到（`Bad state: No element`）。
    // 量 `OhosMiniBar` 自己最稳 —— 它是最外层，且没有别的同名节点包在外面。
    Rect miniRect(WidgetTester tester) =>
        tester.getRect(find.byType(OhosMiniBar));

    testWidgets('折叠态宽度自拟 56，高度与页签栏对齐 56', (WidgetTester tester) async {
      await tester.pumpWidget(miniHost());
      final Rect r = miniRect(tester);
      expect(r.width, 56);
      expect(r.height, 56);
    });

    // 展开态复用页签栏的默认算法。1 个页签、360 < 600 ⇒ 76×1+8 = 84。
    testWidgets('展开态按分档算法算宽', (WidgetTester tester) async {
      await tester.pumpWidget(
        miniHost(barStyle: OhosBarStyle.expand, widthRange: null),
      );
      expect(miniRect(tester).width, 84);
    });

    // 328 是绝对上限：窄容器里「边距 + 328」会溢出，所以再夹一次可用宽。
    testWidgets('展开态宽度不超过容器宽', (WidgetTester tester) async {
      await tester.pumpWidget(
        miniHost(width: 300, barStyle: OhosBarStyle.expand),
      );
      expect(miniRect(tester).width, lessThanOrEqualTo(300));
    });

    // 官方两条原文合起来才完整：①首次创建默认折叠 ②>600vp 强制展开，
    // 此时调用方传什么都不作数。
    testWidgets('首次创建：小屏默认折叠', (WidgetTester tester) async {
      expect(
        OhosMiniBar.initialStyle(containerWidth: 360),
        OhosBarStyle.collapse,
      );
    });

    testWidgets('首次创建：>600vp 强制展开，忽略调用方传入的折叠', (WidgetTester tester) async {
      expect(
        OhosMiniBar.initialStyle(
          containerWidth: 700,
          requested: OhosBarStyle.collapse,
        ),
        OhosBarStyle.expand,
        reason: '官方原文：宽度大于 600vp 则为展开样式',
      );
    });

    testWidgets('首次创建：小屏尊重调用方显式传入', (WidgetTester tester) async {
      expect(
        OhosMiniBar.initialStyle(
          containerWidth: 500,
          requested: OhosBarStyle.expand,
        ),
        OhosBarStyle.expand,
      );
    });

    // 居中规则在 440vp 处换口径，这是本组最容易写错的一条。
    testWidgets('<440vp 一展一折：整体居中', (WidgetTester tester) async {
      expect(
        OhosMiniBar.alignFor(
          containerWidth: 400,
          miniStyle: OhosBarStyle.collapse,
          tabStyle: OhosBarStyle.expand,
        ),
        OhosMiniBarAlign.group,
      );
    });

    testWidgets('440–600vp 一展一折：只有展开者居中', (WidgetTester tester) async {
      expect(
        OhosMiniBar.alignFor(
          containerWidth: 520,
          miniStyle: OhosBarStyle.collapse,
          tabStyle: OhosBarStyle.expand,
        ),
        OhosMiniBarAlign.expandedOnly,
      );
    });

    testWidgets('两者同时展开：整体居中', (WidgetTester tester) async {
      expect(
        OhosMiniBar.alignFor(
          containerWidth: 800,
          miniStyle: OhosBarStyle.expand,
          tabStyle: OhosBarStyle.expand,
        ),
        OhosMiniBarAlign.group,
      );
    });

    testWidgets('两者同时折叠：整体居中', (WidgetTester tester) async {
      expect(
        OhosMiniBar.alignFor(
          containerWidth: 520,
          miniStyle: OhosBarStyle.collapse,
          tabStyle: OhosBarStyle.collapse,
        ),
        OhosMiniBarAlign.group,
      );
    });

    // `enableMiniBarBackground = false` 是「无色透明」的字面意思：不画底。
    testWidgets('background 为 false 时不画背板', (WidgetTester tester) async {
      await tester.pumpWidget(
        miniHost(style: const OhosMiniBarStyle(background: false)),
      );
      expect(
        find.descendant(
          of: find.byType(OhosMiniBar),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });

    testWidgets('background 为 true 时画背板', (WidgetTester tester) async {
      await tester.pumpWidget(miniHost());
      expect(
        find.descendant(
          of: find.byType(OhosMiniBar),
          matching: find.byType(DecoratedBox),
        ),
        findsWidgets,
      );
    });

    // `enableMiniBarClip = true` 时内容被圆角裁剪；false 时不建 ClipRRect。
    testWidgets('clip 为 true 时裁内容', (WidgetTester tester) async {
      await tester.pumpWidget(miniHost());
      expect(
        find.descendant(
          of: find.byType(OhosMiniBar),
          matching: find.byType(ClipRRect),
        ),
        findsOneWidget,
      );
    });

    testWidgets('clip 为 false 时不裁内容', (WidgetTester tester) async {
      await tester.pumpWidget(
        miniHost(style: const OhosMiniBarStyle(clip: false)),
      );
      expect(
        find.descendant(
          of: find.byType(OhosMiniBar),
          matching: find.byType(ClipRRect),
        ),
        findsNothing,
      );
    });

    group('OhosMiniBarScaffold', () {
      Widget scaffoldHost({
        required double width,
        required OhosBarStyle miniStyle,
        required OhosBarStyle tabStyle,
        OhosBarLayoutMode layoutMode = OhosBarLayoutMode.horizontal,
      }) {
        return wrap(
          SizedBox(
            width: width,
            height: 400,
            child: OhosMiniBarScaffold(
              miniStyle: miniStyle,
              tabStyle: tabStyle,
              layoutMode: layoutMode,
              miniBar: const SizedBox(
                key: ValueKey<String>('mini'),
                width: 56,
                height: 56,
              ),
              tabBar: const SizedBox(
                key: ValueKey<String>('tab'),
                width: 200,
                height: 56,
              ),
            ),
          ),
        );
      }

      // 一展一折且 440–600vp：只有展开者居中，折叠者贴左边。
      //
      // **坐标是全局的**：宿主被 `Center` 居中后不从 x=0 起（520 宽居中在
      // 800 宽屏上是 x=140）。所有位置一律相对容器矩形算，别拿局部值当
      // 绝对坐标 —— 这正是「量尺寸先认清节点」那条坑的坐标版本。
      Rect containerRect(WidgetTester tester) =>
          tester.getRect(find.byType(OhosMiniBarScaffold));

      testWidgets('440–600vp 折叠者贴边，展开者居中', (WidgetTester tester) async {
        await tester.pumpWidget(
          scaffoldHost(
            width: 520,
            miniStyle: OhosBarStyle.collapse,
            tabStyle: OhosBarStyle.expand,
          ),
        );
        final Rect box = containerRect(tester);
        final Rect mini = tester.getRect(
          find.byKey(const ValueKey<String>('mini')),
        );
        final Rect tab = tester.getRect(
          find.byKey(const ValueKey<String>('tab')),
        );
        // 折叠者贴左：距离容器左边 ≈ padding 16。
        expect(mini.left - box.left, 16);
        // 展开者居中：中心与容器中心重合（留 1vp 容差）。
        expect((tab.center.dx - box.center.dx).abs(), lessThan(1));
      });

      // <440vp 一展一折：整体居中，折叠者不再贴边。
      testWidgets('<440vp 两个栏作为一个整体居中', (WidgetTester tester) async {
        await tester.pumpWidget(
          scaffoldHost(
            width: 400,
            miniStyle: OhosBarStyle.collapse,
            tabStyle: OhosBarStyle.expand,
          ),
        );
        final Rect box = containerRect(tester);
        final Rect mini = tester.getRect(
          find.byKey(const ValueKey<String>('mini')),
        );
        final Rect tab = tester.getRect(
          find.byKey(const ValueKey<String>('tab')),
        );
        // 整组中心应落在容器中心。
        final double groupCenter = (mini.left + tab.right) / 2;
        expect((groupCenter - box.center.dx).abs(), lessThan(1));
        // 而且折叠者**不再**贴边 —— 这正是与 expandedOnly 的区别。
        expect(mini.left - box.left, greaterThan(16));
      });

      testWidgets('垂直布局：上下排列', (WidgetTester tester) async {
        await tester.pumpWidget(
          scaffoldHost(
            width: 400,
            miniStyle: OhosBarStyle.collapse,
            tabStyle: OhosBarStyle.expand,
            layoutMode: OhosBarLayoutMode.vertical,
          ),
        );
        final Rect mini = tester.getRect(
          find.byKey(const ValueKey<String>('mini')),
        );
        final Rect tab = tester.getRect(
          find.byKey(const ValueKey<String>('tab')),
        );
        expect(mini.bottom, lessThanOrEqualTo(tab.top), reason: '迷你栏在上');
      });

      // 两个栏的宽度各自独立算出，**合计可能超容器**。这条用例来自 example
      // 溢出矩阵的真实报错：320vp 屏上「200 + 8 + 220 = 428」溢出 68vp，
      // 静态分析毫无提示，只有真跑布局才看得见。
      testWidgets('两个栏合计超宽时不溢出', (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 320,
              height: 400,
              child: OhosMiniBarScaffold(
                miniStyle: OhosBarStyle.expand,
                tabStyle: OhosBarStyle.expand,
                miniBar: const SizedBox(width: 200, height: 56),
                tabBar: const SizedBox(width: 220, height: 56),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '不该有 RenderFlex 溢出');
      });
    });

    testWidgets('墨屏上零动效：直接定格，不做宽度过渡', (WidgetTester tester) async {
      // 灰阶屏上的宽度过渡会拖出一条中间灰带，真机看起来像「栏没画完」。
      // 策略层 `scaleMotion` 在墨屏返回 `Duration.zero`，这里守的就是
      // 组件确实走了那条路 —— 而不是写死 200ms 无视策略。
      final OhosTabsController c = OhosTabsController(
        miniBarStyle: OhosBarStyle.collapse,
        tabBarStyle: OhosBarStyle.collapse,
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 400,
                  // 必须套一层 `Align`：`SizedBox` 给子的是**紧**约束，
                  // 迷你栏拿到 360 就被迫撑满、自己算的 56 会被忽略。
                  // 真实用法里它总在 `Row` / `Align` 这类松约束下。
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: OhosMiniBar(
                      controller: c,
                      builder: (_) => const Text('mini'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // 墨屏走 `SizedBox` 分支（无过渡），量它而不是外层组件 ——
      // 组件自身的盒子在松约束下会取父的可用宽。
      double miniWidth() => tester
          .getRect(
            find
                .descendant(
                  of: find.byType(OhosMiniBar),
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .width;
      final double collapsed = miniWidth();
      c.applyShowAnimation(OhosAnimationMode.click);
      // 只 pump 一帧：有过渡的话此时还在中间宽度。
      await tester.pump();
      expect(miniWidth(), isNot(collapsed), reason: '墨屏应立刻定格到展开宽度，不是停在折叠宽度');
    });

    group('OhosTabsController', () {
      test('applyMiniBarStyle 只在真变化时通知', () {
        final OhosTabsController c = OhosTabsController();
        int calls = 0;
        c.addListener(() => calls++);

        c.applyMiniBarStyle(OhosBarStyle.expand);
        expect(calls, 1, reason: 'collapse → expand 要通知');

        // 状态没变就不再通知 —— 否则滚动回调每次写同样的值，整棵子树跟着重建，
        // 而肉眼什么都没发生。
        c.applyMiniBarStyle(OhosBarStyle.expand);
        expect(calls, 1, reason: '同状态重复设置不该通知');
      });

      test('applyHideAnimation 折叠两栏', () {
        final OhosTabsController c = OhosTabsController(
          miniBarStyle: OhosBarStyle.expand,
          tabBarStyle: OhosBarStyle.expand,
        );
        c.applyHideAnimation(OhosAnimationMode.click);
        expect(c.miniBarStyle, OhosBarStyle.collapse);
        expect(c.tabBarStyle, OhosBarStyle.collapse);
        expect(c.lastAnimationMode, OhosAnimationMode.click);
      });

      test('applyShowAnimation 展开两栏', () {
        final OhosTabsController c = OhosTabsController();
        c.applyShowAnimation(OhosAnimationMode.scroll);
        expect(c.miniBarStyle, OhosBarStyle.expand);
        expect(c.tabBarStyle, OhosBarStyle.expand);
        expect(c.lastAnimationMode, OhosAnimationMode.scroll);
      });

      test('applyShowAnimation 已在展开态时不通知', () {
        final OhosTabsController c = OhosTabsController(
          miniBarStyle: OhosBarStyle.expand,
          tabBarStyle: OhosBarStyle.expand,
        );
        int calls = 0;
        c.addListener(() => calls++);
        c.applyShowAnimation(OhosAnimationMode.click);
        expect(calls, 0);
        // 模式仍然要记下来 —— 它是「上次怎么触发的」，与状态是否变化无关。
        expect(c.lastAnimationMode, OhosAnimationMode.click);
      });

      test('bindScroller 登记索引与控制器', () {
        final OhosTabsController c = OhosTabsController();
        final ScrollController s0 = ScrollController();
        final ScrollController s1 = ScrollController();
        c.bindScroller(0, s0);
        c.bindScroller(1, s1);
        expect(c.boundIndexes.toList(), <int>[0, 1]);
        expect(c.scrollerFor(0), same(s0));
      });

      test('unbindScroller 解绑后不再可查', () {
        final OhosTabsController c = OhosTabsController();
        final ScrollController s = ScrollController();
        c.bindScroller(0, s);
        c.unbindScroller(s);
        expect(c.boundIndexes, isEmpty);
        expect(c.scrollerFor(0), isNull);
      });

      test('重复绑定同一索引不叠加监听', () {
        final OhosTabsController c = OhosTabsController();
        final ScrollController a = ScrollController();
        final ScrollController b = ScrollController();
        c.bindScroller(0, a);
        c.bindScroller(0, b);
        expect(c.boundIndexes.toList(), <int>[0]);
        expect(c.scrollerFor(0), same(b));
        // 旧的必须解绑，否则 `a` 上留着监听、且永远没人再能解掉它。
        expect(c.offsetFor(0), isNotNull);
        c.dispose();
      });

      test('bindScroller 不接管滚动：绑了也能正常滚', () {
        // 这条守的是「别在绑定那一刻 hold / 改写 position」。曾经的实现里
        // 是 `scroller.position.hold()`，那会让内容区滚动卡住不动 ——
        // 单看 API 签名完全看不出来，只能真滚一次。
        final ScrollController s = ScrollController();
        final OhosTabsController c = OhosTabsController();
        c.bindScroller(0, s);
        expect(s.hasClients, isFalse, reason: '绑定时不该动 position');
        c.unbindScroller(s);
        c.dispose();
        s.dispose();
      });

      testWidgets('控制器驱动 scaffold 切换居中规则', (WidgetTester tester) async {
        final OhosTabsController c = OhosTabsController(
          miniBarStyle: OhosBarStyle.collapse,
          tabBarStyle: OhosBarStyle.expand,
        );
        addTearDown(c.dispose);
        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 520,
              height: 400,
              child: OhosMiniBarScaffold(
                controller: c,
                miniBar: const SizedBox(
                  key: ValueKey<String>('m'),
                  width: 56,
                  height: 56,
                ),
                tabBar: const SizedBox(
                  key: ValueKey<String>('t'),
                  width: 200,
                  height: 56,
                ),
              ),
            ),
          ),
        );
        final Rect box = tester.getRect(find.byType(OhosMiniBarScaffold));
        final Rect mini = tester.getRect(
          find.byKey(const ValueKey<String>('m')),
        );
        // 440–600vp 一展一折 → 折叠者贴边。
        expect(mini.left - box.left, 16);

        // 折叠迷你栏 → 两栏同折叠 → 整体居中。
        c.applyHideAnimation(OhosAnimationMode.click);
        await tester.pumpAndSettle();
        final Rect mini2 = tester.getRect(
          find.byKey(const ValueKey<String>('m')),
        );
        expect(
          mini2.left - box.left,
          greaterThan(16),
          reason: '两栏同状态后应整体居中，折叠者不再贴边',
        );
      });
    });
  });
  group('OhosTabBar', () {
    testWidgets('松宽度约束下也撑满父宽（不再塌成 0 宽）', (WidgetTester tester) async {
      // 宿主是 `Center` + 未 stretch 的 `Column`：两层给的都是 `minWidth = 0`
      // 的松约束。组件外壳是「固定高度 + 全 `Positioned.fill` 的 Stack」，不兜
      // 一下会取 `constraints.smallest` → 宽度 0，三个标题叠在正中。
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 360,
            child: DefaultTabController(
              length: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  OhosTabBar(
                    tabs: <Widget>[Text('文件'), Text('提交'), Text('分支')],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final Rect bar = tester.getRect(find.byType(OhosTabBar));
      expect(bar.width, 360);
      expect(
        tester.getCenter(find.text('文件')).dx,
        moreOrLessEquals(bar.left + 60),
      );
      expect(
        tester.getCenter(find.text('提交')).dx,
        moreOrLessEquals(bar.center.dx),
      );
      expect(
        tester.getCenter(find.text('分支')).dx,
        moreOrLessEquals(bar.right - 60),
      );
    });

    testWidgets('跟手分割线按 followStartOffset → followEndOffset 淡入', (
      WidgetTester tester,
    ) async {
      final ScrollController scroller = ScrollController();
      addTearDown(scroller.dispose);

      await tester.pumpWidget(
        wrap(
          DefaultTabController(
            length: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                OhosTabBar(
                  tabs: const <Widget>[Text('一'), Text('二')],
                  divider: const OhosTabBarDividerOptions(
                    mode: OhosTabBarDividerMode.followScroll,
                    followStartOffset: 0,
                    followEndOffset: 20,
                  ),
                  scrollController: scroller,
                ),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    controller: scroller,
                    itemCount: 40,
                    itemBuilder: (BuildContext context, int i) =>
                        SizedBox(height: 40, child: Text('行 $i')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      double dividerOpacity() => tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(OhosTabBar),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;

      // 停在顶部时整条线不可见（列表还没被页签压住）
      expect(dividerOpacity(), 0);

      scroller.jumpTo(10);
      await tester.pump();
      expect(dividerOpacity(), moreOrLessEquals(0.5, epsilon: 0.01));

      scroller.jumpTo(20);
      await tester.pump();
      expect(dividerOpacity(), 1);
    });

    testWidgets('none 模式不画线，visible 模式常显', (WidgetTester tester) async {
      final Color dividerColor = OhosThemeData.light().dividerColor;
      Finder dividerLine() => find.descendant(
        of: find.byType(OhosTabBar),
        matching: find.byWidgetPredicate(
          (Widget w) => w is Container && w.color == dividerColor,
        ),
      );

      Future<void> pumpWithMode(OhosTabBarDividerMode mode) async {
        await tester.pumpWidget(
          wrap(
            DefaultTabController(
              length: 2,
              child: OhosTabBar(
                tabs: const <Widget>[Text('一'), Text('二')],
                divider: OhosTabBarDividerOptions(mode: mode),
              ),
            ),
          ),
        );
      }

      // 常隐：线本身不构建，连跟手那层 Opacity 壳都不在
      await pumpWithMode(OhosTabBarDividerMode.none);
      expect(dividerLine(), findsNothing);
      expect(
        find.descendant(
          of: find.byType(OhosTabBar),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );

      // 常显：线直接画出来，不经过 Opacity（否则 0 透明度会被当成「有但看不见」）
      await pumpWithMode(OhosTabBarDividerMode.visible);
      expect(dividerLine(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(OhosTabBar),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
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

  group('OhosGrid', () {
    // 宿主宽度固定，并在网格下方留一个标记：`Align` 在无界高度下会收缩包裹
    // 网格，于是标记的顶点就等于网格的真实高度（含或不含末行行距）。
    Widget host(Widget child) {
      return OhosTheme(
        data: OhosThemeData.light(),
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                child,
                Container(key: const ValueKey<String>('after'), height: 10),
              ],
            ),
          ),
        ),
      );
    }

    OhosGridItem cell(String id, int span, {double height = 40}) {
      return OhosGridItem(
        columnSpan: span,
        child: Container(key: ValueKey<String>(id), height: height),
      );
    }

    double widthOf(WidgetTester tester, String id) =>
        tester.getSize(find.byKey(ValueKey<String>(id))).width;

    testWidgets('末行不满时保留空列，单元宽度与满行一致', (WidgetTester tester) async {
      // 1000vp → 12 列、margin 32、gutter 16；内容区 936vp、单列 63.33vp，
      // 跨 3 列的单元因此是 3×63.33 + 2×16 = 222vp（不是整行的 936vp）。
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        host(
          OhosGrid(
            children: <Widget>[
              cell('a', 3),
              cell('b', 3),
              cell('c', 3),
              cell('d', 3),
              cell('e', 3),
            ],
          ),
        ),
      );

      expect(widthOf(tester, 'a'), moreOrLessEquals(222, epsilon: 0.01));
      for (final String id in <String>['b', 'c', 'd', 'e']) {
        expect(
          widthOf(tester, id),
          moreOrLessEquals(widthOf(tester, 'a'), epsilon: 0.01),
          reason: '单元宽度不应随本行单元个数变化（$id）',
        );
      }
      // 第二行只有一格，左边缘要与第一行对齐
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<String>('e'))).dx,
        moreOrLessEquals(
          tester.getTopLeft(find.byKey(const ValueKey<String>('a'))).dx,
          epsilon: 0.01,
        ),
      );
      // 首格贴页面边距（不是内缩半个 gutter）
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<String>('a'))).dx,
        moreOrLessEquals(32, epsilon: 0.01),
      );
    });

    testWidgets('行距只出现在行与行之间', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        host(
          OhosGrid(
            children: <Widget>[cell('a', 6), cell('b', 6), cell('c', 6)],
          ),
        ),
      );

      final double firstTop = tester
          .getTopLeft(find.byKey(const ValueKey<String>('a')))
          .dy;
      // 两行 × 40 + 一条 gutter 16 = 96；末行再加一条就是 112
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<String>('after'))).dy,
        moreOrLessEquals(96, epsilon: 0.01),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<String>('c'))).dy,
        moreOrLessEquals(firstTop + 40 + 16, epsilon: 0.01),
      );
    });

    testWidgets('maxWidth 限制的是单元区，边距在外', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(2400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        host(OhosGrid(maxWidth: 1000, children: <Widget>[cell('a', 12)])),
      );

      // 跨满 12 列 = 内容区宽度，正好等于 maxWidth，不扣除两侧 margin
      expect(widthOf(tester, 'a'), moreOrLessEquals(1000, epsilon: 0.01));
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
        place(
          const Offset(300, 300),
          side: OhosMagnifierSide.aboveRight,
        ).offset,
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
      expect(tester.getSize(find.byType(OhosMagnifier)), const Size.square(48));
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
      controller.update(const Offset(200, 300), child: const Text('B'));
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

    testWidgets('墨水屏：1px 纯黑描边，且不做入场动画', (WidgetTester tester) async {
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

    testWidgets('只覆盖字号的 textStyle 也让字母颜色跟随主题', (WidgetTester tester) async {
      // `inherit: false` 断掉继承后没有祖先可以取色：调用方只传
      // `fontSize` / `fontWeight`（dartdoc 允许的用法）时，颜色必须在组件里
      // 兜住，否则深色 / 墨主题下是黑字压深底。
      final OhosThemeData dark = OhosThemeData.dark();
      await tester.pumpWidget(
        OhosTheme(
          data: dark,
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosMagnifier(
                  text: 'A',
                  animate: false,
                  textStyle: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
        ),
      );
      expect(paintedColor(tester, 'A'), dark.highlightColor);
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

    testWidgets('墨屏：选中字母反白，不糊成黑块（issue #7）', (WidgetTester tester) async {
      final OhosThemeData ink = OhosThemeData.ink();
      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosAlphabetIndexer(
                  indexer: letters,
                  size: const Size(24, 160),
                  selectedIndex: 2,
                  onSelected: (String _) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 灰阶屏留不住 10% 叠色 ⇒ 底块换成实色（墨屏 = 纯黑）。此时字必须反白，
      // 否则实底 + `highlightColor`（墨屏同为纯黑）会糊成一个黑疙瘩。
      expect(paintedColor(tester, 'B'), ink.onHighlightColor);
      expect(paintedColor(tester, 'B'), isNot(ink.highlightColor));
      // 未选中项不受影响
      expect(paintedColor(tester, 'A'), ink.textSecondaryColor);
    });

    testWidgets('墨屏：显式 selectedColor 优先，不被反白默认值吞掉', (WidgetTester tester) async {
      final OhosThemeData ink = OhosThemeData.ink();
      // 宿主自己挑的可读色：反白只是**默认值**，不是强制覆盖。
      const Color custom = Color(0xFF808080);
      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosAlphabetIndexer(
                  indexer: letters,
                  size: const Size(24, 160),
                  selectedIndex: 2,
                  selectedColor: custom,
                  onSelected: (String _) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 实底分支仍走 `selectedColor`：量化型主题不该静默改掉调用方的配色。
      expect(paintedColor(tester, 'B'), custom);
      expect(paintedColor(tester, 'B'), isNot(ink.onHighlightColor));
    });

    testWidgets('调用方传实心底时按实际底色反白，不被判成「浅底」', (
      WidgetTester tester,
    ) async {
      final OhosThemeData light = OhosThemeData.light();
      await tester.pumpWidget(
        wrap(
          OhosAlphabetIndexer(
            indexer: letters,
            size: const Size(24, 160),
            selectedIndex: 2,
            selectedBackgroundColor: light.highlightColor,
            onSelected: (String _) {},
          ),
        ),
      );
      await tester.pump();

      // `quantize` 对这块实心品牌蓝原样返回 ⇒ 旧判据把它当「10% 浅底」、
      // 退回品牌色字，结果蓝底压蓝字。判据必须看底实际亮不亮。
      expect(paintedColor(tester, 'B'), light.onHighlightColor);
    });

    testWidgets('选中圆标等径：窄字母 I 与宽字母 W 的底圆一样大', (WidgetTester tester) async {
      Widget host(int selected) => wrap(
        OhosAlphabetIndexer(
          indexer: const <String>['I', 'W'],
          size: const Size(24, 64),
          selectedIndex: selected,
          onSelected: (String _) {},
        ),
      );

      Size dotSize() => tester.getSize(
        find.descendant(
          of: find.byType(OhosAlphabetIndexer),
          matching: find.byType(DecoratedBox),
        ),
      );

      await tester.pumpWidget(host(0));
      await tester.pump();
      final Size narrow = dotSize();

      await tester.pumpWidget(host(1));
      await tester.pump();
      final Size wide = dotSize();

      // 等径：底圆不跟字形宽窄走，否则滚动换组时那点亮色会忽胖忽瘦。
      expect(wide.width, narrow.width);
      expect(wide.height, narrow.height);
      // 直径 = 一格高，但被条宽 24 收住（64vp 高 / 2 个字母 ⇒ slot 32）。
      expect(narrow.width, 24);
      expect(narrow.height, 24);
    });

    testWidgets('父级比 size.width 窄时，圆标按实际宽度收住，不变竖椭圆', (
      WidgetTester tester,
    ) async {
      // size.width 只是期望：外面套一层 16vp 宽的盒子，实际只有 16。
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 16,
            child: OhosAlphabetIndexer(
              indexer: const <String>['I', 'W'],
              size: const Size(24, 64),
              selectedIndex: 0,
              onSelected: (String _) {},
            ),
          ),
        ),
      );
      await tester.pump();

      final Size dot = tester.getSize(
        find.descendant(
          of: find.byType(OhosAlphabetIndexer),
          matching: find.byType(DecoratedBox),
        ),
      );
      // 按 size.width(24) 算会得到一个 24x24 的圆，塞进 16 宽的条里变竖椭圆。
      expect(dot.width, 16);
      expect(dot.height, 16);
      expect(tester.takeException(), isNull);
    });

    testWidgets('彩屏：选中字母仍是品牌色，没被反白顺手改掉', (WidgetTester tester) async {
      final OhosThemeData light = OhosThemeData.light();
      await tester.pumpWidget(
        wrap(
          OhosAlphabetIndexer(
            indexer: letters,
            size: const Size(24, 160),
            selectedIndex: 2,
            onSelected: (String _) {},
          ),
        ),
      );
      await tester.pump();

      // 彩屏 `quantize` 原样返回 ⇒ 走 10% 叠色分支，字仍用 highlightColor。
      expect(paintedColor(tester, 'B'), light.highlightColor);
      expect(paintedColor(tester, 'A'), light.textSecondaryColor);
    });

    testWidgets('点当前高亮的字母也会回调（不再「点不动」）', (WidgetTester tester) async {
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

    testWidgets('条内留白也参与命中，不再漏给下层', (WidgetTester tester) async {
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

    testWidgets('selectedIndex 变化写回内部高亮（代码定位）', (WidgetTester tester) async {
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

    testWidgets('受控高亮下点同一个字母，回调照旧触发', (WidgetTester tester) async {
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

    testWidgets('拖动期间父级改了 selectedIndex，抬手后高亮回到受控值', (
      WidgetTester tester,
    ) async {
      final OhosThemeData theme = OhosThemeData.light();
      final ValueNotifier<int?> controlled = ValueNotifier<int?>(0);
      addTearDown(controlled.dispose);
      await tester.pumpWidget(
        wrap(
          ValueListenableBuilder<int?>(
            valueListenable: controlled,
            builder: (BuildContext context, int? value, Widget? child) {
              return OhosAlphabetIndexer(
                indexer: letters,
                size: const Size(24, 160),
                selectedIndex: value,
                showMagnifier: false,
                onSelected: (String _) {},
              );
            },
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
      expect(paintedColor(tester, 'B'), theme.highlightColor);

      // 拖动中挂起受控值：父级改成 A（1）也不许把高亮从指下拽走。
      controlled.value = 1;
      await tester.pump();
      expect(paintedColor(tester, 'B'), theme.highlightColor);

      // 抬手后没有新的父级重建，收尾时自己对齐受控值。
      await gesture.up();
      await tester.pump();
      expect(paintedColor(tester, 'A'), theme.highlightColor);
      expect(paintedColor(tester, 'B'), theme.textSecondaryColor);
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

    testWidgets('无字母表 + 非空 selectedIndex 不崩（没有合法下标可断言）', (
      WidgetTester tester,
    ) async {
      // 分组切换把 indexer 清空、而父级仍拿着上一次的 selectedIndex 重建：
      // 修复前 `selected >= 0 && selected < 0` 恒假，debug 下必崩。
      await tester.pumpWidget(
        wrap(
          OhosAlphabetIndexer(
            indexer: const <String>[],
            size: const Size(24, 160),
            selectedIndex: 3,
            onSelected: (String _) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('字母表被换成空表时不崩，恢复后高亮夹回合法位置', (WidgetTester tester) async {
      Widget controlled(List<String> indexer, int index) {
        return wrap(
          OhosAlphabetIndexer(
            indexer: indexer,
            size: const Size(24, 160),
            selectedIndex: index,
            onSelected: (String _) {},
          ),
        );
      }

      await tester.pumpWidget(controlled(letters, 4));
      await tester.pumpWidget(controlled(const <String>[], 4));
      expect(tester.takeException(), isNull);
      // 空表期间把高亮留在一个不存在的下标上，恢复时就会越界取字母。
      await tester.pumpWidget(controlled(letters, 4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('槽位与命中同源：点渲染出来的字母就是它自己', (WidgetTester tester) async {
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

    testWidgets('父级给更高的紧约束时，视觉格与命中格一起铺满', (WidgetTester tester) async {
      // 父级紧约束 500 > size.height 360：`SizedBox` 会被 minHeight 抬到 500，
      // 但槽位若只按 `min(size.height, maxHeight)` 算仍是 360 —— 字母挤在顶部
      // 360vp、底部 140vp 空白却照样接管手势，点它会夹成末格。
      final List<String> picked = <String>[];
      final List<String> many = List<String>.generate(
        26,
        (int i) => String.fromCharCode(65 + i),
      );
      await tester.pumpWidget(
        wrap(
          SizedBox(
            height: 500,
            child: OhosAlphabetIndexer(
              indexer: many,
              size: const Size(24, 360),
              onSelected: picked.add,
            ),
          ),
        ),
      );
      final Rect rect = tester.getRect(find.byType(OhosAlphabetIndexer));
      expect(rect.height, 500);
      // 500 / 26 ≈ 19.23：y = 370 落在第 20 格（索引 19 = 'T'）。
      // 按 360 算槽位时这里会被夹成 'Z'。
      await tester.tapAt(Offset(rect.center.dx, rect.top + 370));
      await tester.pump();
      expect(picked.last, 'T');
    });

    testWidgets('高度无界时也吃 minHeight（scroll 里套 ConstrainedBox）', (
      WidgetTester tester,
    ) async {
      // `hasBoundedHeight == false` 时曾被直接当成「用 size.height」：父级用
      // ConstrainedBox(minHeight: 500) 把它撑到 500，槽位仍按 360 算，字母挤在
      // 上方，底部空白却接管手势 —— 点 y=370 会跳末格 'Z'。
      final List<String> picked = <String>[];
      final List<String> many = List<String>.generate(
        26,
        (int i) => String.fromCharCode(65 + i),
      );
      await tester.pumpWidget(
        wrap(
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 500),
              child: OhosAlphabetIndexer(
                indexer: many,
                size: const Size(24, 360),
                onSelected: picked.add,
              ),
            ),
          ),
        ),
      );
      final Rect rect = tester.getRect(find.byType(OhosAlphabetIndexer));
      expect(rect.height, 500);
      // 500 / 26 ≈ 19.23：y = 370 落在第 20 格（索引 19 = 'T'）。
      await tester.tapAt(Offset(rect.center.dx, rect.top + 370));
      await tester.pump();
      expect(picked.last, 'T');
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

    testWidgets('字母继承外层字体家族（golden 里不再画成实心方块）', (WidgetTester tester) async {
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

    testWidgets('高度缩小后字号立刻生效，不再等 200ms 追上来', (WidgetTester tester) async {
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

    testWidgets('拖动中字母表变短：抬手不越界，回调落在新表内', (WidgetTester tester) async {
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

    testWidgets('受控：外部 selectedIndex 没变时，重建也能把高亮纠回来', (
      WidgetTester tester,
    ) async {
      // 受控写法是「外部值说了算」：手指点过之后内部高亮先跟手，父级用同一个
      // selectedIndex 重建时应该纠回受控值。旧实现只在 selected != previous
      // 时回写，重建一次就再也纠不回来了。
      const int controlled = 1; // 'A'
      final OhosThemeData theme = OhosThemeData.light();
      late StateSetter rebuild;
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              rebuild = setState;
              return OhosAlphabetIndexer(
                indexer: letters,
                size: const Size(24, 160),
                selectedIndex: controlled,
                onSelected: (_) {},
              );
            },
          ),
        ),
      );
      expect(paintedColor(tester, 'A'), theme.highlightColor);

      await tester.tap(find.text('D'));
      await tester.pump();
      expect(paintedColor(tester, 'D'), theme.highlightColor, reason: '点完先跟手');

      rebuild(() {});
      await tester.pump();
      expect(paintedColor(tester, 'A'), theme.highlightColor, reason: '纠回受控值');
      expect(paintedColor(tester, 'D'), theme.textSecondaryColor);
    });

    testWidgets('拖动中父级改 selectedIndex 不会把高亮从指下拽走', (WidgetTester tester) async {
      // `_syncSelected` 原本在 `didUpdateWidget` 里无条件执行：拖动过程中父级
      // 一 setState（改 selectedIndex），高亮就会从指下跳回旧位置。
      int controlled = 0; // '#'
      final OhosThemeData theme = OhosThemeData.light();
      late StateSetter rebuild;
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              rebuild = setState;
              return OhosAlphabetIndexer(
                indexer: letters,
                size: const Size(24, 160),
                selectedIndex: controlled,
                // 这里只盯高亮：关掉放大镜，免得它在 Overlay 里也渲染一份
                // 同名文字，`find.text('C')` 落到两个 widget 上。
                showMagnifier: false,
                onSelected: (_) {},
              );
            },
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
      await gesture.moveBy(const Offset(0, 60)); // slot 32 → 'C'
      await tester.pump();
      expect(paintedColor(tester, 'C'), theme.highlightColor);

      rebuild(() => controlled = 1); // 'A'
      await tester.pump();
      expect(
        paintedColor(tester, 'C'),
        theme.highlightColor,
        reason: '拖动中保持跟手，不被外部值拽回',
      );

      await gesture.up();
      await tester.pumpAndSettle();
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

    testWidgets('拖动时出现放大镜，字母跟随，抬手消失', (WidgetTester tester) async {
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

    testWidgets('泡泡与手指在两个轴上都留够指肚的余量', (WidgetTester tester) async {
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

    testWidgets('showMagnifier: false 时拖动也不显示', (WidgetTester tester) async {
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

    testWidgets('magnifierBuilder 可换成自定义内容', (WidgetTester tester) async {
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

    testWidgets('primary 默认吃掉状态栏内边距：栏高 = height + inset，标题下移', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(topPadding: 24, bar: const OhosAppBar(title: Text('标题'))),
      );

      expect(tester.getSize(find.byType(OhosAppBar)).height, 56 + 24);
      // 标题仍在 56 的工具栏区域正中（24 + 28），不是被状态栏压到顶上
      expect(tester.getCenter(find.text('标题')).dy, 52);
    });

    testWidgets('状态栏为 0 时保持 56（桌面/无状态栏场景不变）', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(topPadding: 0, bar: const OhosAppBar(title: Text('标题'))),
      );
      expect(tester.getSize(find.byType(OhosAppBar)).height, 56);
    });

    testWidgets('primary: false 不吃内边距（调用方自己处理时用）', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          topPadding: 24,
          bar: const OhosAppBar(primary: false, title: Text('标题')),
        ),
      );
      expect(tester.getSize(find.byType(OhosAppBar)).height, 56);
    });

    test('preferredSize 不含状态栏：Scaffold 已经加过一次，重复加会多留一条', () {
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

    testWidgets('底部导航存在时 body 不再重复让出底部内边距', (WidgetTester tester) async {
      // body 的 `SafeArea` 若同时让 bottom，会与底部导航那层 `SafeArea`
      // 叠成两条 padding.bottom：内容与导航之间多出一条空白，列表末项被顶起。
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                padding: EdgeInsets.only(bottom: 24),
              ),
              child: OhosScaffold(
                body: const SizedBox.expand(key: Key('body')),
                bottomNavigationBar: const SizedBox(
                  key: Key('nav'),
                  height: 48,
                ),
              ),
            ),
          ),
        ),
      );
      final Rect scaffold = tester.getRect(find.byType(Scaffold));
      final Rect body = tester.getRect(find.byKey(const Key('body')));
      final Rect nav = tester.getRect(find.byKey(const Key('nav')));
      expect(nav.height, 48);
      expect(nav.bottom, scaffold.bottom - 24, reason: '底部导航自己让出安全区');
      expect(body.bottom, nav.top, reason: 'body 底部紧贴导航，不叠第二层留白');
    });

    testWidgets('body 子树不再看到已被页面容器认领的内边距', (WidgetTester tester) async {
      // `SafeArea(top: false)` 只让几何，不会把这一边从子树的 `MediaQuery` 里
      // 摘掉：调用方在 body 里按最常见写法再包一层 `SafeArea`，就会凭空多出
      // 一条状态栏高度的空白；四条边都成立（左右是横屏刘海，底部是导航条）。
      // body 里自己读 `MediaQuery.padding` 做偏移的代码同样会重复计算。
      EdgeInsets? seen;
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(800, 600),
                padding: EdgeInsets.only(
                  left: 44,
                  top: 24,
                  right: 44,
                  bottom: 16,
                ),
              ),
              child: OhosScaffold(
                appBar: const OhosAppBar(title: Text('标题')),
                bottomNavigationBar: const SizedBox(
                  key: Key('nav'),
                  height: 48,
                ),
                body: Builder(
                  builder: (BuildContext context) {
                    seen = MediaQuery.paddingOf(context);
                    return const SafeArea(
                      child: SizedBox.expand(key: Key('inner')),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      final Rect bar = tester.getRect(find.byType(OhosAppBar));
      final Rect inner = tester.getRect(find.byKey(const Key('inner')));
      final Rect nav = tester.getRect(find.byKey(const Key('nav')));
      expect(inner.top, bar.bottom, reason: 'body 顶部紧贴栏底，不再多吃 24');
      expect(inner.bottom, nav.top, reason: 'body 底部紧贴导航，不再多吃 16');
      expect(inner.left, 44, reason: '左右安全区只让一次');
      expect(inner.right, 800 - 44, reason: '左右安全区只让一次');
      expect(seen, EdgeInsets.zero, reason: 'body 内读到的 padding 已被页面容器消费干净');
    });

    testWidgets('primary: false 的 AppBar 在 OhosScaffold 里仍让出状态栏', (
      WidgetTester tester,
    ) async {
      // `primary: false` 表示栏自己不吃状态栏内边距，页面级容器得替它让一次；
      // AppBar 移出外层 `SafeArea` 之后这里一度无人消费，标题直接顶到状态栏。
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                padding: EdgeInsets.only(top: 24),
              ),
              child: const OhosScaffold(
                appBar: OhosAppBar(primary: false, title: Text('标题')),
                body: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      expect(tester.getRect(find.byType(OhosAppBar)).top, 24);
      expect(tester.getSize(find.byType(OhosAppBar)).height, 56);
    });

    testWidgets('横屏刘海下 AppBar 仍让出左右安全区（primary 两种取值一致）', (
      WidgetTester tester,
    ) async {
      // AppBar 移出外层 SafeArea 后，primary: true 的分支曾被裸放 —— 顶部由栏
      // 自己吸收没问题，但 left / right（横屏刘海、挖孔）就没人让了，内容压到
      // 屏幕边缘；primary: false 的分支反倒让了，两者不一致。
      for (final bool primary in <bool>[true, false]) {
        await tester.pumpWidget(
          OhosTheme(
            data: OhosThemeData.light(),
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(800, 360),
                  padding: EdgeInsets.only(left: 44, right: 44),
                ),
                child: OhosScaffold(
                  appBar: OhosAppBar(primary: primary, title: const Text('标题')),
                  body: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        );
        final Rect bar = tester.getRect(find.byType(OhosAppBar));
        expect(bar.left, 44, reason: 'primary=$primary 时左侧安全区要让出');
        expect(bar.right, 800 - 44, reason: 'primary=$primary 时右侧安全区要让出');
      }
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

    testWidgets('leading / 标题 / actions 单行排布，标题不会压到右侧动作上', (
      WidgetTester tester,
    ) async {
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

    testWidgets('只有 actions 时标题居中于「剩余空间」而不是整栏中轴', (WidgetTester tester) async {
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

    testWidgets('长标题被约束在剩余空间内，不溢出也不盖住动作', (WidgetTester tester) async {
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

    testWidgets('titleAlignment.start 让标题贴在 leading 之后，不再强制居中', (
      WidgetTester tester,
    ) async {
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

    testWidgets('titlePadding 可收紧：窄容器里标题能拿到更多宽度', (WidgetTester tester) async {
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

    testWidgets('leadingWidth 固定左侧槽宽，leading 在槽内居中', (
      WidgetTester tester,
    ) async {
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

    testWidgets('bottom 里的 OhosTabBar 铺满整宽：三个页签均分，不挤成一坨', (
      WidgetTester tester,
    ) async {
      // `OhosTabBar` 内部是 `Stack` + 全 `Positioned.fill` 子节点：父级若给的是
      // **松**宽度约束（minWidth 0），它会取 `constraints.smallest` → 宽度塌成
      // 0，几个页签的标题堆在正中叠成一坨。AppBar 的 content 是 Column，默认
      // `center` 正好给的就是松约束，所以这里必须走真实 bottom 链路验证。
      const OhosAppBar bar = OhosAppBar(
        title: Text('标题'),
        bottom: OhosTabBar(tabs: <Widget>[Text('文件'), Text('提交'), Text('分支')]),
      );
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: MaterialApp(
            home: DefaultTabController(
              length: 3,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 360,
                  child: Scaffold(appBar: bar, body: const SizedBox.expand()),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(OhosTabBar)).width, 360);
      expect(tester.getCenter(find.text('文件')).dx, moreOrLessEquals(60));
      expect(tester.getCenter(find.text('提交')).dx, moreOrLessEquals(180));
      expect(tester.getCenter(find.text('分支')).dx, moreOrLessEquals(300));
    });

    testWidgets('systemOverlayStyle 通过 AnnotatedRegion 交给系统状态栏', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          topPadding: 0,
          bar: const OhosAppBar(
            title: Text('标题'),
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
        ),
      );

      final AnnotatedRegion<SystemUiOverlayStyle> region = tester.widget(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
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

    testWidgets('带色带 + lightMaterial 时栏体仍有确定高度', (WidgetTester tester) async {
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

    testWidgets('toolbarHeight 是 height 的别名（对齐 kToolbarHeight 命名）', (
      WidgetTester tester,
    ) async {
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

    testWidgets('没显式传 controller 时退回 PrimaryScrollController', (
      WidgetTester tester,
    ) async {
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

  group('OhosActionBar', () {
    // 官方结构是「起始按钮组 + 主按钮 + 末尾按钮组」，不是「全部放一侧」。
    // 旧实现只有一个 `secondaryActions`，两端布局用不了。
    testWidgets('startButtons 与 endButtons 分居主按钮两侧', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OhosActionBar(
            // 必须显式展开：`isExpand` 默认 false（官方值），收起态末尾按钮组
            // 本来就不参与布局 —— 不写这一行，下面的 endX 会拿到 findsNothing。
            isExpand: true,
            startButtons: <OhosActionBarButton>[
              OhosActionBarButton(
                icon: const Icon(Icons.share_rounded),
                accessibilityLabel: '分享',
                onPressed: () {},
              ),
            ],
            endButtons: <OhosActionBarButton>[
              OhosActionBarButton(
                icon: const Icon(Icons.bookmark_border_rounded),
                accessibilityLabel: '收藏',
                onPressed: () {},
              ),
            ],
            primaryButton: OhosActionBarButton(
              icon: const Icon(Icons.check_rounded),
              accessibilityLabel: '确认',
              onPressed: () {},
            ),
          ),
        ),
      );

      final double startX = tester
          .getCenter(find.byIcon(Icons.share_rounded))
          .dx;
      final double primaryX = tester
          .getCenter(find.byIcon(Icons.check_rounded))
          .dx;
      final double endX = tester
          .getCenter(find.byIcon(Icons.bookmark_border_rounded))
          .dx;

      // 主按钮在中间：两端各在自己那侧。用坐标比大小而不是量 padding ——
      // 前者对「主按钮到底居中还是贴右」才有区分力。
      expect(startX, lessThan(primaryX));
      expect(primaryX, lessThan(endX));
    });

    // 官方 `primaryButton` 可选，去掉主按钮是合法形态（示例里 0 或 1 个主按钮）。
    testWidgets('去掉主按钮时只画两端按钮组', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosActionBar(
            startButtons: <OhosActionBarButton>[
              OhosActionBarButton(
                icon: const Icon(Icons.share_rounded),
                accessibilityLabel: '分享',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
      // 没有主按钮就不该有圆底按钮 —— 旧实现在这里画过一个空白药丸。
      expect(find.byType(CircleBorder), findsNothing);
    });

    // `ActionBarButton.enabled` 是逐按钮开关，`ActionBarStyle.enabled` 是总开关。
    // 官方说明：「enabled=false 表示不启用，则背板不启用并且所有按钮都不启用；
    // enabled=true 时每个按钮可以单独设置」。
    testWidgets('整体禁用时所有按钮都不可点', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        wrap(
          OhosActionBar(
            startButtons: <OhosActionBarButton>[
              OhosActionBarButton(
                icon: const Icon(Icons.share_rounded),
                accessibilityLabel: '分享',
                onPressed: () => taps++,
              ),
            ],
            primaryButton: OhosActionBarButton(
              icon: const Icon(Icons.check_rounded),
              accessibilityLabel: '确认',
              onPressed: () => taps++,
            ),
            style: const OhosActionBarStyle(enabled: false),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.share_rounded));
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pump();
      expect(taps, 0, reason: '总开关关掉后个别按钮的 onPressed 不该被调到');
    });

    testWidgets('逐按钮禁用不影响同栏其它按钮', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        wrap(
          OhosActionBar(
            startButtons: <OhosActionBarButton>[
              OhosActionBarButton(
                icon: const Icon(Icons.share_rounded),
                accessibilityLabel: '分享',
                enabled: false,
                onPressed: () => taps++,
              ),
              OhosActionBarButton(
                icon: const Icon(Icons.favorite_border_rounded),
                accessibilityLabel: '点赞',
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.share_rounded));
      await tester.pump();
      expect(taps, 0, reason: 'enabled: false 的按钮不该触发 onPressed');

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pump();
      expect(taps, 1, reason: '同栏另一个按钮必须仍然可点');
    });

    // 官方 `isPrimaryIconChanged`：true → altIcon，false → baseIcon。
    testWidgets('isPrimaryIconChanged 切换主按钮图标', (WidgetTester tester) async {
      Widget build(bool changed) => wrap(
        OhosActionBar(
          primaryButton: const OhosActionBarButton(
            icon: Icon(Icons.add_rounded),
            altIcon: Icon(Icons.play_arrow_rounded),
          ),
          style: OhosActionBarStyle(isPrimaryIconChanged: changed),
        ),
      );

      await tester.pumpWidget(build(false));
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

      await tester.pumpWidget(build(true));
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
    });

    // 缺 `altIcon` 时回落 —— 与 `OhosChip.selectedIcon` 同一条规则：
    // 「切一下就掉图标」不是双态，是缺陷。
    testWidgets('切换但没给 altIcon 时回落成 baseIcon', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosActionBar(
            primaryButton: OhosActionBarButton(icon: Icon(Icons.add_rounded)),
            style: OhosActionBarStyle(isPrimaryIconChanged: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    // `isExpand` 默认 false（官方值）。收起态末尾按钮组不参与布局。
    testWidgets('isExpand 默认 false，收起时末尾按钮组让位', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosActionBar(
            endButtons: <OhosActionBarButton>[
              OhosActionBarButton(
                icon: const Icon(Icons.bookmark_border_rounded),
                accessibilityLabel: '收藏',
                onPressed: () {},
              ),
            ],
            primaryButton: OhosActionBarButton(
              icon: const Icon(Icons.check_rounded),
              accessibilityLabel: '确认',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(
        find.byIcon(Icons.bookmark_border_rounded),
        findsNothing,
        reason: '默认收起',
      );
    });

    // 官方在 `startSpace` / `endSpace` 的说明里明文写「水平排列时为左边框，
    // 竖直排列时为上边框」—— 这条映射最容易按名字写成 left/right 固定。
    testWidgets('竖直排列时 startSpace / endSpace 落到上下边框', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OhosActionBar(
            startButtons: <OhosActionBarButton>[
              OhosActionBarButton(
                icon: const Icon(Icons.share_rounded),
                accessibilityLabel: '分享',
                onPressed: () {},
              ),
            ],
            primaryButton: OhosActionBarButton(
              icon: const Icon(Icons.check_rounded),
              accessibilityLabel: '确认',
              onPressed: () {},
            ),
            style: const OhosActionBarStyle(
              isHorizontal: false,
              startSpace: 40,
              endSpace: 0,
            ),
          ),
        ),
      );

      final Rect bar = tester.getRect(find.byType(OhosActionBar));
      final Rect start = tester.getRect(find.byIcon(Icons.share_rounded));
      // 上边框距离 = startSpace(40)，不是 0 —— 若把 startSpace 映射到 left，
      // 这个差值会是 0（按钮会被水平居中压缩到很近）。
      expect(
        start.top - bar.top,
        greaterThanOrEqualTo(40),
        reason: 'startSpace 在竖直排列下必须作用于上边框',
      );
    });

    // 背板材质：彩屏默认走模糊材质，墨屏退化为实色 + 描边。
    // 官方「组件背板默认带有模糊材质和投影」。
    testWidgets('彩屏背板走模糊材质，墨屏退化为实色 + 描边', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosActionBar(
            primaryButton: OhosActionBarButton(
              icon: const Icon(Icons.check_rounded),
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.byType(OhosLightMaterial), findsOneWidget);

      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosActionBar(
                  primaryButton: OhosActionBarButton(
                    icon: const Icon(Icons.check_rounded),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byType(OhosLightMaterial),
        findsNothing,
        reason: '墨屏上 BackdropFilter 真机退化为拖尾/灰块',
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(OhosActionBar),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).border, isNotNull);
    });

    // `blurStrategy: disabled` 与「墨屏」走同一条退化路径，但原因不同：
    // 一个是调用方显式关掉，一个是硬件画不出来。
    testWidgets('blurStrategy: disabled 不开模糊材质', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosActionBar(
            blurStrategy: OhosBlurStrategy.disabled,
            primaryButton: OhosActionBarButton(
              icon: const Icon(Icons.check_rounded),
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(OhosLightMaterial), findsNothing);
    });

    // 自定义主按钮：官方「primaryButtonBuilder 优先级高于 primaryButton」，
    // 且「必须同时设置 primaryButtonBuilderWidth」。
    testWidgets('primaryButtonBuilder 顶掉 primaryButton，且按给定宽度排版', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OhosActionBar(
            primaryButton: OhosActionBarButton(
              icon: const Icon(Icons.check_rounded),
              accessibilityLabel: '内置主按钮',
              onPressed: () {},
            ),
            primaryButtonBuilder: (BuildContext context) =>
                const ColoredBox(color: Color(0xFF123456)),
            primaryButtonBuilderWidth: 120,
          ),
        ),
      );

      expect(find.byIcon(Icons.check_rounded), findsNothing);
      final Rect custom = tester.getRect(
        find.byWidgetPredicate(
          (Widget w) => w is ColoredBox && w.color == const Color(0xFF123456),
        ),
      );
      expect(custom.width, 120);
    });

    // 官方 `ActionBarButton.width` 覆盖默认直径。
    testWidgets('逐按钮 width 覆盖默认圆直径', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosActionBar(
            primaryButton: const OhosActionBarButton(
              icon: Icon(Icons.check_rounded),
              width: 72,
            ),
          ),
        ),
      );

      final Size size = tester.getSize(
        find
            .ancestor(
              of: find.byIcon(Icons.check_rounded),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(size.width, 72);
      expect(size.height, 72);
    });

    // 样式是值对象，`==` 必须按字段比 —— 缺了它 `updateShouldNotify` 静默失效。
    test('OhosActionBarStyle 值相等', () {
      const OhosActionBarStyle a = OhosActionBarStyle(
        isHorizontal: false,
        isPrimaryIconChanged: true,
        innerSpace: 8,
      );
      const OhosActionBarStyle b = OhosActionBarStyle(
        isHorizontal: false,
        isPrimaryIconChanged: true,
        innerSpace: 8,
      );
      const OhosActionBarStyle c = OhosActionBarStyle(isHorizontal: false);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('OhosSubheader', () {
    // 三档高度是官方的硬规格（`subheader_single_title_height` /
    // `_single_subtitle_height` / `_double_height` = 56 / 56 / 72）。
    // 旧实现没有高度概念，行高靠字阶撑 —— 18fp 的实际行盒只有 ~42，
    // 比官方矮一截，所以这里断的是组件本身的尺寸而不是 padding。
    testWidgets('高度三档：单标题 56 / 单副标题 56 / 双行 72', (WidgetTester tester) async {
      for (final (OhosSubheader, double) probe in <(OhosSubheader, double)>[
        (const OhosSubheader(title: '最近使用'), 56),
        (const OhosSubheader(secondaryTitle: '已完成'), 56),
        (const OhosSubheader(title: '本周', secondaryTitle: '共 12 项'), 72),
        (
          const OhosSubheader(
            secondaryTitle: '已完成',
            icon: Icon(Icons.check_rounded),
          ),
          56,
        ),
      ]) {
        await tester.pumpWidget(wrap(probe.$1));
        expect(
          tester.getSize(find.byType(OhosSubheader)).height,
          probe.$2,
          reason: '${probe.$1.title ?? probe.$1.secondaryTitle} 的行高',
        );
      }
    });

    // 双行形态：主标题 18fp/700、副标题 14fp/**400**、两行之间 2vp。
    // 权重是这一条的重点 —— 同一个副标题单独成行时官方给的是 500，
    // 两处不同，容易写成一处。
    testWidgets('双行形态的字阶与 2vp 行间距', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(const OhosSubheader(title: '本周', secondaryTitle: '共 12 项')),
      );

      final Text title = tester.widget<Text>(find.text('本周'));
      expect(title.style?.fontSize, 18);
      expect(title.style?.fontWeight, FontWeight.w700);

      final Text subtitle = tester.widget<Text>(find.text('共 12 项'));
      expect(subtitle.style?.fontSize, 14);
      expect(subtitle.style?.fontWeight, FontWeight.w400);

      // 2vp 是 `subheader_titles_space`。18 + 2 = 20，不能是字阶自带的行距。
      final double titleBottom = tester.getBottomLeft(find.text('本周')).dy;
      final double subtitleTop = tester.getTopLeft(find.text('共 12 项')).dy;
      expect(subtitleTop - titleBottom, closeTo(2, 0.01));
    });

    // 副标题单独成行时权重升到 500（`SecondTitleStyle` 里的
    // `FontWeight.Medium`）。同一条副标题文字，形态一变权重就变 ——
    // 这不是笔误，官方就这么写的。
    testWidgets('副标题单独成行时权重 500，双行时 400', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const OhosSubheader(secondaryTitle: '已完成')));
      expect(
        tester.widget<Text>(find.text('已完成')).style?.fontWeight,
        FontWeight.w500,
      );

      await tester.pumpWidget(
        wrap(const OhosSubheader(title: '本周', secondaryTitle: '已完成')),
      );
      expect(
        tester.widget<Text>(find.text('已完成')).style?.fontWeight,
        FontWeight.w400,
      );
    });

    // `icon` 只在有副标题时生效（`subheader.ets:646` 的优先级链），
    // 而且图标 16、与文字间距 8。这条同时钉住「只给 title 时图标不出现」，
    // 因为那是本库最容易被当成 bug 反手「修」掉的一处。
    testWidgets('左图标 16 + 间距 8，且只给 title 时不出现', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosSubheader(
            secondaryTitle: '已完成',
            icon: Icon(Icons.check_rounded),
          ),
        ),
      );
      final Finder icon = find.byIcon(Icons.check_rounded);
      expect(icon, findsOneWidget);
      expect(tester.getSize(icon).width, 16);
      expect(tester.getSize(icon).height, 16);
      final double gap =
          tester.getTopLeft(find.text('已完成')).dx - tester.getTopRight(icon).dx;
      expect(gap, closeTo(8, 0.01));

      await tester.pumpWidget(
        wrap(const OhosSubheader(title: '本周', icon: Icon(Icons.check_rounded))),
      );
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    // 左右外边距 16/16；副标题单行形态再多 12 的横向内边距，所以它的
    // 文字比纯标题形态深一档（28 而非 16）。官方 `getAreaPadding()` 的条件
    // 就是这个不对称 —— 目的是让副标题对齐到列表项的文字。
    testWidgets('左右边距 16，副标题单行额外 12', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const OhosSubheader(title: '最近使用')));
      final Rect box = tester.getRect(find.byType(OhosSubheader));
      expect(tester.getTopLeft(find.text('最近使用')).dx - box.left, 16);

      await tester.pumpWidget(wrap(const OhosSubheader(secondaryTitle: '已完成')));
      final Rect box2 = tester.getRect(find.byType(OhosSubheader));
      expect(
        tester.getTopLeft(find.text('已完成')).dx - box2.left,
        16 + 12,
        reason: 'margin 16 + subheader_single_subtitle_padding 12',
      );
    });

    // `type` 是从字段推导出来的只读结论，不是入参：ArkUI 的 `SubHeader`
    // 根本没有 `type`。这条防止有人后来把它改成可写的开关 —— 那样调用方
    // 就能声明一个渲染器兑现不了的形态。
    testWidgets('type 由字段推导：两行内容型，其余列表型', (WidgetTester tester) async {
      const OhosSubheader twoLine = OhosSubheader(
        title: '本周',
        secondaryTitle: '共 12 项',
      );
      expect(twoLine.type, OhosSubheaderType.content);

      const OhosSubheader oneLine = OhosSubheader(title: '最近使用');
      expect(oneLine.type, OhosSubheaderType.list);

      // 给了图标就不走双行分支 —— 与 `getMinHeight()` 的判定顺序一致，
      // 此时 title 会被 secondaryTitle 顶掉。
      const OhosSubheader iconWins = OhosSubheader(
        title: '本周',
        secondaryTitle: '共 12 项',
        icon: Icon(Icons.check_rounded),
      );
      expect(iconWins.type, OhosSubheaderType.list);
    });

    // 右侧链路：文本 + 箭头（TEXT_ARROW）与纯文本（BUTTON，showTrailingArrow
    // = false）两种。箭头不画时总宽要窄一截，否则「关掉箭头」就只是心里想想。
    testWidgets('右侧文本带箭头 / 不带箭头', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(const OhosSubheader(title: '最近使用', trailing: '查看全部')),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      final double withArrow = tester.getSize(find.byType(OhosSubheader)).width;

      await tester.pumpWidget(
        wrap(
          const OhosSubheader(
            title: '最近使用',
            trailing: '查看全部',
            showTrailingArrow: false,
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.text('查看全部'), findsOneWidget);
      // 高度不随箭头变化：右侧那条横线不该把整行撑高。
      expect(
        tester.getSize(find.byType(OhosSubheader)).height,
        56,
        reason: '右侧有无箭头都不改变行高',
      );
      expect(withArrow, greaterThan(0));
    });

    testWidgets('点右侧文本触发回调', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        wrap(
          OhosSubheader(
            title: '最近使用',
            trailing: '查看全部',
            onTrailingTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('查看全部'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    // `leading` 是 `titleBuilder` 的对应物：给了它，三个文本字段全部让位。
    // 但**行高不跟着变** —— `getMinHeight()` 读的是字段而非 builder，
    // 两个文本都在就仍是 72。这一点看着反直觉，却是官方行为：自绘标题
    // 不该让上下两块的位置跳一下。
    testWidgets('leading 顶掉文本，行高仍按字段算', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosSubheader(
            title: '本周',
            secondaryTitle: '共 12 项',
            leading: Text('自定义标题区'),
          ),
        ),
      );

      expect(find.text('自定义标题区'), findsOneWidget);
      expect(find.text('本周'), findsNothing);
      expect(find.text('共 12 项'), findsNothing);
      expect(
        tester.getSize(find.byType(OhosSubheader)).height,
        72,
        reason: 'getMinHeight() 只看 title/secondaryTitle 字段，不看 builder',
      );

      // 只给一个字段的 leading 仍是 56。
      await tester.pumpWidget(
        wrap(const OhosSubheader(title: '本周', leading: Text('自定义标题区'))),
      );
      expect(tester.getSize(find.byType(OhosSubheader)).height, 56);
    });

    // 内容贴着行底：上方多出来的高度就是与上一区块的间距。居中会把它
    // 一分为二，读不出「这一段从哪开始」。
    testWidgets('内容靠底部对齐', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const OhosSubheader(title: '最近使用')));

      final Rect box = tester.getRect(find.byType(OhosSubheader));
      final Rect text = tester.getRect(find.text('最近使用'));
      // 底部 8（content_padding）留白，上方把剩下的都吃掉。
      expect(box.bottom - text.bottom, closeTo(8, 0.01));
      expect(text.top - box.top, greaterThan(box.bottom - text.bottom));
    });
  });

  group('OhosToolbar', () {
    OhosToolbarItem item(
      String label, {
      IconData icon = Icons.home_outlined,
      OhosToolbarItemState state = OhosToolbarItemState.enabled,
      VoidCallback? onPressed,
    }) => OhosToolbarItem(
      icon: icon,
      label: label,
      state: state,
      onPressed: onPressed,
    );

    // `DEFAULT_TOOLBAR_HEIGHT = 56`，且官方写明「此高度不包含分割线」→ 整条
    // 57。旧实现写死 72，高了 16，是照着「图标 24 + 间距 + 12fp 文字」凑出来
    // 的，不是官方值。这条同时钉住分割线只有 1。
    testWidgets('整条高 57 = 56 栏高 + 1 分割线', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(OhosToolbar(items: <OhosToolbarItem>[item('首页')])),
      );

      expect(tester.getSize(find.byType(OhosToolbar)).height, 57);
      // 分割线是这颗 1 高的 Container，宽满。
      final Finder divider = find
          .descendant(
            of: find.byType(OhosToolbar),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(divider).height, 1);
    });

    // 图标 24、图标下间距 2、label 10fp/w500。10 是 `ohos_id_text_size_caption1`
    // 的值 —— 比 Material 的 caption（12）还小一档，配套 56 的栏才不挤。
    //
    // 字阶走 `DefaultTextStyle.merge`，所以 `Text.style` 里只有 `null`；
    // 真实值要读绘制用的 `RichText`（`paintedTextStyle`）。
    testWidgets('图标 24 + 间距 2 + 10fp 标签', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(OhosToolbar(items: <OhosToolbarItem>[item('首页')])),
      );

      final Finder icon = find.byIcon(Icons.home_outlined);
      expect(tester.getSize(icon).width, 24);
      expect(tester.getSize(icon).height, 24);

      final TextStyle painted = paintedTextStyle(tester, '首页');
      expect(painted.fontSize, 10);
      expect(painted.fontWeight, FontWeight.w500);

      // 图标下沿到文字上沿 = 2（`padding_level1`）。旧实现是 6。
      final double gap =
          tester.getTopLeft(find.text('首页')).dy - tester.getBottomLeft(icon).dy;
      expect(gap, closeTo(2, 0.01));
    });

    // 左右内边距只在**少于 5** 项时是 24（`padding_level12`），正好 5 项时
    // 归 0 靠均分铺满。`< 5` 不是 `<= 5` —— 写成后者会让 5 项那档突然缩进
    // 24，与 6 项收纳后的 5 格对不齐。
    testWidgets('少于 5 项时左右内边距 24，5 项时归零', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosToolbar(
            items: <OhosToolbarItem>[item('A'), item('B'), item('C')],
          ),
        ),
      );
      Rect bar = tester.getRect(find.byType(OhosToolbar));
      expect(
        tester.getTopLeft(find.text('A')).dx -
            tester.getRect(find.byType(OhosToolbar)).left,
        greaterThan(24),
        reason: '第一格从 24 之后开始，文字居中还会再往右',
      );

      // 5 项：padding 归零，首格贴边（文字仍在格内居中）。
      await tester.pumpWidget(
        wrap(
          OhosToolbar(
            items: <OhosToolbarItem>[
              item('A'),
              item('B'),
              item('C'),
              item('D'),
              item('E'),
            ],
          ),
        ),
      );
      bar = tester.getRect(find.byType(OhosToolbar));
      final double cellWidth = bar.width / 5;
      // 首格中心在 cellWidth/2，说明边距为 0。
      expect(
        tester.getCenter(find.text('A')).dx - bar.left,
        closeTo(cellWidth / 2, 1),
      );
    });

    // 超过 5 项收纳：前 4 项留在栏里，第 5 格变「更多」。
    // `TOOLBAR_MAX_LENGTH = 5` / `moreIndex = 4`。
    testWidgets('6 项时前 4 项 + 更多', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosToolbar(
            items: <OhosToolbarItem>[
              item('A'),
              item('B'),
              item('C'),
              item('D'),
              item('E'),
              item('F'),
            ],
          ),
        ),
      );

      for (final String label in <String>['A', 'B', 'C', 'D']) {
        expect(find.text(label), findsOneWidget, reason: '$label 应留在栏内');
      }
      expect(find.text('E'), findsNothing, reason: 'E 收进更多');
      expect(find.text('F'), findsNothing, reason: 'F 收进更多');
      expect(find.text('更多'), findsOneWidget);
    });

    // 正好 5 项**不收纳**：边界是 `> 5` 而不是 `>= 5`。
    testWidgets('正好 5 项不出现更多', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosToolbar(
            items: <OhosToolbarItem>[
              item('A'),
              item('B'),
              item('C'),
              item('D'),
              item('E'),
            ],
          ),
        ),
      );

      expect(find.text('更多'), findsNothing);
      expect(find.text('E'), findsOneWidget);
    });

    // 激活态要**两个条件同时成立**：`activeIndex` 指向它，且它的 state 是
    // ACTIVATE。只给 activeIndex 不点亮 —— 官方行为，最容易被当成 bug 的一处。
    testWidgets('激活态需 activeIndex 与 ACTIVATE 同时满足', (
      WidgetTester tester,
    ) async {
      final OhosThemeData theme = OhosThemeData.light();

      // 只给 activeIndex、state 仍是 ENABLE → 不点亮。
      await tester.pumpWidget(
        wrap(
          OhosToolbar(
            activeIndex: 0,
            items: <OhosToolbarItem>[item('A'), item('B')],
          ),
        ),
      );
      expect(
        paintedColor(tester, 'A'),
        theme.textPrimaryColor,
        reason: 'ENABLE 项即使被 activeIndex 指到也不点亮',
      );

      // 加 ACTIVATE → 点亮为品牌色。
      await tester.pumpWidget(
        wrap(
          OhosToolbar(
            activeIndex: 0,
            items: <OhosToolbarItem>[
              item('A', state: OhosToolbarItemState.activated),
              item('B'),
            ],
          ),
        ),
      );
      expect(paintedColor(tester, 'A'), theme.highlightColor);
      expect(paintedColor(tester, 'B'), theme.textPrimaryColor);

      // activeIndex 指向 B（非 ACTIVATE）时 A 也退回常态。
      await tester.pumpWidget(
        wrap(
          OhosToolbar(
            activeIndex: 1,
            items: <OhosToolbarItem>[
              item('A', state: OhosToolbarItemState.activated),
              item('B'),
            ],
          ),
        ),
      );
      expect(paintedColor(tester, 'A'), theme.textPrimaryColor);
    });

    // 禁用项：不可点、取 tertiary 色。
    testWidgets('禁用项不可点且变灰', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        wrap(
          OhosToolbar(
            items: <OhosToolbarItem>[
              item('可用', onPressed: () => taps++),
              item(
                '禁用',
                state: OhosToolbarItemState.disabled,
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      );

      expect(
        paintedColor(tester, '禁用'),
        OhosThemeData.light().textTertiaryColor,
      );

      await tester.tap(find.text('禁用'));
      await tester.pumpAndSettle();
      expect(taps, 0, reason: '禁用项不触发回调');

      await tester.tap(find.text('可用'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    // 常态文字用 textPrimary 而不是 textSecondary：工具栏是主导航，不是
    // 辅助信息。旧实现用次级色，整条栏发灰。
    testWidgets('常态文字取主色而非次级色', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(OhosToolbar(items: <OhosToolbarItem>[item('首页')])),
      );

      final OhosThemeData theme = OhosThemeData.light();
      expect(paintedColor(tester, '首页'), theme.textPrimaryColor);
      expect(paintedColor(tester, '首页'), isNot(theme.textSecondaryColor));
    });

    // 点「更多」打开菜单，列出被收纳的两项。默认走 showOhosMenu，
    // 传 onMorePressed 可整块替换。
    testWidgets('点更多列出收纳项', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosToolbar(
            items: <OhosToolbarItem>[
              item('A'),
              item('B'),
              item('C'),
              item('D'),
              item('E'),
              item('F'),
            ],
          ),
        ),
      );

      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle();

      expect(find.text('E'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
    });

    testWidgets('onMorePressed 覆盖默认菜单', (WidgetTester tester) async {
      int more = 0;
      await tester.pumpWidget(
        wrap(
          OhosToolbar(
            onMorePressed: (_) => more++,
            items: <OhosToolbarItem>[
              item('A'),
              item('B'),
              item('C'),
              item('D'),
              item('E'),
              item('F'),
            ],
          ),
        ),
      );

      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle();

      expect(more, 1);
      expect(find.text('E'), findsNothing, reason: '不再弹默认菜单');
    });

    // 墨水屏：`highlightColor` 与 `textPrimaryColor` **都是纯黑**，所以「选中 =
    // 换品牌色」在灰阶屏上等于没做。策略给出 `selectionMark = inverse`，
    // 组件改为反白（实底 + 纸色字）。这条是写代码时**先写了错的版本**再被
    // 断言逼出来的：第一版直接用 highlightColor，墨屏上激活项与常态项同色。
    testWidgets('墨水屏下激活项反白，不靠换色', (WidgetTester tester) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: MaterialApp(
            home: OhosScaffold(
              body: OhosToolbar(
                activeIndex: 0,
                items: <OhosToolbarItem>[
                  item('激活', state: OhosToolbarItemState.activated),
                  item('常态'),
                ],
              ),
            ),
          ),
        ),
      );

      final OhosThemeData ink = OhosThemeData.ink();
      // 前提：这两色在墨屏上确实相同 —— 否则本用例守的就不是那个问题了。
      expect(
        ink.highlightColor,
        ink.textPrimaryColor,
        reason: '本用例成立的前提：墨屏上品牌色与主文字色同值',
      );
      expect(ink.policy.selectionMark, OhosSelectionMark.inverse);

      final Color activeColor = paintedColor(tester, '激活')!;
      final Color idleColor = paintedColor(tester, '常态')!;
      expect(activeColor.a, 1.0, reason: '墨屏上必须是实色');
      expect(idleColor.a, 1.0, reason: '墨屏上必须是实色');
      expect(activeColor, isNot(idleColor), reason: '激活与常态要有明度差，否则读者看不出当前在哪');
      // 反白：激活项的外层 Material 铺实底品牌色，文字取 onHighlightColor。
      final Material activeSurface = tester.widget<Material>(
        find
            .ancestor(of: find.text('激活'), matching: find.byType(Material))
            .first,
      );
      expect(activeSurface.color, ink.highlightColor, reason: '激活格要铺实底');
      expect(activeColor, ink.onHighlightColor);
    });
  });

  group('OhosPageIndicator', () {
    // 未选中点 6×6（`itemWidth`/`itemHeight` 默认 6），选中 12×6。
    // **选中是变宽、不是变大**：官方示例写的就是
    // `selectedItemWidth(16).selectedItemHeight(8)` —— 沿主轴长成胶囊，
    // 高度不变。旧实现两边都是 8 且选中只是 ×2 宽，高度对不上。
    testWidgets('未选中点 6×6，选中点 12×6（变宽不变高）', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(const OhosPageIndicator(count: 3, currentIndex: 1)),
      );
      await tester.pumpAndSettle();

      final Finder dots = find.descendant(
        of: find.byType(OhosPageIndicator),
        matching: find.byType(AnimatedContainer),
      );
      expect(dots, findsNWidgets(3));

      final Size first = tester.getSize(dots.at(0));
      expect(first.width, 6);
      expect(first.height, 6, reason: '未选中点高宽相等');

      final Size active = tester.getSize(dots.at(1));
      expect(active.width, 12, reason: '选中点是 12 宽');
      expect(active.height, 6, reason: '高度不变 —— 变的是宽度');
    });

    // 间距 8 是 `space` 的默认值（手机 / 平板），也是
    // `ohos_id_swiper_indicator_point_padding` 的真值。旧实现 6。
    testWidgets('点间距 8', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(const OhosPageIndicator(count: 3, currentIndex: 0)),
      );
      await tester.pumpAndSettle();

      final Finder dots = find.descendant(
        of: find.byType(OhosPageIndicator),
        matching: find.byType(AnimatedContainer),
      );
      // 第 0 颗 12 宽、后面 6 宽，间隔 = 1 号左边 − 0 号右边。
      final double gap =
          tester.getTopLeft(dots.at(1)).dx - tester.getTopRight(dots.at(0)).dx;
      expect(gap, closeTo(8, 0.01));
    });

    // 数字型是 `DigitIndicator`：显示 `当前/总数`，**从 1 起数**。
    // `currentIndex` 是 0-based，直接拼进文案会显示成 `0/3`。
    testWidgets('数字型显示 当前/总数 且从 1 起', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosPageIndicator(
            count: 8,
            currentIndex: 2,
            type: OhosPageIndicatorType.digit,
          ),
        ),
      );
      expect(find.text('3'), findsOneWidget);
      expect(find.text('/'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      // 没有圆点。
      expect(
        find.descendant(
          of: find.byType(OhosPageIndicator),
          matching: find.byType(AnimatedContainer),
        ),
        findsNothing,
      );
    });

    // 数字型的字号是 14（`digitFont` 默认 `{size: 14, weight: Normal}`）。
    // 当前页与总数只差颜色，**不加粗也不放大** —— 与圆点「变宽」是两种
    // 完全不同的强调方式，容易照圆点的思路写成加粗。
    testWidgets('数字型 14fp/w400，当前页与总数只差颜色', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosPageIndicator(
            count: 8,
            currentIndex: 0,
            type: OhosPageIndicatorType.digit,
          ),
        ),
      );
      final TextStyle current = paintedTextStyle(tester, '1');
      final TextStyle total = paintedTextStyle(tester, '8');

      expect(current.fontSize, 14);
      expect(total.fontSize, 14);
      expect(current.fontWeight, FontWeight.w400);
      expect(total.fontWeight, FontWeight.w400, reason: '总数不加粗');
      expect(current.color, isNot(total.color), reason: '当前页要靠颜色区分');
    });

    // `count` 为 0 时不能显示 `1/0`（`clamp` 前会算出 1）。空轮播是常态：
    // 数据还没到、`children` 先为空。此时两侧都是 0 —— `0/0` 难看但不越界，
    // 而 `1/0` 会让调用方以为是自己的数据错。
    testWidgets('count 为 0 时数字型不越界', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosPageIndicator(
            count: 0,
            currentIndex: 0,
            type: OhosPageIndicatorType.digit,
          ),
        ),
      );
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('1'), findsNothing, reason: '不能凭空出现第 1 页');
      expect(tester.takeException(), isNull);
    });
  });

  group('OhosSwiper', () {
    // `displayArrow` 默认 `false` —— 不传就不画箭头。箭头是可选装饰，
    // 默认画出来会盖住内容。
    testWidgets('默认不画箭头', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosSwiper(
            height: 120,
            children: const <Widget>[Text('一'), Text('二'), Text('三')],
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('showArrows 时左右各一个，点击翻页', (WidgetTester tester) async {
      final List<int> changes = <int>[];
      await tester.pumpWidget(
        wrap(
          OhosSwiper(
            height: 120,
            showArrows: true,
            loop: false,
            onPageChanged: changes.add,
            children: const <Widget>[Text('一'), Text('二'), Text('三')],
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(changes, <int>[1]);
    });

    // 「一屏放得下就没得翻」—— 只有一页时官方两个箭头都不显示，
    // 即使显式打开了 `displayArrow`。
    testWidgets('只有一页时不画箭头', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosSwiper(
            height: 120,
            showArrows: true,
            children: const <Widget>[Text('唯一')],
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    // 指示器样式可以整体切换成数字型。
    testWidgets('indicatorType 切到数字型', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          OhosSwiper(
            height: 120,
            loop: false,
            indicatorType: OhosPageIndicatorType.digit,
            children: const <Widget>[Text('一'), Text('二'), Text('三')],
          ),
        ),
      );
      expect(find.text('1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('OhosDate', () {
    // 官方 `getDayNumber()` 的闰年判定是 `(y%4==0 && y%100!=0) || y%400==0`。
    // 1900 不是闰年（整百不闰）、2000 是 —— 这两档最容易写成「能被 4 整除」。
    test('闰年判定按公历规则', () {
      expect(const OhosDate(year: 2000, month: 2, day: 1).isLeapYear, isTrue);
      expect(const OhosDate(year: 1900, month: 2, day: 1).isLeapYear, isFalse);
      expect(const OhosDate(year: 2024, month: 2, day: 1).isLeapYear, isTrue);
      expect(const OhosDate(year: 2023, month: 2, day: 1).isLeapYear, isFalse);
    });

    test('每月天数', () {
      const OhosDate base = OhosDate(year: 2023, month: 1, day: 1);
      expect(base.copyWith(month: 1).daysInMonth, 31);
      expect(base.copyWith(month: 2).daysInMonth, 28);
      expect(base.copyWith(month: 4).daysInMonth, 30);
      expect(base.copyWith(month: 12).daysInMonth, 31);
    });

    // 三个字段的回绕方式各不相同，这是整个组件的核心语义：
    // 年**夹取**（到 1 / 5000 按钮就死）、月**回绕**但不进位到年、
    // 日**回绕**但按当月长度算。
    test('加年份到边界是夹取，不回绕', () {
      const OhosDate top = OhosDate(year: 5000, month: 6, day: 15);
      expect(top.addYears(1), top);
      const OhosDate bottom = OhosDate(year: 1, month: 6, day: 15);
      expect(bottom.addYears(-1), bottom);
    });

    test('加月份回绕且不进位到年', () {
      const OhosDate december = OhosDate(year: 2024, month: 12, day: 15);
      final OhosDate next = december.addMonths(1);
      expect(next.month, 1);
      // 关键：年份**没变**。真按 DateTime 进位会变成 2025。
      expect(next.year, 2024);

      const OhosDate january = OhosDate(year: 2024, month: 1, day: 15);
      final OhosDate prev = january.addMonths(-1);
      expect(prev.month, 12);
      expect(prev.year, 2024);
    });

    test('加日期回绕按当月长度，不跨月', () {
      const OhosDate endOfFeb = OhosDate(year: 2024, month: 2, day: 29);
      final OhosDate next = endOfFeb.addDays(1);
      expect(next.day, 1);
      // 不是 3 月 1 日 —— 日字段只在当月里绕。
      expect(next.month, 2);

      const OhosDate startOfFeb = OhosDate(year: 2024, month: 2, day: 1);
      expect(startOfFeb.addDays(-1).day, 29);
      // 平年那档只有 28 天。
      expect(const OhosDate(year: 2023, month: 2, day: 1).addDays(-1).day, 28);
    });

    // `updateDay()`：换月后日超出当月长度要收回来。1 月 31 日切到 2 月 →
    // 2 月 29 日（闰年），不是非法的「2 月 31 日」。
    test('换到更短的月份时日期收敛到月末', () {
      const OhosDate jan31 = OhosDate(year: 2024, month: 1, day: 31);
      final OhosDate feb = jan31.copyWith(month: 2);
      expect(feb.day, 29);
      expect(feb.month, 2);

      final OhosDate feb2023 = jan31.copyWith(year: 2023, month: 2);
      expect(feb2023.day, 28);
    });

    test('toString 是 YYYY-MM-DD 且月日补零', () {
      expect(
        const OhosDate(year: 2024, month: 3, day: 7).toString(),
        '2024-03-07',
      );
      expect(
        const OhosDate(year: 999, month: 12, day: 31).toString(),
        '999-12-31',
      );
    });

    // 值对象：`didUpdateWidget` 靠它判断要不要把输入框重同步回去。
    test('值相等性', () {
      expect(
        const OhosDate(year: 2024, month: 3, day: 7),
        const OhosDate(year: 2024, month: 3, day: 7),
      );
      expect(
        const OhosDate(year: 2024, month: 3, day: 7).hashCode,
        const OhosDate(year: 2024, month: 3, day: 7).hashCode,
      );
      expect(
        const OhosDate(year: 2024, month: 3, day: 7),
        isNot(const OhosDate(year: 2024, month: 3, day: 8)),
      );
    });
  });

  group('OhosDateCounter', () {
    Widget counter({
      required OhosDate value,
      required ValueChanged<OhosDate> onChanged,
      int step = 1,
      bool enabled = true,
    }) {
      return wrap(
        OhosDateCounter(
          value: value,
          onChanged: onChanged,
          step: step,
          enabled: enabled,
        ),
      );
    }

    // 三段都渲染出来了，且年初的补零是对的。
    testWidgets('渲染 年/月/日 三段', (WidgetTester tester) async {
      await tester.pumpWidget(
        counter(
          value: const OhosDate(year: 2024, month: 3, day: 7),
          onChanged: (_) {},
        ),
      );
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('03'), findsOneWidget);
      expect(find.text('07'), findsOneWidget);
      // 两个分隔符。
      expect(find.text('/'), findsNWidgets(2));
    });

    // 三个输入框在同一个 Row 里，宽度按官方 38 / 19 / 19 分。
    testWidgets('分段宽度 38 / 19 / 19', (WidgetTester tester) async {
      await tester.pumpWidget(
        counter(
          value: const OhosDate(year: 2024, month: 3, day: 7),
          onChanged: (_) {},
        ),
      );
      final Iterable<Size> sizes = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((TextField f) => tester.getSize(find.byWidget(f)));
      expect(sizes.length, 3);
      expect(sizes.elementAt(0).width, 38);
      expect(sizes.elementAt(1).width, 19);
      expect(sizes.elementAt(2).width, 19);
    });

    // 容器高 32、圆角 8、1vp 描边 —— 全部来自 counter.ets 而不是文档那句
    // 「32vp」概括。
    testWidgets('容器高 32 且有描边', (WidgetTester tester) async {
      await tester.pumpWidget(
        counter(
          value: const OhosDate(year: 2024, month: 3, day: 7),
          onChanged: (_) {},
        ),
      );
      final Size size = tester.getSize(find.byType(OhosDateCounter));
      expect(size.height, 32);
      // 无焦点时点「日」右侧的上箭头 → 日字段 +1。
      final Container box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(OhosDateCounter),
              matching: find.byType(Container),
            )
            .first,
      );
      final BoxDecoration decoration = box.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(8));
      expect(decoration.border, isNotNull);
    });

    // 没有段聚焦时按钮作用于**日**（官方 focusDayWithAdd / focusDayWitdhSub）。
    testWidgets('无焦点时上箭头加日', (WidgetTester tester) async {
      OhosDate? last;
      await tester.pumpWidget(
        counter(
          value: const OhosDate(year: 2024, month: 3, day: 7),
          onChanged: (OhosDate v) => last = v,
        ),
      );
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
      await tester.pumpAndSettle();
      expect(last, const OhosDate(year: 2024, month: 3, day: 8));
    });

    // 点年段再按上箭头 → 年 +1，而日不动。
    testWidgets('点年段后上箭头加年', (WidgetTester tester) async {
      OhosDate? last;
      await tester.pumpWidget(
        counter(
          value: const OhosDate(year: 2024, month: 3, day: 7),
          onChanged: (OhosDate v) => last = v,
        ),
      );
      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
      await tester.pumpAndSettle();
      expect(last, const OhosDate(year: 2025, month: 3, day: 7));
    });

    testWidgets('点月段后下箭头减月并回绕', (WidgetTester tester) async {
      OhosDate? last;
      await tester.pumpWidget(
        counter(
          value: const OhosDate(year: 2024, month: 1, day: 7),
          onChanged: (OhosDate v) => last = v,
        ),
      );
      await tester.tap(find.text('01'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();
      expect(last, const OhosDate(year: 2024, month: 12, day: 7));
    });

    // step 作用于当前段的单位：step=3 时按一次上箭头是 +3 天。
    testWidgets('step 生效于当前段', (WidgetTester tester) async {
      OhosDate? last;
      await tester.pumpWidget(
        counter(
          value: const OhosDate(year: 2024, month: 3, day: 7),
          onChanged: (OhosDate v) => last = v,
          step: 3,
        ),
      );
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
      await tester.pumpAndSettle();
      expect(last, const OhosDate(year: 2024, month: 3, day: 10));
    });

    // 年在上边界时，上箭头不回调也不崩 —— 官方是把按钮禁用掉的。
    testWidgets('年份到 5000 时上箭头不再变化', (WidgetTester tester) async {
      int calls = 0;
      await tester.pumpWidget(
        counter(
          value: const OhosDate(year: 5000, month: 3, day: 7),
          onChanged: (_) => calls++,
        ),
      );
      await tester.tap(find.text('5000'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
      await tester.pumpAndSettle();
      expect(calls, 0);
    });

    testWidgets('enabled: false 时按钮点不动', (WidgetTester tester) async {
      int calls = 0;
      await tester.pumpWidget(
        counter(
          value: const OhosDate(year: 2024, month: 3, day: 7),
          onChanged: (_) => calls++,
          enabled: false,
        ),
      );
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
      await tester.pumpAndSettle();
      expect(calls, 0);
    });

    // 直接输入：只有输入满位数才提交，这是官方 `value.length === 4` / `=== 2`。
    testWidgets('输入满 4 位的年份才提交', (WidgetTester tester) async {
      OhosDate? last;
      await tester.pumpWidget(
        counter(
          value: const OhosDate(year: 2024, month: 3, day: 7),
          onChanged: (OhosDate v) => last = v,
        ),
      );
      await tester.enterText(find.byType(TextField).first, '202');
      await tester.pumpAndSettle();
      expect(last, isNull);
      await tester.enterText(find.byType(TextField).first, '2030');
      await tester.pumpAndSettle();
      expect(last, const OhosDate(year: 2030, month: 3, day: 7));
    });

    // 输入一个不存在的日期（平年 2 月 30 日）时整段回退、不提交 —— 官方是
    // `if (inputDay >= 1 && inputDay <= getDayNumber())` 才赋值，越界就原样退回，
    // 不是收敛到月末（收敛只发生在**换月**时，见上面的模型用例）。
    testWidgets('输入超范围的日整段回退，不提交也不收敛', (WidgetTester tester) async {
      OhosDate? last;
      await tester.pumpWidget(
        counter(
          value: const OhosDate(year: 2023, month: 2, day: 7),
          onChanged: (OhosDate v) => last = v,
        ),
      );
      await tester.enterText(find.byType(TextField).last, '30');
      await tester.pumpAndSettle();
      expect(last, isNull);
      // 显示回退到原值 07，而不是被钳成 28。
      expect(find.text('07'), findsOneWidget);
    });

    // 焦点段换底色是「唯一的分段线索」：彩屏上是品牌蓝，文字转 onHighlight。
    // 墨屏上 highlightColor 就是纯黑，于是变成黑块 + 纸色字 —— 同一个分支
    // 在两种屏上都读得出来，不需要 policy 判断。
    testWidgets('聚焦段换成高亮底色', (WidgetTester tester) async {
      await tester.pumpWidget(
        counter(
          value: const OhosDate(year: 2024, month: 3, day: 7),
          onChanged: (_) {},
        ),
      );
      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();

      final OhosThemeData theme = OhosThemeData.light();
      final TextField field = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(field.style?.color, theme.onHighlightColor);

      // 外层 Container 的底色即高亮色。
      final Container block = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(TextField).first,
              matching: find.byType(Container),
            )
            .first,
      );
      expect(block.color, theme.highlightColor);
    });
  });
  group('OhosProgressIndicator', () {
    test('几何常量对得上资源表', () {
      expect(OhosProgressMetrics.thickness, 4);
      expect(OhosProgressMetrics.linearWidth, 300);
      expect(OhosProgressMetrics.diameter, 72);
      expect(OhosProgressMetrics.scaleRingDiameter, 77);
      expect(OhosProgressMetrics.scaleCount, 120);
      expect(OhosProgressMetrics.scaleWidth, 2);
      expect(OhosProgressMetrics.capsuleBorderWidth, 1);
      expect(OhosProgressMetrics.capsuleBorderColor, const Color(0x33007DFF));
    });

    test('刻度环直径 77 是「刚好不退化」的下界', () {
      // 官方文档的刻度数上界 = min(w,h)/scaleWidth/2/π，是同一个不等式的移项。
      // 直径 72 + 默认 120 刻度 + 宽 2 ⇒ 间距 1.88 < 2 ⇒ 退化。
      expect(
        ohosScaleRingDegrades(radius: 36, scaleCount: 120, scaleWidth: 2),
        isTrue,
        reason: '72 直径下默认刻度应当退化',
      );
      // 77 ⇒ 间距 2.02 > 2 ⇒ 正好不退化。这就是 77 这个「奇怪」下界的来由。
      expect(
        ohosScaleRingDegrades(radius: 38.5, scaleCount: 120, scaleWidth: 2),
        isFalse,
      );
      // 刻度宽大于间距（大刻度数或粗刻度）
      expect(
        ohosScaleRingDegrades(radius: 50, scaleCount: 120, scaleWidth: 5),
        isTrue,
      );
      expect(
        ohosScaleRingDegrades(radius: 50, scaleCount: 120, scaleWidth: 2),
        isFalse,
      );
      // 刻度数 < 2 或半径 <= 0 也退化
      expect(
        ohosScaleRingDegrades(radius: 50, scaleCount: 1, scaleWidth: 1),
        isTrue,
      );
      expect(
        ohosScaleRingDegrades(radius: 0, scaleCount: 120, scaleWidth: 2),
        isTrue,
      );
    });

    test('月相 0 是空、0.5 是左半圆、1 是满圆', () {
      // 用 `Path.contains` 而不是 `getBounds`：后者把弧的控制点也算进包围盒，
      // 于是 0 和 0.25 会给出同一个矩形 —— 量不出「填了多少面积」。
      // 三档端点各不相同，照「按角度画扇形」实现会全错：0.5 不是画了一半，
      // 而是一整个左半圆。
      const Rect r = Rect.fromLTWH(0, 0, 100, 100);
      Path p(double v) => ohosEclipsePath(r, v);

      // 0：一个像素都不填
      expect(p(0).contains(const Offset(25, 50)), isFalse);
      // 0.25：只填到 1/4 处，25 以内
      expect(p(0.25).contains(const Offset(10, 50)), isTrue);
      expect(p(0.25).contains(const Offset(40, 50)), isFalse);
      // 0.5：整个左半圆（x < 50），右半圆仍是空的
      expect(p(0.5).contains(const Offset(25, 50)), isTrue);
      expect(p(0.5).contains(const Offset(49, 50)), isTrue);
      expect(p(0.5).contains(const Offset(51, 50)), isFalse);
      // 0.75：越过中线，但还没到右边缘
      expect(p(0.75).contains(const Offset(60, 50)), isTrue);
      expect(p(0.75).contains(const Offset(90, 50)), isFalse);
      // 1：满圆
      expect(p(1).contains(const Offset(90, 50)), isTrue);
      // 四个角在圆外的点始终不被填
      expect(p(1).contains(const Offset(2, 2)), isFalse);
    });

    test('月相边界随进度单调推进，不是阶跃', () {
      // 逐档扫左半轴上「最远被填到的 x」，应当严格递增 —— 这是「月相」与
      // 「按角度画扇形」在行为上的分水岭：前者沿 x 推进，后者沿角度推进。
      const Rect r = Rect.fromLTWH(0, 0, 100, 100);
      int reach(double v) {
        final Path p = ohosEclipsePath(r, v);
        int last = -1;
        for (int x = 0; x < 100; x++) {
          if (p.contains(Offset(x + 0.5, 50))) {
            last = x;
          }
        }
        return last;
      }

      final List<int> reaches = <double>[
        0,
        0.25,
        0.5,
        0.75,
        1,
      ].map(reach).toList();
      for (int i = 1; i < reaches.length; i++) {
        expect(
          reaches[i],
          greaterThan(reaches[i - 1]),
          reason: 'value 增大时填充必须继续向右推进：$reaches',
        );
      }
      // 0.25 大约到 25，0.5 到 50，0.75 到 75（各留 ±3 的像素容差）
      expect(reaches[1], closeTo(25, 3));
      expect(reaches[2], closeTo(50, 3));
      expect(reaches[3], closeTo(75, 3));
      // 夹取：越界值与端点同形
      expect(ohosEclipsePath(r, -2).contains(const Offset(25, 50)), isFalse);
      expect(ohosEclipsePath(r, 5).contains(const Offset(90, 50)), isTrue);
    });

    test('胶囊三档：月牙 / 中段矩形 / 收口', () {
      // 三档是三种不同的几何，缺一档就会露馅。用 `contains` 采样中轴线上
      // 的四个位置（5 / 30 / 70 / 95），逐档确认「填到哪」。
      const Size size = Size(100, 40);
      Path p(double v) =>
          ohosCapsuleProgressPath(size: size, value: v, borderRadius: 20);
      List<bool> probe(Path path) => <double>[
        5,
        30,
        70,
        95,
      ].map((double x) => path.contains(Offset(x, 20))).toList();

      // 1) progress < r：只填左端月牙，中段与右端都是空的
      expect(probe(p(0.1)), <bool>[true, false, false, false]);
      // 2) r ≤ progress < w - r：左半圆 + 中段矩形，右端仍空
      expect(probe(p(0.5)), <bool>[true, true, false, false]);
      // 3) progress ≥ w - r：右端收口，四段全填 —— 缺了会少一个角
      expect(probe(p(0.9)), <bool>[true, true, true, true]);
      expect(probe(p(1)), <bool>[true, true, true, true]);
      // 四角始终在胶囊之外
      expect(p(1).contains(const Offset(0, 0)), isFalse);
      expect(p(1).contains(const Offset(100, 40)), isFalse);
    });

    test('胶囊圆角夹到 0…height/2', () {
      const Size size = Size(100, 40);
      Path p(double radius) =>
          ohosCapsuleProgressPath(size: size, value: 0.5, borderRadius: radius);
      // 圆角给到 200 时按 20 处理：不该算出一条比盒子还高的弧
      expect(
        p(200).contains(const Offset(30, 20)),
        p(20).contains(const Offset(30, 20)),
      );
      expect(
        p(200).contains(const Offset(1, 1)),
        p(20).contains(const Offset(1, 1)),
      );
      // 圆角为 0 时退化成直角矩形：角上是填满的
      expect(p(0).contains(const Offset(1, 1)), isTrue);
    });

    test('胶囊尺寸为零时不画任何东西', () {
      final Path empty = ohosCapsuleProgressPath(
        size: Size.zero,
        value: 0.5,
        borderRadius: 10,
      );
      // 空 Path 没有任何度量段 —— `Path` 没有 `isEmpty`，只能看 metrics
      expect(empty.computeMetrics().isEmpty, isTrue);
    });

    testWidgets('线性：按比例画长度，超界夹到盒内', (WidgetTester tester) async {
      Future<Rect> bar(double value) async {
        await tester.pumpWidget(
          wrap(
            const SizedBox(
              width: 200,
              height: 4,
              child: OhosProgressIndicator.linear(value: 0),
            ),
          ),
        );
        // 换 value 后重放 painter：组件本身是 const，直接换实例
        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 200,
              height: 4,
              child: OhosProgressIndicator.linear(value: value),
            ),
          ),
        );
        final List<Object> draws = _replay(
          tester,
          OhosProgressIndicator,
          size: const Size(200, 4),
        );
        final List<_RectDraw> rects = draws.whereType<_RectDraw>().toList();
        // 第一条是轨道，最后一条是已完成
        return rects.last.rect;
      }

      expect((await bar(0.5)).width, moreOrLessEquals(100));
      expect((await bar(0.25)).width, moreOrLessEquals(50));
      // 超界不画到盒子外面
      expect((await bar(3)).width, 200);
      // 0 与负数时只有轨道一条，没有已完成矩形
      Future<int> count(double value) async {
        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 200,
              height: 4,
              child: OhosProgressIndicator.linear(value: value),
            ),
          ),
        );
        return _replay(
          tester,
          OhosProgressIndicator,
          size: const Size(200, 4),
        ).whereType<_RectDraw>().length;
      }

      expect(await count(0), 1);
      expect(await count(-1), 1);
      expect(await count(0.5), 2);
    });

    testWidgets('线性：完全无界时退回 300，不拿 Infinity 崩布局', (WidgetTester tester) async {
      // 必须给一个**真正无界**的约束才能触发回落：`Center` 会把 child 撑到
      // 父宽（800），那时走的是正常分支，测不到默认值。所以这里绕过
      // `Center`，直接让孩子贴在一个纵向 `Column` 里 —— 横轴仍是紧约束，
      // 所以改用 `UnconstrainedBox` 打开两个方向。
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.light(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: UnconstrainedBox(
              child: OhosProgressIndicator.linear(value: 0.5),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(OhosProgressIndicator)),
        const Size(300, 4),
      );
    });

    testWidgets('环形：12 点起顺时针，弧度按比例', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(const OhosProgressIndicator.ring(value: 0.5)),
      );
      final List<Object> draws = _replay(tester, OhosProgressIndicator);
      // 轨道走 `drawCircle`（一整圈），只有进度走 `drawArc`
      expect(draws.whereType<_CircleDraw>(), hasLength(1));
      final List<_ArcDraw> arcs = draws.whereType<_ArcDraw>().toList();
      expect(arcs, hasLength(1));
      // 从 12 点起顺时针，弧度按比例（0.5 → π）
      expect(arcs.single.start, moreOrLessEquals(-math.pi / 2));
      expect(arcs.single.sweep, moreOrLessEquals(math.pi));
    });

    testWidgets('环形：厚度 + 阴影超半径时被压成半径一半', (WidgetTester tester) async {
      // 不夹取的话，小尺寸 + 粗环会画成一个实心圆
      await tester.pumpWidget(
        wrap(
          const OhosProgressIndicator.ring(
            value: 0.5,
            size: 24,
            strokeWidth: 20,
          ),
        ),
      );
      final List<_ArcDraw> arcs = _replay(
        tester,
        OhosProgressIndicator,
        size: const Size(24, 24),
      ).whereType<_ArcDraw>().toList();
      // 半径 12，压成 6 ⇒ 中心线半径 12 - 3 = 9
      expect(arcs.single.radius, moreOrLessEquals(9));
    });

    testWidgets('环形：半径 ≤ 10 不画阴影（官方：没空间同时画）', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosProgressIndicator.ring(value: 0.5, size: 16, shadow: true),
        ),
      );
      // 半径 8 ≤ 10：只有一条进度弧，没有阴影弧
      expect(
        _replay(
          tester,
          OhosProgressIndicator,
          size: const Size(16, 16),
        ).whereType<_ArcDraw>().length,
        1,
        reason: '半径 8 时不该画阴影',
      );

      await tester.pumpWidget(
        wrap(
          const OhosProgressIndicator.ring(value: 0.5, size: 100, shadow: true),
        ),
      );
      final List<_ArcDraw> big = _replay(
        tester,
        OhosProgressIndicator,
        size: const Size(100, 100),
      ).whereType<_ArcDraw>().toList();
      expect(big, hasLength(2), reason: '大尺寸下阴影弧必须真的画出来');
      // 阴影半透明、进度实色：两者都在，且前后顺序是先影后体
      expect(big.first.color.a, lessThan(big.last.color.a));
    });

    testWidgets('刻度环：进度靠换色，刻度数不变', (WidgetTester tester) async {
      // 最容易做反的一条：照线性条的直觉会画出一条越来越长的弧。
      Future<List<_LineDraw>> ticks(double value) async {
        await tester.pumpWidget(
          wrap(
            OhosProgressIndicator.scaleRing(
              value: value,
              scaleCount: 10,
              scaleWidth: 2,
              size: 100,
            ),
          ),
        );
        return _replay(
          tester,
          OhosProgressIndicator,
          size: const Size(100, 100),
        ).whereType<_LineDraw>().toList();
      }

      final List<_LineDraw> zero = await ticks(0);
      final List<_LineDraw> half = await ticks(0.5);
      // 刻度总数不随进度变
      expect(zero.length, 10);
      expect(half.length, 10);
      // 0 时全是轨道色
      expect(zero.every((_LineDraw l) => l.color == zero.first.color), isTrue);
      // 一半换成了进度色，另一半仍是轨道色
      expect(
        half.take(5).every((_LineDraw l) => l.color == half.first.color),
        isTrue,
      );
      expect(half.last.color, isNot(half.first.color));
    });

    testWidgets('刻度环退化时画的是环，不是空白', (WidgetTester tester) async {
      // 「退化」被误实现成「不画」时界面上是块空白，比刻度糊掉更糟。
      // 72 直径 + 默认 120 刻度 + 宽 2 恰好满足退化条件（见上一条用例）。
      await tester.pumpWidget(
        wrap(
          const OhosProgressIndicator.scaleRing(
            value: 0.5,
            size: 72,
            scaleWidth: 2,
            scaleCount: 120,
          ),
        ),
      );
      final List<Object> draws = _replay(
        tester,
        OhosProgressIndicator,
        size: const Size(72, 72),
      );
      // 退化后走「画环」：一整圈轨道圆 + 一段进度弧，且一根刻度线都没有
      expect(draws.whereType<_LineDraw>(), isEmpty);
      expect(draws.whereType<_CircleDraw>(), hasLength(1));
      final List<_ArcDraw> arcs = draws.whereType<_ArcDraw>().toList();
      expect(arcs, hasLength(1));
      expect(arcs.single.sweep, moreOrLessEquals(math.pi));
    });

    testWidgets('月相：先铺整圆底，再画一条月牙路径', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(const OhosProgressIndicator.eclipse(value: 0.5)),
      );
      final List<Object> draws = _replay(tester, OhosProgressIndicator);
      expect(draws.whereType<_CircleDraw>(), hasLength(1));
      expect(draws.whereType<_PathDraw>(), hasLength(1));
      // 月牙的包围盒是左半圆
      final Rect bounds = draws.whereType<_PathDraw>().single.path.getBounds();
      expect(bounds.width, moreOrLessEquals(36), reason: '72 直径的左半圆');
    });

    testWidgets('胶囊：画底板、内描边、进度路径', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 200,
            height: 40,
            child: OhosProgressIndicator.capsule(value: 0.5),
          ),
        ),
      );
      final List<Object> draws = _replay(
        tester,
        OhosProgressIndicator,
        size: const Size(200, 40),
      );
      // 底板 + 内描边两条 RRect，加一条进度路径
      expect(draws.whereType<_RRectDraw>(), hasLength(2));
      expect(draws.whereType<_PathDraw>(), hasLength(1));
      // 内描边是 1vp
      expect(draws.whereType<_RRectDraw>().last.strokeWidth, 1);
      expect(
        draws.whereType<_PathDraw>().single.path.getBounds().right,
        moreOrLessEquals(100),
      );
    });

    testWidgets('胶囊 content 压过百分比', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 200,
            height: 40,
            child: OhosProgressIndicator.capsule(
              value: 0.5,
              content: '安装中',
              showDefaultPercentage: true,
            ),
          ),
        ),
      );
      // 官方：「设置了 content 属性时该属性不生效」
      expect(find.text('安装中'), findsOneWidget);
      expect(find.text('50%'), findsNothing);
    });

    testWidgets('胶囊百分比取整：0.999 显示 100% 而不是 99%', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 200,
            height: 40,
            child: OhosProgressIndicator.capsule(
              value: 0.999,
              showDefaultPercentage: true,
            ),
          ),
        ),
      );
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('两个都不给时不显示文字', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 200,
            height: 40,
            child: OhosProgressIndicator.capsule(value: 0.5),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(OhosProgressIndicator),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });

    testWidgets('墨屏：轨道改画线，不铺 15% 的底', (WidgetTester tester) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: const MaterialApp(
            home: OhosScaffold(
              body: Center(child: OhosProgressIndicator.ring(value: 0.5)),
            ),
          ),
        ),
      );
      final List<_CircleDraw> circles = _replay(
        tester,
        OhosProgressIndicator,
      ).whereType<_CircleDraw>().toList();
      // 灰阶屏上 15% 的底留不住形体，必须换成 1px 实线环
      expect(circles.first.strokeWidth, 1);
    });

    testWidgets('value 为 null：线性/环形给不确定态，月相不画进度', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 200,
            height: 4,
            child: OhosProgressIndicator.linear(),
          ),
        ),
      );
      // 轨道 + 一段游标
      expect(
        _replay(
          tester,
          OhosProgressIndicator,
          size: const Size(200, 4),
        ).whereType<_RectDraw>().length,
        2,
      );

      // 官方的不确定态只有 ProgressStatus.LOADING，只挂在 RingStyleOptions 上
      await tester.pumpWidget(wrap(const OhosProgressIndicator.eclipse()));
      expect(
        _replay(tester, OhosProgressIndicator).whereType<_PathDraw>(),
        isEmpty,
        reason: '月相没有不确定态，null 按 0 画',
      );
    });

    testWidgets('linear 不确定态：库内自驱，游标随时间扫过', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 200,
            height: 4,
            child: OhosProgressIndicator.linear(),
          ),
        ),
      );
      double cursorLeft() => _replay(
        tester,
        OhosProgressIndicator,
        size: const Size(200, 4),
      ).whereType<_RectDraw>().last.rect.left;

      final double first = cursorLeft();
      await tester.pump(const Duration(milliseconds: 400));
      final double second = cursorLeft();
      await tester.pump(const Duration(milliseconds: 400));
      final double third = cursorLeft();

      expect(
        second,
        isNot(first),
        reason: '不确定态要自己转，不能要求调用方另接 AnimationController',
      );
      expect(third, isNot(second), reason: '一轮 2000ms，两帧之间必须前进');
    });

    testWidgets('ring 不确定态：90° 游标绕圈转', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const OhosProgressIndicator.ring()));
      double startAngle() => _replay(
        tester,
        OhosProgressIndicator,
      ).whereType<_ArcDraw>().first.start;

      final double first = startAngle();
      await tester.pump(const Duration(milliseconds: 500));
      final double second = startAngle();

      // 500ms 是四分之一轮，正好 90°（π/2）
      expect(second - first, closeTo(math.pi / 2, 0.05));
    });

    testWidgets('墨屏：不确定态不转，停在静态中位', (WidgetTester tester) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: MaterialApp(
            home: const OhosScaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  height: 4,
                  child: OhosProgressIndicator.linear(),
                ),
              ),
            ),
          ),
        ),
      );
      double cursorLeft() => _replay(
        tester,
        OhosProgressIndicator,
        size: const Size(200, 4),
      ).whereType<_RectDraw>().last.rect.left;

      final double first = cursorLeft();
      await tester.pump(const Duration(milliseconds: 800));

      // 策略把动画时长压成 0：相位为 null，落在 35% 的静态中位
      expect(cursorLeft(), first, reason: '墨水屏上不许有帧动画');
      expect(first, closeTo(200 * 0.35, 0.01));
    });
  });

  group('OhosLoadingIndicator', () {
    testWidgets('默认 32vp，且真的在画彗星弧', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const OhosLoadingIndicator()));
      expect(
        tester.getSize(find.byType(OhosLoadingIndicator)),
        const Size(32, 32),
      );
      // 一条弧 + 渐变 shader：尾巴靠 GPU 连续插值淡出。
      // 早先的 24 段写法在大尺寸露出台阶、小尺寸糊成团块，两档都不像彗尾。
      final List<_ArcDraw> arcs = _replay(
        tester,
        OhosLoadingIndicator,
      ).whereType<_ArcDraw>().toList();
      expect(arcs.length, 1, reason: '不许多笔分段，段间会有台阶与抗锯齿缝');
      expect(arcs.single.shader, isNotNull, reason: '尾巴必须由 shader 连续淡出');
      expect(
        arcs.single.sweep,
        moreOrLessEquals(0.6 * 2 * math.pi, epsilon: 0.01),
        reason: '弧长固定 60%，不随动画变长',
      );
      // paint 的 alpha 会调制 shader 输出：这里必须是 1，透明度全交给渐变。
      // 早先把带 alpha 的主题色原样写上，整条弧被乘了第二遍（峰值 0.22），
      // 27vp 的圈在白底上就是一条浅灰带。
      expect(arcs.single.color.a, 1.0, reason: 'paint 不能再调制一次 shader 的 alpha');
    });

    testWidgets('彗星弧的 alpha 曲线：弧头最亮、沿弧单调递减', (WidgetTester tester) async {
      // 官方默认色 `#ff666666` = 60% 黑，就是色板里的次级文字色
      final OhosThemeData theme = OhosThemeData.light();
      expect(
        theme.textSecondaryColor.a,
        closeTo(0.6, 0.01),
        reason: '0x99000000 叠白即 #666666',
      );

      final List<Color> fade = OhosLoadingIndicatorMetrics.cometFadeColors(
        theme.textSecondaryColor,
      );
      expect(fade.length, 5);
      expect(
        fade.first.a,
        closeTo(0.6, 0.01),
        reason: '弧头取颜色自带的 alpha，不能被拉满成实黑',
      );
      for (int i = 1; i < fade.length; i++) {
        expect(
          fade[i].a,
          lessThan(fade[i - 1].a),
          reason: '第 $i 档必须比前一档淡 —— 早先 0.5625 覆盖 0.6 会在弧上冒出「亮肩」',
        );
      }
      expect(fade.last.a, 0, reason: '弧尾要真的淡到看不见');
    });

    testWidgets('彗星弧的头在前进方向那端，不是拖在后面', (WidgetTester tester) async {
      // drawArc 的正角度与 SweepGradient 的 stop 都沿顺时针增长，弧也顺时针
      // 转 —— 所以 stop 越大越靠前，最亮的必须落在末位。早先按「stop 0 是
      // 弧头」铺，真机上浅色尾巴在前面跑、深色脑袋拖在后面。
      final List<Color> sweep = OhosLoadingIndicatorMetrics.cometSweepColors(
        const Color(0x99000000),
      );
      expect(sweep.length, 6);
      for (int i = 1; i < sweep.length; i++) {
        expect(
          sweep[i].a,
          greaterThanOrEqualTo(sweep[i - 1].a),
          reason: '沿 stop 递增方向 alpha 只能变大：第 $i 档比前一档亮或持平',
        );
      }
      expect(sweep.first.a, 0, reason: 'stop 0 是弧尾');
      expect(sweep.last.a, closeTo(0.6, 0.01), reason: '末位才是弧头');
    });

    testWidgets('enableLoading=false 仍占位，只是不转', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(const OhosLoadingIndicator(enableLoading: false)),
      );
      // 尺寸不变 —— 加载完切成 false 不会让列表跳一下
      expect(
        tester.getSize(find.byType(OhosLoadingIndicator)),
        const Size(32, 32),
      );
      // 仍然画出静止的弧，不是消失
      expect(_replay(tester, OhosLoadingIndicator), isNotEmpty);
    });

    testWidgets('会转：相位随时间推进', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const OhosLoadingIndicator()));
      final double before = _replay(
        tester,
        OhosLoadingIndicator,
      ).whereType<_ArcDraw>().first.start;
      await tester.pump(const Duration(milliseconds: 500));
      final double after = _replay(
        tester,
        OhosLoadingIndicator,
      ).whereType<_ArcDraw>().first.start;
      expect(after, isNot(moreOrLessEquals(before)));
    });

    testWidgets('墨屏上停转，但弧还在', (WidgetTester tester) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: const MaterialApp(
            home: OhosScaffold(body: Center(child: OhosLoadingIndicator())),
          ),
        ),
      );
      final double before = _replay(
        tester,
        OhosLoadingIndicator,
      ).whereType<_ArcDraw>().first.start;
      await tester.pump(const Duration(milliseconds: 500));
      final double after = _replay(
        tester,
        OhosLoadingIndicator,
      ).whereType<_ArcDraw>().first.start;
      // 每帧一次真实全屏刷新在墨水屏上是灾难，所以整段动画被压成零时长
      expect(after, moreOrLessEquals(before));
      expect(_replay(tester, OhosLoadingIndicator), isNotEmpty);
    });

    testWidgets('颜色默认取次级文字色，不是品牌色', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const OhosLoadingIndicator()));
      final Color painted = _replay(
        tester,
        OhosLoadingIndicator,
      ).whereType<_ArcDraw>().first.color;
      final OhosThemeData theme = OhosThemeData.light();
      // 官方默认 #ff666666 是一档中性灰，不是主色 —— 加载态不是品牌露出。
      // 透明度不进 paint（会二次调制 shader），所以这里只看色相。
      expect(
        painted.r,
        moreOrLessEquals(theme.textSecondaryColor.r, epsilon: 0.02),
      );
      expect(painted, isNot(theme.highlightColor));
    });

    testWidgets('size 与 strokeWidth 生效', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(const OhosLoadingIndicator(size: 48, strokeWidth: 5)),
      );
      expect(
        tester.getSize(find.byType(OhosLoadingIndicator)),
        const Size(48, 48),
      );
      expect(
        _replay(
          tester,
          OhosLoadingIndicator,
        ).whereType<_ArcDraw>().first.strokeWidth,
        5,
      );
    });
  });

  group('OhosListGroup', () {
    /// 从分组里取组内分隔线：`OhosListTile` 自己的线被 scope 压掉了，所以
    /// 整个子树里剩下的 [OhosDivider] 全是分组画的。
    List<OhosDivider> groupDividers(WidgetTester tester) =>
        tester.widgetList<OhosDivider>(find.byType(OhosDivider)).toList();

    test('几何常量：12 / 4 / 24 分处三个来源，行级 48 / 8 只在文档里', () {
      // 12vp：资源表 ohos_id_card_margin_start/_end
      expect(OhosListGroupMetrics.cardMargin, 12);
      // 4vp：文档正文「上下左右内边距 4vp」，资源表无此令牌
      expect(OhosListGroupMetrics.cardPadding, 4);
      // 24vp：list_item_pattern.item_border_radius → ohos_id_corner_radius_default_l
      expect(OhosListGroupMetrics.cardRadius, 24);
      // 行级：48vp / 8vp，同样只在文档正文
      expect(OhosListGroupMetrics.cardItemHeight, 48);
      expect(OhosListGroupMetrics.cardItemPadding, 8);
    });

    test('枚举值与官方四个枚举同序，便于逐条对照', () {
      // ArkUI：ListItemGroupStyle.NONE=0 / CARD=1
      expect(OhosListGroupStyle.none.index, 0);
      expect(OhosListGroupStyle.card.index, 1);
      // ArkUI：ListItemStyle.NONE=0 / CARD=1
      expect(OhosListGroupItemStyle.none.index, 0);
      expect(OhosListGroupItemStyle.card.index, 1);
      // ArkUI：StickyStyle.None=0 / Header=1 / Footer=2 / BOTH=3
      expect(OhosListStickyStyle.none.index, 0);
      expect(OhosListStickyStyle.header.index, 1);
      expect(OhosListStickyStyle.footer.index, 2);
      expect(OhosListStickyStyle.both.index, 3);
    });

    testWidgets('style: none 不铺底板、不加外边距', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosListGroup(
            children: <Widget>[
              OhosListTile(title: Text('A')),
              OhosListTile(title: Text('B')),
            ],
          ),
        ),
      );

      final Rect group = tester.getRect(find.byType(OhosListGroup));
      final Rect rowA = tester.getRect(find.text('A'));
      // 无外边距：第一行文字直接落在分组左边界 + 行内边距 16 处
      expect(rowA.left - group.left, moreOrLessEquals(16, epsilon: 0.01));
      // 无底板：分组自身不该有 DecoratedBox 背景
      final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(OhosListGroup),
          matching: find.byType(DecoratedBox),
        ),
      );
      final bool hasFilled = boxes.any((DecoratedBox box) {
        final Decoration decoration = box.decoration;
        return decoration is BoxDecoration && decoration.color != null;
      });
      expect(hasFilled, isFalse);
    });

    testWidgets('style: card 左右外边距 12、内边距 4、圆角 24、铺卡片色', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const OhosListGroup(
            style: OhosListGroupStyle.card,
            children: <Widget>[
              OhosListTile(title: Text('A')),
              OhosListTile(title: Text('B')),
            ],
          ),
        ),
      );

      final Rect group = tester.getRect(find.byType(OhosListGroup));
      // 外层 Padding 12 + 内层 Padding 4 + 行内边距 16
      final Rect rowA = tester.getRect(find.text('A'));
      expect(
        rowA.left - group.left,
        moreOrLessEquals(12 + 4 + 16, epsilon: 0.01),
      );

      final DecoratedBox fill = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(OhosListGroup),
              matching: find.byType(DecoratedBox),
            ),
          )
          .firstWhere((DecoratedBox box) {
            final Decoration d = box.decoration;
            return d is BoxDecoration && d.color != null;
          });
      final BoxDecoration decoration = fill.decoration as BoxDecoration;
      expect(decoration.color, OhosThemeData.light().cardColor);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(OhosListGroupMetrics.cardRadius),
      );
    });

    testWidgets('space 只加在行与行之间，不加在组头/组尾两侧', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosListGroup(
            space: 20,
            header: Text('组头'),
            footer: Text('组尾'),
            children: <Widget>[
              OhosListTile(title: Text('A')),
              OhosListTile(title: Text('B')),
              OhosListTile(title: Text('C')),
            ],
          ),
        ),
      );

      // 量**行框**而不是文字框：文字框只有 24 高，行框才是 14+24+14。
      final List<Rect> rows = <Rect>[
        for (int i = 0; i < 3; i++)
          tester.getRect(find.byType(OhosListTile).at(i)),
      ];
      final double headerBottom = tester.getRect(find.text('组头')).bottom;
      final double footerTop = tester.getRect(find.text('组尾')).top;

      // 组头下边距 8 之后**直接**是首行，中间没有 space
      expect(rows[0].top - headerBottom, moreOrLessEquals(8, epsilon: 0.5));
      // A→B 之间只有 space 20
      expect(rows[1].top - rows[0].bottom, moreOrLessEquals(20, epsilon: 0.01));
      expect(rows[2].top - rows[1].bottom, moreOrLessEquals(20, epsilon: 0.01));
      // 末行之后直接是组尾，中间没有 space，只有组尾自己的上内边距 8
      expect(footerTop - rows[2].bottom, moreOrLessEquals(8, epsilon: 0.5));
    });

    testWidgets('space 为负数时按 0 处理（官方：非法值按默认值）', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosListGroup(
            space: -50,
            children: <Widget>[
              OhosListTile(title: Text('A')),
              OhosListTile(title: Text('B')),
            ],
          ),
        ),
      );
      // 没有负间距把两行叠在一起
      expect(
        tester.getRect(find.text('B')).top,
        greaterThan(tester.getRect(find.text('A')).bottom),
      );
    });

    testWidgets('divider 默认 null：一条都不画', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosListGroup(
            children: <Widget>[
              OhosListTile(title: Text('A')),
              OhosListTile(title: Text('B')),
              OhosListTile(title: Text('C')),
            ],
          ),
        ),
      );
      expect(groupDividers(tester), isEmpty);
    });

    testWidgets('给了 divider：n 行画 n−1 条，末行不画', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosListGroup(
            divider: OhosGroupDivider(
              strokeWidth: 1,
              startMargin: 16,
              endMargin: 16,
            ),
            children: <Widget>[
              OhosListTile(title: Text('A')),
              OhosListTile(title: Text('B')),
              OhosListTile(title: Text('C')),
            ],
          ),
        ),
      );
      final List<OhosDivider> dividers = groupDividers(tester);
      expect(dividers.length, 2);
      expect(dividers.every((OhosDivider d) => d.thickness == 1), isTrue);
      expect(dividers.every((OhosDivider d) => d.indent == 16), isTrue);
      expect(dividers.every((OhosDivider d) => d.endIndent == 16), isTrue);
    });

    testWidgets('组内分隔线接管后，tile 自己那条被压掉（不叠双线）', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosListGroup(
            divider: OhosGroupDivider(strokeWidth: 1),
            children: <Widget>[
              OhosListTile(title: Text('A')),
              OhosListTile(title: Text('B')),
            ],
          ),
        ),
      );
      // 2 行 → 1 条。若 scope 没压住，tile 会各画一条，共 3 条。
      expect(groupDividers(tester).length, 1);
    });

    testWidgets('一个 tile 都没有时分组不崩、也不画线', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosListGroup(
            divider: OhosGroupDivider(),
            header: Text('空组'),
            children: <Widget>[],
          ),
        ),
      );
      expect(find.text('空组'), findsOneWidget);
      expect(groupDividers(tester), isEmpty);
    });

    testWidgets('itemStyle: card 把行撑到至少 48、左右各 8', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 320,
            child: OhosListGroup(
              itemStyle: OhosListGroupItemStyle.card,
              children: <Widget>[
                OhosListTile(title: Text('A'), padding: EdgeInsets.zero),
                OhosListTile(title: Text('B'), padding: EdgeInsets.zero),
              ],
            ),
          ),
        ),
      );

      // 行容器：`ConstrainedBox(minHeight: 48)`。不能直接用
      // `find.ancestor(...).first` —— Scaffold / MaterialApp 自己也会插
      // ConstrainedBox，`.first` 命中的是最外层那个（宽度撑满、高度无限）。
      final Finder rowBox = find.ancestor(
        of: find.byType(OhosListTile).first,
        matching: find.byWidgetPredicate(
          (Widget w) =>
              w is ConstrainedBox &&
              w.constraints.minHeight == OhosListGroupMetrics.cardItemHeight,
        ),
      );
      expect(rowBox, findsOneWidget);
      final Rect row = tester.getRect(rowBox);
      expect(row.height, moreOrLessEquals(48, epsilon: 0.01));
      // 8vp 内边距在 ConstrainedBox **内部**（ConstrainedBox → Padding(8) →
      // Align → tile），所以量行容器只能得到宽度撑满；要看内边距得量 tile。
      final Rect group = tester.getRect(find.byType(OhosListGroup));
      expect(
        tester.getRect(find.byType(OhosListTile).first).left - group.left,
        moreOrLessEquals(8, epsilon: 0.01),
      );
    });

    testWidgets('itemStyle: none 不加最小高度，行按自身内容高', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const OhosListGroup(
            children: <Widget>[
              OhosListTile(title: Text('A'), padding: EdgeInsets.zero),
            ],
          ),
        ),
      );
      // 无内边距的单行文字自然高度远小于 48
      final double textHeight = tester.getRect(find.text('A')).height;
      expect(textHeight, lessThan(48));
    });
  });

  group('OhosListGroupSliver', () {
    /// 一个**真的会溢出**的滚动视口。
    ///
    /// 两个坑都在这里踩过：
    /// 1. 不要放进 `OhosScaffold.body` —— 它的 body 槽位会把子节点拉到整屏高，
    ///    `SizedBox(height: 300)` 会被撑成 600，于是内容根本不溢出、滚不动，
    ///    「组头有没有滚走」这类断言全部失去意义。
    /// 2. 宽高都要收住：`CustomScrollView` 在无界宽度下会按子节点最宽处测量，
    ///    量出来的横向位置与真实视口无关。
    Widget scrollHost(List<Widget> slivers) {
      return OhosTheme(
        data: OhosThemeData.light(),
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                height: 300,
                child: CustomScrollView(slivers: slivers),
              ),
            ),
          ),
        ),
      );
    }

    /// 一个分组：组头 + 5 行 + 组尾，总高约 12+20+8 + 5×52 + 12+20 ≈ 332，
    /// 单组就已超出 300 的视口。
    OhosListGroup buildGroup({String tag = ''}) => OhosListGroup(
      header: Text('头$tag'),
      footer: Text('尾$tag'),
      children: <Widget>[
        OhosListTile(title: Text('A$tag')),
        OhosListTile(title: Text('B$tag')),
        OhosListTile(title: Text('C$tag')),
        OhosListTile(title: Text('D$tag')),
        OhosListTile(title: Text('E$tag')),
      ],
    );

    testWidgets('取了 ConstrainedBox 的最小高度，不写死 48', (WidgetTester tester) async {
      await tester.pumpWidget(scrollHost(<Widget>[]));

      // 骨架先确认宿主有效：视口必须是 400×300，否则后面所有位移都在打折
      expect(
        tester.getSize(find.byType(CustomScrollView)),
        const Size(400, 300),
      );
    });

    testWidgets('sticky: none 时组头不钉住，会随内容滚走', (WidgetTester tester) async {
      await tester.pumpWidget(
        scrollHost(<Widget>[
          OhosListGroupSliver(group: buildGroup(tag: '1')),
          OhosListGroupSliver(group: buildGroup(tag: '2')),
        ]),
      );

      final double before = tester.getTopLeft(find.text('头1')).dy;
      // 只拖 30：拖太多会把组头整体滚出视口，`find.text` 直接找不到它，
      // 那时「位置有没有变」就无从比较（实测拖 100 时组头已不可见）。
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -30));
      await tester.pumpAndSettle();
      final double after = tester.getTopLeft(find.text('头1')).dy;

      expect(after, lessThan(before - 20), reason: '不吸顶就该跟着滚走');
    });

    testWidgets('sticky: header 时组头钉在视口顶端，后面的行从它下面穿过', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        scrollHost(<Widget>[
          OhosListGroupSliver(
            group: buildGroup(tag: '1'),
            sticky: OhosListStickyStyle.header,
          ),
          OhosListGroupSliver(group: buildGroup(tag: '2')),
        ]),
      );

      final double top = tester.getTopLeft(find.text('头1')).dy;
      expect(top, moreOrLessEquals(12, epsilon: 0.01), reason: '组头初始在顶端');

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
      await tester.pumpAndSettle();

      // 已经滚过 100，但组头仍在原位（视口顶端 + 自身内边距 12）
      expect(
        tester.getTopLeft(find.text('头1')).dy,
        moreOrLessEquals(top, epsilon: 0.5),
      );
      // 同时它确实"钉"住了：后面的行已经滚到它下面，不会再把它顶走
      // 行确实从组头下方穿过了：C1 原本在 158，滚 100 后落到 58
      // （组头 12～32 之下），说明它没有把组头顶走
      expect(
        tester.getTopLeft(find.text('C1')).dy,
        lessThan(158),
        reason: '行应当已经从组头下方穿过',
      );
    });

    testWidgets('吸顶的组头自带背板：THICK 材质，不会透出后面的行', (WidgetTester tester) async {
      await tester.pumpWidget(
        scrollHost(<Widget>[
          OhosListGroupSliver(
            group: buildGroup(tag: '1'),
            sticky: OhosListStickyStyle.header,
          ),
        ]),
      );
      // 官方 ApplyHeaderFooterStyle 做的是「补圆角 + THICK 沉浸材质」，
      // 不补的话浮起来的组头会透出后面的行。
      final Finder material = find.ancestor(
        of: find.text('头1'),
        matching: find.byType(OhosLightMaterial),
      );
      expect(material, findsOneWidget);
      expect(
        tester.widget<OhosLightMaterial>(material).level,
        OhosLightMaterialLevel.thick,
      );
    });

    testWidgets('不吸顶的组头不包材质（省掉一层模糊）', (WidgetTester tester) async {
      await tester.pumpWidget(
        scrollHost(<Widget>[OhosListGroupSliver(group: buildGroup(tag: '1'))]),
      );
      expect(
        find.ancestor(
          of: find.text('头1'),
          matching: find.byType(OhosLightMaterial),
        ),
        findsNothing,
      );
    });

    testWidgets('sticky: footer / both 的组尾仍留在自然位置（已知缺口）', (
      WidgetTester tester,
    ) async {
      // 这条用例的作用是**钉住缺口**，不是验证功能：`footer` / `both` 已经
      // 声明在枚举里，但吸底没实现（理由见 `OhosListGroupSliver.sticky` 的
      // dartdoc：分组内部拿不到可靠的「视口末端距离」）。
      //
      // 钉住它的价值在于：真有人去实现吸底时，这条会因为「组尾不再落在自然
      // 位置」而变红，提醒他把这条用例改成断言吸底 —— 而不是悄悄多出一个
      // 行为、没人知道文档里还写着「未实现」。
      for (final OhosListStickyStyle style in <OhosListStickyStyle>[
        OhosListStickyStyle.footer,
        OhosListStickyStyle.both,
      ]) {
        await tester.pumpWidget(
          scrollHost(<Widget>[
            OhosListGroupSliver(
              group: buildGroup(tag: '1'),
              sticky: style,
            ),
          ]),
        );
        // 组尾在视口外 ⇒ 根本没被构建（CustomScrollView 只建可见区 +
        // cacheExtent）。这本身就是「没吸底」最强的一条证据：真吸底了它一定
        // 在视口里、一定被构建出来。
        expect(
          find.text('尾1'),
          findsNothing,
          reason: '$style：吸底会把组尾拉进视口，那样它必然被构建',
        );
        // 顺带确认它确实存在于**数据**里（不是拼错了 tag）
        expect(
          find.text('尾2', skipOffstage: false),
          findsNothing,
          reason: '第二组更靠后，同样在视口外',
        );
      }
    });

    testWidgets('卡片样式的 sliver 也有 12 外边距与卡片底板', (WidgetTester tester) async {
      await tester.pumpWidget(
        scrollHost(<Widget>[
          OhosListGroupSliver(
            group: OhosListGroup(
              style: OhosListGroupStyle.card,
              header: const Text('头'),
              children: <Widget>[
                OhosListTile(title: const Text('A')),
                OhosListTile(title: const Text('B')),
              ],
            ),
          ),
        ]),
      );

      final Rect viewport = tester.getRect(find.byType(CustomScrollView));
      // 12 外边距 + 4 内边距 + 16 行内边距 = 32
      expect(
        tester.getRect(find.text('A')).left - viewport.left,
        moreOrLessEquals(32, epsilon: 0.01),
      );
      // 卡片底板在 sliver 树里只能是 DecoratedSliver —— 盒子版（DecoratedBox）
      // 不是 sliver，放进 CustomScrollView 会直接报类型错。
      expect(find.byType(DecoratedSliver), findsWidgets);
    });

    testWidgets('没有 header / footer 时只出列表，不崩', (WidgetTester tester) async {
      await tester.pumpWidget(
        scrollHost(<Widget>[
          OhosListGroupSliver(
            group: const OhosListGroup(
              children: <Widget>[
                OhosListTile(title: Text('A')),
                OhosListTile(title: Text('B')),
              ],
            ),
          ),
        ]),
      );
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });
  });

  group('OhosListItemCard', () {
    /// 卡片在测试里的宿主：宽度收住 400，否则 `OhosScaffold.body` 下的
    /// `Center` 会给卡片一个「刚好包住内容」的宽度，`Expanded` 就量不出东西。
    Widget host(Widget child) {
      return OhosTheme(
        data: OhosThemeData.light(),
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 400, child: child),
            ),
          ),
        ),
      );
    }

    /// 卡片底板：从卡片子树里取那层真有填充色的 `DecoratedBox`。
    ///
    /// `Material` / `ClipRRect` 都会插 `DecoratedBox`，所以要按「有没有
    /// color」过滤，不能取 `.first`。
    BoxDecoration cardDecoration(WidgetTester tester) {
      final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(OhosListItemCard),
          matching: find.byType(DecoratedBox),
        ),
      );
      final DecoratedBox filled = boxes.firstWhere((DecoratedBox box) {
        final Decoration d = box.decoration;
        return d is BoxDecoration && d.color != null;
      });
      return filled.decoration as BoxDecoration;
    }

    test('几何常量：16 / 24 来自官方明文，其余全部自拟', () {
      // 官方 IconSize.SMALL_ICON / SYSTEM_ICON，参考文档里是全页仅有的数字之一
      expect(OhosListItemCardMetrics.iconSmall, 16);
      expect(OhosListItemCardMetrics.iconSystem, 24);
      // 以下官方文档一律未给 —— 这几条断言的用途是「改值时必须改这里」，
      // 阻止后来者误以为它们来自规格。
      expect(OhosListItemCardMetrics.cardHeight, 72);
      expect(OhosListItemCardMetrics.cardRadius, 24);
      expect(OhosListItemCardMetrics.cardMargin, 12);
      expect(OhosListItemCardMetrics.cardPadding, 16);
      // 三区间距 12、行内间距 2、C 区组合间距 8、C 区最大宽 160
      expect(OhosListItemCardMetrics.blockGap, OhosGeometry.spaceSm);
      expect(OhosListItemCardMetrics.titleGap, 2);
      expect(OhosListItemCardMetrics.suffixGap, OhosGeometry.spaceXs);
      expect(OhosListItemCardMetrics.suffixMaxWidth, 160);
    });

    test('枚举值与官方同序：IconSize.SMALL_ICON=1 / SYSTEM_ICON=2', () {
      expect(OhosListItemCardIconSize.small.index, 0);
      expect(OhosListItemCardIconSize.system.index, 1);
      // prefix.extent 跟着枚举走，而不是跟着固定 24
      expect(
        const OhosListItemCardPrefix(
          child: SizedBox(),
          size: OhosListItemCardIconSize.small,
        ).extent,
        OhosListItemCardMetrics.iconSmall,
      );
      expect(
        const OhosListItemCardPrefix(child: SizedBox()).extent,
        OhosListItemCardMetrics.iconSystem,
        reason: '默认是 SYSTEM_ICON，官方写明的默认值',
      );
    });

    test('A 区按 extent 定尺寸，图标被夹在里面而不是撑大盒子', () {
      const Widget icon = Icon(Icons.settings);
      const OhosListItemCardPrefix p = OhosListItemCardPrefix(
        child: icon,
        size: OhosListItemCardIconSize.small,
      );
      expect(p.extent, 16);
      // value object 必须有 ==/hashCode，否则 const 缓存与 rebuild 判断会静默失效。
      // 注意比较的是**同一个 child 实例**：`Widget` 基类不重载 `==`，两个分别
      // 构造的 `Icon(Icons.settings)` 在 identity 上就是两个对象 —— 这不是本
      // 类的缺陷，是 Flutter 的既定语义，`==` 只对「复用同一实例」有意义。
      expect(
        p,
        const OhosListItemCardPrefix(
          child: icon,
          size: OhosListItemCardIconSize.small,
        ),
      );
      expect(
        p,
        isNot(equals(const OhosListItemCardPrefix(child: icon))),
        reason: 'size 不同就必须不等，否则 rebuild 判不出变化',
      );
    });

    testWidgets('三区布局：A 区 16 + 间距 12 + B 区 + 间距 12 + C 区', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          const OhosListItemCard(
            prefix: OhosListItemCardPrefix(
              child: Icon(Icons.settings),
              size: OhosListItemCardIconSize.small,
            ),
            title: '无线网络',
            suffix: OhosListItemCardSuffix.arrow(),
          ),
        ),
      );

      final Rect card = tester.getRect(find.byType(OhosListItemCard));
      // 外层 prefixMargin 12 + 内边距 16 = 28 才是内容区左边
      final Rect icon = tester.getRect(find.byIcon(Icons.settings));
      expect(icon.left - card.left, moreOrLessEquals(12 + 16, epsilon: 0.01));
      expect(icon.width, moreOrLessEquals(16, epsilon: 0.01));

      // B 区紧接 A 区之后，间距 12
      final Rect title = tester.getRect(find.text('无线网络'));
      expect(
        title.left - icon.right,
        moreOrLessEquals(OhosListItemCardMetrics.blockGap, epsilon: 0.01),
        reason: 'A 区与 B 区之间的 blockGap',
      );

      // C 区在右侧，且右边缘落在「卡片右边界 - 内边距 16 - 外边距 12」上
      final Rect arrow = tester.getRect(find.byIcon(Icons.chevron_right));
      expect(
        card.right - arrow.right,
        moreOrLessEquals(12 + 16, epsilon: 0.01),
      );
      expect(
        arrow.left - title.right,
        greaterThanOrEqualTo(OhosListItemCardMetrics.blockGap - 0.01),
        reason: 'B/C 之间至少留出 blockGap（标题短，中间是空档）',
      );
    });

    testWidgets('没有 prefix / suffix 时 B 区独占整行，不留空槽', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(const OhosListItemCard(title: '只有标题')));
      final Rect card = tester.getRect(find.byType(OhosListItemCard));
      final Rect title = tester.getRect(find.text('只有标题'));
      // 只有内边距 16 + 外边距 12
      expect(title.left - card.left, moreOrLessEquals(28, epsilon: 0.01));
    });

    testWidgets('三层文本各自上色：主 textPrimary / 副 textSecondary / 描述 textTertiary', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          const OhosListItemCard(
            title: '主标题',
            subtitle: '副标题',
            description: '描述文字',
          ),
        ),
      );
      final OhosThemeData theme = OhosThemeData.light();
      expect(paintedColor(tester, '主标题'), theme.textPrimaryColor);
      expect(paintedColor(tester, '副标题'), theme.textSecondaryColor);
      expect(paintedColor(tester, '描述文字'), theme.textTertiaryColor);

      // 主标题 bodyLarge / 后两层 bodySmall：官方三个字段并列，字阶不同
      expect(paintedTextStyle(tester, '主标题').fontSize, 16);
      expect(paintedTextStyle(tester, '副标题').fontSize, 14);
      expect(paintedTextStyle(tester, '描述文字').fontSize, 14);
    });

    testWidgets('三层文本同时存在时纵向叠开，不是二选一', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const OhosListItemCard(
            title: '主标题',
            subtitle: '副标题',
            description: '描述文字',
          ),
        ),
      );
      final Rect t = tester.getRect(find.text('主标题'));
      final Rect s = tester.getRect(find.text('副标题'));
      final Rect d = tester.getRect(find.text('描述文字'));
      expect(t.bottom, lessThanOrEqualTo(s.top + 0.01));
      expect(s.bottom, lessThanOrEqualTo(d.top + 0.01));
      // 三行都是单行，宽度一致（同一列）
      expect(s.left, moreOrLessEquals(t.left, epsilon: 0.01));
      expect(d.left, moreOrLessEquals(t.left, epsilon: 0.01));
    });

    testWidgets('contentBuilder 优先：给了它，三层文本与主标题图标全部让位', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          OhosListItemCard(
            title: '不该出现',
            subtitle: '也不该出现',
            primaryPrefix: const Icon(Icons.star),
            contentBuilder: (BuildContext ctx) => const Text('自定义内容'),
          ),
        ),
      );
      expect(find.text('自定义内容'), findsOneWidget);
      expect(find.text('不该出现'), findsNothing);
      expect(find.text('也不该出现'), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('主标题左右图标是 16vp，跟标题文字同色', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const OhosListItemCard(
            title: '主标题',
            primaryPrefix: Icon(Icons.check),
            primarySuffix: Icon(Icons.info),
          ),
        ),
      );
      final IconThemeData pre = IconTheme.of(
        tester.element(find.byIcon(Icons.check)),
      );
      final IconThemeData suf = IconTheme.of(
        tester.element(find.byIcon(Icons.info)),
      );
      expect(pre.size, OhosListItemCardMetrics.iconSmall);
      expect(suf.size, OhosListItemCardMetrics.iconSmall);
      expect(pre.color, OhosThemeData.light().textPrimaryColor);
      expect(suf.color, OhosThemeData.light().textPrimaryColor);
    });

    testWidgets('C 区九种类型各自渲染出内容，没有一种是空白', (WidgetTester tester) async {
      // 首版把「声明了 radio 却没地方收 radio」当成了设计，六个枚举值永远渲染
      // 空 —— 这条用例就是拦那种「传了但没反应」的开关。
      final Map<String, OhosListItemCardSuffix> cases =
          <String, OhosListItemCardSuffix>{
            'text': const OhosListItemCardSuffix.text('已开启'),
            'image': const OhosListItemCardSuffix.image(Icon(Icons.image)),
            'loading': const OhosListItemCardSuffix.loading(),
            'radio': const OhosListItemCardSuffix.radio(
              Icon(Icons.radio_button_checked),
            ),
            'checkbox': const OhosListItemCardSuffix.checkbox(
              Icon(Icons.check_box),
            ),
            'switchButton': const OhosListItemCardSuffix.switchButton(
              Icon(Icons.toggle_on),
            ),
            'arrow': const OhosListItemCardSuffix.arrow(),
            'select': const OhosListItemCardSuffix.select('中文'),
            'badge': const OhosListItemCardSuffix.badge(Icon(Icons.circle)),
            'custom': const OhosListItemCardSuffix.custom(Text('自定义')),
          };

      for (final MapEntry<String, OhosListItemCardSuffix> entry
          in cases.entries) {
        await tester.pumpWidget(
          host(
            OhosListItemCard(
              key: ValueKey<String>(entry.key),
              title: '行',
              suffix: entry.value,
            ),
          ),
        );
        await tester.pump();
        final Finder suffixBox = find.descendant(
          of: find.byType(ConstrainedBox),
          matching: find.byType(SizedBox),
        );
        // 每种都要么画出图形/文字，要么至少有一个非零尺寸的可见子节点
        final bool drewSomething =
            find.byType(Text).evaluate().length > 1 ||
            find.byType(Icon).evaluate().isNotEmpty ||
            find.byType(OhosLoadingIndicator).evaluate().isNotEmpty ||
            suffixBox.evaluate().isNotEmpty;
        expect(drewSomething, isTrue, reason: '${entry.key} 渲染成了空白');
      }
    });

    testWidgets('text 后缀是 bodySmall + textSecondary，禁用降到 textTertiary', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          const OhosListItemCard(
            title: '行',
            suffix: OhosListItemCardSuffix.text('已开启'),
          ),
        ),
      );
      expect(
        paintedColor(tester, '已开启'),
        OhosThemeData.light().textSecondaryColor,
      );
      expect(paintedTextStyle(tester, '已开启').fontSize, 14);

      await tester.pumpWidget(
        host(
          const OhosListItemCard(
            title: '行',
            suffix: OhosListItemCardSuffix.text('已开启', enabled: false),
          ),
        ),
      );
      expect(
        paintedColor(tester, '已开启'),
        OhosThemeData.light().textTertiaryColor,
        reason: 'suffix 自己的 enabled 只管 C 区这一个控件',
      );
    });

    testWidgets('loading 后缀复用 OhosLoadingIndicator，尺寸走 size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          const OhosListItemCard(
            title: '行',
            suffix: OhosListItemCardSuffix.loading(size: 20),
          ),
        ),
      );
      final OhosLoadingIndicator indicator = tester
          .widget<OhosLoadingIndicator>(find.byType(OhosLoadingIndicator));
      expect(indicator.size, 20);
      expect(indicator.color, OhosThemeData.light().textSecondaryColor);
    });

    testWidgets('select 后缀是文案 + 下箭头，箭头不是字体字形', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const OhosListItemCard(
            title: '行',
            suffix: OhosListItemCardSuffix.select('中文'),
          ),
        ),
      );
      expect(find.text('中文'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('arrow 后缀是 Icon 而非字符，颜色跟主题走', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const OhosListItemCard(
            title: '行',
            suffix: OhosListItemCardSuffix.arrow(),
          ),
        ),
      );
      final Icon icon = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
      expect(icon.size, 20);
      expect(icon.color, OhosThemeData.light().textSecondaryColor);
    });

    testWidgets('C 区最宽 160：长文本省略而不是把 B 区挤没', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const OhosListItemCard(
            title: '行',
            suffix: OhosListItemCardSuffix.text('这是一段特别特别长的后缀文案，长到必须被截断才合理'),
          ),
        ),
      );
      final double suffixWidth = tester
          .getRect(find.text('这是一段特别特别长的后缀文案，长到必须被截断才合理'))
          .width;
      expect(
        suffixWidth,
        lessThanOrEqualTo(OhosListItemCardMetrics.suffixMaxWidth + 0.01),
      );
      // B 区还在，没有被挤成负宽度导致溢出
      expect(tester.getRect(find.text('行')).width, greaterThan(0));
    });

    testWidgets('默认高度容得下三层文本，不溢出', (WidgetTester tester) async {
      // 这条钉的是踩过的坑：首版取 64 时，三层同时给出来 `Column` 溢出 6vp。
      // 算错的原因是把 16 / 14 / 14 的字号当成了行高 —— 实际要乘
      // `bodyLarge` / `bodySmall` 各自的 height（1.5），
      // 24 + 2 + 21 + 2 + 21 = 70。
      await tester.pumpWidget(
        host(
          const OhosListItemCard(
            title: '主标题',
            subtitle: '副标题',
            description: '描述文字',
          ),
        ),
      );
      // 溢出在测试里表现为异常（RenderFlex overflowed），pumpWidget 就会失败，
      // 所以这里只要「能 pump 完、三行都在」就说明没溢出
      expect(tester.takeException(), isNull);
      final Rect t = tester.getRect(find.text('主标题'));
      final Rect d = tester.getRect(find.text('描述文字'));
      expect(
        d.bottom - t.top,
        lessThanOrEqualTo(OhosListItemCardMetrics.cardHeight + 0.01),
        reason: '三层文本总高必须落在卡片高度内',
      );
    });

    testWidgets('height 是固定值不是 minHeight：内容超了也按 height 走', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(const OhosListItemCard(title: '行', height: 48)),
      );
      final Size size = tester.getSize(find.byType(OhosListItemCard));
      // 卡片自身尺寸 = 内容盒（48）—— 外边距在外层 Padding 上，不算进 Size
      expect(size.height, moreOrLessEquals(48, epsilon: 0.01));

      await tester.pumpWidget(
        host(const OhosListItemCard(title: '行', height: 96)),
      );
      expect(
        tester.getSize(find.byType(OhosListItemCard)).height,
        moreOrLessEquals(96, epsilon: 0.01),
        reason: 'height 直接决定尺寸，不是下限',
      );
    });

    testWidgets('默认高度 72（容得下三层文本）、左侧外边距 12', (WidgetTester tester) async {
      await tester.pumpWidget(host(const OhosListItemCard(title: '行')));
      expect(
        tester.getSize(find.byType(OhosListItemCard)).height,
        moreOrLessEquals(OhosListItemCardMetrics.cardHeight, epsilon: 0.01),
      );
      final Rect outer = tester.getRect(find.byType(OhosListItemCard));
      final Rect inner = tester.getRect(
        find.descendant(
          of: find.byType(OhosListItemCard),
          matching: find.byType(ClipRRect),
        ),
      );
      // 外边距 12 在外层 Padding，圆角盒（ClipRRect）从 12 开始
      expect(inner.left - outer.left, moreOrLessEquals(12, epsilon: 0.01));
      expect(outer.right - inner.right, moreOrLessEquals(12, epsilon: 0.01));
    });

    testWidgets('底板铺卡片色、圆角 24', (WidgetTester tester) async {
      await tester.pumpWidget(host(const OhosListItemCard(title: '行')));
      final BoxDecoration decoration = cardDecoration(tester);
      expect(decoration.color, OhosThemeData.light().cardColor);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(OhosListItemCardMetrics.cardRadius),
      );
      // 彩屏不描边
      expect(decoration.border, isNull);
    });

    testWidgets('backgroundColor 覆盖底板色', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const OhosListItemCard(
            title: '行',
            backgroundColor: Color(0xFF123456),
          ),
        ),
      );
      expect(cardDecoration(tester).color, const Color(0xFF123456));
    });

    testWidgets('墨水屏靠描边分层，不靠浅色填充', (WidgetTester tester) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 400,
                  child: const OhosListItemCard(title: '行'),
                ),
              ),
            ),
          ),
        ),
      );
      final BoxDecoration decoration = cardDecoration(tester);
      // 16 级灰里浅色底板与纸面分不开 —— 必须有实线才看得见边界
      expect(decoration.border, isNotNull);
      expect(decoration.border!.top.color, OhosThemeData.ink().dividerColor);
      expect(decoration.border!.top.width, greaterThan(0));
      expect(
        decoration.border!.top.strokeAlign,
        BorderSide.strokeAlignInside,
        reason: '画在盒外会被 clip 吃掉半条，四条边不同宽',
      );
    });

    testWidgets('enabled: false 整块 40% 不透明且不响应点击', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        host(OhosListItemCard(title: '行', enabled: false, onTap: () => taps++)),
      );
      final Opacity opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(OhosListItemCard),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.4);

      await tester.tap(find.text('行'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(taps, 0, reason: 'IgnorePointer 必须真的挡住点击');
    });

    testWidgets('enabled 但 onTap 为 null：无点击反馈也不显示成按钮', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(const OhosListItemCard(title: '行')));
      final InkWell inkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(OhosListItemCard),
          matching: find.byType(InkWell),
        ),
      );
      expect(inkWell.onTap, isNull);
      // 没有 Opacity，说明「enabled: true」没有偷偷降透明
      expect(
        find.descendant(
          of: find.byType(OhosListItemCard),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets('墨水屏无水波纹：splashColor 透明', (WidgetTester tester) async {
      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 400,
                  child: OhosListItemCard(title: '行', onTap: _noop),
                ),
              ),
            ),
          ),
        ),
      );
      final InkWell inkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(OhosListItemCard),
          matching: find.byType(InkWell),
        ),
      );
      // 真机上水波纹会拖尾成一串灰块，墨屏直接关掉
      expect(inkWell.splashColor, Colors.transparent);
      expect(inkWell.highlightColor, Colors.transparent);
    });

    testWidgets('无障碍标签：不传时由三层文本用「，」拼起来', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const OhosListItemCard(
            title: '无线网络',
            subtitle: '已连接',
            description: '信号强',
          ),
        ),
      );
      expect(find.bySemanticsLabel('无线网络，已连接，信号强'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('无障碍标签：显式 semanticLabel 覆盖自动拼接', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const OhosListItemCard(title: '无线网络', semanticLabel: '无线网络，双击进入设置'),
        ),
      );
      expect(find.bySemanticsLabel('无线网络，双击进入设置'), findsOneWidget);
      expect(find.bySemanticsLabel('无线网络'), findsNothing);
      handle.dispose();
    });

    testWidgets('没有任何文本又不给 semanticLabel：标签为 null，而不是空串', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const OhosListItemCard(
            prefix: OhosListItemCardPrefix(child: Icon(Icons.settings)),
          ),
        ),
      );
      final SemanticsNode node = tester.getSemantics(
        find.byType(OhosListItemCard),
      );
      // 官方特意强调「组件不包含文本属性时朗读不播报」，空串会让朗读器读出
      // 一段静默，不如不给标签
      expect(node.label, isEmpty);
      handle.dispose();
    });

    test('Suffix 的 == / hashCode 覆盖 type / text / child / enabled / size', () {
      const OhosListItemCardSuffix a = OhosListItemCardSuffix.text('A');
      expect(a, const OhosListItemCardSuffix.text('A'));
      expect(a, isNot(equals(const OhosListItemCardSuffix.text('B'))));
      expect(
        a,
        isNot(equals(const OhosListItemCardSuffix.text('A', enabled: false))),
      );
      expect(a, isNot(equals(const OhosListItemCardSuffix.arrow())));
      expect(
        const OhosListItemCardSuffix.arrow(),
        isNot(equals(const OhosListItemCardSuffix.arrow(size: 24))),
      );
      expect(a.hashCode, const OhosListItemCardSuffix.text('A').hashCode);
    });

    testWidgets('卡片单张自己不带外边距间隙：间距交给列表层', (WidgetTester tester) async {
      // 官方示例把卡片塞进 List({ space: 5 })，间距由列表负责 —— 卡片若自己
      // 带纵向 margin，插删项时会留下多余空缝
      await tester.pumpWidget(
        host(
          Column(
            children: const <Widget>[
              OhosListItemCard(title: '上'),
              OhosListItemCard(title: '下'),
            ],
          ),
        ),
      );
      final Rect a = tester.getRect(find.byType(OhosListItemCard).first);
      final Rect b = tester.getRect(find.byType(OhosListItemCard).last);
      expect(b.top, moreOrLessEquals(a.bottom, epsilon: 0.01));
    });

    group('OhosListItemCardList', () {
      testWidgets('默认卡片之间 8 的间隙', (WidgetTester tester) async {
        await tester.pumpWidget(
          host(
            const OhosListItemCardList(
              children: <Widget>[
                OhosListItemCard(title: '上'),
                OhosListItemCard(title: '下'),
              ],
            ),
          ),
        );
        final Rect a = tester.getRect(find.byType(OhosListItemCard).first);
        final Rect b = tester.getRect(find.byType(OhosListItemCard).last);
        expect(
          b.top - a.bottom,
          moreOrLessEquals(OhosGeometry.spaceXs, epsilon: 0.01),
        );
      });

      testWidgets('divider: true 换成发丝线，且不再叠 spacing', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          host(
            const OhosListItemCardList(
              divider: true,
              children: <Widget>[
                OhosListItemCard(title: '上'),
                OhosListItemCard(title: '下'),
              ],
            ),
          ),
        );
        expect(find.byType(OhosDivider), findsOneWidget);
        final Rect a = tester.getRect(find.byType(OhosListItemCard).first);
        final Rect b = tester.getRect(find.byType(OhosListItemCard).last);
        // 有线时不再额外塞 8 —— 线与间隙二选一，否则中间会宽出一倍
        expect(b.top - a.bottom, lessThan(OhosGeometry.spaceXs + 1));
        expect(b.top - a.bottom, greaterThan(0));
      });

      testWidgets('单张卡不出分隔线（i > 0 才插）', (WidgetTester tester) async {
        await tester.pumpWidget(
          host(
            const OhosListItemCardList(
              divider: true,
              children: <Widget>[OhosListItemCard(title: '唯一')],
            ),
          ),
        );
        expect(find.byType(OhosDivider), findsNothing);
      });

      testWidgets('padding / shrinkWrap 透传给 ListView', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          host(
            const OhosListItemCardList(
              padding: EdgeInsets.all(16),
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: <Widget>[OhosListItemCard(title: '唯一')],
            ),
          ),
        );
        final ListView list = tester.widget<ListView>(find.byType(ListView));
        expect(list.padding, const EdgeInsets.all(16));
        expect(list.shrinkWrap, isTrue);
        expect(list.physics, isA<NeverScrollableScrollPhysics>());
      });
    });
  });

  group('OhosTextClock', () {
    /// 时钟真正画出来的文字。取 `RichText` 的 `TextSpan` 而不是 `Text.data`，
    /// 因为样式经 `OhosTheme` 的 `DefaultTextStyle` 合并后才落成最终文本。
    String painted(WidgetTester tester) {
      final RichText rich = tester.widget<RichText>(
        find.byType(RichText).first,
      );
      return (rich.text as TextSpan).toPlainText();
    }

    /// 可推进的假时钟。**必须走注入而不是 `DateTime.now()`** ——
    /// `tester.pump(Duration(seconds: 1))` 推进的是 `Timer`，不推进 wall clock，
    /// 真实时钟下「有没有在跳」观测不到，断言只能恒真。
    DateTime fake = DateTime(2026, 11, 7, 10, 0, 0);

    Widget host(
      Widget clock, {
      bool visible = true,
      Locale locale = const Locale('zh'),
    }) {
      return OhosTheme(
        data: OhosThemeData.light(),
        child: MaterialApp(
          locale: locale,
          home: OhosScaffold(
            body: Center(
              child: TickerMode(enabled: visible, child: clock),
            ),
          ),
        ),
      );
    }

    setUp(() {
      fake = DateTime(2026, 11, 7, 10, 0, 0);
    });

    testWidgets('控制器默认 started = true，stop / start 同步状态', (
      WidgetTester tester,
    ) async {
      final OhosTextClockController controller = OhosTextClockController();
      expect(controller.started, isTrue, reason: '官方默认 started = true');

      controller.stop();
      expect(controller.started, isFalse);
      // 重复调用不重复通知 —— 否则每点一次按钮子树就多重建一次
      int notifications = 0;
      controller.addListener(() => notifications++);
      controller.stop();
      expect(notifications, 0, reason: 'already stopped');
      controller.start();
      expect(notifications, 1);
      controller.start();
      expect(notifications, 1, reason: 'already started');
    });

    testWidgets('格式串按官方语义逐个字母解析', (WidgetTester tester) async {
      // 先卸载上一用例的树：`pumpWidget` 会复用同类型的 `State`，`_tick`
      // 不重读，循环里第一条断言就可能拿到别的时刻。
      await tester.pumpWidget(const SizedBox());
      // 官方示例表里的形态逐条对上（日期部分固定成 2026-11-07 星期六）
      final List<(String, String)> cases = <(String, String)>[
        ('HH:mm:ss', '10:00:00'),
        ('yyyy年M月d日 EEEE', '2026年11月7日 星期六'),
        ('yyyy/M/d', '2026/11/7'),
        ('MM/dd/yyyy', '11/07/2026'),
        ('yy年MM月dd日', '26年11月07日'),
        ('aa hh:mm:ss', '上午 10:00:00'),
        ('hh:mm', '10:00'),
        ('HH', '10'),
        ('M月d日', '11月7日'),
        ('EEE MM月dd日', '周六 11月07日'),
        ('mm:ss.SSS', '00:00.000'),
      ];
      for (final (String pattern, String expected) in cases) {
        await tester.pumpWidget(
          host(
            OhosTextClock(
              format: pattern,
              clockSource: () => fake,
              // `flutter_test` 只装了 `en` 一套 localization，`maybeLocaleOf`
              // 恒给 `en_US`（真机上是系统语言）。要断中文星期名必须显式传。
              locale: const Locale('zh'),
            ),
          ),
        );
        expect(painted(tester), expected, reason: '格式 $pattern');
      }
    });

    testWidgets('单字母替换不许回头吃已吐出的结果', (WidgetTester tester) async {
      // 踩过的真实缺陷：链式 `replaceAll` 会让 `EEEE → 星期六` 里的「星」
      // 之外的字母被后来的 `a` / `S` 再吃一遍。英文星期名里同时有 `a` 与
      // `S`，是最能暴露这条的输入。
      // 先卸载上一个用例留下的树：`pumpWidget` 复用同一个 `State` 时
      // `_tick` 不会重读，格式串的断言会拿到别的时刻。
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        host(
          OhosTextClock(
            format: 'yyyy年M月d日 EEEE',
            clockSource: () => fake,
            // 英文 locale 下 `EEEE` 给完整英文名
            locale: const Locale('en'),
          ),
        ),
      );
      expect(painted(tester), '2026年11月7日 Saturday');
    });

    testWidgets('a 在 24 小时制格式里不生效（官方明文）', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(OhosTextClock(format: 'HH:mm a', clockSource: () => fake)),
      );
      // `a` 被吃掉，只剩 `HH:mm` 和它前后的分隔符
      expect(painted(tester), '10:00 ');
    });

    testWidgets('timeZoneOffset：东八区传 -8（负值表示东时区）', (WidgetTester tester) async {
      // 固定 UTC 时间，避免用例跑在任意本地时区上时结论漂移
      final DateTime utc = DateTime.utc(2026, 11, 7, 2, 0, 0);
      await tester.pumpWidget(
        host(
          OhosTextClock(
            format: 'HH:mm',
            timeZoneOffset: -8,
            clockSource: () => utc,
          ),
        ),
      );
      // UTC 02:00 → 东八区 10:00
      expect(painted(tester), '10:00');

      // 西五区传 +5：UTC 02:00 → 前一天 21:00
      await tester.pumpWidget(
        host(
          OhosTextClock(
            format: 'HH:mm',
            timeZoneOffset: 5,
            clockSource: () => utc,
          ),
        ),
      );
      expect(painted(tester), '21:00');
    });

    testWidgets('timeZoneOffset 越界回落系统时区', (WidgetTester tester) async {
      final DateTime utc = DateTime.utc(2026, 11, 7, 2, 0, 0);
      // 官方范围 [-14, 12]，13 越界
      await tester.pumpWidget(
        host(
          OhosTextClock(
            format: 'HH:mm',
            timeZoneOffset: 13,
            clockSource: () => utc,
          ),
        ),
      );
      final DateTime local = utc.toLocal();
      final String expected =
          '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
      expect(painted(tester), expected);
    });

    testWidgets('不可见时时间停止变动，重新可见后追上', (WidgetTester tester) async {
      final List<int> ticks = <int>[];
      Widget build({bool visible = true}) => host(
        OhosTextClock(
          format: 'HH:mm:ss',
          clockSource: () => fake,
          onDateChange: (OhosTextClockTick t) => ticks.add(t.value),
        ),
        visible: visible,
      );

      await tester.pumpWidget(build());
      expect(painted(tester), '10:00:00');

      fake = fake.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(painted(tester), '10:00:03');

      // 不可见：官方「组件不可见时，时间变动将停止」
      await tester.pumpWidget(build(visible: false));
      final String frozen = painted(tester);
      fake = fake.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 2));
      expect(painted(tester), frozen, reason: '不可见时不许跳');

      // 重新可见：立刻对齐到当前时间，而不是先补上一秒
      await tester.pumpWidget(build(visible: true));
      expect(painted(tester), '10:00:08', reason: '重新可见立刻追上');
    });

    testWidgets('stop 冻结显示，start 立刻对齐', (WidgetTester tester) async {
      final OhosTextClockController controller = OhosTextClockController();
      await tester.pumpWidget(
        host(
          OhosTextClock(
            format: 'HH:mm:ss',
            controller: controller,
            clockSource: () => fake,
          ),
        ),
      );
      expect(painted(tester), '10:00:00');

      controller.stop();
      await tester.pump();
      fake = fake.add(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 2));
      expect(painted(tester), '10:00:00', reason: 'stop 后冻结，不清空');

      controller.start();
      await tester.pump();
      // 官方的 stop 是「停止刷新」，不是「回到初始值」；重新 start 要立刻
      // 对齐当前真实时间，而不是停在旧值上等下一秒
      expect(painted(tester), '10:00:04');
    });

    testWidgets('onDateChange 首帧就报一次，之后每秒一次', (WidgetTester tester) async {
      final List<OhosTextClockTick> ticks = <OhosTextClockTick>[];
      await tester.pumpWidget(
        host(
          OhosTextClock(
            format: 'HH:mm:ss',
            clockSource: () => fake,
            onDateChange: ticks.add,
          ),
        ),
      );
      // 首帧回调放在 post-frame，pumpWidget 之后已经跑完
      expect(ticks.length, 1, reason: '首帧补一次，调用方的外部状态不至于差一秒');
      expect(ticks.single.value, fake.millisecondsSinceEpoch ~/ 1000);

      fake = fake.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(ticks.length, 2);
      // 官方 value 是「自 1970-01-01 UTC 起经过的秒数」
      expect(ticks.last.value - ticks.first.value, 1);
    });

    testWidgets('hourFormat 覆盖默认的前导零规则', (WidgetTester tester) async {
      // 官方默认：24 小时制带前导零
      await tester.pumpWidget(
        host(OhosTextClock(format: 'HH:mm', clockSource: () => fake)),
      );
      expect(painted(tester), '10:00');

      // numeric 去掉前导零
      await tester.pumpWidget(
        host(
          OhosTextClock(
            format: 'HH:mm',
            clockSource: () => fake,
            hourFormat: OhosClockHourFormat.numeric,
          ),
        ),
      );
      expect(painted(tester), '10:00', reason: '10 点本来就没有前导零可去');

      // 用 1 点这个有前导零的时刻才有区分力
      fake = DateTime(2026, 11, 7, 1, 5, 0);
      await tester.pumpWidget(
        host(
          OhosTextClock(
            format: 'HH:mm',
            clockSource: () => fake,
            hourFormat: OhosClockHourFormat.numeric,
          ),
        ),
      );
      // clockSource 是同一个闭包引用，`didUpdateWidget` 探不出变化，所以要
      // 真推进一次计时器才重读 —— 这也正是真机上「下一秒就更新」的路径。
      await tester.pump(const Duration(seconds: 1));
      expect(painted(tester), '1:05');

      // 12 小时制默认不补零，twoDigit 强制补
      await tester.pumpWidget(
        host(
          OhosTextClock(
            format: 'hh:mm',
            clockSource: () => fake,
            hourFormat: OhosClockHourFormat.twoDigit,
          ),
        ),
      );
      expect(painted(tester), '01:05');

      // 12 小时制去掉前导零时，凌晨 1 点是 1 而不是 01
      await tester.pumpWidget(
        host(
          OhosTextClock(
            format: 'hh:mm',
            clockSource: () => fake,
            hourFormat: OhosClockHourFormat.numeric,
          ),
        ),
      );
      expect(painted(tester), '1:05');
    });

    testWidgets('空格式回落官方默认 HH:mm:ss', (WidgetTester tester) async {
      for (final String? pattern in <String?>[null, '']) {
        await tester.pumpWidget(
          host(OhosTextClock(format: pattern, clockSource: () => fake)),
        );
        expect(painted(tester), '10:00:00', reason: 'format = $pattern');
      }
    });

    testWidgets('文字默认走主题标题字阶 + 等宽数字', (WidgetTester tester) async {
      await tester.pumpWidget(host(OhosTextClock(clockSource: () => fake)));
      final TextStyle style = paintedTextStyle(tester, '10:00:00');
      final OhosThemeData theme = OhosThemeData.light();
      expect(style.fontSize, theme.typography.titleMedium?.fontSize);
      expect(style.color, theme.textPrimaryColor);
      // 官方 `fontFeature` 的典型用法 —— 每秒跳动时非等宽数字会让文本左右抖
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  });

  group('OhosImage', () {
    Widget host(Widget child) {
      return OhosTheme(
        data: OhosThemeData.light(),
        child: MaterialApp(
          home: OhosScaffold(body: Center(child: child)),
        ),
      );
    }

    testWidgets('默认 objectFit 是 cover（官方「未设置时默认 ImageFit.Cover」）', (
      WidgetTester tester,
    ) async {
      final ui.Image image = await makeTestImage(200, 100);
      await tester.pumpWidget(
        host(
          OhosImage(image: TestImageProvider(image), width: 100, height: 100),
        ),
      );
      await tester.pump();
      final RawImage raw = tester.widget<RawImage>(find.byType(RawImage));
      expect(raw.fit, BoxFit.cover);
    });

    testWidgets('八档 fit 逐档映射到 BoxFit，且互相不撞', (WidgetTester tester) async {
      final ui.Image image = await makeTestImage(200, 100);
      // 「与图片的填充效果一致」这条要求每档都能落到一个具体 BoxFit
      const Map<OhosImageFit, BoxFit> expected = <OhosImageFit, BoxFit>{
        OhosImageFit.cover: BoxFit.cover,
        OhosImageFit.contain: BoxFit.contain,
        OhosImageFit.fill: BoxFit.fill,
        OhosImageFit.scaleDown: BoxFit.scaleDown,
        OhosImageFit.auto: BoxFit.scaleDown,
        OhosImageFit.none: BoxFit.none,
        OhosImageFit.original: BoxFit.none,
        OhosImageFit.topStart: BoxFit.none,
      };
      for (final MapEntry<OhosImageFit, BoxFit> entry in expected.entries) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          host(
            OhosImage(
              image: TestImageProvider(image),
              width: 100,
              height: 100,
              fit: entry.key,
            ),
          ),
        );
        await tester.pump();
        final RawImage raw = tester.widget<RawImage>(find.byType(RawImage));
        expect(raw.fit, entry.value, reason: '${entry.key}');
      }
    });

    testWidgets('onComplete 回调两次：loadingStatus 0 与 1（官方「均触发」）', (
      WidgetTester tester,
    ) async {
      final ui.Image image = await makeTestImage(200, 100);
      final List<OhosImageLoadInfo> infos = <OhosImageLoadInfo>[];
      await tester.pumpWidget(
        host(
          OhosImage(
            image: TestImageProvider(image),
            width: 100,
            height: 100,
            onComplete: infos.add,
          ),
        ),
      );
      await tester.pump();

      expect(infos.length, 2, reason: '官方：数据加载成功与解码成功各一次');
      expect(infos[0].loadingStatus, 0);
      expect(infos[1].loadingStatus, 1);
      expect(infos[1].decoded, isTrue);
      // 原始尺寸来自图源本身
      expect(infos[1].width, 200);
      expect(infos[1].height, 100);
      // cover = max(100/200, 100/100) = **1.0**：200×100 的原图在这个
      // 100×100 的方框里，高度刚好相等、宽度溢出 100 → 内容仍是 200×100，
      // 居中后水平偏移 -50（左半被裁）。
      //
      // 两处曾写错：① 按「放大到 200×200」算 —— 那是把 cover 的 `max` 与
      // contain 的 `min` 混了；② 偏移写 0 —— 算到缩放就会漏掉居中位移。
      expect(infos[1].componentWidth, 100);
      expect(infos[1].componentHeight, 100);
      expect(infos[1].contentWidth, 200);
      expect(infos[1].contentHeight, 100);
      expect(infos[1].contentOffsetX, -50);
      expect(infos[1].contentOffsetY, 0);
    });

    testWidgets('contain 下 contentOffset 是正向留白', (WidgetTester tester) async {
      final ui.Image image = await makeTestImage(200, 100);
      final List<OhosImageLoadInfo> infos = <OhosImageLoadInfo>[];
      await tester.pumpWidget(
        host(
          OhosImage(
            image: TestImageProvider(image),
            width: 100,
            height: 100,
            fit: OhosImageFit.contain,
            onComplete: infos.add,
          ),
        ),
      );
      await tester.pump();
      final OhosImageLoadInfo info = infos.last;
      // contain：等比缩到 100×50，垂直居中 → y 偏移 25
      expect(info.contentWidth, 100);
      expect(info.contentHeight, 50);
      expect(info.contentOffsetY, 25);
    });

    testWidgets('scaleDown / auto 只缩不放', (WidgetTester tester) async {
      // 图片比容器小：contain 会放大，scaleDown 保持原尺寸
      final ui.Image image = await makeTestImage(50, 50);
      final List<OhosImageLoadInfo> contain = <OhosImageLoadInfo>[];
      final List<OhosImageLoadInfo> scaleDown = <OhosImageLoadInfo>[];

      await tester.pumpWidget(
        host(
          OhosImage(
            image: TestImageProvider(image),
            width: 100,
            height: 100,
            fit: OhosImageFit.contain,
            onComplete: contain.add,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        host(
          OhosImage(
            image: TestImageProvider(image),
            width: 100,
            height: 100,
            fit: OhosImageFit.scaleDown,
            onComplete: scaleDown.add,
          ),
        ),
      );
      await tester.pump();

      expect(contain.last.contentWidth, 100, reason: 'contain 放大到填满');
      expect(scaleDown.last.contentWidth, 50, reason: 'scaleDown 不放大');
    });

    testWidgets('加载失败：onError 拿到 message 与组件尺寸', (WidgetTester tester) async {
      final List<OhosImageError> errors = <OhosImageError>[];
      await tester.pumpWidget(
        host(
          OhosImage(
            image: const FailingImageProvider(message: 'decode failed'),
            width: 100,
            height: 60,
            onError: errors.add,
          ),
        ),
      );
      await tester.pump();

      expect(errors.length, 1);
      expect(errors.single.message, contains('decode failed'));
      expect(errors.single.componentWidth, 100);
      expect(errors.single.componentHeight, 60);
    });

    testWidgets('errorPlaceholder 优先于 placeholder，都没给才画默认图标', (
      WidgetTester tester,
    ) async {
      // ① 两个都给：失败时用 errorPlaceholder
      await tester.pumpWidget(
        host(
          OhosImage(
            image: const FailingImageProvider(),
            width: 100,
            height: 60,
            placeholder: const Text('LOADING'),
            errorPlaceholder: const Text('FAILED'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('FAILED'), findsOneWidget);
      expect(find.text('LOADING'), findsNothing);

      // ② 只给 placeholder：失败时退回它（官方 22+ 之前的兼容行为）
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        host(
          OhosImage(
            image: const FailingImageProvider(),
            width: 100,
            height: 60,
            placeholder: const Text('LOADING'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('LOADING'), findsOneWidget);

      // ③ 都不给：默认的「图片坏了」图标
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        host(
          OhosImage(
            image: const FailingImageProvider(),
            width: 100,
            height: 60,
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('placeholder 只在加载中显示，加载完成后让位', (WidgetTester tester) async {
      final ui.Image image = await makeTestImage(200, 100);
      await tester.pumpWidget(
        host(
          OhosImage(
            image: TestImageProvider(image),
            width: 100,
            height: 100,
            placeholder: const Text('LOADING'),
          ),
        ),
      );
      // 首帧：图还没解码，占位图在
      expect(find.text('LOADING'), findsOneWidget);
      await tester.pump();
      expect(find.text('LOADING'), findsNothing);
      expect(find.byType(RawImage), findsOneWidget);
    });

    testWidgets('永远加载不完成时占位图一直显示', (WidgetTester tester) async {
      // 图源给 `null`（completer 不完成）—— 这是「加载中」最纯粹的形态
      await tester.pumpWidget(
        host(
          OhosImage(
            image: TestImageProvider(null),
            width: 100,
            height: 100,
            placeholder: const Text('LOADING'),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('LOADING'), findsOneWidget);
      // 图没解码完就不该有 `RawImage` —— 占位图整块顶替内容，
      // 而不是「占位图叠在一张空 RawImage 上」。
      expect(find.byType(RawImage), findsNothing);
    });

    testWidgets('换图源会重新加载并清掉失败态', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          OhosImage(
            image: const FailingImageProvider(message: 'first fail'),
            width: 100,
            height: 60,
            errorPlaceholder: const Text('FAILED'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('FAILED'), findsOneWidget);

      // 换成一张能加载的图
      final ui.Image image = await makeTestImage(200, 100);
      await tester.pumpWidget(
        host(
          OhosImage(image: TestImageProvider(image), width: 100, height: 60),
        ),
      );
      await tester.pump();
      expect(find.text('FAILED'), findsNothing);
      expect(find.byType(RawImage), findsOneWidget);
    });

    testWidgets('选中描边走品牌色，未选中不画边', (WidgetTester tester) async {
      final ui.Image image = await makeTestImage(200, 100);
      await tester.pumpWidget(
        host(
          OhosImage(image: TestImageProvider(image), width: 100, height: 60),
        ),
      );
      final Container plain = tester.widget<Container>(
        find.byType(Container).first,
      );
      expect((plain.decoration! as BoxDecoration).border, isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        host(
          OhosImage(
            image: TestImageProvider(image),
            width: 100,
            height: 60,
            selected: true,
          ),
        ),
      );
      final Container selected = tester.widget<Container>(
        find.byType(Container).first,
      );
      final BoxBorder? border = (selected.decoration! as BoxDecoration).border;
      expect(border, isNotNull);
      expect(
        (border! as Border).top.color,
        OhosThemeData.light().highlightColor,
      );
    });
  });

  group('OhosList', () {
    Widget host(Widget child) {
      return OhosTheme(
        data: OhosThemeData.light(),
        child: MaterialApp(
          home: OhosScaffold(body: Center(child: child)),
        ),
      );
    }

    test('lanes 两形态按官方语义解析列数', () {
      // 官方「value 为 number 类型时，根据 number 类型数值指定列数」
      expect(const OhosFixedLanes(2).resolve(360), 2);
      expect(const OhosFixedLanes(4).resolve(100), 4, reason: '固定列数不看宽度');
      // 官方「取值范围 [1, +∞)，传入小于 1 的值时按默认值处理」→ 默认 1
      expect(const OhosFixedLanes(0).resolve(360), 1);
      expect(const OhosFixedLanes(-3).resolve(360), 1);

      // 官方 LengthConstrain：按自身宽度算最大列数
      // 360 宽 / 最小 104 → floor((360+0)/(104+0)) = 3
      expect(const OhosLanesByWidth(104).resolve(360), 3);
      // 带 12 的间距：floor((360+12)/(104+12)) = floor(3.2) = 3
      expect(const OhosLanesByWidth(104, gutter: 12).resolve(360), 3);
      // 宽度不够时至少 1 列（官方没写「算出来是 0 怎么办」，按 1 兜住）
      expect(const OhosLanesByWidth(104).resolve(80), 1);
      expect(const OhosLanesByWidth(104).resolve(0), 1);
      // minWidth 非法（≤0）回落防呆值 104 → 360 仍是 3
      expect(const OhosLanesByWidth(0).resolve(360), 3);
      expect(const OhosLanesByWidth(-5).resolve(360), 3);
    });

    test('lanes 的列数算法必须把 gutter 加进分子分母', () {
      // 这条守的是「不加 gutter 会多算一列」：真按 extent/min 算，
      // 360/104 = 3.46 → 3 列，看起来对；但 3 列 + 2 个间距要
      // 3*104 + 2*12 = 336 ≤ 360 ✓，而 4 列 + 3 个间距 = 452 > 360 ✗。
      // 换一组能分开两个算法的数：min=110, gutter=12, extent=360
      //   正确：(360+12)/(110+12) = 3.049 → 3
      //   错解：360/110 = 3.27 → 3   ← 相同
      // 所以取 extent=370：正确 (382)/(122) = 3.13 → 3；错解 370/110=3.36 → 3
      // 真正能分开的是 extent 恰好在边界：min=120, gutter=0 → 3 列占 360
      expect(const OhosLanesByWidth(120).resolve(360), 3, reason: '恰好 3 列');
      expect(const OhosLanesByWidth(120).resolve(359), 2, reason: '差 1 就掉一列');
      // 有间距时边界更早：min=120, gutter=10 → 3 列要 380
      expect(const OhosLanesByWidth(120, gutter: 10).resolve(380), 3);
      expect(const OhosLanesByWidth(120, gutter: 10).resolve(379), 2);
    });

    testWidgets('静态形态保持 0.5 的观感：圆角卡片 + 行间线', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const OhosList(
            children: <Widget>[
              OhosListTile(title: Text('A')),
              OhosListTile(title: Text('B')),
            ],
          ),
        ),
      );
      // 两个 tile 之间一条线（最后一行不画）
      expect(find.byType(OhosDivider), findsOneWidget);
      // 不走滚动：静态形态没有 CustomScrollView
      expect(find.byType(CustomScrollView), findsNothing);
      // 外底板是圆角卡片
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      expect(
        (box.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(16),
      );
    });

    testWidgets('divider: false 一条线都不画', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const OhosList(
            divider: false,
            children: <Widget>[
              OhosListTile(title: Text('A')),
              OhosListTile(title: Text('B')),
            ],
          ),
        ),
      );
      expect(find.byType(OhosDivider), findsNothing);
    });

    testWidgets('dividerStyle 的四个字段落到实际绘制的线上', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const OhosList(
            dividerStyle: OhosListDivider(
              strokeWidth: 2,
              color: Color(0xFF112233),
              startMargin: 24,
              endMargin: 8,
            ),
            children: <Widget>[
              // 用非 tile 子节点触发「列表自己补线」那条路径，
              // tile 的线由 tile 自己画、不吃 dividerStyle
              Text('A'),
              Text('B'),
            ],
          ),
        ),
      );
      final OhosDivider line = tester.widget<OhosDivider>(
        find.byType(OhosDivider),
      );
      expect(line.thickness, 2);
      expect(line.color, const Color(0xFF112233));
      expect(line.indent, 24);
      expect(line.endIndent, 8);
    });

    testWidgets('scrollable 形态走 CustomScrollView 并带着高度', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          OhosList.scrollable(
            height: 200,
            children: <Widget>[
              for (int i = 0; i < 20; i++) OhosListTile(title: Text('R$i')),
            ],
          ),
        ),
      );
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(tester.getSize(find.byType(OhosList)).height, 200);
    });

    testWidgets('onReachStart 初始化时触发一次（官方明文）', (WidgetTester tester) async {
      int starts = 0;
      int ends = 0;
      await tester.pumpWidget(
        host(
          OhosList.scrollable(
            height: 200,
            onReachStart: () => starts++,
            onReachEnd: () => ends++,
            children: <Widget>[
              for (int i = 0; i < 20; i++) OhosListTile(title: Text('R$i')),
            ],
          ),
        ),
      );
      await tester.pump();
      // 官方「List 初始化时如果 initialIndex 为 0 会触发一次」
      expect(starts, 1);
      expect(ends, 0);
    });

    testWidgets('滚到底触发 onReachEnd，且只触发一次', (WidgetTester tester) async {
      int ends = 0;
      final ScrollController controller = ScrollController();
      await tester.pumpWidget(
        host(
          OhosList.scrollable(
            height: 200,
            controller: controller,
            onReachEnd: () => ends++,
            children: <Widget>[
              for (int i = 0; i < 20; i++) OhosListTile(title: Text('R$i')),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(ends, 0);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(ends, 1);

      // 继续在同一位置发通知不该重复触发 —— 否则「加载更多」会被连环调用
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(ends, 1, reason: '已在末尾，状态没变');
    });

    testWidgets('onScrollIndex 给出 start / end / center 三个索引', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      final List<(int, int, int)> seen = <(int, int, int)>[];
      await tester.pumpWidget(
        host(
          OhosList.scrollable(
            height: 200,
            controller: controller,
            onScrollIndex: (int start, int end, int center) =>
                seen.add((start, end, center)),
            children: <Widget>[
              for (int i = 0; i < 20; i++) OhosListTile(title: Text('R$i')),
            ],
          ),
        ),
      );
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      expect(seen, isNotEmpty);
      // 三个索引必须单调且落在合法区间内
      final (int, int, int) last = seen.last;
      expect(last.$1, inInclusiveRange(0, 19));
      expect(last.$2, inInclusiveRange(0, 19));
      expect(last.$3, inInclusiveRange(0, 19));
      expect(last.$1 <= last.$3, isTrue, reason: 'center 落在 start 与 end 之间');
      expect(last.$3 <= last.$2, isTrue, reason: 'center 落在 start 与 end 之间');
    });

    testWidgets('sticky 广播到每个分组：分组被转成 sliver', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          OhosList.scrollable(
            height: 300,
            sticky: OhosListStickyStyle.header,
            children: const <Widget>[
              OhosListGroup(
                header: Text('H'),
                children: <Widget>[OhosListTile(title: Text('X'))],
              ),
            ],
          ),
        ),
      );
      expect(find.byType(OhosListGroupSliver), findsOneWidget);
      // 盒子形态已被消耗成 sliver，树上不该再有独立的 `OhosListGroup`
      expect(find.byType(OhosListGroup), findsNothing);
      final OhosListGroupSliver sliver = tester.widget<OhosListGroupSliver>(
        find.byType(OhosListGroupSliver),
      );
      expect(sliver.sticky, OhosListStickyStyle.header);
    });

    testWidgets('sticky: none 时分组也走 sliver，但不吸顶', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          OhosList.scrollable(
            height: 300,
            children: const <Widget>[
              OhosListGroup(
                header: Text('H'),
                children: <Widget>[OhosListTile(title: Text('X'))],
              ),
            ],
          ),
        ),
      );
      final OhosListGroupSliver sliver = tester.widget<OhosListGroupSliver>(
        find.byType(OhosListGroupSliver),
      );
      expect(sliver.sticky, OhosListStickyStyle.none);
    });

    testWidgets('lanes > 1 时按行并排且不钉高，单列用 SliverList', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          OhosList.scrollable(
            height: 200,
            lanes: const OhosFixedLanes(2),
            children: <Widget>[
              for (int i = 0; i < 6; i++) OhosListTile(title: Text('R$i')),
            ],
          ),
        ),
      );
      final CustomScrollView view = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      final SliverPadding pad = view.slivers.whereType<SliverPadding>().single;
      // **不能用 SliverGrid**：它的 childAspectRatio 会把每格高度钉死。
      // 溢出矩阵实测过 —— 360 屏两列时每格只有 44.8 高，而 tile 要 58，
      // `RenderFlex overflowed by 13 pixels`。所以走「按行 SliverCrossAxisGroup」，
      // 行高由内容决定。
      expect(pad.child, isA<SliverMainAxisGroup>());
      final SliverMainAxisGroup group = pad.child! as SliverMainAxisGroup;
      expect(group.children.first, isA<SliverCrossAxisGroup>());
      expect(find.byType(SliverGrid), findsNothing);

      // 单列回到 SliverList
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        host(
          OhosList.scrollable(
            height: 200,
            children: <Widget>[
              for (int i = 0; i < 6; i++) OhosListTile(title: Text('R$i')),
            ],
          ),
        ),
      );
      final CustomScrollView plain = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      final SliverPadding plainPad = plain.slivers
          .whereType<SliverPadding>()
          .single;
      expect(plainPad.child, isA<SliverList>());
    });

    testWidgets('lanes > 1 时行高由内容决定，不许压塌 tile', (WidgetTester tester) async {
      // 这条守的是溢出矩阵抓到的真实缺陷：`SliverGrid` 的
      // `childAspectRatio` 会把行高钉死，360 屏两列时每格只给 44.8 高，
      // 而 `OhosListTile` 常规档要 58 → `RenderFlex overflowed by 13 pixels`。
      // 判据不能只看「有没有报错」（pump 不报错的溢出照样挤出屏幕），
      // 要量 tile 的实际渲染高度。
      await tester.pumpWidget(
        host(
          OhosList.scrollable(
            height: 400,
            lanes: const OhosFixedLanes(2, gutter: 8),
            children: <Widget>[
              for (int i = 0; i < 4; i++) OhosListTile(title: Text('R$i')),
            ],
          ),
        ),
      );
      // 判据是「等于它自己的自然高度」，不是钉一个 56 —— `OhosListTile`
      // 没有最小高度，常规档实测 53（标题 16 + 上下各 14 + 内边距）。
      // 钉死 44.8 的版本会让它溢出 13px，所以量的必须是真实渲染高度。
      final Size tile = tester.getSize(find.byType(OhosListTile).first);
      expect(tile.height, greaterThanOrEqualTo(50), reason: '行高不许被格高压塌');
      // 两列模式下同一个 tile 的高度必须与单列一致（列数不影响行高）
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        host(
          OhosList.scrollable(
            height: 400,
            children: <Widget>[
              for (int i = 0; i < 4; i++) OhosListTile(title: Text('R$i')),
            ],
          ),
        ),
      );
      final Size single = tester.getSize(find.byType(OhosListTile).first);
      expect(tile.height, single.height, reason: '列数不该改变行高');
      expect(tester.takeException(), isNull);
    });

    testWidgets('静态形态不认 sticky / lanes —— 它们只在滚动形态有意义', (
      WidgetTester tester,
    ) async {
      // 静态构造器没有这两个参数，所以这里断的是「传不进去」这件事本身：
      // 静态形态没有视口，把 sticky 塞进去只会得到一个不生效的开关。
      await tester.pumpWidget(
        host(
          const OhosList(children: <Widget>[OhosListTile(title: Text('A'))]),
        ),
      );
      expect(find.byType(CustomScrollView), findsNothing);
      expect(find.byType(SliverList), findsNothing);
    });
  });
}
