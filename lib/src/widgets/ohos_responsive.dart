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
  final EdgeInsetsGeometry? padding;

  /// Maximum content width of the grid (栅格最大使用宽度 2220vp).
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return OhosResponsiveBuilder(
      builder: (BuildContext context, OhosWindowSize size) {
        final double gutter = spacing ?? size.gutter;
        final double runGap = runSpacing ?? gutter;
        final EdgeInsetsGeometry pad =
            padding ?? EdgeInsets.symmetric(horizontal: size.margin);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: pad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final Widget row in _buildRows(size.columns, gutter))
                    Padding(
                      padding: EdgeInsets.only(bottom: runGap),
                      child: row,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Partitions children into rows whose span totals never exceed the active
  /// column count, then emits a [Row] of `Expanded` cells with gutters.
  List<Widget> _buildRows(int columns, double gutter) {
    final List<Widget> rows = <Widget>[];
    final List<Widget> row = <Widget>[];
    int remaining = columns;
    for (final Widget child in children) {
      int span = child is OhosGridItem ? child.columnSpan : 1;
      if (span > columns) {
        span = columns;
      }
      if (span > remaining && row.isNotEmpty) {
        rows.add(_emitRow(row, remaining, gutter));
        row.clear();
        remaining = columns;
      }
      row.add(
        Expanded(
          flex: span,
          child: child is OhosGridItem ? child.child : child,
        ),
      );
      remaining -= span;
      if (remaining <= 0) {
        rows.add(_emitRow(row, remaining, gutter));
        row.clear();
        remaining = columns;
      }
    }
    if (row.isNotEmpty) {
      rows.add(_emitRow(row, remaining, gutter));
    }
    return rows;
  }

  Widget _emitRow(List<Widget> row, int remaining, double gutter) {
    final List<Widget> cells = <Widget>[];
    for (int i = 0; i < row.length; i++) {
      if (i > 0) {
        cells.add(SizedBox(width: gutter));
      }
      cells.add(row[i]);
    }
    return Row(children: cells);
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
