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
    final OhosVisualPolicy policy = theme.policy;
    // 6% 的轨道底与选中段的 cardColor 同为纯白 → 三段会糊成一片，只剩字重
    // 差别。策略把 6% 判成透明，下面改成「轨道 + 选中段各一条实线」。
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: policy.tint(theme.textPrimaryColor, 0.06),
        borderRadius: BorderRadius.circular(height / 2),
        border: policy.outlineWidth == null
            ? null
            : Border.all(
                color: theme.dividerColor,
                width: ohosStrokeWidth(context, policy.outlineWidth!),
              ),
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
                    // 选中段：彩屏是浮起的白药丸，墨屏是同样的一块白，只能靠线
                    color: segment.value == selected
                        ? theme.cardColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular((height - 6) / 2),
                    border: policy.outlineWidth != null &&
                            segment.value == selected
                        ? Border.all(
                            color: theme.dividerColor,
                            width: ohosStrokeWidth(
                              context,
                              policy.outlineWidth!,
                            ),
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
