import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// Shows a rounded bubble popup anchored above/around the given widget
/// (气泡提示 in the HarmonyOS guideline).
///
/// ```dart
/// showOhosPopup(
///   context: context,
///   child: const Text('长按扫码支付'),
///   target: myButtonGlobalKey,
/// );
/// ```
Future<void> showOhosPopup({
  required BuildContext context,
  required String content,
  required GlobalKey targetKey,
  Duration duration = const Duration(seconds: 2),
}) {
  final OverlayState overlay = Overlay.of(context);
  final RenderBox box =
      targetKey.currentContext!.findRenderObject()! as RenderBox;
  final Offset position = box.localToGlobal(Offset.zero);
  final Size size = box.size;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) {
      return _OhosPopupOverlayEntry(
        content: content,
        anchor: position,
        anchorSize: size,
        onDismissed: () => entry.remove(),
      );
    },
  );
  overlay.insert(entry);
  Future<void>.delayed(duration, () {
    if (entry.mounted) entry.remove();
  });
  return Future<void>.delayed(duration);
}

class _OhosPopupOverlayEntry extends StatelessWidget {
  const _OhosPopupOverlayEntry({
    required this.content,
    required this.anchor,
    required this.anchorSize,
    required this.onDismissed,
  });

  final String content;
  final Offset anchor;
  final Size anchorSize;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Positioned(
      left: anchor.dx,
      top: anchor.dy - 12,
      child: IgnorePointer(
        child: Transform.translate(
          offset: const Offset(0, -52),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.popupColor,
              borderRadius: BorderRadius.circular(OhosGeometry.radiusMedium),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              content,
              style:
                  (theme.typography.bodySmall ?? const TextStyle(fontSize: 14))
                      .copyWith(color: theme.textPrimaryColor),
            ),
          ),
        ),
      ),
    );
  }
}
