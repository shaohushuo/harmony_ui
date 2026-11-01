import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';

/// Visual variants of [OhosButton], mirroring ArkUI's button shapes.
enum OhosButtonShape {
  /// Fully rounded capsule (default).
  capsule,

  /// Large corner-radius square, e.g. 24vp.
  rounded,

  /// Perfect circle, typically for icon-only buttons.
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
    this.loading = false,
    this.minSize = const Size(48, 40),
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
  });

  /// Called when the button is tapped. When null the button is disabled.
  final VoidCallback? onPressed;

  /// The primary content, typically a [Text].
  final Widget? child;

  /// Optional leading icon.
  final Widget? icon;

  /// Emphasis level of the button.
  final OhosButtonStyle style;

  /// Shape of the button.
  final OhosButtonShape shape;

  /// Shows an inline spinner in place of [icon] and disables taps.
  final bool loading;

  /// Minimum size of the button.
  final Size minSize;

  /// Padding inside the button.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // loading 与「没有回调」是两件事：前者只是暂时不能点，视觉上仍是「正在
    // 干活」的主按钮；后者才是禁用。混在一个布尔里会让 filled + loading 落到
    // 禁用分支，而转圈的白色是写死的 —— 浅底白圈在 16 级灰上整块消失（真机：
    // NoteAir 上「加载中」按钮只剩一个空白药丸，连转圈都看不见）。
    final bool interactive = onPressed != null && !loading;
    final bool dimmed = onPressed == null && !loading;
    final bool ink = theme.monochrome;
    final Color highlight = theme.highlightColor;
    final Color textPrimary = theme.textPrimaryColor;

    final Color background;
    final Color foreground;
    final Color border;
    switch (style) {
      case OhosButtonStyle.filled:
        // 禁用态不能靠「淡化填充 + 白字」表达：高亮色通常是深色，淡化到 20% 是
        // 浅底，白字压在上面几乎看不见 —— 墨水屏预设里 highlightColor 就是纯黑，
        // 于是变成「#CCCCCC 底 + 白字」，16 级灰阶上整块消失（真机：NoteAir 变更
        // 抽屉在没有暂存文件时，「提交 (0)」按钮看不见）。
        //
        // 墨水屏上更进一步：20% 的浅底本身就留不住形状（同一份预设里已经为
        // 「10% 黑的分隔线」写过这句话），改成透明底 + 实线描边，与 outlined 同一套。
        background = dimmed
            ? (ink ? Colors.transparent : highlight.withValues(alpha: 0.20))
            : highlight;
        foreground = dimmed ? theme.textTertiaryColor : Colors.white;
        border = dimmed && ink ? theme.textTertiaryColor : Colors.transparent;
      case OhosButtonStyle.tonal:
        background = highlight.withValues(alpha: dimmed ? 0.06 : 0.12);
        foreground = dimmed ? theme.textTertiaryColor : highlight;
        // 12% / 6% 的底在墨水屏上同样看不见，补一条实线把轮廓留住
        border = ink ? (dimmed ? theme.textTertiaryColor : highlight) : Colors.transparent;
      case OhosButtonStyle.outlined:
        background = Colors.transparent;
        foreground = dimmed ? theme.textTertiaryColor : highlight;
        // 50% / 40% 的线在 16 级灰上会淡掉，墨水屏一律用实色
        border = ink
            ? (dimmed ? theme.textTertiaryColor : highlight)
            : (dimmed
                ? theme.textTertiaryColor.withValues(alpha: 0.4)
                : highlight.withValues(alpha: 0.5));
      case OhosButtonStyle.text:
        background = Colors.transparent;
        foreground = dimmed ? theme.textTertiaryColor : highlight;
        border = Colors.transparent;
      case OhosButtonStyle.plain:
        background = dimmed
            ? (ink ? Colors.transparent : const Color(0x14000000))
            : theme.cardColor;
        foreground = dimmed ? theme.textTertiaryColor : textPrimary;
        border = ink
            ? theme.textTertiaryColor
            : (dimmed
                ? theme.textTertiaryColor.withValues(alpha: 0.2)
                : theme.textTertiaryColor.withValues(alpha: 0.4));
    }

    // 三个形状共用同一条边：宽度换算与「画在盒内」都走 ohosBorderSide
    final BorderSide borderSide = ohosBorderSide(context, border);
    OutlinedBorder shapeBorder;
    switch (shape) {
      case OhosButtonShape.capsule:
        shapeBorder = StadiumBorder(side: borderSide);
      case OhosButtonShape.rounded:
        shapeBorder = RoundedRectangleBorder(
          side: borderSide,
          borderRadius: BorderRadius.circular(OhosGeometry.radiusLarge),
        );
      case OhosButtonShape.circle:
        shapeBorder = CircleBorder(side: borderSide);
    }

    final Widget label = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: style == OhosButtonStyle.filled
                  ? Colors.white70
                  : highlight,
            ),
          )
        : DefaultTextStyle.merge(
            style:
                (theme.typography.labelLarge ?? const TextStyle(fontSize: 16))
                    .copyWith(color: foreground),
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

    // 墨水屏（`monochrome`）与 `NoSplash` 主题下不闪水波纹：前者每次点按都会
    // 留一块半透明灰且刷新慢，后者是调用方显式关掉了 splash。
    final bool noSplash =
        theme.monochrome ||
        Theme.of(context).splashFactory == NoSplash.splashFactory;

    return Material(
      color: background,
      shape: shapeBorder,
      clipBehavior: Clip.antiAlias,
      elevation: style == OhosButtonStyle.filled && !dimmed ? 1 : 0,
      shadowColor: highlight.withValues(alpha: 0.25),
      child: InkWell(
        onTap: interactive ? onPressed : null,
        splashColor: noSplash
            ? Colors.transparent
            : Colors.white.withValues(
                alpha: style == OhosButtonStyle.filled ? 0.25 : 0.20,
              ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minSize.width,
            minHeight: minSize.height,
          ),
          child: Padding(padding: padding, child: content),
        ),
      ),
    );
  }
}
