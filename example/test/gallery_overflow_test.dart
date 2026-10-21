import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmony_ui/harmony_ui.dart';

import 'package:ohos_ui_example/pages/action_page.dart';
import 'package:ohos_ui_example/pages/container_page.dart';
import 'package:ohos_ui_example/pages/display_page.dart';
import 'package:ohos_ui_example/pages/input_page.dart';
import 'package:ohos_ui_example/pages/kit_page.dart';
import 'package:ohos_ui_example/pages/layout_page.dart';
import 'package:ohos_ui_example/pages/navigation_page.dart';
import 'package:ohos_ui_example/pages/selection_page.dart';

/// Gallery 的「斑马线」回归测试。
///
/// 每个示例页在窄屏（360 / 320vp）下逐屏下滑一遍，把 `RenderFlex overflowed`
/// 收集起来；出现溢出就失败，并给出溢出的 Row / Column / Stack 与源码行号。
/// 组件库里凡是固定高度/固定宽度的行（页签、操作栏、数据面板、索引条）最容易
/// 在窄屏翻车，这个测试就是用来兜住它们的。
const List<Size> _sizes = <Size>[
  Size(360, 800),
  Size(320, 800),
];

Widget _host(Widget page) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OhosTheme(data: OhosThemeData.light(), child: page),
  );
}

/// 逐屏下滑并收集溢出错误。
///
/// 用 `pump` 而不是 `pumpAndSettle`：示例里的加载动画 / 光感动效可能一直在跑，
/// `pumpAndSettle` 会直接超时。
Future<void> _scan(
  WidgetTester tester,
  Widget page,
  List<String> errors,
) async {
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final String text = details.toString();
    if (text.contains('overflowed')) {
      errors.add(
        text
            .split('\n')
            .where(
              (String line) =>
                  line.contains('overflowed') ||
                  line.contains('error-causing widget') ||
                  line.trimLeft().startsWith('Row:') ||
                  line.trimLeft().startsWith('Column:') ||
                  line.trimLeft().startsWith('Stack:'),
            )
            .join('\n'),
      );
    }
    previous?.call(details);
  };

  Future<void> settle() async {
    await tester.pump(const Duration(milliseconds: 300));
    tester.takeException();
  }

  await tester.pumpWidget(_host(page));
  await settle();

  for (int i = 0; i < 24; i++) {
    final Finder scroll = find.byType(Scrollable).first;
    await tester.drag(scroll, const Offset(0, -420));
    await settle();
  }

  FlutterError.onError = previous;
}

void main() {
  final Map<String, Widget> pages = <String, Widget>{
    'action': const ActionPage(),
    'container': const ContainerPage(),
    'display': const DisplayPage(),
    'input': const InputPage(),
    'kit': const KitPage(),
    'layout': const LayoutPage(),
    'navigation': const NavigationPage(),
    'selection': const SelectionPage(),
  };

  for (final Size size in _sizes) {
    for (final MapEntry<String, Widget> entry in pages.entries) {
      testWidgets('${entry.key} 页在 ${size.width}x${size.height} 下不溢出', (
        WidgetTester tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final List<String> errors = <String>[];
        await _scan(tester, entry.value, errors);

        if (errors.isNotEmpty) {
          fail(errors.join('\n- - - - -\n'));
        }
      });
    }
  }
}
