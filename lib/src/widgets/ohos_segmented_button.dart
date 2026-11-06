import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';

/// 官方 `SegmentButton` 的两种形态，对应 `SegmentButtonOptions.tab()` /
/// `.capsule()`。
enum OhosSegmentType {
  /// 页签型：只有文本、白背板、**强制单选**。
  ///
  /// 官方的 `TabSegmentButtonConstructionOptions.buttons` 类型是
  /// `ItemRestriction<SegmentButtonTextItem>` —— 类型层面就没有图标字段，
  /// 所以 [OhosSegment.icon] 在 tab 型下**不渲染**（见 [OhosSegmentedButton]）。
  tab,

  /// 胶囊型：可带图标 / 图标 + 文本，选中项是一块品牌色药丸。
  ///
  /// 这是唯一支持 `multiply` 多选的形态 —— 官方在构造器里把 `this.multiply`
  /// 写在 `if (this.type === 'capsule')` 分支内，tab 型永远拿不到它。
  capsule,
}

/// Option model of an [OhosSegmentedButton].
class OhosSegment<T> {
  const OhosSegment({
    required this.label,
    required this.value,
    this.icon,
    this.selectedIcon,
  });

  /// Segment label.
  final String label;

  /// Value reported on selection.
  final T value;

  /// Leading icon. Ignored when the control is [OhosSegmentType.tab].
  final IconData? icon;

  /// Icon shown when the segment is selected.
  ///
  /// Two **distinct glyphs**, not one glyph recoloured — same rule as
  /// `Chip.selectedIcon` and `SegmentButtonIconItem.selectedIcon`. Falls back to
  /// [icon] when null.
  final IconData? selectedIcon;
}

/// A segmented control (分段按钮 in the HarmonyOS guideline).
///
/// 两种形态由 [type] 决定，规格全部取自 `segmentbutton.ets` 的
/// `segmentButtonTheme` 与文档《SegmentButton》：
///
/// | 项 | 值 | 依据 |
/// | --- | --- | --- |
/// | 按钮数量 | **2–5**（`MIN_ITEM_COUNT` / `MAX_ITEM_COUNT`） | 源码常量 + `ItemRestriction` 元组 |
/// | 最小高度 | **28** | `segment_button_height` |
/// | 基底内边距 | **2**（多选时 **0**） | `segment_button_baseplate_padding` |
/// | 文字水平内边距 | **8** | `segment_button_text_l_r_padding` |
/// | 文字垂直内边距 | **4**；图标 + 文本时 **6** | `segment_button_text_u_d_padding` / `..._capsule_u_d_padding` |
/// | 段间距 | **1** | `Row({ space: 1 })` |
/// | 图标 | **24**，与文字间距 **2** | 文档默认 `imageSize` + `Column({ space: 2 })` |
/// | 字号 | **14fp**（选中不放大） | `ohos_id_text_size_body2` |
/// | 字重 | 未选中 **w400**、选中 **w500** | `segment_button_unselected_font_weight` / `FontWeight.Medium` |
/// | 圆角 | 单选每段与容器都是胶囊；多选只有首末段外侧圆 | `calculateBorderRadius()` |
/// | 描边 | **0** | `segment_button_border_width` |
///
/// 三处**有意偏离**：
///
/// 1. **选中态是逐段淡入淡出，不是浮层滑动。** 官方单选模式用一个独立的
///    `SelectItem` 浮层跟着 `selectedIndexes[0]` 平移（spring 动画）。改成逐段
///    上色后，「A 变亮 / B 变暗」的信息量一样，但少了「从哪滑到哪」的方向感。
///    在多选（官方同样是逐段上色）与单选之间统一实现，是为了让两套语义的
///    视觉规则一致 —— 否则同一控件在 `multiply` 一开一关时换了一套动画。
/// 2. **tab 型不渲染图标。** 官方类型上就没有这个字段，给了也画不出来；这里
///    忽略而非 assert，理由与 `OhosChip` 的前缀图标回落相同 —— 一个字段在
///    两种形态下都能传，只在其中一种生效，比拒绝调用更符合「形态是参数组合
///    的结果」这个事实。
/// 3. **[height] 默认 `null`（自适应，最小 28）**，旧版写死 40。40 是自拟值，
///    官方只给 `minHeight`，内容撑多高就多高。要固定高度仍可显式传。
class OhosSegmentedButton<T> extends StatelessWidget {
  // 不能是 const：`assert` 要读 `segments.length`，而隐式 const 上下文里
  // 属性访问不是常量表达式。少了这个 assert，「只传 1 个」会画出一个只有一格
  // 的分段控件 —— 而官方在类型层面就不允许（`ItemRestriction` 元组至少 2 项）。
  // ignore: prefer_const_constructors_in_immutables
  OhosSegmentedButton({
    super.key,
    required this.segments,
    this.type = OhosSegmentType.capsule,
    this.selected,
    this.onSelected,
    this.selectedValues,
    this.onSelectionChanged,
    this.multiply = false,
    this.enabled = true,
    this.height,
  }) : assert(
         segments.length >= _minItems && segments.length <= _maxItems,
         '分段按钮只支持 $_minItems–$_maxItems 个按钮（官方 '
         'MIN_ITEM_COUNT / MAX_ITEM_COUNT），当前 ${segments.length} 个。'
         '「超过 5 项静默截断」比「当场报错」更坏：调用方会看到第 6 项凭空'
         '消失，而没有任何提示。官方在类型层面就是 5 项元组，超出的根本传不进',
       );

  static const int _minItems = 2;
  static const int _maxItems = 5;

  /// Segments of the control.
  final List<OhosSegment<T>> segments;

  /// Which of the two official forms to draw.
  final OhosSegmentType type;

  /// 单选时的当前值。多选模式下忽略，改用 [selectedValues]。
  final T? selected;

  /// 单选时点击某段回调。多选模式下忽略，改用 [onSelectionChanged]。
  final ValueChanged<T>? onSelected;

  /// 多选时的当前集合。为 null 时视为空集。
  final Set<T>? selectedValues;

  /// 多选时点击某段回调，参数是**变更后的完整集合**。
  ///
  /// 给完整集合而不是单个值：多选的意义就是「现在一共选了哪些」，让调用方
  /// 自己维护增删等于把状态机复制一份到每个使用点。
  final ValueChanged<Set<T>>? onSelectionChanged;

  /// 是否可多选。**只在 [OhosSegmentType.capsule] 下生效** —— tab 型强制单选
  /// 是官方行为（`multiply` 只在 capsule 构造分支里被读取）。
  final bool multiply;

  /// When false the control is disabled.
  final bool enabled;

  /// 固定高度。null 表示按官方自适应（`constraintSize({minHeight: 28})`）。
  final double? height;

  /// 是否走多选语义。
  bool get isMultiple => type == OhosSegmentType.capsule && multiply;

  /// 面板内边距：多选时官方把它归零（`componentPadding = multiply ? 0 : 2`）。
  ///
  /// 原因不是省地方 —— 多选时每一段本身就是一块独立底板，段与段之间已经由
  /// `Row(space: 1)` 分隔，再加 2 的内边距会让两端的段缩进去、与轨道外沿
  /// 对不齐。
  double get _baseplatePadding => isMultiple ? 0 : 2;

  /// 当前选中集合，单选与多选统一成一种形状。
  Set<T> get _currentSelection {
    if (isMultiple) {
      return selectedValues ?? const <Never>{};
    }
    final T? single = selected;
    return single == null ? const <Never>{} : <T>{single};
  }

  /// 段内垂直内边距：图标 + 文本形态是 6，其余 4。
  double get _itemVerticalPadding =>
      type == OhosSegmentType.capsule && _showsIcons && _showsText ? 6 : 4;

  /// tab 型只有文本（官方类型上没有图标字段）。
  bool get _showsIcons =>
      type == OhosSegmentType.capsule &&
      segments.any((OhosSegment<T> s) => s.icon != null);

  bool get _showsText => segments.any((OhosSegment<T> s) => s.label.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    // 正常路径下走不到这里：构造期 assert 已经挡住了 < 2 与 > 5。留这条兜底
    // 是为了 release 构建 —— Flutter 在 release 下**不执行 assert**，那时
    // 「只传 1 个」会真的进来，画一个只有一格的分段控件比什么都不画更像坏掉。
    // 对应官方 `if (this.optionsArray.length > 1)`。
    if (segments.length < _minItems) {
      return const SizedBox.shrink();
    }
    final OhosThemeData theme = OhosTheme.of(context);
    final OhosVisualPolicy policy = theme.policy;
    final Set<T> selection = _currentSelection;

    final Widget row = Row(
      // 官方 `Row({ space: 1 })`：段与段之间留 1vp，让相邻两段的圆角各自
      // 成立。留 0 的话两个 999 半径的圆角会贴在一起，接缝处出现一道
      // 凭空生成的「沙漏」暗线。
      spacing: 1,
      children: <Widget>[
        for (int i = 0; i < segments.length; i++)
          Expanded(
            child: _SegmentTapTarget(
              enabled: enabled,
              onTap: () => _handleTap(segments[i].value),
              child: _segmentBody(
                context: context,
                theme: theme,
                policy: policy,
                segment: segments[i],
                index: i,
                count: segments.length,
                isSelected: selection.contains(segments[i].value),
              ),
            ),
          ),
      ],
    );

    final Widget baseplate = Container(
      // 官方 `borderWidth(segment_button_border_width)` = 0，描边只在本库的
      // 墨水屏策略下补（见 _segmentBody 的说明）。
      padding: EdgeInsets.all(_baseplatePadding),
      decoration: BoxDecoration(
        color: policy.tint(theme.textPrimaryColor, 0.06),
        borderRadius: BorderRadius.circular(OhosGeometry.radiusCapsule),
        border: theme.usesOutlines
            ? Border.fromBorderSide(
                ohosBorderSide(
                  context,
                  theme.dividerColor,
                  width: theme.outlineWidth,
                ),
              )
            : null,
      ),
      child: row,
    );

    return height == null
        ? ConstrainedBox(
            // 官方 `constraintSize({ minHeight: segment_button_height })` = 28。
            // 用 minHeight 而不是固定高：图标 + 文本形态自然要 57 左右，钉死
            // 28 会把它们压扁。
            constraints: const BoxConstraints(minHeight: 28),
            child: baseplate,
          )
        : SizedBox(height: height, child: baseplate);
  }

  void _handleTap(T value) {
    if (!enabled) {
      return;
    }
    if (isMultiple) {
      final Set<T> next = <T>{..._currentSelection};
      // 多选是 toggle：再点一次取消。官方 `MultiSelectItemArray.onSelectedChange`
      // 也是这个语义 —— 点已选项会把它移出 selectedIndexes。
      if (!next.remove(value)) {
        next.add(value);
      }
      onSelectionChanged?.call(next);
      return;
    }
    // 单选重复点已选项仍然回调：调用方可能靠它做「重新加载」，而官方也没有
    // 拦这种情况。
    onSelected?.call(value);
  }

  Widget _segmentBody({
    required BuildContext context,
    required OhosThemeData theme,
    required OhosVisualPolicy policy,
    required OhosSegment<T> segment,
    required int index,
    required int count,
    required bool isSelected,
  }) {
    final Color textColor = _textColor(theme: theme, isSelected: isSelected);
    final IconData? icon = isSelected
        ? (segment.selectedIcon ?? segment.icon)
        : segment.icon;

    return AnimatedContainer(
      duration: OhosGeometry.durationShort,
      curve: OhosGeometry.easeOut,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: _itemVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: _fillColor(theme: theme, isSelected: isSelected),
        borderRadius: _itemRadius(index: index, count: count),
        // 彩屏选中段靠色差浮起，墨屏色差不存在 —— 与基底一样补 1px 实线，
        // 否则「选中」只剩字重 w400 → w500 这一档差别，远看等于没有。
        border: theme.usesOutlines && isSelected
            ? Border.fromBorderSide(
                ohosBorderSide(
                  context,
                  theme.dividerColor,
                  width: theme.outlineWidth,
                ),
              )
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: <Widget>[
          if (_showsIcons && icon != null)
            Icon(icon, size: 24, color: textColor),
          if (_showsText)
            Text(
              segment.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.typography.labelMedium?.copyWith(
                fontSize: 14,
                color: textColor,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
        ],
      ),
    );
  }

  /// 选中段的底色。
  ///
  /// tab 型是**白色背板**（`segment_button_checked_foreground_color`），不是
  /// 品牌色 —— 页签靠「抬起来」表示当前项，不是靠染色；capsule 型才是品牌色
  /// 药丸（`ohos_id_color_emphasize`）。两者都用 `cardColor` / `highlightColor`
  /// 之外的第二条线索（字色）配合，所以墨屏上还得再加一条线。
  Color _fillColor({required OhosThemeData theme, required bool isSelected}) {
    if (!isSelected) {
      return Colors.transparent;
    }
    if (type == OhosSegmentType.tab) {
      return theme.cardColor;
    }
    // 墨屏上 highlightColor 与 textPrimaryColor 都是纯黑，实底 + 反白字才是
    // 稳的（见 OhosVisualPolicy.selectionMark 的文档）。这里不判 policy 类型，
    // 只判「选中项怎么表达」。
    return switch (theme.policy.selectionMark) {
      OhosSelectionMark.inverse => theme.highlightColor,
      OhosSelectionMark.tint || OhosSelectionMark.emphasis =>
        theme.emphasizeTertiaryColor ?? theme.highlightColor,
    };
  }

  Color _textColor({required OhosThemeData theme, required bool isSelected}) {
    if (!isSelected) {
      return theme.textSecondaryColor;
    }
    // tab 型：选中的字是主文本色（抬起的白背板上写黑字）。
    if (type == OhosSegmentType.tab) {
      return theme.textPrimaryColor;
    }
    // capsule 型：官方默认 `ohos_id_color_foreground_contrary` —— 在品牌底
    // 上的反白字。彩屏（浅色药丸）与墨屏（黑色药丸）都读同一个字段。
    return theme.onHighlightColor;
  }

  /// 单段圆角。
  ///
  /// 单选：每段都是胶囊（官方 `radius = height / 2`，用 999 让 Flutter 自己
  /// clamp 到一半高，省掉「自适应高度时算不出段高」这件事）。
  /// 多选：只有首段左侧、末段右侧圆，中间两段直角 —— 这样才能看出「它们
  /// 属于同一块底板」而不是三个各自独立的胶囊。
  BorderRadius _itemRadius({required int index, required int count}) {
    if (!isMultiple) {
      return BorderRadius.circular(OhosGeometry.radiusCapsule);
    }
    const Radius capsule = Radius.circular(OhosGeometry.radiusCapsule);
    return BorderRadius.only(
      topLeft: index == 0 ? capsule : Radius.zero,
      bottomLeft: index == 0 ? capsule : Radius.zero,
      topRight: index == count - 1 ? capsule : Radius.zero,
      bottomRight: index == count - 1 ? capsule : Radius.zero,
    );
  }
}

/// 单段的点击目标。
///
/// 单独抽出来是因为 [OhosSegmentedButton] 本身要能在**没有 Material 祖先**的
/// 场景下工作（嵌在 `Stack` / `CustomPaint` 里时并不保证有 `Material`），
/// 所以不用 `InkWell`，按策略自己画按压底色。
class _SegmentTapTarget extends StatefulWidget {
  const _SegmentTapTarget({
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_SegmentTapTarget> createState() => _SegmentTapTargetState();
}

class _SegmentTapTargetState extends State<_SegmentTapTarget> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // 灰阶屏上 `tint` 返回透明 —— 那一档的按压反馈由段的描边与位移承担，
    // 在这里再叠一块 20% 的灰既读不出「按下」也刷新慢。
    final Color overlay = theme.policy.tint(theme.textPrimaryColor, 0.06);
    final bool showsOverlay =
        _pressed && widget.enabled && overlay != Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      onTapDown: widget.enabled
          ? (TapDownDetails _) => _setPressed(true)
          : null,
      onTapUp: widget.enabled ? (TapUpDetails _) => _setPressed(false) : null,
      onTapCancel: widget.enabled ? () => _setPressed(false) : null,
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          widget.child,
          if (showsOverlay)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: overlay,
                    borderRadius: BorderRadius.circular(
                      OhosGeometry.radiusCapsule,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }
}