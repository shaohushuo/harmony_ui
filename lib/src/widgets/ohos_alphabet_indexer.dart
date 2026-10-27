import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_magnifier.dart';

/// A vertical alphabetical index strip (索引条 in the HarmonyOS guideline)
/// used to jump through long lists. Tap or drag to select a letter.
///
/// The letters are laid out as equal-height slots and the hit test uses the
/// very same slot height, so the letter under the finger is the letter handed
/// to [onSelected]: there is no second geometry for the caller to keep in
/// sync. The slot height comes from the parent's constraints (falling back to
/// [size] when the height is unbounded), so a shrinking panel shrinks the
/// strip instead of overflowing it.
class OhosAlphabetIndexer extends StatefulWidget {
  const OhosAlphabetIndexer({
    super.key,
    required this.indexer,
    required this.onSelected,
    this.size = const Size(24, 360),
    this.selectedIndex,
    this.onSelectEnd,
    this.showMagnifier = true,
    this.magnifierBuilder,
  });

  /// The letters to display, e.g. `A-Z`, `#`.
  final List<String> indexer;

  /// Called with the selected letter.
  ///
  /// Taps always fire, including the letter that is already highlighted: the
  /// strip does not know where the list is scrolled to, so a "no change, no
  /// callback" shortcut swallows the tap on the letter the list currently sits
  /// at. Jumping to the same offset twice is harmless for the caller.
  ///
  /// Drags fire only when the finger crosses into another letter — a drag
  /// update arrives on every frame, and notifying per frame turns the caller's
  /// `jumpTo` into a continuous scroll.
  final ValueChanged<String> onSelected;

  /// Preferred size of the strip.
  ///
  /// The width is used as-is; the height is an upper bound — when the parent
  /// hands down a smaller height (a draggable panel, `Expanded`, …), the strip
  /// shrinks to it and the letters scale down with it. When the height is
  /// unbounded, [Size.height] is used.
  final Size size;

  /// Index of the highlighted letter, or null to let the strip keep it
  /// itself (updated by taps / drags).
  ///
  /// A new value is written into the internal state (so the highlight follows
  /// both the caller's jumps and the finger — one paint path). [onSelected]
  /// still fires normally, the caller decides whether to adopt a hit. The
  /// usual use case is a position the caller located by code — restoring the
  /// last seen item, jumping between the index and the list — where the item
  /// index is already at hand, so one `setState` is enough and no scroll
  /// subscription is needed.
  ///
  /// Out-of-range values assert in debug and are clamped in release.
  final int? selectedIndex;

  /// Called once when the interaction settles: tap up, drag up, or drag
  /// cancel — always with the letter that ended up highlighted.
  ///
  /// Division of labour with [onSelected]: that one is the process (a tap fires
  /// once immediately; a drag fires once per letter crossed), this one is the
  /// result (exactly once). Callers who want "locate only on release" subscribe
  /// here and need not remember the last [onSelected] value.
  final ValueChanged<String>? onSelectEnd;

  /// Whether a magnifier bubble follows the finger while dragging.
  ///
  /// Taps do not show it: the finger is already lifting, so a flash is more
  /// noise than help. The bubble is drawn in the nearest [Overlay] (supplied by
  /// `MaterialApp` / `WidgetsApp`), which lets it paint outside the strip; a
  /// tree without one simply shows nothing.
  final bool showMagnifier;

  /// Replaces the bubble content for [letter] — for example a capsule with an
  /// arrow, or a plain colour block. Null keeps the default [OhosMagnifier]
  /// with the letter set large.
  final Widget Function(BuildContext context, String letter)? magnifierBuilder;

  @override
  State<OhosAlphabetIndexer> createState() => _OhosAlphabetIndexerState();
}

class _OhosAlphabetIndexerState extends State<OhosAlphabetIndexer> {
  int _current = 0;
  bool _dragging = false;
  OhosMagnifierController? _magnifier;

  /// 泡泡与手指之间的留白，按「指肚接触半径」估：约 10mm 的接触面在手机
  /// 上折合 30vp 上下，再留一点余量取 32vp —— 否则泡泡的两个近边会被
  /// 指肚遮掉一部分（16vp 实测仍压手）。两个轴都要留，泡泡才真正落在
  /// 手指的左上/右上「角」上。
  static const double _magnifierGap = 32;

  /// `selectedIndex` 只在**变化**时回写内部状态：绘制、命中、气泡都读
  /// [_current] 一个来源。若改成"绘制优先外部值"，受控期间手指拖动就看不到
  /// 高亮反馈了。
  @override
  void initState() {
    super.initState();
    _syncSelected(widget.selectedIndex, null);
  }

  @override
  void didUpdateWidget(OhosAlphabetIndexer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSelected(widget.selectedIndex, oldWidget.selectedIndex);
    // 字母表可能在运行中变短（切换分组 / 数据刷新）：上面只在外部
    // `selectedIndex` 变化时才重算，父级换了个更短的 `indexer` 而
    // `selectedIndex` 没变时 `_current` 会停在旧位置 —— 高亮错位、命中错格，
    // 而三个回调都拿它当 `indexer` 的下标。
    final int count = widget.indexer.length;
    if (count > 0 && _current >= count) {
      _current = count - 1;
    }
  }

  void _syncSelected(int? selected, int? previous) {
    if (selected == null || selected == previous) {
      return;
    }
    final int count = widget.indexer.length;
    assert(
      selected >= 0 && selected < count,
      'selectedIndex $selected 超出 0..${count - 1}',
    );
    _current = count == 0 ? 0 : selected.clamp(0, count - 1);
  }

  /// 命中一格。`slot` 来自 `build` 里同一个约束（布局、字号、命中同源）。
  ///
  /// `force` 由 tap 路径传入：点哪个字母都要通知。
  ///
  /// 拖动路径不传 —— `onVerticalDragUpdate` 每帧都会来一次，逐帧 `onSelected`
  /// 会把调用方的 `jumpTo` 打成连续滚动，所以只在**跨格**时通知（0.3.0 的
  /// 去重口径，只是把 tap 从短路里摘了出来）。
  void _selectAt(double dy, double slot, {bool force = false}) {
    final int index = slot <= 0
        ? 0
        : (dy / slot).floor().clamp(0, widget.indexer.length - 1);
    final bool changed = index != _current;
    if (changed) {
      setState(() => _current = index);
    }
    if (force || changed) {
      widget.onSelected(widget.indexer[index]);
    }
  }

  void _startDrag(DragStartDetails details, double slot) {
    _dragging = true;
    // 越过 slop 的位置往往已经不是落指那一点：先按当前位置更新一次，泡泡
    // 才不会先闪一个上一个字母。
    _selectAt(details.localPosition.dy, slot);
    _showMagnifier(details.globalPosition);
  }

  void _showMagnifier(Offset anchor) {
    if (!widget.showMagnifier) {
      return;
    }
    final String? letter = _currentLetter;
    if (letter == null) {
      return;
    }
    final OhosMagnifierController controller = _magnifier ??=
        OhosMagnifierController();
    controller.show(
      context,
      anchor: anchor,
      text: widget.magnifierBuilder == null ? letter : null,
      child: widget.magnifierBuilder?.call(context, letter),
      gap: _magnifierGap,
    );
  }

  /// 先算新字母、再更新泡泡：否则会出现「泡泡还停在上一个字母、列表已跳走」。
  void _updateMagnifier(Offset anchor) {
    final OhosMagnifierController? controller = _magnifier;
    if (controller == null || !controller.isShowing) {
      return;
    }
    final String? letter = _currentLetter;
    if (letter == null) {
      return;
    }
    controller.update(
      anchor,
      text: widget.magnifierBuilder == null ? letter : null,
      child: widget.magnifierBuilder?.call(context, letter),
    );
  }

  void _hideMagnifier() {
    _magnifier?.hide();
  }

  /// 当前生效的字母；空表时返回 null。
  ///
  /// 放大镜的显示 / 跟随与 [OhosAlphabetIndexer.onSelectEnd] 都把它当
  /// `indexer` 的下标：[didUpdateWidget] 的夹紧只在 `count > 0` 时成立，字母表
  /// 被父级换成空表时没有任何合法下标，这里统一兜住 —— 否则「拖动中列表刷新」
  /// 这条路径抬手就会 `RangeError`。
  String? get _currentLetter {
    final List<String> letters = widget.indexer;
    if (letters.isEmpty) {
      return null;
    }
    return letters[_current.clamp(0, letters.length - 1)];
  }

  void _selectEnd() {
    final String? letter = _currentLetter;
    if (letter != null) {
      widget.onSelectEnd?.call(letter);
    }
  }

  /// 抬手 / 中途取消时收尾。`onVerticalDragCancel` 在「点按被 tap 抢走」
  /// 时同样会触发，所以用 `_dragging` 挡掉从未真正开始的拖动。
  void _finishDrag() {
    _hideMagnifier();
    if (!_dragging) {
      return;
    }
    _dragging = false;
    _selectEnd();
  }

  Widget _letter(
    OhosThemeData theme,
    TextStyle base,
    int index,
    double fontSize,
  ) {
    // 只读内部状态：受控值已经在 initState / didUpdateWidget 里回写过了，
    // 所以"外部定位"与"手指拖动"共用一条绘制路径。
    final bool on = index == _current;
    // 字号不作隐式动画：容器高度是立即变的，字号若走 200ms 过渡，拖动期间
    // 每一帧都偏大，字母会互相压住（0.3.0 里直接 `RenderFlex overflowed`）。
    return DefaultTextStyle(
      // copyWith 而不是新建 TextStyle：字体家族这类没在这里列出的字段要
      // 从外层 DefaultTextStyle 继承。新建会把 fontFamily 丢掉，真机上看
      // 不出问题，flutter_tester 里 null 家族 = Ahem，整列变成实心方块。
      //
      // 外层也可能没有家族（Material 的 M3 默认是 Roboto，测试环境并未加载）：
      // 退到本库主题口径。注意这**不**等于 golden 能出真字 —— 家族没注册时
      // 引擎仍回退 Ahem，截图侧得用 FontLoader 把真实字体注册到同一个家族。
      style: base.copyWith(
        fontFamily: base.fontFamily ?? theme.typography.fontFamily,
        fontSize: fontSize,
        height: 1,
        color: on ? theme.highlightColor : theme.textSecondaryColor,
        fontWeight: on ? FontWeight.w600 : FontWeight.w400,
      ),
      child: Text(widget.indexer[index]),
    );
  }

  @override
  void dispose() {
    _magnifier?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final TextStyle base = DefaultTextStyle.of(context).style;
    final int count = widget.indexer.length;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 条高：默认 size.height，父级的约束优先 —— 可拖分隔条的面板会把可用
        // 高度压到 size.height 以下，按 size 算就会溢出；反过来父级给的是比
        // size.height **更高**的紧约束时，`SizedBox` 会被 minHeight 抬上去，
        // 只按 maxHeight 算会让字母挤在顶部、命中区却铺满整条（点空白跳末格）。
        // `constrainHeight` 同时看 min 与 max，命中格与视觉格才重合。
        final double height = constraints.hasBoundedHeight
            ? constraints.constrainHeight(widget.size.height)
            : widget.size.height;
        if (count == 0 || height <= 0) {
          return SizedBox(width: widget.size.width, height: 0);
        }
        // 唯一来源：布局、字号、命中都用这个 slot，不再有第二套几何。
        final double slot = height / count;
        // 字号按槽位高度摊分：索引条高度小于 letters × 12vp 时（手机竖屏）
        // 原来 26 个字母会撑破 Column，出斑马线。系统字体放大（如 Mate 60 Pro
        // 默认 1.15）会把文字等比撑高，只按 vp 摊分还会溢出 27px —— 先把缩放
        // 折算回设计字号再取 95% 留余量。下限 1 而不是 5：槽位小到 5vp 以下时
        // 宁可字更小，也不要把 Column 撑破。
        final double scaled = MediaQuery.textScalerOf(context).scale(12);
        final double textScale = scaled <= 0 ? 1 : scaled / 12;
        final double fontSize = (slot / textScale * 0.95).clamp(1, 12);
        return SizedBox(
          width: widget.size.width,
          height: height,
          child: GestureDetector(
            // opaque：整条（含字形两侧的留白与字间空隙）都参与命中。默认的
            // deferToChild 只认字形本身，点偏一点就漏给下层，拖动也起不了手。
            behavior: HitTestBehavior.opaque,
            onTapDown: (TapDownDetails d) =>
                _selectAt(d.localPosition.dy, slot, force: true),
            // tap 也要有收尾：`onSelected` 是过程（落指即报），`onSelectEnd`
            // 是结果（抬手一次），两者并存调用方才会只订阅一个通道。
            onTapUp: (TapUpDetails _) => _selectEnd(),
            onVerticalDragUpdate: (DragUpdateDetails d) {
              _selectAt(d.localPosition.dy, slot);
              _updateMagnifier(d.globalPosition);
            },
              onVerticalDragStart: (DragStartDetails d) => _startDrag(d, slot),
            onVerticalDragEnd: (DragEndDetails _) => _finishDrag(),
            onVerticalDragCancel: _finishDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < count; i++)
                  SizedBox(
                    height: slot,
                    child: Center(child: _letter(theme, base, i, fontSize)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
