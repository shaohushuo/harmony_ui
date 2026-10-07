import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// A two-state toggle button (状态按钮 in the HarmonyOS guideline).
class OhosToggleButton extends StatelessWidget {
  const OhosToggleButton({
    super.key,
    required this.value,
    required this.onChanged,
    required this.child,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
  });

  /// Whether the button is in the "on" state.
  final bool value;

  /// Called when the user toggles the state.
  final ValueChanged<bool> onChanged;

  /// Button content.
  final Widget child;

  /// Optional leading icon.
  final Widget? icon;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color highlight = theme.highlightColor;
    final Color fg = value ? highlight : theme.textSecondaryColor;
    return Material(
      color: value ? highlight.withValues(alpha: 0.12) : theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OhosGeometry.radiusCapsule),
        side: BorderSide(
          color: value
              ? highlight.withValues(alpha: 0.5)
              : theme.textTertiaryColor.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                IconTheme.merge(
                  data: IconThemeData(color: fg, size: 18),
                  child: icon!,
                ),
                const SizedBox(width: 8),
              ],
              DefaultTextStyle.merge(
                style:
                    (theme.typography.labelLarge ??
                            const TextStyle(fontSize: 16))
                        .copyWith(color: fg),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
