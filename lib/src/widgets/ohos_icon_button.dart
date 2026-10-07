import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// A square icon button with HarmonyOS press feedback, the counterpart of
/// Flutter's [IconButton].
class OhosIconButton extends StatelessWidget {
  const OhosIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.onLongPress,
    this.color,
    this.backgroundColor,
    this.size = 48,
    this.iconSize = 24,
    this.tooltip,
  });

  /// The icon to display.
  final Widget icon;

  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  /// Called when the button is long-pressed.
  final VoidCallback? onLongPress;

  /// Icon color; defaults to the theme primary text color.
  final Color? color;

  /// Background color for filled variants.
  final Color? backgroundColor;

  /// The width and height of the touch target.
  final double size;

  /// The icon size.
  final double iconSize;

  /// Tooltip text for accessibility.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = onPressed != null;
    final Color effective =
        color ?? (enabled ? theme.textPrimaryColor : theme.textTertiaryColor);
    final Color splash = theme.highlightColor.withValues(alpha: 0.12);
    return Tooltip(
      message: tooltip ?? '',
      child: Semantics(
        button: true,
        enabled: enabled,
        child: Material(
          color: backgroundColor ?? Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            onLongPress: onLongPress,
            customBorder: const CircleBorder(),
            splashColor: splash,
            highlightColor: splash,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(size: iconSize, color: effective),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
