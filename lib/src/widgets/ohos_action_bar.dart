import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_button.dart';
import 'ohos_divider.dart';

/// A bottom action bar (核心操作栏 in the HarmonyOS guideline): secondary
/// actions on the left, one primary action on the right.
class OhosActionBar extends StatelessWidget {
  const OhosActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryActions = const <Widget>[],
    this.primaryLoading = false,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  /// Label of the primary action.
  final String primaryLabel;

  /// Called when the primary action is tapped.
  final VoidCallback onPrimaryPressed;

  /// Secondary actions (typically text buttons) on the left.
  final List<Widget> secondaryActions;

  /// Whether the primary action shows a loading spinner.
  final bool primaryLoading;

  /// Padding around the bar.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Material(
      color: theme.cardColor,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const OhosDivider(indent: 0, endIndent: 0),
            Padding(
              padding: padding,
              child: Row(
                children: <Widget>[
                  for (final Widget action in secondaryActions)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: action,
                    ),
                  const Spacer(),
                  OhosButton(
                    onPressed: primaryLoading ? null : onPrimaryPressed,
                    loading: primaryLoading,
                    child: Text(primaryLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
