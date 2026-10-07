import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_button.dart';
import 'ohos_divider.dart';

/// Shows a HarmonyOS half-sheet panel (半模态面板 in the guideline) — a
/// rounded bottom sheet with title, content and optional dismiss button.
///
/// ```dart
/// await showOhosBottomSheet(
///   context: context,
///   title: '分享',
///   content: SizedBox(height: 200, child: ...),
/// );
/// ```
Future<void> showOhosBottomSheet({
  required BuildContext context,
  required String title,
  required Widget content,
  String? dismissLabel,
  bool showCloseButton = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: OhosTheme.of(context).popupColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) {
      final OhosThemeData theme = OhosTheme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.textTertiaryColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: theme.typography.titleMedium?.copyWith(
                        color: theme.textPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (showCloseButton)
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: theme.textSecondaryColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(child: SingleChildScrollView(child: content)),
              const SizedBox(height: 8),
              const OhosDivider(indent: 0, endIndent: 0),
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: OhosButton(
                    onPressed: dismissLabel == null
                        ? null
                        : () => Navigator.pop(context),
                    child: Text(dismissLabel ?? ''),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
