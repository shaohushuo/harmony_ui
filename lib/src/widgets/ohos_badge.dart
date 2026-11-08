import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// 徽标位置（对应官方 `BadgePosition` 三档）。
enum OhosBadgePosition {
  /// 右上角（官方默认 `BadgePosition.RightTop`）。
  rightTop,

  /// 右侧纵向居中（官方 `Right`）。
  ///
  /// 设计要求「圆点标记显示在文本之后」用的就是这一档 —— 它是一个**行内**
  /// 标记，贴着文本右边缘垂直居中，而不是飘在图标右上角的角标。
  right,

  /// 左侧纵向居中（官方 `Left`）。
  left,
}

/// 徽标的官方尺寸令牌，取自系统资源表 `float.json` 与
/// `pattern.json` 的 `ohos_badge_pattern`。
class OhosBadgeMetrics {
  const OhosBadgeMetrics._();

  /// 徽标基准边长（`BadgeStyle.badgeSize` 默认 **16vp**）。
  ///
  /// 老实现写死 18 —— 那是 Material 的默认值，比官方大一档。
  static const double size = 16;

  /// 徽标文字字号（`BadgeStyle.fontSize` 默认 **10vp**）。
  ///
  /// 资源表里对应 `ohos_id_text_size_caption = 10.0vp`。
  static const double fontSize = 10;

  /// 圆点标记的直径（`little_badge_size = 6vp`）。
  ///
  /// 注意：这是**圆点标记**的尺寸，不是数字标记的。老实现用 8。
  static const double dotSize = 6;

  /// 数字徽标为容纳多位数字而**额外增加的总宽度**
  /// （`numerical_badge_padding = 6vp`）。
  ///
  /// 口径说明：令牌只说 6vp，没说「每侧」还是「总额」。取总额是因为
  /// 一位数的徽标必须仍是 16vp 的圆（设计规范图里就是圆点）+ 最多 12vp
  /// 若按「每侧 6」，一位数最窄也会到 10+12=22vp、方不方圆不圆。按总额
  /// 增长则：1 位 = max(16, 6+6) = 16 圆、2 位 = 18、3 位 = 24，与官方
  /// 「位数变多横向长成胶囊」一致。
  static const double numericalPadding = 6;

  /// 数字上限默认值（`maxCount` 默认 99）。
  static const int maxCount = 99;
}

/// A count, text or dot badge attached to icons and tabs, the `ohos_ui`
/// counterpart of Material's `Badge`.
///
/// 三种形态对应官方的三种入参：
///
/// * `count`（官方 `BadgeParamWithNumber`）—— 数字标记，超过 [maxCount] 显示
///   `99+`；
/// * `value`（官方 `BadgeParamWithString`）—— 任意短文本（「NEW」这类运营
///   标记）；空串退化为圆点，与官方「value 为空字符串时不显示文本，仅显示
///   圆点标记」一致；
/// * [isDot] —— 圆点标记。
///
/// 数字徽标的基准是 16×16 的圆，位数变多时横向长成胶囊，**绝不会被父行拉成
/// 竖胶囊**：内部用 `Center(widthFactor: 1)` 而不是 `alignment:`，后者会插一个
/// `Align`，在「宽度无界、高度有界」的约束下（`Row` 里的非弹性子节点正是
/// 这样）把高度撑到父级上限。
class OhosBadge extends StatelessWidget {
  const OhosBadge({
    super.key,
    this.count,
    this.value,
    this.child,
    this.color,
    this.textColor,
    this.maxCount = OhosBadgeMetrics.maxCount,
    this.isDot = false,
    this.position = OhosBadgePosition.rightTop,
    this.offset = Offset.zero,
    this.badgeSize = OhosBadgeMetrics.size,
    this.fontSize = OhosBadgeMetrics.fontSize,
    this.borderColor,
    this.borderWidth = 0,
  });

  /// The badge value; when null the badge is hidden but [child] remains.
  final int? count;

  /// 字符串形态（官方 `BadgeParamWithString.value`）。
  ///
  /// 给了它就以它为准、忽略 [count]：[value] 是「运营标记」（NEW / 热）这类
  /// 任意文本，没有「超过上限显示 max+」的语义。
  final String? value;

  /// The widget the badge is attached to.
  final Widget? child;

  /// Badge background color; defaults to [OhosColors.danger].
  final Color? color;

  /// 徽标文字颜色（官方 `BadgeStyle.color`，默认 `Color.White`）。
  final Color? textColor;

  /// Values above this are shown as "max+", e.g. "99+".
  final int maxCount;

  /// When true renders a plain dot instead of a numeric label.
  final bool isDot;

  /// 徽标相对 [child] 的位置（官方 `BadgePosition`）。
  ///
  /// 只有给了 [child] 才有意义：没有宿主时徽标单独渲染，位置就是它自己。
  final OhosBadgePosition position;

  /// Extra offset applied to the badge label.
  ///
  /// 在 [position] 之上再叠一层微调 —— 官方把「具体坐标」作为 `position` 的
  /// 另一种入参（`Position`），Flutter 侧保留这个逃生口，免得为了挪 2vp
  /// 就要自己套 `Stack`。
  final Offset offset;

  /// 徽标边长（官方 `BadgeStyle.badgeSize`，默认 16vp）。圆点形态取
  /// [OhosBadgeMetrics.dotSize]。
  final double badgeSize;

  /// 徽标字号（官方 `BadgeStyle.fontSize`，默认 10vp）。
  ///
  /// 官方还有一条约束：「当设置了 fontSize 且 badgeSize 小于 fontSize 时，
  /// badgeSize 将按照 fontSize 生效」—— 否则文字会把底板撑破。
  final double fontSize;

  /// 底板描边颜色（官方 `BadgeStyle.borderColor`，默认与底色相同）。
  ///
  /// 默认与底色一致 = 看不见；需要「白圈压在深色图标上」这类效果时传白。
  final Color? borderColor;

  /// 底板描边粗细（官方 `BadgeStyle.borderWidth`，默认 1）。
  final double borderWidth;

  /// 数字徽标的实际最小边长：字号大于 [badgeSize] 时按字号走（官方口径）。
  double get _effectiveMinSize => badgeSize < fontSize ? fontSize : badgeSize;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color badgeColor = color ?? theme.dangerColor;
    final Widget? label = _buildLabel(theme, badgeColor);
    if (child == null && label == null) {
      return const SizedBox.shrink();
    }
    if (child == null) {
      return label!;
    }
    final Widget? positioned = label == null ? null : _positioned(label);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[child!, if (positioned != null) positioned],
    );
  }

  Widget? _buildLabel(OhosThemeData theme, Color badgeColor) {
    if (isDot || (value != null && value!.isEmpty)) {
      // 圆点：官方 `little_badge_size = 6vp`，不是数字标记的 16。
      return ohosBadgeHalo(
        theme,
        _decorate(
          badgeColor,
          borderRadius: OhosBadgeMetrics.dotSize / 2,
          child: const SizedBox(
            width: OhosBadgeMetrics.dotSize,
            height: OhosBadgeMetrics.dotSize,
          ),
        ),
        OhosBadgeMetrics.dotSize / 2,
      );
    }
    final String? text = value ?? _countText;
    if (text == null) {
      return null;
    }
    final double min = _effectiveMinSize;
    // 数字色跟着底色亮度走，不写死白：深色墨屏的 `dangerColor` 已经反成白，
    // 再配白字就是白底白字，数字整颗消失。彩屏红底（亮度 0.28）仍是白字，
    // 白纸墨屏黑底也是白字 —— 一条规则三档都对。
    final Color onBadge = ohosBadgeForeground(badgeColor, override: textColor);
    return ohosBadgeHalo(
      theme,
      _decorate(
        badgeColor,
        borderRadius: min / 2,
        child: Container(
          constraints: BoxConstraints(minWidth: min, minHeight: min),
          // 总额 6vp 摊到两侧各 3：见 [OhosBadgeMetrics.numericalPadding] 的
          // 口径说明 —— 每侧 6 会把一位数撑成 22vp，不再是 16 的圆。
          padding: EdgeInsets.symmetric(
            horizontal: OhosBadgeMetrics.numericalPadding / 2,
            vertical: 0,
          ),
          // 同老实现：不能用 `alignment:`（会插 `Align`，高度被父级上限拉满）。
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              text,
              style: TextStyle(
                color: onBadge,
                fontSize: fontSize,
                fontWeight: FontWeight.w400,
                height: 1.2,
                // 挂在根 Overlay / 裸树时没有 Material 祖先，`MaterialApp` 会
                // 给这种位置兜底 `_errorTextStyle`（mono + 黄色双下划线）。
                decoration: TextDecoration.none,
                inherit: false,
                fontFamily: theme.typography.fontFamily,
              ),
            ),
          ),
        ),
      ),
      min / 2,
    );
  }

  String? get _countText {
    if (count == null) {
      return null;
    }
    // 官方：小于等于 0 且小于 maxCount 时不显示标记。
    if (count! <= 0) {
      return null;
    }
    return count! > maxCount ? '$maxCount+' : '$count';
  }

  Widget _decorate(
    Color badgeColor, {
    required double borderRadius,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderWidth > 0
            ? Border.all(color: borderColor ?? badgeColor, width: borderWidth)
            : null,
      ),
      child: child,
    );
  }

  Widget _positioned(Widget label) {
    final Offset extra = offset;
    switch (position) {
      case OhosBadgePosition.rightTop:
        // 右上角：徽标中心落在宿主右上角内侧一点点。`right: 0` 时徽标完全
        // 站进宿主盒子内部，圆角图标看起来就是「压在角上」；再往外溢就要
        // 吃掉父级 padding（`Stack(clipBehavior: none)` 允许，但会把相邻
        // 元素挤开）。
        return Positioned(top: extra.dy, right: extra.dx, child: label);
      case OhosBadgePosition.right:
        return Positioned(
          top: extra.dy,
          right: extra.dx,
          bottom: extra.dy,
          child: Center(widthFactor: 1, child: label),
        );
      case OhosBadgePosition.left:
        return Positioned(
          top: extra.dy,
          left: extra.dx,
          bottom: extra.dy,
          child: Center(widthFactor: 1, child: label),
        );
    }
  }
}

/// 给角标套一圈纸色外描边 —— 只在这套主题需要轮廓线时生效。
///
/// 角标叠在图标右上角，墨屏下两者都是纯黑：不描边就糊成一坨，看不出数字
/// 的边界，也分不清它压在谁身上。彩屏靠底色分层（`outlineWidth` 为 null）
/// 不做；描边色取 `backgroundColor` 而不是写死白 —— 深色墨屏里角标自身已是
/// 白底黑字，纸色是黑，于是自动变成「黑边」，一套规则两端都成立，不必写
/// `isMonochrome` 分支。
///
/// 用 `padding` 画在外侧而不是 `Border.all`：后者画在盒子内侧，会吃掉数字
/// 的内边距，16vp 的圆里再少 2vp 就挤了。本体因此增加 `2 × outline`，相对
/// 图标的那点外溢可以忽略。
///
/// 这条规则不只服务 [OhosBadge]：`OhosFloatingTabBar` 的角标是另一份实现
/// （尺寸 14、字号 9），它压在**选中的那一项**上 —— 墨屏里选中项本身就画成
/// 反白实底，角标底色又恰好是同一个 `dangerColor`，两团同色连边界都没有。
/// 两处共用这一个函数，免得一边修好一边继续糊。
Widget ohosBadgeHalo(OhosThemeData theme, Widget child, double radius) {
  final double? outline = theme.policy.outlineWidth;
  if (outline == null) {
    return child;
  }
  return Container(
    padding: EdgeInsets.all(outline),
    decoration: BoxDecoration(
      color: theme.backgroundColor,
      borderRadius: BorderRadius.circular(radius + outline),
    ),
    child: child,
  );
}

/// 角标上文字该用的颜色：跟着**底色亮度**走，不写死白。
///
/// 深色墨屏的 `dangerColor` 已经反成纸色，再配白字就是白底白字，数字整颗
/// 消失。彩屏红底（亮度 0.28）与白纸墨屏的黑底都该是白字 —— 一条规则覆盖
/// 彩屏 / 白纸墨屏 / 深色墨屏三档，比按主题分支少猜两次。
Color ohosBadgeForeground(Color badgeColor, {Color? override}) =>
    override ??
    (badgeColor.computeLuminance() > 0.5
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF));
