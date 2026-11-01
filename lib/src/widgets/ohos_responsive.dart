import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';

/// Window size category resolved from the official HarmonyOS breakpoints
/// (断点系统): the grid switches at 600vp and 840vp window widths.
enum OhosWindowSizeType {
  /// 手机竖屏窗口：`0 <= width < 600vp`，4 列栅格，16vp margin。
  compact,

  /// 折叠屏/平板竖屏窗口：`600 <= width < 840vp`，8 列栅格，24vp margin。
  medium,

  /// 平板横屏及更大窗口：`840 <= width`，12 列栅格，32vp margin。
  large,
}

/// Resolved layout parameters for the current [OhosWindowSizeType].
@immutable
class OhosWindowSize {
  const OhosWindowSize({
    required this.type,
    required this.width,
    required this.columns,
    required this.margin,
    required this.gutter,
  });

  /// The window size category.
  final OhosWindowSizeType type;

  /// Window width in logical pixels.
  final double width;

  /// Column count of the matching grid (4/8/12).
  final int columns;

  /// Page margin in logical pixels (16/24/32vp).
  final double margin;

  /// Grid gutter in logical pixels (8/12/16vp).
  final double gutter;

  /// Convenience getters.
  bool get isCompact => type == OhosWindowSizeType.compact;
  bool get isMedium => type == OhosWindowSizeType.medium;
  bool get isLarge => type == OhosWindowSizeType.large;

  /// Horizontal padding produced by the page margin.
  EdgeInsets get pagePadding => EdgeInsets.symmetric(horizontal: margin);

  /// Whether side tabs are recommended (>= 840vp).
  bool get useSideTab => isLarge;

  /// Resolves from a raw width.
  factory OhosWindowSize.fromWidth(double width) {
    final double w = width < 0 ? 0 : width;
    final OhosWindowSizeType type;
    final int columns;
    final double margin;
    final double gutter;
    if (w < OhosGeometry.breakpointCompact) {
      type = OhosWindowSizeType.compact;
      columns = OhosGeometry.gridColumnsCompact;
      margin = OhosGeometry.gridMarginCompact;
      gutter = OhosGeometry.gridGutterCompact;
    } else if (w < OhosGeometry.breakpointMedium) {
      type = OhosWindowSizeType.medium;
      columns = OhosGeometry.gridColumnsMedium;
      margin = OhosGeometry.gridMarginMedium;
      gutter = OhosGeometry.gridGutterMedium;
    } else {
      type = OhosWindowSizeType.large;
      columns = OhosGeometry.gridColumnsLarge;
      margin = OhosGeometry.gridMarginLarge;
      gutter = OhosGeometry.gridGutterLarge;
    }
    return OhosWindowSize(
      type: type,
      width: w,
      columns: columns,
      margin: margin,
      gutter: gutter,
    );
  }
}

/// Rebuilds its child whenever the window crosses a HarmonyOS breakpoint.
///
/// ```dart
/// OhosResponsiveBuilder(
///   builder: (context, size) => size.isLarge
///       ? _SplitView(size: size)
///       : _SingleListView(size: size),
/// )
/// ```
class OhosResponsiveBuilder extends StatelessWidget {
  const OhosResponsiveBuilder({super.key, required this.builder});

  /// Called with the current [OhosWindowSize] whenever it changes.
  final Widget Function(BuildContext context, OhosWindowSize size) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return builder(context, OhosWindowSize.fromWidth(constraints.maxWidth));
      },
    );
  }
}

/// A HarmonyOS responsive grid (栅格系统). It resolves 4/8/12 columns from the
/// window width breakpoints, applies the official margin and gutter, and lays
/// out [OhosGridItem] children with `columnSpan`.
///
/// Details that follow the official grid rather than the obvious `Row` /
/// `Column` shortcuts:
///
/// * A row that cannot be filled keeps **empty columns on the right** instead of
///   stretching its cells over the whole width, so every cell in the grid has
///   the same width (a lone `columnSpan: 3` item on a 12-column grid occupies a
///   quarter of the row, not all of it).
/// * Column width is `span · colWidth + (span − 1) · gutter`, independent of how
///   many cells share the row. It is reached by giving every cell `gutter / 2`
///   of padding on both sides and letting the outer [padding] give that half
///   back — so cells line up with the page margin, not half a gutter inside it.
/// * [maxWidth] caps the **cell area** (栅格最大使用宽度 2220vp); the page margin
///   is applied outside that cap, not inside it.
/// * [runSpacing] separates rows; no trailing gap is added below the last row.
///
/// ```dart
/// OhosGrid(
///   children: <Widget>[
///     OhosGridItem(columnSpan: 2, child: Card(...)),
///     OhosGridItem(columnSpan: 2, child: Card(...)),
///   ],
/// )
/// ```
class OhosGrid extends StatelessWidget {
  const OhosGrid({
    super.key,
    required this.children,
    this.spacing,
    this.runSpacing,
    this.padding,
    this.maxWidth = OhosGeometry.gridMaxWidth,
  });

  /// Grid columns to place. Use [OhosGridItem] to control spans.
  final List<Widget> children;

  /// Overrides the horizontal gutter between columns.
  final double? spacing;

  /// Overrides the vertical gutter between rows.
  final double? runSpacing;

  /// Padding around the grid; defaults to the official [OhosWindowSize.margin].
  ///
  /// Measured to the outer edge of the first / last cell. Because cells keep
  /// half a gutter of padding of their own, `gutter / 2` is taken off the left
  /// and right side here; a side smaller than that (e.g. `EdgeInsets.zero`)
  /// cannot be compensated and the cells end up inset by the remainder.
  final EdgeInsetsGeometry? padding;

  /// Maximum content width of the grid (栅格最大使用宽度 2220vp).
  ///
  /// The cap applies to the content area only; the page margin (or [padding])
  /// sits outside it, so the whole grid may be `maxWidth + 2 × margin` wide.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return OhosResponsiveBuilder(
      builder: (BuildContext context, OhosWindowSize size) {
        final double gutter = spacing ?? size.gutter;
        final double runGap = runSpacing ?? gutter;
        final double half = gutter / 2;
        final EdgeInsets base =
            (padding ?? EdgeInsets.symmetric(horizontal: size.margin)).resolve(
              Directionality.maybeOf(context) ?? TextDirection.ltr,
            );
        // 列宽由 Row 的 flex 摊分，但「单元 + 固定宽的 spacer」会让列宽跟着
        // 「本行有几个单元」变（4×span3 与 1×span3 差出小半个 gutter）。这里把
        // gutter 劈成两半放进每个单元的内边距：槽位宽 = (内容宽 + gutter)·span/列数，
        // 减去两侧各 half 后正好是 span·colWidth + (span-1)·gutter —— 官方列宽公式，
        // 且与同行单元个数无关，行与行之间边缘严丝合缝。
        //
        // 首尾两格也因此各内缩 half，所以外层 padding 让回 half，单元边缘仍落在
        // 页面边距上；maxWidth 上限同步加回一个 gutter，可见内容区依然以它为界。
        final EdgeInsets pad = EdgeInsets.only(
          left: _shave(base.left, half),
          top: base.top,
          right: _shave(base.right, half),
          bottom: base.bottom,
        );
        final List<Widget> rows = _buildRows(size.columns, gutter);
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: pad,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth + gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // 行距只加在行与行之间：末行也补一段会让网格底部凭空多出一条
                  // runSpacing 的空隙，调用方拼接下一块内容时对不齐。
                  for (int i = 0; i < rows.length; i++)
                    if (i == rows.length - 1)
                      rows[i]
                    else
                      Padding(
                        padding: EdgeInsets.only(bottom: runGap),
                        child: rows[i],
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static double _shave(double value, double amount) =>
      value > amount ? value - amount : 0;

  /// Partitions children into rows whose span totals never exceed the active
  /// column count, then emits a [Row] of `Expanded` cells.
  ///
  /// Each cell carries `gutter / 2` of padding on both sides (see [build]), so
  /// the gap between two neighbours adds up to a full gutter while the cell
  /// itself keeps the official column width.
  List<Widget> _buildRows(int columns, double gutter) {
    final EdgeInsets inset = EdgeInsets.symmetric(horizontal: gutter / 2);
    final List<Widget> rows = <Widget>[];
    final List<Widget> row = <Widget>[];
    int remaining = columns;
    for (final Widget child in children) {
      int span = child is OhosGridItem ? child.columnSpan : 1;
      if (span > columns) {
        span = columns;
      }
      if (span > remaining && row.isNotEmpty) {
        rows.add(_emitRow(row, remaining));
        row.clear();
        remaining = columns;
      }
      row.add(
        Expanded(
          flex: span,
          child: Padding(
            padding: inset,
            child: child is OhosGridItem ? child.child : child,
          ),
        ),
      );
      remaining -= span;
      if (remaining <= 0) {
        rows.add(_emitRow(row, 0));
        row.clear();
        remaining = columns;
      }
    }
    if (row.isNotEmpty) {
      rows.add(_emitRow(row, remaining));
    }
    return rows;
  }

  /// Emits one [Row] from the collected cells.
  ///
  /// [remaining] is the number of columns still free at the end of the row; a
  /// row that stops short keeps that many empty columns on the right instead of
  /// stretching its cells. Without the spacer, a lone `columnSpan: 3` item on a
  /// 12-column grid would spread over the whole row rather than a quarter of it.
  Widget _emitRow(List<Widget> row, int remaining) {
    return Row(
      children: <Widget>[
        ...row,
        if (remaining > 0)
          Expanded(flex: remaining, child: const SizedBox.shrink()),
      ],
    );
  }
}

/// A grid cell that spans [columnSpan] of the active responsive grid.
class OhosGridItem extends StatelessWidget {
  const OhosGridItem({super.key, required this.child, this.columnSpan = 1});

  /// Number of columns occupied by [child] (1 … active grid column count).
  final int columnSpan;

  /// The cell content.
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
