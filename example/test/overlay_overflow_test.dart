import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmony_ui/harmony_ui.dart';

/// 弹层类的溢出矩阵。
///
/// 为什么单开一份：`gallery_overflow_test.dart` 只扫**页面本身**，而弹层
/// （半模态 / 菜单 / 弹出框 / 选择器）是在**新路由**里建的 —— 页面上那个
/// 触发按钮扫一万遍也不会让面板布局跑一次。半模态 5 形态刚落地时，
/// 面板高度、宽度、标题栏的固定行都还没有被任何窄屏用例覆盖过。
///
/// 尺寸与字号沿用主矩阵同一组，保证两张表可以对照。
const List<Size> _sizes = <Size>[
  Size(360, 800),
  Size(320, 800),
  Size(387, 820),
];

const List<double> _textScales = <double>[1.0, 1.15, 1.3];

/// 每种弹层的打开方式 + 名称。
Map<String, Future<void> Function(BuildContext)> _openers() {
  Widget content() => const Padding(
    padding: EdgeInsets.all(12),
    child: Text(
      '面板内容，用来把面板撑到有实际高度。'
      '长文本还会换行，从而在窄屏上真正产生布局压力。',
    ),
  );

  return <String, Future<void> Function(BuildContext)>{
    'sheet-bottom': (BuildContext c) => showOhosBottomSheet(
      context: c,
      title: '底部弹窗',
      type: OhosSheetType.bottom,
      content: content(),
    ),
    'sheet-center': (BuildContext c) => showOhosBottomSheet(
      context: c,
      title: '居中弹窗',
      type: OhosSheetType.center,
      content: content(),
    ),
    'sheet-popup': (BuildContext c) => showOhosBottomSheet(
      context: c,
      title: '跟手弹窗',
      type: OhosSheetType.popup,
      content: content(),
    ),
    'sheet-side': (BuildContext c) => showOhosBottomSheet(
      context: c,
      title: '侧边弹窗',
      type: OhosSheetType.side,
      content: content(),
    ),
    'sheet-content-cover': (BuildContext c) => showOhosBottomSheet(
      context: c,
      title: '全屏弹窗',
      type: OhosSheetType.contentCover,
      content: content(),
    ),
    // detents 生效时面板高度由挡位决定，与上面的「内容自适应」是两条路径。
    'sheet-detents': (BuildContext c) => showOhosBottomSheet(
      context: c,
      title: '多挡位',
      type: OhosSheetType.bottom,
      detents: <OhosSheetDetent>[
        const OhosSheetDetent.value(300),
        const OhosSheetDetent.value(600),
      ],
      content: content(),
    ),
    'dialog': (BuildContext c) => showOhosDialog<bool>(
      context: c,
      title: '弹出框',
      content: '面板内容，用来把弹出框撑到有实际高度。长文本还会换行。',
      actions: <OhosDialogAction>[
        OhosDialogAction(
          label: '取消',
          onPressed: () => Navigator.pop(c, false),
        ),
        OhosDialogAction(
          label: '确定',
          onPressed: () => Navigator.pop(c, true),
        ),
      ],
    ),
    'menu': (BuildContext c) => showOhosMenu<String>(
      context: c,
      items: const <OhosMenuItem<String>>[
        OhosMenuItem<String>(label: '菜单项一', value: 'a'),
        OhosMenuItem<String>(label: '菜单项二', value: 'b'),
        OhosMenuItem<String>(label: '菜单项三', value: 'c'),
      ],
      position: const RelativeRect.fromLTRB(40, 300, 40, 0),
    ),
    'toast': (BuildContext c) async => showOhosToast(c, '提示消息'),
    'snackbar': (BuildContext c) async => showOhosSnackBar(
      c,
      message: '操作已完成，长文本已经换行\n第二行内容用来撑高',
      actionLabel: '撤销',
      onAction: () {},
    ),
  };
}

Widget _host(double textScale, Future<void> Function(BuildContext) open) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: OhosTheme(
      data: OhosThemeData.light(),
      child: OhosScaffold(
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

/// 打开弹层、收集布局错误。**用 `pump` 而不是 `pumpAndSettle`**：
/// 弹层里可能有持续动效（光感、加载环），`pumpAndSettle` 会超时。
Future<void> _scanOpener(
  WidgetTester tester,
  double textScale,
  Future<void> Function(BuildContext) open,
  List<String> errors,
) async {
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final String text = details.toString();
    if (text.contains('overflowed')) {
      errors.add(text.split('\n').take(4).join(' | '));
    } else {
      previous?.call(details);
    }
  };

  await tester.pumpWidget(_host(textScale, open));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('打开'));
  await tester.pump();
  // 打开后多 pump 几帧，让入场动画走完 —— 溢出一半是动画到位之后才显形。
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  tester.takeException();

  // 把待处理的定时器走完再收尾。`showOhosToast` 会自动关闭（默认 2s），
  // `showOhosSnackBar` 3s —— 不推完的话测试框架会以
  // 「Pending timers」失败，而那个报错里没有 overflowed 字样，
  // 看起来像布局问题、实际只是收尾没做。
  await tester.pump(const Duration(seconds: 4));

  FlutterError.onError = previous;
}

void main() {
  final Map<String, Future<void> Function(BuildContext)> openers = _openers();

  for (final Size size in _sizes) {
    for (final double textScale in _textScales) {
      for (final MapEntry<String, Future<void> Function(BuildContext)> e
          in openers.entries) {
        testWidgets(
          '${e.key} @ ${size.width.toInt()}vp ×${textScale}x 字号不溢出',
          (WidgetTester tester) async {
            await tester.binding.setSurfaceSize(size);
            addTearDown(() => tester.binding.setSurfaceSize(null));

            final List<String> errors = <String>[];
            await _scanOpener(tester, textScale, e.value, errors);

            if (errors.isNotEmpty) {
              fail(errors.join('\n- - - - -\n'));
            }
          },
        );
      }
    }
  }
}
