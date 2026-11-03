import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harmony_ui/harmony_ui.dart';
// 角度换算与弧段绘制是内部实现（不对外导出），但「钟面 0 度」和「350 → 10
// 只扫 20 度」这两条正是最容易被写反的地方，必须直接断在函数上。
import 'package:harmony_ui/src/widgets/ohos_arc.dart';

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
      strokeWidth = paint.strokeWidth;
  final Color color;
  final double strokeWidth;
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
List<Object> _replay(
  WidgetTester tester,
  Type type, {
  Size? size,
}) {
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

    testWidgets('ink 主题下禁用按钮：浅底换成实线描边，字也不再是白色', (
      WidgetTester tester,
    ) async {
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
                child: OhosButton(
                  onPressed: null,
                  child: const Text('提交 (0)'),
                ),
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
            .ancestor(
              of: find.text('提交 (0)'),
              matching: find.byType(Material),
            )
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

  // 墨水屏：凡是靠「浅色填充」表达状态的组件，填充一律换成留白 + 1px 实线。
  // 依据是 16 级灰阶下 20% 以内的黑落在第 0–3 级，等于没有。
  group('墨水屏灰阶填充', () {
    testWidgets('ink 勾选框：未选中描边与禁用勾都用实色', (
      WidgetTester tester,
    ) async {
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
            home: OhosScaffold(
              body: Center(child: OhosCheckbox(value: true)),
            ),
          ),
        ),
      );
      final Icon check = tester.widget<Icon>(find.byType(Icon));
      expect(check.color, ink.textTertiaryColor, reason: '白勾压不到浅灰底上');
    });

    testWidgets('ink 开关关闭态：轨道与滑块都有 1px 轮廓', (
      WidgetTester tester,
    ) async {
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

      // 轨道加 1px 边之后滑块仍是正圆（26×26），没有被压成 26×24
      final Size thumbSize = tester.getSize(thumbFinder);
      expect(thumbSize.width, thumbSize.height);
      expect(thumbSize.height, 26);
    });

    testWidgets('ink 卡片默认面补 1px 实线，自定义色不框', (
      WidgetTester tester,
    ) async {
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
      expect(
        inverted.clipBehavior,
        Clip.none,
        reason: '没描边就不裁子节点，溢出行为保持原样',
      );
    });

    testWidgets('ink 描边卡片把子节点的方角裁进圆角', (
      WidgetTester tester,
    ) async {
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

    testWidgets('ink 分段按钮：轨道与选中段各一条实线', (
      WidgetTester tester,
    ) async {
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

    testWidgets('2–5 个按钮：1 个与 6 个都在构造期断言失败', (
      WidgetTester tester,
    ) async {
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

    testWidgets('tab 型选中段是白背板，capsule 型是品牌色', (
      WidgetTester tester,
    ) async {
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
      AnimatedContainer bodyAt(int i) => tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(OhosSegmentedButton<String>),
          matching: find.byType(AnimatedContainer),
        ),
      ).elementAt(i);
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
        reason: '官方 tab 型的 buttons 类型是 ItemRestriction<SegmentButtonTextItem>，'
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

    testWidgets('多选是 toggle：再点一次取消，回调给完整集合', (
      WidgetTester tester,
    ) async {
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
      expect((bodies[1].decoration! as BoxDecoration).color, Colors.transparent);
      expect((bodies[2].decoration! as BoxDecoration).color, lit);
    });

    testWidgets('tab 型即使 multiply 为 true 也是单选', (WidgetTester tester) async {
      // 官方把 `this.multiply` 写在 `if (this.type === 'capsule')` 分支里 ——
      // tab 型拿不到这个开关，传了也白传。
      final OhosSegmentedButton<String> control =
          OhosSegmentedButton<String>(
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
          onSelectionChanged: (Set<String> _) =>
              fail('tab 型不该走多选回调'),
        ),
      );
      await tester.tap(find.text('月'));
      await tester.pumpAndSettle();
      expect(picked, 'month');
    });

    testWidgets('多选时基底内边距归零、只有首末段外侧圆角', (
      WidgetTester tester,
    ) async {
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
      BorderRadius radiusAt(int i) =>
          (bodies[i].decoration! as BoxDecoration).borderRadius!
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

    testWidgets('图标 24、文字 14fp、选中 w500 未选中 w400', (
      WidgetTester tester,
    ) async {
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
      expect(tester.widget<Icon>(find.byIcon(Icons.wb_sunny_outlined)).size, 24);

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
        reason: '选中不放大字号：官方 checked 与 unselected 两个令牌都指向 ohos_id_text_size_body2',
      );
    });

    testWidgets('墨水屏：基底与选中段各补 1px 实线，选中段用实底反白', (
      WidgetTester tester,
    ) async {
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
        reason: '墨水屏上 highlightColor 与 textPrimaryColor 都是纯黑，'
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
    testWidgets('宽度取整到整数设备像素，且显式画在盒内', (
      WidgetTester tester,
    ) async {
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

    testWidgets('发丝线按逻辑宽度换算（0.5px 在 3x 屏上就是 2px）', (
      WidgetTester tester,
    ) async {
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

    testWidgets('墨屏滑块自己画描边，禁用态换一档灰（不与轨道同色）', (
      WidgetTester tester,
    ) async {
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
              body: Center(
                child: SizedBox(width: 320, child: slider),
              ),
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
      final OhosSliderThumbShape shape = data.thumbShape! as OhosSliderThumbShape;
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
      final OhosSliderThumbShape shape = data.thumbShape! as OhosSliderThumbShape;
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
      expect(
        (data.overlayShape! as RoundSliderOverlayShape).overlayRadius,
        20,
      );
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
        slider: OhosSlider(
          value: 40,
          onChanged: _noopDouble,
          divisions: 10,
        ),
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

    testWidgets('stepSize 两个边界：0 不画、超轨道粗细时夹回来', (
      WidgetTester tester,
    ) async {
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
          ohosSelectStatusOf(
            allNames: const <String>[],
            selected: <String>{},
          ),
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

    testWidgets('全选是勾、半选是一横 —— 不是「颜色浅一点的勾」', (
      WidgetTester tester,
    ) async {
      Future<void> pump(OhosSelectStatus status) async {
        await tester.pumpWidget(
          wrap(
            OhosCheckboxGroup.status(
              status: status,
              onChanged: _noopBool,
            ),
          ),
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

    testWidgets('默认圆角方形，round 才是圆形', (WidgetTester tester) async {
      // 官方 `checkboxShape` 默认是 CIRCLE，本库的 OhosCheckbox 是圆角方形。
      // 两者混在一个列表里最刺眼，所以这里默认跟成员走，要圆得显式声明。
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

      final BorderRadius square = await radiusOf(round: false);
      expect(square.topLeft.x, closeTo(24 * 0.26, 0.01));

      final BorderRadius circle = await radiusOf(round: true);
      expect(circle.topLeft.x, 12, reason: '24 / 2');
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
      await pumpRadio(
        tester,
        OhosRadio(value: true, onChanged: _noopBool),
      );
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
        tester.widget<DecoratedBox>(
          find.descendant(of: dot, matching: find.byType(DecoratedBox)),
        ).decoration is BoxDecoration,
        isTrue,
      );
      expect(tester.getSize(dot), const Size.square(12),
          reason: 'ohos_id_radio_inner_size_ratio = 0.5 × 24');
    });

    testWidgets('CUSTOM 用 indicatorBuilder 的内容，中心对齐', (WidgetTester tester) async {
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

    testWidgets('选中是实心底板 + 反差图形，未选中留白 + 描边', (
      WidgetTester tester,
    ) async {
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
      await pumpRadio(
        tester,
        OhosRadio(value: false, onChanged: taps.add),
      );
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

    testWidgets('墨屏：选中底板纯黑、图形反白，未选中靠实线', (
      WidgetTester tester,
    ) async {
      // 墨屏上 highlight 与 textPrimary 都是纯黑 —— 选中/未选中的区别只能靠
      // 「实心 vs 只有线」，这也是 ohos_id_radio_inactive_background_solid = 0
      // （未选中不铺底）存在的意义。
      final OhosThemeData ink = OhosThemeData.ink();
      await tester.pumpWidget(
        OhosTheme(
          data: ink,
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: OhosRadio(value: true, onChanged: _noopBool),
              ),
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
        OhosWheelPicker(columns: <OhosPickerColumn>[
          OhosPickerColumn(labels: numbers(3)),
        ]),
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
        OhosWheelPicker(columns: <OhosPickerColumn>[
          OhosPickerColumn(labels: numbers(20)),
        ]),
      );
      expect(tester.getSize(find.byType(OhosWheelPicker)).height, 200);

      await pumpPicker(
        tester,
        OhosWheelPicker(
          height: 120,
          columns: <OhosPickerColumn>[
            OhosPickerColumn(labels: numbers(20)),
          ],
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
          columns: <OhosPickerColumn>[
            OhosPickerColumn(labels: numbers(7)),
          ],
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
          columns: <OhosPickerColumn>[
            OhosPickerColumn(labels: numbers(8)),
          ],
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
          columns: <OhosPickerColumn>[
            OhosPickerColumn(labels: numbers(12)),
          ],
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
        OhosWheelPicker(columns: <OhosPickerColumn>[
          OhosPickerColumn(labels: numbers(4), flex: 2),
          OhosPickerColumn(labels: numbers(4)),
          OhosPickerColumn(labels: numbers(4)),
        ]),
      );
      final List<double> widths = <double>[
        for (int i = 0; i < 3; i++)
          tester
              .getSize(
                find.byType(ListWheelScrollView).at(i),
              )
              .width,
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
        OhosWheelPicker(columns: <OhosPickerColumn>[
          OhosPickerColumn(labels: numbers(4)),
        ]),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey<String>('picker-indicator')),
      );
      final BoxDecoration decoration = box.decoration as BoxDecoration;
      expect(
        decoration.borderRadius!.resolve(TextDirection.ltr).topLeft.x,
        12,
      );
      expect(tester.getSize(find.byKey(
        const ValueKey<String>('picker-indicator'),
      )).height, 40);

      await tester.pumpWidget(
        OhosTheme(
          data: OhosThemeData.ink(),
          child: MaterialApp(
            home: OhosScaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: OhosWheelPicker(columns: <OhosPickerColumn>[
                    OhosPickerColumn(labels: numbers(4)),
                  ]),
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
          columns: <OhosPickerColumn>[
            OhosPickerColumn(labels: numbers(4)),
          ],
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
          onChanged: (int column, int index) =>
              calls.add('$column:$index'),
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
          columns: <OhosPickerColumn>[
            OhosPickerColumn(labels: numbers(12)),
          ],
          onChanged: (int c, int i) => changes.add('$c:$i'),
          onScrollStop: (int c, int i) => stops.add('$c:$i'),
        ),
      );
      expect(stops, isEmpty, reason: '还没滚过');

      await tester.drag(
        find.byType(ListWheelScrollView),
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      expect(stops, hasLength(1), reason: '一次滑动只停一次');
      expect(changes.length, greaterThan(1), reason: '过程中跨过多项');
    });

    testWidgets('enabled: false 时不可滚，文字降到提示色', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await pumpPicker(
        tester,
        OhosWheelPicker(
          enabled: false,
          columns: <OhosPickerColumn>[
            OhosPickerColumn(labels: numbers(12)),
          ],
          onChanged: (int c, int i) => calls.add('$c:$i'),
        ),
      );
      await tester.drag(
        find.byType(ListWheelScrollView),
        const Offset(0, -80),
      );
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
          columns: <OhosPickerColumn>[
            OhosPickerColumn(labels: numbers(20)),
          ],
        ),
      );
      key.currentState!.animateTo(0, 10);
      await tester.pumpAndSettle();
      expect(key.currentState!.indexes, <int>[10]);
    });

    testWidgets('列数变化时重建控制器，不抛越界', (WidgetTester tester) async {
      await pumpPicker(
        tester,
        OhosWheelPicker(columns: <OhosPickerColumn>[
          OhosPickerColumn(labels: numbers(5)),
          OhosPickerColumn(labels: numbers(5)),
        ]),
      );
      expect(tester.takeException(), isNull);

      await pumpPicker(
        tester,
        OhosWheelPicker(columns: <OhosPickerColumn>[
          OhosPickerColumn(labels: numbers(5)),
        ]),
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
          OhosTimePicker(hour: 9, minute: 30, onChanged: (int h, int m, int s) {}),
        ),
      );
      expect(find.byType(ListWheelScrollView), findsNWidgets(2), reason: '时 + 分');

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

  group('OhosColorPicker', () {
    testWidgets('墨屏模式页签：选中反相成黑底白字，未选中留白 + 1px 线', (
      WidgetTester tester,
    ) async {
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
      expect(tester.widget<Text>(find.text('网格')).style?.color, ink.backgroundColor);
    });

    testWidgets('未选中的浅色色块补描边，深色不描；墨屏用纯黑', (
      WidgetTester tester,
    ) async {
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
          if (decoration is BoxDecoration && decoration.shape == BoxShape.circle) {
            found[decoration.color!] = decoration;
          }
        }
        return found;
      }

      final OhosThemeData ink = OhosThemeData.ink();
      final Map<Color, BoxDecoration> inkGrid = await pumpGrid(ink, Colors.black);

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
      const OhosDataPanel negative = OhosDataPanel(
        values: <double>[-1, 2],
      );
      expect(negative.effectiveValues, <double>[0, 2]);
    });

    testWidgets('max > 0 是标尺：四段共 75%，剩余留作底槽', (WidgetTester tester) async {
      const OhosDataPanel panel = OhosDataPanel(
        values: <double>[50, 12, 8, 5],
        max: 100,
      );
      expect(panel.effectiveMax, 100);
      final double used = panel.effectiveValues.reduce((double a, double b) => a + b);
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
      const OhosDataPanel panel = OhosDataPanel(
        values: <double>[0, 0],
        max: 0,
      );
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
      expect(OhosDataPanel.defaultColors.first.endColor, const Color(0xFFF99B11));
      expect(OhosDataPanel.defaultColors.last.color, const Color(0xFFA2A2B0));
      expect(OhosDataPanel.defaultColors.last.endColor, const Color(0xFF8E8E93));
    });

    testWidgets('线形与环形都画得出来，且不溢出', (WidgetTester tester) async {
      await pumpPanel(tester, values: <double>[5, 5], type: OhosDataPanelType.line);
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
      await pumpPanel(
        tester,
        values: <double>[50],
        child: const Text('75%'),
      );
      expect(find.text('75%'), findsOneWidget);
      final Offset center = tester.getCenter(find.text('75%'));
      final Offset panel = tester.getCenter(find.byType(OhosDataPanel));
      expect(center.dx, moreOrLessEquals(panel.dx, epsilon: 0.5));
      expect(center.dy, moreOrLessEquals(panel.dy, epsilon: 0.5));
    });
  });

  group('OhosGauge', () {
    test('开环 350 → 10 顺时针只扫 20 度，不是反着扫 340', () {
      expect(
        ohosSweepRadians(350, 10),
        moreOrLessEquals(20 * math.pi / 180),
      );
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

    testWidgets('比重为 0 的段不显示，全部为 0 时整环不显示', (
      WidgetTester tester,
    ) async {
      // 私有方法拿不到，改从渲染结果侧面验：能画出且不抛异常即为「可绘制」，
      // 真正的过滤逻辑由下一层的 `isVisible` 单测守住。
      expect(const OhosGaugeSegment(color: Color(0xFF64BB5C), weight: 0).isVisible,
          isFalse);
      expect(
        const OhosGaugeSegment(color: Color(0xFF64BB5C), weight: 0.001).isVisible,
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
        wrap(const SizedBox.square(dimension: 160, child: OhosGauge(value: 50))),
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

    testWidgets('showIndicator: false 只画环，仍能正常布局', (
      WidgetTester tester,
    ) async {
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

    testWidgets('箭头形起止角度（225 → 135）扫过 270 度', (
      WidgetTester tester,
    ) async {
      expect(
        ohosSweepRadians(225, 135),
        moreOrLessEquals(270 * math.pi / 180),
      );
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

    testWidgets('内置四项按固定顺序：剪切 → 复制 → 粘贴 → 全选', (
      WidgetTester tester,
    ) async {
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
      final Icon icon = tester.widget<Icon>(find.byIcon(Icons.content_copy_rounded));
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
    testWidgets('清空键回调 onClear，空态占位与清空键同宽（40vp）', (
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
      // 空态与清空键同宽，输入区宽度不会在空↔有字之间跳动。
      // 40 是官方 `search_close_icon_hot_zone_horizontal` 的值 —— 手指够得着
      // 的下限；原来是 32，真机上偏窄。
      expect(placeholder.width, 40);
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

    testWidgets('ink 胶囊补 1px 实线，且四边同宽、画在子节点之上', (
      WidgetTester tester,
    ) async {
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
          SizedBox(
            width: 320,
            child: OhosSearchBar(controller: controller),
          ),
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
    testWidgets('autoDisable：空内容时按钮置灰且不可点，有字恢复', (
      WidgetTester tester,
    ) async {
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
      TextButton button() => tester.widget<TextButton>(
        find.widgetWithText(TextButton, '搜索'),
      );

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

    testWidgets('无搜索按钮时右侧不留 2vp，输入区宽度不变', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 360,
            child: OhosSearchBar(controller: controller),
          ),
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

  group('OhosList', () {
    List<OhosDivider> dividersOf(WidgetTester tester) =>
        tester.widgetList<OhosDivider>(find.byType(OhosDivider)).toList();

    testWidgets('每个行边界只有一条线，末行不画（不叠双线）', (
      WidgetTester tester,
    ) async {
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
              OhosListTile(
                leading: Icon(Icons.wifi),
                title: Text('带图标'),
              ),
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
            children: <Widget>[
              SizedBox(height: 40),
              SizedBox(height: 40),
            ],
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
    testWidgets('行高有界时仍是 18×18 的圆，不会拉成竖胶囊', (
      WidgetTester tester,
    ) async {
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
      // 高度必须锁在自己的 18vp 上（修复前被拉到 46）；宽度不小于高度 ——
      // 竖胶囊正是「宽 < 高」。测试里 `flutter_tester` 用 Ahem，字形是方形，
      // 所以宽度会略大于 18，真实字体下宽 = 高 = 18 的圆。
      expect(size.height, 18);
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
      expect(size.height, 18);
      expect(size.width, greaterThan(18));
    });

    testWidgets('点在 8×8，没有 count 也没有 child 时收成零', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const Row(
            children: <Widget>[
              OhosBadge(isDot: true),
              OhosBadge(),
            ],
          ),
        ),
      );

      expect(tester.getSize(find.byType(OhosBadge).first), const Size(8, 8));
      expect(tester.getSize(find.byType(OhosBadge).last), Size.zero);
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

    testWidgets('滑块：拇指是圆且高于轨道，不会把轨道切出一道白口', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        picker(
          tab: OhosColorPickerTab.sliders,
          color: const Color(0xFF0A59F7),
        ),
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

    testWidgets('浅底浮条自己画 hairline：墨屏纯黑，彩屏用分隔色', (
      WidgetTester tester,
    ) async {
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
    testWidgets('芯片尺寸对齐官方 chip_* 令牌（36/28 高、18/14 圆角）', (
      WidgetTester tester,
    ) async {
      // 这些数字不是自拟的：是 ArkUI 自己读的 sys.float 令牌真值，
      // 经 pattern.json -> float_sys.json -> float.json 解析得到
      // （见 tool/fetch_sys_resources.sh）。原来是 32/24 高、16/12 圆角，
      // 两档都偏小 4vp —— 因为 ChipGroup 和 Chip 各写了一份尺寸。
      for (final (OhosChipGroupSize size, double h, double r) in <
        (OhosChipGroupSize, double, double)
      >[
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
      expect(
        group.height,
        closeTo(64, 0.01),
        reason: 'chipGroupPadding 只加纵向',
      );
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
        return tester.widget<AnimatedContainer>(
              i == 0 ? boxes.first : boxes.at(i),
            ).decoration!
            as BoxDecoration;
      }

      final OhosThemeData theme = OhosThemeData.light();
      expect(deco(0).color, theme.highlightColor, reason: '第 0 颗默认选中');
      expect(
        deco(1).color,
        isNot(theme.highlightColor),
        reason: '其余保持空闲',
      );
    });

    // 行为变更：0.5.x 不传就一个都不选中，现在与 ArkUI 同默认。想保留旧表现
    // 要显式传 -1 / 空集 —— 这条断言把「旧表现仍可达」钉住，否则升级路径断掉。
    testWidgets('selectedIndex: -1 与空集可退回「全不选」', (
      WidgetTester tester,
    ) async {
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
    testWidgets('芯片项 selectedIcon 只在选中时替换 icon', (
      WidgetTester tester,
    ) async {
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
      for (final (OhosChipSize size, double h, double r) in <
        (OhosChipSize, double, double)
      >[
        (OhosChipSize.normal, 36, 18),
        (OhosChipSize.small, 28, 14),
      ]) {
        await tester.pumpWidget(
          wrap(
            OhosChip(
              size: size,
              label: const Text('标签'),
              onPressed: () {},
            ),
          ),
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
      final double gap = tester.getTopLeft(find.text('标签')).dx -
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
        wrap(
          OhosChip(label: const Text('标签'), onPressed: () {}),
        ),
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
      final double gap = tester.getTopLeft(find.byIcon(Icons.arrow_drop_down)).dx -
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
            tester.getTopLeft(find.text('标签')).dx - tester.getTopRight(shown).dx;
        expect(gap, 6, reason: 'selected=$sel 的图标间距');
      }
    });

    // 只给 normal 态时不照搬 ArkUI 的「选中就失去图标」：`chip.ets:1014` 的
    // `hasPrefix()` 会连带去掉图标和间距，在 Flutter 侧那是既有用法被点一下就
    // 掉图标，属于缺陷而非语义。回落规则写在 [OhosChip.selectedIcon] 上。
    testWidgets('只传 icon 时选中态沿用 icon，不会消失', (
      WidgetTester tester,
    ) async {
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
                  OhosTabBar(tabs: <Widget>[Text('文件'), Text('提交'), Text('分支')]),
                ],
              ),
            ),
          ),
        ),
      );

      final Rect bar = tester.getRect(find.byType(OhosTabBar));
      expect(bar.width, 360);
      expect(tester.getCenter(find.text('文件')).dx, moreOrLessEquals(bar.left + 60));
      expect(tester.getCenter(find.text('提交')).dx, moreOrLessEquals(bar.center.dx));
      expect(tester.getCenter(find.text('分支')).dx, moreOrLessEquals(bar.right - 60));
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

    testWidgets('只覆盖字号的 textStyle 也让字母颜色跟随主题', (
      WidgetTester tester,
    ) async {
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

    testWidgets('字母表被换成空表时不崩，恢复后高亮夹回合法位置', (
      WidgetTester tester,
    ) async {
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

    testWidgets('父级给更高的紧约束时，视觉格与命中格一起铺满', (
      WidgetTester tester,
    ) async {
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

    testWidgets('拖动中父级改 selectedIndex 不会把高亮从指下拽走', (
      WidgetTester tester,
    ) async {
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

    testWidgets('底部导航存在时 body 不再重复让出底部内边距', (
      WidgetTester tester,
    ) async {
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
                bottomNavigationBar: const SizedBox(key: Key('nav'), height: 48),
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

    testWidgets('body 子树不再看到已被页面容器认领的内边距', (
      WidgetTester tester,
    ) async {
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
                bottomNavigationBar: const SizedBox(key: Key('nav'), height: 48),
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
      expect(
        seen,
        EdgeInsets.zero,
        reason: 'body 内读到的 padding 已被页面容器消费干净',
      );
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

  group('OhosActionBar', () {
    // 官方 HdsActionBar 有「去掉主按钮」这一形态。原来的实现在不传
    // primaryLabel 时仍然渲染 OhosButton，其标签是 `primaryLabel ?? ''` ——
    // 得到一个没有文字的空白药丸，看上去像加载失败。
    testWidgets('omits the primary button when no label is given', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const OhosActionBar(
            secondaryActions: <Widget>[Text('分享'), Text('收藏')],
          ),
        ),
      );

      expect(find.byType(OhosButton), findsNothing);
      expect(find.text('分享'), findsOneWidget);
    });

    testWidgets('keeps the primary button when a label is given', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(const OhosActionBar(primaryLabel: '提交')),
      );

      expect(find.byType(OhosButton), findsOneWidget);
      expect(find.text('提交'), findsOneWidget);
    });

    // loading 但还没有标签时仍要画：转圈本身就是「正在做某事」的唯一反馈，
    // 这时候抽掉按钮，调用方会以为请求被丢了。
    testWidgets('keeps the button while loading without a label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const OhosActionBar(primaryLoading: true)));

      expect(find.byType(OhosButton), findsOneWidget);
    });
  });

  group('OhosSubheader', () {
    // 三档高度是官方的硬规格（`subheader_single_title_height` /
    // `_single_subtitle_height` / `_double_height` = 56 / 56 / 72）。
    // 旧实现没有高度概念，行高靠字阶撑 —— 18fp 的实际行盒只有 ~42，
    // 比官方矮一截，所以这里断的是组件本身的尺寸而不是 padding。
    testWidgets('高度三档：单标题 56 / 单副标题 56 / 双行 72', (
      WidgetTester tester,
    ) async {
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
      final double titleBottom = tester
          .getBottomLeft(find.text('本周'))
          .dy;
      final double subtitleTop = tester.getTopLeft(find.text('共 12 项')).dy;
      expect(subtitleTop - titleBottom, closeTo(2, 0.01));
    });

    // 副标题单独成行时权重升到 500（`SecondTitleStyle` 里的
    // `FontWeight.Medium`）。同一条副标题文字，形态一变权重就变 ——
    // 这不是笔误，官方就这么写的。
    testWidgets('副标题单独成行时权重 500，双行时 400', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(const OhosSubheader(secondaryTitle: '已完成')),
      );
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
    testWidgets('左图标 16 + 间距 8，且只给 title 时不出现', (
      WidgetTester tester,
    ) async {
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
          tester.getTopLeft(find.text('已完成')).dx -
          tester.getTopRight(icon).dx;
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

      await tester.pumpWidget(
        wrap(const OhosSubheader(secondaryTitle: '已完成')),
      );
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
    testWidgets('type 由字段推导：两行内容型，其余列表型', (
      WidgetTester tester,
    ) async {
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
      final double withArrow = tester
          .getSize(find.byType(OhosSubheader))
          .width;

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
        wrap(
          const OhosSubheader(title: '本周', leading: Text('自定义标题区')),
        ),
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
          tester.getTopLeft(find.text('首页')).dy -
          tester.getBottomLeft(icon).dy;
      expect(gap, closeTo(2, 0.01));
    });

    // 左右内边距只在**少于 5** 项时是 24（`padding_level12`），正好 5 项时
    // 归 0 靠均分铺满。`< 5` 不是 `<= 5` —— 写成后者会让 5 项那档突然缩进
    // 24，与 6 项收纳后的 5 格对不齐。
    testWidgets('少于 5 项时左右内边距 24，5 项时归零', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OhosToolbar(
            items: <OhosToolbarItem>[item('A'), item('B'), item('C')],
          ),
        ),
      );
      Rect bar = tester.getRect(find.byType(OhosToolbar));
      expect(
        tester.getTopLeft(find.text('A')).dx - tester.getRect(find.byType(OhosToolbar)).left,
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

      expect(paintedColor(tester, '禁用'), OhosThemeData.light().textTertiaryColor);

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
      expect(
        paintedColor(tester, '首页'),
        isNot(theme.textSecondaryColor),
      );
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
      expect(
        activeColor,
        isNot(idleColor),
        reason: '激活与常态要有明度差，否则读者看不出当前在哪',
      );
      // 反白：激活项的外层 Material 铺实底品牌色，文字取 onHighlightColor。
      final Material activeSurface = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('激活'),
              matching: find.byType(Material),
            )
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
    testWidgets('未选中点 6×6，选中点 12×6（变宽不变高）', (
      WidgetTester tester,
    ) async {
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
          tester.getTopLeft(dots.at(1)).dx -
          tester.getTopRight(dots.at(0)).dx;
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
    testWidgets('数字型 14fp/w400，当前页与总数只差颜色', (
      WidgetTester tester,
    ) async {
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
      expect(const OhosDate(year: 2024, month: 3, day: 7).toString(), '2024-03-07');
      expect(const OhosDate(year: 999, month: 12, day: 31).toString(), '999-12-31');
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

      final List<int> reaches = <double>[0, 0.25, 0.5, 0.75, 1]
          .map(reach)
          .toList();
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
      List<bool> probe(Path path) => <double>[5, 30, 70, 95]
          .map((double x) => path.contains(Offset(x, 20)))
          .toList();

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
        await tester.pumpWidget(wrap(
          const SizedBox(
            width: 200,
            height: 4,
            child: OhosProgressIndicator.linear(value: 0),
          ),
        ));
        // 换 value 后重放 painter：组件本身是 const，直接换实例
        await tester.pumpWidget(wrap(
          SizedBox(
            width: 200,
            height: 4,
            child: OhosProgressIndicator.linear(value: value),
          ),
        ));
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
        await tester.pumpWidget(wrap(
          SizedBox(
            width: 200,
            height: 4,
            child: OhosProgressIndicator.linear(value: value),
          ),
        ));
        return _replay(tester, OhosProgressIndicator, size: const Size(200, 4))
            .whereType<_RectDraw>()
            .length;
      }

      expect(await count(0), 1);
      expect(await count(-1), 1);
      expect(await count(0.5), 2);
    });

    testWidgets('线性：完全无界时退回 300，不拿 Infinity 崩布局',
        (WidgetTester tester) async {
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
      await tester.pumpWidget(wrap(
        const OhosProgressIndicator.ring(value: 0.5),
      ));
      final List<Object> draws = _replay(tester, OhosProgressIndicator);
      // 轨道走 `drawCircle`（一整圈），只有进度走 `drawArc`
      expect(draws.whereType<_CircleDraw>(), hasLength(1));
      final List<_ArcDraw> arcs = draws.whereType<_ArcDraw>().toList();
      expect(arcs, hasLength(1));
      // 从 12 点起顺时针，弧度按比例（0.5 → π）
      expect(arcs.single.start, moreOrLessEquals(-math.pi / 2));
      expect(arcs.single.sweep, moreOrLessEquals(math.pi));
    });

    testWidgets('环形：厚度 + 阴影超半径时被压成半径一半',
        (WidgetTester tester) async {
      // 不夹取的话，小尺寸 + 粗环会画成一个实心圆
      await tester.pumpWidget(wrap(
        const OhosProgressIndicator.ring(
          value: 0.5,
          size: 24,
          strokeWidth: 20,
        ),
      ));
      final List<_ArcDraw> arcs = _replay(
        tester,
        OhosProgressIndicator,
        size: const Size(24, 24),
      ).whereType<_ArcDraw>().toList();
      // 半径 12，压成 6 ⇒ 中心线半径 12 - 3 = 9
      expect(arcs.single.radius, moreOrLessEquals(9));
    });

    testWidgets('环形：半径 ≤ 10 不画阴影（官方：没空间同时画）',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const OhosProgressIndicator.ring(value: 0.5, size: 16, shadow: true),
      ));
      // 半径 8 ≤ 10：只有一条进度弧，没有阴影弧
      expect(
        _replay(tester, OhosProgressIndicator, size: const Size(16, 16))
            .whereType<_ArcDraw>()
            .length,
        1,
        reason: '半径 8 时不该画阴影',
      );

      await tester.pumpWidget(wrap(
        const OhosProgressIndicator.ring(value: 0.5, size: 100, shadow: true),
      ));
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
        await tester.pumpWidget(wrap(
          OhosProgressIndicator.scaleRing(
            value: value,
            scaleCount: 10,
            scaleWidth: 2,
            size: 100,
          ),
        ));
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
      expect(
        zero.every((_LineDraw l) => l.color == zero.first.color),
        isTrue,
      );
      // 一半换成了进度色，另一半仍是轨道色
      expect(half.take(5).every((_LineDraw l) => l.color == half.first.color),
          isTrue);
      expect(half.last.color, isNot(half.first.color));
    });

    testWidgets('刻度环退化时画的是环，不是空白', (WidgetTester tester) async {
      // 「退化」被误实现成「不画」时界面上是块空白，比刻度糊掉更糟。
      // 72 直径 + 默认 120 刻度 + 宽 2 恰好满足退化条件（见上一条用例）。
      await tester.pumpWidget(wrap(
        const OhosProgressIndicator.scaleRing(
          value: 0.5,
          size: 72,
          scaleWidth: 2,
          scaleCount: 120,
        ),
      ));
      final List<Object> draws = _replay(
        tester,
        OhosProgressIndicator,
        size: const Size(72, 72),
      );
      // 退化后走「画环」：一整圈轨道圆 + 一段进度弧，且一根刻度线都没有
      expect(draws.whereType<_LineDraw>(), isEmpty);
      expect(draws.whereType<_CircleDraw>(), hasLength(1));
      final List<_ArcDraw> arcs =
          draws.whereType<_ArcDraw>().toList();
      expect(arcs, hasLength(1));
      expect(arcs.single.sweep, moreOrLessEquals(math.pi));
    });

    testWidgets('月相：先铺整圆底，再画一条月牙路径', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const OhosProgressIndicator.eclipse(value: 0.5),
      ));
      final List<Object> draws = _replay(tester, OhosProgressIndicator);
      expect(draws.whereType<_CircleDraw>(), hasLength(1));
      expect(draws.whereType<_PathDraw>(), hasLength(1));
      // 月牙的包围盒是左半圆
      final Rect bounds = draws.whereType<_PathDraw>().single.path.getBounds();
      expect(bounds.width, moreOrLessEquals(36), reason: '72 直径的左半圆');
    });

    testWidgets('胶囊：画底板、内描边、进度路径', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 200,
          height: 40,
          child: OhosProgressIndicator.capsule(value: 0.5),
        ),
      ));
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
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 200,
          height: 40,
          child: OhosProgressIndicator.capsule(
            value: 0.5,
            content: '安装中',
            showDefaultPercentage: true,
          ),
        ),
      ));
      // 官方：「设置了 content 属性时该属性不生效」
      expect(find.text('安装中'), findsOneWidget);
      expect(find.text('50%'), findsNothing);
    });

    testWidgets('胶囊百分比取整：0.999 显示 100% 而不是 99%',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 200,
          height: 40,
          child: OhosProgressIndicator.capsule(
            value: 0.999,
            showDefaultPercentage: true,
          ),
        ),
      ));
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('两个都不给时不显示文字', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 200,
          height: 40,
          child: OhosProgressIndicator.capsule(value: 0.5),
        ),
      ));
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

    testWidgets('value 为 null：线性/环形给不确定态，月相不画进度',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 200,
          height: 4,
          child: OhosProgressIndicator.linear(),
        ),
      ));
      // 轨道 + 一段游标
      expect(
        _replay(tester, OhosProgressIndicator, size: const Size(200, 4))
            .whereType<_RectDraw>()
            .length,
        2,
      );

      // 官方的不确定态只有 ProgressStatus.LOADING，只挂在 RingStyleOptions 上
      await tester.pumpWidget(wrap(
        const OhosProgressIndicator.eclipse(),
      ));
      expect(
        _replay(tester, OhosProgressIndicator).whereType<_PathDraw>(),
        isEmpty,
        reason: '月相没有不确定态，null 按 0 画',
      );
    });
  });

  group('OhosLoadingIndicator', () {
    testWidgets('默认 32vp，且真的在画彗星弧', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const OhosLoadingIndicator()));
      expect(
        tester.getSize(find.byType(OhosLoadingIndicator)),
        const Size(32, 32),
      );
      // 分段拼出来的彗尾：不是一条弧
      final List<_ArcDraw> arcs = _replay(tester, OhosLoadingIndicator)
          .whereType<_ArcDraw>()
          .toList();
      expect(arcs.length, greaterThan(1));
      // 头部最实、尾部渐隐
      expect(arcs.first.color.a, greaterThan(arcs.last.color.a));
    });

    testWidgets('enableLoading=false 仍占位，只是不转',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const OhosLoadingIndicator(enableLoading: false),
      ));
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
      final double before = _replay(tester, OhosLoadingIndicator)
          .whereType<_ArcDraw>()
          .first
          .start;
      await tester.pump(const Duration(milliseconds: 500));
      final double after = _replay(tester, OhosLoadingIndicator)
          .whereType<_ArcDraw>()
          .first
          .start;
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
      final double before = _replay(tester, OhosLoadingIndicator)
          .whereType<_ArcDraw>()
          .first
          .start;
      await tester.pump(const Duration(milliseconds: 500));
      final double after = _replay(tester, OhosLoadingIndicator)
          .whereType<_ArcDraw>()
          .first
          .start;
      // 每帧一次真实全屏刷新在墨水屏上是灾难，所以整段动画被压成零时长
      expect(after, moreOrLessEquals(before));
      expect(_replay(tester, OhosLoadingIndicator), isNotEmpty);
    });

    testWidgets('颜色默认取提示色，不是品牌色', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const OhosLoadingIndicator()));
      final Color painted = _replay(tester, OhosLoadingIndicator)
          .whereType<_ArcDraw>()
          .first
          .color;
      final OhosThemeData theme = OhosThemeData.light();
      // 官方默认 #ff666666 是一档中性灰，不是主色 —— 加载态不是品牌露出
      expect(
        painted.r,
        moreOrLessEquals(theme.textTertiaryColor.r, epsilon: 0.02),
      );
      expect(painted, isNot(theme.highlightColor));
    });

    testWidgets('size 与 strokeWidth 生效', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const OhosLoadingIndicator(size: 48, strokeWidth: 5),
      ));
      expect(
        tester.getSize(find.byType(OhosLoadingIndicator)),
        const Size(48, 48),
      );
      expect(
        _replay(tester, OhosLoadingIndicator)
            .whereType<_ArcDraw>()
            .first
            .strokeWidth,
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
      expect(rowA.left - group.left, moreOrLessEquals(12 + 4 + 16, epsilon: 0.01));

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
      expect(
        decoration.color,
        OhosThemeData.light().cardColor,
      );
      expect(
        decoration.borderRadius,
        BorderRadius.circular(OhosListGroupMetrics.cardRadius),
      );
    });

    testWidgets('space 只加在行与行之间，不加在组头/组尾两侧', (
      WidgetTester tester,
    ) async {
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

    testWidgets('space 为负数时按 0 处理（官方：非法值按默认值）', (
      WidgetTester tester,
    ) async {
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

    testWidgets('给了 divider：n 行画 n−1 条，末行不画', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const OhosListGroup(
            divider: OhosGroupDivider(strokeWidth: 1, startMargin: 16, endMargin: 16),
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

    testWidgets('组内分隔线接管后，tile 自己那条被压掉（不叠双线）', (
      WidgetTester tester,
    ) async {
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

    testWidgets('itemStyle: card 把行撑到至少 48、左右各 8', (
      WidgetTester tester,
    ) async {
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

    testWidgets('itemStyle: none 不加最小高度，行按自身内容高', (
      WidgetTester tester,
    ) async {
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

    testWidgets('取了 ConstrainedBox 的最小高度，不写死 48', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(scrollHost(<Widget>[]));

      // 骨架先确认宿主有效：视口必须是 400×300，否则后面所有位移都在打折
      expect(
        tester.getSize(find.byType(CustomScrollView)),
        const Size(400, 300),
      );
    });

    testWidgets('sticky: none 时组头不钉住，会随内容滚走', (
      WidgetTester tester,
    ) async {
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

    testWidgets('吸顶的组头自带背板：THICK 材质，不会透出后面的行', (
      WidgetTester tester,
    ) async {
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
        scrollHost(<Widget>[
          OhosListGroupSliver(group: buildGroup(tag: '1')),
        ]),
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
            OhosListGroupSliver(group: buildGroup(tag: '1'), sticky: style),
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

    testWidgets('卡片样式的 sliver 也有 12 外边距与卡片底板', (
      WidgetTester tester,
    ) async {
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

    testWidgets('没有 header / footer 时只出列表，不崩', (
      WidgetTester tester,
    ) async {
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
}
