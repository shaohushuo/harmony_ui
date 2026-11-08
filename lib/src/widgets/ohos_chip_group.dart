import 'package:flutter/material.dart';

import '../theme/ohos_chip_metrics.dart';
import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';

/// Size of an [OhosChipGroup] item (`ChipSize`).
///
/// Alias of [OhosChipSize] so that a chip looks the same whether you drop it in
/// a group or use it standalone — the two used to carry separate copies of the
/// same enum and drifted to 32/24 tall instead of the official 36/28.
typedef OhosChipGroupSize = OhosChipSize;

/// A single selectable chip in an [OhosChipGroup].
@immutable
class OhosChipItem {
  const OhosChipItem({
    required this.label,
    this.icon,
    this.selectedIcon,
    this.suffixIcon,
    this.allowClose = false,
    this.onClose,
  });

  /// The chip label, usually a short [Text].
  final Widget label;

  /// Optional leading icon, typically an [Icon].
  final Widget? icon;

  /// Leading icon used while this item is selected.
  ///
  /// Matches ArkUI's `prefixSymbol.normal` / `prefixSymbol.activated` pair —
  /// the two states are different glyphs, not one glyph recoloured. Null falls
  /// back to [icon] (see [OhosChip.selectedIcon] for why the strict ArkUI
  /// behaviour of *hiding* the icon is not copied).
  final Widget? selectedIcon;

  /// Optional trailing icon, e.g. a dropdown arrow.
  ///
  /// Suppresses [allowClose], matching ArkUI's `suffixSymbol` /
  /// `suffixImageIcon` precedence (`chipgroup.ets:578`).
  final Widget? suffixIcon;

  /// Whether the built-in close (×) button is shown for this chip.
  ///
  /// Defaults to `false`, which *is* the ArkUI default here —
  /// `chipgroup.ets:580` passes `chipItem.allowClose ?? false`. (A standalone
  /// ArkUI `Chip` defaults the other way; see [OhosChip.allowClose].)
  final bool allowClose;

  /// Called after the close button is tapped.
  ///
  /// Removing the item is the caller's job — see [OhosChip.onClose].
  final VoidCallback? onClose;
}

/// The HarmonyOS capsule-style sub-tab group (子页签 - 胶囊样式,
/// ArkUI `ChipGroup`).
///
/// The active chip gets a brand-color fill (`comp_background_emphasize`) with
/// white content, idle chips use the component gray background
/// (`comp_background_gray`) — exactly as in the official spec. Supports the
/// single-select and multiple-select ([multiple]) modes and two sizes.
///
/// ```dart
/// OhosChipGroup(
///   items: const <OhosChipItem>[
///     OhosChipItem(label: Text('推荐')),
///     OhosChipItem(label: Text('关注')),
///   ],
///   selectedIndex: 0,
///   onSelected: (int i) => setState(() => _index = i),
/// )
/// ```
class OhosChipGroup extends StatelessWidget {
  const OhosChipGroup({
    super.key,
    required this.items,
    this.selectedIndex = 0,
    this.onSelected,
    this.multiple = false,
    this.selectedIndexes,
    this.onSelectionChanged,
    this.size = OhosChipGroupSize.normal,
    this.spacing = OhosGeometry.spaceXs,
    this.startSpace = 16,
    this.endSpace = 16,
    this.padding = const EdgeInsets.symmetric(vertical: 14),
    this.scrollable = false,
    this.activeColor,
    this.backgroundColor,
  });

  /// The chips to display.
  final List<OhosChipItem> items;

  /// Active index in single-select mode.
  ///
  /// Defaults to `0` — the first chip is selected when you pass nothing.
  /// ArkUI's `ChipGroup` declares `selectedIndexes: Array<number> = [0]` and
  /// `aboutToAppear` re-applies `[0]` whenever the resolved set is empty
  /// (`chipgroup.ets:332` / `:356`), so a freshly built group is never in an
  /// all-idle state. Pass `-1` (or an out-of-range index) for "nothing
  /// selected"; every value that does not name an existing chip is ignored,
  /// matching `getSelectedIndexes()`'s filter.
  final int? selectedIndex;

  /// Called with the tapped index in single-select mode.
  final ValueChanged<int>? onSelected;

  /// When true the group allows multiple selection.
  final bool multiple;

  /// Active indexes in multiple-select mode.
  ///
  /// Defaults to `{0}` for the same reason as [selectedIndex] — one shared
  /// `selectedIndexes` array backs both modes in ArkUI, so `multiple` does not
  /// turn the default off. This is a **behaviour change** from 0.5.x, where an
  /// unset selection left every chip idle; pass `const <int>{}` for that.
  final Set<int>? selectedIndexes;

  /// Called with the updated selection in multiple-select mode.
  final ValueChanged<Set<int>>? onSelectionChanged;

  /// Item size: normal (36vp) or small (28lpx).
  final OhosChipGroupSize size;

  /// Horizontal gap between chips. The official guideline warns against
  /// oversized gaps, so the default is a compact 8vp.
  ///
  /// The counterpart of `chipGroupSpace.itemSpace` (default 8) — that is the
  /// *middle* segment only; the two edge segments are [startSpace] and
  /// [endSpace].
  final double spacing;

  /// Leading inset before the first chip (`chipGroupSpace.startSpace`, 16).
  ///
  /// ArkUI applies it as `padding({ left: … })` on the scrolling row, so the
  /// first chip never touches the screen edge — without it a strip that is
  /// scrolled to the start looks like it is bleeding out of its container.
  final double startSpace;

  /// Trailing inset after the last chip (`chipGroupSpace.endSpace`, 16).
  ///
  /// Same token family as [startSpace]; it uses `end` rather than `right` so a
  /// RTL strip gets the mirror image for free.
  final double endSpace;

  /// Vertical padding around the strip (`chipGroupPadding`, 14 / 14).
  ///
  /// Horizontal values are ignored: the horizontal geometry is fully owned by
  /// [startSpace] / [endSpace], and letting both apply is how the group ends up
  /// with a 30vp inset on the leading edge. Pass
  /// `EdgeInsets.symmetric(vertical: 0)` for a flush strip.
  final EdgeInsetsGeometry padding;

  /// Whether the strip is *always* horizontally scrollable.
  ///
  /// `false` (default) means "don't add a scroll view when the chips fit";
  /// a strip wider than its parent **still** scrolls horizontally instead of
  /// overflowing (0.3.0 changed this: previously it produced a `RenderFlex`
  /// overflow). Note that a non-scrolling strip that is cut off gives no visual
  /// affordance — on a narrow screen the trailing chips need a swipe to reach.
  /// If you want wrapping instead, build a `Wrap` of [OhosChip]s yourself.
  final bool scrollable;

  /// Overrides the active (brand) fill color.
  final Color? activeColor;

  /// Overrides the idle chip background color.
  final Color? backgroundColor;

  /// Resolved chip geometry for [size].
  ///
  /// Read from [OhosChipMetrics] rather than recomputed here: the numbers are
  /// ArkUI's `chip_*` token values (36/28 tall, 18/14 radius, 16/6 padding and
  /// icon gap, 14fp label), and keeping a second copy is how this widget ended
  /// up 4vp short of [OhosChip] in both size classes.
  OhosChipMetrics get _metrics => OhosChipMetrics.of(size);

  @override
  Widget build(BuildContext context) {
    final Widget strip = _scrollableStrip(context);
    // `chipGroupPadding` 只取纵向：`chipgroup.ets:639` 把它加在 Stack 上，
    // 而那层的横向已经有 start/end 两段。整组高度因此是 36 + 14 + 14 = 64。
    //
    // 注意别写成 `EdgeInsets.symmetric(vertical: padding.vertical)` ——
    // `padding.vertical` 本身已经是**上下之和**，再塞进 vertical 就翻倍
    // （36 + 28 + 28 = 92）。这里直接把原 padding 的上下两值搬过来。
    final EdgeInsets resolved = padding.resolve(Directionality.of(context));
    return resolved.top == 0 && resolved.bottom == 0
        ? strip
        : Padding(
            padding: EdgeInsets.only(
              top: resolved.top,
              bottom: resolved.bottom,
            ),
            child: strip,
          );
  }

  Widget _scrollableStrip(BuildContext context) {
    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _strip(context),
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 被放进 Row / 无界宽度里时保持原来的自然宽度（滚动视图拿不到无界宽度）
        if (!constraints.hasBoundedWidth) {
          return _strip(context);
        }
        // 不滚动模式原来直接把 Row 塞进约束里，窄屏放不下就出斑马线。
        // 这里仍然整行展示，但超出部分改为横向滚动，内容窄时保持原来的左对齐。
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Align(
              alignment: Alignment.centerLeft,
              // 只按子尺寸占高。没有这两个 factor 时，`Align` 在松高度约束下
              // 会一路撑到 `constraints.maxHeight` —— 一排芯片躺在页面里就变成
              // 占满整屏 600 高的空白块，把下面的内容全顶走。
              widthFactor: 1,
              heightFactor: 1,
              child: _strip(context),
            ),
          ),
        );
      },
    );
  }

  Widget _strip(BuildContext context) {
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(SizedBox(width: spacing));
      }
      children.add(_item(context, i));
    }
    // 三段间距按 ArkUI 的三段给：`chipGroupSpace` 是 `{itemSpace, startSpace,
    // endSpace}`，中间那段由 Row 的 gap 表达，两端由这里的内边距表达。
    // 只用纵向 padding 是因为横向已被 start/end 占满 —— 若同时给横向，
    // 首端会变成 16 + 16（`chipgroup.ets:615` 的 padding 只有 left/right 两个方向，
    // 上下另由 `chipGroupPadding` 负责）。
    return Padding(
      padding: EdgeInsets.only(left: startSpace, right: endSpace),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  /// Resolved multi-select set — mirrors ArkUI's `getSelectedIndexes()`
  /// (`chipgroup.ets:455`): null becomes `{0}`, and out-of-range or negative
  /// indexes are dropped rather than silently selecting nothing.
  Set<int> get _resolvedIndexes {
    final Set<int> raw = selectedIndexes ?? const <int>{0};
    return raw
        .where((int i) => i >= 0 && i < items.length)
        .toSet();
  }

  /// True when [index] is selected, honouring `multiple` and the fallback
  /// defaults documented on [selectedIndex] / [selectedIndexes].
  bool _isSelected(int index) {
    if (multiple) {
      return _resolvedIndexes.contains(index);
    }
    final int? single = selectedIndex;
    return single != null && single == index;
  }

  Widget _item(BuildContext context, int index) {
    final OhosThemeData theme = OhosTheme.of(context);
    final OhosVisualPolicy policy = theme.policy;
    final OhosChipMetrics metrics = _metrics;
    final bool selected = _isSelected(index);
    final Color fill = selected
        ? (activeColor ?? theme.highlightColor)
        : (backgroundColor ?? theme.compBackgroundGrayColor ?? theme.cardColor);
    final Color fg = selected
        ? theme.onHighlightColor
        : theme.textSecondaryColor;
    // 未选中态原先只有填充、没有描边。彩屏上填充自己够得着（灰底压白页），
    // 但墨水屏的 compBackgroundGrayColor 就是纸色 —— 芯片与页面同色、又没有线，
    // 一排里只有选中那颗有形状，其余散成纯文字，读者分不出哪个能点。
    // 描边取色与 OhosChip 保持一致：选中用品牌色，未选中用提示色。
    final Color borderColor = selected
        ? policy.line(theme.highlightColor, 0.20)
        : policy.line(theme.textTertiaryColor, 0.3);
    // 双态前图标，回落规则与 OhosChip 共用一条：选中态优先 selectedIcon，
    // 缺省沿用 icon（ArkUI 只给 normal 时会让选中态整个失去图标，照搬就是缺陷）。
    final Widget? leading = selected
        ? (items[index].selectedIcon ?? items[index].icon)
        : items[index].icon;
    return GestureDetector(
      onTap: () {
        if (multiple) {
          final Set<int> next = Set<int>.of(_resolvedIndexes);
          if (!next.add(index)) {
            next.remove(index);
          }
          onSelectionChanged?.call(next);
        } else {
          onSelected?.call(index);
        }
      },
      child: AnimatedContainer(
        duration: OhosGeometry.durationShort,
        curve: OhosGeometry.spring,
        height: metrics.height,
        constraints: const BoxConstraints(minWidth: 48),
        padding: EdgeInsets.symmetric(horizontal: metrics.horizontalPadding),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          // 官方给的是显式圆角（18 / 14），不是 `height / 2`。两档当前恰好
          // 等于折半值，但那是巧合 —— 胶囊观感是结果，不是来源。
          borderRadius: BorderRadius.circular(metrics.radius),
          border: Border.fromBorderSide(
            ohosBorderSide(context, borderColor),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              IconTheme.merge(
                data: IconThemeData(color: fg, size: metrics.iconSize),
                child: leading,
              ),
              SizedBox(width: metrics.iconGap),
            ],
            DefaultTextStyle.merge(
              style:
                  (theme.typography.labelSmall ??
                          TextStyle(fontSize: metrics.fontSize))
                      .copyWith(
                        color: fg,
                        fontSize: metrics.fontSize,
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
              child: items[index].label,
            ),
            if (items[index].suffixIcon != null) ...<Widget>[
              SizedBox(width: metrics.iconGap),
              IconTheme.merge(
                data: IconThemeData(color: fg, size: metrics.iconSize),
                child: items[index].suffixIcon!,
              ),
            ] else if (items[index].allowClose) ...<Widget>[
              SizedBox(width: metrics.iconGap),
              // 与 OhosChip 同一条约束：ArkUI 的关闭按钮 padding(0)，
              // 命中区等于图标本身（16），没有可查的 hot_zone 令牌。
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: items[index].onClose,
                child: IconTheme.merge(
                  data: IconThemeData(color: fg, size: metrics.iconSize),
                  child: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
