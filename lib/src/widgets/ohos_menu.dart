import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// Menu style of [showOhosMenu].
enum OhosMenuStyle { list, grid }

/// Shows a rounded HarmonyOS menu anchored at a position (菜单 in the
/// HarmonyOS guideline).
///
/// ```dart
/// await showOhosMenu<String>(
///   context: context,
///   items: const [
///     OhosMenuItem(label: '复制', icon: Icons.copy, value: 'copy'),
///     OhosMenuItem(label: '删除', icon: Icons.delete, value: 'delete'),
///   ],
///   position: RelativeRect.fromLTRB(offset.dx, offset.dy, 0, 0),
/// );
/// ```
Future<T?> showOhosMenu<T>({
  required BuildContext context,
  required List<OhosMenuItem<T>> items,
  RelativeRect? position,
  OhosMenuStyle style = OhosMenuStyle.list,
}) {
  final RelativeRect rect = position ?? RelativeRect.fromLTRB(16, 120, 16, 16);
  return showMenu<T>(
    context: context,
    position: rect,
    color: OhosTheme.of(context).popupColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(OhosGeometry.radiusMedium),
      side: BorderSide(color: OhosTheme.of(context).dividerColor, width: 0.5),
    ),
    elevation: 8,
    items: <PopupMenuEntry<T>>[
      if (style == OhosMenuStyle.grid)
        PopupMenuItem<T>(
          enabled: false,
          child: Wrap(
            spacing: OhosGeometry.spaceMd,
            runSpacing: OhosGeometry.spaceSm,
            children: <Widget>[
              for (final OhosMenuItem<T> item in items)
                PopupMenuItem<T>(
                  value: item.value,
                  enabled: item.enabled,
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: OhosTheme.of(
                              context,
                            ).textPrimaryColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Icon(
                            item.icon ?? Icons.square_rounded,
                            size: 20,
                            color: item.danger
                                ? OhosTheme.of(context).dangerColor
                                : OhosTheme.of(context).textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OhosTheme.of(context).typography.labelSmall
                              ?.copyWith(
                                color: item.danger
                                    ? OhosTheme.of(context).dangerColor
                                    : OhosTheme.of(context).textPrimaryColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        )
      else
        for (final OhosMenuItem<T> item in items)
          PopupMenuItem<T>(
            value: item.value,
            enabled: item.enabled,
            child: Row(
              children: <Widget>[
                if (item.icon != null) ...<Widget>[
                  Icon(
                    item.icon,
                    size: 18,
                    color: item.danger
                        ? OhosTheme.of(context).dangerColor
                        : OhosTheme.of(context).textSecondaryColor,
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  item.label,
                  style: OhosTheme.of(context).typography.bodyMedium?.copyWith(
                    color: item.danger
                        ? OhosTheme.of(context).dangerColor
                        : OhosTheme.of(context).textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
    ],
  );
}

/// An entry of [showOhosMenu].
class OhosMenuItem<T> {
  const OhosMenuItem({
    required this.label,
    required this.value,
    this.icon,
    this.danger = false,
    this.enabled = true,
  });

  /// Display label.
  final String label;

  /// Value returned when the item is selected.
  final T value;

  /// Optional leading icon.
  final IconData? icon;

  /// When true the label is tinted with the danger color.
  final bool danger;

  /// When false the item cannot be selected.
  final bool enabled;
}
