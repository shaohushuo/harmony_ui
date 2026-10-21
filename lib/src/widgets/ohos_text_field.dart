import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// Visual variant of [OhosTextField].
enum OhosTextFieldVariant {
  /// ArkUI default: transparent background with an accent underline.
  underline,

  /// Gray rounded block without a line, the common HarmonyOS form field.
  ///
  /// On an e-ink theme (`OhosThemeData.monochrome`) the fill would equal the
  /// page background, so the field falls back to a transparent background with
  /// a 1px border instead of a fill.
  filled,

  /// Fully rounded search-like field with a 1px outline.
  capsule,
}

/// A HarmonyOS text input, the counterpart of Flutter's [TextField].
///
/// Defaults to ArkUI's underline style and turns the accent line brand-colored
/// while focused; [variant] switches to the filled / capsule forms used by
/// HarmonyOS forms and search entries.
class OhosTextField extends StatefulWidget {
  const OhosTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.initialValue,
    this.maxLines = 1,
    this.variant = OhosTextFieldVariant.underline,
    this.style,
  });

  /// Controller for the text; if null an internal one is created from
  /// [initialValue].
  final TextEditingController? controller;

  /// External focus node, e.g. to focus the field from a button.
  ///
  /// When null the field owns one internally; a supplied node is never disposed
  /// by the widget.
  final FocusNode? focusNode;

  /// Hint shown when empty.
  final String? hintText;

  /// Floats above the input when focused/not empty.
  final String? labelText;

  /// Leading icon inside the field.
  final Widget? prefixIcon;

  /// Trailing icon inside the field (clear / visibility toggle etc.).
  final Widget? suffixIcon;

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

  /// Visual variant: underline (default) / filled / capsule.
  final OhosTextFieldVariant variant;

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
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocus);
    _focused = _focusNode.hasFocus;
  }

  void _onFocus() {
    if (mounted && _focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
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
    final InputDecoration decoration = switch (widget.variant) {
      OhosTextFieldVariant.underline => InputDecoration(
        hintText: widget.hintText,
        labelText: widget.labelText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.suffixIcon,
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
        suffixIconColor: theme.textSecondaryColor,
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
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.dangerColor, width: 2),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.dangerColor, width: 2),
        ),
      ),
      OhosTextFieldVariant.filled || OhosTextFieldVariant.capsule =>
        _boxedDecoration(
          theme: theme,
          hasError: hasError,
          accent: accent,
          // 墨水屏上「填充色 = 背景色」，灰底方块的边界会整个消失 →
          // 改回透明底 + 1px 黑边，靠线而不是靠色分层。
          useFill: widget.variant == OhosTextFieldVariant.filled &&
              !theme.monochrome,
          radius: widget.variant == OhosTextFieldVariant.capsule
              ? OhosGeometry.radiusCapsule
              : OhosGeometry.radiusMedium,
        ),
    };
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
          decoration: decoration,
        ),
      ],
    );
  }

  /// Filled / capsule variants: a boxed field whose border only shows while
  /// focused or in error, unless the fill is unavailable (e-ink) — then a
  /// hairline border carries the boundary instead.
  InputDecoration _boxedDecoration({
    required OhosThemeData theme,
    required bool hasError,
    required Color accent,
    required bool useFill,
    required double radius,
  }) {
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    final Color hairline = theme.textTertiaryColor.withValues(alpha: 0.5);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: widget.hintText,
      labelText: widget.labelText,
      prefixIcon: widget.prefixIcon,
      suffixIcon: widget.suffixIcon,
      errorText: widget.errorText,
      enabled: widget.enabled,
      errorMaxLines: 2,
      hintStyle: TextStyle(color: theme.textTertiaryColor),
      labelStyle: TextStyle(
        color: hasError
            ? theme.dangerColor
            : _focused
            ? theme.highlightColor
            : theme.textSecondaryColor,
      ),
      errorStyle: TextStyle(color: theme.dangerColor),
      prefixIconColor: accent,
      suffixIconColor: theme.textSecondaryColor,
      filled: useFill,
      fillColor:
          theme.compBackgroundGrayColor ??
          theme.backgroundSecondaryColor ??
          theme.cardColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: useFill ? border(Colors.transparent, 0) : border(hairline),
      focusedBorder: border(accent, 1.5),
      disabledBorder: useFill
          ? border(Colors.transparent, 0)
          : border(theme.textTertiaryColor.withValues(alpha: 0.2)),
      errorBorder: border(theme.dangerColor, 1.5),
      focusedErrorBorder: border(theme.dangerColor, 1.5),
    );
  }
}
