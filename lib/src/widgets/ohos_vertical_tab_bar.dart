import 'package:flutter/material.dart';

import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_press_feedback.dart';

/// 纵向页签栏里的一项。
///
/// 一个 item 有两种呈现，由 [label] 是否为空决定：
///
/// * 带 [label]：标准的「图标 + 文字」纵向项，对应 `BottomTabBarStyle`；
/// * [label] 为空：渲染成**出血图标**（bleed icon）—— 纯图标、48x48 圆形、
///   没有文字，对应官方 `bleedIconStyle`。常用于运营位 / 自定义图标。
class OhosVerticalTabItem {
  const OhosVerticalTabItem({
    required this.icon,
    this.activeIcon,
    this.label,
    this.badge,
    this.enabled = true,
  });

  /// 未选中态图标。
  final Widget icon;

  /// 选中态图标；为空回落到 [icon]。
  final Widget? activeIcon;

  /// 文字标签。留空（null 或空串）= 出血图标项。
  final String? label;

  /// 可选角标，叠在图标右上角。
  final Widget? badge;

  /// 是否可点。
  final bool enabled;

  /// 是否为出血图标项（无文字）。
  bool get isBleed => label == null || label!.isEmpty;
}

/// 纵向页签栏 —— 对应官方 `HdsTabs` 的 `vertical(true)` 侧边导航。
///
/// 平板 / 横屏场景下，页签栏从底部挪到**左侧纵向排列**（官方 `vertical` 属性，
/// 纵向 `barWidth` 默认 96vp），与内容区靠右侧 1px 分割线分界。本组件同时
/// 承载两种官方增强样式：
///
/// * **出血图标**：[OhosVerticalTabItem.label] 留空的项，渲染成 48x48 圆形纯
///   图标，对应 `bleedIconStyle`；
/// * **半屏居中**：[halfScreenFixed] = true，对应 `barMode(HALF_SCREEN_FIXED)` ——
///   页签栏整体在垂直方向居中，总高度为容器高度的 1/4，各页签在其中均分。
///
/// 它不是 [OhosNavigationBar] 转个方向：底部那套是横向、平铺/悬浮，而纵向栏
/// 有独立的默认宽度（96vp）、独立的半屏居中规则，所以单独成组件。
class OhosVerticalTabBar extends StatelessWidget {
  const OhosVerticalTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.width = 96,
    this.halfScreenFixed = false,
    this.backgroundColor,
  });

  /// 页签项。
  final List<OhosVerticalTabItem> items;

  /// 当前选中索引。
  final int selectedIndex;

  /// 选中回调。
  final ValueChanged<int> onSelected;

  /// 栏宽（官方纵向 `barWidth` 默认 96vp）。
  final double width;

  /// 是否半屏居中布局（官方 `HALF_SCREEN_FIXED`）。
  final bool halfScreenFixed;

  /// 背景色，默认卡片色。
  final Color? backgroundColor;

  /// 标准 / 出血项的固定高度（非半屏居中时）。
  ///
  /// 自拟：官方只给纵向栏宽 96vp，没给单项高度。图标 24 + 文字 11 + 间距，
  /// 取 64vp 与底部平铺 48vp 拉开纵向呼吸。
  static const double itemHeight = 64;

  /// 出血图标的圆形尺寸（官方示例 48x48、圆角 24）。
  static const double bleedSize = 48;

  /// 半屏居中时每一项允许被压到的最小高度。
  ///
  /// **自拟，而且这个保底是必要的。** 官方原文是「所有页签总高度之和为
  /// HdsTabs 组件高度的四分之一，且处在二分之一屏的居中位置」—— 只给总高
  /// 比例，没给单项下限。按比例硬算会撞上一个物理事实：320vp 高的容器里
  /// 1/4 是 80vp，5 个页签各分 16vp，而单项内容是 `图标 24 + 间距 4 + 文字
  /// 13`，怎么塞都溢出（实测渲染图满是 `RenderFlex overflowed` 条纹）。
  ///
  /// 所以取 `max(容器高/4, 项数 × 本值)`：页签少时严格遵守官方比例，页签多
  /// 到比例算不下时以「读得出来」为先，仍然是垂直居中。取 56vp 是因为它
  /// 正好等于官方悬浮式页签的栏高，单项在这个高度下面图标与文字都不局促。
  static const double minHalfScreenItemHeight = 56;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool threeQuarter = halfScreenFixed;

    Widget panel() {
      // 半屏居中：外层已把 `listHeight` 算好（含保底），栏内用 `Expanded`
      // 均分。早先用固定 `SizedBox(height: listHeight / items.length)`，各项
      // 之和恒等于 `listHeight`，而 `SafeArea` 会按状态栏 / 导航条把可用高度
      // 向内缩 —— 孩子总高没变、可用高度变小，`RenderFlex` 当场溢出（溢出量
      // 正好是上下 inset 之和）。`Expanded` 分的是「扣掉安全区之后」的高度，
      // 安全区只压缩每项、不产生溢出。保底仍由外层 `listHeight` 负责，所以
      // 「5 项各 16vp 装不下图标」那个老问题不会回来。
      //
      // 默认形态：每项固定 64vp，但 `Column` 用 `MainAxisSize.max` 铺满父级
      // 高度 —— 栏底色与右侧 1px 分割线要一直画到栏底，不能只到最后一项就断。
      // 早先统一写成 `min`，默认形态下整块栏体只有 `项数 × 64` 高，放在 800vp
      // 的 `Row` 里时下半屏成了无背景无分界的裸区。
      final List<Widget> children = <Widget>[
        for (int i = 0; i < items.length; i++)
          if (threeQuarter)
            Expanded(child: _item(context, theme, i))
          else
            SizedBox(height: itemHeight, child: _item(context, theme, i)),
      ];
      return DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? theme.cardColor,
          // 纵向栏固定在左侧，右侧 1px 分割线与内容分界；墨水屏用实色。
          border: Border(
            right: theme.usesOutlines
                ? ohosBorderSide(
                    context,
                    theme.dividerColor,
                    width: theme.outlineWidth,
                  )
                : BorderSide.none,
          ),
        ),
        child: SizedBox(
          width: width,
          // 左侧栏：左边不做安全区，避免与屏幕左缘凭空多出竖缝。
          child: SafeArea(
            left: false,
            child: Column(
              mainAxisSize: threeQuarter ? MainAxisSize.min : MainAxisSize.max,
              children: children,
            ),
          ),
        ),
      );
    }

    if (!halfScreenFixed) {
      return SizedBox(width: width, child: panel());
    }

    // 半屏居中：页签组整体垂直居中，总高度 = 容器高度的 1/4（带保底）。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double fullHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        // 1/4 是官方比例，`items.length × 56` 是「塞得下」的下限，取较大者，
        // 再不超过容器本身。
        //
        // **不能用 `num.clamp`。** 它在「下限 > 上限」时直接抛 `ArgumentError`
        // （源码 `if (lowerLimit.compareTo(upperLimit) > 0) throw ...`），不是
        // 「两值取大」。容器比 `项数 × 56` 还矮时（6 项放进 320vp：336 > 320，
        // 或 LayoutBuilder 某一帧 `maxHeight` 为 0）下限就大于上限，`build`
        // 期间当场红屏。手写上下界，边界条件再极端也只是把栏压到容器高。
        final double quarter = fullHeight / 4;
        final double floor = items.length * minHalfScreenItemHeight;
        final double wanted = quarter > floor ? quarter : floor;
        final double listHeight = wanted < fullHeight ? wanted : fullHeight;
        return SizedBox(
          width: width,
          height: fullHeight,
          child: Align(
            // 官方：处在二分之一屏的居中位置 —— 居中，不是贴顶。
            alignment: Alignment.centerLeft,
            child: SizedBox(height: listHeight, child: panel()),
          ),
        );
      },
    );
  }

  Widget _item(BuildContext context, OhosThemeData theme, int index) {
    final OhosVerticalTabItem item = items[index];
    final bool selected = index == selectedIndex;
    return OhosPressFeedback(
      onTap: item.enabled ? () => onSelected(index) : null,
      child: item.isBleed
          ? _bleedContent(theme, item, selected)
          : _standardContent(theme, item, selected),
    );
  }

  /// 出血图标：48x48 圆形纯图标，选中态铺一层品牌高亮底。
  Widget _bleedContent(
    OhosThemeData theme,
    OhosVerticalTabItem item,
    bool selected,
  ) {
    final Color active = theme.highlightColor;
    final Color idle = theme.textSecondaryColor;
    return Center(
      child: Container(
        width: bleedSize,
        height: bleedSize,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? (theme.emphasizeSecondaryColor ?? active.withValues(alpha: 0.2))
              : Colors.transparent,
        ),
        child: IconTheme.merge(
          data: IconThemeData(
            color: selected ? active : idle,
            size: 26,
            opacity: item.enabled ? 1 : 0.4,
          ),
          child: selected ? (item.activeIcon ?? item.icon) : item.icon,
        ),
      ),
    );
  }

  /// 标准项：图标在上、文字在下，纵向居中。
  Widget _standardContent(
    OhosThemeData theme,
    OhosVerticalTabItem item,
    bool selected,
  ) {
    final Color active = theme.highlightColor;
    final Color idle = theme.textSecondaryColor;
    final Widget icon = IconTheme.merge(
      data: IconThemeData(
        color: selected ? active : idle,
        size: 24,
        opacity: item.enabled ? 1 : 0.4,
      ),
      child: selected ? (item.activeIcon ?? item.icon) : item.icon,
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            icon,
            if (item.badge != null)
              Positioned(top: -6, right: -8, child: item.badge!),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            item.label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (theme.typography.labelSmall ?? const TextStyle(fontSize: 11))
                    .copyWith(
                      color: selected ? active : idle,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
          ),
        ),
      ],
    );
  }
}
