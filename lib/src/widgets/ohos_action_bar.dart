import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';
import 'ohos_button.dart';
import 'ohos_divider.dart';

/// A bottom action bar (核心操作栏 in the HarmonyOS guideline), the Flutter
/// counterpart of `HdsActionBar`.
///
/// Two layouts are supported:
/// - Legacy full-width bar: secondary actions on the left, one primary
///   action on the right.
/// - Expandable cluster (`expandable: true`): a floating row of secondary
///   icon buttons plus a round primary button whose icon toggles
///   `+ / 关闭`; tapping the primary button collapses / expands the
///   secondary actions with a spring animation.
class OhosActionBar extends StatelessWidget {
  const OhosActionBar({
    super.key,
    this.primaryLabel,
    this.onPrimaryPressed,
    this.secondaryActions = const <Widget>[],
    this.primaryLoading = false,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
    this.expandable = false,
    this.isExpanded = true,
    this.onIsExpandedChanged,
    this.primaryIcon,
    this.primaryTooltip,
  });

  /// Label of the primary action (legacy layout).
  final String? primaryLabel;

  /// Called when the primary action is tapped.
  final VoidCallback? onPrimaryPressed;

  /// Secondary actions (typically icon or text buttons).
  final List<Widget> secondaryActions;

  /// Whether the primary action shows a loading spinner (legacy layout).
  final bool primaryLoading;

  /// Padding around the bar.
  final EdgeInsetsGeometry padding;

  /// When true, renders the expandable HdsActionBar cluster layout.
  final bool expandable;

  /// Whether the secondary actions are expanded (controlled).
  final bool isExpanded;

  /// Called when the user taps the primary button to toggle expand state.
  final ValueChanged<bool>? onIsExpandedChanged;

  /// Icon shown on the round primary button (defaults to a plus sign).
  final IconData? primaryIcon;

  /// Tooltip of the primary button.
  final String? primaryTooltip;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    if (expandable) {
      return _buildExpandable(theme);
    }
    return Material(
      color: theme.cardColor,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const OhosDivider(indent: 0, endIndent: 0),
            Padding(
              padding: padding,
              child: Row(
                children: <Widget>[
                  for (final Widget action in secondaryActions)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: action,
                    ),
                  const Spacer(),
                  OhosButton(
                    onPressed: primaryLoading ? null : onPrimaryPressed,
                    loading: primaryLoading,
                    child: Text(primaryLabel ?? ''),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandable(OhosThemeData theme) {
    final Color highlight = theme.highlightColor;
    final Widget primary = Material(
      color: highlight,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: highlight.withValues(alpha: 0.35),
      child: InkWell(
        onTap: () => onIsExpandedChanged?.call(!isExpanded),
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: primaryTooltip ?? (isExpanded ? '收起' : '展开'),
          child: SizedBox(
            width: 56,
            height: 56,
            child: IconTheme.merge(
              data: const IconThemeData(color: Colors.white, size: 26),
              child: Icon(
                primaryIcon ?? (isExpanded ? Icons.close_rounded : Icons.add_rounded),
              ),
            ),
          ),
        ),
      ),
    );
    final Widget secondary = AnimatedSwitcher(
      duration: OhosGeometry.durationMedium,
      switchInCurve: OhosGeometry.easeOut,
      switchOutCurve: OhosGeometry.easeOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.2, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: isExpanded
          ? Row(
              key: const ValueKey<String>('expanded'),
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final Widget action in secondaryActions)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: action,
                  ),
                const SizedBox(width: 12),
              ],
            )
          : const SizedBox(
              key: ValueKey<String>('collapsed'),
              width: 12,
              height: 56,
            ),
    );
    return Align(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedSize(
                duration: OhosGeometry.durationMedium,
                curve: OhosGeometry.spring,
                child: secondary,
              ),
              primary,
            ],
          ),
        ),
      ),
    );
  }
}
