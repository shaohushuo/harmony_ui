import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// A scrollbar with HarmonyOS-styled rounded thumb, the counterpart of
/// Flutter's [Scrollbar].
class OhosScrollbar extends StatelessWidget {
  const OhosScrollbar({
    super.key,
    required this.controller,
    required this.child,
    this.thumbColor,
    this.thumbRadius = 4,
    this.thickness = 8,
  });

  /// Scroll controller attached to the scrollable child.
  final ScrollController controller;

  /// The scrollable widget.
  final Widget child;

  /// Thumb color; defaults to a translucent black.
  final Color? thumbColor;

  /// Radius of the rounded thumb.
  final double thumbRadius;

  /// Width of the scrollbar track.
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return RawScrollbar(
      controller: controller,
      thickness: thickness,
      radius: Radius.circular(thumbRadius),
      thumbColor: thumbColor ?? theme.textPrimaryColor.withValues(alpha: 0.30),
      child: child,
    );
  }
}
