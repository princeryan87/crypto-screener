import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animasi pulse heartbeat (EKG/ECG line) merah yang bergerak looping
/// dari kiri ke kanan, dipakai sebagai indikator loading saat proses
/// screening berjalan (bisa makan waktu cukup lama karena fetch
/// puluhan-ratusan pair dari Binance).
///
/// CATATAN DESAIN: sama seperti AnimatedCandlestickBackground, ini
/// dibuat sebagai animasi vector native (CustomPainter +
/// AnimationController) meniru bentuk garis heartbeat/EKG dari
/// referensi yang dikirim user, BUKAN file .gif/.webp asli - supaya
/// tetap ringan (tanpa aset dibundle ke APK) dan smooth di resolusi
/// apapun.
class PulseHeartbeatLoader extends StatefulWidget {
  final double height;
  final String? label;

  const PulseHeartbeatLoader({
    super.key,
    this.height = 80,
    this.label,
  });

  @override
  State<PulseHeartbeatLoader> createState() => _PulseHeartbeatLoaderState();
}

class _PulseHeartbeatLoaderState extends State<PulseHeartbeatLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _HeartbeatPainter(progress: _controller.value),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.label!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _HeartbeatPainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0, looping

  _HeartbeatPainter({required this.progress});

  /// Membentuk satu path garis EKG: flat - bump kecil - lonjakan tajam
  /// ke atas - turun tajam ke bawah - flat - bump kecil - flat,
  /// menyerupai bentuk pada gambar referensi.
  Path _buildEkgPath(double width, double height) {
    final path = Path();
    final midY = height * 0.55;
    path.moveTo(0, midY);
    path.lineTo(width * 0.08, midY);
    path.lineTo(width * 0.12, midY - height * 0.12);
    path.lineTo(width * 0.16, midY);
    path.lineTo(width * 0.20, midY);
    path.lineTo(width * 0.25, height * 0.05); // lonjakan tajam ke atas
    path.lineTo(width * 0.29, height * 0.95); // turun tajam ke bawah
    path.lineTo(width * 0.33, midY);
    path.lineTo(width * 0.40, midY);
    path.lineTo(width * 0.44, midY - height * 0.18); // bump kecil
    path.lineTo(width * 0.48, midY);
    path.lineTo(width * 0.62, midY);
    path.lineTo(width * 0.66, midY - height * 0.12);
    path.lineTo(width * 0.70, midY);
    path.lineTo(width * 1.0, midY);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.dangerRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = AppColors.dangerRed.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Path digambar berulang 2x bersisian, lalu di-scroll horizontal
    // berdasarkan progress, supaya looping terasa mulus tanpa "loncat"
    // di akhir siklus.
    final singlePath = _buildEkgPath(size.width, size.height);
    final offsetX = -progress * size.width;

    canvas.save();
    canvas.translate(offsetX, 0);
    canvas.drawPath(singlePath, glowPaint);
    canvas.drawPath(singlePath, linePaint);
    canvas.translate(size.width, 0);
    canvas.drawPath(singlePath, glowPaint);
    canvas.drawPath(singlePath, linePaint);
    canvas.restore();

    // Titik terang ("blip") yang mengikuti ujung gelombang berjalan,
    // memperkuat kesan "alat monitor aktif".
    final blipX = size.width * ((progress * 3) % 1.0);
    final blipPaint = Paint()..color = AppColors.dangerRed;
    canvas.drawCircle(
      Offset(blipX, size.height * 0.55),
      3.5 + sin(progress * 2 * pi * 6) * 1.5,
      blipPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HeartbeatPainter oldDelegate) => true;
}
