import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_button.dart';

/// Option model of [showOhosPicker].
class OhosPickerItem<T> {
  const OhosPickerItem({
    required this.label,
    required this.value,
    this.subtitle,
  });

  /// Display label.
  final String label;

  /// Value returned when selected.
  final T value;

  /// Optional secondary line.
  final String? subtitle;
}

/// Shows a bottom-sheet picker (选择器 in the HarmonyOS guideline) and
/// resolves with the selected value.
///
/// ```dart
/// final String? city = await showOhosPicker<String>(
///   context: context,
///   title: '选择城市',
///   items: const [
///     OhosPickerItem(label: '北京', value: 'beijing'),
///     OhosPickerItem(label: '上海', value: 'shanghai'),
///   ],
///   initialValue: 'beijing',
/// );
/// ```
Future<T?> showOhosPicker<T>({
  required BuildContext context,
  required String title,
  required List<OhosPickerItem<T>> items,
  T? initialValue,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: OhosTheme.of(context).popupColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) {
      final OhosThemeData theme = OhosTheme.of(context);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.typography.titleMedium?.copyWith(
                color: theme.textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final OhosPickerItem<T> item in items)
                    InkWell(
                      onTap: () => Navigator.pop(context, item.value),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.label,
                                    style: theme.typography.bodyLarge?.copyWith(
                                      color: theme.textPrimaryColor,
                                    ),
                                  ),
                                  if (item.subtitle != null)
                                    Text(
                                      item.subtitle!,
                                      style: theme.typography.bodySmall
                                          ?.copyWith(
                                            color: theme.textSecondaryColor,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            if (item.value == initialValue)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                                color: theme.highlightColor,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OhosButton(
                  onPressed: () => Navigator.pop(context),
                  style: OhosButtonStyle.text,
                  child: const Text('取消'),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
