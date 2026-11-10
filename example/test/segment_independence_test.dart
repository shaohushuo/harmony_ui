import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmony_ui/harmony_ui.dart';
import 'package:ohos_ui_example/pages/selection_page.dart';

/// 分段按钮示例：两处控件必须各自独立。
///
/// ## 为什么需要这条
///
/// 「选择类」页里并排演示了两个 `OhosSegmentedButton`：capsule 单选与 tab 型。
/// 早先它们共用同一个 `_selected`，tab 型的 `selected` 写成
/// `_selected == 'day' ? 'all' : 'image'` —— 从 capsule 的取值倒推自己的取值，
/// `onSelected` 则是个 `setState(() {})`（点了不记）。
///
/// 于是在页面上表现为：**点 capsule 的「周」，下面 tab 型跟着从「全部」跳到
/// 「图片」**。用户报的就是这个。根因不在组件里（`OhosSegmentedButton` 是纯
/// 受控组件，自己不留状态），而在示例把两个独立控件的状态合并成了一份。
///
/// ## 判据为什么读「选中段的底色」而不是文本
///
/// 选中态唯一的视觉表达就是那一格的底板颜色（tab 型是白背板，capsule 型是
/// 品牌色药丸），文字只差一档字重。读底色才等于断言「用户看到的那一格变了」。
void main() {
  /// 滚到分段按钮那一段。
  ///
  /// 「选择类」页是 `ListView` 懒构建 —— 不滚过去，`OhosSegmentedButton` 压根
  /// 没被 build，`find.byType` 返回空，后面所有断言都会对着「找不到」而不是
  /// 对着「值不对」报错，白读一堆栈。
  Future<void> openSegmentSection(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OhosTheme(
        data: OhosThemeData.light(),
        child: const MaterialApp(home: SelectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('capsule 单选'),
      find.byType(Scrollable).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
  }

  /// 某个分段按钮里，**被选中**那一格的标签。
  ///
  /// 选中的判据是「底板色不是透明」：未选中段是 `Colors.transparent`，
  /// 选中段是卡片白或品牌色。
  String selectedLabel(WidgetTester tester, Finder control) {
    final Finder decorated = find.descendant(
      of: control,
      matching: find.byType(AnimatedContainer),
    );
    final Iterable<Element> elements = tester.elementList(decorated);
    expect(elements, isNotEmpty, reason: '分段按钮里没有段');

    String? label;
    int highlighted = 0;
    for (final Element element in elements) {
      final AnimatedContainer box = element.widget as AnimatedContainer;
      final Decoration? decoration = box.decoration;
      if (decoration is! BoxDecoration) {
        continue;
      }
      final Color? color = decoration.color;
      if (color == null || color.a == 0) {
        continue;
      }
      highlighted++;
      // 这一格里的标签文字。用 Element 定位而不是再写一遍 of:，避免
      // 「同一个 label 在别处也出现」时匹配到别的段。
      final Finder text = find.descendant(
        of: find.byElementPredicate((Element e) => e == element),
        matching: find.byType(Text),
      );
      expect(text, findsOneWidget);
      label = tester.widget<Text>(text).data;
    }
    expect(highlighted, 1, reason: '选中态应当只有一格底板是有颜色的');
    expect(label, isNotNull);
    return label!;
  }

  /// 页面上的两个分段按钮：capsule 单选与 tab 型。
  Finder capsuleControl() => find
      .byWidgetPredicate(
        (Widget w) =>
            w is OhosSegmentedButton &&
            w.type == OhosSegmentType.capsule &&
            !w.multiply,
      )
      .first;

  Finder tabControl() => find.byWidgetPredicate(
    (Widget w) => w is OhosSegmentedButton && w.type == OhosSegmentType.tab,
  );

  testWidgets('点 capsule 的某一项，tab 型的选中项不变', (WidgetTester tester) async {
    await openSegmentSection(tester);

    final Finder capsule = capsuleControl();
    final Finder tab = tabControl();

    // 初始：capsule 选「日」，tab 选「全部」。
    expect(selectedLabel(tester, capsule), '日');
    expect(selectedLabel(tester, tab), '全部');

    // 点 capsule 的「周」。
    await tester.tap(find.descendant(of: capsule, matching: find.text('周')));
    await tester.pumpAndSettle();

    // capsule 自己动了……
    expect(selectedLabel(tester, capsule), '周');
    // ……tab 必须原地不动。这条就是用户报的「联动」。
    expect(
      selectedLabel(tester, tab),
      '全部',
      reason: 'tab 型与 capsule 是两处独立控件，点 capsule 不该改动 tab 的选中项',
    );
  });

  testWidgets('tab 型自己可以切，且不会反过来带动 capsule', (WidgetTester tester) async {
    // 上一条只验「capsule → tab」这个方向。反向也得验：早先 tab 的
    // `onSelected` 是空实现，点它什么都不发生（选中项永远停在算出来的那个），
    // 这种「点了不记」是同一个 bug 的另一半。
    await openSegmentSection(tester);

    final Finder capsule = capsuleControl();
    final Finder tab = tabControl();

    await tester.tap(find.descendant(of: tab, matching: find.text('视频')));
    await tester.pumpAndSettle();

    expect(selectedLabel(tester, tab), '视频');
    expect(selectedLabel(tester, capsule), '日');
  });
}
