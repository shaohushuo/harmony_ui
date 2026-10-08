import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// A swipe action button of an [OhosListItem] (横滑动效按钮).
class OhosSwipeAction {
  const OhosSwipeAction({
    required this.icon,
    this.label,
    this.backgroundColor = const Color(0xFFE3E6EA),
    this.foregroundColor,
    this.onTap,
    this.width = 72,
  });

  /// Action icon (a [SymbolGlyph]-like widget or plain [Icon]).
  final Widget icon;

  /// Optional label shown under the icon.
  final String? label;

  /// Fill color of the action cell.
  final Color backgroundColor;

  /// Icon/label color; defaults to the primary text color.
  final Color? foregroundColor;

  /// Called when the action is tapped (after the item springs open).
  final VoidCallback? onTap;

  /// Cell width in logical pixels.
  final double width;
}

/// A horizontally swipeable HarmonyOS list item, the counterpart of
/// `HdsListItem` with `swipeActionOptions`.
///
/// Swiping left reveals [actions] on the trailing edge; each action opens a
/// callback. When [fullDelete] is true, dragging far enough fires
/// [onFullDelete] and the item animates away — the caller is expected to
/// remove the row from its data source.
class OhosListItem extends StatefulWidget {
  const OhosListItem({
    super.key,
    required this.child,
    this.actions = const <OhosSwipeAction>[],
    this.fullDelete = false,
    this.onFullDelete,
    this.borderRadius = BorderRadius.zero,
    this.deleteThreshold = 0.65,
  });

  /// The row content (usually an [OhosListTile] or a custom row).
  final Widget child;

  /// Optional trailing swipe actions (rendered right-aligned behind).
  final List<OhosSwipeAction> actions;

  /// Whether dragging past [deleteThreshold] auto-triggers [onFullDelete].
  final bool fullDelete;

  /// Called when a full-swipe delete is triggered.
  final VoidCallback? onFullDelete;

  /// Corner radius applied to the whole row (clips actions and content).
  final BorderRadius borderRadius;

  /// Fraction of the total action width that counts as a full delete.
  final double deleteThreshold;

  @override
  State<OhosListItem> createState() => _OhosListItemState();
}

class _OhosListItemState extends State<OhosListItem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragStart = 0;
  double _dragTotal = 0;

  double get _actionsWidth {
    double total = 0;
    for (final OhosSwipeAction action in widget.actions) {
      total += action.width;
    }
    return total;
  }

  /// Current content offset in px (positive = actions revealed).
  double get _revealed => _controller.value * _actionsWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OhosGeometry.durationShort,
      reverseDuration: OhosGeometry.durationShort,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _dragStart = _controller.value;
    _dragTotal = 0;
    _controller.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _dragTotal += details.delta.dx;
    final double overshoot = 40 / _actionsWidth;
    _controller.value =
        (_dragStart - _dragTotal / _actionsWidth).clamp(0.0, 1.0 + overshoot);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    final double revealed = _revealed;
    if (widget.fullDelete &&
        revealed > _actionsWidth * widget.deleteThreshold &&
        widget.onFullDelete != null) {
      final VoidCallback? onDelete = widget.onFullDelete;
      _controller.animateTo(1).whenComplete(() {
        setState(() => _controller.value = 0);
        onDelete?.call();
      });
      return;
    }
    final bool open = velocity > 300 || revealed > _actionsWidth / 2;
    _controller.animateTo(open ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color fg = theme.textPrimaryColor;
    final List<OhosSwipeAction> actions = widget.actions;
    final bool hasActions = actions.isNotEmpty;
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        children: <Widget>[
          if (hasActions)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final OhosSwipeAction action in actions)
                      _actionCell(action, fg, theme),
                  ],
                ),
              ),
            ),
          AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              // The gesture area travels with the content, so tapping a
              // revealed action behind it keeps working after the swipe.
              return Transform.translate(
                offset: Offset(-_revealed, 0),
                child: child,
              );
            },
            child: GestureDetector(
              onHorizontalDragStart: hasActions ? _onDragStart : null,
              onHorizontalDragUpdate: hasActions ? _onHorizontalDragUpdate : null,
              onHorizontalDragEnd: hasActions ? _onHorizontalDragEnd : null,
              behavior: HitTestBehavior.opaque,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCell(OhosSwipeAction action, Color defaultFg, OhosThemeData theme) {
    final Color color = action.foregroundColor ?? defaultFg;
    return Material(
      color: action.backgroundColor,
      child: InkWell(
        onTap: () {
          _controller.reverse();
          action.onTap?.call();
        },
        child: SizedBox(
          width: action.width,
          height: double.infinity,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconTheme.merge(
                  data: IconThemeData(color: color, size: 20),
                  child: action.icon,
                ),
                if (action.label != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    action.label!,
                    style: theme.typography.labelSmall?.copyWith(
                      color: color,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
