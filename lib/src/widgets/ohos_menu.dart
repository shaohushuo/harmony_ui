import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// Menu style of [showOhosMenu].
enum OhosMenuStyle { list, grid }

/// Shows a rounded HarmonyOS menu anchored at a position (菜单 in the
/// HarmonyOS guideline).
///
/// Pass [anchor] (a [BuildContext] or [GlobalKey] of the triggering widget)
/// so the menu pops up right below the trigger; otherwise provide [position]
/// explicitly.
///
/// ```dart
/// await showOhosMenu<String>(
///   context: context,
///   anchor: buttonKey,
///   items: const [
///     OhosMenuItem(label: '复制', icon: Icons.copy, value: 'copy'),
///     OhosMenuItem(label: '删除', icon: Icons.delete, value: 'delete'),
///   ],
/// );
/// ```
Future<T?> showOhosMenu<T>({
  required BuildContext context,
  required List<OhosMenuItem<T>> items,
  RelativeRect? position,

  /// Menu style: a vertical list or a grid.
  OhosMenuStyle style = OhosMenuStyle.list,

  /// Widget to anchor the menu to — a [BuildContext] or [GlobalKey] of the
  /// triggering control. When provided the menu is positioned right below it.
  Object? anchor,
}) {
  final RelativeRect rect =
      position ??
      _anchorRect(context, anchor) ??
      RelativeRect.fromLTRB(16, 120, 16, 16);
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

/// Computes a [RelativeRect] that anchors the menu below the widget
/// referenced by [anchor] (a [BuildContext] or a [GlobalKey]). Falls back to
/// `null` when the anchor cannot be resolved.
RelativeRect? _anchorRect(BuildContext context, Object? anchor) {
  BuildContext? anchorContext;
  if (anchor is BuildContext) {
    anchorContext = anchor;
  } else if (anchor is GlobalKey) {
    anchorContext = anchor.currentContext;
  }
  if (anchorContext == null) {
    return null;
  }
  final RenderBox? box = anchorContext.findRenderObject() as RenderBox?;
  final RenderBox? overlay = Overlay.maybeOf(
    context,
    rootOverlay: true,
  )?.context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null || !box.hasSize) {
    return null;
  }
  final Offset topLeft = box.localToGlobal(Offset.zero);
  final Offset bottomRight = box.localToGlobal(
    box.size.bottomRight(Offset.zero),
  );
  final double gap = 4;
  return RelativeRect.fromLTRB(
    topLeft.dx,
    bottomRight.dy + gap,
    overlay.size.width - bottomRight.dx,
    overlay.size.height - bottomRight.dy - gap,
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
