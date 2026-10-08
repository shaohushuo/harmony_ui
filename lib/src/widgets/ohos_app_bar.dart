import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_icon_button.dart';
import 'ohos_light_material.dart';

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
    this.lightMaterial = false,
    this.lightLevel = OhosLightMaterialLevel.ultraThin,
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

  /// Whether the bar uses the immersive light material
  /// (ULTRA_THIN + top gradient fade) instead of an opaque background.
  final bool lightMaterial;

  /// Immersive-light level when [lightMaterial] is true.
  final OhosLightMaterialLevel lightLevel;

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
    final Widget surface = Material(
      color: lightMaterial
          ? Colors.transparent
          : backgroundColor ?? theme.backgroundColor,
      elevation: elevation,
      child: SizedBox(
        height: preferredSize.height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // The title is always centered in the full bar width, regardless
            // of whether a leading/back button or actions are present.
            DefaultTextStyle.merge(
              style:
                  theme.typography.titleMedium ?? const TextStyle(fontSize: 17),
              textAlign: TextAlign.center,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: title ?? const SizedBox.shrink(),
                ),
              ),
            ),
            if (leadingWidget != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: leadingWidget,
                ),
              ),
            if (actions != null && actions!.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final Widget action in actions!) action,
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (!lightMaterial) {
      return surface;
    }
    return OhosLightMaterial(
      level: lightLevel,
      gradientFade: OhosLightFade.top,
      gradientExtent: 24,
      child: surface,
    );
  }
}
