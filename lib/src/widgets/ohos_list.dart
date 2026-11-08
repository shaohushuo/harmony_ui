import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_divider.dart';
import 'ohos_list_group.dart';
import 'ohos_list_tile.dart';

/// 列表分割线的样式，对应 ArkUI 的 `ListDividerOptions`。
///
/// 官方四个字段：`strokeWidth`（必填）、`color`（默认 `0x08000000`）、
/// `startMargin`、`endMargin`（默认 0）。
///
/// 两条容易漏的官方约束，都影响观感而不只是数值：
/// * 「分割线的宽度会影响子组件之间的间隔，当 `space` 或 `spaceWidth` 值小于
///   分割线宽度时，子组件主轴方向的间隔取分割线宽度」—— 也就是说线宽是
///   **间距下限**，不是「画在间距中间的一根细线」；
/// * 「`endMargin + startMargin` 超过列宽度后 **startMargin 和 endMargin
///   均会被置 0**」—— 不是夹到刚好放得下，是两个都归零。这条在行为上很怪，
///   但它是官方原话，而且能观测到（线会突然贴满两端）。
@immutable
class OhosListDivider {
  const OhosListDivider({
    this.strokeWidth,
    this.color,
    this.startMargin = 0,
    this.endMargin = 0,
  });

  /// 线宽（vp）。`null` 时按官方 `1px` 设备像素（与 [OhosDivider] 同源）。
  ///
  /// 官方这个字段**必填**，本库给可空是为了让默认值挂在主题上：墨屏要的是
  /// 1 个设备像素的实线，彩屏是 1 物理像素的发丝线，两者都不是一个固定 vp。
  final double? strokeWidth;

  /// 线色。`null` 用 `theme.dividerColor`。
  ///
  /// 官方默认 `0x08000000`（3% 黑）。本库**不**用它 —— 墨屏上 3% 黑落在
  /// 16 级灰的第 0 级、与纸面完全分不开（与 `OhosGroupDivider` 同一条理由）。
  final Color? color;

  /// 与列表侧边起始端的距离（vp）。官方默认 0，负数按 0。
  final double startMargin;

  /// 与列表侧边结束端的距离（vp）。官方默认 0，负数按 0。
  final double endMargin;

  @override
  bool operator ==(Object other) =>
      other is OhosListDivider &&
      other.strokeWidth == strokeWidth &&
      other.color == color &&
      other.startMargin == startMargin &&
      other.endMargin == endMargin;

  @override
  int get hashCode => Object.hash(strokeWidth, color, startMargin, endMargin);
}

/// 多列布局，对应官方 `lanes` 的两形态。
///
/// 官方 `lanes(value: number | LengthConstrain, gutter?)`：传数字是**列数**，
/// 传 `LengthConstrain` 是「最小列宽 → 由组件宽度反推最大列数」。两种形态
/// 的结果不同，所以用 sealed 类表达而不是一个 `int?`。
@immutable
sealed class OhosListLanes {
  const OhosListLanes({this.gutter = 0});

  /// 列间距（官方 `gutter`，10+）。
  final double gutter;

  /// 由「列表交叉轴可用长度」算出实际列数。
  int resolve(double crossAxisExtent);
}

/// 固定列数（官方 `lanes: number`）。
///
/// 官方「取值范围 [1, +∞)，传入小于 1 的值时按默认值处理」—— 默认 1。
@immutable
class OhosFixedLanes extends OhosListLanes {
  const OhosFixedLanes(this.count, {super.gutter});

  /// 列数。
  final int count;

  @override
  int resolve(double crossAxisExtent) => count < 1 ? 1 : count;
}

/// 最小列宽（官方 `lanes: LengthConstrain`）。
///
/// 官方「`minLength` 表示最小列宽，List 组件会根据自身宽度在满足最小列宽
/// 的情况下计算最大列数」。
@immutable
class OhosLanesByWidth extends OhosListLanes {
  const OhosLanesByWidth(this.minWidth, {super.gutter});

  /// 最小列宽。≤0 时按 [OhosListMetrics.defaultLanesMinWidth]（自拟防呆值）。
  final double minWidth;

  @override
  int resolve(double crossAxisExtent) {
    final double min = minWidth > 0
        ? minWidth
        : OhosListMetrics.defaultLanesMinWidth;
    if (crossAxisExtent <= 0) {
      return 1;
    }
    // 列数 = (可用宽度 + gutter) / (minWidth + gutter)，向下取整。
    // 把 gutter 加进分子分母是为了「n 列 + (n-1) 个间距」恰好不超宽 ——
    // 直接用 extent / min 会多算一列。
    final int n = ((crossAxisExtent + gutter) / (min + gutter)).floor();
    return n < 1 ? 1 : n;
  }
}

/// `OhosList` 里那些「官方给了具体值」或「本库自拟但有理由」的常量。
class OhosListMetrics {
  const OhosListMetrics._();

  /// `LengthConstrain` 形态下 `minLength` 的防呆回落。
  ///
  /// **自拟**：官方只说「`minLength` 表示最小列宽」，没给默认值也没说上限。
  /// 取 104 是因为本库最窄的列表卡片（`OhosListItemCard`）是 72 高 + 两侧
  /// 12 外边距，一行三层文本至少要 100 宽才放得下标题，再窄就换成单列更合理。
  static const double defaultLanesMinWidth = 104;

  /// 「滚动到边缘」的判定阈值。
  ///
  /// **自拟**：官方只定义「到达起始/末尾位置时触发」，没给像素阈值。取 0
  /// —— 也就是严格按 `pixels <= minScrollExtent` / `>= maxScrollExtent` 判，
  /// 不引入容差。理由是：加了容差之后「到达」会提前触发，而官方两个回调在
  /// 弹簧效果下会「经过时一次、回弹时再一次」，容差会让这两个事件合并成一个。
  static const double reachTolerance = 0;
}

/// 列表容器，ArkUI `List` 的 Flutter 对应物。
///
/// ## 两种形态
///
/// - **静态形态**（默认）：[children] 一次性排布，不滚动。这是 0.5 就有的
///   形态 —— 官方 `List` 本身是滚动容器，但本库的 `OhosList` 在示例与文档里
///   一直当「带分组标题的卡片容器」用，直接改成滚动容器会让所有既有布局
///   突然多出一个视口高度。所以滚动形态走 [OhosList.scrollable]，默认形态不变。
/// - **滚动形态**：给一个固定高度，内部是 [CustomScrollView]，此时
///   [lanes] / [sticky] / [onReachStart] / [onReachEnd] / [onScrollIndex]
///   才生效。
///
/// 分割线默认**有**（与本库 0.5 的行为一致）；这与官方的「默认无分割线」
/// 相反 —— 这个差别在本库是刻意的：`OhosList` 的既有语义是「设置页的那种
/// 带线卡片」，改成默认无线会让所有既有页面丢掉分隔。要严格对齐官方就显式
/// 传 `divider: null`。
class OhosList extends StatefulWidget {
  /// 静态卡片容器形态。
  const OhosList({
    super.key,
    required this.children,
    this.header,
    this.headerPadding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
    this.divider = true,
    this.dividerStyle,
    this.cornerRadius = 16,
  }) : scrollable = false,
       height = null,
       lanes = null,
       sticky = OhosListStickyStyle.none,
       onReachStart = null,
       onReachEnd = null,
       onScrollIndex = null,
       controller = null,
       padding = EdgeInsets.zero;

  /// 滚动形态，对应官方 `List` 的滚动能力。
  const OhosList.scrollable({
    super.key,
    required this.children,
    this.height,
    this.header,
    this.headerPadding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
    this.divider = true,
    this.dividerStyle,
    this.cornerRadius = 16,
    this.lanes,
    this.sticky = OhosListStickyStyle.none,
    this.onReachStart,
    this.onReachEnd,
    this.onScrollIndex,
    this.controller,
    this.padding = EdgeInsets.zero,
  }) : scrollable = true;

  /// Rows or groups inside the list.
  final List<Widget> children;

  /// Optional section header (usually an [OhosSubheader]).
  final Widget? header;

  /// Padding of the [header].
  final EdgeInsetsGeometry headerPadding;

  /// 是否画行间分割线。
  ///
  /// 与官方「默认无分割线」相反（官方 `divider` 默认 `null`），本库默认 `true`
  /// —— 见类注释。
  final bool divider;

  /// 分割线样式（官方 `ListDividerOptions`）。`null` 时用本库默认的发丝线。
  final OhosListDivider? dividerStyle;

  /// 卡片圆角（静态形态的外底板）。滚动形态下不铺底板。
  final double cornerRadius;

  /// 是否走滚动形态。
  final bool scrollable;

  /// 滚动形态的高度。`null` 时撑满父级给的约束。
  final double? height;

  /// 多列（官方 `lanes`）。只有滚动形态生效。
  ///
  /// 官方「`ListItemGroup` 在多列模式下也是独占一行」—— 本库的分组是
  /// [OhosListGroup]，它天然是一整块，在多列里也独占一行，与官方一致。
  final OhosListLanes? lanes;

  /// 吸顶 / 吸底（官方 `sticky`）。只有滚动形态生效。
  ///
  /// 官方这个属性挂在 `List` 上、一次管住所有 `ListItemGroup`。本库的
  /// [OhosListGroupSliver] 是逐组声明 —— 逐组能表达的集合严格更大（可以
  /// 「这组吸、那组不吸」），而「所有组都吸」就是给每个组传同一个值。
  /// 所以这里做的是**广播**：把 [sticky] 应用到每一个 [OhosListGroup] 子节点。
  ///
  /// **只落地了组头吸顶**，`footer` / `both` 传进来组尾仍不吸底（理由见
  /// [OhosListGroupSliver.sticky] 的注释）。
  final OhosListStickyStyle sticky;

  /// 到达起始位置（官方 `onReachStart`）。只有滚动形态生效。
  final VoidCallback? onReachStart;

  /// 到达末尾位置（官方 `onReachEnd`）。只有滚动形态生效。
  final VoidCallback? onReachEnd;

  /// 可视区首/尾/中项索引变化（官方 `onScrollIndex(start, end, center)`）。
  ///
  /// 官方 10+ 才补上 `center`。本库这个回调**只在滚动形态**有效 ——
  /// 静态形态没有视口，索引没有意义。
  final void Function(int start, int end, int center)? onScrollIndex;

  /// 滚动控制器（官方 `scroller`）。
  final ScrollController? controller;

  /// 内容内边距。
  final EdgeInsetsGeometry padding;

  @override
  State<OhosList> createState() => _OhosListState();
}

class _OhosListState extends State<OhosList> {
  ScrollController? _ownedController;
  bool _atStart = true;
  bool _atEnd = false;
  int _lastStart = -1;
  int _lastEnd = -1;
  int _lastCenter = -1;

  ScrollController get _controller =>
      widget.controller ?? (_ownedController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    if (widget.scrollable) {
      _controller.addListener(_onScroll);
      // 官方「List 初始化时如果 initialIndex 为 0 会触发一次 `onReachStart`」
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onReachStart?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    if (_ownedController != null) {
      _ownedController!.dispose();
      _ownedController = null;
    }
    super.dispose();
  }

  void _onScroll() {
    final ScrollPosition? position = _controller.hasClients
        ? _controller.position
        : null;
    if (position == null) {
      return;
    }

    // 官方「到达起始位置时触发」「当最后一个子组件…出现在列表视窗中时触发」。
    // 用 `pixels` 与两个边界比较，**不给容差**：加了容差会让「到达」提前
    // 触发，而弹簧效果下「经过时一次 + 回弹时一次」是两个独立事件。
    final double tol = OhosListMetrics.reachTolerance;
    final bool atStart = position.pixels <= position.minScrollExtent + tol;
    final bool atEnd = position.pixels >= position.maxScrollExtent - tol;
    if (atStart && !_atStart) {
      widget.onReachStart?.call();
    }
    if (atEnd && !_atEnd) {
      widget.onReachEnd?.call();
    }
    _atStart = atStart;
    _atEnd = atEnd;

    final void Function(int, int, int)? index = widget.onScrollIndex;
    if (index == null) {
      return;
    }
    final _VisibleRange range = _visibleRange(position, widget.children.length);
    if (range.start != _lastStart ||
        range.end != _lastEnd ||
        range.center != _lastCenter) {
      _lastStart = range.start;
      _lastEnd = range.end;
      _lastCenter = range.center;
      index(range.start, range.end, range.center);
    }
  }

  /// 可视区索引区间的近似值。
  ///
  /// **这是近似，且必须说清近似的方向**：官方 `onScrollIndex` 给的是
  /// 实际滑入/滑出视口的那三个索引。Flutter 侧在不给每一项挂
  /// `GlobalKey` 的前提下拿不到真实索引，只能用「滚动偏移 ÷ 等比高度」估算。
  /// 所以本库的取值**按等高项**成立，项高不等时会偏 —— 与官方
  /// `scrollSnapAlign` 那句「只支持 item 等高场景限位」是同一类限制。
  _VisibleRange _visibleRange(ScrollPosition position, int count) {
    if (count <= 0) {
      return const _VisibleRange(0, 0, 0);
    }
    final double extent = position.viewportDimension;
    final double total = position.maxScrollExtent + extent;
    if (total <= 0 || extent <= 0) {
      return _VisibleRange(0, count - 1, (count - 1) ~/ 2);
    }
    final double itemExtent = total / count;
    final int start = (position.pixels / itemExtent).floor().clamp(
      0,
      count - 1,
    );
    final int end =
        ((position.pixels + extent) / itemExtent).ceil().clamp(1, count) - 1;
    // 官方 `center` 是「显示区域中间位置子组件的索引值」
    final int center = ((position.pixels + extent / 2) / itemExtent)
        .floor()
        .clamp(0, count - 1);
    return _VisibleRange(start, end < start ? start : end, center);
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return widget.scrollable ? _buildScrollable(theme) : _buildStatic(theme);
  }

  /// 静态形态：一张圆角卡片，内部按顺序排布，不用视口。
  Widget _buildStatic(OhosThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.header != null)
          Padding(padding: widget.headerPadding, child: widget.header!),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(widget.cornerRadius),
          ),
          child: Padding(
            padding: widget.padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < widget.children.length; i++)
                  _row(i, isLast: i == widget.children.length - 1),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(int i, {required bool isLast}) {
    final Widget child = widget.children[i];
    final bool isTile = child is OhosListTile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OhosListDividerScope(
          // 只有直接放进列表的 tile 才需要「下面还有一行」这个信号。
          // 非 tile 子节点（包括包了一层 Padding/InkWell 的 tile）一律给
          // false：那条线由列表自己补，里面再画一条就叠成双线。
          showBottom: widget.divider && !isLast && isTile,
          child: child,
        ),
        // tile 自己会画线（indent 随 leading），只有非 tile 子节点需要列表
        // 在这里补一条，避免又叠成两条。
        if (widget.divider && !isLast && !isTile) _divider(),
      ],
    );
  }

  Widget _divider() {
    final OhosListDivider? style = widget.dividerStyle;
    // 没有 `dividerStyle` 时沿用 0.5 的默认缩进：左侧让开 56（图标列 40 +
    // 16 内边距，与 `OhosListTile` 的 leading 对齐）、右侧收 16 —— 线不穿到
    // 卡片边缘。这是本库的既有观感，改掉会让所有既有页面的线突然贯穿到底。
    //
    // 官方的 `startMargin` / `endMargin` 默认是 **0**（线贴满两端），与这里
    // 相反。要严格对齐官方就显式传 `dividerStyle: OhosListDivider()`。
    return OhosDivider(
      thickness: style?.strokeWidth,
      color: style?.color,
      indent: style?.startMargin ?? _defaultDividerIndent,
      endIndent: style?.endMargin ?? _defaultDividerEndIndent,
    );
  }

  /// 默认左缩进（见 [_divider] 的说明）。
  static const double _defaultDividerIndent = 56;

  /// 默认右缩进（见 [_divider] 的说明）。
  static const double _defaultDividerEndIndent = 16;

  /// 滚动形态：`CustomScrollView` 承载，支持 lanes / sticky / 滚动回调。
  Widget _buildScrollable(OhosThemeData theme) {
    final List<Widget> slivers = <Widget>[];
    if (widget.header != null) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(padding: widget.headerPadding, child: widget.header!),
        ),
      );
    }

    final int lanes =
        widget.lanes?.resolve(MediaQuery.maybeSizeOf(context)?.width ?? 0) ?? 1;
    final double gutter = widget.lanes?.gutter ?? 0;

    // 官方 `ListItemGroup` 在多列下也独占一行，本库的 `OhosListGroup` 是一整块
    // Widget —— 与组头吸顶(SliverMainAxisGroup)同理，分组必须是 **sliver**
    // 而不是塞进 `SliverList` 的一格里。所以这里维护两个滑轨：
    //   - `boxRows`：普通子节点，逐项进 SliverList / SliverGrid
    //   - `slivers`：分组，直接进 CustomScrollView
    // 顺序由 `pending` 缓冲保序 —— 遇到分组就先把攒下的 boxRows 冲成一个
    // sliver，再追加分组 sliver。
    final List<Widget> boxRows = <Widget>[];
    void flushBoxes() {
      if (boxRows.isEmpty) {
        return;
      }
      // 必须留一份快照再清空：`itemBuilder` 是**懒执行**的，它引用的
      // `boxRows` 会在下一轮追加时被改写/清空 —— 直接闭包捕获会拿到空列表，
      // 报 `RangeError: Valid value range is empty`（第 0 项就崩）。
      final List<Widget> rows = List<Widget>.of(boxRows);
      boxRows.clear();
      if (lanes > 1) {
        // **不能用 `SliverGrid`。** 试过，溢出矩阵当场抓到：
        // `SliverGridDelegateWithFixedCrossAxisCount` 的
        // `childAspectRatio` 会把每格的高度钉死 —— 360 屏上两列时每格
        // 160 宽、按 200/56 的比例只给 **44.8** 高，而 `OhosListTile`
        // 的常规档要 58，于是 `RenderFlex overflowed by 13 pixels`。
        // 官方 `lanes` 只说「列数」，行高由 `ListItem` 自己的高决定，
        // 所以这里用 `SliverCrossAxisGroup` 把相邻 N 项**按自然高度**并排
        // —— 每行取该行最高的一项，与官方「一组 ListItem 排一行」一致。
        final List<Widget> lineRuns = <Widget>[];
        for (int start = 0; start < rows.length; start += lanes) {
          final int end = (start + lanes) > rows.length
              ? rows.length
              : start + lanes;
          lineRuns.add(
            SliverCrossAxisGroup(
              slivers: <Widget>[
                for (int i = start; i < end; i++)
                  SliverToBoxAdapter(
                    child: Padding(
                      // 只有非最后一列要有 gutter，否则右边缘会多一条空白
                      padding: EdgeInsets.only(
                        right: i == end - 1 ? 0 : gutter,
                      ),
                      child: rows[i],
                    ),
                  ),
              ],
            ),
          );
        }
        slivers.add(
          SliverPadding(
            padding: widget.padding,
            sliver: SliverMainAxisGroup(slivers: lineRuns),
          ),
        );
      } else {
        slivers.add(
          SliverPadding(
            padding: widget.padding,
            sliver: SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (BuildContext context, int i) => rows[i],
            ),
          ),
        );
      }
    }

    for (int i = 0; i < widget.children.length; i++) {
      final Widget child = widget.children[i];
      final bool isLast = i == widget.children.length - 1;
      if (child is OhosListGroup) {
        flushBoxes();
        slivers.add(OhosListGroupSliver(group: child, sticky: widget.sticky));
        continue;
      }
      // tile 自己画线；非 tile 由列表补一条 —— 与静态形态同一条规则。
      boxRows.add(
        OhosListDividerScope(
          showBottom: widget.divider && !isLast && child is OhosListTile,
          child: widget.divider && !isLast && child is! OhosListTile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[child, _divider()],
                )
              : child,
        ),
      );
    }
    flushBoxes();

    return SizedBox(
      height: widget.height,
      child: CustomScrollView(controller: _controller, slivers: slivers),
    );
  }
}

@immutable
class _VisibleRange {
  const _VisibleRange(this.start, this.end, this.center);

  final int start;
  final int end;
  final int center;
}
