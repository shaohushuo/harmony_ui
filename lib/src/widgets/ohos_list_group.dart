import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_divider.dart';
import 'ohos_light_material.dart';
import 'ohos_list_tile.dart';

/// 分组的容器样式，对应 ArkUI 的 `ListItemGroupStyle`。
enum OhosListGroupStyle {
  /// 无样式：分组只是把若干行排在一起，不加底板、不加外边距。
  none,

  /// 卡片样式：左右外边距 12vp、四周内边距 4vp、圆角 24vp 的底板。
  ///
  /// 官方建议与行级的 [OhosListGroupItemStyle.card] 同时使用 —— 底板负责
  /// 「这是一组」，行级样式负责「行与行的边界」。
  card,
}

/// 分组内每一行的样式，对应 ArkUI 的 `ListItemStyle`。
///
/// **这是行级样式，不是分组样式**：官方 `ListItem({ style })` 与
/// `ListItemGroup({ style })` 是两个独立参数，可以自由组合（官方示例 2 第一组
/// 是 `Group.CARD + Item.CARD`，第四组是 `Group.NONE + Item.CARD`）。
enum OhosListGroupItemStyle {
  /// 无样式。
  none,

  /// 卡片内列表项：高度 48vp、左右内边距 8vp。
  card,
}

/// 吸顶 / 吸底，对应 ArkUI 的 `StickyStyle`。
///
/// 值顺序与官方一致（`None=0` / `Header=1` / `Footer=2` / `BOTH=3`），便于对照。
enum OhosListStickyStyle {
  /// 组头不吸顶，组尾不吸底。
  none,

  /// 组头吸顶。
  header,

  /// 组尾吸底。
  footer,

  /// 组头吸顶且组尾吸底。
  both,
}

/// `OhosListGroup` 里那些「官方给了具体值」的几何常量。
///
/// 三个数分处三个来源，混着记会看不出哪个能核对：
///
/// - [cardMargin] = 12vp：资源表 `ohos_id_card_margin_start` /
///   `_end`（`list_item_pattern.item_margin_left/right` 指向它们，
///   `float.json` 里两值都是 `12.0vp`）；
/// - [cardPadding] = 4vp：**只在文档正文里**（「卡片样式下，ListItemGroup 默认
///   规格：左右外边距 12vp，上下左右内边距 4vp」），资源表里没有对应令牌；
/// - [cardRadius] = 24vp：`list_item_pattern.item_border_radius` →
///   `ohos_id_corner_radius_default_l`（`float.json` = `24.0vp`）。
///
/// 行级那一档（[cardItemHeight] / [cardItemPadding]）同样只在文档正文里：
/// 「卡片样式下，ListItem 默认规格：高度 48vp，宽度 100%，左右内边距 8vp」。
class OhosListGroupMetrics {
  const OhosListGroupMetrics._();

  /// 卡片样式的左右外边距（令牌 `ohos_id_card_margin_start/end`）。
  static const double cardMargin = 12;

  /// 卡片样式四周的内边距（文档正文，无令牌）。
  static const double cardPadding = 4;

  /// 卡片圆角（令牌 `ohos_id_corner_radius_default_l`）。
  static const double cardRadius = 24;

  /// 卡片内列表项的高度（文档正文）。
  static const double cardItemHeight = 48;

  /// 卡片内列表项的左右内边距（文档正文）。
  static const double cardItemPadding = 8;

  /// 分隔线的默认粗细。
  ///
  /// 官方 `ListDividerOptions.strokeWidth` 是**必填**（没有默认值），而分组本身
  /// 的 `divider` 默认是 `null`，即**默认没有分隔线**。所以这里取的是与
  /// [OhosDivider] 一致的 0.5 发丝线，而不是某个官方常量 —— 只属于本库的
  /// 兜底值，只在调用方显式给出 [OhosGroupDivider] 时才可能被读到。
  static const double dividerThickness = 0.5;
}

/// 分组的分隔线，对应 ArkUI 的 `ListDividerOptions`。
///
/// 与 [OhosList] 的 `divider: bool` 不同，分组的默认值是 **`null`**（官方
/// 「设置 ListItem 分割线样式，默认无分割线」）—— 传 `null` 就一条都不画。
@immutable
class OhosGroupDivider {
  const OhosGroupDivider({
    this.strokeWidth = OhosListGroupMetrics.dividerThickness,
    this.color,
    this.startMargin = 0,
    this.endMargin = 0,
  });

  /// 线宽。官方这里必填；本库默认给发丝线宽度。
  final double strokeWidth;

  /// 线色；`null` 用主题的分隔线色。
  ///
  /// 官方默认 `0x08000000`（3% 黑）。本库读 `theme.dividerColor` —— 墨水屏上
  /// 3% 黑落在 16 级灰的第 0 级、与纸面完全分不开，主题色已经是量化过的实色。
  final Color? color;

  /// 与起点端的距离。
  final double startMargin;

  /// 与结束端的距离。
  final double endMargin;

  @override
  bool operator ==(Object other) =>
      other is OhosGroupDivider &&
      other.strokeWidth == strokeWidth &&
      other.color == color &&
      other.startMargin == startMargin &&
      other.endMargin == endMargin;

  @override
  int get hashCode => Object.hash(strokeWidth, color, startMargin, endMargin);
}

/// 列表分组，对应 ArkUI 的 `ListItemGroup`。
///
/// 一个分组 = 可选组头 + 若干行 + 可选组尾。[space] 只作用于**行与行之间**，
/// 不作用于组头与首行、末行与组尾之间 —— 这是官方写明的一条，也是它和「给每行
/// 加 padding」最容易混的地方。
///
/// ## 两种形态
///
/// - [OhosListGroup] 本身是**盒子**，用在不滚动的容器里（[Column]、
///   [OhosList.children]、`SingleChildScrollView` 里都行）；
/// - [OhosListGroupSliver] 是** sliver**，用在 [CustomScrollView] 里，并且只有
///   这一形态能吸顶 / 吸底。
///
/// 为什么要分两个类：`sticky` 在 ArkUI 里是 **`List` 的属性**
/// （`List().sticky(StickyStyle.Header)`），不是 `ListItemGroup` 的。Flutter
/// 侧「吸顶」是一个 sliver 行为（`PinnedHeaderSliver`），盒子形态根本无处可吸。
/// 把 `sticky` 放在盒子组上会得到一个「传了但没反应」的开关 —— 那比不支持更坏，
/// 所以这里让它只出现在 sliver 形态上。
///
/// 粒度上的差别（有意为之）：官方的 `sticky` 一次管住列表内**所有**分组，本库
/// 是逐组声明。逐组能表达的集合严格大于整表 —— 想要官方那种整表一致的观感，
/// 把每个组的 `sticky` 传成同一个值即可。
class OhosListGroup extends StatelessWidget {
  const OhosListGroup({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.style = OhosListGroupStyle.none,
    this.itemStyle = OhosListGroupItemStyle.none,
    this.space = 0,
    this.divider,
    this.headerPadding,
    this.footerPadding,
  });

  /// 分组内的行。
  final List<Widget> children;

  /// 组头。官方允许「单个子组件或不放」。
  final Widget? header;

  /// 组尾。
  final Widget? footer;

  /// 容器样式，见 [OhosListGroupStyle]。
  final OhosListGroupStyle style;

  /// 行级样式，见 [OhosListGroupItemStyle]。
  final OhosListGroupItemStyle itemStyle;

  /// 行与行之间的间距。不作用于组头与首行、末行与组尾。
  ///
  /// 官方对非法值（负数、或大于等于内容区长度）的处理是「按默认值显示」，即
  /// 落回 0；本库同样夹到 `>= 0`。
  final double space;

  /// 行与行之间的分隔线；`null`（默认）一条都不画。
  final OhosGroupDivider? divider;

  /// 组头的内边距；`null` 用 [kOhosListGroupHeaderPadding]。
  final EdgeInsetsGeometry? headerPadding;

  /// 组尾的内边距；`null` 用 [kOhosListGroupFooterPadding]。
  final EdgeInsetsGeometry? footerPadding;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool card = style == OhosListGroupStyle.card;
    final BorderRadius radius = BorderRadius.circular(
      card ? OhosListGroupMetrics.cardRadius : 0,
    );

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (header != null)
          Padding(
            padding: headerPadding ?? kOhosListGroupHeaderPadding,
            child: header!,
          ),
        for (int i = 0; i < children.length; i++) _rowAt(i),
        if (footer != null)
          Padding(
            padding: footerPadding ?? kOhosListGroupFooterPadding,
            child: footer!,
          ),
      ],
    );

    if (!card) return body;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: OhosListGroupMetrics.cardMargin,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: radius),
        child: Padding(
          padding: const EdgeInsets.all(OhosListGroupMetrics.cardPadding),
          child: body,
        ),
      ),
    );
  }

  /// 第 [index] 行的最终形态：上间距 → 行 → 分隔线。
  ///
  /// 盒子形态与 sliver 形态共用这一个函数，避免两处各排一遍、有一处忘了
  /// 「间距不加在首行上」。
  Widget _rowAt(int index) {
    final bool cardItem = itemStyle == OhosListGroupItemStyle.card;
    Widget row = children[index];
    if (cardItem) {
      row = ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: OhosListGroupMetrics.cardItemHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OhosListGroupMetrics.cardItemPadding,
          ),
          // 行级 CARD 的垂直居中：48vp 是**最小**高度，内容更高的行照旧长高，
          // 所以这里用 min 而不是 fixed。
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            heightFactor: 1,
            child: row,
          ),
        ),
      );
    }
    // 组内分隔线归组所有：告诉行内的 tile「你自己那条不要画」。
    final Widget scoped = OhosListDividerScope(showBottom: false, child: row);
    final double gap = index == 0 ? 0 : math.max(0, space);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (gap > 0) SizedBox(height: gap),
        scoped,
        if (divider != null && index < children.length - 1)
          OhosDivider(
            thickness: divider!.strokeWidth,
            color: divider!.color,
            indent: divider!.startMargin,
            endIndent: divider!.endMargin,
          ),
      ],
    );
  }
}

/// 组头的默认内边距。
///
/// 官方没给组头内边距的令牌 —— 示例里组头自己 `padding(10)` 全包。这里给一组
/// 通栏用的 16/8：左右与列表内容边距对齐，上下留出与行之间的呼吸。调用方要
/// 官方示例那种「整块色带」的效果，传 `EdgeInsets.zero` 并在组头内部自己上色。
const EdgeInsets kOhosListGroupHeaderPadding = EdgeInsets.fromLTRB(
  16,
  12,
  16,
  8,
);

/// 组尾的默认内边距。
const EdgeInsets kOhosListGroupFooterPadding = EdgeInsets.fromLTRB(
  16,
  8,
  16,
  12,
);

/// 列表分组的 sliver 形态，用在 [CustomScrollView] 里。
///
/// 与 [OhosListGroup] 共享全部字段（通过 [group] 组合，不再复制一遍），只多出
/// 一个 [sticky]。
class OhosListGroupSliver extends StatelessWidget {
  const OhosListGroupSliver({
    super.key,
    required this.group,
    this.sticky = OhosListStickyStyle.none,
  });

  /// 要渲染成分组内容的盒子形态分组。
  final OhosListGroup group;

  /// 组头吸顶 / 组尾吸底，见 [OhosListStickyStyle]。
  ///
  /// **当前只落地了「组头吸顶」。** `footer` / `both` 这两个值传进来时组尾仍然
  /// 在自然位置，不会吸底 —— 传了不生效，所以不要靠它做「底部悬浮汇总条」。
  ///
  /// 为什么不做：Flutter 只有钉在**起点**的 [PinnedHeaderSliver]，没有反向版本，
  /// 得自己写一个。第一版写出来了，用的是 `remainingPaintExtent` 推「视口末端
  /// 距本 sliver 多远」，实测这个值在 `SliverMainAxisGroup` 内部已经被同组前面的
  /// 子 sliver 扣掉过，且滑出视口时被夹到 0 —— 于是「组尾原来在视口下方多少」
  /// 这条关键信息在需要它的那一刻恰好丢失，吸底链会算成「原地不动」。换别的
  /// 近似量（`precedingScrollExtent` 与视口滚动量之差）能得到正确方向，但那个
  /// 差值在分组内部拿不到视口自己的滚动量，仍是猜的。宁可留一个 `○`，也不留一个
  /// 「多数情况下看着对、滚到某些位置就错位」的实现 —— 那比没有更难查。
  final OhosListStickyStyle sticky;

  bool get _stickyHeader =>
      sticky == OhosListStickyStyle.header ||
      sticky == OhosListStickyStyle.both;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool card = group.style == OhosListGroupStyle.card;
    final BorderRadius radius = BorderRadius.circular(
      card ? OhosListGroupMetrics.cardRadius : 0,
    );

    Widget sliver = SliverMainAxisGroup(
      slivers: <Widget>[
        if (group.header != null) _headerSliver(group.header!, radius),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) => group._rowAt(index),
            childCount: group.children.length,
          ),
        ),
        if (group.footer != null) _footerSliver(group.footer!),
      ],
    );

    if (card) {
      sliver = SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: OhosListGroupMetrics.cardMargin,
        ),
        sliver: DecoratedSliver(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: radius,
          ),
          sliver: SliverPadding(
            padding: const EdgeInsets.all(OhosListGroupMetrics.cardPadding),
            sliver: sliver,
          ),
        ),
      );
    }
    return sliver;
  }

  Widget _headerSliver(Widget header, BorderRadius radius) {
    final Widget box = Padding(
      padding: group.headerPadding ?? kOhosListGroupHeaderPadding,
      child: header,
    );
    if (!_stickyHeader) return SliverToBoxAdapter(child: box);
    // 吸顶的组头必须自带背板。
    //
    // `PinnedHeaderSliver` 只负责把子节点钉在视口顶端，不负责遮挡 —— 组头一旦
    // 浮起来，后面的行就会从它下面穿过去。官方在
    // `ListItemGroupPattern::ApplyHeaderFooterStyle` 里做的是同一件事：给组头
    // 补上分组自己的圆角 + `UiMaterialStyle::THICK` 沉浸材质。这里照搬。
    return PinnedHeaderSliver(
      child: OhosLightMaterial(
        level: OhosLightMaterialLevel.thick,
        borderRadius: radius,
        child: box,
      ),
    );
  }

  Widget _footerSliver(Widget footer) {
    // 组尾**不吸底**，见 [sticky] 的说明。
    return SliverToBoxAdapter(
      child: Padding(
        padding: group.footerPadding ?? kOhosListGroupFooterPadding,
        child: footer,
      ),
    );
  }
}
