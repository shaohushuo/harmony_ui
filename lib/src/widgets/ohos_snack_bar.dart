import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// 即时操作（HdsSnackBar）: a snack bar with an optional action and a
/// resident mode.
///
/// ```dart
/// showOhosSnackBar(
///   context,
///   message: '已删除 1 个文件',
///   actionLabel: '撤销',
///   onAction: () {},
/// );
///
/// // 常驻通知：duration -1 语义，显示关闭按钮，不自动消失
/// showOhosSnackBar(context, resident: true, icon: ..., title: 'Wi-Fi 已断开', content: '请检查网络后重试');
/// ```
void showOhosSnackBar(
  BuildContext context, {
  String? message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
  bool resident = false,
  Widget? icon,
  String? title,
  String? content,
  Color? backgroundColor,
}) {
  final OhosThemeData theme = OhosTheme.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  final bool hasIcon = icon != null;
  final bool hasTitle = title != null || content != null;
  messenger.showSnackBar(
    SnackBar(
      duration: resident ? const Duration(days: 365) : duration,
      behavior: SnackBarBehavior.floating,
      backgroundColor: backgroundColor ?? theme.cardColor,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OhosGeometry.radiusMedium),
      ),
      content: Row(
        children: <Widget>[
          if (hasIcon) ...<Widget>[
            IconTheme.merge(
              data: IconThemeData(color: theme.highlightColor, size: 22),
              child: icon,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: hasTitle
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (title != null)
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (theme.typography.bodyMedium ??
                                  const TextStyle(fontSize: 15))
                              .copyWith(
                                color: theme.textPrimaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      if (content != null) ...<Widget>[
                        if (title != null) const SizedBox(height: 2),
                        Text(
                          content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: (theme.typography.bodySmall ??
                                  const TextStyle(fontSize: 13))
                              .copyWith(color: theme.textSecondaryColor),
                        ),
                      ],
                    ],
                  )
                : Text(
                    message ?? '',
                    style: (theme.typography.bodyMedium ??
                            const TextStyle(fontSize: 15))
                        .copyWith(color: theme.textPrimaryColor),
                  ),
          ),
          if (resident)
            InkWell(
              onTap: () => messenger.hideCurrentSnackBar(),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: theme.textSecondaryColor,
                ),
              ),
            )
          else if (actionLabel != null)
            TextButton(
              onPressed: () {
                messenger.hideCurrentSnackBar();
                onAction?.call();
              },
              style: TextButton.styleFrom(
                foregroundColor: theme.highlightColor,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(actionLabel),
            ),
        ],
      ),
    ),
  );
}
