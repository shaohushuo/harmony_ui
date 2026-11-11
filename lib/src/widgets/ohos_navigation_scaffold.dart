import 'package:flutter/material.dart';

import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_light_material.dart';
import 'ohos_press_feedback.dart';

/// 标题栏显示模式 —— 对应官方 `HdsNavigationTitleMode` 里的两种固定形态。
enum OhosNavTitleMode {
  /// 小标题（官方 `MINI`）：标题栏固定 56vp，标题居中。
  mini,

  /// 大标题（官方 `FULL`）：仅主标题时栏高 112vp，带副标题时 138vp，
  /// 标题在底部左对齐。
  full,
}

/// 底部工具栏的一项 —— 对应官方 `ToolbarItem`。
class OhosNavToolbarItem {
  const OhosNavToolbarItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
  });

  /// 工具栏图标。
  final Widget icon;

  /// 图标下方文字。
  final String label;

  /// 点击回调。
  final VoidCallback? onTap;

  /// 是否可点。
  final bool enabled;
}

/// 组件导航的根视图容器 —— 对应官方 `HdsNavigation`。
///
/// 官方 `HdsNavigation` 是路由导航的根容器，内部默认包含**标题栏、内容区、
/// 工具栏**，并默认支持标题栏随内容滚动的动态模糊。它的路由栈（`NavPathStack`）
/// 在 Flutter 里由框架自身的 [Navigator] / 路由体系承担，本组件不重复实现一套
/// 路由，而是提供 `HdsNavigation` 的**视觉外壳与布局骨架**：
///
/// * 标题栏：[titleMode] 切换小标题（MINI 56vp）/ 大标题（FULL 112/138vp），
///   含返回图标、标题（可带副标题）、菜单 [actions] 与背景板；
/// * 内容区：[child]，占满标题栏与工具栏之间的空间；
/// * 工具栏：[toolbarItems] 非空时在底部均分图标 + 文字，最多 5 项。
///
/// 标题栏背景板默认实色 + 底部 1px 分割线；[blurredBackground] 开启后改用
/// 沉浸光感材质（对应官方默认的动态模糊背板）。
///
/// 官方的 `HdsNavDestination`（路由栈 push 出来的子页面根容器）结构同样是
/// 「标题栏 + 内容 + 工具栏」，因此本组件也可直接作为子页面骨架使用，无需另造
/// 一个组件——根容器与子页面容器的差别在路由位置，而不在布局。
class OhosNavigationScaffold extends StatelessWidget {
  const OhosNavigationScaffold({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.toolbarItems,
    this.titleMode = OhosNavTitleMode.mini,
    this.automaticallyImplyLeading = true,
    this.blurredBackground = false,
    this.backgroundColor,
  });

  /// 内容区。
  final Widget child;

  /// 主标题。
  final String? title;

  /// 副标题（仅大标题模式 [OhosNavTitleMode.full] 展示）。
  final String? subtitle;

  /// 标题栏左侧自定义控件；为空且 [automaticallyImplyLeading] 为 true 时
  /// 自动放返回键。
  final Widget? leading;

  /// 标题栏右侧菜单区。
  final List<Widget>? actions;

  /// 底部工具栏项；为空或 null 时不显示工具栏。
  final List<OhosNavToolbarItem>? toolbarItems;

  /// 标题栏模式。
  final OhosNavTitleMode titleMode;

  /// 是否在能返回时自动显示返回键。
  final bool automaticallyImplyLeading;

  /// 标题栏是否使用动态模糊背景板。
  final bool blurredBackground;

  /// 标题栏 / 工具栏背景色，默认卡片色。
  final Color? backgroundColor;

  /// 官方小标题栏高度（MINI）。
  static const double miniHeight = 56;

  /// 官方大标题栏高度（FULL，仅主标题）。
  static const double fullHeight = 112;

  /// 官方大标题栏高度（FULL，主 + 副标题）。
  static const double fullWithSubtitleHeight = 138;

  /// 工具栏高度。
  static const double toolbarHeight = 56;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color background = backgroundColor ?? theme.cardColor;
    return Column(
      children: <Widget>[
        _titleBar(context, theme, background),
        Expanded(child: child),
        if (toolbarItems != null && toolbarItems!.isNotEmpty)
          _toolbar(context, theme, background),
      ],
    );
  }

  Widget _titleBar(
    BuildContext context,
    OhosThemeData theme,
    Color background,
  ) {
    final Widget content = titleMode == OhosNavTitleMode.full
        ? _fullTitleBar(context, theme)
        : _miniTitleBar(context, theme);

    // 背景板：动态模糊材质 or 实色 + 底部 1px 分割线。
    Widget result;
    if (blurredBackground) {
      result = OhosLightMaterial(
        level: OhosLightMaterialLevel.ultraThin,
        showShadow: false,
        gradientFade: OhosLightFade.top,
        child: content,
      );
    } else {
      result = DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          border: Border(
            bottom: theme.usesOutlines
                ? ohosBorderSide(
                    context,
                    theme.dividerColor,
                    width: theme.outlineWidth,
                  )
                : BorderSide.none,
          ),
        ),
        child: content,
      );
    }
    // 标题栏内容避开状态栏，背景仍铺到最顶端。
    return SafeArea(bottom: false, child: result);
  }

  /// 小标题栏：返回键（左）、居中标题、菜单（右）。
  Widget _miniTitleBar(BuildContext context, OhosThemeData theme) {
    return SizedBox(
      height: miniHeight,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 4,
            top: 8,
            bottom: 8,
            child: leading ?? _defaultLeading(context, theme),
          ),
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: Text(
                  title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (theme.typography.titleMedium ??
                              const TextStyle(fontSize: 17))
                          .copyWith(color: theme.textPrimaryColor),
                ),
              ),
            ),
          ),
          if (actions != null)
            Positioned(
              right: 8,
              top: 8,
              bottom: 8,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions!),
            ),
        ],
      ),
    );
  }

  /// 大标题栏：顶部一行返回键 + 菜单，底部左对齐主标题（+ 副标题）。
  Widget _fullTitleBar(BuildContext context, OhosThemeData theme) {
    final double height = subtitle != null
        ? fullWithSubtitleHeight
        : fullHeight;
    return SizedBox(
      height: height,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: miniHeight,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 4,
                  top: 8,
                  bottom: 8,
                  child: leading ?? _defaultLeading(context, theme),
                ),
                if (actions != null)
                  Positioned(
                    right: 8,
                    top: 8,
                    bottom: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions!,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (theme.typography.headlineMedium ??
                                const TextStyle(fontSize: 28))
                            .copyWith(
                              color: theme.textPrimaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (theme.typography.bodyMedium ??
                                  const TextStyle(fontSize: 14))
                              .copyWith(color: theme.textSecondaryColor),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 默认返回键：圆形按压、无 Material 水波纹。
  Widget _defaultLeading(BuildContext context, OhosThemeData theme) {
    if (!automaticallyImplyLeading) {
      return const SizedBox.shrink();
    }
    final bool canPop = Navigator.of(context).canPop();
    if (!canPop) {
      return const SizedBox.shrink();
    }
    return OhosPressFeedback(
      onTap: () => Navigator.maybePop(context),
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          Icons.arrow_back_rounded,
          size: 22,
          color: theme.textPrimaryColor,
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context, OhosThemeData theme, Color background) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: theme.usesOutlines
              ? ohosBorderSide(
                  context,
                  theme.dividerColor,
                  width: theme.outlineWidth,
                )
              : BorderSide.none,
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: toolbarHeight,
          child: Row(
            children: <Widget>[
              for (final OhosNavToolbarItem item in toolbarItems!)
                Expanded(child: _toolbarItem(theme, item)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbarItem(OhosThemeData theme, OhosNavToolbarItem item) {
    final Color color = item.enabled
        ? theme.textPrimaryColor
        : theme.textTertiaryColor;
    return OhosPressFeedback(
      onTap: item.enabled ? item.onTap : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconTheme.merge(
            data: IconThemeData(color: color, size: 22),
            child: item.icon,
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (theme.typography.labelSmall ?? const TextStyle(fontSize: 11))
                      .copyWith(color: color, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
