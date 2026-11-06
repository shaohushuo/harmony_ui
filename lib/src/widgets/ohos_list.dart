import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_divider.dart';
import 'ohos_list_tile.dart';

/// A grouped list container (列表 in the HarmonyOS guideline) that lays out
/// [OhosListTile]s on the theme card surface with hairline dividers.
///
/// Dividers are the list's business: each row boundary gets exactly one
/// hairline and the last row gets none. A direct [OhosListTile] child draws that
/// hairline itself — [OhosListDividerScope] tells it whether the boundary
/// exists — so the indent can follow its own `leading`. Any other child,
/// including a tile wrapped in a `Padding`/`InkWell`, is told `false` and gets a
/// default-indent divider inserted here instead, so a wrapped tile never stacks
/// a second line under the first.
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
                      // 只有直接放进列表的 tile 才需要「下面还有一行」这个信号。
                      // 非 tile 子节点（包括包了一层 Padding/InkWell 的 tile）
                      // 一律给 false：那条线由列表自己补，里面再画一条就叠成双线。
                      showBottom:
                          divider &&
                          i < children.length - 1 &&
                          children[i] is OhosListTile,
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
