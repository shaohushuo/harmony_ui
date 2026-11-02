import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_icon_button.dart';

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
    this.borderRadius = OhosGeometry.radiusCapsule,
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
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: <Widget>[
                IconTheme.merge(
                  data: IconThemeData(
                    color: theme.textSecondaryColor,
                    size: 18,
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
                    // 空态占位与清空键同宽（32），否则空↔有字切换时输入区
                    // 会横向跳 20vp，长关键词末尾的字会抖一下。
                    return AnimatedSwitcher(
                      duration: OhosGeometry.durationShort,
                      child: value.text.isEmpty
                          ? const SizedBox(
                              width: 32,
                              key: ValueKey<String>('empty'),
                            )
                          : OhosIconButton(
                              key: const ValueKey<String>('clear'),
                              icon: const Icon(Icons.cancel_rounded, size: 16),
                              size: 32,
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
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
