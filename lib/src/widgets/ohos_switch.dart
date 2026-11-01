import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';

/// A HarmonyOS switch, the counterpart of Flutter's [Switch] and
/// Cupertino's [CupertinoSwitch].
class OhosSwitch extends StatefulWidget {
  const OhosSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.size = const Size(50, 30),
  });

  /// Current value of the switch.
  final bool value;

  /// Called when the user toggles the value; null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// Color of the track when active; defaults to the theme highlight color.
  final Color? activeColor;

  /// Color of the track when inactive.
  final Color? inactiveColor;

  /// Logical size of the whole switch.
  final Size size;

  @override
  State<OhosSwitch> createState() => _OhosSwitchState();
}

class _OhosSwitchState extends State<OhosSwitch> {
  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = widget.onChanged != null;
    final bool ink = theme.monochrome;
    final Color active = widget.activeColor ?? theme.highlightColor;
    // 墨水屏：30% 灰的轨道落在 16 级灰的第 2 级，关闭态等于只有一个白圆点
    // 悬在白页面上 —— 轨道改成留白 + 1px 实线，滑块也补轮廓。
    final Color inactive =
        widget.inactiveColor ??
        (ink
            ? Colors.transparent
            : theme.textTertiaryColor.withValues(alpha: 0.3));
    // 轨道 / 滑块共用的轮廓色：启用纯黑，禁用降一档到 #767676
    final Color inkLine = enabled ? theme.dividerColor : theme.textTertiaryColor;
    final double trackWidth = widget.size.width;
    final double trackHeight = widget.size.height;
    final double thumb = trackHeight - 4;
    return Semantics(
      toggled: widget.value,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? () => widget.onChanged!(!widget.value) : null,
        child: AnimatedContainer(
          duration: OhosGeometry.durationShort,
          curve: OhosGeometry.spring,
          width: trackWidth,
          height: trackHeight,
          decoration: BoxDecoration(
            color: widget.value
                ? (ink && !enabled ? theme.textTertiaryColor : active)
                : inactive,
            borderRadius: BorderRadius.circular(trackHeight / 2),
            border: ink
                ? Border.all(color: inkLine, width: ohosStrokeWidth(context))
                : null,
          ),
          padding: EdgeInsets.all((trackHeight - thumb) / 2),
          child: AnimatedAlign(
            duration: OhosGeometry.durationShort,
            curve: OhosGeometry.spring,
            alignment: widget.value
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              width: thumb,
              height: thumb,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: ink
                    ? Border.all(color: inkLine, width: ohosStrokeWidth(context))
                    : null,
                // 阴影在墨水屏上不存在，别占一层刷新
                boxShadow: ink
                    ? null
                    : const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
