import 'package:flutter/material.dart';

import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_button.dart';

/// 下拉菜单相对触发按钮的对齐方式，对应官方 `MenuAlignType`（API 10+）。
///
/// 官方默认 `START` ——「按照语言方向起始端对齐」。注意它说的是**菜单**对齐到
/// **按钮**的哪一侧，不是文字的对齐。
enum OhosSelectMenuAlign {
  /// 起始端对齐（官方默认）：菜单左边缘 = 按钮左边缘。
  start,

  /// 居中。
  center,

  /// 末端对齐：菜单右边缘 = 按钮右边缘。
  end,
}

/// 下拉按钮箭头位置，对应官方 `ArrowPosition`（API 10+）。
///
/// 官方默认 `END` ——「文字在前，箭头在后」。命名反直觉（`END` 是箭头在**后**，
/// 也就是视觉上的右侧），照官方原样保留，不改成 `trailing`：调用方搜文档时
/// 应该能对上词。
enum OhosSelectArrowPosition {
  /// 文字在前、箭头在后（官方默认）。
  end,

  /// 箭头在前、文字在后。
  start,
}

/// 下拉按钮的几何与菜单规格，取自 Select 参考文档与系统资源表。
class OhosSelectMetrics {
  const OhosSelectMetrics._();

  /// 按钮与菜单之间的间距（官方 `space`）。文档「默认值：8vp」，且
  /// 「设置为 ≤8 的值时取默认值」—— 也就是说 8 是下限而不是上限。
  static const double space = 8;

  /// 菜单最小宽度。资源表 `ohos_id_select_popup_min_width = 136vp`。
  static const double popupMinWidth = 136;

  /// 菜单圆角。资源表 `ohos_id_select_popup_rrect_size = 16vp`。
  static const double popupRadius = 16;

  /// 按钮自身圆角。资源表 `ohos_id_select_itself_rrect_size = 8vp`。
  static const double buttonRadius = 8;

  /// 选中项背景色的透明度。资源表 `ohos_id_alpha_highlight_bg = 0.2`
  /// （深色档 `ohos_id_alpha_highlight_bg_dark = 0.4`，由主题决定）。
  static const double selectedBackgroundAlpha = 0.2;

  /// 菜单项最小高度。资源表 `option_min_height = 48vp`。
  static const double optionMinHeight = 48;

  /// 分割线默认样式：`{strokeWidth: '1px', color: '#33182431'}`（文档原文）。
  static const double dividerWidthPx = 1;
  static const Color dividerColor = Color(0x33182431);
}

/// Option model of an [OhosSelect].
class OhosSelectOption<T> {
  const OhosSelectOption({required this.label, required this.value, this.icon});

  /// Display label.
  final String label;

  /// Value returned on selection.
  final T value;

  /// Optional leading icon.
  final IconData? icon;
}

/// A HarmonyOS dropdown select button (下拉按钮 in the guideline).
///
/// 官方 `Select` 有 35 属性，本库 0.5 只落了 6 个 —— 且**几乎每个视觉参数都
/// 不可配**。0.6 按文档逐条补齐配色、尺寸与对齐（数值出处见下表）。
///
/// | 项 | 值 | 依据 |
/// | --- | --- | --- |
/// | 按钮与菜单间距 | **8vp** | 文档 `space`，且 ≤8 取默认 |
/// | 菜单圆角 | **16vp** | 资源表 `ohos_id_select_popup_rrect_size` |
/// | 菜单最小宽 | **136vp** | 资源表 `ohos_id_select_popup_min_width` |
/// | 菜单项最小高 | **48vp** | 资源表 `option_min_height` |
/// | 选中项底色 | 品牌色 **20%** | 文档默认「activated 混 `ohos_id_alpha_highlight_bg = 0.2`」 |
/// | 选中项字色 | 品牌色 | 文档默认 `ohos_id_color_text_primary_activated` |
/// | 普通项字色 | 主文本色 | 文档默认 `ohos_id_color_text_primary` |
/// | 分割线 | `1px` / `#33182431` | 文档 `divider` 默认值 |
/// | 菜单对齐 | **START** | 文档 `menuAlign` 默认 `MenuAlignType.START` |
/// | 箭头位置 | **END** | 文档 `arrowPosition` 默认 `ArrowPosition.END` |
/// | 默认选中图标 | **不显示** | 文档 `showDefaultSelectedIcon` 默认 `false` |
///
/// 三处**有意偏离**：
///
/// 1. **[menuAlign] 是近似实现**。`showMenu` 的定位先于布局，拿不到菜单实际
///    宽度，只能用按钮宽度推左边缘。`start` 是精确的，`center` / `end` 会
///    偏半个菜单宽 —— 写成精确的对齐要绕开 `showMenu` 自己算，代价远大于
///    收益（官方这三个档位在真机上的差别也很小）。
/// 2. **分割线用 Flutter 的 `PopupMenuDivider`**，它只有颜色与高度，没有官方
///    `DividerStyleOptions` 的 `startMargin` / `endMargin`。缩进差一两档，
///    结构上补不了。
/// 3. **[optionWidth] 的下限**取资源表的 136vp 而不是文档说的 56vp：56 是
///    「属性失效的门槛」，136 是「菜单默认最小宽」，两个数在文档里分属不同
///    句子。用 136 更接近真机观感。
class OhosSelect<T> extends StatelessWidget {
  const OhosSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
    this.style = OhosButtonStyle.plain,
    this.selectedOptionBgColor,
    this.selectedOptionFontColor,
    this.optionBgColor,
    this.optionFontColor,
    this.showDefaultSelectedIcon = false,
    this.menuAlign = OhosSelectMenuAlign.start,
    this.arrowPosition = OhosSelectArrowPosition.end,
    this.optionWidth,
    this.optionHeight,
    this.showDivider = true,
    this.dividerColor,
  });

  /// Available options.
  final List<OhosSelectOption<T>> options;

  /// Currently selected value.
  final T value;

  /// Called with the newly selected value.
  final ValueChanged<T> onChanged;

  /// Optional label next to the selected value.
  final String? label;

  /// When false the select is disabled.
  final bool enabled;

  /// Emphasis style of the trigger button.
  final OhosButtonStyle style;

  /// 选中项背景色（官方 `selectedOptionBgColor`）。
  ///
  /// 默认「品牌色 + `ohos_id_alpha_highlight_bg = 0.2`」。灰阶屏上 20% 落在
  /// 第 0–3 级、与纸面不可分，策略会把它判成透明 —— 那时只能靠
  /// [showDefaultSelectedIcon] 的勾或字色补。
  final Color? selectedOptionBgColor;

  /// 选中项文字颜色（官方 `selectedOptionFontColor`）。
  ///
  /// 默认 `ohos_id_color_text_primary_activated` → 主题品牌色。
  final Color? selectedOptionFontColor;

  /// 普通项背景色（官方 `optionBgColor`，API 11 起默认 `Transparent`）。
  final Color? optionBgColor;

  /// 普通项文字颜色（官方 `optionFontColor`，默认
  /// `ohos_id_color_text_primary`）。
  final Color? optionFontColor;

  /// 是否给选中项画一个勾（官方 `showDefaultSelectedIcon`，**默认 false**）。
  ///
  /// 官方原文：`false` 时「通过突出显示背景色来表示选中」。老实现**总是**画
  /// 勾，与这一条相反：彩屏上「勾 + 底色」是双重标注，与自家 `OhosMenu` 的
  /// 风格也不一致。需要勾就显式打开。
  final bool showDefaultSelectedIcon;

  /// 菜单相对按钮的对齐（官方 `menuAlign`，默认 `START`）。
  final OhosSelectMenuAlign menuAlign;

  /// 触发按钮上箭头的位置（官方 `arrowPosition`，默认 `END`）。
  final OhosSelectArrowPosition arrowPosition;

  /// 菜单项宽度（官方 `optionWidth`）。null 表示只给下限、按内容撑开。
  final double? optionWidth;

  /// 菜单最大高度（官方 `optionHeight`，默认「屏幕可用高度的 80%」）。
  final double? optionHeight;

  /// 是否画菜单项之间的分割线（官方 `divider`；官方传 `null` 即不显示）。
  final bool showDivider;

  /// 分割线颜色。默认 `#33182431`（文档 `divider` 默认值）。
  final Color? dividerColor;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final OhosVisualPolicy policy = theme.policy;
    final OhosSelectOption<T> selected = options.firstWhere(
      (OhosSelectOption<T> o) => o.value == value,
      orElse: () => options.first,
    );

    // 选中项字色：官方 `ohos_id_color_text_primary_activated` —— 品牌色的另一种
    // 说法。墨屏上品牌色与正文同为纯黑，「选中」只剩底色这一条线索（20% 又被
    // 策略判成透明）→ 必须靠 showDefaultSelectedIcon 的勾补上。这正是官方把
    // 那个开关做成默认 false 却仍留着的原因：不同屏上缺的线索不一样。
    final Color selectedFg = selectedOptionFontColor ?? theme.highlightColor;
    final Color normalFg = optionFontColor ?? theme.textPrimaryColor;
    // 选中底色：官方「activated 混 20%」。走 tint 而不是直接 withValues：
    // 灰阶屏上 20% 托不住形体，tint 会返回透明 —— 与「策略管表现」的分层一致。
    final Color selectedBg =
        selectedOptionBgColor ??
        policy.tint(
          theme.highlightColor,
          OhosSelectMetrics.selectedBackgroundAlpha,
        );
    final Color normalBg = optionBgColor ?? Colors.transparent;

    final Widget triggerIcon = Icon(
      arrowPosition == OhosSelectArrowPosition.end
          ? Icons.expand_more_rounded
          : Icons.expand_less_rounded,
    );

    return OhosButton(
      onPressed: enabled
          ? () async {
              final T? result = await showMenu<T>(
                context: context,
                position: _menuPosition(context),
                color: theme.popupColor,
                constraints: _menuConstraints(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    OhosSelectMetrics.popupRadius,
                  ),
                  // 墨水屏：下拉面板与页面同为纯白，阴影不存在 → 1px 实线
                  side: theme.usesOutlines
                      ? ohosBorderSide(
                          context,
                          theme.dividerColor,
                          width: theme.outlineWidth,
                        )
                      : BorderSide.none,
                ),
                items: <PopupMenuEntry<T>>[
                  for (
                    int i = 0;
                    i < options.length;
                    i++
                  ) ...<PopupMenuEntry<T>>[
                    PopupMenuItem<T>(
                      value: options[i].value,
                      height: OhosSelectMetrics.optionMinHeight,
                      padding: EdgeInsets.zero,
                      child: _OptionRow(
                        theme: theme,
                        option: options[i],
                        isSelected: options[i].value == value,
                        background: options[i].value == value
                            ? selectedBg
                            : normalBg,
                        foreground: options[i].value == value
                            ? selectedFg
                            : normalFg,
                        // 勾必须与字色同源：墨屏上「白勾 + 白字」都压不住，
                        // 「黑勾 + 黑字」才一致；写死品牌色会让勾在墨屏上消失。
                        showCheck:
                            options[i].value == value &&
                            showDefaultSelectedIcon,
                      ),
                    ),
                    // 分割线插在两项之间，最后一项后面不画 —— 与官方 `divider`
                    // 「项间分隔」的语义一致，也不是上下边框。
                    if (showDivider && i != options.length - 1)
                      PopupMenuDivider(
                        height: ohosStrokeWidth(
                          context,
                          OhosSelectMetrics.dividerWidthPx,
                        ),
                        color: dividerColor ?? OhosSelectMetrics.dividerColor,
                      ),
                  ],
                ],
              );
              if (result != null) onChanged(result);
            }
          : null,
      style: style,
      icon: triggerIcon,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 88, maxWidth: 200),
        child: Text(
          label == null ? selected.label : '$label ${selected.label}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
        ),
      ),
    );
  }

  /// 菜单尺寸约束。
  ///
  /// 官方 `optionWidth` 有两档：给了具体值就照给（低于 56vp 视为无效、回落
  /// 默认），没给则「继承下拉按钮宽度」。Flutter 的 `showMenu` 用
  /// `constraints` 表达，这里把两档折成同一个 `BoxConstraints`。
  BoxConstraints _menuConstraints(BuildContext context) {
    final double? explicit = optionWidth;
    final double maxHeight =
        optionHeight ?? MediaQuery.sizeOf(context).height * 0.8;
    if (explicit != null && explicit >= 56) {
      return BoxConstraints(
        minWidth: explicit,
        maxWidth: explicit,
        maxHeight: maxHeight,
      );
    }
    // 未给：只钉下限，上限留空让 `showMenu` 按内容撑开（官方「跟随按钮宽度 /
    // 2 栅格」的等价表达 —— `showMenu` 自己会按内容算，比硬钉一个数更准）。
    return BoxConstraints(
      minWidth: OhosSelectMetrics.popupMinWidth,
      maxHeight: maxHeight,
    );
  }

  /// Anchors the dropdown below the trigger button according to [menuAlign].
  RelativeRect _menuPosition(BuildContext context) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final RenderBox? overlay =
        Overlay.maybeOf(context, rootOverlay: true)?.context.findRenderObject()
            as RenderBox?;
    if (box == null || overlay == null || !box.hasSize) {
      return RelativeRect.fromLTRB(0, 0, 0, 0);
    }
    final Offset topLeft = box.localToGlobal(Offset.zero);
    final Offset bottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
    );
    // 间距走官方 `space` = 8vp（老实现写死 4，正是文档说「≤8 取默认」的那个 8）。
    const double gap = OhosSelectMetrics.space;
    final double buttonWidth = bottomRight.dx - topLeft.dx;
    final double left = switch (menuAlign) {
      OhosSelectMenuAlign.start => topLeft.dx,
      // 菜单宽度拿不到（定位先于布局），用按钮宽度近似：center 从按钮中点
      // 向右展开，end 从按钮右边缘向左展开。
      OhosSelectMenuAlign.center => topLeft.dx + buttonWidth / 2,
      OhosSelectMenuAlign.end => bottomRight.dx - buttonWidth,
    };
    return RelativeRect.fromLTRB(
      left < 0 ? 0 : left,
      bottomRight.dy + gap,
      overlay.size.width - bottomRight.dx,
      overlay.size.height - bottomRight.dy - gap,
    );
  }
}

/// 单项：底色 + 图标 + 文字 + （可选）勾。
///
/// 底色必须铺在**整行**上（`Container` 包住左右内边距），否则官方
/// `selectedOptionBgColor` 只会在文字背后画一条彩带，而不是「整项被选中」。
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.theme,
    required this.option,
    required this.isSelected,
    required this.background,
    required this.foreground,
    required this.showCheck,
  });

  final OhosThemeData theme;
  final OhosSelectOption<Object?> option;
  final bool isSelected;
  final Color background;
  final Color foreground;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    // 左右 16vp 是本库列表项的通行边距（`OhosListItemCard`、`OhosMenu` 同值）。
    // 官方文档没有给项内边距的数值，资源表里的 `padding_level2 = 4vp` 是菜单
    // **容器**级别，不是项内。
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        children: <Widget>[
          if (option.icon != null) ...<Widget>[
            Icon(option.icon, size: 18, color: foreground),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          // 勾的颜色与字色同源，不写死品牌色：墨屏上品牌色被压成纯黑，
          // 黑勾压在 20%（被判成透明）的底色上仍然看得见，但换成白勾就消失。
          if (showCheck) Icon(Icons.check_rounded, size: 18, color: foreground),
        ],
      ),
    );
  }
}
