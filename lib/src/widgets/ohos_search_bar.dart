import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_icon_button.dart';
import 'ohos_selection_toolbar.dart';

/// A capsule-shaped HarmonyOS search input, modeled after the ArkUI search
/// component. Includes an optional clear button and submit callback.
class OhosSearchBar extends StatefulWidget {
  const OhosSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = '搜索',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onCancel,
    this.cancelText = '取消',
    this.enabled = true,
    this.autofocus = false,
    this.height = 40,
    this.prefixIcon,
    this.borderRadius = OhosGeometry.radiusSearch,
    this.searchButtonText,
    this.autoDisable = false,
    this.selectionMenuItems = const <OhosSelectionMenuItem>[],
  });

  /// Controller for the search text.
  final TextEditingController? controller;

  /// External focus node, e.g. to focus the bar when the page opens.
  ///
  /// A supplied node is listened to but never disposed by the widget.
  final FocusNode? focusNode;

  /// Placeholder text.
  final String hintText;

  /// Called whenever the query changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user presses the search key.
  final ValueChanged<String>? onSubmitted;

  /// Called after the clear button empties the field.
  ///
  /// Fires in addition to `onChanged('')`, so a page that keeps its own query
  /// state can drop it here without watching [controller].
  final VoidCallback? onClear;

  /// ArkUI-style cancel action: shows a trailing "取消" while the field is
  /// focused, clears the text, unfocuses and calls this back.
  ///
  /// Null hides the button.
  final VoidCallback? onCancel;

  /// Label of the cancel button when [onCancel] is set.
  final String cancelText;

  /// When false the search bar is disabled.
  final bool enabled;

  /// Focus the field when the widget is first built.
  final bool autofocus;

  /// Logical height of the bar.
  final double height;

  /// Text of the trailing submit button (ArkUI `searchButton`).
  ///
  /// Null hides it. When present the bar draws the official trailing cluster:
  /// `… input | divider | SEARCH`. Geometry below is all token-backed —
  /// `search_button_space` = 2 (both the gap to the divider and the button's
  /// outer inset), `search_divider_side_space` = 2, 1px divider.
  ///
  /// **The bar does *not* grow to 56 here.** ArkUI has a
  /// `sys.float.search_height` = 56 token, and earlier notes in this repo
  /// claimed 56 was "the height with a search button". That is wrong on two
  /// counts: `search_height` is never read by the search implementation (it
  /// appears in none of the 13 `search/` sources; `SearchTheme::GetHeight()`
  /// resolves from `search_default_height` = 40 only), and every official
  /// sample that sets `searchButton` still writes `.height(40)`. Keeping
  /// [height] at 40 is the faithful behaviour.
  final String? searchButtonText;

  /// 扩展动作（翻译 / 分享 / 搜索 / 三方），显示在「更多」二级菜单里。
  ///
  /// 内置的剪切 / 复制 / 粘贴 / 全选与 [OhosTextField.selectionMenuItems]
  /// 走同一条实现，取舍理由也相同：前四项不进「更多」。
  final List<OhosSelectionMenuItem> selectionMenuItems;

  /// Grey out and disable [searchButtonText] while the field is empty.
  ///
  /// ArkUI `SearchButtonOptions.autoDisable` (API 18+), **default `false`** —
  /// matching the official documentation rather than assuming the friendlier
  /// behaviour: an out-of-the-box `Search` lets you tap an empty "Search"
  /// button, and the app decides what that means.
  ///
  /// Only affects the trailing button. [enabled] still disables the whole bar.
  final bool autoDisable;

  /// Overrides the leading search icon.
  final Widget? prefixIcon;

  /// Corner radius of the capsule.
  final double borderRadius;

  @override
  State<OhosSearchBar> createState() => _OhosSearchBarState();
}

class _OhosSearchBarState extends State<OhosSearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  /// 只有自己创建的实例才由本组件 dispose，外部传入的归调用方所有。
  bool _ownsController = false;
  bool _ownsFocusNode = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _useController(widget.controller);
    _useFocusNode(widget.focusNode);
  }

  void _useController(TextEditingController? controller) {
    _controller = controller ?? TextEditingController();
    _ownsController = controller == null;
  }

  void _useFocusNode(FocusNode? focusNode) {
    _focusNode = focusNode ?? FocusNode();
    _ownsFocusNode = focusNode == null;
    _focusNode.addListener(_onFocus);
    // 新节点可能已经处于聚焦态：不同步的话「取消」按钮要等下一次焦点变化
    // 才出现（旧节点聚焦时换到未聚焦节点则恰好相反，一直挂着）。
    _focused = _focusNode.hasFocus;
  }

  void _releaseFocusNode() {
    _focusNode.removeListener(_onFocus);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
  }

  void _onFocus() {
    if (mounted && _focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void didUpdateWidget(OhosSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (_ownsController) {
        _controller.dispose();
      }
      _useController(widget.controller);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      _releaseFocusNode();
      _useFocusNode(widget.focusNode);
    }
  }

  @override
  void dispose() {
    _releaseFocusNode();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleCancel() {
    _controller.clear();
    widget.onChanged?.call('');
    _focusNode.unfocus();
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return SizedBox(
      height: widget.height,
      child: Container(
        // 墨水屏：胶囊白底压在白页面上没有任何边界（`cardColor` 与
        // `backgroundColor` 同一色），补 1px 实线。
        //
        // 这条线不能交给 `Material.shape`：它在 1.5x 屏上会和子节点抢同一条
        // 边（下沿实测只剩 1 个设备像素，上沿却有 2 个），看着「下边框变细」。
        // 用 `foregroundDecoration` 单独画在最上层，四条边落在同一套几何上。
        foregroundDecoration: theme.usesOutlines
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: theme.dividerColor,
                  width: ohosStrokeWidth(context, theme.outlineWidth),
                ),
              )
            : null,
        child: Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Padding(
            // 官方把左侧留白交给 `search_icon_left_space`(=12)、把图标与文字的
            // 间距交给 `search_icon_right_space`(=8)，图标本身 16。这两条是
            // `search_layout_algorithm.cpp` 里 `LayoutSearchIcon` /
            // `LayoutTextField` 的真实几何：
            //   iconX   = padding.left + search_icon_left_space
            //   fieldX  = iconWidth + search_icon_left_space + search_icon_right_space
            //
            // 注意别把 `search_text_field_padding_left`(=4) 当成这里的 12 ——
            // 那个令牌在 NG 实现里只被 `SearchTheme::GetLeftPadding()` 读进
            // 字段、没有任何调用方，是旧框架的遗留。上一版文档据此把本库的
            // 12 判成「多 8」，那个判断是错的。
            // 右侧留白跟着形态走：有搜索按钮时是 `search_button_space`(=2)，
            // 对应 `LayoutSearchButton` 的 `frameW - buttonW - searchButtonSpace`；
            // 无按钮时交给清除按钮自己的 40 命中区，不再叠额外内边距
            // （否则空态占位 40 + 4 会让输入区比有字时更窄）。
            padding: EdgeInsets.only(
              left: 12,
              right: widget.searchButtonText != null ? 2 : 0,
            ),
            child: Row(
              children: <Widget>[
                IconTheme.merge(
                  data: IconThemeData(
                    color: theme.textSecondaryColor,
                    size: 16,
                  ),
                  child: widget.prefixIcon ?? const Icon(Icons.search_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    textInputAction: TextInputAction.search,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    style: theme.typography.bodyMedium?.copyWith(
                      color: theme.textPrimaryColor,
                    ),
                    contextMenuBuilder:
                        (BuildContext context, EditableTextState state) =>
                            OhosSelectionToolbar.editable(
                              context: context,
                              editableTextState: state,
                              items: widget.selectionMenuItems,
                            ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(color: theme.textTertiaryColor),
                      // 边框的六个状态槽位必须逐个钉成 none，只写 `border` 是不够的：
                      // `InputDecoration.applyDefaults` 用的是
                      // `enabledBorder ?? theme.enabledBorder`，装饰器自己的
                      // `border` 不会回填状态槽位；而 `_getBorder` 先按状态取槽位，
                      // 取到了就直接用，压根走不到读 `border` 那一步。
                      //
                      // 于是宿主只要给 Material 的 `inputDecorationTheme` 配过
                      // `enabledBorder`（墨水屏上很常见 —— 没有填充色可用，只能靠
                      // 1px 描边给输入框分层），胶囊里就会再套一圈圆角框。
                      // 外层胶囊已经在 `foregroundDecoration` 里自己画了 1px 边，
                      // 内层永远不该再画。
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      // 同一个 `applyDefaults` 还会把宿主的 `filled: true` 带进来，
                      // 在胶囊里多出一块填充矩形。搜索框没有填充语义，显式关掉。
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (BuildContext context, TextEditingValue value, _) {
                    // 空态占位与清空键同宽（40），否则空↔有字切换时输入区
                    // 会横向跳 24vp，长关键词末尾的字会抖一下。
                    //
                    // 40 不是随手取的整数：官方 `search_close_icon_hot_zone_horizontal`
                    // 就是 40vp，这是手指够得着的下限。原来是 32，真机上偏窄
                    // 到「点两次才中一次」。
                    return AnimatedSwitcher(
                      duration: OhosGeometry.durationShort,
                      child: value.text.isEmpty
                          ? const SizedBox(
                              width: 40,
                              key: ValueKey<String>('empty'),
                            )
                          : OhosIconButton(
                              key: const ValueKey<String>('clear'),
                              icon: const Icon(Icons.cancel_rounded, size: 16),
                              size: 40,
                              iconSize: 16,
                              color: theme.textTertiaryColor,
                              onPressed: () {
                                _controller.clear();
                                widget.onChanged?.call('');
                                widget.onClear?.call();
                              },
                            ),
                    );
                  },
                ),
                if (_focused && widget.onCancel != null)
                  // 取消是「按钮」而不是一块可点区域：TextButton 自带 button 语义、
                  // 焦点与回车/空格激活，命中区也够 40vp（裸 GestureDetector 三者都没有）。
                  TextButton(
                    onPressed: _handleCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.highlightColor,
                      textStyle:
                          theme.typography.bodyMedium ??
                          const TextStyle(fontSize: 15),
                      // 命中区至少 48×40：`visualDensity` 不压（compact 会再砍 8vp，
                      // 高 40 的栏里就只剩 32 了），`shrinkWrap` 则是不额外加水波纹余量。
                      minimumSize: const Size(48, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.standard,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      // 不做水波纹的主题：点按时不要半透明灰块
                      overlayColor: theme.policy.allowsRipple
                          ? null
                          : Colors.transparent,
                    ),
                    child: Text(widget.cancelText),
                  ),
                // 右侧搜索按钮形态（ArkUI `searchButton`）。几何全部来自令牌：
                //   `search_button_space` = 2  —— 分隔线两侧、以及按钮到右边界
                //   `search_divider_side_space` = 2 —— 与前者同值，但语义不同
                //   `search_divider_width` = 1px
                //
                // 顺序是「清除 | 2 | 分隔线 | 2 | 按钮 | 2」，对应
                // `search_layout_algorithm.cpp` 的三个偏移：
                //   buttonX  = frameW - buttonW - searchButtonSpace
                //   dividerX = frameW - buttonW - dividerSpace - space - dividerW/2
                //   cancelX  = buttonX - cancelW - 2*dividerSpace - dividerW
                // 也就是说清除按钮落在分隔线**左侧**，不是和按钮并排。
                if (widget.searchButtonText != null) ...<Widget>[
                  const SizedBox(width: 2),
                  SizedBox(
                    // 高度取 `search_icon_height`(16)，但夹在栏高内 —— 官方
                    // `DividerMeasure` 就是 `min(searchHeight, iconHeight)`，
                    // 栏高只有 40 时这条线不该顶到上下边框。
                    height: 16,
                    child: VerticalDivider(
                      width: 1,
                      thickness: ohosStrokeWidth(context, 1),
                      color: theme.dividerColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  // `autoDisable` 要看**当时**的输入内容，而外层已经在
                  // `ValueListenableBuilder` 里包住了清除按钮；搜索按钮在它
                  // 之后，拿到的是同一次构建的 controller 值 —— 这里另起一层
                  // 监听而不是把 button 挪进上面那层，是因为两者中间隔着分隔线，
                  // 挪进去会让分隔线也跟着抖。
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (
                      BuildContext context,
                      TextEditingValue value,
                      _,
                    ) {
                      // 只有开了 autoDisable 且确实为空才置灰；`enabled: false`
                      // （整栏禁用）优先，两者对按钮的效果都是不可点 + 灰字。
                      final bool empty =
                          widget.autoDisable && value.text.isEmpty;
                      final bool canSubmit = widget.enabled && !empty;
                      return TextButton(
                        onPressed: canSubmit
                            ? () => widget.onSubmitted?.call(_controller.text)
                            : null,
                        style: TextButton.styleFrom(
                          // 官方 `autoDisable` 的表述是「置灰且不可点击」。
                          // 灰取 `textTertiaryColor`：彩屏上是从品牌蓝降一档，
                          // 墨屏上是 0x767676 的中灰 —— 两者都落在能读出
                          // 「这字还在、但点不动」的区间，没有引入新色值。
                          foregroundColor: canSubmit
                              ? theme.highlightColor
                              : theme.textTertiaryColor,
                          // 官方默认 `fontSize: '16fp'`，但那是 `SearchButtonOptions`
                          // 的文档兜底值；真正生效的是 `search_font_size_API16`
                          // → `Body_M` = 14fp（theme 里 API18 起覆盖）。
                          textStyle: const TextStyle(fontSize: 14),
                      // `search_button_text_padding` = 14 —— 文字的左右内边距。
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          // 按钮高 = 栏高 - 2*searchButtonSpace，即 40 - 4 = 36。
                          // 用 fixedSize 而不是 minimumSize，是因为官方连字号放大
                          // 后也夹在 `searchHeight_` 内（`std::min(..., searchHeight_)`）。
                          minimumSize: Size(0, widget.height - 4),
                          fixedSize: Size.fromHeight(widget.height - 4),
                          visualDensity: VisualDensity.standard,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          overlayColor: theme.policy.allowsRipple
                              ? null
                              : Colors.transparent,
                        ),
                        child: Text(widget.searchButtonText!),
                      );
                    },
                  ),
                  // 按钮右边 2vp 内外都要留（官方 `rightOffset + searchButtonSpace`）。
                  // 这个留白由外层 Padding 统一给，见下面 `_rightInset`。
                ] else
                  const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
