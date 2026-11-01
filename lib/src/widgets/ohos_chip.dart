import 'package:flutter/material.dart';

import '../theme/ohos_stroke.dart';
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
    // 墨水屏：12% 的选中底与 30% 的描边都活不过 16 级灰阶，改成「留白 +
    // 选中纯黑边 / 未选中 #767676 边」，靠线的深浅而不是色的浓淡表意。
    final bool ink = theme.monochrome;
    final Color fg = selected ? theme.highlightColor : theme.textSecondaryColor;
    // 墨屏两种状态都不填色，一律透明底 + 描边。
    final Color idleFill = ink
        ? Colors.transparent
        : (theme.compBackgroundGrayColor ?? theme.cardColor);
    final Color selectedFill = ink
        ? Colors.transparent
        : (theme.emphasizeTertiaryColor ??
              theme.highlightColor.withValues(alpha: 0.10));
    final Color bg = selected
        ? (selectedColor ?? selectedFill)
        : idleFill;
    // 描边：墨屏选中纯黑、未选中 #767676；彩屏沿用半透明品牌色 / 30% 灰。
    final Color borderColor = selected
        ? (ink
              ? theme.dividerColor
              : (theme.emphasizeSecondaryColor ??
                    theme.highlightColor.withValues(alpha: 0.20)))
        : (ink
              ? theme.textTertiaryColor
              : theme.textTertiaryColor.withValues(alpha: 0.3));
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: ohosBorderSide(context, borderColor),
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
