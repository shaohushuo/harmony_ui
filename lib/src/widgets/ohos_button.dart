import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_press_feedback.dart';

/// 按钮的官方几何，来自设计规范《按钮》的响应式布局规则。
class OhosButtonMetrics {
  const OhosButtonMetrics._();

  /// 大屏上的最大宽度（设计规范：「大屏上按钮最大宽度为 **448vp**」）。
  ///
  /// 窗口化场景同一条：「容器宽 − 两侧 16vp，仍 ≤ 448」—— 也就是说 448 之外
  /// 还要再夹一次容器宽。这里只钉上限，夹容器宽由布局自然完成（紧约束会覆盖
  /// 它，见 [OhosButton.maxWidth] 的说明）。
  static const double maxWidth = 448;

  /// 窗口化场景下按钮与容器两侧的间距。
  static const double sideMargin = 16;
}

/// 按钮尺寸档位，对应官方 `ControlSize`（API 11+，默认 [normal]）。
///
/// 几何全部取自系统资源表（`pattern.json`），不是自拟：
///
/// | 档位 | 高度 | 字号 | 水平内边距 | 圆角（rounded 形态） |
/// | --- | --- | --- | --- | --- |
/// | [normal] | `button_height` 36 | `button_font_size` 16 | `button_horizontal_padding` 16 | `button_border_radius_normal` 20 |
/// | [small] | `small_button_height` 28 | `small_button_font_size` 12 | `small_button_horizontal_padding` 8 | `button_border_radius_small` 14 |
enum OhosButtonSize {
  /// 普通尺寸按钮（`ControlSize.NORMAL`）。
  normal,

  /// 小尺寸按钮（`ControlSize.SMALL`）。
  small;

  /// 按钮高度（vp）。
  double get height => switch (this) {
    OhosButtonSize.normal => 36,
    OhosButtonSize.small => 28,
  };

  /// 文字字号（fp）。
  double get fontSize => switch (this) {
    OhosButtonSize.normal => 16,
    OhosButtonSize.small => 12,
  };

  /// 水平内边距（vp）。
  double get horizontalPadding => switch (this) {
    OhosButtonSize.normal => 16,
    OhosButtonSize.small => 8,
  };

  /// rounded 形态的圆角（vp）。
  double get cornerRadius => switch (this) {
    OhosButtonSize.normal => 20,
    OhosButtonSize.small => 14,
  };
}

/// Visual variants of [OhosButton], mirroring ArkUI's button shapes.
enum OhosButtonShape {
  /// Fully rounded capsule (default).
  capsule,

  /// Large corner-radius square, e.g. 24vp.
  rounded,

  /// Perfect circle, typically for icon-only buttons.
  ///
  /// 直径取 [OhosButtonSize] 的高度（normal 36 / small 28），宽高相等、圆角为
  /// 直径一半；被 [OhosButton.maxWidth] 更小的值收紧时按该值缩小。
  ///
  /// 只能承载**一个**元素：有 `icon` 时用 `icon`，否则用 `child`。同时传两者
  /// 会在构造时断言失败 —— 圆形没有「图标 + 8vp 间距 + 文字」的横向排布，
  /// 复用那条 Row 会把图标推离圆心。极短的纯文字（如单字「+」）可以塞进直径
  /// 36 的圆里，2 字已接近上限（实测约 32.5×22），更长请改用其它形态。
  circle,
}

/// Emphasis levels of [OhosButton], mirroring ArkUI's button types.
enum OhosButtonStyle {
  /// Blue filled button with white text — first-level operations.
  filled,

  /// Soft blue-tinted surface with blue text — secondary operations.
  tonal,

  /// Transparent background with border — third-level operations.
  outlined,

  /// Borderless text button.
  text,

  /// White surface with border (classic "normal" button).
  plain,
}

/// A HarmonyOS button, the counterpart of Material's [ElevatedButton] /
/// [OutlinedButton] / [TextButton] and Cupertino's [CupertinoButton].
///
/// ```dart
/// OhosButton(
///   onPressed: () {},
///   child: Text('确定'),
/// )
/// ```
class OhosButton extends StatelessWidget {
  const OhosButton({
    super.key,
    required this.onPressed,
    this.child,
    this.icon,
    this.style = OhosButtonStyle.filled,
    this.shape = OhosButtonShape.capsule,
    this.controlSize = OhosButtonSize.normal,
    this.loading = false,
    this.minSize,
    this.padding,
    this.maxWidth,
  }) : assert(
         !(shape == OhosButtonShape.circle && icon != null && child != null),
         'circle 形态只承载单个元素：给了 icon 就用 icon、否则用 child。'
         '两者同时传会让 child 不渲染（圆形按钮没有「图标 + 间距 + 文字」的'
         '横向排布），请改用 capsule / rounded 形态承载图文按钮。',
       );

  /// Called when the button is tapped. When null the button is disabled.
  final VoidCallback? onPressed;

  /// The primary content, typically a [Text].
  final Widget? child;

  /// Optional leading icon.
  final Widget? icon;

  /// Emphasis level of the button.
  final OhosButtonStyle style;

  /// Shape of the button.
  ///
  /// [OhosButtonShape.circle] 是**单元素**形态：只取 [icon]（没有 icon 时取
  /// [child]），宽高都钉成直径，并忽略 [padding] 与 [minSize] 的宽度部分 ——
  /// 图文并排请用 [OhosButtonShape.capsule] / [OhosButtonShape.rounded]。
  final OhosButtonShape shape;

  /// 尺寸档位（官方 `controlSize`，默认 [OhosButtonSize.normal]）。
  /// 决定高度、字号、内边距与 rounded 圆角；[minSize] / [padding] 显式传值时
  /// 覆盖对应几何。
  final OhosButtonSize controlSize;

  /// Shows an inline spinner in place of [icon] and disables taps.
  final bool loading;

  /// Minimum size of the button; null 时宽度下限 48、高度取 [controlSize] 的
  /// 官方高度（NORMAL 36 / SMALL 28）。
  final Size? minSize;

  /// Padding inside the button; null 时按 [controlSize] 给水平内边距
  ///（NORMAL 16 / SMALL 8），垂直方向为 0（高度由 [minSize] 高度钉住）。
  final EdgeInsetsGeometry? padding;

  /// 最大宽度。官方设计规范：「大屏上按钮最大 **448vp**」、窗口化场景「容器宽
  /// − 两侧 16vp，仍 ≤ 448」。老实现完全没有上限 —— 大屏上一颗「提交」按钮
  /// 会被撑到整行宽，看起来像一条横幅。
  ///
  /// **它是上限，不是必然值**，也压不过父级的紧约束。`SizedBox(width: 700)` /
  /// `CrossAxisAlignment.stretch` / 铺满整行的 `Column` 会把 `minWidth` 与
  /// `maxWidth` 同时钉成 700，这里写 448 一样渲染成 700 —— 那是布局模型的
  /// 定义（子节点不得小于父级给的紧约束），换成 `Align(widthFactor: 1)` 也
  /// 一样，它最后一步依然走 `constraints.constrain()`。要按钮铺满某块区域是
  /// 调用方的布局选择，本组件只负责「不限宽时别无限拉伸」。
  ///
  /// 传 `double.infinity` 关闭上限。
  ///
  /// [OhosButtonShape.circle] 下它只作为**直径上限**：直径取 [controlSize] 的
  /// 高度，传了更小的 [maxWidth] 就按它缩小（仍是正圆），传更大值或 `null`
  /// 则不影响 —— 与其它形态「限制横向拉伸」的语义不同，因为圆形的宽度就是
  /// 高度，没有「变宽不变高」这一说。
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // 几何推导：显式 minSize/padding 优先，否则按 controlSize 的官方令牌值。
    final Size effectiveMinSize = minSize ?? Size(48, controlSize.height);
    final EdgeInsetsGeometry effectivePadding =
        padding ??
        EdgeInsets.symmetric(horizontal: controlSize.horizontalPadding);
    final double effectiveCorner = controlSize.cornerRadius;
    // circle 形态：直径取按钮高度，强制宽高相等，否则只画 height/2 圆角得到的是
    // 「两端半圆的药丸」（纯图标时实测 52×36），不是正圆。`maxWidth` 在这里是
    // 直径上限（圆没有「变宽不变高」的形态），传更小的值就整体缩小。
    final bool isCircle = shape == OhosButtonShape.circle;
    final double circleDiameter = isCircle && maxWidth != null
        ? math.min(effectiveMinSize.height, maxWidth!)
        : effectiveMinSize.height;
    // loading 与「没有回调」是两件事：前者只是暂时不能点，视觉上仍是「正在
    // 干活」的主按钮；后者才是禁用。混在一个布尔里会让 filled + loading 落到
    // 禁用分支，而转圈的白色是写死的 —— 浅底白圈在 16 级灰上整块消失（真机：
    // NoteAir 上「加载中」按钮只剩一个空白药丸，连转圈都看不见）。
    final bool interactive = onPressed != null && !loading;
    final bool dimmed = onPressed == null && !loading;
    final OhosVisualPolicy policy = theme.policy;
    final Color highlight = theme.highlightColor;
    final Color textPrimary = theme.textPrimaryColor;

    final Color background;
    final Color foreground;
    final Color border;
    switch (style) {
      case OhosButtonStyle.filled:
        // 禁用态不能靠「淡化填充 + 白字」表达：高亮色通常是深色，淡化到 20% 是
        // 浅底，白字压在上面几乎看不见。策略把这种「托不住形体的浅底」判成
        // 透明，于是自动落到下面的描边分支，与 outlined 同一套。
        //
        // 真机背景：NoteAir 变更抽屉在没有暂存文件时，「提交 (0)」按钮看不见。
        background = dimmed ? policy.tint(highlight, 0.20) : highlight;
        // 不能写死 `Colors.white`：深色墨水屏的 `highlightColor` 是纸白，
        // 白底再压白字就整颗字消失。反白色由主题给 —— 浅色/深色彩屏是白色，
        // 白纸墨屏是纸白，深色墨屏是纸黑。
        foreground = dimmed ? theme.textTertiaryColor : theme.onHighlightColor;
        border = dimmed && background.a == 0
            ? policy.line(theme.textTertiaryColor, 1)
            : Colors.transparent;
      case OhosButtonStyle.tonal:
        background = policy.tint(highlight, dimmed ? 0.06 : 0.12);
        foreground = dimmed ? theme.textTertiaryColor : highlight;
        // 底色被策略判成透明（墨屏上 12% / 6% 看不见）时，补一条实线把轮廓留住
        border = background.a == 0
            ? policy.line(dimmed ? theme.textTertiaryColor : highlight, 1)
            : Colors.transparent;
      case OhosButtonStyle.outlined:
        background = Colors.transparent;
        foreground = dimmed ? theme.textTertiaryColor : highlight;
        // 50% / 40% 的线在 16 级灰上会淡掉，由策略统一换成实色
        border = policy.line(
          dimmed ? theme.textTertiaryColor : highlight,
          dimmed ? 0.4 : 0.5,
        );
      case OhosButtonStyle.text:
        background = Colors.transparent;
        foreground = dimmed ? theme.textTertiaryColor : highlight;
        border = Colors.transparent;
      case OhosButtonStyle.plain:
        // 基准色必须是**黑**而不是 cardColor：浅色档的 cardColor 就是白色，
        // 白 8% 铺在白页 / 白卡上等于没有（旧实现是 `0x14000000`，黑 8%，
        // 在浅底上是一块看得见的灰）。墨水屏下 alpha ≤ 0.20 仍被判成透明，
        // 与旧行为一致，禁用态靠下面那条描边区分。
        background = dimmed
            ? policy.tint(const Color(0xFF000000), 0.08)
            : theme.cardColor;
        foreground = dimmed ? theme.textTertiaryColor : textPrimary;
        // 彩屏的 plain 是「白底 + 发丝线」，禁用时连那条线也淡掉；极浅的底
        // 在灰阶屏上等于没有，策略把线换成实色，靠线留住轮廓。
        border = dimmed
            ? policy.line(theme.textTertiaryColor, 0.2)
            : policy.line(theme.textTertiaryColor, 0.4);
    }

    // 三个形状共用同一条边：宽度换算与「画在盒内」都走 ohosBorderSide
    final BorderSide borderSide = ohosBorderSide(context, border);

    // 无底色 + 无边框的文字按钮，在灰阶屏上与正文同色（ink 主题的
    // highlightColor 和 textPrimaryColor 都是纯黑），读者分不出哪个能点。
    // 下划线不是装饰，是这块屏上唯一剩下的可供性线索 —— 交给策略判断，
    // 因为「要不要划线」取决于这块屏的其他线索够不够，不是取决于描边宽度。
    final bool underline =
        style == OhosButtonStyle.text &&
        !dimmed &&
        theme.policy.underlinesTextActions;

    final Widget label = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              // 同一个坑：深色墨屏下 filled 的底是纸白，写死白色的转圈会跟着
              // 消失（真机上「加载中」只剩一枚空药丸）。
              color: style == OhosButtonStyle.filled
                  ? theme.onHighlightColor.withValues(alpha: 0.7)
                  : highlight,
            ),
          )
        : DefaultTextStyle.merge(
            style: (theme.typography.labelLarge ?? const TextStyle(fontSize: 16))
                .copyWith(
                  // 字号跟随 controlSize：NORMAL 16 / SMALL 12（官方
                  // button_font_size / small_button_font_size）。
                  fontSize: controlSize.fontSize,
                  color: foreground,
                  // 两个分支都显式写 `decoration`：`DefaultTextStyle.merge`
                  // 只覆盖非 null 字段，写 null 等于把祖先的 decoration
                  // 放行下来。Material 3 的默认 DefaultTextStyle 恰好是
                  // `TextDecoration.none`，所以彩屏看着没问题 —— 那是巧合，
                  // 不是保证。可供性既然归按钮判断，就不该外泄给祖先。
                  decoration: underline
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  // `decorationColor` 同理，**也必须两个分支都给值**。
                  //
                  // 这里曾经写成 `decorationColor: underline ? foreground : null`，
                  // 于是三个字段只有这一个漏了：`decoration` 已经是 none，
                  // 祖先把我们的橙黄 `decorationColor` 递了下来。flutter_test
                  // 的默认 `DefaultTextStyle` 恰好带 `decorationColor = #FFFF00`
                  // （纯黄）—— 那是测试框架给「不该有下划线却有了」留的视觉
                  // 警报色。结果：墨屏对话框的标题与正文各带一条**黄线**，
                  // 而所有断言（都只查 `decoration`）全绿。
                  //
                  // 真机不显形，是因为 Material 3 的 `decorationColor` 是正文色，
                  // 即使下划线被关掉也看不出来。**「彩屏看着没问题」在这里第二次
                  // 掩盖了同一个缺陷**：前一次是 `decoration`（注释已记录），
                  // 这一次是它的兄弟字段。所以不再走「靠祖先恰好对我有利」这条
                  // 路，直接给中性值。
                  decorationColor: underline ? foreground : Colors.transparent,
                  decorationStyle: underline ? TextDecorationStyle.solid : null,
                ),
            // 按钮标签按惯例是单行：给 Text 默认省略号，配合上面的
            // Flexible 收缩，窄容器不会再报 overflow。
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: child ?? const SizedBox.shrink(),
          );

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!loading && icon != null) ...<Widget>[
          IconTheme.merge(
            data: IconThemeData(color: foreground, size: 20),
            child: icon!,
          ),
          const SizedBox(width: 8),
        ],
        // Flexible + 单行省略：窄容器（抽屉里的 3:2 双按钮、200vp 小窗）里
        // label 自己收缩，而不是整行 RenderFlex overflow。
        Flexible(child: label),
      ],
    );

    // circle 里没有「图标 + 间距 + 文字」的横向排布 —— 复用上面的 Row 会带上
    // 那 8vp 间距，纯图标时图标被推偏 4vp、看上去不在圆心。这里只取一个元素。
    final Widget circleContent = loading
        ? label
        : (icon != null
              ? IconTheme.merge(
                  data: IconThemeData(color: foreground, size: 20),
                  child: icon!,
                )
              : label);

    // 按钮的按压反馈是整块底板换一档色，不是 Material 那种从触点扩散、再淡出
    // 的圆形高光。官方的按钮按下态就是 `bg_color_clicked_blend` 压在整块底上，
    // 形状与按钮自身一致 —— 涟漪那圈圆斑在 448vp 宽的药丸上尤其明显。
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: switch (shape) {
          OhosButtonShape.capsule => BorderRadius.circular(
            OhosGeometry.radiusCapsule,
          ),
          OhosButtonShape.rounded => BorderRadius.circular(effectiveCorner),
          OhosButtonShape.circle => BorderRadius.circular(circleDiameter / 2),
        },
        // 判 `border` 而不是 `borderSide.width`：后者恒为 1，照它判会给每个
        // 按钮都描一圈（`border` 是透明时那圈看不见，但会占掉 1vp 内容宽度）。
        border: border.a > 0 ? Border.fromBorderSide(borderSide) : null,
        boxShadow:
            style == OhosButtonStyle.filled &&
                !dimmed &&
                theme.policy.allowsShadow
            ? <BoxShadow>[
                BoxShadow(
                  color: highlight.withValues(alpha: 0.25),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: OhosPressFeedback(
        onTap: interactive ? onPressed : null,
        borderRadius: switch (shape) {
          OhosButtonShape.capsule => BorderRadius.circular(
            OhosGeometry.radiusCapsule,
          ),
          OhosButtonShape.rounded => BorderRadius.circular(effectiveCorner),
          OhosButtonShape.circle => BorderRadius.circular(circleDiameter / 2),
        },
        // 实心按钮的底是品牌色，官方按下态是**压亮**而不是压暗（`blend_white`
        // 一档），所以这里用白而不是默认的 `interactive_click` 黑。
        pressedColor: style == OhosButtonStyle.filled
            ? Colors.white.withValues(alpha: 0.20)
            : null,
        // `maxWidth` 是**上限**，不是必然值，也压不过父级的紧约束：
        // `SizedBox(width: 700)` / `stretch` / 铺满整行的 `Column` 会把
        // `minWidth` 和 `maxWidth` 同时钉到 700，这里写 448 一样是 700 ——
        // 这不是这里的缺陷，是布局模型的定义（子节点不能小于父级给的紧约束）。
        //
        // 试过改成外层 `Align(widthFactor: 1)`：`RenderPositionedBox` 最后一步
        // 是 `constraints.constrain(child.size * factor)`，紧约束下照样夹回
        // 700。**没有 Widget 能在紧约束下变窄**，所以正确做法是：
        // 上限只负责「宽内容别撑成横幅」，容器铺满由调用方自己传宽度。
        child: ConstrainedBox(
          constraints: isCircle
              // 宽高都钉到直径：minWidth == maxWidth == 直径，content 无法再
              // 把宽度撑大；图标靠 Center 落在圆心。
              ? BoxConstraints(
                  minWidth: circleDiameter,
                  maxWidth: circleDiameter,
                  minHeight: circleDiameter,
                  maxHeight: circleDiameter,
                )
              : BoxConstraints(
                  minWidth: effectiveMinSize.width,
                  minHeight: effectiveMinSize.height,
                  maxWidth: maxWidth ?? OhosButtonMetrics.maxWidth,
                ),
          child: Padding(
            // circle 不吃水平文字内边距，只居中单个元素；其余形态保留官方 padding。
            padding: isCircle ? EdgeInsets.zero : effectivePadding,
            child: isCircle ? Center(child: circleContent) : content,
          ),
        ),
      ),
    );
  }
}
