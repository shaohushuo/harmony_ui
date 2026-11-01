import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
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
    final bool ink = theme.monochrome;
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
            // 禁用态的 15% 灰底没有任何信息量，墨水屏上直接留白，交给描边。
            color: enabled && value
                ? active
                : (enabled || ink
                      ? Colors.transparent
                      : theme.textTertiaryColor.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              // 未选中的 50% 灰（≈#BBB）在 16 级灰上是第 3 级，几乎等于没有；
              // 墨水屏一律用实色，禁用时降一档到 #767676 以示区别。
              color: value && enabled
                  ? active
                  : (ink
                        ? theme.textTertiaryColor
                        : theme.textTertiaryColor.withValues(alpha: 0.5)),
              width: ohosStrokeWidth(context, 1.5),
            ),
          ),
          child: value
              ? Icon(
                  Icons.check_rounded,
                  size: size * 0.72,
                  // 禁用 + 选中时底色不再是实色，白勾会浮在浅灰上（真机：
                  // NoteAir 上只剩一个空框），跟着描边一起降到 #767676。
                  color: enabled ? Colors.white : theme.textTertiaryColor,
                )
              : null,
        ),
      ),
    );
  }
}
