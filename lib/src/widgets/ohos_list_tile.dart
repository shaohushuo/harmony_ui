import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_divider.dart';
import 'ohos_press_feedback.dart';

/// Vertical rhythm of [OhosListTile].
enum OhosListTileDensity {
  /// Settings-list comfort: title 16sp, subtitle 14sp, 14vp vertical padding.
  regular,

  /// File / commit list rhythm: title 14sp, subtitle 12sp, 8vp padding.
  ///
  /// The Material equivalent is `ListTile(dense: true)`; use this instead of
  /// squeezing a regular tile when replacing a dense list.
  compact,
}

/// Tells [OhosListTile]s whether the surrounding [OhosList] wants a hairline
/// under this row.
///
/// 分隔线归列表所有：`OhosList` 在行与行之间画一条，列表内的 tile 就不再各画
/// 一条（否则每个边界会叠出两条 indent 不同的黑线）。不在列表里时
/// [maybeOf] 返回 `null`，由 tile 自己的 `divider` 决定。
class OhosListDividerScope extends InheritedWidget {
  const OhosListDividerScope({
    super.key,
    required this.showBottom,
    required super.child,
  });

  /// Whether the row draws a hairline below itself.
  final bool showBottom;

  /// `null` when the row is not inside an [OhosList].
  static bool? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<OhosListDividerScope>()
        ?.showBottom;
  }

  @override
  bool updateShouldNotify(OhosListDividerScope oldWidget) {
    return showBottom != oldWidget.showBottom;
  }
}

/// A HarmonyOS list item, the counterpart of Flutter's [ListTile].
///
/// Provides [leading], [title], [subtitle] and [trailing] slots on a white
/// surface with an optional hairline [divider] and a selected state tinted
/// with the brand color.
class OhosListTile extends StatelessWidget {
  const OhosListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.divider,
    this.density = OhosListTileDensity.regular,
    this.padding,
  });

  /// Leading widget (icon or avatar).
  final Widget? leading;

  /// The main line of the tile.
  final Widget title;

  /// Secondary line, typically a [Text] with secondary style.
  final Widget? subtitle;

  /// Trailing widget (chevron, switch, badge...).
  final Widget? trailing;

  /// Called when the tile is tapped.
  final VoidCallback? onTap;

  /// When true, the leading icon and title are tinted with the brand color.
  final bool selected;

  /// Whether to draw the hairline divider below the tile.
  ///
  /// `null` (the default) follows the surrounding [OhosList]: inside a list the
  /// list owns the dividers — one hairline per row boundary, none under the
  /// last row — and a tile standing on its own draws one.
  ///
  /// Pass `false` to force the line off even inside a list (a header row or a
  /// grouped section, say), or `true` to force it on.
  final bool? divider;

  /// Vertical rhythm; see [OhosListTileDensity].
  final OhosListTileDensity density;

  /// Inner padding of the tile; null uses the value implied by [density].
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color titleColor = selected
        ? theme.highlightColor
        : theme.textPrimaryColor;
    final bool compact = density == OhosListTileDensity.compact;
    final double titleSize = compact ? 14 : 16;
    final double subtitleSize = compact ? 12 : 14;
    final Widget content = Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 8 : 14),
      child: Row(
        children: <Widget>[
          if (leading != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconTheme.merge(
                data: IconThemeData(color: titleColor, size: 24),
                child: leading!,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DefaultTextStyle.merge(
                  style:
                      (theme.typography.bodyLarge ??
                              const TextStyle(fontSize: 16))
                          .copyWith(color: titleColor, fontSize: titleSize),
                  child: title,
                ),
                if (subtitle != null)
                  Padding(
                    padding: EdgeInsets.only(top: compact ? 2 : 4),
                    child: DefaultTextStyle.merge(
                      style:
                          (theme.typography.bodySmall ??
                                  const TextStyle(fontSize: 14))
                              .copyWith(
                                color: theme.textSecondaryColor,
                                fontSize: subtitleSize,
                              ),
                      child: subtitle!,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );

    // 分隔线不贯穿：左侧对齐文字（有 leading 时让到图标之后），右侧留出与
    // 内容相同的 16vp，两端都收进卡片里比通栏画一条好看。
    final double dividerIndent = leading == null ? 16 : 56;
    // 显式传值优先（`false` 就是关掉），没传才跟随所在列表，列表里也没人
    // 表态时默认画一条 —— 与 `divider` 原来的「默认 true」一致。
    final bool drawDivider =
        divider ?? OhosListDividerScope.maybeOf(context) ?? true;

    final Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (onTap == null)
          content
        else
          // 列表行的按压态是「整行换一档底色」，不是从触点扩散的水波纹。
          OhosPressFeedback(onTap: onTap, child: content),
        if (drawDivider) OhosDivider(indent: dividerIndent, endIndent: 16),
      ],
    );

    return Semantics(selected: selected, child: column);
  }
}
