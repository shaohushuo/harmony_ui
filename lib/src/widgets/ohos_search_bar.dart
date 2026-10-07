import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';
import 'ohos_icon_button.dart';

/// A capsule-shaped HarmonyOS search input, modeled after the ArkUI search
/// component. Includes an optional clear button and submit callback.
class OhosSearchBar extends StatefulWidget {
  const OhosSearchBar({
    super.key,
    this.controller,
    this.hintText = '搜索',
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.height = 40,
    this.prefixIcon,
    this.borderRadius = OhosGeometry.radiusCapsule,
  });

  /// Controller for the search text.
  final TextEditingController? controller;

  /// Placeholder text.
  final String hintText;

  /// Called whenever the query changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user presses the search key.
  final ValueChanged<String>? onSubmitted;

  /// When false the search bar is disabled.
  final bool enabled;

  /// Focus the field when the widget is first built.
  final bool autofocus;

  /// Logical height of the bar.
  final double height;

  /// Overrides the leading search icon.
  final Widget? prefixIcon;

  /// Corner radius of the capsule.
  final double borderRadius;

  @override
  State<OhosSearchBar> createState() => _OhosSearchBarState();
}

class _OhosSearchBarState extends State<OhosSearchBar> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void didUpdateWidget(OhosSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && widget.controller != _controller) {
      _controller = widget.controller!;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return SizedBox(
      height: widget.height,
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: <Widget>[
              IconTheme.merge(
                data: IconThemeData(color: theme.textSecondaryColor, size: 18),
                child: widget.prefixIcon ?? const Icon(Icons.search_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  textInputAction: TextInputAction.search,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: theme.typography.bodyMedium?.copyWith(
                    color: theme.textPrimaryColor,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(color: theme.textTertiaryColor),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (BuildContext context, TextEditingValue value, _) {
                  return AnimatedSwitcher(
                    duration: OhosGeometry.durationShort,
                    child: value.text.isEmpty
                        ? const SizedBox(
                            width: 12,
                            key: ValueKey<String>('empty'),
                          )
                        : OhosIconButton(
                            key: const ValueKey<String>('clear'),
                            icon: const Icon(Icons.cancel_rounded, size: 16),
                            size: 32,
                            iconSize: 16,
                            color: theme.textTertiaryColor,
                            onPressed: () {
                              _controller.clear();
                              widget.onChanged?.call('');
                            },
                          ),
                  );
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
