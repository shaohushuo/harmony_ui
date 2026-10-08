import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_app_bar.dart';

/// The page-level layout container of `ohos_ui`, the counterpart of Flutter's
/// [Scaffold].
///
/// Paints the theme background color and lays out an optional [appBar], the
/// [body], a [bottomNavigationBar] and a [floatingActionButton].
class OhosScaffold extends StatelessWidget {
  const OhosScaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.drawer,
    this.endDrawer,
  });

  /// Optional top application bar.
  final OhosAppBar? appBar;

  /// The primary content of the page.
  final Widget? body;

  /// Optional bottom navigation bar.
  final Widget? bottomNavigationBar;

  /// Optional floating action button (usually an [OhosIconButton]).
  final Widget? floatingActionButton;

  /// Overrides the page background color.
  final Color? backgroundColor;

  /// Optional drawer shown from the leading edge.
  final Widget? drawer;

  /// Optional drawer shown from the trailing edge.
  final Widget? endDrawer;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color background = backgroundColor ?? theme.backgroundColor;
    // Built on a real [Scaffold] so `ScaffoldMessenger`-based overlays
    // (e.g. SnackBar shown through [showOhosSnackBar]) have a host to
    // present in, and drawers are wired up.
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Column(
                children: <Widget>[
                  if (appBar != null) appBar!,
                  Expanded(child: body ?? const SizedBox.shrink()),
                  if (bottomNavigationBar != null) bottomNavigationBar!,
                ],
              ),
            ),
            if (floatingActionButton != null)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: floatingActionButton,
                ),
              ),
          ],
        ),
      ),
      drawer: drawer,
      endDrawer: endDrawer,
    );
  }
}
