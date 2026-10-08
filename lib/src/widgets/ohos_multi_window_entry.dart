import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// An in-app multi-window entry (应用内多窗入口), the counterpart of
/// `MultiWindowEntryInAPP`.
///
/// Renders a tappable 48x48 tile with a leading icon and an optional
/// subtitle line. On devices without multi-window support the tile is
/// disabled (still rendered, non-interactive) like the ArkUI component.
class OhosMultiWindowEntry extends StatelessWidget {
  const OhosMultiWindowEntry({
    super.key,
    this.icon,
    this.subtitle,
    this.iconSize = 24,
    this.iconColor,
    this.backgroundColor,
    this.size = 48,
    this.enabled = true,
    this.onTap,
  });

  /// Leading icon (e.g. the target window icon).
  final Widget? icon;

  /// Optional subtitle shown under the icon.
  final String? subtitle;

  /// Icon size.
  final double iconSize;

  /// Icon color; defaults to the primary text color.
  final Color? iconColor;

  /// Tile background; defaults to the neutral component background.
  final Color? backgroundColor;

  /// Tile side length.
  final double size;

  /// When false the tile is rendered but does not respond to taps.
  final bool enabled;

  /// Called when the tile is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color fg = iconColor ?? theme.textPrimaryColor;
    final Color bg =
        backgroundColor ??
        (theme.compBackgroundGrayColor ?? theme.textPrimaryColor.withValues(alpha: 0.06));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: enabled ? bg : bg.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: enabled ? fg : fg.withValues(alpha: 0.4),
                    size: iconSize,
                  ),
                  child: icon ?? const Icon(Icons.open_in_new_rounded),
                ),
              ),
            ),
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: theme.typography.labelSmall?.copyWith(
              color: theme.textSecondaryColor,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}
