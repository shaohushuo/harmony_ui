import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmony_icons/harmony_icons.dart';
import 'package:harmony_ui/harmony_ui.dart';

import 'package:ohos_ui_example/pages/icons_page.dart';

Widget _host() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OhosTheme(data: OhosThemeData.light(), child: const IconsPage()),
  );
}

String _countText(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const ValueKey<String>('icons-count')))
      .data!;
}

int _searchHitCount(String query) {
  final String needle = query.toLowerCase();
  return OhosIcons.values.where((OhosIconMeta meta) {
    final String codepoint =
        '0x${meta.codepoint.toRadixString(16).toUpperCase()}';
    final String haystack =
        '${meta.name} ${meta.label} ${meta.module} '
                '${meta.categories.join(' ')} $codepoint'
            .toLowerCase();
    return haystack.contains(needle);
  }).length;
}

int _mirrorGlyphCount() {
  final Set<int> used = <int>{
    for (final OhosIconMeta meta in OhosIcons.values) meta.codepoint,
  };
  int mirrors = 0;
  for (final OhosIconMeta meta in OhosIcons.values) {
    final int? codepoint = meta.mirrorCodepoint;
    if (codepoint != null && used.add(codepoint)) {
      mirrors++;
    }
  }
  return mirrors;
}

void main() {
  testWidgets('默认只展示具名图标', (WidgetTester tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(_countText(tester), '显示 ${OhosIcons.count} / ${OhosIcons.count} 个');
    expect(
      find.byKey(const ValueKey<String>('icon-airplane_fill')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('icon-airplane_fill__mirror')),
      findsNothing,
    );
  });

  testWidgets('搜索同时匹配英文名与中文名', (WidgetTester tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    final Finder searchField = find.descendant(
      of: find.byKey(const ValueKey<String>('icons-search')),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, 'wifi');
    await tester.pump();

    final int expected = _searchHitCount('wifi');
    expect(expected, greaterThan(0));
    expect(_countText(tester), '显示 $expected / ${OhosIcons.count} 个');
    expect(find.byKey(const ValueKey<String>('icon-wifi')), findsOneWidget);
  });

  testWidgets('切到全部字形后带出隐藏的 RTL 镜像字形', (WidgetTester tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    final int mirrors = _mirrorGlyphCount();
    final int total = OhosIcons.count + mirrors;
    expect(mirrors, greaterThan(0));

    await tester.tap(find.text('全部字形 $total'));
    await tester.pump();

    expect(_countText(tester), '显示 $total / $total 个（含 $mirrors 个隐藏字形）');
    expect(
      find.byKey(const ValueKey<String>('icon-airplane_fill__mirror')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('icon-airplane_fill')));
    await tester.pumpAndSettle();

    expect(find.text('0xF0113'), findsOneWidget);
    expect(find.text('具名图标'), findsOneWidget);
    expect(find.text('RTL 镜像字形（隐藏）'), findsNothing);
  });

  testWidgets('打开镜像字形详情能看到隐藏类型', (WidgetTester tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.tap(
      find.text('全部字形 ${OhosIcons.count + _mirrorGlyphCount()}'),
    );
    await tester.pump();

    final Finder mirrorCell = find.byKey(
      const ValueKey<String>('icon-airplane_fill__mirror'),
    );
    await tester.ensureVisible(mirrorCell);
    await tester.tap(mirrorCell);
    await tester.pumpAndSettle();

    expect(find.text('RTL 镜像字形（隐藏）'), findsOneWidget);
    expect(find.text('0xF0A02'), findsOneWidget);
  });
}
