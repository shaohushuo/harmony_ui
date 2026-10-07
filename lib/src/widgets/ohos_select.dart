import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';
import 'ohos_button.dart';

/// Option model of an [OhosSelect].
class OhosSelectOption<T> {
  const OhosSelectOption({required this.label, required this.value, this.icon});

  /// Display label.
  final String label;

  /// Value returned on selection.
  final T value;

  /// Optional leading icon.
  final IconData? icon;
}

/// A HarmonyOS dropdown select button (下拉按钮 in the guideline).
class OhosSelect<T> extends StatelessWidget {
  const OhosSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
    this.style = OhosButtonStyle.plain,
  });

  /// Available options.
  final List<OhosSelectOption<T>> options;

  /// Currently selected value.
  final T value;

  /// Called with the newly selected value.
  final ValueChanged<T> onChanged;

  /// Optional label next to the selected value.
  final String? label;

  /// When false the select is disabled.
  final bool enabled;

  /// Emphasis style of the trigger button.
  final OhosButtonStyle style;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final OhosSelectOption<T> selected = options.firstWhere(
      (OhosSelectOption<T> o) => o.value == value,
      orElse: () => options.first,
    );
    return OhosButton(
      onPressed: enabled
          ? () async {
              final T? result = await showMenu<T>(
                context: context,
                position: RelativeRect.fromLTRB(0, 0, 0, 0),
                color: theme.popupColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    OhosGeometry.radiusMedium,
                  ),
                ),
                items: <PopupMenuEntry<T>>[
                  for (final OhosSelectOption<T> option in options)
                    PopupMenuItem<T>(
                      value: option.value,
                      child: Row(
                        children: <Widget>[
                          if (option.icon != null) ...<Widget>[
                            Icon(
                              option.icon,
                              size: 18,
                              color: theme.textSecondaryColor,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            option.label,
                            style: theme.typography.bodyMedium?.copyWith(
                              color: theme.textPrimaryColor,
                            ),
                          ),
                          if (option.value == value) const Spacer(),
                          if (option.value == value)
                            Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: theme.highlightColor,
                            ),
                        ],
                      ),
                    ),
                ],
              );
              if (result != null) onChanged(result);
            }
          : null,
      style: style,
      icon: const Icon(Icons.expand_more_rounded),
      child: Text(label == null ? selected.label : '$label ${selected.label}'),
    );
  }
}
