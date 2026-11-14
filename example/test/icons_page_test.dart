import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmony_icons/harmony_icons.dart';
import 'package:harmony_ui/harmony_ui.dart';
import 'package:hm_symbol/hm_symbol.dart';

import 'package:ohos_ui_example/pages/icons_page.dart';

Widget _host({double textScale = 1.0}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (BuildContext context, Widget? child) {
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
    },
    home: OhosTheme(data: OhosThemeData.light(), child: const IconsPage()),
  );
}

String _countText(WidgetTester tester, String key) {
  return tester.widget<Text>(find.byKey(ValueKey<String>(key))).data!;
}

int _officialSearchHitCount(String query) {
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

int _fullSearchHitCount(String query) {
  final String needle = query.toLowerCase();
  return harmonySymbolCatalog.keys.where((String name) {
    final IconData icon = harmonySymbolCatalog[name]!;
    final String unicode =
        'U+${icon.codePoint.toRadixString(16).toUpperCase().padLeft(5, '0')}';
    return '$name $unicode'.toLowerCase().contains(needle);
  }).length;
}

int _mirroringCount() {
  return harmonySymbolCatalog.keys
      .where((String name) => name.endsWith('_mirroring'))
      .length;
}

Finder _searchField(String key) {
  return find.descendant(
    of: find.byKey(ValueKey<String>(key)),
    matching: find.byType(TextField),
  );
}

Future<void> _openFullTab(WidgetTester tester) async {
  await tester.tap(find.text('全量 ${harmonySymbolCatalog.length}'));
  await tester.pump();
}

void main() {
  testWidgets('默认展示官方推荐集', (WidgetTester tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(
      _countText(tester, 'official-icons-count'),
      '显示 ${OhosIcons.count} / ${OhosIcons.count} 个',
    );
    expect(
      find.byKey(const ValueKey<String>('official-airplane_fill')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('full-ACC_cruise_control')),
      findsNothing,
    );
  });

  testWidgets('官方集搜索同时匹配英文名与中文名', (WidgetTester tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.enterText(_searchField('official-icons-search'), 'wifi');
    await tester.pump();

    final int expected = _officialSearchHitCount('wifi');
    expect(expected, greaterThan(0));
    expect(
      _countText(tester, 'official-icons-count'),
      '显示 $expected / ${OhosIcons.count} 个',
    );
    expect(find.byKey(const ValueKey<String>('official-wifi')), findsOneWidget);
  });

  testWidgets('切到全量 tab 展示 hm_symbol 的 3844 个字形', (WidgetTester tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await _openFullTab(tester);

    expect(
      _countText(tester, 'full-symbols-count'),
      '显示 ${harmonySymbolCatalog.length} / ${harmonySymbolCatalog.length} 个',
    );
    expect(
      find.byKey(const ValueKey<String>('full-ACC_cruise_control')),
      findsOneWidget,
    );
  });

  testWidgets('全量集可按英文名搜索并打开详情', (WidgetTester tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await _openFullTab(tester);
    await tester.enterText(_searchField('full-symbols-search'), 'wifi');
    await tester.pump();

    final int expected = _fullSearchHitCount('wifi');
    expect(expected, greaterThan(0));
    expect(
      _countText(tester, 'full-symbols-count'),
      '显示 $expected / ${harmonySymbolCatalog.length} 个',
    );

    final Finder wifiCell = find.byKey(const ValueKey<String>('full-wifi'));
    expect(wifiCell, findsOneWidget);
    await tester.tap(wifiCell);
    await tester.pumpAndSettle();

    expect(find.text('全量字形'), findsOneWidget);
    expect(find.text('Icon(HarmonySymbols.wifi)'), findsOneWidget);
    expect(find.text('U+F0000'), findsWidgets);
  });

  testWidgets('全量集可按镜像字形筛选', (WidgetTester tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await _openFullTab(tester);
    await tester.tap(find.text('镜像'));
    await tester.pump();

    final int expected = _mirroringCount();
    expect(expected, greaterThan(0));
    expect(
      _countText(tester, 'full-symbols-count'),
      '显示 $expected / ${harmonySymbolCatalog.length} 个',
    );
    expect(
      find.byKey(const ValueKey<String>('full-airplane_fill_mirroring')),
      findsOneWidget,
    );
  });

  testWidgets('全量 tab 在 320vp / 1.3x 字号不溢出', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host(textScale: 1.3));
    await tester.pump();
    await _openFullTab(tester);

    final Finder grid = find.byKey(
      const ValueKey<String>('full-symbols-grid'),
      skipOffstage: false,
    );
    await tester.drag(grid, const Offset(0, -700));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
