import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';
import 'ohos_light_material.dart';

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

/// Presentation style of an [OhosNavigationBar] (HarmonyOS 6.1+ rule).
enum OhosNavigationBarType {
  /// 平铺式: fills the bottom edge of the window, default height 48vp.
  tile,

  /// 悬浮式: a rounded capsule floating above the content, default height
  /// 56vp, typically combined with the immersive light material.
  float,
}

/// A HarmonyOS bottom navigation bar, the counterpart of Material's
/// [NavigationBar].
///
/// Follows the official「底部页签」spec:
///
/// - 平铺式 height 48vp / 悬浮式 height 56vp (3-5 destinations, icon 24x24vp).
/// - The active destination gets a 20% brand highlight
///   (`comp_emphasize_secondary`) pill behind its icon (平铺) or behind the
///   inline icon+label (悬浮).
/// - [lightMaterial] applies the immersive-light backplate (THIN + bottom
///   gradient fade) to the floating style.
class OhosNavigationBar extends StatelessWidget {
  const OhosNavigationBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.backgroundColor,
    this.height,
    this.type = OhosNavigationBarType.tile,
    this.lightMaterial = false,
    this.lightLevel = OhosLightMaterialLevel.thin,
    this.iconSize = 24,
  });

  /// Destinations of the bar.
  final List<OhosNavigationDestination> destinations;

  /// Index of the active destination.
  final int currentIndex;

  /// Called with the index of the tapped destination.
  final ValueChanged<int> onDestinationSelected;

  /// Bar background color; defaults to the theme component background.
  final Color? backgroundColor;

  /// Logical height of the bar; defaults to 48 (tile) or 56 (float).
  final double? height;

  /// 平铺式 or 悬浮式 presentation.
  final OhosNavigationBarType type;

  /// Whether the bar is backed by the immersive light material.
  final bool lightMaterial;

  /// Immersive-light level when [lightMaterial] is true.
  final OhosLightMaterialLevel lightLevel;

  /// Icon size of a destination (official default 24x24vp).
  final double iconSize;

  double get _defaultHeight => type == OhosNavigationBarType.float ? 56 : 48;

  double get _effectiveHeight => height ?? _defaultHeight;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color background =
        backgroundColor ??
        (theme.compBackgroundPrimaryColor ?? theme.cardColor);
    final Widget bar = SizedBox(
      height: _effectiveHeight,
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
                  inline: type == OhosNavigationBarType.float,
                  iconSize: iconSize,
                ),
              ),
          ],
        ),
      ),
    );
    if (type == OhosNavigationBarType.float) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: _effectiveHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_effectiveHeight / 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: lightMaterial
                ? OhosLightMaterial(
                    level: lightLevel,
                    gradientFade: OhosLightFade.bottom,
                    gradientExtent: 24,
                    child: bar,
                  )
                : ColoredBox(color: background, child: bar),
          ),
        ),
      );
    }
    if (lightMaterial) {
      return OhosLightMaterial(
        level: lightLevel,
        gradientFade: OhosLightFade.bottom,
        gradientExtent: 24,
        child: Material(color: Colors.transparent, child: bar),
      );
    }
    return Material(color: background, child: bar);
  }
}

class _OhosNavItem extends StatelessWidget {
  const _OhosNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.inline,
    required this.iconSize,
  });

  final OhosNavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool inline;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color highlight = theme.highlightColor;
    final Color labelColor = selected ? highlight : theme.textSecondaryColor;
    final Color pillColor = selected
        ? (theme.emphasizeSecondaryColor ?? highlight.withValues(alpha: 0.20))
        : Colors.transparent;
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            IconTheme.merge(
              data: IconThemeData(color: labelColor, size: iconSize),
              child: selected
                  ? (destination.selectedIcon ?? destination.icon)
                  : destination.icon,
            ),
            if (destination.badge != null)
              Positioned(top: -6, right: -8, child: destination.badge!),
          ],
        ),
        if (inline && selected)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              destination.label,
              style: theme.typography.labelSmall?.copyWith(
                color: highlight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
    if (inline) {
      return InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: OhosGeometry.durationShort,
          curve: OhosGeometry.spring,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 14 : 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(22),
          ),
          child: content,
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedContainer(
            duration: OhosGeometry.durationShort,
            curve: OhosGeometry.spring,
            width: 56,
            height: selected ? 32 : 26,
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(selected ? 16 : 13),
            ),
            child: Center(child: content),
          ),
          if (!selected) const SizedBox(height: 1),
          if (!selected)
            Text(
              destination.label,
              style:
                  (theme.typography.labelSmall ?? const TextStyle(fontSize: 10))
                      .copyWith(color: labelColor, fontSize: 10, height: 1.2),
            ),
        ],
      ),
    );
  }
}
