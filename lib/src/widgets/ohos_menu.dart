import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';

/// Menu style of [showOhosMenu].
enum OhosMenuStyle { list, grid }

/// 菜单的官方几何，来自设计规范《菜单》的响应式布局段落。
class OhosMenuMetrics {
  const OhosMenuMetrics._();

  /// **泛手机统一宽度**（设计规范原文：「泛手机统一宽度为固定 224vp」）。
  ///
  /// 这是菜单最硬的一条规格：菜单不是「按内容自适应」的容器，而是一个固定
  /// 宽度的面板 —— 同一个菜单在不同条目数下宽度不变，用户按下几次都能预期
  /// 「菜单会占屏幕左侧三分之二」。
  ///
  /// 老实现交给 `PopupMenu` 自适应：一条 4 字菜单只有一百多 vp，宽窄随内容
  /// 跳变，与官方形态不同。
  static const double mobileWidth = 224;

  /// 电脑设备上的**最小**宽度（设计规范：「默认最小宽度 224vp，可配置菜单
  /// 最小宽度，但不得低于 64vp」）。
  ///
  /// 与手机不同：电脑上菜单随内容自适应，224 只是下限，且下限本身可调但不能
  /// 低于 64。这一档本库不做自动判定（`showOhosMenu` 拿不到设备类型），由
  /// 调用方通过 `minWidth` / `width` 表达。
  static const double desktopMinWidth = 224;

  /// 电脑上可配置的最小宽度下限（文档原文「不得低于 **64vp**」）。
  static const double desktopMinWidthFloor = 64;

  /// 内容区（文字、分割线）到菜单卡片**左缘 / 右缘**的水平内边距。
  /// **设计稿**：16vp（配图 `menu_12.png` 左右各一条 16 的横向量线）。
  ///
  /// 资源表里**没有菜单专用的这一项**。`divider_padding_horizontal = 16vp`
  /// 数值相同，但它是分割线的内边距、语义不同 —— 拿它当出处会让「哪天菜单改成
  /// 12vp」的人以为改分割线令牌就能带动菜单。
  ///
  /// 实测框架 `PopupMenuItem` 的默认水平内边距是 **12**（不是直觉里的 16），
  /// 所以此前每个条目都偏窄 4vp。这一条不是「值不对」，而是「值从来没被本库
  /// 声明过」—— 靠框架默认值就等于把规格交给 Flutter 版本。
  static const double contentPaddingHorizontal = 16;

  /// 条目的垂直内边距。**自拟**：官方《菜单》没有条目标高规格，这个值只用来
  /// 复现「条目总高 48vp」（单行文字 23vp + 上下各 12.5vp）。改它会让条目变高。
  static const double contentPaddingVertical = 12.5;

  /// 圆角（资源表 `menu_default_radius_token = 20.0vp`，与
  /// `ohos_id_corner_radius_menu = 20.0vp` 同一档）。
  ///
  /// 老实现取 `OhosGeometry.radiusMedium = 16` —— 那是卡片档，菜单官方比它
  /// 大一档。设计规范另写「2in1 = 8vp」，那是电脑设备风格，本库不做设备判定。
  static const double radius = 20;
}

/// Shows a rounded HarmonyOS menu anchored at a position (菜单 in the
/// HarmonyOS guideline).
///
/// Pass [anchor] (a [BuildContext] or [GlobalKey] of the triggering widget)
/// so the menu pops up right below the trigger; otherwise provide [position]
/// explicitly.
///
/// ```dart
/// await showOhosMenu<String>(
///   context: context,
///   anchor: buttonKey,
///   items: const [
///     OhosMenuItem(label: '复制', icon: Icons.copy, value: 'copy'),
///     OhosMenuItem(label: '删除', icon: Icons.delete, value: 'delete'),
///   ],
/// );
/// ```
Future<T?> showOhosMenu<T>({
  required BuildContext context,
  required List<OhosMenuItem<T>> items,
  RelativeRect? position,

  /// Menu style: a vertical list or a grid.
  OhosMenuStyle style = OhosMenuStyle.list,

  /// Widget to anchor the menu to — a [BuildContext] or [GlobalKey] of the
  /// triggering control. When provided the menu is positioned right below it.
  Object? anchor,

  /// 菜单宽度。null 时按手机规格的**固定 224vp**（见
  /// [OhosMenuMetrics.mobileWidth]）。
  ///
  /// 传 `double.infinity` 退回「跟随内容自适应」的老行为；电脑设备上要
  /// 「自适应但至少 224」就传 [minWidth] 而不是这个。
  double? width,

  /// 最小宽度。null 时不加下限。电脑设备按官方传
  /// [OhosMenuMetrics.desktopMinWidth]（可调，但不低于
  /// [OhosMenuMetrics.desktopMinWidthFloor]）。
  double? minWidth,
}) {
  final OhosThemeData theme = OhosTheme.of(context);
  final RelativeRect rect =
      position ??
      _anchorRect(context, anchor) ??
      RelativeRect.fromLTRB(16, 120, 16, 16);
  return showMenu<T>(
    context: context,
    position: rect,
    color: theme.popupColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(OhosMenuMetrics.radius),
      // 彩屏保持发丝级，墨水屏按 1px 算；宽度换算与「画在盒内」都收在
      // ohosBorderSide 里
      side: ohosBorderSide(
        context,
        theme.dividerColor,
        width: theme.outlineWidth,
      ),
    ),
    elevation: 8,
    // 固定宽 / 最小宽都由 `PopupMenu` 的约束层承担：它给内层的是
    // `constraints`，所以条目里的 `Row` / `Wrap` 拿到的就是最终宽，不用逐条
    // 去钉 `SizedBox`。
    constraints: _menuConstraints(width: width, minWidth: minWidth),
    items: <PopupMenuEntry<T>>[
      if (style == OhosMenuStyle.grid)
        PopupMenuItem<T>(
          enabled: false,
          child: Wrap(
            spacing: OhosGeometry.spaceMd,
            runSpacing: OhosGeometry.spaceSm,
            children: <Widget>[
              for (final OhosMenuItem<T> item in items)
                PopupMenuItem<T>(
                  value: item.value,
                  enabled: item.enabled,
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: OhosTheme.of(
                              context,
                            ).textPrimaryColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Icon(
                            item.icon ?? Icons.square_rounded,
                            size: 20,
                            color: item.danger
                                ? OhosTheme.of(context).dangerColor
                                : OhosTheme.of(context).textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OhosTheme.of(context).typography.labelSmall
                              ?.copyWith(
                                color: item.danger
                                    ? OhosTheme.of(context).dangerColor
                                    : OhosTheme.of(context).textPrimaryColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        )
      else
        for (final OhosMenuItem<T> item in items)
          PopupMenuItem<T>(
            value: item.value,
            enabled: item.enabled,
            // 左右 16vp 是设计稿规格；不吃框架默认（实测 12，会把内容挤窄）。
            padding: const EdgeInsets.symmetric(
              horizontal: OhosMenuMetrics.contentPaddingHorizontal,
              vertical: OhosMenuMetrics.contentPaddingVertical,
            ),
            child: Row(
              children: <Widget>[
                if (item.icon != null) ...<Widget>[
                  Icon(
                    item.icon,
                    size: 18,
                    color: item.danger
                        ? OhosTheme.of(context).dangerColor
                        : OhosTheme.of(context).textSecondaryColor,
                  ),
                  const SizedBox(width: 12),
                ],
                // 菜单宽度是固定的（手机 224vp），条目文案长度不可控 —— 必须
                // 省略号收尾。裸 `Text` 会 `RenderFlex overflowed`，而且溢出
                // 是 4vp 级的，肉眼几乎看不出来，只有断言能抓住。
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OhosTheme.of(context).typography.bodyMedium
                        ?.copyWith(
                          color: item.danger
                              ? OhosTheme.of(context).dangerColor
                              : OhosTheme.of(context).textPrimaryColor,
                        ),
                  ),
                ),
              ],
            ),
          ),
    ],
  );
}

/// 菜单的宽高约束。
///
/// `width` 与 `minWidth` 互斥：给了 `width` 就锁死（手机固定 224），给了
/// `minWidth` 就先保底再跟随内容（电脑）。都没给时默认走手机规格 ——
/// `showOhosMenu` 拿不到设备类型，而手机是主场景。
BoxConstraints? _menuConstraints({double? width, double? minWidth}) {
  final double w = width ?? OhosMenuMetrics.mobileWidth;
  if (!w.isFinite) {
    // `double.infinity` = 调用方显式要求「跟随内容自适应」（老行为）。
    return minWidth == null
        ? null
        : BoxConstraints(minWidth: minWidth, maxWidth: double.infinity);
  }
  final double min = minWidth ?? 0;
  return BoxConstraints(minWidth: w, maxWidth: w < min ? min : w);
}

/// Computes a [RelativeRect] that anchors the menu below the widget
/// referenced by [anchor] (a [BuildContext] or a [GlobalKey]). Falls back to
/// `null` when the anchor cannot be resolved.
RelativeRect? _anchorRect(BuildContext context, Object? anchor) {
  BuildContext? anchorContext;
  if (anchor is BuildContext) {
    anchorContext = anchor;
  } else if (anchor is GlobalKey) {
    anchorContext = anchor.currentContext;
  }
  if (anchorContext == null) {
    return null;
  }
  final RenderBox? box = anchorContext.findRenderObject() as RenderBox?;
  final RenderBox? overlay =
      Overlay.maybeOf(context, rootOverlay: true)?.context.findRenderObject()
          as RenderBox?;
  if (box == null || overlay == null || !box.hasSize) {
    return null;
  }
  final Offset topLeft = box.localToGlobal(Offset.zero);
  final Offset bottomRight = box.localToGlobal(
    box.size.bottomRight(Offset.zero),
  );
  final double gap = 4;
  return RelativeRect.fromLTRB(
    topLeft.dx,
    bottomRight.dy + gap,
    overlay.size.width - bottomRight.dx,
    overlay.size.height - bottomRight.dy - gap,
  );
}

/// An entry of [showOhosMenu].
class OhosMenuItem<T> {
  const OhosMenuItem({
    required this.label,
    required this.value,
    this.icon,
    this.danger = false,
    this.enabled = true,
  });

  /// Display label.
  final String label;

  /// Value returned when the item is selected.
  final T value;

  /// Optional leading icon.
  final IconData? icon;

  /// When true the label is tinted with the danger color.
  final bool danger;

  /// When false the item cannot be selected.
  final bool enabled;
}
