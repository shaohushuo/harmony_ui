import 'package:flutter/material.dart';

import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_menu.dart';
import 'ohos_press_feedback.dart';

/// 工具栏子项的状态，对应 ArkUI 的 `ItemState`。
///
/// 三个值**不是**「开 / 关 / 选中」这组互斥开关，而是两组独立维度：能不能点
/// （[enabled]），以及「允不允许成为当前项」（[activated]）。所以不存在「既禁用
/// 又激活」的组合 —— ArkUI 里 `state` 是单值枚举。混着理解会写出
/// `enabled && activated` 这种永远为假的判断。
enum OhosToolbarItemState {
  /// `ItemState.ENABLE` = 1：正常可点击。
  enabled,

  /// `ItemState.DISABLE` = 2：不可点击。
  disabled,

  /// `ItemState.ACTIVATE` = 3：可点击，且**允许**成为激活项。
  ///
  /// 注意「允许」二字：它本身不等于「已激活」。真正的激活态还要求
  /// [OhosToolbar.activeIndex] 指向这一项 —— 见该字段的文档。
  activated,
}

/// Item model of an [OhosToolbar].
class OhosToolbarItem {
  const OhosToolbarItem({
    required this.icon,
    required this.label,
    this.onPressed,
    this.state = OhosToolbarItemState.enabled,
  });

  /// Icon of the item.
  final IconData icon;

  /// Label of the item.
  final String label;

  /// Called when the item is tapped; ignored while [state] is
  /// [OhosToolbarItemState.disabled].
  final VoidCallback? onPressed;

  /// Current state of the item — ArkUI's `ToolBarOption.state`.
  ///
  /// Replaces the old `selected` flag, which conflated two things: whether the
  /// item *may* be active (opt-in per item in ArkUI) and whether it *is* active
  /// right now (decided by `activeIndex`). The old shape let a caller mark a
  /// disabled item as selected and get a blue-but-dead tile.
  final OhosToolbarItemState state;

  /// Whether the item can be tapped.
  bool get enabled => state != OhosToolbarItemState.disabled;
}

/// A bottom toolbar of icon + label items — the HarmonyOS 工具栏.
///
/// Geometry comes from ArkUI's own constants in `toolbar.ets`:
///
/// | token / constant                | value | note                            |
/// | ------------------------------- | ----- | ------------------------------- |
/// | `DEFAULT_TOOLBAR_HEIGHT`        | 56    | **excludes** the 1vp divider    |
/// | `IMAGE_SIZE`                    | 24    | icon                            |
/// | `padding_level1`                | 2     | gap under the icon              |
/// | `ohos_id_text_size_caption1`    | 10    | label, weight 500               |
/// | `padding_level12`               | 24    | side padding, only when <5 items |
/// | `ohos_id_corner_radius_clicked` | 8     | hit-box radius                  |
///
/// The label is **10fp**, not the 12fp of Material's caption scale. It looks
/// startlingly small next to a 72-tall bar — but this bar is 56.
///
/// More than 5 items collapse: the first 4 stay inline and the 5th slot becomes
/// "更多" (`TOOLBAR_MAX_LENGTH = 5` / `moreIndex = 4`). The overflow list opens
/// as an [showOhosMenu] anchored at that slot.
class OhosToolbar extends StatelessWidget {
  const OhosToolbar({
    super.key,
    required this.items,
    this.activeIndex = -1,
    this.backgroundColor,
    this.moreLabel = '更多',
    this.moreIcon,
    this.onMorePressed,
  });

  /// Toolbar items, in display order.
  final List<OhosToolbarItem> items;

  /// Index of the currently active item — ArkUI's `activateIndex`.
  ///
  /// Only takes effect together with [OhosToolbarItemState.activated] on that
  /// item: `getIconColor()` in `toolbar.ets` reads
  /// `activateIndex == index && state == ACTIVATE`. Pointing at an
  /// `ENABLE`-state item highlights **nothing** — official behaviour, and easy
  /// to mistake for a bug, so pass `ACTIVATE` for anything that can become the
  /// current one.
  ///
  /// `-1` (the default) means "nothing active"; values below -1 are treated the
  /// same way, matching the documented "若设置数值小于-1，按没有激活项处理".
  final int activeIndex;

  /// Bar background; defaults to the theme card color
  /// (`ohos_id_color_toolbar_bg`).
  final Color? backgroundColor;

  /// Label of the overflow slot.
  ///
  /// ArkUI reads it from `sys.string.ohos_toolbar_more`, which the system
  /// localises; a widget library has no system locale channel, so it is a
  /// parameter here.
  final String moreLabel;

  /// Icon of the overflow slot; defaults to a 2×2 dot grid.
  ///
  /// ArkUI hard-codes `sys.symbol.dot_grid_2x2`; a widget library cannot reach
  /// the system symbol set, so a plain [IconData] is used and left open here.
  /// `OhosIcons.dot_grid_2x2` matches the official glyph exactly if you have
  /// that package.
  final IconData? moreIcon;

  /// Called when the overflow slot is tapped.
  ///
  /// Defaults to opening a menu listing the overflowing items. Provide your own
  /// to replace that menu entirely (e.g. with a custom sheet).
  final void Function(BuildContext context)? onMorePressed;

  /// Items that fit inline before the overflow slot takes over.
  ///
  /// `moreIndex = 4` in `toolbar.ets`: with 5 items everything fits; with 6 the
  /// last 2 move into "更多" and 4 stay inline.
  static const int _maxInline = 5;
  static const int _moreIndex = 4;

  /// Official bar height, **not** including the 1vp divider.
  static const double _height = 56;
  static const double _iconSize = 24;
  static const double _iconLabelGap = 2;
  static const double _labelSize = 10;
  static const double _sidePadding = 24;
  static const double _radius = 8;

  /// Whether [items] overflows into the "更多" slot.
  bool get _overflowing => items.length > _maxInline;

  /// Items rendered inline. With overflow this is the first 4.
  List<OhosToolbarItem> get _inlineItems =>
      _overflowing ? items.sublist(0, _moreIndex) : items;

  /// Items hidden behind "更多".
  List<OhosToolbarItem> get _overflowItems =>
      _overflowing ? items.sublist(_moreIndex) : const <OhosToolbarItem>[];

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // ArkUI 的条件是 `toolBarList.length < 5`，**不是** `<= 5`：正好 5 个时
    // 内边距已经是 0，靠均分把 5 项铺满。写成 `<=` 会让 5 项那档突然缩进
    // 24，而 6 项收纳后也是 5 格 —— 两档对不齐。
    final bool padded = items.length < _maxInline;

    return Material(
      color: backgroundColor ?? theme.cardColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 分割线不在 56 之内（官方写明「此高度不包含分割线高度」），所以
          // 整条栏是 1 + 56 = 57。线宽走 ohosStrokeWidth，保证整数设备像素。
          Container(
            height: ohosStrokeWidth(context, 1),
            color: theme.dividerColor,
          ),
          SizedBox(
            height: _height,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: padded ? _sidePadding : 0,
              ),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < _inlineItems.length; i++)
                    Expanded(
                      child: _ToolbarTile(
                        item: _inlineItems[i],
                        active:
                            i == activeIndex &&
                            _inlineItems[i].state ==
                                OhosToolbarItemState.activated,
                      ),
                    ),
                  if (_overflowing)
                    Expanded(
                      child: _MoreTile(
                        label: moreLabel,
                        icon: moreIcon,
                        onPressed: () => _openOverflow(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openOverflow(BuildContext context) {
    if (onMorePressed != null) {
      onMorePressed!(context);
      return;
    }
    showOhosMenu<int>(
      context: context,
      anchor: context,
      items: <OhosMenuItem<int>>[
        for (int i = 0; i < _overflowItems.length; i++)
          OhosMenuItem<int>(
            label: _overflowItems[i].label,
            // `value` 用**原始下标**而不是收纳后的序号：调用方拿到它就能直接
            // 对自己的 `items` 取值，不必再补 `_moreIndex`。
            value: i + _moreIndex,
            icon: _overflowItems[i].icon,
            enabled: _overflowItems[i].enabled,
          ),
      ],
    ).then((int? index) {
      if (index == null) {
        return;
      }
      _overflowItems[index - _moreIndex].onPressed?.call();
    });
  }
}

/// One icon + label cell.
class _ToolbarTile extends StatelessWidget {
  const _ToolbarTile({required this.item, required this.active});

  final OhosToolbarItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = item.enabled;
    // 「我在这一项上」怎么表达由策略回答，不在这里判 monochrome ——
    // 墨水屏上 highlightColor 与 textPrimaryColor 都是纯黑，换色等于没换。
    final OhosSelectionMark mark = theme.policy.selectionMark;
    final bool inverse = active && mark == OhosSelectionMark.inverse;
    // 官方：icon_primary / icon_emphasize、font_primary / font_emphasize。
    // 常态**不是** textSecondary —— 工具栏是主导航而非辅助信息，用次级色会
    // 让整条栏显得发灰、在一堆浅色底上读不出来。
    final Color fg = !enabled
        ? theme.textTertiaryColor
        : inverse
        ? theme.onHighlightColor
        : (active ? theme.highlightColor : theme.textPrimaryColor);

    return Semantics(
      button: true,
      enabled: enabled,
      selected: active,
      label: item.label,
      child: OhosPressFeedback(
        onTap: enabled ? item.onPressed : null,
        borderRadius: BorderRadius.circular(OhosToolbar._radius),
        // 反白要自己给实底；tint / emphasis 用透明，页面底色透上来。
        pressedColor: inverse ? Colors.white.withValues(alpha: 0.16) : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: inverse ? theme.highlightColor : Colors.transparent,
            borderRadius: BorderRadius.circular(OhosToolbar._radius),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconTheme.merge(
                data: IconThemeData(size: OhosToolbar._iconSize, color: fg),
                child: Icon(item.icon),
              ),
              const SizedBox(height: OhosToolbar._iconLabelGap),
              DefaultTextStyle.merge(
                style:
                    (theme.typography.labelSmall ??
                            const TextStyle(fontSize: OhosToolbar._labelSize))
                        .copyWith(
                          fontSize: OhosToolbar._labelSize,
                          // 官方 `FontWeight.Medium`。`emphasis` 策略才靠加粗
                          // 补一条线索，其余情形字形不变。
                          fontWeight:
                              active && mark == OhosSelectionMark.emphasis
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: fg,
                        ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "更多" cell — same geometry, a 2×2 dot grid instead of an item icon.
class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // 官方是 `sys.symbol.dot_grid_2x2`；拿不到系统图标集时退到最接近的点阵 —
    // 这里借 `Icons.more_horiz` 的邻居 `Icons.grid_view_rounded`（四格）。
    // 调用方可用 [OhosToolbar.moreIcon] 传入 `OhosIcons.dot_grid_2x2` 对齐官方。
    return Semantics(
      button: true,
      label: label,
      child: OhosPressFeedback(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(OhosToolbar._radius),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconTheme.merge(
              data: IconThemeData(
                size: OhosToolbar._iconSize,
                color: theme.textPrimaryColor,
              ),
              child: Icon(icon ?? Icons.grid_view_rounded),
            ),
            const SizedBox(height: OhosToolbar._iconLabelGap),
            DefaultTextStyle.merge(
              style:
                  (theme.typography.labelSmall ??
                          const TextStyle(fontSize: OhosToolbar._labelSize))
                      .copyWith(
                        fontSize: OhosToolbar._labelSize,
                        fontWeight: FontWeight.w500,
                        color: theme.textPrimaryColor,
                      ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
