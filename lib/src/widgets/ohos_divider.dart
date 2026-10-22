import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// A hairline divider used to separate list items, the counterpart of
/// Flutter's [Divider].
///
/// [indent] defaults to 0, the same as Material's `Divider`, so a straight
/// replacement keeps the previous geometry. Insets that align the hairline with
/// list text are the caller's job — `OhosListTile` passes `indent: 16` itself.
class OhosDivider extends StatelessWidget {
  const OhosDivider({
    super.key,
    this.thickness = 0.5,
    this.color,
    this.indent = 0,
    this.endIndent = 0,
    this.height = 1,
  });

  /// The line thickness.
  final double thickness;

  /// Line color; defaults to the theme divider color.
  final Color? color;

  /// Leading padding before the line.
  final double indent;

  /// Trailing padding after the line.
  final double endIndent;

  /// Total logical height occupied.
  final double height;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: SizedBox(
        height: height,
        child: Center(
          child: Container(
            height: thickness,
            color: color ?? theme.dividerColor,
          ),
        ),
      ),
    );
  }
}
