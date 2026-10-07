import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// A HarmonyOS checkbox whose frame is rounded instead of square, the
/// counterpart of Flutter's [Checkbox].
class OhosCheckbox extends StatelessWidget {
  const OhosCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.size = 24,
  });

  /// Current value of the checkbox; true when checked.
  final bool value;

  /// Called when the user changes the state; null disables the checkbox.
  final ValueChanged<bool>? onChanged;

  /// Color of the checked frame and check mark.
  final Color? activeColor;

  /// Logical size of the checkbox.
  final double size;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = onChanged != null;
    final Color active = activeColor ?? theme.highlightColor;
    final double radius = size * 0.26;
    return Semantics(
      checked: value,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: OhosGeometry.durationShort,
          curve: OhosGeometry.spring,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: enabled && value
                ? active
                : (enabled
                      ? Colors.transparent
                      : theme.textTertiaryColor.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: value && enabled
                  ? active
                  : theme.textTertiaryColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: value
              ? Icon(
                  Icons.check_rounded,
                  size: size * 0.72,
                  color: Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}
