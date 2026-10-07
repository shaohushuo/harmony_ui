import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// A count or dot badge attached to icons and tabs, the `ohos_ui` counterpart
/// of Material's `Badge`.
class OhosBadge extends StatelessWidget {
  const OhosBadge({
    super.key,
    this.count,
    this.child,
    this.color,
    this.maxCount = 99,
    this.isDot = false,
    this.offset = Offset.zero,
  });

  /// The badge value; when null the badge is hidden but [child] remains.
  final int? count;

  /// The widget the badge is attached to.
  final Widget? child;

  /// Badge background color; defaults to [OhosColors.danger].
  final Color? color;

  /// Values above this are shown as "max+", e.g. "99+".
  final int maxCount;

  /// When true renders a plain dot instead of a numeric label.
  final bool isDot;

  /// Extra offset applied to the badge label.
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color badgeColor = color ?? theme.dangerColor;
    final Widget? label;
    if (isDot) {
      label = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
      );
    } else if (count != null) {
      final String text = count! > maxCount ? '$maxCount+' : '$count';
      label = Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      );
    } else {
      label = null;
    }
    if (child == null && label == null) {
      return const SizedBox.shrink();
    }
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: <Widget>[
        if (child != null) child!,
        if (label != null)
          if (child == null)
            label
          else
            Positioned(top: offset.dy, right: offset.dx, child: label),
      ],
    );
  }
}
