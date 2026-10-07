import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// A palette-style color picker (色彩选择器 in the HarmonyOS guideline)
/// built on the 11-color HarmonyOS multi-color system.
class OhosColorPicker extends StatelessWidget {
  const OhosColorPicker({
    super.key,
    required this.colors,
    required this.selectedColor,
    required this.onChanged,
    this.itemSize = 36,
  });

  /// Available colors.
  final List<Color> colors;

  /// Currently selected color.
  final Color selectedColor;

  /// Called when a color is tapped.
  final ValueChanged<Color> onChanged;

  /// Diameter of each color dot.
  final double itemSize;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: <Widget>[
        for (final Color color in colors)
          InkWell(
            onTap: () => onChanged(color),
            customBorder: const CircleBorder(),
            child: Container(
              width: itemSize,
              height: itemSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color == selectedColor
                      ? theme.textPrimaryColor
                      : Colors.transparent,
                  width: 3,
                ),
              ),
              child: color == selectedColor
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}
