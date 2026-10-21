import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// [data] as a QR code a phone can scan from the couch: black modules on
/// white with the four-module quiet zone, in every theme (a phone camera
/// reads dark on light best). The modules snap to whole pixels.
class QrCodeView extends StatelessWidget {
  const QrCodeView({super.key, required this.data, this.size = 320});

  final String data;

  /// The side, quiet zone included.
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(
      QrCode(
        payload: QrPayload.fromString(data),
        errorCorrectLevel: QrErrorCorrectLevel.medium,
      ),
    );
    return Semantics(
      label: 'QR code',
      value: data,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          key: ValueKey('qr:$data'),
          size: Size.square(size),
          painter: _QrPainter(data, image),
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.data, this.image);

  final String data;
  final QrImage image;

  /// Light modules around the code (the standard asks for four).
  static const _quiet = 4;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = Colors.white);
    final n = image.moduleCount + 2 * _quiet;
    final m = (s.width / n).floorToDouble();
    if (m <= 0) return;
    // Centred, so the rounding leaves an even margin.
    final origin = (s.width - m * n) / 2 + m * _quiet;
    final dark = Paint()..color = Colors.black;
    for (var r = 0; r < image.moduleCount; r++) {
      for (var c = 0; c < image.moduleCount; c++) {
        if (!image.isDark(r, c)) continue;
        canvas.drawRect(
          Rect.fromLTWH(origin + c * m, origin + r * m, m, m),
          dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.data != data;
}
