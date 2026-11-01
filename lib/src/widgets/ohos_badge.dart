import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// A count or dot badge attached to icons and tabs, the `ohos_ui` counterpart
/// of Material's `Badge`.
///
/// The count badge is a circle (18vp, radius 9) for one or two digits and grows
/// into a **horizontal** capsule for longer values. It never follows the height
/// of the row it sits in: the label is measured against its own content, so a
/// badge inside a 48vp menu row is still 18×18 instead of an 18×46 pill.
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
        // 这里不能用 `alignment:` —— 它会插一个 `Align`，在「高度有界、宽度无界」
        // 的约束下（Row 里的非弹性子节点就是这样）宽高表现不一致：宽度收缩到
        // 内容、高度被拉到父级给的上限。侧边菜单 48vp 的行因此把 8 号 badge 拉成
        // 18×46 的竖胶囊。`Center` 带上两个 factor 后两个方向都只包住内容。
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
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
