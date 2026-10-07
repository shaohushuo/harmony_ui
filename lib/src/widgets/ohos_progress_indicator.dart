import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// Circular and linear progress indicators with HarmonyOS styling, the
/// counterpart of Flutter's [CircularProgressIndicator] / [LinearProgressIndicator].
///
/// When [value] is null the indicator animates indefinitely.
class OhosProgressIndicator extends StatelessWidget {
  const OhosProgressIndicator.circular({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.size = 48,
    this.strokeWidth = 4,
  }) : variant = OhosProgressIndicatorVariant.circular,
       trackHeight = null;

  const OhosProgressIndicator.linear({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.trackHeight = 4,
  }) : variant = OhosProgressIndicatorVariant.linear,
       size = 48,
       strokeWidth = 4;

  final OhosProgressIndicatorVariant variant;
  final double? value;
  final Color? color;
  final Color? backgroundColor;
  final double? size;
  final double? strokeWidth;
  final double? trackHeight;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color active = color ?? theme.highlightColor;
    final Color track =
        backgroundColor ?? theme.highlightColor.withValues(alpha: 0.15);
    switch (variant) {
      case OhosProgressIndicatorVariant.circular:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: value,
            color: active,
            backgroundColor: track,
            strokeWidth: strokeWidth!,
          ),
        );
      case OhosProgressIndicatorVariant.linear:
        return ClipRRect(
          borderRadius: BorderRadius.circular(trackHeight! / 2),
          child: SizedBox(
            height: trackHeight,
            child: LinearProgressIndicator(
              value: value,
              color: active,
              backgroundColor: track,
            ),
          ),
        );
    }
  }
}

/// The visual variant of an [OhosProgressIndicator].
enum OhosProgressIndicatorVariant { circular, linear }
