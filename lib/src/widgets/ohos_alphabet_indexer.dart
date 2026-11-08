import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_magnifier.dart';

/// 索引条的颜色与尺寸，取自参考文档 `ts-container-alphabet-indexer.md`
/// 的属性表默认值（这一层就是明文数值，不需要再下资源表）。
///
/// 注意 `selectedColor` / `popupColor` 是 **`0xFF007DFF`** 而不是本库主题的
/// `highlightColor`（0xFF0A59F7）：官方在索引条上钉了一个固定的蓝，不跟随
/// 品牌色。这是少数「组件自带固定色」的地方，照抄比统一更忠实。
class OhosIndexerMetrics {
  const OhosIndexerMetrics._();

  /// 未选中项文本色（官方 `color` 默认 `0x99182431`）。
  static const Color textColor = Color(0x99182431);

  /// 选中项文本色（官方 `selectedColor` 默认 `0xFF007DFF`）。
  static const Color selectedColor = Color(0xFF007DFF);

  /// 选中项背景色（官方 `selectedBackgroundColor` 默认 `0x1A007DFF`）。
  static const Color selectedBackgroundColor = Color(0x1A007DFF);

  /// 提示气泡一级文本色（官方 `popupColor` 默认 `0xFF007DFF`）。
  static const Color popupColor = Color(0xFF007DFF);

  /// 索引项区域边长（官方 `itemSize` 默认 `16vp`）。
  ///
  /// 「索引项区域为正方形」，实际还受组件尺寸约束：宽不超过
  /// 组件宽 − 左右 padding，高不超过（组件高 − 上下 padding）/ 项数。
  static const double itemSize = 16;

  /// 组件默认 padding（文档正文：「`padding` 属性默认为 4vp」）。
  static const double padding = 4;
}

/// 索引条提示弹窗的对齐档（官方 `IndexerAlign` 4 个成员）。
///
/// 官方文档的措辞是「弹窗显示在索引条**右侧**」对应 `Left` —— 按**索引条
/// 本身**的物理位置命名，不是按弹窗的位置。这里的枚举照它的语义走，别按字面
/// 直觉反过来用。
enum OhosIndexerAlign {
  /// 弹窗在索引条右侧（官方 `Left`，值 0）。
  left,

  /// 弹窗在索引条左侧（官方 `Right`，值 1）。
  right,

  /// LTR 下在右侧、RTL 下在左侧（官方 `START`，值 2）。
  start,

  /// LTR 下在左侧、RTL 下在右侧（官方 `END`，值 3）——**官方默认档**。
  end,
}

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
    this.textColor,
    this.selectedColor,
    this.selectedBackgroundColor,
    this.alignStyle = OhosIndexerAlign.end,
    this.showPopupBubble = false,
    this.popupColor,
    this.itemSize,
    this.padding = const EdgeInsets.all(OhosIndexerMetrics.padding),
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

  /// 未选中字母的颜色（官方 `color`，默认 `0x99182431`）。
  final Color? textColor;

  /// 选中字母的颜色（官方 `selectedColor`，默认 `0xFF007DFF`）。
  ///
  /// 官方这一档是**固定蓝**，不跟随主题品牌色 —— 传 null 时取
  /// [OhosIndexerMetrics.selectedColor] 而不是主题的 `highlightColor`，
  /// 与官方一致。想让它跟随主题就显式传 `theme.highlightColor`。
  final Color? selectedColor;

  /// 选中字母的底色（官方 `selectedBackgroundColor`，默认 `0x1A007DFF`）。
  ///
  /// 老实现完全没有这一档 —— 索引条上「当前是哪个字母」只有颜色深浅的差别，
  /// 在浅色主题里对比度不够。官方给的是一个 10% 的蓝色圆角底。
  final Color? selectedBackgroundColor;

  /// 提示弹窗的对齐档（官方 `alignStyle`，默认 `IndexerAlign.END`）。
  ///
  /// 这一档官方只用来摆**提示弹窗**的位置，与索引条自身在屏幕的左右无关。
  /// 本库把它用在两处：气泡/放大镜的落点方向，以及选中底色的圆角朝向
  /// （贴着屏幕边缘那一侧的角不圆）。
  final OhosIndexerAlign alignStyle;

  /// 是否显示官方的「提示弹窗气泡」（官方 `usingPopup`，默认 `false`）。
  ///
  /// 与 [showMagnifier] 的关系：两者都是「手指旁边出现一个放大/提示的泡泡」，
  /// 但官方索引条的气泡是**矩形文字块**（`popupColor` 蓝字、`popupBackground`
  /// 浅底、可显示二级索引），放大镜是**圆形内容投影**。`showPopupBubble`
  /// 优先：开了它就按官方气泡造型画，否则退回放大镜。
  final bool showPopupBubble;

  /// 气泡文字颜色（官方 `popupColor`，默认 `0xFF007DFF`）。
  final Color? popupColor;

  /// 索引项区域边长（官方 `itemSize`，默认 16vp）。
  ///
  /// 实际是**上限**：高度方向还要被「可用高 / 项数」夹一次，否则 26 个字母
  /// 在 360vp 高的条上每格只有 13vp。宽度方向夹到「条宽 − 左右 padding」。
  final double? itemSize;

  /// 索引条内边距（官方默认 4vp）。
  final EdgeInsets padding;

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
    final int count = widget.indexer.length;
    // 拖动中先不理会外部值：手指的即时高亮优先，否则父级一 setState 就会把
    // 高亮从指下拽回旧位置。抬手后的下一次重建再对齐受控值。
    if (!_dragging) {
      _syncSelected(widget.selectedIndex, oldWidget.selectedIndex);
      // 受控语义：外部值没变也要回写 —— 拖动 / 点击会改内部 [_current]，父级
      // 用同一个 `selectedIndex` 重建时得能把高亮纠回受控值，否则「受控」只在
      // 外部值变化的那一刻成立。
      final int? controlled = widget.selectedIndex;
      if (controlled != null && count > 0) {
        _current = controlled.clamp(0, count - 1);
      }
    }
    // 字母表可能在运行中变短（切换分组 / 数据刷新）：上面只在外部
    // `selectedIndex` 变化时才重算，父级换了个更短的 `indexer` 而
    // `selectedIndex` 没变时 `_current` 会停在旧位置 —— 高亮错位、命中错格，
    // 而三个回调都拿它当 `indexer` 的下标。拖动中同样要夹，否则抬手就越界。
    if (count > 0 && _current >= count) {
      _current = count - 1;
    }
  }

  void _syncSelected(int? selected, int? previous) {
    if (selected == null || selected == previous) {
      return;
    }
    final int count = widget.indexer.length;
    // 空字母表没有合法下标可指：此处只归零，不参与越界断言 —— 否则
    // 「先给了 selectedIndex、随后分组切换把 indexer 清空」会在 debug 下崩。
    if (count == 0) {
      _current = 0;
      return;
    }
    assert(
      selected >= 0 && selected < count,
      'selectedIndex $selected 超出 0..${count - 1}',
    );
    _current = selected.clamp(0, count - 1);
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
    // 先报结果：调用方要的是「手指最后停在哪」，此刻 [_current] 还是指下那个字母。
    _selectEnd();
    // 拖动期间刻意挂起了受控值（见 [didUpdateWidget]），抬手时自己补回来 ——
    // 父级在拖动中改过 `selectedIndex` 未必会再来一次重建。
    _applyControlled();
  }

  /// 把外部 `selectedIndex` 回写到内部高亮。没有受控值、或字母表为空时不动。
  ///
  /// 与 [_syncSelected] 的分工：[didUpdateWidget] 里那样「值变了才处理」的场合
  /// 走前者（带越界断言），这里是「无条件对齐」——外部值没变、但内部被手势改过，
  /// 仍然要回到受控值。
  void _applyControlled() {
    final int? controlled = widget.selectedIndex;
    if (controlled == null) {
      return;
    }
    final int count = widget.indexer.length;
    if (count == 0) {
      return;
    }
    final int target = controlled.clamp(0, count - 1);
    if (target != _current) {
      setState(() => _current = target);
    }
  }

  Widget _letter(
    OhosThemeData theme,
    TextStyle base,
    int index,
    double fontSize,
    double dot,
  ) {
    // 只读内部状态：受控值已经在 initState / didUpdateWidget 里回写过了，
    // 所以"外部定位"与"手指拖动"共用一条绘制路径。
    final bool on = index == _current;
    // 默认取主题色而不是官方那对固定值（`0x99182431` / `0xFF007DFF`）：
    // 本库的组件颜色统一由 `OhosThemeData` 负责，深色与墨屏都靠它换值。
    // 写死官方蓝的话，墨屏上这条蓝既不会被 `quantize` 成灰阶，也没法跟
    // 「当前主题的品牌色」对齐。要严格对齐官方外观就显式传
    // `textColor: OhosIndexerMetrics.textColor` 与
    // `selectedColor: OhosIndexerMetrics.selectedColor`。
    final Color idle = widget.textColor ?? theme.textSecondaryColor;
    final Color active = widget.selectedColor ?? theme.highlightColor;
    // 选中底色：官方 `selectedBackgroundColor`。
    //
    // 这里**不能**写 `policy.isMonochrome ? 实线 : 10% 叠色` —— 那样一来「加
    // 一块屏」又得回来改组件（`system_theme_test` 明令禁止）。问策略真正管
    // 的事：「这个颜色能否在你那块屏上原样表达」。彩屏 `quantize` 原样返回、
    // 10% 的蓝就是 10% 的蓝；灰阶屏必须合成到纸面并去饱和，必然不等 —— 那时
    // 才换成 `line` 的实色把选区托住（10% 落在第 0–3 级灰、与白底不可分）。
    final Color highlightBackground =
        widget.selectedBackgroundColor ??
        theme.highlightColor.withValues(alpha: 0.1);
    // 这块屏能不能原样表达那层 10% 叠色？彩屏能（`quantize` 原样返回），灰阶屏
    // 不能（必须先合成到纸面再取灰，必然不等）。不能时改用实色底把选区托住。
    //
    // 但**实底必须配反白字**：墨屏预设里 `highlightColor` 与 `textPrimaryColor`
    // 都是 `inkForeground`（纯黑），实底 + 同色字会糊成一团黑块，连是哪个字母
    // 都看不出来（issue #7）。反白色不自己拼，用主题的 `onHighlightColor` ——
    // 白纸墨屏是 `inkBackground`，深色墨屏是 `inkBackgroundDark`。
    final bool solidFill =
        theme.policy.quantize(highlightBackground) != highlightBackground;
    final Color selectedFill = solidFill
        ? theme.policy.line(theme.textPrimaryColor, 1)
        : highlightBackground;
    final Color selectedText = solidFill ? theme.onHighlightColor : active;
    // 字号不作隐式动画：容器高度是立即变的，字号若走 200ms 过渡，拖动期间
    // 每一帧都偏大，字母会互相压住（0.3.0 里直接 `RenderFlex overflowed`）。
    final Widget content = DefaultTextStyle(
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
        color: on ? selectedText : idle,
        fontWeight: on ? FontWeight.w600 : FontWeight.w400,
      ),
      child: Text(widget.indexer[index]),
    );
    if (!on) {
      return content;
    }
    // 选中底色：**等径正圆**，直径由 `dot` 给定、圆心就是格子中心。
    //
    // 早先只圆左侧、右侧留直角，高度还跟着字形收缩，结果底块的重心偏左偏上，
    // 跟字母对不上圆心（看着像贴在字母左上角的一块墨）。改成正方形 + 半径
    // 取直径一半就是正圆；直径不再跟着字宽走，宽窄字母的圆一样大，滚动时
    // 那点亮色不会忽胖忽瘦。
    return Center(
      child: SizedBox(
        width: dot,
        height: dot,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selectedFill,
            borderRadius: BorderRadius.all(Radius.circular(dot / 2)),
          ),
          child: Center(child: content),
        ),
      ),
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
        // 条高：以 size.height 为基准，父级约束优先 —— 可拖分隔条的面板会把可用
        // 高度压到 size.height 以下，按 size 算就会溢出；反过来父级把组件撑得比
        // size.height **更高**，只按 maxHeight 算会让字母挤在顶部、命中区却铺满
        // 整条（点空白跳末格）。`constrainHeight` 同时看 min 与 max，命中格与
        // 视觉格才重合；高度无界（`SingleChildScrollView` 里）时它会只吃
        // minHeight，这正是「scroll 里再套 ConstrainedBox(minHeight)」的场景，
        // 那时 hasBoundedHeight 为 false，绕过约束就会退回 size.height 而错位。
        final double height = constraints.constrainHeight(widget.size.height);
        if (count == 0 || height <= 0) {
          return SizedBox(width: widget.size.width, height: 0);
        }
        // 唯一来源：布局、字号、命中都用这个 slot，不再有第二套几何。
        //
        // [OhosAlphabetIndexer.itemSize] 给了就把每格锁成那个正方形的边长，
        // 没给就按可用高平摊 —— 后者是 0.3.0 起的既有行为（父级压高度时整条
        // 跟着缩）。官方 `itemSize` 的默认 16vp 是**组件默认**，本库不把它当
        // 默认值，是因为索引条在真机上永远被放在一个刚好够高的容器里，
        // 锁死 16 会让「5 个字母、160vp 高」的条只画 80vp 高、下面留白。
        // 想严格对齐官方方形索引项：传 `itemSize: OhosIndexerMetrics.itemSize`。
        final double? cap = widget.itemSize;
        final double slot = cap == null
            ? height / count
            : math.min(cap <= 0 ? height / count : cap, height / count);
        // 字号按槽位高度摊分：索引条高度小于 letters × 12vp 时（手机竖屏）
        // 原来 26 个字母会撑破 Column，出斑马线。系统字体放大（如 Mate 60 Pro
        // 默认 1.15）会把文字等比撑高，只按 vp 摊分还会溢出 27px —— 先把缩放
        // 折算回设计字号再取 95% 留余量。下限 1 而不是 5：槽位小到 5vp 以下时
        // 宁可字更小，也不要把 Column 撑破。
        final double scaled = MediaQuery.textScalerOf(context).scale(12);
        final double textScale = scaled <= 0 ? 1 : scaled / 12;
        final double fontSize = (slot / textScale * 0.95).clamp(1, 12);
        // 选中圆标的直径：与格子同高；条本身比格子窄时（5 个字母、160vp 高的
        // 条，slot 会到 32vp）收到条宽，免得圆被左右裁掉。
        final double dot = math.min(slot, widget.size.width);
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
                    child: Center(
                      child: _letter(theme, base, i, fontSize, dot),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
