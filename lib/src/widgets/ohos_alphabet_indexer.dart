import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// A vertical alphabetical index strip (索引条 in the HarmonyOS guideline)
/// used to jump through long lists. Tap or drag to select a letter.
class OhosAlphabetIndexer extends StatefulWidget {
  const OhosAlphabetIndexer({
    super.key,
    required this.indexer,
    required this.onSelected,
    this.itemHeight = 20,
    this.size = const Size(24, 360),
  });

  /// The letters to display, e.g. `A-Z`, `#`.
  final List<String> indexer;

  /// Called with the selected letter.
  final ValueChanged<String> onSelected;

  /// Height of each letter row.
  final double itemHeight;

  /// Size of the strip.
  final Size size;

  @override
  State<OhosAlphabetIndexer> createState() => _OhosAlphabetIndexerState();
}

class _OhosAlphabetIndexerState extends State<OhosAlphabetIndexer> {
  int _current = 0;

  void _selectAt(double dy) {
    final int index = (dy / widget.itemHeight).floor().clamp(
      0,
      widget.indexer.length - 1,
    );
    if (index != _current) {
      setState(() => _current = index);
      widget.onSelected(widget.indexer[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return SizedBox(
      width: widget.size.width,
      height: widget.size.height,
      child: GestureDetector(
        onTapDown: (TapDownDetails d) => _selectAt(d.localPosition.dy),
        onVerticalDragUpdate: (DragUpdateDetails d) =>
            _selectAt(d.localPosition.dy),
        // 字号按可用高度摊分：索引条高度小于 letters × 12vp 时（手机竖屏）
        // 原来 26 个字母会撑破 Column，出斑马线。
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double perLetter =
                constraints.maxHeight / widget.indexer.length;
            // 系统字体放大（如 Mate 60 Pro 默认 1.15）会把文字等比撑高，
            // 只按 vp 摊分还会溢出 27px —— 先把缩放折算回设计字号再取 95% 留余量。
            final double scaled = MediaQuery.textScalerOf(context).scale(12);
            final double textScale = scaled <= 0 ? 1 : scaled / 12;
            final double fontSize = (perLetter / textScale * 0.95)
                .clamp(5, 12);
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (int i = 0; i < widget.indexer.length; i++)
                  AnimatedDefaultTextStyle(
                    duration: OhosGeometry.durationShort,
                    style: TextStyle(
                      fontSize: fontSize,
                      height: 1,
                      color: i == _current
                          ? theme.highlightColor
                          : theme.textSecondaryColor,
                      fontWeight:
                          i == _current ? FontWeight.w600 : FontWeight.w400,
                    ),
                    child: Text(widget.indexer[i]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
