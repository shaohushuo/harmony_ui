import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// Composes a layered icon (分层图标), the Flutter counterpart of the HDS
/// `LayeredDrawableDescriptor` pipeline (`getHdsLayeredIcon`).
///
/// Renders [foreground] on top of [background] inside a rounded square,
/// optionally scaling the foreground (padding) and drawing a border stroke.
class OhosLayeredIcon extends StatelessWidget {
  const OhosLayeredIcon({
    super.key,
    this.size = 48,
    required this.foreground,
    this.background = const Color(0xFFE3E6EA),
    this.borderRadius = 12,
    this.padding = 10,
    this.borderColor,
    this.borderWidth = 1,
    this.clip = true,
  });

  /// Side length of the composed icon.
  final double size;

  /// Foreground layer (icon / symbol).
  final Widget foreground;

  /// Background layer color.
  final Color background;

  /// Corner radius of the background plate.
  final double borderRadius;

  /// Inner padding between the plate edge and the foreground.
  final double padding;

  /// Optional stroke color around the plate.
  final Color? borderColor;

  /// Stroke width of the plate border.
  final double borderWidth;

  /// Whether to clip the foreground to the rounded plate.
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color stroke = borderColor ?? theme.textTertiaryColor.withValues(alpha: 0.25);
    Widget plate = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderWidth > 0
            ? Border.all(color: stroke, width: borderWidth)
            : null,
      ),
      child: Center(child: foreground),
    );
    if (clip) {
      plate = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: plate,
      );
    }
    return plate;
  }
}
