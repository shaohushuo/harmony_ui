import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// Destination model of an [OhosNavigationBar].
class OhosNavigationDestination {
  const OhosNavigationDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badge,
  });

  /// Icon shown while the destination is selected.
  final Widget icon;

  /// Icon shown when the destination is not selected.
  final Widget? selectedIcon;

  /// The label below the icon.
  final String label;

  /// Optional widget overlaying the icon corner (e.g. [OhosBadge]).
  final Widget? badge;
}

/// A HarmonyOS bottom navigation bar, the counterpart of Material's
/// [NavigationBar]. The active destination gets a brand-colored pill behind
/// its icon, matching the ArkUI `Tabs` bar indicator.
class OhosNavigationBar extends StatelessWidget {
  const OhosNavigationBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.backgroundColor,
    this.height = 80,
  });

  /// Destinations of the bar.
  final List<OhosNavigationDestination> destinations;

  /// Index of the active destination.
  final int currentIndex;

  /// Called with the index of the tapped destination.
  final ValueChanged<int> onDestinationSelected;

  /// Bar background color; defaults to the theme card color.
  final Color? backgroundColor;

  /// Logical height of the bar.
  final double height;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Material(
      color: backgroundColor ?? theme.cardColor,
      child: SizedBox(
        height: height,
        child: SafeArea(
          top: false,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < destinations.length; i++)
                Expanded(
                  child: _OhosNavItem(
                    destination: destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OhosNavItem extends StatelessWidget {
  const _OhosNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final OhosNavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color highlight = theme.highlightColor;
    final Color labelColor = selected ? highlight : theme.textSecondaryColor;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AnimatedContainer(
            duration: OhosGeometry.durationShort,
            curve: OhosGeometry.spring,
            width: 56,
            height: 32,
            decoration: BoxDecoration(
              color: selected
                  ? highlight.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconTheme.merge(
                        data: IconThemeData(
                          color: selected
                              ? highlight
                              : theme.textSecondaryColor,
                          size: 22,
                        ),
                        child: selected
                            ? (destination.selectedIcon ?? destination.icon)
                            : destination.icon,
                      ),
                      AnimatedSwitcher(
                        duration: OhosGeometry.durationShort,
                        child: selected
                            ? Padding(
                                key: const ValueKey<String>('active'),
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  destination.label,
                                  style: theme.typography.labelSmall?.copyWith(
                                    color: highlight,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : const SizedBox(
                                key: ValueKey<String>('idle'),
                                width: 0,
                              ),
                      ),
                    ],
                  ),
                  if (destination.badge != null)
                    Positioned(top: -8, right: -10, child: destination.badge!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (!selected)
            Text(
              destination.label,
              style: theme.typography.labelSmall?.copyWith(color: labelColor),
            ),
        ],
      ),
    );
  }
}
