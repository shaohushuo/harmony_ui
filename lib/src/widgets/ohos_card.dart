import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_press_feedback.dart';

/// A HarmonyOS card surface with a 24vp corner radius, the counterpart of
/// Flutter's Material [Card].
class OhosCard extends StatelessWidget {
  const OhosCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
    this.borderRadius = OhosGeometry.radiusLarge,
    this.elevation = 0,
  });

  /// The content of the card.
  final Widget child;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Outer margin.
  final EdgeInsetsGeometry? margin;

  /// Overrides the card surface color.
  final Color? color;

  /// Corner radius of the card.
  final double borderRadius;

  /// Shadow elevation.
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final OhosVisualPolicy policy = theme.policy;
    final Color surface = color ?? theme.cardColor;
    final Widget content = Padding(padding: padding, child: child);
    // 墨水屏上卡片默认面与页面同为纯白、阴影也不存在 —— 一整块内容会浮在
    // 白底上分不清边界。默认面补 1px 实线；调用方显式给了 color 就不再插手，
    // 免得把一块有色面（比如反白块）又框一条黑边。
    final bool outlined = policy.outlineWidth != null && color == null;
    final BoxDecoration decoration = BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: elevation == 0 || !policy.allowsShadow
          ? null
          : <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
    );
    // 描边画在子节点**之上**（foreground）：`padding: EdgeInsets.zero` 的卡片
    // 里，子节点自带整块底色时，它的抗锯齿边缘会把相邻的 1px 边洗掉 —— 直边
    // 尚存、圆角弧段整段变淡，看起来像「矩形框吃掉了圆角框」。
    final BoxDecoration? outline = outlined
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: theme.dividerColor,
              width: ohosStrokeWidth(context, policy.outlineWidth!),
            ),
          )
        : null;
    if (onTap == null) {
      return Container(
        margin: margin,
        decoration: decoration,
        foregroundDecoration: outline,
        // 子节点也要裁进圆角：`OhosActionBar` 的白底 + 通栏分隔线会把方角露在
        // 圆角外面，看起来像另有一个矩形框。
        clipBehavior: outlined ? Clip.antiAlias : Clip.none,
        child: content,
      );
    }
    return Container(
      margin: margin,
      decoration: decoration,
      foregroundDecoration: outline,
      clipBehavior: Clip.antiAlias,
      // 卡片的按压反馈是整块换一档底色，不是从触点扩散的水波纹 —— 后者的圆斑
      // 在大圆角卡片上会露出与圆角不一致的弧边。
      child: OhosPressFeedback(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      ),
    );
  }
}
