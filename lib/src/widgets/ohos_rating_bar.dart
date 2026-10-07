import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// A star rating bar (评分条 in the HarmonyOS guideline).
class OhosRatingBar extends StatelessWidget {
  const OhosRatingBar({
    super.key,
    required this.value,
    this.onChanged,
    this.count = 5,
    this.starSize = 28,
    this.activeColor,
    this.inactiveColor,
  });

  /// Current rating (0..[count]).
  final int value;

  /// Called when the user taps a star; null disables interaction.
  final ValueChanged<int>? onChanged;

  /// Total number of stars.
  final int count;

  /// Diameter of each star.
  final double starSize;

  /// Color of filled stars; defaults to the warning color.
  final Color? activeColor;

  /// Color of empty stars.
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = onChanged != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 1; i <= count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              onPressed: enabled
                  ? () => onChanged!(i == value ? i - 1 : i)
                  : null,
              iconSize: starSize,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              icon: Icon(
                i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                color: i <= value
                    ? (activeColor ?? theme.warningColor)
                    : (inactiveColor ?? theme.textTertiaryColor),
              ),
              tooltip: '$i',
            ),
          ),
      ],
    );
  }
}
