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
/// 面板是**直角矩形**：官方 Overlay / Embed 两型都不圆角、不带 Material 海拔
/// 阴影。浮层需要分层时用一层很轻的自绘投影，墨水屏（`usesOutlines`）下连
/// 投影也不画，改走 1px 实线。
///
/// 几何默认值来自官方 API 参考（`HdsSideBar` 参数表）：
///
/// | 参数 | 默认值 | 官方参数 |
/// | --- | --- | --- |
/// | 面板宽 | 240vp | `sideBarWidth` |
/// | 最小宽 | 200vp | `minSideBarWidth` |
/// | 最大宽 | 280vp | `maxSideBarWidth` |
/// | 内容区最小宽 | 360vp | `minContentWidth` |
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
    this.width = 240,
    this.backgroundColor,
    this.elevation = 12,
    this.duration,
    this.curve = OhosGeometry.easeOut,
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

  /// Logical width of the sidebar panel. **官方**默认 240vp。
  final double width;

  /// Panel background; defaults to the theme card color.
  final Color? backgroundColor;

  /// Strength of the **self-drawn** floating projection in overlay mode.
  ///
  /// This is NOT a Material elevation: it only seeds a soft [BoxShadow] and is
  /// ignored under the ink (e-ink) visual policy, where a 1px outline replaces
  /// it. Set 0 to disable the projection entirely.
  final double elevation;

  /// 展开 / 收起动效时长。为空时走 [OhosGeometry.durationMedium]，并经
  /// `policy.scaleMotion` 缩放（墨屏归零 —— 长动画在真机上等于卡顿）。
  ///
  /// **官方未给数值**：`HdsSideBar` 文档只说「可显示和隐藏」，没有时长参数。
  /// 这里取主题的中档动效，与 `OhosFloatingTabBar` 的栏出现动效同源。
  final Duration? duration;

  /// 展开 / 收起动效曲线。
  final Curve curve;

  /// 面板宽度的官方默认值（vp）。
  static const double defaultWidth = 240;

  /// 面板宽度下限（官方 `minSideBarWidth` = 200vp）。
  static const double minWidth = 200;

  /// 面板宽度上限（官方 `maxSideBarWidth` = 280vp）。
  static const double maxWidth = 280;

  /// 内容区最小宽度（官方 `minContentWidth` = 360vp）。
  static const double minContentWidth = 360;

  /// 直角面板：纯色背景 + 右侧 1px 分割线（embed 分界 / overlay 描边），
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
    final Duration motion = theme.policy.scaleMotion(
      duration ?? OhosGeometry.durationMedium,
    );

    // Embed：面板与内容并排，面板宽度在 0 / width 之间动画，内容区被推挤。
    if (!overlay) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AnimatedContainer(
            duration: motion,
            curve: curve,
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
                duration: motion,
                curve: curve,
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
          duration: motion,
          curve: curve,
          left: isShowSideBar ? 0 : -width - 24,
          top: 0,
          bottom: 0,
          child: panel,
        ),
      ],
    );
  }
}
