import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_icon_button.dart';

/// The top application bar of `ohos_ui`, the counterpart of Flutter's
/// [AppBar].
///
/// Renders a back button when [leading] is provided or
/// [automaticallyImplyLeading] is true and a route can pop; a centered
/// [title]; and [actions] on the trailing edge.
class OhosAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OhosAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.elevation = 0,
    this.height = 56,
  });

  /// The main title widget, typically a [Text].
  final Widget? title;

  /// Leading widget of the bar (back button etc.).
  final Widget? leading;

  /// Actions displayed at the trailing edge.
  final List<Widget>? actions;

  /// When true and [leading] is null, a back button is inserted when the
  /// enclosing route can actually pop.
  final bool automaticallyImplyLeading;

  /// Overrides the bar background color.
  final Color? backgroundColor;

  /// Shadow elevation; HarmonyOS bars are usually flat so the default is 0.
  final double elevation;

  /// Logical height of the bar.
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    final bool canPop = route?.canPop ?? false;
    Widget? leadingWidget = leading;
    if (leadingWidget == null && automaticallyImplyLeading && canPop) {
      leadingWidget = OhosIconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.maybePop(context),
      );
    }
    return Material(
      color: backgroundColor ?? theme.backgroundColor,
      elevation: elevation,
      child: SizedBox(
        height: preferredSize.height,
        child: Row(
          children: <Widget>[
            if (leadingWidget != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: leadingWidget,
              ),
            Expanded(
              child: DefaultTextStyle.merge(
                style:
                    theme.typography.titleMedium ??
                    const TextStyle(fontSize: 17),
                textAlign: TextAlign.center,
                child: Align(
                  alignment: Alignment.center,
                  child: title ?? const SizedBox.shrink(),
                ),
              ),
            ),
            if (actions != null && actions!.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final Widget action in actions!) action,
                  const SizedBox(width: 8),
                ],
              ),
            SizedBox(width: leadingWidget == null ? 8 : 0),
          ],
        ),
      ),
    );
  }
}
