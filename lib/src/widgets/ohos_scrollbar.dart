import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// 滚动条的官方几何，出自系统资源表 `float.json` 的 `ohos_scroll_bar_pattern`
/// 一组，以及设计规范《滚动条》正文与图注。
class OhosScrollbarMetrics {
  const OhosScrollbarMetrics._();

  /// 静止时的条宽（`ohos_id_scroll_bar_normal_width = 4vp`）。
  ///
  /// 设计规范图注：**「滚动条宽度：4vp，距离屏幕/窗口边缘 4vp」**。
  /// 老实现取 8 —— 那是 Material 的默认厚度，比官方粗一倍。
  static const double width = 4;

  /// 按下 / 拖拽时的条宽（`ohos_id_scroll_bar_active_width = 8vp`）。
  ///
  /// **本库目前没有实现「激活加粗」**，原因见 [activeWidthUnsupported]。
  static const double activeWidth = 8;

  /// 拇指最小长度（`ohos_id_scroll_bar_min_height = 48vp`）。
  ///
  /// 图注：「**未激活** 高度随内容自动计算，**最小高度 48vp**」。
  /// `RawScrollbar` 的 `minThumbLength` 默认 18 —— 内容很长时拇指缩成一小段，
  /// 既抓不住，也看不出「我现在在全文的哪个位置」。
  static const double minThumbLength = 48;

  /// 与屏幕 / 窗口边缘的距离（设计规范图注「距离屏幕/窗口边缘 4vp」）。
  static const double edgeMargin = 4;

  /// 无操作后多久淡出（设计规范正文「无任何操作，**2 秒后消失**」）。
  ///
  /// `RawScrollbar` 的 `timeToFade` 默认 600ms —— 手指刚离开拇指它就没了，
  /// 用户来不及确认拖到哪。
  static const Duration timeToFade = Duration(seconds: 2);

  /// 为什么做不到「按下时加粗到 8vp」。
  ///
  /// `RawScrollbar` 只对外暴露 `pressDuration`（长按多少毫秒起拖），**没有**
  /// `onThumbPress` 这类回调可以通知宿主「现在手指在拇指上」。要加粗只能：
  ///
  /// 1. 在外面套一层 `Listener`，用 `hitTestOnlyThumbInteractive` 自己判位置
  ///    —— 那是 `ScrollbarPainter` 的内部状态，拿不到；
  /// 2. 或者按坐标猜「右侧 30vp 内按下 = 按住滚动条」—— 猜不准，还会把
  ///    「列表右边缘的按钮」误判成按住滚动条。
  ///
  /// 所以本库只实现静止宽度 4vp。**这是明确的功能缺口，不是已经对齐**：
  /// 表现是「拖拽时拇指不会变粗」，用户感知较弱，优先级低于热区与拇指引脚。
  static const String activeWidthUnsupported =
      'RawScrollbar 无拇指按压回调，激活加粗（8vp）未实现';

  /// 触屏命中带的实际宽度（官方要求 **32vp**）。
  ///
  /// **这个数算得出、改不了**：`RawScrollbarState.hitTestInteractive` 把半径
  /// 写死成 `_kMinInteractiveSize / 2 = 24`：
  ///
  /// ```dart
  /// paddedRect = interactiveRect.expandToInclude(
  ///   Rect.fromCircle(center: _thumbRect!.center, radius: 24),
  /// );
  /// ```
  ///
  /// 拇指中轴线距窗口右沿 `edgeMargin + width / 2 = 6`，命中带因此从
  /// `窗口宽 − (24 + 6)` 起算，宽 **30vp**（老实现贴边、条宽 8，恰好 32）。
  ///
  /// 补回那 2vp 只有两条路 —— 把条推离边缘到 2vp（违反「距边缘 4vp」），
  /// 或自己实现整套滚动条手势（拖拽 / 轨道点击 / 嵌套滚动 / 惯性全在手势层
  /// 里，等于重写 `RawScrollbar`）。**两者都比 2vp 贵**，所以本库取 30vp
  /// 并留痕，不假装做到了 32。
  static double get touchWidth => 24 + edgeMargin + width / 2;
}

/// A scrollbar with HarmonyOS-styled rounded thumb, the counterpart of
/// Flutter's [Scrollbar].
///
/// 与 `RawScrollbar` 默认值的三处差异，全部有官方出处（见
/// [OhosScrollbarMetrics]）：条宽 4vp 而不是 8vp、拇指最小 48vp 而不是 18vp、
/// 无操作 2 秒后淡出而不是 0.6 秒。拇指距窗口右沿 4vp。
///
/// 未实现「按下加粗到 8vp」与「热区 32vp」，两处的原因都在
/// [OhosScrollbarMetrics] 里写清了，不再重复。
class OhosScrollbar extends StatelessWidget {
  const OhosScrollbar({
    super.key,
    required this.controller,
    required this.child,
    this.thumbColor,
    this.thickness = OhosScrollbarMetrics.width,
    this.minThumbLength = OhosScrollbarMetrics.minThumbLength,
    this.edgeMargin = OhosScrollbarMetrics.edgeMargin,
    this.thumbRadius,
    this.thumbVisibility,
  });

  /// Scroll controller attached to the scrollable child.
  final ScrollController controller;

  /// The scrollable widget.
  final Widget child;

  /// Thumb color; defaults to a 30% primary-text tint.
  final Color? thumbColor;

  /// 条宽（官方静止态 4vp）。
  final double thickness;

  /// 拇指的最小长度（官方 48vp）。传 0 关闭下限。
  final double minThumbLength;

  /// 拇指与窗口右沿的距离（官方 4vp）。
  final double edgeMargin;

  /// 拇指圆角；null 时取「条宽的一半」，即胶囊形。
  final double? thumbRadius;

  /// 常驻显示（对应官方 `BarState.On`）。null 跟随 `ScrollbarThemeData`。
  final bool? thumbVisibility;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color color =
        thumbColor ?? theme.textPrimaryColor.withValues(alpha: 0.30);
    return RawScrollbar(
      controller: controller,
      thickness: thickness,
      radius: Radius.circular(thumbRadius ?? thickness / 2),
      thumbColor: color,
      minThumbLength: minThumbLength,
      timeToFade: OhosScrollbarMetrics.timeToFade,
      fadeDuration: const Duration(milliseconds: 300),
      thumbVisibility: thumbVisibility,
      // 与窗口右沿的间距。`padding` 而不是 `crossAxisMargin`：后者把轨道一起
      // 撑宽（`thickness + 2 * crossAxisMargin`），会在拇指两侧多画两条灰底。
      padding: EdgeInsets.only(right: edgeMargin),
      child: child,
    );
  }
}
