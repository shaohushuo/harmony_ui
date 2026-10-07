import 'package:flutter/material.dart';

import '../theme/ohos_colors.dart';
import '../theme/ohos_theme.dart';

/// A HarmonyOS text input with an underline accent, the counterpart of
/// Flutter's [TextField]. Matches ArkUI's default underline input style and
/// turns the accent line brand-colored while focused.
class OhosTextField extends StatefulWidget {
  const OhosTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.initialValue,
    this.maxLines = 1,
    this.style,
  });

  /// Controller for the text; if null an internal one is created from
  /// [initialValue].
  final TextEditingController? controller;

  /// Hint shown when empty.
  final String? hintText;

  /// Floats above the input when focused/not empty.
  final String? labelText;

  /// Leading icon inside the field.
  final Widget? prefixIcon;

  /// Error message shown below the field in the danger color.
  final String? errorText;

  /// Hides the input (password etc.).
  final bool obscureText;

  /// When false the field is disabled.
  final bool enabled;

  /// Keyboard type of the input.
  final TextInputType? keyboardType;

  /// Action button of the input method.
  final TextInputAction? textInputAction;

  /// Called whenever the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the text.
  final ValueChanged<String>? onSubmitted;

  /// Initial value of the text.
  final String? initialValue;

  /// Maximum number of lines.
  final int maxLines;

  /// Overrides the input text style.
  final TextStyle? style;

  @override
  State<OhosTextField> createState() => _OhosTextFieldState();
}

class _OhosTextFieldState extends State<OhosTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        TextEditingController(text: widget.initialValue ?? '');
    _focusNode = FocusNode()..addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted && _focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool hasError =
        widget.errorText != null && widget.errorText!.isNotEmpty;
    final Color highlight = theme.highlightColor;
    final Color accent = !widget.enabled
        ? theme.textTertiaryColor
        : hasError
        ? theme.dangerColor
        : _focused
        ? highlight
        : theme.textTertiaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: widget.controller ?? _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          maxLines: widget.maxLines,
          style:
              widget.style ??
              (theme.typography.bodyLarge?.copyWith(
                color: theme.textPrimaryColor,
              )),
          decoration: InputDecoration(
            hintText: widget.hintText,
            labelText: widget.labelText,
            prefixIcon: widget.prefixIcon,
            errorText: widget.errorText,
            enabled: widget.enabled,
            errorMaxLines: 2,
            hintStyle: TextStyle(color: theme.textTertiaryColor),
            labelStyle: TextStyle(
              color: hasError
                  ? theme.dangerColor
                  : _focused
                  ? highlight
                  : theme.textSecondaryColor,
            ),
            errorStyle: TextStyle(color: theme.dangerColor),
            prefixIconColor: accent,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 12,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: theme.textTertiaryColor.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent, width: 2),
            ),
            disabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: theme.textTertiaryColor.withValues(alpha: 0.2),
              ),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: OhosColors.danger, width: 2),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: OhosColors.danger, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
