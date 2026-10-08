import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// A HarmonyOS sidebar container (侧边栏), the counterpart of `HdsSideBar`.
///
/// Mirrors the ArkUI `SideBarContainerType.Overlay` floating style: the
/// [sideBar] panel floats above the [content] area, an optional mask dims the
/// content, and the panel can auto-hide when tapping outside.
///
/// ```dart
/// OhosSideBar(
///   isShowSideBar: _show,
///   onIsShowSideBarChanged: (v) => setState(() => _show = v),
///   sideBar: OhosSideMenu(items: items),
///   content: const ScaffoldBody(),
/// )
/// ```
class OhosSideBar extends StatelessWidget {
  const OhosSideBar({
    super.key,
    required this.sideBar,
    required this.content,
    this.isShowSideBar = true,
    this.onIsShowSideBarChanged,
    this.overlay = true,
    this.contentAreaMask = true,
    this.autoHide = true,
    this.width = 280,
    this.backgroundColor,
    this.elevation = 12,
  });

  /// The sidebar panel, typically an [OhosSideMenu].
  final Widget sideBar;

  /// The main content area.
  final Widget content;

  /// Whether the sidebar is currently visible (controlled).
  final bool isShowSideBar;

  /// Called with the new visibility when the user dismisses the sidebar
  /// (mask tap when [autoHide]).
  final ValueChanged<bool>? onIsShowSideBarChanged;

  /// Overlay (floating) mode; the panel floats above the content with a
  /// rounded trailing edge. When false the panel pushes the content.
  final bool overlay;

  /// Whether tapping the visible content area is blocked by a dim mask.
  final bool contentAreaMask;

  /// When true, tapping the mask hides the sidebar.
  final bool autoHide;

  /// Logical width of the sidebar panel.
  final double width;

  /// Panel background; defaults to the theme card color.
  final Color? backgroundColor;

  /// Shadow elevation of the floating panel.
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Widget panel = Material(
      color: backgroundColor ?? theme.cardColor,
      elevation: overlay ? elevation : 0,
      clipBehavior: overlay ? Clip.antiAlias : Clip.none,
      shape: overlay
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.horizontal(
                right: Radius.circular(OhosGeometry.radiusLarge),
              ),
            )
          : null,
      child: SizedBox(
        width: width,
        child: SafeArea(right: false, child: sideBar),
      ),
    );
    final Widget positionedPanel = overlay
        ? AnimatedPositioned(
            duration: OhosGeometry.durationMedium,
            curve: OhosGeometry.easeOut,
            left: isShowSideBar ? 0 : -width - 24,
            top: 0,
            bottom: 0,
            child: panel,
          )
        : AnimatedPositioned(
            duration: OhosGeometry.durationMedium,
            curve: OhosGeometry.easeOut,
            left: isShowSideBar ? 0 : -width,
            top: 0,
            bottom: 0,
            child: panel,
          );
    return Stack(
      children: <Widget>[
        Positioned.fill(child: content),
        if (overlay && contentAreaMask)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !isShowSideBar,
              child: AnimatedOpacity(
                duration: OhosGeometry.durationMedium,
                curve: OhosGeometry.easeOut,
                opacity: isShowSideBar ? 0.35 : 0,
                child: GestureDetector(
                  onTap: autoHide
                      ? () => onIsShowSideBarChanged?.call(false)
                      : null,
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
        positionedPanel,
      ],
    );
  }
}
