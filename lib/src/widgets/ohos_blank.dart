import 'package:flutter/material.dart';

/// A flexible blank area used to push content, matching the "空白" control in
/// the HarmonyOS design guideline (e.g. an empty list bottom). Behaves like a
/// `SizedBox` in a column/row but expands when placed in a `Flex`.
class OhosBlank extends StatelessWidget {
  const OhosBlank({super.key, this.minSize = 0});

  /// Minimum height the blank occupies when the surrounding constraints are
  /// unbounded or smaller than this value.
  final double minSize;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minSize),
      child: const SizedBox.expand(),
    );
  }
}
