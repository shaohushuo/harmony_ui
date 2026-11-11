import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';

/// A HarmonyOS sidebar container (侧边栏), the counterpart of `HdsSideBar` /
/// ArkUI `SideBarContainer`.
///
/// Two layouts, matching the official `SideBarContainerType`:
///
/// * [overlay] = true → **Overlay**：面板浮在内容区上方，不影响内容区尺寸，
///   可带一层遮罩，点遮罩可收起。
/// * [overlay] = false → **Embed**：面板与内容区**并排**，展开时推挤内容区，
///   整体容器宽度不变、内容区缩小，靠右侧 1px 分割线分界。
///
/// 与 Material `Drawer` 的关键区别（本轮重做）：面板是**直角矩形**，没有
/// `Material` 的圆角尾缘，也没有 Material 海拔阴影 —— 官方 HdsSideBar 无论
/// Overlay 还是 Embed 都不圆角。浮层需要分层时，用一层很轻的自绘投影，
/// 墨水屏（`usesOutlines`）下连投影也不画，改走 1px 实线。
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

  /// Overlay (floating) mode; the panel floats above the content. When false
  /// the panel is embedded beside the content and pushes it.
  final bool overlay;

  /// Whether tapping the visible content area is blocked by a dim mask.
  final bool contentAreaMask;

  /// When true, tapping the mask hides the sidebar.
  final bool autoHide;

  /// Logical width of the sidebar panel.
  final double width;

  /// Panel background; defaults to the theme card color.
  final Color? backgroundColor;

  /// Strength of the **self-drawn** floating projection in overlay mode.
  ///
  /// This is NOT a Material elevation: it only seeds a soft [BoxShadow] and is
  /// ignored under the ink (e-ink) visual policy, where a 1px outline replaces
  /// it. Set 0 to disable the projection entirely.
  final double elevation;

  /// The直角面板：纯色背景 + 右侧 1px 分割线（embed 分界 / overlay 描边），
  /// 浮层模式再补一层很轻的自绘投影。不使用 [Material]、不画圆角。
  Widget _buildPanel(BuildContext context, OhosThemeData theme) {
    final Widget body = ColoredBox(
      color: backgroundColor ?? theme.cardColor,
      child: SizedBox(
        width: width,
        // 左侧面板：右侧不做安全区，避免与内容分界处凭空多出一条竖缝。
        child: SafeArea(right: false, child: sideBar),
      ),
    );

    final BorderSide rightSide = theme.usesOutlines
        ? ohosBorderSide(context, theme.dividerColor, width: theme.outlineWidth)
        : BorderSide.none;

    // 浮层且非墨水屏：用一层很轻的自绘投影表达「浮在内容上」，替代 Material
    // 海拔阴影。官方 Overlay 主要靠遮罩分层，所以投影刻意压得很淡。
    final List<BoxShadow>? shadow =
        (overlay && !theme.usesOutlines && elevation > 0)
        ? <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: elevation,
              offset: const Offset(2, 0),
            ),
          ]
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(right: rightSide),
        boxShadow: shadow,
      ),
      child: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Widget panel = _buildPanel(context, theme);

    // Embed：面板与内容并排，面板宽度在 0 / width 之间动画，内容区被推挤。
    if (!overlay) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AnimatedContainer(
            duration: OhosGeometry.durationMedium,
            curve: OhosGeometry.easeOut,
            width: isShowSideBar ? width : 0,
            // 宽度收窄到 0 时裁掉面板内容，避免内部固定宽度溢出。
            clipBehavior: Clip.hardEdge,
            child: panel,
          ),
          Expanded(child: content),
        ],
      );
    }

    // Overlay：内容在底，遮罩 + 面板浮在上面滑入滑出。
    return Stack(
      children: <Widget>[
        Positioned.fill(child: content),
        if (contentAreaMask)
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
        AnimatedPositioned(
          duration: OhosGeometry.durationMedium,
          curve: OhosGeometry.easeOut,
          left: isShowSideBar ? 0 : -width - 24,
          top: 0,
          bottom: 0,
          child: panel,
        ),
      ],
    );
  }
}
