import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmony_ui/harmony_ui.dart';
import 'package:ohos_ui_example/pages/safe_area_page.dart';

void main() {
  // `flutter_tester` 里真实内边距是 0，页面默认会打开「模拟安全区」（24 / 16），
  // 所以这条用例覆盖的正是「容器让过、body 子树该看到 0」的场景。
  Widget host() {
    return OhosTheme(
      data: OhosThemeData.light(),
      child: const MaterialApp(home: SafeAreaPage()),
    );
  }

  testWidgets('对照页：两栏「顶」「底」条齐平，栏内 padding 四边为 0', (WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // 每条边带里各一个「顶」/「底」，两栏各一份。
    final Finder tops = find.text('顶');
    final Finder bottoms = find.text('底');
    expect(tops, findsNWidgets(2));
    expect(bottoms, findsNWidgets(2));
    expect(
      tester.getRect(tops.at(0)).top,
      tester.getRect(tops.at(1)).top,
      reason: '两栏「顶」条必须齐平',
    );
    expect(
      tester.getRect(bottoms.at(0)).bottom,
      tester.getRect(bottoms.at(1)).bottom,
      reason: '两栏「底」条必须齐平',
    );

    // 摘掉 padding 之后，两栏（含套了 SafeArea 的那栏）读到的都是 0。
    expect(find.textContaining('top 0  bottom 0'), findsNWidgets(2));
  });

  testWidgets('关掉模拟：改用系统内边距（此处为 0），两栏依旧齐平', (WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OhosSwitch));
    await tester.pumpAndSettle();
    expect(find.text('使用系统真实安全区'), findsOneWidget);
    expect(find.textContaining('top 0  bottom 0'), findsNWidgets(2));
  });
}
