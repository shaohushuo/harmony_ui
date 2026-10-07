import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// Shows a HarmonyOS alert dialog and returns the value of the pressed action.
///
/// ```dart
/// final bool? ok = await showOhosDialog<bool>(
///   context: context,
///   title: '删除此项？',
///   content: '该操作不可恢复。',
///   actions: <OhosDialogAction>[
///     OhosDialogAction(label: '取消', onPressed: () => Navigator.pop(context, false)),
///     OhosDialogAction(label: '删除', danger: true, onPressed: () => Navigator.pop(context, true)),
///   ],
/// );
/// ```
class OhosAlertDialog extends StatelessWidget {
  const OhosAlertDialog({
    super.key,
    required this.title,
    this.content,
    this.actions = const <OhosDialogAction>[],
    this.borderRadius = 28,
  });

  /// Title of the dialog.
  final String title;

  /// Optional body text.
  final String? content;

  /// Action buttons laid out vertically (ArkUI style).
  final List<OhosDialogAction> actions;

  /// Corner radius of the dialog surface.
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Dialog(
      backgroundColor: theme.popupColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style:
                  (theme.typography.titleMedium ??
                          const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ))
                      .copyWith(color: theme.textPrimaryColor),
            ),
            if (content != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  content!,
                  textAlign: TextAlign.center,
                  style:
                      (theme.typography.bodyMedium ??
                              const TextStyle(fontSize: 15))
                          .copyWith(color: theme.textSecondaryColor),
                ),
              ),
            const SizedBox(height: 20),
            for (int i = 0; i < actions.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 4),
              _OhosDialogActionButton(action: actions[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// An action entry of [OhosAlertDialog].
class OhosDialogAction {
  const OhosDialogAction({
    required this.label,
    required this.onPressed,
    this.danger = false,
    this.textStyle,
  });

  /// Visible label of the action.
  final String label;

  /// Called when the action is pressed.
  final VoidCallback onPressed;

  /// When true the label is tinted with the danger color.
  final bool danger;

  /// Optional label style override.
  final TextStyle? textStyle;
}

class _OhosDialogActionButton extends StatelessWidget {
  const _OhosDialogActionButton({required this.action});

  final OhosDialogAction action;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color color = action.danger
        ? theme.dangerColor
        : theme.highlightColor;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(OhosGeometry.radiusMedium),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onPressed,
        highlightColor: color.withValues(alpha: 0.08),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          child: Text(
            action.label,
            style:
                (action.textStyle ??
                        theme.typography.labelLarge ??
                        const TextStyle(fontSize: 16))
                    .copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Builds and shows an [OhosAlertDialog], the `ohos_ui` counterpart of
/// `showDialog` + `AlertDialog`.
Future<T?> showOhosDialog<T>({
  required BuildContext context,
  required String title,
  String? content,
  List<OhosDialogAction> actions = const <OhosDialogAction>[],
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext context) {
      return OhosAlertDialog(title: title, content: content, actions: actions);
    },
  );
}
