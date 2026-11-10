import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_press_feedback.dart';

/// A two-state toggle button (状态按钮 in the HarmonyOS guideline).
class OhosToggleButton extends StatelessWidget {
  const OhosToggleButton({
    super.key,
    required this.value,
    required this.onChanged,
    required this.child,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
  });

  /// Whether the button is in the "on" state.
  final bool value;

  /// Called when the user toggles the state.
  final ValueChanged<bool> onChanged;

  /// Button content.
  final Widget child;

  /// Optional leading icon.
  final Widget? icon;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final OhosVisualPolicy policy = theme.policy;
    final Color highlight = theme.highlightColor;
    final Color fg = value ? highlight : theme.textSecondaryColor;
    final BorderRadius radius = BorderRadius.circular(
      OhosGeometry.radiusCapsule,
    );
    return DecoratedBox(
      // 底色与描边原来挂在 `Material(shape: ...)` 上，顺带拿到了水波纹。
      // 切换按钮是胶囊，水波纹的圆斑会跨出圆角 —— 换成自绘底 + 整块按压反馈。
      decoration: BoxDecoration(
        // 12% 的选中底在墨屏上与页面同色，策略判成透明后由描边接手。
        color: value ? policy.tint(highlight, 0.12) : theme.cardColor,
        borderRadius: radius,
        // 50% / 35% 的边在灰阶屏上会淡掉，策略换成实色，选中时提到纯黑。
        border: Border.fromBorderSide(
          ohosBorderSide(
            context,
            value
                ? policy.line(highlight, 0.5)
                : policy.line(theme.textTertiaryColor, 0.35),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: OhosPressFeedback(
          onTap: () => onChanged(!value),
          borderRadius: radius,
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  IconTheme.merge(
                    data: IconThemeData(color: fg, size: 18),
                    child: icon!,
                  ),
                  const SizedBox(width: 8),
                ],
                DefaultTextStyle.merge(
                  style:
                      (theme.typography.labelLarge ??
                              const TextStyle(fontSize: 16))
                          .copyWith(color: fg),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
