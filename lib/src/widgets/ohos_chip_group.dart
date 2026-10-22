import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// Size of an [OhosChipGroup] item (ChipItemStyle.Size).
enum OhosChipGroupSize {
  /// Normal size (默认尺寸规格): 32vp tall capsule.
  normal,

  /// Small size (小尺寸规格): 24vp tall capsule.
  small,
}

/// A single selectable chip in an [OhosChipGroup].
@immutable
class OhosChipItem {
  const OhosChipItem({required this.label, this.icon});

  /// The chip label, usually a short [Text].
  final Widget label;

  /// Optional leading icon, typically an [Icon].
  final Widget? icon;
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
    this.selectedIndex,
    this.onSelected,
    this.multiple = false,
    this.selectedIndexes,
    this.onSelectionChanged,
    this.size = OhosChipGroupSize.normal,
    this.spacing = OhosGeometry.spaceXs,
    this.scrollable = false,
    this.activeColor,
    this.backgroundColor,
  });

  /// The chips to display.
  final List<OhosChipItem> items;

  /// Active index in single-select mode.
  final int? selectedIndex;

  /// Called with the tapped index in single-select mode.
  final ValueChanged<int>? onSelected;

  /// When true the group allows multiple selection.
  final bool multiple;

  /// Active indexes in multiple-select mode.
  final Set<int>? selectedIndexes;

  /// Called with the updated selection in multiple-select mode.
  final ValueChanged<Set<int>>? onSelectionChanged;

  /// Item size: normal (32vp) or small (24vp).
  final OhosChipGroupSize size;

  /// Horizontal gap between chips. The official guideline warns against
  /// oversized gaps, so the default is a compact 8vp.
  final double spacing;

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

  double get _height => size == OhosChipGroupSize.normal ? 32 : 24;

  @override
  Widget build(BuildContext context) {
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
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _item(BuildContext context, int index) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool selected = multiple
        ? selectedIndexes?.contains(index) ?? false
        : selectedIndex == index;
    final Color fill = selected
        ? (activeColor ?? theme.highlightColor)
        : (backgroundColor ?? theme.compBackgroundGrayColor ?? theme.cardColor);
    final Color fg = selected
        ? theme.onHighlightColor
        : theme.textSecondaryColor;
    return GestureDetector(
      onTap: () {
        if (multiple) {
          final Set<int> next = Set<int>.of(selectedIndexes ?? <int>{});
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
        height: _height,
        constraints: const BoxConstraints(minWidth: 48),
        padding: EdgeInsets.symmetric(
          horizontal: size == OhosChipGroupSize.normal ? 16 : 12,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(_height / 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (items[index].icon != null) ...<Widget>[
              IconTheme.merge(
                data: IconThemeData(
                  color: fg,
                  size: size == OhosChipGroupSize.normal ? 16 : 14,
                ),
                child: items[index].icon!,
              ),
              SizedBox(width: size == OhosChipGroupSize.normal ? 4 : 2),
            ],
            DefaultTextStyle.merge(
              style: theme.typography.labelSmall?.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: items[index].label,
            ),
          ],
        ),
      ),
    );
  }
}
