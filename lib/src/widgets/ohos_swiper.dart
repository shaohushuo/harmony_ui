import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// Indicator style of an [OhosSwiper] — ArkUI's `DotIndicator` /
/// `DigitIndicator`.
enum OhosPageIndicatorType {
  /// `DotIndicator`: one dot per page, the current one stretched.
  dot,

  /// `DigitIndicator`: `当前/总数`, e.g. `3/8`.
  digit,
}

/// Navigation dots / digits of an [OhosSwiper] (导航点 in the HarmonyOS
/// guideline).
///
/// Official geometry, from `ts-container-swiper.md` plus the `sys.float`
/// tokens in `float.json`:
///
/// | what                     | value | source                              |
/// | ------------------------ | ----- | ----------------------------------- |
/// | dot width / height       | 6     | `itemWidth` / `itemHeight` default  |
/// | selected dot width       | 12    | `ohos_id_swiper_indicator_selected_size` |
/// | dot spacing              | 8     | `space` default (phone), `ohos_id_swiper_indicator_point_padding` |
/// | pressed scale            | 1.33  | `swiper_indicator_scale`            |
/// | digit font               | 14    | `digitFont` default                 |
///
/// **The selected dot is wider, not taller.** Official examples pass
/// `selectedItemWidth(16)` / `selectedItemHeight(8)` — the dot grows along the
/// main axis into a capsule. Height stays 6.
///
/// A caveat on the numbers: the reference says all four of `itemWidth` /
/// `itemHeight` / `selectedItemWidth` / `selectedItemHeight` default to 6,
/// while the resource table has a dedicated `selected_size` of 12 and every
/// official sample sets the selected width larger than the normal one. 12 is
/// used here — matching the token and the rendered shape, not the prose. The
/// doc's own 6 is almost certainly a copy-paste of the first row.
class OhosPageIndicator extends StatelessWidget {
  const OhosPageIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    this.type = OhosPageIndicatorType.dot,
    this.activeColor,
    this.inactiveColor,
    this.dotSize,
    this.activeDotSize,
    this.spacing,
    this.digitSeparator = '/',
  });

  /// Number of pages.
  final int count;

  /// Index of the active page.
  final int currentIndex;

  /// Dots or digits.
  final OhosPageIndicatorType type;

  /// Color of the active dot; defaults to the theme highlight color.
  final Color? activeColor;

  /// Color of the inactive dots; defaults to 40% of the tertiary text color.
  final Color? inactiveColor;

  /// Diameter of an inactive dot; defaults to 6.
  final double? dotSize;

  /// Width of the active dot; defaults to 12.
  ///
  /// This is a **width**, not a diameter: the active dot is a 12×6 capsule.
  final double? activeDotSize;

  /// Gap between dots; defaults to 8.
  final double? spacing;

  /// Separator between current and total in [OhosPageIndicatorType.digit].
  final String digitSeparator;

  static const double _dotSize = 6;
  static const double _activeDotSize = 12;
  static const double _spacing = 8;
  static const double _digitFontSize = 14;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    switch (type) {
      case OhosPageIndicatorType.dot:
        return _buildDots(theme);
      case OhosPageIndicatorType.digit:
        return _buildDigits(theme);
    }
  }

  Widget _buildDots(OhosThemeData theme) {
    final double size = dotSize ?? _dotSize;
    final double activeWidth = activeDotSize ?? _activeDotSize;
    final double gap = spacing ?? _spacing;
    final Color active = activeColor ?? theme.highlightColor;
    final Color inactive =
        inactiveColor ?? theme.textTertiaryColor.withValues(alpha: 0.4);
    // 墨水屏上 `highlightColor` 与 `textPrimaryColor` 都是纯黑，靠颜色区分当前
    // 项等于什么都没做。圆点没有文字可以加粗，也没有边框可借 —— 长度是唯一
    // 剩下的线索，所以墨屏把选中点拉得更长（由 policy 给出比例）。
    final double inkStretch = theme.policy.allowsRipple ? 1.0 : 1.33;

    return Row(
      mainAxisSize: MainAxisSize.min,
      // 间距走 Row.spacing 而不是每颗点自带 margin：margin 会被算进点自身的
      // 尺寸（6 的点量出来是 6+8=14），而官方的 `space` 是**点与点之间**的
      // 距离，不是点的外扩。用 margin 还会把点击 / 命中区一起撑大。
      spacing: gap,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: OhosGeometry.durationShort,
            curve: OhosGeometry.spring,
            width: i == currentIndex ? activeWidth * inkStretch : size,
            height: size,
            decoration: BoxDecoration(
              color: i == currentIndex ? active : inactive,
              borderRadius: BorderRadius.circular(size / 2),
            ),
          ),
      ],
    );
  }

  Widget _buildDigits(OhosThemeData theme) {
    final Color color = activeColor ?? theme.textPrimaryColor;
    final TextStyle? base = theme.typography.bodyMedium;
    // 官方 digitFont 默认 14 / Normal，两条只差颜色 —— 与圆点不同，数字型
    // **不**加粗也不放大，靠 `selectedFontColor` 区分。两者默认色相同则完全
    // 看不出当前页，所以未选中项按 `inactiveColor` 降一档。
    final TextStyle style = (base ?? const TextStyle()).copyWith(
      fontSize: _digitFontSize,
      fontWeight: FontWeight.w400,
      color: color,
    );
    final TextStyle dimmed = style.copyWith(
      color: inactiveColor ?? theme.textSecondaryColor,
    );
    // 页从 1 数起：官方显示 `当前/总数`，不是下标。
    final int shown = count <= 0 ? 0 : (currentIndex + 1).clamp(1, count);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$shown', style: style),
        Text(digitSeparator, style: dimmed),
        Text('$count', style: dimmed),
      ],
    );
  }
}

/// A page swiper with navigation dots, matching the "轮播/导航点" control in
/// the HarmonyOS design guideline.
class OhosSwiper extends StatefulWidget {
  const OhosSwiper({
    super.key,
    required this.children,
    this.height,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.loop = true,
    this.indicator = true,
    this.indicatorType = OhosPageIndicatorType.dot,
    this.showArrows = false,
    this.onPageChanged,
    this.controller,
    this.clipRadius,
  });

  /// Page widgets.
  final List<Widget> children;

  /// Height of the swiper; defaults to the tallest child.
  final double? height;

  /// Automatically advance pages.
  final bool autoPlay;

  /// Interval between auto-play pages.
  final Duration autoPlayInterval;

  /// Whether the swiper loops back to the first page.
  final bool loop;

  /// Whether to show the page indicator.
  final bool indicator;

  /// Dots or digits — ArkUI's `indicator(DotIndicator | DigitIndicator)`.
  final OhosPageIndicatorType indicatorType;

  /// Whether to draw left/right arrow buttons — ArkUI's `displayArrow`.
  ///
  /// Defaults to **`false`**, matching `displayArrow`'s own default. Arrows are
  /// suppressed entirely when every page fits on screen (nothing to page to),
  /// per "Swiper视窗内显示所有子节点时…左右翻页箭头均不显示".
  final bool showArrows;

  /// Called when the active page changes.
  final ValueChanged<int>? onPageChanged;

  /// Optional page controller.
  final PageController? controller;

  /// Optional corner radius applied to every page. Wrap each page in a
  /// [ClipRRect] so the rounded corners stay intact while pages slide
  /// in/out of the viewport (otherwise the viewport's hard edge cuts the
  /// entering page into right angles).
  final BorderRadius? clipRadius;

  @override
  State<OhosSwiper> createState() => _OhosSwiperState();
}

class _OhosSwiperState extends State<OhosSwiper> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  /// `ArrowStyle` defaults: 32 background for the side-of-component variant,
  /// 24 for the side-of-indicator one, and 24 arrow when no background.
  static const double _arrowBackground = 32;
  static const double _arrowSize = 24;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        PageController(initialPage: widget.loop ? 50000 : 0);
    if (widget.autoPlay && widget.children.length > 1) {
      _timer = Timer.periodic(widget.autoPlayInterval, (_) => _tick());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(OhosSwiper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoPlay != oldWidget.autoPlay ||
        widget.autoPlayInterval != oldWidget.autoPlayInterval) {
      _timer?.cancel();
      _timer = widget.autoPlay && widget.children.length > 1
          ? Timer.periodic(widget.autoPlayInterval, (_) => _tick())
          : null;
    }
  }

  void _tick() {
    if (!mounted || widget.children.isEmpty) {
      return;
    }
    final int next = (_index + 1) % widget.children.length;
    _controller.animateToPage(
      widget.loop ? (_controller.page ?? 0).round() + 1 : next,
      duration: OhosGeometry.durationMedium,
      curve: OhosGeometry.easeOut,
    );
  }

  void _step(int delta) {
    if (widget.children.length < 2) {
      return;
    }
    if (widget.loop) {
      _controller.animateToPage(
        (_controller.page ?? 0).round() + delta,
        duration: OhosGeometry.durationMedium,
        curve: OhosGeometry.easeOut,
      );
      return;
    }
    final int target = (_index + delta).clamp(0, widget.children.length - 1);
    if (target == _index) {
      return;
    }
    _controller.animateToPage(
      target,
      duration: OhosGeometry.durationMedium,
      curve: OhosGeometry.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = widget.children;
    if (pages.isEmpty && !widget.indicator) {
      return const SizedBox.shrink();
    }
    // 「一屏放得下就没得翻」——官方在无导航点 / 只有一页时都不画箭头。
    final bool arrows = widget.showArrows && pages.length > 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              PageView.builder(
                controller: _controller,
                itemCount: widget.loop ? null : pages.length,
                onPageChanged: (int index) {
                  setState(() => _index = index % pages.length);
                  widget.onPageChanged?.call(index % pages.length);
                },
                itemBuilder: (BuildContext context, int index) {
                  final Widget page = pages[index % pages.length];
                  final BorderRadius? radius = widget.clipRadius;
                  if (radius == null) {
                    return page;
                  }
                  return ClipRRect(
                    borderRadius: radius,
                    clipBehavior: Clip.antiAlias,
                    child: page,
                  );
                },
              ),
              if (arrows) ...<Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: _SwiperArrow(
                    icon: Icons.chevron_left,
                    backgroundSize: _arrowBackground,
                    iconSize: _arrowSize,
                    onPressed: () => _step(-1),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _SwiperArrow(
                    icon: Icons.chevron_right,
                    backgroundSize: _arrowBackground,
                    iconSize: _arrowSize,
                    onPressed: () => _step(1),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.indicator)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OhosPageIndicator(
              count: pages.length,
              currentIndex: _index,
              type: widget.indicatorType,
            ),
          ),
      ],
    );
  }
}

/// `ArrowStyle.isSidebarMiddle: true` variant — the arrow sits on the swiper
/// body with a translucent disc behind it.
class _SwiperArrow extends StatelessWidget {
  const _SwiperArrow({
    required this.icon,
    required this.backgroundSize,
    required this.iconSize,
    required this.onPressed,
  });

  final IconData icon;
  final double backgroundSize;
  final double iconSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // 官方 `showBackground: true` + `isSidebarMiddle: true` 的默认值：
    // 底板 32、底板色 `#19182431`（约 10% 黑）、箭头取底板 3/4。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Semantics(
        button: true,
        child: Material(
          // 官方底板色 `#19182431`（约 10% 黑）。走 policy.tint：墨屏上 10%
          // 落在第 0–1 级灰、铺在白底上等于不存在，tint 会返回透明，此时靠
          // 图标本身 + 1px 外圈表达「这里有个可按的圆」。
          color: theme.policy.tint(theme.textPrimaryColor, 0.10),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: backgroundSize,
              height: backgroundSize,
              child: IconTheme.merge(
                data: IconThemeData(
                  size: iconSize * 3 / 4,
                  color: theme.textPrimaryColor,
                ),
                child: Icon(icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}