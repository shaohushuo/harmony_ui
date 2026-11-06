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
    final OhosVisualPolicy policy = theme.policy;
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
            // 只有**禁用**态才铺那层 15% 灰底。启用但未选中必须留白：
            // `policy.tint` 在彩屏上恒返回带 alpha 的颜色（`ColorVisualPolicy`
            // 不判透明），少了 `enabled` 这一维，所有「启用未勾选」的复选框
            // 会在 light / dark 下多出一块浅灰，跟选中态的实心色抢对比度。
            // 墨水屏上这层灰本来就会被策略判成透明，交回描边。
            color: enabled && value
                ? active
                : (enabled
                      ? Colors.transparent
                      : policy.tint(theme.textTertiaryColor, 0.15)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              // 未选中的 50% 灰（≈#BBB）在 16 级灰上是第 3 级，几乎等于没有；
              // 策略一律换成实色，禁用时降一档以示区别。
              color: value && enabled
                  ? active
                  : policy.line(theme.textTertiaryColor, 0.5),
              width: ohosStrokeWidth(context, 1.5),
            ),
          ),
          child: value
              ? Icon(
                  Icons.check_rounded,
                  size: size * 0.72,
                  // 禁用 + 选中时底色不再是实色，白勾会浮在浅灰上（真机：
                  // NoteAir 上只剩一个空框），跟着描边一起降到提示色。
                  color: enabled ? Colors.white : theme.textTertiaryColor,
                )
              : null,
        ),
      ),
    );
  }
}
