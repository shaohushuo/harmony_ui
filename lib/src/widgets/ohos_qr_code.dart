import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../theme/ohos_theme.dart';

/// A HarmonyOS QR code display widget (二维码 in the guideline). Renders the
/// QR matrix with quiet-zone padding and a brand-tinted version.
class OhosQrCode extends StatelessWidget {
  const OhosQrCode({
    super.key,
    required this.data,
    this.size = 180,
    this.color,
    this.backgroundColor,
  });

  /// The payload string.
  final String data;

  /// Side length of the rendered QR code including quiet zone.
  final double size;

  /// Module color; defaults to the theme primary text color.
  final Color? color;

  /// Quiet-zone color; defaults to the theme card color.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final QrCode code = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.L,
    );
    final QrImage image = QrImage(code);
    final int sizeInModules = image.moduleCount;
    final double moduleSize = size / (sizeInModules + 8);
    final Color moduleColor = color ?? theme.textPrimaryColor;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(moduleSize * 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: CustomPaint(
        size: Size.square(size - moduleSize * 8),
        painter: _QrPainter(image: image, moduleColor: moduleColor),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter({required this.image, required this.moduleColor});

  final QrImage image;
  final Color moduleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = moduleColor;
    final int count = image.moduleCount;
    final double w = size.width / count;
    for (int y = 0; y < count; y++) {
      for (int x = 0; x < count; x++) {
        if (image.isDark(y, x)) {
          canvas.drawRect(Rect.fromLTWH(x * w, y * w, w + 0.5, w + 0.5), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.moduleColor != moduleColor;
}
