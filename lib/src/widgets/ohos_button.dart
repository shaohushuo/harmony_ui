import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// Visual variants of [OhosButton], mirroring ArkUI's button shapes.
enum OhosButtonShape {
  /// Fully rounded capsule (default).
  capsule,

  /// Large corner-radius square, e.g. 24vp.
  rounded,

  /// Perfect circle, typically for icon-only buttons.
  circle,
}

/// Emphasis levels of [OhosButton], mirroring ArkUI's button types.
enum OhosButtonStyle {
  /// Blue filled button with white text — first-level operations.
  filled,

  /// Soft blue-tinted surface with blue text — secondary operations.
  tonal,

  /// Transparent background with border — third-level operations.
  outlined,

  /// Borderless text button.
  text,

  /// White surface with border (classic "normal" button).
  plain,
}

/// A HarmonyOS button, the counterpart of Material's [ElevatedButton] /
/// [OutlinedButton] / [TextButton] and Cupertino's [CupertinoButton].
///
/// ```dart
/// OhosButton(
///   onPressed: () {},
///   child: Text('确定'),
/// )
/// ```
class OhosButton extends StatelessWidget {
  const OhosButton({
    super.key,
    required this.onPressed,
    this.child,
    this.icon,
    this.style = OhosButtonStyle.filled,
    this.shape = OhosButtonShape.capsule,
    this.loading = false,
    this.minSize = const Size(48, 40),
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
  });

  /// Called when the button is tapped. When null the button is disabled.
  final VoidCallback? onPressed;

  /// The primary content, typically a [Text].
  final Widget? child;

  /// Optional leading icon.
  final Widget? icon;

  /// Emphasis level of the button.
  final OhosButtonStyle style;

  /// Shape of the button.
  final OhosButtonShape shape;

  /// Shows an inline spinner in place of [icon] and disables taps.
  final bool loading;

  /// Minimum size of the button.
  final Size minSize;

  /// Padding inside the button.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = onPressed != null && !loading;
    final Color highlight = theme.highlightColor;
    final Color textPrimary = theme.textPrimaryColor;

    final Color background;
    final Color foreground;
    final Color border;
    switch (style) {
      case OhosButtonStyle.filled:
        background = enabled ? highlight : highlight.withValues(alpha: 0.20);
        foreground = Colors.white;
        border = Colors.transparent;
      case OhosButtonStyle.tonal:
        background = highlight.withValues(alpha: enabled ? 0.12 : 0.06);
        foreground = enabled ? highlight : theme.textTertiaryColor;
        border = Colors.transparent;
      case OhosButtonStyle.outlined:
        background = Colors.transparent;
        foreground = enabled ? highlight : theme.textTertiaryColor;
        border = enabled
            ? highlight.withValues(alpha: 0.5)
            : theme.textTertiaryColor.withValues(alpha: 0.4);
      case OhosButtonStyle.text:
        background = Colors.transparent;
        foreground = enabled ? highlight : theme.textTertiaryColor;
        border = Colors.transparent;
      case OhosButtonStyle.plain:
        background = enabled ? theme.cardColor : const Color(0x14000000);
        foreground = enabled ? textPrimary : theme.textTertiaryColor;
        border = enabled
            ? theme.textTertiaryColor.withValues(alpha: 0.4)
            : theme.textTertiaryColor.withValues(alpha: 0.2);
    }

    OutlinedBorder shapeBorder;
    switch (shape) {
      case OhosButtonShape.capsule:
        shapeBorder = StadiumBorder(side: BorderSide(color: border));
      case OhosButtonShape.rounded:
        shapeBorder = RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: BorderRadius.circular(OhosGeometry.radiusLarge),
        );
      case OhosButtonShape.circle:
        shapeBorder = CircleBorder(side: BorderSide(color: border));
    }

    final Widget label = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: style == OhosButtonStyle.filled
                  ? Colors.white70
                  : highlight,
            ),
          )
        : DefaultTextStyle.merge(
            style:
                (theme.typography.labelLarge ?? const TextStyle(fontSize: 16))
                    .copyWith(color: foreground),
            child: child ?? const SizedBox.shrink(),
          );

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!loading && icon != null) ...<Widget>[
          IconTheme.merge(
            data: IconThemeData(color: foreground, size: 20),
            child: icon!,
          ),
          const SizedBox(width: 8),
        ],
        label,
      ],
    );

    return Material(
      color: background,
      shape: shapeBorder,
      clipBehavior: Clip.antiAlias,
      elevation: style == OhosButtonStyle.filled && enabled ? 1 : 0,
      shadowColor: highlight.withValues(alpha: 0.25),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        splashColor: Colors.white.withValues(
          alpha: style == OhosButtonStyle.filled ? 0.25 : 0.20,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minSize.width,
            minHeight: minSize.height,
          ),
          child: Padding(padding: padding, child: content),
        ),
      ),
    );
  }
}
