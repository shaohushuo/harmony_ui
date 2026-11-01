import 'package:flutter/material.dart';

import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';

/// Option model of an [OhosSegmentedButton].
class OhosSegment<T> {
  const OhosSegment({required this.label, required this.value});

  /// Segment label.
  final String label;

  /// Value reported on selection.
  final T value;
}

/// A segmented control (分段按钮 in the HarmonyOS guideline).
class OhosSegmentedButton<T> extends StatelessWidget {
  const OhosSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.height = 40,
  });

  /// Segments of the control.
  final List<OhosSegment<T>> segments;

  /// Currently selected value.
  final T selected;

  /// Called when the user selects a segment.
  final ValueChanged<T> onSelected;

  /// When false the control is disabled.
  final bool enabled;

  /// Height of the control.
  final double height;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // 墨水屏：6% 的轨道底与页面同色，选中段的 cardColor 也是纯白 —— 三段会
    // 糊成一片，只剩字重差别。改成「轨道 + 选中段各一条 1px 实线」。
    final bool ink = theme.monochrome;
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ink
            ? Colors.transparent
            : theme.textPrimaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(height / 2),
        border: ink
            ? Border.all(
                color: theme.dividerColor,
                width: ohosStrokeWidth(context),
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final OhosSegment<T> segment in segments)
            Expanded(
              child: InkWell(
                onTap: enabled ? () => onSelected(segment.value) : null,
                borderRadius: BorderRadius.circular((height - 6) / 2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: segment.value == selected && !ink
                        ? theme.cardColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular((height - 6) / 2),
                    border: ink && segment.value == selected
                        ? Border.all(
                            color: theme.dividerColor,
                            width: ohosStrokeWidth(context),
                          )
                        : null,
                    // No outer shadow: it would bleed onto the neighbouring
                    // segments while tapping/animating.
                  ),
                  child: Text(
                    segment.label,
                    style: theme.typography.labelMedium?.copyWith(
                      color: segment.value == selected
                          ? theme.textPrimaryColor
                          : theme.textSecondaryColor,
                      fontWeight: segment.value == selected
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
