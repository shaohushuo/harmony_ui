import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_divider.dart';
import 'ohos_list_tile.dart';

/// A grouped list container (列表 in the HarmonyOS guideline) that lays out
/// [OhosListTile]s on the theme card surface with hairline dividers.
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
                    children[i],
                    if (divider && i < children.length - 1)
                      const OhosDivider(indent: 56),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
