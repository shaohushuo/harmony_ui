import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_icon_button.dart';
import 'ohos_light_material.dart';

/// 标题栏动态模糊 style, mirroring `ScrollEffectType`.
enum OhosAppBarScrollEffectType {
  /// No scroll-dependent effect.
  none,

  /// 通用模糊 (COMMON_BLUR): a uniform blur backplate and a hairline fade in
  /// as content scrolls under the bar.
  commonBlur,

  /// 过渡模糊 (TRANSITION_BLUR): the bar's background / content linearly
  /// transitions from `originalStyle` to `scrollEffectStyle`.
  transitionBlur,

  /// 渐变模糊 (GRADIENT_BLUR): blur strength ramps and the backplate fades in
  /// with a soft gradient edge.
  gradientBlur,
}

/// Scroll range (vp) over which the dynamic blur reaches full strength, plus
/// the scrolled style, mirroring `scrollEffectOpts` +
/// `originalStyle/scrollEffectStyle`.
class OhosAppBarScrollEffectOptions {
  const OhosAppBarScrollEffectOptions({
    this.effect = OhosAppBarScrollEffectType.none,
    this.blurEffectiveStartOffset = 0,
    this.blurEffectiveEndOffset = 20,
    this.blurSigma = 10,
  });

  /// Dynamic blur style.
  final OhosAppBarScrollEffectType effect;

  /// Scroll offset at which the effect starts.
  final double blurEffectiveStartOffset;

  /// Scroll offset at which the effect reaches full strength.
  final double blurEffectiveEndOffset;

  /// Maximum blur sigma.
  final double blurSigma;
}

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
    this.scrollEffect,
    this.scrollController,
    this.scrolledBackgroundColor,
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

  /// Optional scroll-driven dynamic blur (动态模糊) configuration.
  final OhosAppBarScrollEffectOptions? scrollEffect;

  /// Listens to the content scroll extent for [scrollEffect].
  final ScrollController? scrollController;

  /// Background color once the scroll effect is fully active
  /// (`scrollEffectStyle.backgroundStyle.backgroundColor`).
  final Color? scrolledBackgroundColor;

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
    final Color baseColor = lightMaterial
        ? Colors.transparent
        : backgroundColor ?? theme.backgroundColor;
    final Widget surface = Material(
      color: baseColor,
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
    Widget result = lightMaterial
        ? OhosLightMaterial(
            level: lightLevel,
            gradientFade: OhosLightFade.top,
            gradientExtent: 24,
            child: surface,
          )
        : surface;
    final OhosAppBarScrollEffectOptions? effect = scrollEffect;
    final ScrollController? scroller = scrollController;
    if (effect != null &&
        scroller != null &&
        effect.effect != OhosAppBarScrollEffectType.none) {
      result = _ScrollEffectBar(
        effect: effect,
        controller: scroller,
        baseColor: baseColor,
        scrolledColor: scrolledBackgroundColor,
        child: result,
      );
    }
    return result;
  }
}


/// Applies the scroll-driven dynamic blur (动态模糊) to an [OhosAppBar].
class _ScrollEffectBar extends StatelessWidget {
  const _ScrollEffectBar({
    required this.effect,
    required this.controller,
    required this.baseColor,
    required this.scrolledColor,
    required this.child,
  });

  final OhosAppBarScrollEffectOptions effect;
  final ScrollController controller;
  final Color baseColor;
  final Color? scrolledColor;
  final Widget child;

  double get _progress {
    final double offset = controller.hasClients ? controller.offset : 0;
    final double span =
        (effect.blurEffectiveEndOffset - effect.blurEffectiveStartOffset)
            .clamp(0.1, 1e9);
    return ((offset - effect.blurEffectiveStartOffset) / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _progress;
        if (t <= 0) {
          return child!;
        }
        switch (effect.effect) {
          case OhosAppBarScrollEffectType.none:
            return child!;
          case OhosAppBarScrollEffectType.transitionBlur:
            final OhosThemeData theme = OhosTheme.of(context);
            final Color target = scrolledColor ?? Colors.white;
            final Color color = Color.lerp(baseColor, target, t)!;
            return Material(
              color: color,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: child!),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Opacity(
                      opacity: t,
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: theme.dividerColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          case OhosAppBarScrollEffectType.commonBlur:
          case OhosAppBarScrollEffectType.gradientBlur:
            final double eased = effect.effect ==
                    OhosAppBarScrollEffectType.gradientBlur
                ? Curves.easeOut.transform(t)
                : t;
            final double sigma = effect.blurSigma * eased;
            return ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: sigma,
                      sigmaY: sigma,
                    ),
                    child: const SizedBox.expand(),
                  ),
                  child!,
                  // Frosted tint over the blurred backdrop.
                  ColoredBox(
                    color: Colors.white.withValues(
                      alpha: 0.20 + 0.30 * eased,
                    ),
                  ),
                ],
              ),
            );
        }
      },
      child: child,
    );
  }
}
