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
    final OhosVisualPolicy policy = theme.policy;
    final Color active = widget.activeColor ?? theme.highlightColor;
    // 30% 灰的轨道落在 16 级灰的第 2 级，关闭态等于只有一个白圆点悬在白页面
    // 上 —— 用描边的主题一律留白，轮廓交给 [outlineWidth] 那条实线。
    final Color inactive =
        widget.inactiveColor ??
        (theme.usesOutlines
            ? Colors.transparent
            : theme.textTertiaryColor.withValues(alpha: 0.3));
    // 轨道 / 滑块共用的轮廓色：启用纯黑，禁用降一档到 #767676
    final Color lineColor = enabled
        ? theme.dividerColor
        : theme.textTertiaryColor;
    final double? outlineWidth = policy.outlineWidth;
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
            // 禁用 + 选中时轨道不再是实色，跟着描边一起降档
            color: widget.value
                ? (enabled ? active : policy.tint(active, 0.35))
                : inactive,
            borderRadius: BorderRadius.circular(trackHeight / 2),
          ),
          // 边框走 `foregroundDecoration`：`BoxDecoration.border` 会占掉内边距，
          // 26vp 的滑块被压成 26×24 的椭圆（轨道高 30、padding 2、边框 1）。
          foregroundDecoration: outlineWidth == null
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(trackHeight / 2),
                  border: Border.all(
                    color: lineColor,
                    width: ohosStrokeWidth(context, outlineWidth),
                  ),
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
                // 白滑块贴在白页面上等于没有滑块，靠描边读出来
                border: outlineWidth == null
                    ? null
                    : Border.all(
                        color: lineColor,
                        width: ohosStrokeWidth(context, outlineWidth),
                      ),
                // 阴影在墨水屏上不存在，别占一层刷新
                boxShadow: policy.allowsShadow
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
