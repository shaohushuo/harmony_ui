import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// An image container with HarmonyOS styling (rounded corners, optional
/// highlight border for selected state), the `ohos_ui` counterpart of
/// Material's [Image] wrapped in a [ClipRRect].
class OhosImage extends StatelessWidget {
  const OhosImage({
    super.key,
    required this.image,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.selected = false,
    this.borderColor,
    this.placeholder,
  });

  /// The image provider.
  final ImageProvider image;

  /// Width of the image area.
  final double? width;

  /// Height of the image area.
  final double? height;

  /// Corner radius; defaults to the theme small radius.
  final double? borderRadius;

  /// How the image fits into the box.
  final BoxFit fit;

  /// When true a brand-colored border highlights the image.
  final bool selected;

  /// Overrides the selected border color.
  final Color? borderColor;

  /// Widget shown while the image loads.
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.textTertiaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(borderRadius ?? 8),
        border: selected
            ? Border.all(color: borderColor ?? theme.highlightColor, width: 2)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image(
        image: image,
        fit: fit,
        width: width,
        height: height,
        frameBuilder: placeholder == null
            ? null
            : (BuildContext context, Widget child, int? frame, bool sync) {
                return frame == null ? placeholder! : child;
              },
      ),
    );
  }
}
