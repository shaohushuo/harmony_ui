import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// 即时反馈的官方几何，出处分三层：设计规范《即时反馈》、系统资源表
/// `float.json` 的 `ohos_toast_pattern` 一组、参考文档 `ShowToastOptions`。
class OhosToastMetrics {
  const OhosToastMetrics._();

  /// 最大宽度上限（设计规范：「当控件最大拉伸到 **400 vp** 宽度时不再跟随
  /// 放大」）。
  ///
  /// 老实现写死 320 —— 官方规格里没有这个数。差别在 360vp 屏上是
  /// 「铺满 vs 留白」：320 加两侧各 20 的内边距就到 360，正好顶满整屏。
  static const double maxWidth = 400;

  /// 与窗口两侧的安全距离（设计规范把最大宽度定义为「窗口或屏幕宽度 −
  /// **两侧 Margin**」；`pattern.json` 里对应 `toast_margin_left/right` →
  /// `$float:margin_left/right`，两值都是 **16vp**）。
  static const double sideMargin = 16;

  /// 文本上下左右的安全距离。
  ///
  /// **这里有一处容易抄错的坑**：设计规范正文只在「智能穿戴即时反馈」段落写
  /// 「文本上下左右安全距离：10vp」，手机规格没有这一条。手机的真值是资源表：
  ///
  /// * `toast_padding_horizontal_api_twelve = toast_padding_level8 = 16.0vp`
  /// * `toast_padding_vertical_api_twelve = toast_padding_level4 = 8.0vp`
  ///
  /// 老实现 20 / 14 是自选的整数，与两者都不符。取 16 / 8。
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );

  /// 最小高度（`ohos_id_toast_content_min_height = 36vp`）。
  static const double minHeight = 36;

  /// 圆角（`toast_border_radius_old = toast_border_radius_new = 18vp`）。
  ///
  /// 老实现 28 —— 28 是 Material 的 `SnackBar` 圆角，不是 HarmonyOS 的。
  static const double radius = 18;

  /// 距窗口底部的默认高度（设计规范图注：「弹出位置距离底部 **80vp**」，
  /// 资源表 `ohos_id_toast_bottom = 80.0vp`）。
  static const double bottomOffset = 80;

  /// 距顶部的默认高度（`toast_top_new = 0.0vp` —— 官方顶对齐贴住安全区）。
  static const double topOffset = 0;

  /// 实际可用最大宽度：`min(400, 窗口宽 − 两侧 16)`。
  ///
  /// **400 是上限，不是必然值** —— 与 `OhosAlertDialog` / `OhosPopup` 同一个
  /// 道理。窄屏上直接给 400 会让气泡溢出两侧。
  static double maxWidthFor(Size screen) =>
      math.min(maxWidth, screen.width - sideMargin * 2);
}

/// Position of an [showOhosToast] message.
enum OhosToastPosition {
  /// 顶部（官方 `ToastShowMode.TOP`）。
  top,

  /// 默认位置（官方 `ToastShowMode.DEFAULT`，距底 80vp）。
  bottom,

  /// 居中。官方没有这一档，是给「弹窗里的二次确认」这类局部场景留的。
  center,
}

/// Shows a transient toast message (即时反馈 in the HarmonyOS guideline).
///
/// ```dart
/// showOhosToast(context, '操作成功');
/// ```
///
/// 宽度、内边距、圆角、位置四处的官方出处见 [OhosToastMetrics]。
void showOhosToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
  OhosToastPosition position = OhosToastPosition.bottom,
  IconData? icon,
}) {
  final OverlayState overlay = Overlay.of(context);
  final OhosThemeData theme = OhosTheme.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) {
      return _OhosToastOverlay(
        message: message,
        icon: icon,
        theme: theme,
        position: position,
        onDismissed: () => entry.remove(),
      );
    },
  );
  overlay.insert(entry);
  Future<void>.delayed(duration, () {
    if (entry.mounted) entry.remove();
  });
}

class _OhosToastOverlay extends StatelessWidget {
  const _OhosToastOverlay({
    required this.message,
    required this.icon,
    required this.theme,
    required this.position,
    required this.onDismissed,
  });

  final String message;
  final IconData? icon;
  final OhosThemeData theme;
  final OhosToastPosition position;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final double maxWidth = OhosToastMetrics.maxWidthFor(
      MediaQuery.sizeOf(context),
    );
    return SafeArea(
      child: Align(
        // 底部时贴底留 80vp；顶部时贴安全区；居中时居中。
        alignment: switch (position) {
          OhosToastPosition.top => Alignment.topCenter,
          OhosToastPosition.bottom => Alignment.bottomCenter,
          OhosToastPosition.center => Alignment.center,
        },
        child: Padding(
          padding: EdgeInsets.only(
            top: position == OhosToastPosition.top
                ? OhosToastMetrics.topOffset
                : 0,
            bottom: position == OhosToastPosition.bottom
                ? OhosToastMetrics.bottomOffset
                : 0,
            left: OhosToastMetrics.sideMargin,
            right: OhosToastMetrics.sideMargin,
          ),
          child: IgnorePointer(
            // 浮层形态与页面内形态是**同一个组件**：两处的宽度上限、内边距、
            // 圆角都只有一份实现，不会各自漂移。
            child: OhosToast(message: message, icon: icon, maxWidth: maxWidth),
          ),
        ),
      ),
    );
  }
}

/// 底板 + 内容。抽出来复用：页面内的 [OhosToast] 与浮层形态共用同一套规格。
class _ToastSurface extends StatelessWidget {
  const _ToastSurface({
    required this.theme,
    required this.icon,
    required this.message,
  });

  final OhosThemeData theme;
  final IconData? icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    // 彩屏用深色半透明底板（官方「沉浸光感」的极简替代）。灰阶屏上这层
    // 90% 的黑会化进纸色、变成一块边界读不出来的灰斑，得换成实底 + 描边。
    //
    // 判据走 `quantize` 而不是 `policy.isMonochrome`：后者是「按主题档位
    // 分支」，加一块屏就得回来改这里（`system_theme_test` 明令禁止）。这里
    // 问的是策略真正管的事 —— **这个颜色能否在你那块屏上原样表达**。彩屏
    // `quantize` 原样返回（相等），灰阶屏要合成到纸面并去饱和（必然不等）。
    const Color scrim = Color(0xE61A1A1A);
    final bool floats = theme.policy.quantize(scrim) == scrim;
    // 托得住就白字压深底；托不住换实底 `cardColor`（浅纸上的白）配正文色。
    final Color textColor = floats ? Colors.white : theme.textPrimaryColor;
    return Container(
      padding: OhosToastMetrics.padding,
      decoration: BoxDecoration(
        color: floats ? scrim : theme.cardColor,
        borderRadius: BorderRadius.circular(OhosToastMetrics.radius),
        border: floats ? null : Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              message,
              // 设计规范「先换行，默认最多 3 行」。
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              // 这个 Text 走的是根 Overlay，祖先里没有 `Material`：
              // `MaterialApp` 给这种位置兜底的 `_errorTextStyle` 是
              // 「红色 + monospace + 黄色双下划线」。`inherit: false` 一次
              // 断掉；字体族仍跟随主题，主题没设就用引擎默认。
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontFamily: theme.typography.fontFamily,
                decoration: TextDecoration.none,
                inherit: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A toast-style inline message used inside page layouts; see [showOhosToast]
/// for the overlay form.
///
/// 与浮层形态共用 [OhosToastMetrics]：宽度上限、内边距、圆角都一致，区别只在
/// 「谁来摆位置」。
class OhosToast extends StatelessWidget {
  const OhosToast({super.key, required this.message, this.icon, this.maxWidth});

  /// Message text.
  final String message;

  /// Optional leading icon.
  final IconData? icon;

  /// 最大宽度；null 时按官方「上限 400vp，再夹窗口宽 − 两侧 16vp」
  /// （见 [OhosToastMetrics.maxWidthFor]）。
  ///
  /// 浮层形态会在这里传入已夹好屏幕宽的值，页面内形态不传、由组件自己算。
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth:
            maxWidth ??
            OhosToastMetrics.maxWidthFor(MediaQuery.sizeOf(context)),
        minHeight: OhosToastMetrics.minHeight,
      ),
      child: _ToastSurface(
        theme: OhosTheme.of(context),
        icon: icon,
        message: message,
      ),
    );
  }
}
