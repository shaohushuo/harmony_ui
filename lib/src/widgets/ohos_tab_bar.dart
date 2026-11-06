import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';
import 'ohos_chip_group.dart';

/// Visual style of an [OhosTabBar].
enum OhosTabBarType {
  /// Traditional underline style (下划线样式): the active tab carries a short
  /// brand-colored bar at its bottom edge.
  underline,

  /// Capsule style (胶囊样式): the active tab is filled with the brand color.
  capsule,
}

/// Divider (分割线) behaviour under the underline tab strip.
enum OhosTabBarDividerMode {
  /// The divider is always visible.
  visible,

  /// No divider.
  none,

  /// The divider fades in as the bound [ScrollController] scrolls from
  /// [followStartOffset] to [followEndOffset] (跟手滑动效果).
  followScroll,
}

/// Style options of the underline strip divider.
class OhosTabBarDividerOptions {
  const OhosTabBarDividerOptions({
    this.mode = OhosTabBarDividerMode.visible,
    this.color,
    this.strokeWidth = 1,
    this.startMargin = 0,
    this.endMargin = 0,
    this.followStartOffset = 0,
    this.followEndOffset = 20,
  });

  /// How the divider shows.
  final OhosTabBarDividerMode mode;

  /// Divider color; defaults to the theme divider color.
  final Color? color;

  /// Divider thickness.
  final double strokeWidth;

  /// Left margin of the divider line.
  final double startMargin;

  /// Right margin of the divider line.
  final double endMargin;

  /// Scroll offset range (vp) over which the follow-scroll divider fades in.
  final double followStartOffset;
  final double followEndOffset;
}

/// A HarmonyOS segmented tab strip, the counterpart of Material's
/// [TabBar].
///
/// - [OhosTabBarType.underline]: the classic ArkUI `Tabs/SubTabBarStyle` —
///   active tab underlined by a short (24x3vp) brand-colored indicator.
/// - [OhosTabBarType.capsule]: the `ChipGroup` look — active tab filled with
///   the brand color, idle tabs on the light-gray component background.
class OhosTabBar extends StatelessWidget implements PreferredSizeWidget {
  const OhosTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.height = 48,
    this.type = OhosTabBarType.underline,
    this.indicatorColor,
    this.backgroundColor,
    this.showDivider = false,
    this.divider,
    this.dividerStyle,
    this.scrollController,
  });

  /// The tab labels.
  final List<Widget> tabs;

  /// Drives the selected tab. Notifies listeners when the user taps a tab.
  final TabController? controller;

  /// Whether the strip can scroll horizontally.
  final bool isScrollable;

  /// Logical height of the strip.
  final double height;

  /// Visual style of the strip.
  final OhosTabBarType type;

  /// Color of the underline / active fill; defaults to the brand color.
  final Color? indicatorColor;

  /// Background color of the strip; defaults to the theme page background.
  final Color? backgroundColor;

  /// Whether a 1px hairline separates the strip from the content below
  /// (bottom-tab style). Superseded by [dividerStyle] / [divider].
  final bool showDivider;

  /// Optional divider configuration (常显/常隐/跟手滑动).
  ///
  /// Null falls back to [showDivider]: a hairline when it is true, nothing
  /// when it is false — so existing call sites keep their behaviour.
  final OhosTabBarDividerOptions? divider;

  /// Alias of [divider]; kept for readability in call sites.
  ///
  /// Still honoured because 0.4.0 shipped it — prefer [divider] in new code.
  final OhosTabBarDividerOptions? dividerStyle;

  /// Listens for the follow-scroll divider mode.
  final ScrollController? scrollController;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final TabController controller =
        this.controller ?? DefaultTabController.of(context);
    final int length = controller.length;
    if (type == OhosTabBarType.capsule) {
      return _fillWidth(
        SizedBox(
          height: height,
          child: AnimatedBuilder(
            animation: controller,
            builder: (BuildContext context, Widget? child) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OhosChipGroup(
                    items: <OhosChipItem>[
                      for (int i = 0; i < length; i++) _chipItem(tabs[i]),
                    ],
                    selectedIndex: controller.index,
                    onSelected: (int i) => controller.index = i,
                    scrollable: isScrollable,
                    activeColor: indicatorColor,
                    // 页签是**条**，不是「一坨独立芯片」：两头和内边距都已经由
                    // 这里的 16 水平 padding + 固定 [height] 表达过了。
                    // 沿用 ChipGroup 的组内边距会得到两个后果：水平 16+16=32
                    // 双倍缩进；纵向 14+14 把 36 高的芯片压进 48 高的栏里，
                    // 只剩 20 —— 芯片被裁掉一半，点击也落在裁剪区外。
                    // 所以这里显式归零，几何只由本组件的 [height] 决定。
                    startSpace: 0,
                    endSpace: 0,
                    padding: EdgeInsets.zero,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    return _fillWidth(
      Material(
        color: backgroundColor ?? theme.backgroundColor,
        child: SizedBox(
          height: height,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (BuildContext context, Widget? child) {
                    final List<Widget> items = <Widget>[
                      for (int i = 0; i < length; i++)
                        _tabItem(
                          context,
                          tabs[i],
                          i == controller.index,
                          () => controller.index = i,
                        ),
                    ];
                    if (isScrollable) {
                      return ListView(
                        scrollDirection: Axis.horizontal,
                        children: <Widget>[
                          for (int i = 0; i < items.length; i++) ...<Widget>[
                            SizedBox(width: 96, child: items[i]),
                          ],
                        ],
                      );
                    }
                    return Row(
                      children: <Widget>[
                        for (int i = 0; i < items.length; i++)
                          Expanded(child: items[i]),
                      ],
                    );
                  },
                ),
              ),
              _UnderlineDivider(
                options: divider ?? dividerStyle,
                legacyShowDivider: showDivider,
                dividerColor: theme.dividerColor,
                scrollController: scrollController,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 松宽度约束下也撑满可用宽度。
  ///
  /// `Column` / `Center` 这类父级给的 `minWidth` 是 0，而上面两个分支的外壳都是
  /// 「固定高度 + `Stack`（子节点全是 `Positioned.fill`）」，宽松约束下 `Stack`
  /// 会取 `constraints.smallest` → 整条页签宽度塌成 0，几个标题挤在正中叠成一坨，
  /// 高度正常所以不报错。宽度有界时显式顶到 `maxWidth`；无界（横向滚动列表里）
  /// 保持原样，不去强制一个无限宽。
  Widget _fillWidth(Widget bar) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedWidth) {
          return bar;
        }
        return SizedBox(width: constraints.maxWidth, child: bar);
      },
    );
  }

  OhosChipItem _chipItem(Widget tab) {
    final String label = _labelOf(tab);
    return OhosChipItem(label: Text(label));
  }

  String _labelOf(Widget tab) {
    if (tab is Tab) {
      return tab.text ?? '';
    }
    // Text widgets carry their data in `data`.
    final Text? text = tab is Text ? tab : null;
    return text?.data ?? '';
  }

  Widget _tabItem(
    BuildContext context,
    Widget tab,
    bool selected,
    VoidCallback onTap,
  ) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color activeColor = indicatorColor ?? theme.highlightColor;
    return InkWell(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          DefaultTextStyle.merge(
            style:
                (theme.typography.titleSmall ?? const TextStyle(fontSize: 16))
                    .copyWith(
                      color: selected ? activeColor : theme.textSecondaryColor,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
            child: tab,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: TweenAnimationBuilder<double>(
              // `spring` 的 y 控制点是 1.56，会过冲到 1 以上；这里的目标值有一侧
              // 是 0，插值就变成**负宽** —— `Container` 会抛
              // "BoxConstraints has a negative minimum width"（debug 下红屏 + 闪烁）。
              // 过冲段 clamp 到 0，弹性仍保留；`begin` 留空，首次直接就位、不播动画。
              tween: Tween<double>(end: selected ? 24 : 0),
              duration: OhosGeometry.durationShort,
              curve: OhosGeometry.spring,
              builder: (BuildContext context, double width, Widget? child) {
                return Container(
                  width: width.clamp(0.0, 24),
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the strip divider (常显 / 常隐 / 跟手滑动) at the bottom edge.
class _UnderlineDivider extends StatelessWidget {
  const _UnderlineDivider({
    required this.options,
    required this.legacyShowDivider,
    required this.dividerColor,
    this.scrollController,
  });

  final OhosTabBarDividerOptions? options;
  final bool legacyShowDivider;
  final Color dividerColor;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final OhosTabBarDividerOptions opts =
        options ??
        OhosTabBarDividerOptions(
          mode: legacyShowDivider
              ? OhosTabBarDividerMode.visible
              : OhosTabBarDividerMode.none,
        );
    final OhosTabBarDividerMode mode = opts.mode;
    if (mode == OhosTabBarDividerMode.none) {
      return const SizedBox.shrink();
    }
    final Color color = opts.color ?? dividerColor;
    final Widget line = Container(
      height: opts.strokeWidth,
      margin: EdgeInsets.only(left: opts.startMargin, right: opts.endMargin),
      color: color,
    );
    if (mode == OhosTabBarDividerMode.visible) {
      return Align(alignment: Alignment.bottomCenter, child: line);
    }
    // followScroll: fade + slide in as the content scrolls under the strip.
    final ScrollController? controller = scrollController;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ListenableBuilder(
        listenable: controller ?? ValueNotifier<double>(0),
        builder: (BuildContext context, Widget? child) {
          final double offset = (controller?.hasClients ?? false)
              ? controller!.offset
              : 0;
          final double span = (opts.followEndOffset - opts.followStartOffset)
              .clamp(0.1, 1e9);
          final double t = ((offset - opts.followStartOffset) / span).clamp(
            0.0,
            1.0,
          );
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 3),
              child: child,
            ),
          );
        },
        child: line,
      ),
    );
  }
}
