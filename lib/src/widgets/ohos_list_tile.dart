import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_divider.dart';

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
    this.divider = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
  final bool divider;

  /// Inner padding of the tile.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color titleColor = selected
        ? theme.highlightColor
        : theme.textPrimaryColor;
    final Widget content = Padding(
      padding: padding,
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
                          .copyWith(color: titleColor),
                  child: title,
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: DefaultTextStyle.merge(
                      style:
                          (theme.typography.bodySmall ??
                                  const TextStyle(fontSize: 14))
                              .copyWith(color: theme.textSecondaryColor),
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

    final Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (onTap == null)
          content
        else
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: theme.highlightColor.withValues(alpha: 0.08),
              highlightColor: theme.highlightColor.withValues(alpha: 0.06),
              child: content,
            ),
          ),
        if (divider) const OhosDivider(),
      ],
    );

    return Semantics(selected: selected, child: column);
  }
}
