import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_press_feedback.dart';

/// A square icon button with HarmonyOS press feedback, the counterpart of
/// Flutter's [IconButton].
class OhosIconButton extends StatelessWidget {
  const OhosIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.onLongPress,
    this.color,
    this.backgroundColor,
    this.size = 48,
    this.iconSize = 24,
    this.tooltip,
  });

  /// The icon to display.
  final Widget icon;

  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  /// Called when the button is long-pressed.
  final VoidCallback? onLongPress;

  /// Icon color; defaults to the theme primary text color.
  final Color? color;

  /// Background color for filled variants.
  final Color? backgroundColor;

  /// The width and height of the touch target.
  final double size;

  /// The icon size.
  final double iconSize;

  /// Tooltip text for accessibility.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = onPressed != null;
    final Color effective =
        color ?? (enabled ? theme.textPrimaryColor : theme.textTertiaryColor);
    final BorderRadius radius = BorderRadius.circular(size / 2);
    return Tooltip(
      message: tooltip ?? '',
      child: Semantics(
        button: true,
        enabled: enabled,
        child: DecoratedBox(
          // 圆形底原来由 `Material(shape: CircleBorder())` 提供。Material 会给
          // 每个可点子节点挂上水波纹 —— 一个 40vp 的图标按钮上，那圈扩散的
          // 圆形高光几乎盖满整个按钮，是「Material 的味道」最重的一处。
          // 底色自己画，按压反馈换成整块换一档色（圆形靠圆角裁出）。
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.transparent,
            borderRadius: radius,
          ),
          child: OhosPressFeedback(
            onTap: onPressed,
            onLongPress: onLongPress,
            borderRadius: radius,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(size: iconSize, color: effective),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
