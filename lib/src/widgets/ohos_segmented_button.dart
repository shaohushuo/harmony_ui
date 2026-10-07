import 'package:flutter/material.dart';

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
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.textPrimaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(height / 2),
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
                    color: segment.value == selected
                        ? theme.cardColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular((height - 6) / 2),
                    boxShadow: segment.value == selected
                        ? <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
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
