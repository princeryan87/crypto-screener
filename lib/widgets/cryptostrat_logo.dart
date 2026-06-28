import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Logo Cryptostrat - rekreasi vector dari desain "C" (huruf C terbuka,
/// menyerupai arah rotasi/refresh) dengan garis chart zigzag naik dan
/// anak panah di ujung kanan atas, mengikuti referensi logo yang
/// dikirim user.
///
/// Dibuat sebagai CustomPainter (vector, bukan file gambar) supaya
/// tetap konsisten dengan pendekatan "ringan tanpa aset eksternal"
/// yang sudah dipakai di AnimatedCandlestickBackground - dan supaya
/// tajam di resolusi apapun (app icon kecil maupun logo besar di
/// landing page) tanpa pecah/blur.
class CryptostratLogo extends StatelessWidget {
  final double size;
  final Color color;

  const CryptostratLogo({
    super.key,
    this.size = 48,
    this.color = AppColors.primaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _LogoPainter(color: color),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color color;
  _LogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;
    final strokeWidth = size.width * 0.11;

    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Huruf "C" terbuka - dibuat dari 2 arc terpisah (atas & bawah)
    // dengan gap di kanan, supaya menyerupai bentuk huruf C/refresh
    // pada logo referensi.
    final ringRect = Rect.fromCircle(center: center, radius: radius);
    // Arc atas: dari sekitar arah jam 10 ke jam 2 (radian: -2.4 ke -0.5)
    canvas.drawArc(ringRect, -2.55, 1.55, false, ringPaint);
    // Arc bawah: dari sekitar arah jam 8 ke jam 4
    canvas.drawArc(ringRect, 1.0, 1.55, false, ringPaint);

    // Garis chart zigzag (naik-turun-naik) yang memotong badan C,
    // melanjutkan jadi anak panah di ujung kanan atas.
    final chartPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.85
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final left = size.width * 0.08;
    final bottom = size.height * 0.72;
    final midLow = size.height * 0.50;
    final midHigh = size.height * 0.40;
    final peak = size.height * 0.62;
    final rightTipX = size.width * 0.92;
    final rightTipY = size.height * 0.22;

    path.moveTo(left, bottom);
    path.lineTo(size.width * 0.40, midHigh);
    path.lineTo(size.width * 0.52, peak);
    path.lineTo(size.width * 0.66, midLow);
    path.lineTo(rightTipX, rightTipY);
    canvas.drawPath(path, chartPaint);

    // Kepala anak panah di ujung kanan atas
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final arrowSize = size.width * 0.14;
    final arrowPath = Path()
      ..moveTo(rightTipX, rightTipY)
      ..lineTo(rightTipX - arrowSize * 1.3, rightTipY - arrowSize * 0.15)
      ..lineTo(rightTipX - arrowSize * 0.55, rightTipY + arrowSize * 0.85)
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
