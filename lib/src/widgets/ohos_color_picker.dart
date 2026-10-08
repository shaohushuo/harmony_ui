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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double size = _fitItemSize(constraints.maxWidth);
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: <Widget>[
            for (final Color color in colors)
              InkWell(
                onTap: () => onChanged(color),
                customBorder: const CircleBorder(),
                child: Container(
                  width: size,
                  height: size,
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
                      ? Icon(Icons.check_rounded, size: size * .5, color: Colors.white)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Shrinks the colour dots when the container is too narrow for the
  /// requested [itemSize], so the picker never overflows (e.g. inside a
  /// `Row`/`Expanded` on narrow screens).
  double _fitItemSize(double maxWidth) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return itemSize;
    }
    const double spacing = 14;
    const int targetPerRow = 5;
    if (colors.length <= targetPerRow) {
      return itemSize;
    }
    final double idealPerRow = ((maxWidth + spacing) / (itemSize + spacing));
    if (idealPerRow >= targetPerRow) {
      return itemSize;
    }
    final double fitted = (maxWidth - spacing * (targetPerRow - 1)) /
        targetPerRow;
    return fitted.clamp(18.0, itemSize).toDouble();
  }
}
