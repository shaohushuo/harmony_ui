import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// A HarmonyOS filter chip used for tags and multi-select filters, the
/// counterpart of Material's [FilterChip] / [ActionChip].
class OhosChip extends StatelessWidget {
  const OhosChip({
    super.key,
    required this.label,
    this.onPressed,
    this.selected = false,
    this.icon,
    this.selectedColor,
  });

  /// The chip label.
  final Widget label;

  /// Called when the chip is tapped; null disables the chip.
  final VoidCallback? onPressed;

  /// Whether the chip is currently selected.
  final bool selected;

  /// Optional leading icon.
  final Widget? icon;

  /// Background color when selected; defaults to a brand-tinted surface.
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = onPressed != null;
    final Color fg = selected ? theme.highlightColor : theme.textSecondaryColor;
    final Color bg = selected
        ? (selectedColor ??
              (theme.emphasizeTertiaryColor ??
                  theme.highlightColor.withValues(alpha: 0.10)))
        : (theme.compBackgroundGrayColor ?? theme.cardColor);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? (theme.emphasizeSecondaryColor ??
                    theme.highlightColor.withValues(alpha: 0.20))
              : theme.textTertiaryColor.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                IconTheme.merge(
                  data: IconThemeData(color: fg, size: 16),
                  child: icon!,
                ),
                const SizedBox(width: 6),
              ],
              DefaultTextStyle.merge(
                style:
                    (theme.typography.labelMedium ??
                            const TextStyle(fontSize: 14))
                        .copyWith(color: fg),
                child: label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
