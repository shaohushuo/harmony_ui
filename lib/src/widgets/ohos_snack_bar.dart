import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// Shows a snack bar with an optional action (即时操作 in the HarmonyOS
/// guideline).
///
/// ```dart
/// showOhosSnackBar(
///   context,
///   message: '已删除 1 个文件',
///   actionLabel: '撤销',
///   onAction: () {},
/// );
/// ```
void showOhosSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final OhosThemeData theme = OhosTheme.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: duration,
      behavior: SnackBarBehavior.floating,
      backgroundColor: theme.cardColor,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OhosGeometry.radiusMedium),
      ),
      content: Text(
        message,
        style: (theme.typography.bodyMedium ?? const TextStyle(fontSize: 15))
            .copyWith(color: theme.textPrimaryColor),
      ),
      action: actionLabel == null || onAction == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: theme.highlightColor,
              onPressed: onAction,
            ),
    ),
  );
}
