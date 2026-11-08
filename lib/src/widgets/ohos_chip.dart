import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ohos_chip_metrics.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';

/// A HarmonyOS filter chip used for tags and multi-select filters, the
/// counterpart of Material's [FilterChip] / [ActionChip].
///
/// Geometry comes from [OhosChipMetrics], which carries the resolved values of
/// ArkUI's own `chip_*` `sys.float` tokens — 36/28 tall, 18/14 radius, 16/6
/// padding + icon gap, 14 fp label. Pass [size] to pick the class.
///
/// Trailing affordances follow ArkUI's precedence chain
/// `suffixSymbol > suffixImageIcon > allowClose`: pass [suffixIcon] to draw
/// your own glyph, or [allowClose] to get the built-in `xmark`. When both are
/// given, [suffixIcon] wins and [allowClose] is ignored — mirroring
/// `isNeedShowCloseIconMargin` / `hasSuffix()` in `chip.ets`.
class OhosChip extends StatelessWidget {
  const OhosChip({
    super.key,
    required this.label,
    this.onPressed,
    this.selected = false,
    this.icon,
    this.selectedIcon,
    this.suffixIcon,
    this.suffixSelectedIcon,
    this.allowClose = false,
    this.onClose,
    this.selectedColor,
    this.size = OhosChipSize.normal,
    this.backgroundColor,
    this.activatedBackgroundColor,
    this.labelColor,
    this.activatedLabelColor,
    this.labelFontSize,
    this.labelFontFamily,
  });

  /// The chip label.
  final Widget label;

  /// Called when the chip is tapped; null disables the chip.
  final VoidCallback? onPressed;

  /// Whether the chip is currently selected.
  final bool selected;

  /// Optional leading icon.
  final Widget? icon;

  /// Leading icon used while [selected] is true.
  ///
  /// The counterpart of ArkUI `prefixSymbol.activated` / `prefixIcon`'s
  /// `activatedFillColor`. `chip.ets` resolves the leading slot as
  /// `isChipActivated() ? prefixSymbol.activated : prefixSymbol.normal`, i.e.
  /// the two states are **different glyphs**, not one glyph recoloured. Pass
  /// this when the selected state needs a filled variant of [icon] (outline →
  /// filled); when null, [icon] is reused and only its tint follows [selected],
  /// which matches `activatedFillColor` on its own.
  final Widget? selectedIcon;

  /// Optional trailing icon, e.g. a dropdown arrow.
  ///
  /// Takes precedence over [allowClose]: ArkUI's `suffixSymbol` /
  /// `suffixImageIcon` both suppress the built-in close button, and only when
  /// neither is present does `allowClose` decide.
  final Widget? suffixIcon;

  /// 选中态的后缀图标（官方 `suffixSymbol.activated`）。
  ///
  /// 与 [selectedIcon] 同一条语义：官方的前后缀 symbol 都是 `normal` /
  /// `activated` **两个图形**，不是同一图形换色。为 null 时回落到 [suffixIcon]
  /// （回落理由见 [selectedIcon]）。
  final Widget? suffixSelectedIcon;

  /// Whether the built-in close (×) button is shown.
  ///
  /// **Deliberately defaults to `false`, unlike ArkUI.** `chip.ets` resolves
  /// `isClosable()` as `allowClose ?? true`, so a standalone ArkUI `Chip` ships
  /// with a × by default — while `chipgroup.ets:580` passes
  /// `chipItem.allowClose ?? false`, i.e. group items default to *no* ×. Since
  /// this widget is used both standalone and inside [OhosChipGroup], following
  /// the standalone default would make every existing chip grow a × on upgrade
  /// (a silent visual break, and a dead one when [onClose] is null). Opt in.
  final bool allowClose;

  /// Called after the close button is tapped.
  ///
  /// The chip is not removed for you: the ArkUI original runs a 150ms
  /// fade+shrink and then unmounts itself, but a Flutter `StatelessWidget`
  /// cannot own its own lifetime, so the caller drops it from the list. Null
  /// still renders the × — matching ArkUI, where `onClose` is optional.
  final VoidCallback? onClose;

  /// Background color when selected; defaults to a brand-tinted surface.
  final Color? selectedColor;

  /// Size class; resolves to [OhosChipMetrics.normal] / [OhosChipMetrics.small].
  final OhosChipSize size;

  /// 常态背景色（官方 `backgroundColor`，默认
  /// `ohos_id_color_button_normal`）。
  ///
  /// null 时走主题回落（`compBackgroundGrayColor` / `cardColor`）。
  final Color? backgroundColor;

  /// 激活态背景色（官方 `activatedBackgroundColor`，默认
  /// `ohos_id_color_emphasize`）。
  ///
  /// 默认值的依据：官方文档 `ohos-arkui-advanced-Chip.md` 的
  /// `ChipOptions.activatedBackgroundColor` 表格（API 12 起）写的就是
  /// `$r('sys.color.ohos_id_color_emphasize')`；源码 `chip.ets:389` 走的是
  /// `sys.color.chip_container_activated_color` —— 与文档不同源，但同属高亮
  /// 容器色，此处按文档口径记默认值，不追 hex。
  ///
  /// 与 [selectedColor] 是同一条规格的两个入口：那个是 0.5 起的本库参数名，
  /// 这个对齐官方文档。两者都给时 [activatedBackgroundColor] 优先。
  final Color? activatedBackgroundColor;

  /// 常态文字色（官方 `LabelOptions.fontColor`，默认
  /// `ohos_id_color_text_primary`）。
  final Color? labelColor;

  /// 激活态文字色（官方 `LabelOptions.activatedFontColor`，默认
  /// `ohos_id_color_text_primary_contrary`）。
  ///
  /// 默认值的依据：官方文档 `ohos-arkui-advanced-Chip.md`（`ChipOptions.label`
  /// 表格，API 12 起）明写 `activatedFontColor` 默认
  /// `$r('sys.color.ohos_id_color_text_primary_contrary')`；源码 `chip.ets:328`
  /// 的 theme 走 `sys.color.chip_activated_fontcolor`，语义同为「高亮容器上的
  /// 反色前景」。**不要**改成 `ohos_id_color_text_primary` —— 那是非激活态的
  /// `fontColor`，配强调色底会掉到 ~1.1:1。
  ///
  /// 文档另提醒：调用方把 [activatedBackgroundColor] 换成浅色时必须同步给
  /// 本参数，否则对比度不足 —— 那是调用方配置问题，不是默认值问题。
  ///
  /// 注意它与图标色的默认值**不同源**：图标非激活是
  /// `ohos_id_color_secondary`、激活是 `ohos_id_color_text_primary_contrary`；
  /// 文字非激活是 `ohos_id_color_text_primary`。老实现把两者绑在同一个
  /// [fg] 上，所以文字常态拿了图标的 secondary 色 —— 偏淡一档，这里分开。
  final Color? activatedLabelColor;

  /// 文字字号（官方 `LabelOptions.fontSize`，默认
  /// `ohos_id_text_size_button2 = 14fp`）。
  ///
  /// null 时取 [OhosChipMetrics.fontSize]（两档都是 14）。
  final double? labelFontSize;

  /// 文字字体族（官方 `LabelOptions.fontFamily`，默认 `"HarmonyOS Sans"`）。
  ///
  /// null 时跟随 [OhosThemeData.typography] —— 本库不写死字体名，否则
  /// 非 HarmonyOS 设备会因缺字体回退成系统默认，反而比主题口径更差。
  final String? labelFontFamily;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final OhosChipMetrics metrics = OhosChipMetrics.of(size);
    final bool enabled = onPressed != null;
    final OhosVisualPolicy policy = theme.policy;
    // 12% 的选中底活不过 16 级灰阶：策略会把它判成透明，这时改走
    // 「反白实底」—— 与 tabs / toolbar 同一条 `selectionMark` 约定。
    //
    // 早先这里只把底判成透明、字色却仍是 `onHighlightColor`：白纸上白字压白纸、
    // 深色纸上是纸色字压纸底，选中的 chip 整颗字消失，只剩一圈稍深的描边。
    final OhosSelectionMark mark = policy.selectionMark;
    final bool inverse = selected && mark == OhosSelectionMark.inverse;
    final Color idleFill =
        backgroundColor ?? theme.compBackgroundGrayColor ?? theme.cardColor;
    final Color selectedFill =
        policy.tint(theme.highlightColor, 0.10) == Colors.transparent
        ? Colors.transparent
        : (theme.emphasizeTertiaryColor ??
              theme.highlightColor.withValues(alpha: 0.10));
    // 激活底色的优先级：官方参数名 → 本库旧参数名 → 主题回落。
    final Color bg = selected
        ? (activatedBackgroundColor ??
              selectedColor ??
              (inverse ? theme.highlightColor : selectedFill))
        : idleFill;
    // 文字色与图标色**分开**：官方 `LabelOptions.fontColor` 默认
    // `ohos_id_color_text_primary`，而 `prefixIcon.fillColor` 默认
    // `chip_usually_icon_color`（≈ `ohos_id_color_secondary`）。老实现把两者
    // 绑在同一个 `fg` 上，文字常态因此偏淡一档。
    final Color iconFg = !selected
        ? theme.textSecondaryColor
        : _selectedForeground(theme, bg, onNoFill: theme.highlightColor);
    final Color labelFg = !selected
        ? (labelColor ?? theme.textPrimaryColor)
        : (activatedLabelColor ??
              _selectedForeground(theme, bg, onNoFill: theme.textPrimaryColor));
    // 描边：选中用品牌色，未选中用提示色；墨屏上两者都由策略换成实色
    final Color borderColor = selected
        ? policy.line(theme.highlightColor, 0.20)
        : policy.line(theme.textTertiaryColor, 0.3);
    // 双态前图标：激活态优先 selectedIcon，缺省回落到 icon。
    //
    // 这里**有意偏离** ArkUI 的严格语义：`chip.ets:1014` 的 `hasPrefix()` 是
    // `isChipActivated() ? !!activated : !!normal`，只给了 normal 时选中态连
    // 图标**和间距**一起消失。照搬会让既有用法（只传 icon）在被点中的一瞬间
    // 掉掉图标 —— 那不是「双态」，是缺陷。回落更接近 `activatedFillColor`
    // 的默认行为（不传就沿用常态表现）。
    final Widget? leading = selected ? (selectedIcon ?? icon) : icon;
    // 后缀同样双态：官方 `suffixSymbol.normal` / `.activated` 是两个图形。
    final Widget? trailing = selected
        ? (suffixSelectedIcon ?? suffixIcon)
        : suffixIcon;
    // 官方字重：`chip_text_font_weight = 400`、`chip_activated_text_font_weight
    // = 500`（资源表 float_sys.json 真值）。老实现两档都是 400，
    // 「选中」只剩颜色一条线索 —— 墨屏上颜色失效后就看不出选中了。
    final FontWeight weight = selected ? FontWeight.w500 : FontWeight.w400;
    final double fontSize = labelFontSize ?? metrics.fontSize;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        // 官方给的是显式圆角（18 / 14），不是「高度折半」。当前两档恰好等于
        // 折半值，但一旦有人调高 [OhosChipMetrics.height]，`height / 2` 就会
        // 悄悄偏离官方规格 —— 胶囊观感是结果，不是来源。
        borderRadius: BorderRadius.circular(metrics.radius),
        side: ohosBorderSide(context, borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          // 高度由令牌钉死（36 / 28），不靠 padding + 字阶撑出来：
          // 原来用 `vertical: 7` 配 14fp×1.4 行高只有 33.6，比官方矮 2.4，
          // 而且字阶一改高度就跟着漂。
          height: metrics.height,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.horizontalPadding,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // 双态前图标与 ArkUI 的 `hasPrefix()` 同义：只要任一侧有图标就
                // 占位，激活态优先取 selectedIcon。回落规则见上面的 [leading]。
                if (leading != null) ...<Widget>[
                  IconTheme.merge(
                    data: IconThemeData(color: iconFg, size: metrics.iconSize),
                    child: leading,
                  ),
                  SizedBox(width: metrics.iconGap),
                ],
                DefaultTextStyle.merge(
                  style:
                      (theme.typography.labelMedium ??
                              TextStyle(fontSize: fontSize))
                          .copyWith(
                            color: labelFg,
                            fontSize: fontSize,
                            fontWeight: weight,
                            // 两个分支都显式给 fontFamily：`merge` 只覆盖非
                            // null 字段，写 null 等于把祖先的家族放行下来。
                            fontFamily:
                                labelFontFamily ?? theme.typography.fontFamily,
                          ),
                  child: label,
                ),
                // 后缀优先级与 ArkUI 一致：自己给的后缀图标压过内置关闭按钮。
                // `chip.ets` 的 `hasSuffix()` / `isNeedShowCloseIconMargin()`
                // 就是这个次序，且两者共用同一个文字侧边距（6 / 4），所以
                // 间距一律用 metrics.iconGap，不另取一个整数。
                //
                // 判据用 [trailing]（已按 selected 选好双态）而不是原字段：
                // 只看 `suffixIcon != null` 会让「只给了 activated 后缀」的
                // 芯片在选中态什么也不画 —— 那正好是「选中后掉了图标」。
                if (trailing != null) ...<Widget>[
                  SizedBox(width: metrics.iconGap),
                  IconTheme.merge(
                    data: IconThemeData(color: iconFg, size: metrics.iconSize),
                    child: trailing,
                  ),
                ] else if (allowClose) ...<Widget>[
                  SizedBox(width: metrics.iconGap),
                  // 关闭图标本身没有独立的尺寸令牌，ArkUI 用的是
                  // `defaultSymbolFontsize()`，即 `chip_normal_icon_size` /
                  // `chip_small_icon_size`（两档都是 16），所以这里复用
                  // metrics.iconSize。
                  //
                  // 命中区就是图标本身（16×16）：`chip.ets` 的关闭按钮显式
                  // `padding(0)` + `stateEffect(false)`，没有 `hot_zone` 可查。
                  // 需要更大命中区时传 [suffixIcon] 自带一块 40×40 的按钮，
                  // 而不是在这里自拟一个数字。
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? onClose : null,
                    child: IconTheme.merge(
                      data: IconThemeData(
                        color: iconFg,
                        size: metrics.iconSize,
                      ),
                      child: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 选中态的文字 / 图标该用什么颜色 —— 按**实际底色**算，不按分支猜。
///
/// 官方 `activatedFontColor` 默认 `text_primary_contrary`（≈ 反白），那是在
/// 「实底 `highlightColor`」这个前提下给的。本库彩屏的选中底是 10% 品牌色
/// tint，照抄反白就是白字压白纸；反过来，调用方显式传了实心品牌底时，退回
/// 品牌色字又是蓝字压蓝底。所以判据只能是合成后的真实底色。
///
/// [onNoFill] 是底色最终被判成完全透明时的退路（选中表达只剩描边，字要用
/// 常态色）。
Color _selectedForeground(
  OhosThemeData theme,
  Color fill, {
  required Color onNoFill,
}) {
  if (fill.a == 0) {
    return onNoFill;
  }
  // 底色可能是半透明 tint：先合成到页面上，`computeLuminance` 读出来的才是
  // 屏幕上那层实际颜色。
  final Color backdrop = Color.alphaBlend(fill, theme.backgroundColor);
  return _contrastRatio(theme.onHighlightColor, backdrop) >= _kChipReadable
      ? theme.onHighlightColor
      : theme.highlightTextColor;
}

/// 反白字在底色上至少要有这么多对比度才用它，否则退到品牌色字。
///
/// 2.5 是「看得清」的下限：官方彩屏实底蓝 + 白字约 6.1:1，10% tint 底 + 白字
/// 约 1.2:1（这一档必须退），tint 底 + 品牌色字约 4.7:1。
const double _kChipReadable = 2.5;

/// WCAG 对比度。与 `ohos_progress_indicator.dart` 里的同名私有函数一致；
/// 出现第三个调用点时再抽到公共 util。
double _contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
