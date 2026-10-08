import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';
import 'ohos_badge.dart';

/// A sub (second-level) item of an [OhosSideMenuItem].
class OhosSideMenuSubItem {
  const OhosSideMenuSubItem({
    required this.label,
    this.value,
    this.badgeCount,
    this.enabled = true,
  });

  /// Display label.
  final String label;

  /// Value reported on selection; defaults to [label].
  final String? value;

  /// Optional new-message count badge.
  final int? badgeCount;

  /// When false the item cannot be selected.
  final bool enabled;
}

/// A main (first-level) item of an [OhosSideMenu].
class OhosSideMenuItem {
  const OhosSideMenuItem({
    required this.label,
    this.icon,
    this.value,
    this.badgeCount,
    this.subItems = const <OhosSideMenuSubItem>[],
    this.enabled = true,
  });

  /// Display label of the main item.
  final String label;

  /// Optional leading icon.
  final Widget? icon;

  /// Value reported on selection; defaults to [label].
  final String? value;

  /// Optional new-message count badge on the main item.
  final int? badgeCount;

  /// Optional second-level items; when non-empty the row expands.
  final List<OhosSideMenuSubItem> subItems;

  /// When false the item cannot be selected.
  final bool enabled;
}

/// A HarmonyOS side menu (侧边栏菜单), the counterpart of `HdsSideMenu`.
///
/// Renders first-level [items]; a main item with [OhosSideMenuItem.subItems]
/// expands to reveal its second-level entries. Selected rows are highlighted
/// with the brand color, and [OhosSideMenuSubItem.badgeCount] shows the
/// new-message red dot / count.
class OhosSideMenu extends StatefulWidget {
  const OhosSideMenu({
    super.key,
    required this.items,
    this.selectedValue,
    this.onSelected,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  /// Menu items.
  final List<OhosSideMenuItem> items;

  /// Currently selected value (main or sub item).
  final String? selectedValue;

  /// Called when a selectable item is tapped.
  final ValueChanged<String>? onSelected;

  /// Vertical padding around the list.
  final EdgeInsetsGeometry padding;

  @override
  State<OhosSideMenu> createState() => _OhosSideMenuState();
}

class _OhosSideMenuState extends State<OhosSideMenu> {
  final Set<String> _expanded = <String>{};

  bool _isExpanded(OhosSideMenuItem item) {
    return _expanded.contains(item.value ?? item.label);
  }

  void _toggle(OhosSideMenuItem item) {
    setState(() {
      final String key = item.value ?? item.label;
      if (!_expanded.remove(key)) {
        _expanded.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return ListView(
      padding: widget.padding,
      children: <Widget>[
        for (final OhosSideMenuItem item in widget.items) ...<Widget>[
          _mainItem(item, theme),
          if (_isExpanded(item))
            for (final OhosSideMenuSubItem sub in item.subItems) _subItem(sub),
        ],
      ],
    );
  }

  Widget _mainItem(OhosSideMenuItem item, OhosThemeData theme) {
    final bool selected = widget.selectedValue == (item.value ?? item.label);
    final bool expanded = _isExpanded(item);
    final bool hasChildren = item.subItems.isNotEmpty;
    final Color fg = selected ? theme.highlightColor : theme.textPrimaryColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.enabled
            ? () {
                if (hasChildren) {
                  _toggle(item);
                }
                widget.onSelected?.call(item.value ?? item.label);
              }
            : null,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: selected
              ? (theme.emphasizeSecondaryColor ??
                    theme.highlightColor.withValues(alpha: 0.12))
              : Colors.transparent,
          child: Row(
            children: <Widget>[
              if (item.icon != null) ...<Widget>[
                IconTheme.merge(
                  data: IconThemeData(color: fg, size: 20),
                  child: item.icon!,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (theme.typography.bodyMedium ??
                          const TextStyle(fontSize: 15))
                      .copyWith(color: fg, fontWeight: FontWeight.w500),
                ),
              ),
              if (item.badgeCount != null) ...<Widget>[
                const SizedBox(width: 8),
                OhosBadge(count: item.badgeCount!),
              ],
              if (hasChildren) ...<Widget>[
                const SizedBox(width: 6),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: theme.textTertiaryColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _subItem(OhosSideMenuSubItem sub) {
    return Builder(
      builder: (BuildContext context) {
        final OhosThemeData theme = OhosTheme.of(context);
        final bool selected = widget.selectedValue == (sub.value ?? sub.label);
        final Color fg = selected
            ? theme.highlightColor
            : theme.textSecondaryColor;
        return InkWell(
          onTap: sub.enabled
              ? () => widget.onSelected?.call(sub.value ?? sub.label)
              : null,
          child: Container(
            height: 44,
            padding: const EdgeInsets.only(left: 44, right: 16),
            decoration: BoxDecoration(
              color: selected
                  ? (theme.emphasizeSecondaryColor ??
                        theme.highlightColor.withValues(alpha: 0.12))
                  : Colors.transparent,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(OhosGeometry.radiusMedium),
                bottomRight: Radius.circular(OhosGeometry.radiusMedium),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: selected ? theme.highlightColor : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sub.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (theme.typography.bodyMedium ??
                            const TextStyle(fontSize: 15))
                        .copyWith(color: fg),
                  ),
                ),
                if (sub.badgeCount != null) ...<Widget>[
                  const SizedBox(width: 8),
                  OhosBadge(count: sub.badgeCount!),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
