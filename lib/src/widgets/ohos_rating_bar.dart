import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// 评分条的官方几何，全部取自系统资源表 `float.json`。
///
/// 与 `OhosDialogMetrics` 一样，这里不再往下追令牌 —— `ohos_id_rating_*`
/// 就是带明文数值的那一层。
class OhosRatingMetrics {
  const OhosRatingMetrics._();

  /// 星数默认值（`ohos_id_rating_start_num = 5`，文档 `stars` 默认 5）。
  static const int starCount = 5;

  /// 步长默认值（`ohos_id_rating_step_size = 0.5`）。
  ///
  /// 文档 `stepSize` 把区间写成 `[0.1, stars]`，小于 0.1 按默认值处理 ——
  /// 也就是说 0.5 是**可用的最小粒度基准**，半星（2.5 星）必须表达得出。
  static const double stepSize = 0.5;

  /// 可交互时单颗星的边长（`ohos_id_rating_big_height = 28vp`）。
  ///
  /// 官方把组件宽写成 `height * stars`（28 × 5 = 140），即星与星之间没有
  /// 额外间隙；间距是星图内部的留白，不是布局空隙。
  static const double starSize = 28;

  /// `indicator: true` 时单颗星的边长（`ohos_id_rating_mini_height = 12vp`）。
  static const double indicatorStarSize = 12;
}

/// A star rating bar (评分条 in the HarmonyOS guideline).
///
/// ```dart
/// OhosRatingBar(
///   value: rating,
///   onChanged: (double v) => setState(() => rating = v),
/// )
/// ```
///
/// 三条与官方一致的行为：
///
/// * **分值可半星** —— `value` 是 `double`，写入时按 [stepSize] 规整（四舍五入
///   到最近的整数倍），与官方「设置的评分值会规整到 stepSize 的整数倍」一致；
/// * **点击位置决定分值** —— 点在第 3 颗星的左半边是 2.5、右半边是 3.0，
///   而不是「点第几颗就是几星」；
/// * **再点一次不会清零** —— 官方没有「取消评分」这个语义，老实现里
///   `i == value ? i - 1 : i` 是自加的，会让用户误触后丢掉整条评分。
class OhosRatingBar extends StatelessWidget {
  const OhosRatingBar({
    super.key,
    required this.value,
    this.onChanged,
    this.count = OhosRatingMetrics.starCount,
    this.stepSize = OhosRatingMetrics.stepSize,
    this.indicator = false,
    this.starSize,
    this.activeColor,
    this.inactiveColor,
    this.activeIcon,
    this.inactiveIcon,
  });

  /// 当前评分，取值 `[0, count]`。
  ///
  /// 与老版本（`int`）的差别：官方 `stepSize` 默认 0.5，`int` 根本表达不出
  /// 半星。`value: 3` 这类整数字面量仍能直接编译（Dart 的 int→double 字面量
  /// 转换），只有「把一个 `int` 变量直接传进来」的调用点需要改。
  final double value;

  /// 评分变化时回调，参数是**规整到 [stepSize] 整数倍**后的新值。
  ///
  /// null 表示只读 —— 与官方 `indicator: true` 等价（两者都是「不能改分」，
  /// 差别只在默认星径，见 [indicator]）。
  final ValueChanged<double>? onChanged;

  /// 总星数（官方 `stars`，默认 5）。
  final int count;

  /// 步长。写入时会把结果四舍五入到它的整数倍。
  ///
  /// 小于 0.1 时按 0.5 处理 —— 官方文档「设置为小于 0.1 的值时，按默认值
  /// 显示」。
  final double stepSize;

  /// 指示器形态（官方 `indicator`）：不可交互，星径默认缩到 12vp。
  ///
  /// 传了 [onChanged] 时以交互为准 —— 一个「能点却宣称只读」的组合没有
  /// 合理语义。
  final bool indicator;

  /// 单颗星的边长；null 时按 [indicator] 取 28 或 12。
  final double? starSize;

  /// 已选中星的颜色；默认主题警告色。
  final Color? activeColor;

  /// 未选中星的颜色；默认主题三级文本色。
  final Color? inactiveColor;

  /// 替换「已选中」的图形（官方 `starStyle.foregroundUri`）。
  ///
  /// 官方用三张图（选中 / 未选中 / 半选）表达分档。Flutter 侧不需要第三张：
  /// 半星由 [ClipRect] 按比例裁切已选中图形得到，换任何图形都适用。
  final Widget? activeIcon;

  /// 替换「未选中」的图形（官方 `starStyle.backgroundUri`）。
  final Widget? inactiveIcon;

  bool get _interactive => onChanged != null;

  /// 把 [value] 规整到步长的整数倍并夹进 `[0, count]`。
  ///
  /// 官方口径：「四舍五入到最近的整数倍」。`(v / step).round() * step` 在
  /// 浮点下会漂（0.5 的整数倍里 1.5000000000000002 这种值会渲染出 99.9% 的
  /// 宽度），所以最后按步长位数取整一次。
  double _normalize(double raw) {
    final double step = stepSize < 0.1 ? OhosRatingMetrics.stepSize : stepSize;
    final double clamped = raw.clamp(0.0, count.toDouble());
    final int steps = (clamped / step).round();
    final double snapped = steps * step;
    // 只保留 6 位小数：足够吃掉二进制浮点误差，又不会把 0.1 这类步长弄丢。
    return double.parse(
      snapped.toStringAsFixed(6),
    ).clamp(0.0, count.toDouble());
  }

  /// 单颗星的填充比例，`0` 空、`1` 满、中间是半星。
  ///
  /// 入参是**规整过**的分值：官方「实际显示值与 onChange 回调值均为规整后的
  /// 值」，所以绘制与写回共用同一个口径。少了这一步，调用方传 2.3 会画出
  /// 一条 30% 的窄条，而 `stepSize` 说粒度只有 0.5。
  double _fillFor(int index, double normalized) {
    final double filled = normalized - (index - 1);
    if (filled <= 0) {
      return 0;
    }
    return filled >= 1 ? 1 : filled;
  }

  void _select(int star, double localDx, double size) {
    final ValueChanged<double>? changed = onChanged;
    if (changed == null || size <= 0) {
      return;
    }
    final double step = stepSize < 0.1 ? OhosRatingMetrics.stepSize : stepSize;
    // 星内位置 → 颗内步数。`ceil` 让「点在右半格」直接落到该格的右边界，
    // 与官方「按箭头/触点的位置取最近的步」一致；下限一颗步长保证点了这颗
    // 星至少是它的起点 + 一格。
    final double fraction = (localDx / size).clamp(0.0, 1.0);
    final double withinStar = ((fraction / step).ceil() * step).clamp(
      step,
      1.0,
    );
    changed(_normalize(star - 1 + withinStar));
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final double size =
        starSize ??
        (indicator
            ? OhosRatingMetrics.indicatorStarSize
            : OhosRatingMetrics.starSize);
    final bool interactive = _interactive;
    final Color active = activeColor ?? theme.warningColor;
    final Color inactive = inactiveColor ?? theme.textTertiaryColor;
    final Widget emptyStar =
        inactiveIcon ??
        Icon(Icons.star_outline_rounded, size: size, color: inactive);
    final Widget fullStar =
        activeIcon ?? Icon(Icons.star_rounded, size: size, color: active);
    final double normalized = _normalize(value);

    // 官方尺寸是 height × stars：星与星紧贴，不留 Row 级别的间隙。
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 1; i <= count; i++)
          _Star(
            size: size,
            fill: _fillFor(i, normalized),
            empty: emptyStar,
            full: fullStar,
            onTapDown: interactive ? (double dx) => _select(i, dx, size) : null,
            semanticLabel: '$i',
          ),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({
    required this.size,
    required this.fill,
    required this.empty,
    required this.full,
    required this.onTapDown,
    required this.semanticLabel,
  });

  final double size;
  final double fill;
  final Widget empty;
  final Widget full;
  final ValueChanged<double>? onTapDown;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    // 半星：先画底图，再把顶图按「填充比例」裁出来。
    //
    // 用 `Align(widthFactor: fill)` 而不是 `ClipRect(clipper:)` —— 本库的
    // 目标是「换图标也不用改代码」，而 `ClipRect` 需要事先知道子节点尺寸；
    // `Align` 在给子节点铺满高度的同时，把自身宽度收成 `fill × 宽`，外面
    // 套一层 `ClipRect` 就只留下左边那一截。填充为 0 / 1 时直接短路，避免
    // 每颗星都套两层剪切。
    Widget star;
    if (fill >= 1) {
      star = full;
    } else if (fill <= 0) {
      star = empty;
    } else {
      star = ClipRect(
        child: Stack(
          children: <Widget>[
            empty,
            Align(
              alignment: Alignment.centerLeft,
              widthFactor: fill,
              child: full,
            ),
          ],
        ),
      );
    }
    final Widget sized = SizedBox(width: size, height: size, child: star);
    if (onTapDown == null) {
      return sized;
    }
    return GestureDetector(
      // opaque：星与星之间没有空隙，整块区域都参与命中。少了它，
      // 图标外接框里的留白会漏给下层，触点略偏就变成「点了没反应」。
      behavior: HitTestBehavior.opaque,
      onTapDown: (TapDownDetails d) => onTapDown!(d.localPosition.dx),
      child: SizedBox(
        width: size,
        height: size,
        child: Semantics(label: semanticLabel, child: star),
      ),
    );
  }
}
