import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// Item model of an [OhosToolbar].
class OhosToolbarItem {
  const OhosToolbarItem({
    required this.icon,
    required this.label,
    this.onPressed,
    this.selected = false,
  });

  /// Icon of the item.
  final IconData icon;

  /// Label of the item.
  final String label;

  /// Called when the item is tapped.
  final VoidCallback? onPressed;

  /// Whether the item is in the selected state.
  final bool selected;
}

/// A horizontal toolbar with icon items and separators (工具栏 in the
/// HarmonyOS guideline).
class OhosToolbar extends StatelessWidget {
  const OhosToolbar({super.key, required this.items, this.backgroundColor});

  /// Toolbar items.
  final List<OhosToolbarItem> items;

  /// Bar background; defaults to the theme card color.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Material(
      color: backgroundColor ?? theme.cardColor,
      child: SizedBox(
        height: 72,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            for (int i = 0; i < items.length; i++)
              Expanded(child: _OhosToolbarItemView(item: items[i])),
          ],
        ),
      ),
    );
  }
}

class _OhosToolbarItemView extends StatelessWidget {
  const _OhosToolbarItemView({required this.item});

  final OhosToolbarItem item;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color fg = item.selected
        ? theme.highlightColor
        : theme.textSecondaryColor;
    return InkWell(
      onTap: item.onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(item.icon, size: 24, color: fg),
          const SizedBox(height: 6),
          Text(
            item.label,
            style: theme.typography.labelSmall?.copyWith(
              color: fg,
              fontWeight: item.selected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
