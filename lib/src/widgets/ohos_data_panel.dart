import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// A key-value data statistics panel (数据可视化 in the HarmonyOS guideline)
/// that renders a series of metrics on cards.
class OhosDataPanel extends StatelessWidget {
  const OhosDataPanel({
    super.key,
    required this.title,
    required this.entries,
    this.columns = 2,
    this.decimals = 0,
    this.prefix,
    this.suffix,
  });

  /// Panel title.
  final String title;

  /// Metric entries: label -> value.
  final Map<String, num> entries;

  /// Number of columns in the grid.
  final int columns;

  /// Decimal places of the values.
  final int decimals;

  /// Prefix symbol, e.g. `¥`.
  final String? prefix;

  /// Suffix symbol, e.g. `%`, `万`.
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final List<MapEntry<String, num>> items = entries.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            title,
            style: theme.typography.titleSmall?.copyWith(
              color: theme.textPrimaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: <Widget>[
            for (final MapEntry<String, num> entry in items)
              _OhosDataPanelItem(
                entry: entry,
                theme: theme,
                decimals: decimals,
                prefix: prefix,
                suffix: suffix,
              ),
          ],
        ),
      ],
    );
  }
}

class _OhosDataPanelItem extends StatelessWidget {
  const _OhosDataPanelItem({
    required this.entry,
    required this.theme,
    required this.decimals,
    required this.prefix,
    required this.suffix,
  });

  final MapEntry<String, num> entry;
  final OhosThemeData theme;
  final int decimals;
  final String? prefix;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            entry.key,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.bodySmall?.copyWith(
              color: theme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${prefix ?? ''}${entry.value.toStringAsFixed(decimals)}${suffix ?? ''}',
            maxLines: 1,
            style: theme.typography.headlineMedium?.copyWith(
              color: theme.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
