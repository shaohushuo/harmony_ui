import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// A HarmonyOS radio button, the counterpart of Flutter's [Radio].
class OhosRadio extends StatelessWidget {
  const OhosRadio({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.size = 24,
  });

  /// Current value of the radio; true when selected.
  final bool value;

  /// Called when the user selects it; null disables the radio.
  final ValueChanged<bool>? onChanged;

  /// Color of the selected radio.
  final Color? activeColor;

  /// Logical size of the radio.
  final double size;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = onChanged != null;
    final Color active = activeColor ?? theme.highlightColor;
    return Semantics(
      checked: value,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: OhosGeometry.durationShort,
          curve: OhosGeometry.spring,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: value && enabled
                  ? active
                  : theme.textTertiaryColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          padding: EdgeInsets.all(size * 0.22),
          child: value
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled ? active : theme.textTertiaryColor,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
