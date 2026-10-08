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

  /// The divider fades in as the bound [ScrollController] scrolls past
  /// `blurEffectiveStartOffset` (跟手滑动效果).
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
  /// (bottom-tab style). Superseded by [dividerStyle].
  final bool showDivider;

  /// Optional divider configuration (常显/常隐/跟手滑动).
  final OhosTabBarDividerOptions? divider;

  /// Alias of [divider]; kept for readability in call sites.
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
      return SizedBox(
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
                ),
              ),
            );
          },
        ),
      );
    }
    return Material(
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
            child: AnimatedContainer(
              duration: OhosGeometry.durationShort,
              curve: OhosGeometry.spring,
              width: selected ? 24 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
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
          final double span =
              (opts.followEndOffset - opts.followStartOffset).clamp(0.1, 1e9);
          final double t =
              ((offset - opts.followStartOffset) / span).clamp(0.0, 1.0);
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
