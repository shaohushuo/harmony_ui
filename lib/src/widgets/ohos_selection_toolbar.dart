import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_light_material.dart';
import 'ohos_menu.dart';

/// 内置选择菜单动作的固定顺序，取自设计规范：
/// 剪切 → 复制 → 粘贴 → 全选 → 翻译 → 分享 → 搜索 → 其他。
///
/// **前四项不进「更多」，扩展项全部进「更多」。** 这条不是排版偏好：前四项是
/// 读者对「选中一段字」这一动作的条件反射，藏进二级菜单会让最常见的操作多
/// 一次点击；扩展项（翻译 / 分享 / 搜索 / 三方动作）是「对选中的内容再做点
/// 什么」，本来就该先看一眼有什么。
enum OhosSelectionMenuAction {
  /// 剪切。无选区时禁用。
  cut,

  /// 复制。无选区时禁用。
  copy,

  /// 粘贴。剪贴板为空时禁用。
  paste,

  /// 全选。
  selectAll,

  /// 翻译（扩展项）。
  translate,

  /// 分享（扩展项）。
  share,

  /// 搜索（扩展项）。
  search,

  /// 三方扩展动作（扩展项）。
  more,
}

/// 一项自定义菜单动作。
///
/// 与 `ExpandedMenuOptions`（`MenuItemOptions` + `action`）对应。用 id 而不是
/// 回调本身做相等判断的键：同一个动作在不同重建里是不同的闭包实例，按回调
/// 比较会让每次 `setState` 都判成「变了」。
@immutable
class OhosSelectionMenuItem {
  const OhosSelectionMenuItem({
    required this.id,
    required this.label,
    this.icon,
    this.onSelected,
  });

  /// Stable identity, used for equality and for tests.
  final String id;

  /// Menu label.
  final String label;

  /// Leading icon.
  ///
  /// `IconData` rather than a `Widget`, matching [OhosMenuItem]: these items are
  /// rendered by [showOhosMenu] inside the「更多」sub-menu, and that path can
  /// only draw icon fonts. Accepting a widget here would mean the icon silently
  /// disappears for exactly the items that need the sub-menu most.
  final IconData? icon;

  /// Called when the item is tapped. A null callback renders the item
  /// disabled instead of hiding it — same as ArkUI, where an item with neither
  /// `action` nor `builder` is drawn but not tappable.
  final VoidCallback? onSelected;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OhosSelectionMenuItem && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'OhosSelectionMenuItem($id)';
}

/// 文本选择菜单（文本选择菜单 in the HarmonyOS guideline），ArkUI 的
/// `SelectionMenu` 在 Flutter 侧的对应物。
///
/// 两种用法：
///
/// 1. **接管 `TextField` 的右键 / 长按菜单** —— 传给 [OhosTextField] 或
///    [OhosSearchBar] 的 `contextMenuBuilder`：
///
///    ```dart
///    OhosTextField(
///      contextMenuBuilder: (BuildContext context, EditableTextState state) =>
///        OhosSelectionToolbar.editable(
///          context: context,
///          editableTextState: state,
///          items: <OhosSelectionMenuItem>[...],
///        ),
///    )
///    ```
///
/// 2. **独立使用** —— 需要自己摆位置时用 [OhosSelectionToolbar.anchored]。
///
/// 与前四项对不上的一点：Flutter 的 `TextSelectionToolbar` 在
/// `Theme.of(context).platform == iOS / macOS` 时会换用 Cupertino 的实现，
/// 那套装不了我们的容器。本组件固定用 `TextSelectionToolbar`，把
/// `platform` 临时覆盖成 `ohos`，这样三端渲染一致 —— 库的语义就是
/// HarmonyOS，不该在 iOS 上变成另一个样子。
class OhosSelectionToolbar extends StatelessWidget {
  const OhosSelectionToolbar._({
    required this.children,
    required this.anchorAbove,
    required this.anchorBelow,
  });

  /// 由 `EditableTextState` 接管的标准用法。
  ///
  /// [items] 是**扩展项**（翻译 / 分享 / 搜索 / 三方），内置的剪切 / 复制 /
  /// 粘贴 / 全选四项由本方法按 [showCut] 等开关与当前选区状态自动生成并固定
  /// 排在前面。
  factory OhosSelectionToolbar.editable({
    required BuildContext context,
    required EditableTextState editableTextState,
    List<OhosSelectionMenuItem> items = const <OhosSelectionMenuItem>[],
    bool showCut = true,
    bool showCopy = true,
    bool showPaste = true,
    bool showSelectAll = true,
  }) {
    final OhosThemeData theme = OhosTheme.of(context);
    final List<ContextMenuButtonItem> buttons = _builtInButtons(
      editableTextState: editableTextState,
      showCut: showCut,
      showCopy: showCopy,
      showPaste: showPaste,
      showSelectAll: showSelectAll,
    );
    return OhosSelectionToolbar._(
      anchorAbove: editableTextState.contextMenuAnchors.primaryAnchor,
      anchorBelow:
          editableTextState.contextMenuAnchors.secondaryAnchor ??
          editableTextState.contextMenuAnchors.primaryAnchor,
      children: <Widget>[
        ..._actionButtons(context, theme, buttons),
        if (items.isNotEmpty) _moreButton(context, editableTextState, items),
      ],
    );
  }

  /// 手动定位。两个锚点的含义同 `TextSelectionToolbar`：先试上方，
  /// 放不下就翻到下方。
  factory OhosSelectionToolbar.anchored({
    Key? key,
    required Offset anchorAbove,
    required Offset anchorBelow,
    required List<OhosSelectionMenuItem> items,
  }) {
    return OhosSelectionToolbar._(
      anchorAbove: anchorAbove,
      anchorBelow: anchorBelow,
      children: <Widget>[
        for (final OhosSelectionMenuItem item in items)
          _IconActionButton(
            label: item.label,
            icon: item.icon,
            onTap: item.onSelected,
          ),
      ],
    );
  }

  final Offset anchorAbove;
  final Offset anchorBelow;
  final List<Widget> children;

  /// 内置四项，按固定顺序生成，缺一不可补位 —— 不用一组 if 决定「谁是第一项」。
  static List<ContextMenuButtonItem> _builtInButtons({
    required EditableTextState editableTextState,
    required bool showCut,
    required bool showCopy,
    required bool showPaste,
    required bool showSelectAll,
  }) {
    final List<ContextMenuButtonItem> all = editableTextState.contextMenuButtonItems;
    ContextMenuButtonItem? pick(ContextMenuButtonType type) {
      for (final ContextMenuButtonItem item in all) {
        if (item.type == type) {
          return item;
        }
      }
      return null;
    }

    // 固定顺序：剪切 → 复制 → 粘贴 → 全选。不用「遍历 all 保序」——那等于把
    // 顺序交给框架，以后 Flutter 调整枚举顺序，这里会静默跟着变。
    final ContextMenuButtonItem? cut = showCut
        ? pick(ContextMenuButtonType.cut)
        : null;
    final ContextMenuButtonItem? copy = showCopy
        ? pick(ContextMenuButtonType.copy)
        : null;
    final ContextMenuButtonItem? paste = showPaste
        ? pick(ContextMenuButtonType.paste)
        : null;
    final ContextMenuButtonItem? selectAll = showSelectAll
        ? pick(ContextMenuButtonType.selectAll)
        : null;

    return <ContextMenuButtonItem>[
      if (cut != null) cut,
      if (copy != null) copy,
      if (paste != null) paste,
      if (selectAll != null) selectAll,
    ];
  }

  static List<Widget> _actionButtons(
    BuildContext context,
    OhosThemeData theme,
    List<ContextMenuButtonItem> buttons,
  ) {
    return <Widget>[
      for (final ContextMenuButtonItem button in buttons)
        _IconActionButton(
          label: _labelFor(button.type),
          icon: _iconFor(button.type),
          onTap: button.onPressed,
        ),
    ];
  }

  static Widget _moreButton(
    BuildContext context,
    EditableTextState editableTextState,
    List<OhosSelectionMenuItem> items,
  ) {
    return _IconActionButton(
      label: '更多',
      icon: Icons.more_horiz_rounded,
      onTap: () {
        // 收起系统菜单再弹自己的二级菜单：两个菜单同时浮着时，二级菜单会
        // 被系统菜单的入场动画盖住一半。
        editableTextState.hideToolbar();
        showOhosMenu<OhosSelectionMenuItem>(
          context: context,
          items: <OhosMenuItem<OhosSelectionMenuItem>>[
            for (final OhosSelectionMenuItem item in items)
              OhosMenuItem<OhosSelectionMenuItem>(
                label: item.label,
                icon: item.icon,
                value: item,
                enabled: item.onSelected != null,
              ),
          ],
          position: _menuRect(context, editableTextState),
        ).then((OhosSelectionMenuItem? picked) {
          picked?.onSelected?.call();
        });
      },
    );
  }

  /// 二级菜单的锚定矩形：贴在选择区上方。
  static RelativeRect _menuRect(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final Offset anchor = editableTextState.contextMenuAnchors.primaryAnchor;
    final Size screen = MediaQuery.sizeOf(context);
    return RelativeRect.fromLTRB(
      anchor.dx.clamp(8, screen.width - 8),
      // 与一级菜单同向：先往上排，顶部空间不够再由 `showMenu` 自行翻下去。
      anchor.dy - 8,
      (screen.width - anchor.dx).clamp(8, screen.width - 8),
      (screen.height - anchor.dy).clamp(8, screen.height - 8),
    );
  }

  /// 内置动作的文字。与 ArkUI 默认菜单一致（含快捷键提示的那几项只取动作名）。
  static String _labelFor(ContextMenuButtonType type) {
    switch (type) {
      case ContextMenuButtonType.cut:
        return '剪切';
      case ContextMenuButtonType.copy:
        return '复制';
      case ContextMenuButtonType.paste:
        return '粘贴';
      case ContextMenuButtonType.selectAll:
        return '全选';
      case ContextMenuButtonType.lookUp:
        return '查询';
      case ContextMenuButtonType.searchWeb:
        return '搜索';
      case ContextMenuButtonType.share:
        return '分享';
      case ContextMenuButtonType.liveTextInput:
        return '实况文本';
      case ContextMenuButtonType.delete:
        return '删除';
      case ContextMenuButtonType.custom:
        return '';
    }
  }

  /// 内置动作的图标。
  ///
  /// 用 Material 图标而不是 `harmony_icons`：后者只供 example 使用，`lib/`
  /// 不依赖任何图标包（这条约定见 CHANGELOG 的迁移说明）。语义对得上即可，
  /// 形状差异属于后续统一换图标包时一起处理的范围。
  static IconData? _iconFor(ContextMenuButtonType type) {
    switch (type) {
      case ContextMenuButtonType.cut:
        return Icons.content_cut_rounded;
      case ContextMenuButtonType.copy:
        return Icons.content_copy_rounded;
      case ContextMenuButtonType.paste:
        return Icons.content_paste_rounded;
      case ContextMenuButtonType.selectAll:
        return Icons.select_all_rounded;
      case ContextMenuButtonType.lookUp:
        return Icons.manage_search_rounded;
      case ContextMenuButtonType.searchWeb:
        return Icons.search_rounded;
      case ContextMenuButtonType.share:
        return Icons.ios_share_rounded;
      case ContextMenuButtonType.liveTextInput:
        return Icons.text_fields_rounded;
      case ContextMenuButtonType.delete:
        return Icons.delete_outline_rounded;
      case ContextMenuButtonType.custom:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Theme(
      // 见类注释：Cupertino 分支装不下我们的容器。
      data: Theme.of(context).copyWith(platform: TargetPlatform.ohos),
      child: TextSelectionToolbar(
        anchorAbove: anchorAbove,
        anchorBelow: anchorBelow,
        // 只有一项时也走 `children` 分支的横向容器，形状与多项一致。
        children: children,
        toolbarBuilder: (BuildContext context, Widget child) =>
            _OhosSelectionSurface(theme: theme, child: child),
      ),
    );
  }
}

/// 一级菜单的容器：40vp 方按钮横排、8vp 圆角、1vp 内外描边、默认开模糊。
///
/// 几何全部取自 `selectionmenu.ets` 的 `defaultTheme`：
/// `buttonSize` 40、`expandedOptionPadding` 4（即按钮间距 4，且容器内边距 = 4）、
/// `containerBorderRadius` = `corner_radius_level4` = 8、`imageSize` 24、
/// `menuSpacing` 8（菜单与锚点之间的距离）。
class _OhosSelectionSurface extends StatelessWidget {
  const _OhosSelectionSurface({required this.theme, required this.child});

  final OhosThemeData theme;
  final Widget child;

  static const double _radius = 8;
  static const double _padding = 4;

  @override
  Widget build(BuildContext context) {
    final Widget row = Padding(
      padding: const EdgeInsets.all(_padding),
      child: child,
    );
    // 官方默认 `iconPanelShadowStyle` = `ShadowStyle.OUTER_DEFAULT_SM`，底板
    // 走 `ohos_id_color_dialog_bg`（= 弹窗底色）；吹弹窗底色的同时叠一层
    // 模糊，才是「浮在正文之上」的观感。墨屏无模糊也无投影，改画 1px 实线。
    return Container(
      constraints: const BoxConstraints(minWidth: 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        border: Border.fromBorderSide(
          ohosBorderSide(context, theme.outlineColor, width: theme.outlineWidth),
        ),
      ),
      child: theme.policy.allowsBlur
          ? OhosLightMaterial(
              level: OhosLightMaterialLevel.thick,
              borderRadius: BorderRadius.circular(_radius),
              child: row,
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: theme.popupColor,
                borderRadius: BorderRadius.circular(_radius),
              ),
              child: row,
            ),
    );
  }
}

/// 单个 40×40 的动作按钮（图标 24，居中）。
class _IconActionButton extends StatefulWidget {
  const _IconActionButton({
    required this.label,
    this.icon,
    this.onTap,
  });

  /// 无障碍名称，也用作 `Semantics` 的 label。
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  State<_IconActionButton> createState() => _IconActionButtonState();
}

class _IconActionButtonState extends State<_IconActionButton> {
  static const double _size = 40;

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = widget.onTap != null;
    // 不用 `InkWell`：选择菜单活在 overlay 里，祖先没有 `Material`，
    // `InkWell` 会直接抛 "No Material widget found"。这里按策略自己画按压
    // 底色 —— 彩屏给一档浅色叠底，灰阶屏上 `tint` 返回透明，于是整块不画
    // （20% 的灰块既读不出「按下」也刷新慢，那正是策略要挡的东西）。
    final Color pressed = theme.policy.tint(
      theme.textPrimaryColor,
      0.06,
    );
    final Color? fill =
        _pressed && pressed != const Color(0x00000000) ? pressed : null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: enabled ? (TapDownDetails _) => _setPressed(true) : null,
        onTapUp: enabled ? (TapUpDetails _) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(OhosGeometry.radiusSmall),
          ),
          child: Center(
            child: IconTheme(
              data: IconThemeData(
                size: 24,
                color: enabled
                    ? theme.textPrimaryColor
                    : theme.policy.disabledFill(theme.textPrimaryColor),
              ),
              // 没有图标时给一个同尺寸空盒：`IconTheme.child` 不接受 null，
              // 而这类只画图标的按钮必须保持 40×40 的命中区。
              child: widget.icon == null
                  ? const SizedBox(width: 24, height: 24)
                  : Icon(widget.icon),
            ),
          ),
        ),
      ),
    );
  }

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }
}