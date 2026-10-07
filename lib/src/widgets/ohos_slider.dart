import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// A HarmonyOS slider with a value-bubble tooltip (滑动条 in the guideline).
class OhosSlider extends StatefulWidget {
  const OhosSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.divisions,
    this.label,
    this.activeColor,
    this.enabled = true,
    this.showValueBubble = false,
  });

  /// Current value.
  final double value;

  /// Called continuously while dragging.
  final ValueChanged<double> onChanged;

  /// Minimum value.
  final double min;

  /// Maximum value.
  final double max;

  /// Snap divisions; when set the value snaps to discrete steps.
  final int? divisions;

  /// Label shown in the bubble.
  final String? label;

  /// Track color; defaults to the theme highlight color.
  final Color? activeColor;

  /// When false the slider is disabled.
  final bool enabled;

  /// Whether to show the value bubble above the thumb.
  final bool showValueBubble;

  @override
  State<OhosSlider> createState() => _OhosSliderState();
}

class _OhosSliderState extends State<OhosSlider> {
  double? _dragValue;

  double get _display => _dragValue ?? widget.value;

  String get _bubble =>
      widget.label ?? _display.toStringAsFixed(_isInteger(widget.max) ? 0 : 1);

  bool _isInteger(double v) => v == v.roundToDouble();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color active = widget.activeColor ?? theme.highlightColor;
    final bool showBubble = widget.showValueBubble && _dragValue != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showBubble)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.popupColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              _bubble,
              style: theme.typography.labelMedium?.copyWith(
                color: theme.textPrimaryColor,
              ),
            ),
          ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: active,
            inactiveTrackColor: active.withValues(alpha: 0.15),
            thumbColor: Colors.white,
            overlayColor: active.withValues(alpha: 0.12),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
              elevation: 3,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: _display.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: _bubble,
            onChanged: widget.enabled
                ? (double v) {
                    setState(() => _dragValue = v);
                    widget.onChanged(v);
                  }
                : null,
            onChangeEnd: widget.enabled
                ? (double v) {
                    setState(() => _dragValue = null);
                    widget.onChanged(v);
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
