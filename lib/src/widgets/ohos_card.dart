import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// A HarmonyOS card surface with a 24vp corner radius, the counterpart of
/// Flutter's Material [Card].
class OhosCard extends StatelessWidget {
  const OhosCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
    this.borderRadius = OhosGeometry.radiusLarge,
    this.elevation = 0,
  });

  /// The content of the card.
  final Widget child;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Outer margin.
  final EdgeInsetsGeometry? margin;

  /// Overrides the card surface color.
  final Color? color;

  /// Corner radius of the card.
  final double borderRadius;

  /// Shadow elevation.
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color surface = color ?? theme.cardColor;
    final Widget content = Padding(padding: padding, child: child);
    if (onTap == null) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: elevation == 0
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: content,
      );
    }
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: elevation == 0
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: theme.highlightColor.withValues(alpha: 0.10),
          highlightColor: theme.highlightColor.withValues(alpha: 0.08),
          child: content,
        ),
      ),
    );
  }
}
