import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_press_feedback.dart';

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
  ScaffoldMessengerState? customMessenger,
}) {
  final OhosThemeData theme = OhosTheme.of(context);
  // 就近查找只覆盖祖先：分层页面（抽屉 / 弹层挂在根 Navigator）里必须能显式
  // 指定某一层 messenger，否则提示会被外层整个盖住。
  final ScaffoldMessengerState messenger =
      customMessenger ?? ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  final bool hasIcon = icon != null;
  final bool hasTitle = title != null || content != null;
  final Color surface = backgroundColor ?? theme.cardColor;
  // 浮条是靠阴影和底色拉开距离的，两样在浅底上都靠不住：墨水屏（灰阶）没有
  // 阴影，彩屏给一块纯白浮条也只有 6dp 的淡影。凡是浅底都补一条 hairline，
  // 墨屏用纯黑，彩屏用主题的分隔色（10% 黑），不做成硬边框。
  final bool lightSurface =
      ThemeData.estimateBrightnessForColor(surface) == Brightness.light;
  messenger.showSnackBar(
    SnackBar(
      duration: resident ? const Duration(days: 365) : duration,
      behavior: SnackBarBehavior.floating,
      backgroundColor: surface,
      elevation: theme.policy.allowsShadow ? 6 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OhosGeometry.radiusMedium),
        // 浅底浮条自己画一条发丝线：墨屏纯黑、彩屏用分隔色
        side: theme.usesOutlines || lightSurface
            ? ohosBorderSide(
                context,
                theme.dividerColor,
                width: theme.outlineWidth,
              )
            : BorderSide.none,
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
                          style:
                              (theme.typography.bodyMedium ??
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
                          style:
                              (theme.typography.bodySmall ??
                                      const TextStyle(fontSize: 13))
                                  .copyWith(color: theme.textSecondaryColor),
                        ),
                      ],
                    ],
                  )
                : Text(
                    message ?? '',
                    style:
                        (theme.typography.bodyMedium ??
                                const TextStyle(fontSize: 15))
                            .copyWith(color: theme.textPrimaryColor),
                  ),
          ),
          if (resident)
            OhosPressFeedback(
              onTap: () => messenger.hideCurrentSnackBar(),
              borderRadius: BorderRadius.circular(15),
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
            // 不用 `TextButton`：它自带 Material 的 splash、`overlayColor`
            // 与最小的 8vp 内边距，浮条里那一小块按下去会闪一圈圆光。
            OhosPressFeedback(
              onTap: () {
                messenger.hideCurrentSnackBar();
                onAction?.call();
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  actionLabel,
                  style:
                      (theme.typography.labelMedium ??
                              const TextStyle(fontSize: 14))
                          .copyWith(
                            color: theme.highlightColor,
                            fontWeight: FontWeight.w600,
                          ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
