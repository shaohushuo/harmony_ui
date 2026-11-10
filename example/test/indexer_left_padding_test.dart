import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmony_ui/harmony_ui.dart';
import 'package:ohos_ui_example/pages/display_page.dart';

/// 索引条示例：左侧城市列表要有内距。
///
/// ## 为什么需要这条
///
/// 这一页的列表是示例自己用 `ListView.builder` 拼的（不是 `OhosListTile`），
/// 所以组件层的 16vp 内容内距不会自动带过来。早先它的 `padding` 只给了
/// `vertical: 6`，城市名与字母直接贴在示例外框的左线上 —— 用户看到的就是
/// 「和左侧边框靠一起」。
///
/// ## 判据为什么量坐标差而不是读 `padding` 字段
///
/// 读 `ListView.padding` 只能证明「参数传了」，证明不了「文字真的挪了」：
/// 外面再套一层 `Align` / 负 `margin` 就能把它抵消掉。所以这里量**文字实际
/// 左边缘**与**外框左边缘**的距离 —— 也就是用户眼睛看到的那条间距。
void main() {
  /// 打开「展示类」页并滚到索引条那一段。
  ///
  /// 全程用 `pump(Duration)` 而不是 `pumpAndSettle`：这一页挂着
  /// `OhosLoadingIndicator`（彗星形，无限循环），`pumpAndSettle` 会一直等到
  /// 超时。
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
  }

  Future<void> openIndexerSection(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OhosTheme(
        data: OhosThemeData.light(),
        child: const MaterialApp(home: DisplayPage()),
      ),
    );
    await settle(tester);

    // 页面是懒构建的 ListView，不滚过去索引条示例根本不会 build。
    final Finder title = find.text('索引条 OhosAlphabetIndexer');
    for (int i = 0; i < 60 && title.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await settle(tester);
    }
    expect(title, findsWidgets, reason: '没滚到索引条示例，后面的断言无从谈起');
    // 标题进视口不等于整个示例都建好了，再推几帧让它落地。
    await settle(tester);
  }

  testWidgets('城市列表文字与左侧边框留出 16vp', (WidgetTester tester) async {
    await openIndexerSection(tester);

    // 第一行是字母「A」，也是列表的第一项，能代表最左边缘。
    final Finder firstRow = find.text('A');
    expect(firstRow, findsWidgets);

    // 列表自己的外框：`ClipRRect` 里那层 `DecoratedBox` 的左边。
    final Finder frame = find
        .ancestor(of: firstRow.first, matching: find.byType(DecoratedBox))
        .first;
    final double frameLeft = tester.getTopLeft(frame).dx;
    final double textLeft = tester.getTopLeft(firstRow.first).dx;

    // 16vp 内距。允许 1vp 误差：字形左侧自带一点空白（`bodySmall` 的行高
    // 与字形边界不完全重合），这里断的是「有明显的间距」而不是像素级对齐。
    expect(
      textLeft - frameLeft,
      closeTo(16, 1),
      reason: '城市列表的文字应当离左边框有 16vp 间距，而不是贴在一起',
    );
  });

  testWidgets('间距不是靠挤走索引条换来的', (WidgetTester tester) async {
    // 只加左内距很容易顺手把右边也压掉，让索引条贴到列表文字上。
    // 这条断「列表右边缘与索引条左边缘之间仍有间隔」。
    await openIndexerSection(tester);

    final Finder indexer = find.byType(OhosAlphabetIndexer);
    expect(indexer, findsOneWidget);

    final Finder firstRow = find.text('A').first;
    final Finder frame = find
        .ancestor(of: firstRow, matching: find.byType(DecoratedBox))
        .first;

    final double frameRight = tester.getTopRight(frame).dx;
    final double indexerLeft = tester.getTopLeft(indexer).dx;

    expect(
      indexerLeft - frameRight,
      greaterThanOrEqualTo(4),
      reason: '索引条与列表之间应当留出间隔，不能被列表内容顶住',
    );
  });
}
