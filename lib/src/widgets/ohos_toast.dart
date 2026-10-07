import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// Shows a transient toast message (即时反馈 in the HarmonyOS guideline).
///
/// ```dart
/// showOhosToast(context, '操作成功');
/// ```
void showOhosToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
  OhosToastPosition position = OhosToastPosition.center,
  IconData? icon,
}) {
  final OverlayState overlay = Overlay.of(context);
  final OhosThemeData theme = OhosTheme.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) {
      return _OhosToastOverlay(
        message: message,
        icon: icon,
        theme: theme,
        position: position,
        onDismissed: () => entry.remove(),
      );
    },
  );
  overlay.insert(entry);
  Future<void>.delayed(duration, () {
    if (entry.mounted) entry.remove();
  });
}

/// Position of an [showOhosToast] message.
enum OhosToastPosition { top, center, bottom }

class _OhosToastOverlay extends StatelessWidget {
  const _OhosToastOverlay({
    required this.message,
    required this.icon,
    required this.theme,
    required this.position,
    required this.onDismissed,
  });

  final String message;
  final IconData? icon;
  final OhosThemeData theme;
  final OhosToastPosition position;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final double offset = switch (position) {
      OhosToastPosition.top => MediaQuery.sizeOf(context).height * 0.18,
      OhosToastPosition.bottom => MediaQuery.sizeOf(context).height * 0.82,
      OhosToastPosition.center => MediaQuery.sizeOf(context).height * 0.45,
    };
    return SafeArea(
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Transform.translate(
            offset: Offset(0, offset - MediaQuery.sizeOf(context).height * 0.5),
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xE61A1A1A),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (icon != null) ...<Widget>[
                        Icon(icon, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A toast-style inline message used inside page layouts; see [showOhosToast]
/// for the overlay form.
class OhosToast extends StatelessWidget {
  const OhosToast({super.key, required this.message, this.icon});

  /// Message text.
  final String message;

  /// Optional leading icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xE61A1A1A),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
