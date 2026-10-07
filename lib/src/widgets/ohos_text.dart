import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// Text level of [OhosText], mirroring the HarmonyOS typography scale.
enum OhosTextLevel {
  /// 36sp bold, first-screen hero text.
  displayLarge,

  /// 32sp bold.
  displayMedium,

  /// 28sp headline.
  headlineLarge,

  /// 24sp headline.
  headlineMedium,

  /// 20sp title.
  titleLarge,

  /// 17sp title.
  titleMedium,

  /// 16sp title.
  titleSmall,

  /// 16sp body.
  bodyLarge,

  /// 15sp body.
  bodyMedium,

  /// 14sp body.
  bodySmall,

  /// 16sp medium label.
  labelLarge,

  /// 14sp label.
  labelMedium,

  /// 12sp caption.
  labelSmall,
}

/// A text widget bound to the HarmonyOS typography tokens, the `ohos_ui`
/// counterpart of Material's [Text]. Picks the matching [OhosTextLevel]
/// style from the surrounding [OhosTheme].
class OhosText extends StatelessWidget {
  const OhosText(
    this.data, {
    super.key,
    this.level = OhosTextLevel.bodyLarge,
    this.color,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  /// The text to display.
  final String data;

  /// Typography level.
  final OhosTextLevel level;

  /// Overrides the text color.
  final Color? color;

  /// Maximum number of lines.
  final int? maxLines;

  /// Overflow behavior.
  final TextOverflow? overflow;

  /// Text alignment.
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final TextStyle? base = switch (level) {
      OhosTextLevel.displayLarge => theme.typography.displayLarge,
      OhosTextLevel.displayMedium => theme.typography.displayMedium,
      OhosTextLevel.headlineLarge => theme.typography.headlineLarge,
      OhosTextLevel.headlineMedium => theme.typography.headlineMedium,
      OhosTextLevel.titleLarge => theme.typography.titleLarge,
      OhosTextLevel.titleMedium => theme.typography.titleMedium,
      OhosTextLevel.titleSmall => theme.typography.titleSmall,
      OhosTextLevel.bodyLarge => theme.typography.bodyLarge,
      OhosTextLevel.bodyMedium => theme.typography.bodyMedium,
      OhosTextLevel.bodySmall => theme.typography.bodySmall,
      OhosTextLevel.labelLarge => theme.typography.labelLarge,
      OhosTextLevel.labelMedium => theme.typography.labelMedium,
      OhosTextLevel.labelSmall => theme.typography.labelSmall,
    };
    if (color != null) {
      return Text(
        data,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        style: base?.copyWith(color: color),
      );
    }
    return Text(
      data,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: base ?? TextStyle(fontSize: 16, color: theme.textPrimaryColor),
    );
  }
}

/// A section subheader with optional trailing link, matching the "子标题"
/// control in the HarmonyOS design guideline.
class OhosSubheader extends StatelessWidget {
  const OhosSubheader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
  });

  /// Section title.
  final String title;

  /// Optional trailing text, e.g. "更多".
  final String? trailing;

  /// Called when the trailing link is tapped.
  final VoidCallback? onTrailingTap;

  /// Padding around the header.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: OhosText(
              title,
              level: OhosTextLevel.titleMedium,
              color: theme.textPrimaryColor,
            ),
          ),
          if (trailing != null)
            InkWell(
              onTap: onTrailingTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  OhosText(
                    trailing!,
                    level: OhosTextLevel.bodySmall,
                    color: theme.textSecondaryColor,
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: theme.textSecondaryColor,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
