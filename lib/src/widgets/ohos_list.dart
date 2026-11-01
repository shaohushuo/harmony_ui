import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_divider.dart';
import 'ohos_list_tile.dart';

/// A grouped list container (列表 in the HarmonyOS guideline) that lays out
/// [OhosListTile]s on the theme card surface with hairline dividers.
///
/// Dividers are the list's business: each row boundary gets exactly one
/// hairline and the last row gets none. [OhosListTile]s inside the list are told
/// so through [OhosListDividerScope] and stop drawing their own, which used to
/// stack two lines of different indents on every boundary. Children that are
/// not [OhosListTile]s still get a divider inserted here.
class OhosList extends StatelessWidget {
  const OhosList({
    super.key,
    required this.children,
    this.header,
    this.headerPadding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
    this.divider = true,
  });

  /// Tiles inside the list.
  final List<Widget> children;

  /// Optional section header (usually an [OhosSubheader]).
  final Widget? header;

  /// Padding of the [header].
  final EdgeInsetsGeometry headerPadding;

  /// Whether tiles are separated by hairline dividers.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (header != null) Padding(padding: headerPadding, child: header!),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < children.length; i++)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    OhosListDividerScope(
                      showBottom: divider && i < children.length - 1,
                      child: children[i],
                    ),
                    // tile 自己会画线（indent 随 leading），只有非 tile 子节点
                    // 需要列表在这里补一条，避免又叠成两条。
                    if (divider &&
                        i < children.length - 1 &&
                        children[i] is! OhosListTile)
                      const OhosDivider(indent: 56, endIndent: 16),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
