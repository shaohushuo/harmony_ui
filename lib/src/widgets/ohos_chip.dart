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
    this.allowClose = false,
    this.onClose,
    this.selectedColor,
    this.size = OhosChipSize.normal,
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

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final OhosChipMetrics metrics = OhosChipMetrics.of(size);
    final bool enabled = onPressed != null;
    final OhosVisualPolicy policy = theme.policy;
    final Color fg = selected ? theme.highlightColor : theme.textSecondaryColor;
    // 12% 的选中底活不过 16 级灰阶：策略会把它判成透明，下面统一改成
    // 「留白 + 描边」，靠线的深浅而不是色的浓淡表意。
    final Color idleFill = theme.compBackgroundGrayColor ?? theme.cardColor;
    final Color selectedFill =
        policy.tint(theme.highlightColor, 0.10) == Colors.transparent
        ? Colors.transparent
        : (theme.emphasizeTertiaryColor ??
              theme.highlightColor.withValues(alpha: 0.10));
    final Color bg = selected ? (selectedColor ?? selectedFill) : idleFill;
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
                    data: IconThemeData(
                      color: fg,
                      size: metrics.iconSize,
                    ),
                    child: leading,
                  ),
                  SizedBox(width: metrics.iconGap),
                ],
                DefaultTextStyle.merge(
                  style:
                      (theme.typography.labelMedium ??
                              TextStyle(fontSize: metrics.fontSize))
                          .copyWith(color: fg, fontSize: metrics.fontSize),
                  child: label,
                ),
                // 后缀优先级与 ArkUI 一致：自己给的后缀图标压过内置关闭按钮。
                // `chip.ets` 的 `hasSuffix()` / `isNeedShowCloseIconMargin()`
                // 就是这个次序，且两者共用同一个文字侧边距（6 / 4），所以
                // 间距一律用 metrics.iconGap，不另取一个整数。
                if (suffixIcon != null) ...<Widget>[
                  SizedBox(width: metrics.iconGap),
                  IconTheme.merge(
                    data: IconThemeData(
                      color: fg,
                      size: metrics.iconSize,
                    ),
                    child: suffixIcon!,
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
                        color: fg,
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