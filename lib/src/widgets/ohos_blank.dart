import 'package:flutter/material.dart';

/// A flexible blank area used to push content, matching the "空白" control in
/// the HarmonyOS design guideline (e.g. an empty list bottom).
///
/// When placed inside a bounded box (e.g. wrapped by `Expanded` in a `Column`)
/// the blank fills the available space; in an unbounded context (e.g. directly
/// inside a `ListView`) it only occupies [minSize] so it never creates
/// endless scrolling space.
class OhosBlank extends StatelessWidget {
  const OhosBlank({super.key, this.minSize = 0});

  /// Minimum height the blank occupies when the surrounding constraints are
  /// unbounded or smaller than this value.
  final double minSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool bounded = constraints.maxHeight.isFinite;
        final double height = bounded
            ? constraints.maxHeight < minSize
                ? minSize
                : constraints.maxHeight
            : minSize;
        return SizedBox(
          width: constraints.maxWidth.isFinite ? double.infinity : null,
          height: height,
        );
      },
    );
  }
}
