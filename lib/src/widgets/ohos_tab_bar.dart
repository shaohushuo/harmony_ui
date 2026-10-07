import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// A HarmonyOS segmented tab strip, the counterpart of Material's
/// [TabBar]. The active tab is underlined by a short brand-colored indicator.
class OhosTabBar extends StatelessWidget implements PreferredSizeWidget {
  const OhosTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.height = 48,
  });

  /// The tab labels.
  final List<Widget> tabs;

  /// Drives the selected tab. Notifies listeners when the user taps a tab.
  final TabController? controller;

  /// Whether the strip can scroll horizontally.
  final bool isScrollable;

  /// Logical height of the strip.
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final TabController controller =
        this.controller ?? DefaultTabController.of(context);
    final int length = controller.length;
    return Material(
      color: theme.backgroundColor,
      child: SizedBox(
        height: height,
        child: AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? child) {
            return Row(
              children: <Widget>[
                for (int i = 0; i < length; i++)
                  Expanded(
                    flex: isScrollable ? 0 : 1,
                    child: _OhosTabItem(
                      label: tabs[i],
                      selected: i == controller.index,
                      onTap: () => controller.index = i,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OhosTabItem extends StatelessWidget {
  const _OhosTabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return InkWell(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          DefaultTextStyle.merge(
            style:
                (theme.typography.titleSmall ?? const TextStyle(fontSize: 16))
                    .copyWith(
                      color: selected
                          ? theme.highlightColor
                          : theme.textSecondaryColor,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
            child: label,
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
                color: theme.highlightColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
