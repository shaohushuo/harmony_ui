import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_press_feedback.dart';

/// A sub (second-level) item of an [OhosSideMenuItem].
class OhosSideMenuSubItem {
  const OhosSideMenuSubItem({
    required this.label,
    this.value,
    this.badgeCount,
    this.enabled = true,
  });

  /// Display label.
  final String label;

  /// Value reported on selection; defaults to [label].
  final String? value;

  /// Optional new-message count badge.
  final int? badgeCount;

  /// When false the item cannot be selected.
  final bool enabled;
}

/// A main (first-level) item of an [OhosSideMenu].
class OhosSideMenuItem {
  const OhosSideMenuItem({
    required this.label,
    this.icon,
    this.value,
    this.badgeCount,
    this.subItems = const <OhosSideMenuSubItem>[],
    this.enabled = true,
  });

  /// Display label of the main item.
  final String label;

  /// Optional leading icon.
  final Widget? icon;

  /// Value reported on selection; defaults to [label].
  final String? value;

  /// Optional new-message count badge on the main item.
  final int? badgeCount;

  /// Optional second-level items; when non-empty the row expands.
  final List<OhosSideMenuSubItem> subItems;

  /// When false the item cannot be selected.
  final bool enabled;
}

/// A HarmonyOS side menu (侧边栏菜单), the counterpart of `HdsSideMenu`.
///
/// 视觉规格**全部有出处**，不是按 Material 抽屉调出来的：
///
/// | 项 | 值 | 出处 |
/// | --- | --- | --- |
/// | 行高 | 48vp | `pattern.sidebar_sidemenu_menuitem_height` |
/// | 选中块圆角 | 16vp | `pattern.sidebar_sidemenu_menuitem_radius` |
/// | 文字 | 16fp | `pattern.sidebar_sidemenu_menuitem_text_font_size` |
/// | 药丸左右内缩 | 16vp | `pattern.sidebar_sidemenu_menuitem_padding_level8` |
/// | 选中底色 | `sidebar_board_actived_color` | 同上表 |
/// | 未选中图标 / 文字 | `icon_secondary` / `font_secondary` | 同上表 |
///
/// 四条与 Material 抽屉的实质区别（本轮重做）：
///
/// 1. **选中块是内缩的圆角药丸，不是通栏直角块。** 行本身撑满面板宽度承担
///    点击热区，选中底色只画在内缩后的 16vp 圆角块上。通栏直角块会让面板左
///    边缘出现一条与面板等高的色带 —— 这正是「看着像 Material」的主因。
/// 2. **图标与文字都读次要色**，选中行只换背板 + 升到主色 + 加一档字重，
///    **不是品牌色高亮**。官方截图里选中项的字仍然是黑的。
/// 3. **没有展开箭头。** 二级菜单的展开由组件内部状态驱动，行尾只允许放
///    计数（右对齐）。`chevron_right` 是 Material `ExpansionTile` 的惯例，
///    官方 `HdsSideMenu` 没有这个元素。
/// 4. **没有二级项的小圆点。** 二级项靠缩进区分层级，不加装饰性圆点。
///
/// ```dart
/// OhosSideMenu(
///   items: items,
///   selectedValue: '收件箱',
///   onSelected: (v) => setState(() => _selected = v),
/// )
/// ```
class OhosSideMenu extends StatefulWidget {
  const OhosSideMenu({
    super.key,
    required this.items,
    this.selectedValue,
    this.onSelected,
    this.padding = const EdgeInsets.symmetric(
      vertical: OhosGeometry.spaceXs,
      horizontal: OhosSideMenu.itemInset,
    ),
  });

  /// Menu items.
  final List<OhosSideMenuItem> items;

  /// Currently selected value (main or sub item).
  final String? selectedValue;

  /// Called when a selectable item is tapped.
  final ValueChanged<String>? onSelected;

  /// Padding around the list.
  ///
  /// 水平部分就是选中块的**左右内缩**：药丸不可能比列表内容区更宽，把它放在
  /// 这里而不是每行各写一遍，才能保证一级 / 二级项的药丸左右边缘是同一条线。
  final EdgeInsetsGeometry padding;

  /// 一级项行高。**官方**：48vp（`pattern.sidebar_sidemenu_menuitem_height`
  /// → `float_sys.tabs_sidebar_sidemenu_menuitem_container_height`）。
  static const double itemHeight = 48;

  /// 选中块圆角。**官方**：16vp（`pattern.sidebar_sidemenu_menuitem_radius`
  /// → `float.corner_radius_level8`）。
  static const double itemRadius = 16;

  /// 一级项字号。**官方**：16fp（`pattern.sidebar_sidemenu_menuitem_text_font_size`）。
  static const double itemFontSize = 16;

  /// 药丸左右内缩。**官方**：16vp（`pattern.sidebar_sidemenu_menuitem_padding_level8`）。
  static const double itemInset = 16;

  @override
  State<OhosSideMenu> createState() => _OhosSideMenuState();
}

class _OhosSideMenuState extends State<OhosSideMenu> {
  final Set<String> _expanded = <String>{};

  bool _isExpanded(OhosSideMenuItem item) {
    return _expanded.contains(item.value ?? item.label);
  }

  void _toggle(OhosSideMenuItem item) {
    setState(() {
      final String key = item.value ?? item.label;
      if (!_expanded.remove(key)) {
        _expanded.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // 墨屏把时长归零（`scaleMotion`），灰阶屏上没有中间色阶可看，展开过程
    // 只会变成一片闪烁的灰块。
    final Duration motion = theme.policy.scaleMotion(
      OhosGeometry.durationShort,
    );
    return ListView(
      padding: widget.padding,
      children: <Widget>[
        for (final OhosSideMenuItem item in widget.items)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _mainItem(context, theme, item),
              // 展开 / 折叠必须有过渡，否则二级项是「啪」地跳出来的：一级项
              // 下方的兄弟会在同一帧整体位移，肉眼看到的是内容瞬移。用
              // `AnimatedSize` 让高度连续变化，`clipBehavior` 默认 `hardEdge`
              // 把动画中途溢出的子项裁掉，不会压到下一行。
              AnimatedSize(
                duration: motion,
                curve: OhosGeometry.easeOut,
                alignment: Alignment.topCenter,
                child: _isExpanded(item)
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (final OhosSideMenuSubItem sub in item.subItems)
                            _subItem(context, theme, sub),
                        ],
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ],
          ),
      ],
    );
  }

  /// 一行的骨架：外层撑满宽度承担热区，内层是内缩后的圆角药丸。
  ///
  /// 这两层必须分开。把圆角与内缩写在同一个 [Container] 上、靠 `margin`
  /// 收窄，热区会跟着缩进药丸里，48vp 行只剩中间那一小段可点；反过来把圆角
  /// 写在外层、只给 `padding`，背板又会一直画到面板左边缘。
  Widget _row({
    required OhosThemeData theme,
    required bool selected,
    required double indent,
    required Widget child,
    required VoidCallback? onTap,
  }) {
    // 选中背板：彩屏是 20% 品牌色；墨屏下这个 alpha 会被 `policy.tint` 判成
    // 透明（16 级灰里 ≤20% 的黑与白底不可分），此时改画 1px 实色描边 ——
    // 与 `OhosListItem` 的选中态同一约定，否则灰阶屏上选中与未选中完全一样。
    //
    // **三个条件缺一不可，早先漏了 `!selected`。** `emphasizeSecondaryColor`
    // 本身就是 20% alpha 的品牌色（不是「强调色的不透明版本」），少了这一判
    // 会把同一种背板铺到每一行上 —— 渲染出来是整列全亮，反而看不出选的是谁。
    // 墨屏则必须绕过它：那里的 `emphasizeSecondaryColor` 是**实色**，铺上去
    // 与同样读 `textPrimaryColor` 的文字同色，黑底黑字直接消失。
    final Color tinted = theme.policy.tint(theme.highlightColor, 0.12);
    final bool useOutline = tinted.a == 0;
    final Color fill = !selected || useOutline
        ? Colors.transparent
        : (theme.emphasizeSecondaryColor ?? tinted);
    // 墨屏选中：实底走不通（见上），靠描边 + 主色文字表达，与列表项同约定。
    final Color contentColor = selected
        ? theme.textPrimaryColor
        : theme.textSecondaryColor;

    return OhosPressFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OhosSideMenu.itemRadius),
      child: SizedBox(
        height: OhosSideMenu.itemHeight,
        child: Padding(
          // 纵向不留白：48vp 行就应该是 48vp 的触控带。左右由列表 `padding`
          // 统一内缩，二级项在此基础上再加 [indent]。
          padding: EdgeInsets.only(left: indent),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(OhosSideMenu.itemRadius),
              border: useOutline && selected
                  ? Border.fromBorderSide(
                      ohosBorderSide(
                        context,
                        theme.dividerColor,
                        width: theme.outlineWidth,
                      ),
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: IconTheme.merge(
                data: IconThemeData(color: contentColor),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: contentColor),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mainItem(
    BuildContext context,
    OhosThemeData theme,
    OhosSideMenuItem item,
  ) {
    final bool selected = widget.selectedValue == (item.value ?? item.label);
    final bool hasChildren = item.subItems.isNotEmpty;
    return _row(
      theme: theme,
      selected: selected,
      indent: 0,
      onTap: item.enabled
          ? () {
              if (hasChildren) {
                _toggle(item);
              }
              widget.onSelected?.call(item.value ?? item.label);
            }
          : null,
      child: Row(
        children: <Widget>[
          if (item.icon != null) ...<Widget>[
            IconTheme.merge(
              // 颜色由 `_row` 的 `IconTheme.merge` 统一给（官方
              // `icon_primary` / `icon_secondary`），这里只定尺寸。
              data: const IconThemeData(size: 24),
              child: item.icon!,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: OhosSideMenu.itemFontSize,
                // 选中加一档字重：官方截图里选中项笔画略粗。只换颜色的话，
                // 16fp 主色与次要色的差别要贴得很近才看得出来。
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          // 行尾只放计数，**不放展开箭头** —— 官方没有这个元素。
          if (item.badgeCount != null) _badge(theme, item.badgeCount!),
        ],
      ),
    );
  }

  Widget _subItem(
    BuildContext context,
    OhosThemeData theme,
    OhosSideMenuSubItem sub,
  ) {
    final bool selected = widget.selectedValue == (sub.value ?? sub.label);
    return _row(
      theme: theme,
      selected: selected,
      // 二级项缩进 = 父项图标层宽度（24 图标 + 8 间距）。这样二级项文字
      // 正好落在父项文字的左边界上，读起来是一棵层级树而不是两列。
      indent: 32,
      onTap: sub.enabled
          ? () => widget.onSelected?.call(sub.value ?? sub.label)
          : null,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              sub.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (sub.badgeCount != null) _badge(theme, sub.badgeCount!),
        ],
      ),
    );
  }

  /// 行尾计数。**官方** `HdsSideMenuBadgeParam.count`：0 不显示、1 显示「·」、
  /// >99 显示「99+」，形态是排在行尾的**纯文本**。
  ///
  /// 画成红底白字的小药丸（`OhosBadge` 那种）是 Material 角标，官方侧边菜单
  /// 里它只是串次要色数字。
  Widget _badge(OhosThemeData theme, int count) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }
    return Text(
      count > 99 ? '99+' : '$count',
      maxLines: 1,
      style: TextStyle(
        fontSize: 14,
        color: theme.textTertiaryColor,
        fontFeatures: const <FontFeature>[
          // 等宽数字：多个项的计数列才对得齐。
          FontFeature.tabularFigures(),
        ],
      ),
    );
  }
}
