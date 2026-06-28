import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animasi candlestick bergerak naik-turun untuk landing page.
///
/// CATATAN DESAIN: permintaan awal adalah GIF candlestick, tapi GIF
/// asli butuh file aset yang harus dibundle ke APK (nambah ukuran
/// file) dan tidak bisa dibuat di environment development ini (tidak
/// ada akses image/video generation atau internet untuk download
/// aset). Sebagai gantinya dipakai animasi vector native Flutter
/// (CustomPainter + AnimationController) yang meniru gerakan
/// candlestick naik-turun secara looping - hasilnya SAMA-SAMA ringan
/// (tanpa file aset sama sekali, murni kode), bahkan lebih ringan
/// dari GIF, dan tetap memberi kesan "bergerak/hidup" yang diminta.
///
/// Jika nanti memang ingin GIF asli (misal sudah punya file dari
/// CapCut/sumber lain), tinggal ganti widget ini dengan
/// Image.asset('assets/candlestick.gif') dan daftarkan asetnya di
/// pubspec.yaml.
class AnimatedCandlestickBackground extends StatefulWidget {
  final int candleCount;
  final double opacity;

  const AnimatedCandlestickBackground({
    super.key,
    this.candleCount = 24,
    this.opacity = 0.35,
  });

  @override
  State<AnimatedCandlestickBackground> createState() =>
      _AnimatedCandlestickBackgroundState();
}

class _AnimatedCandlestickBackgroundState
    extends State<AnimatedCandlestickBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_CandleData> _candles;
  final _random = Random(42); // seed fixed - pola konsisten tiap buka app

  @override
  void initState() {
    super.initState();
    _candles = _generateCandles(widget.candleCount);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  List<_CandleData> _generateCandles(int count) {
    final candles = <_CandleData>[];
    double lastClose = 0.5;
    for (int i = 0; i < count; i++) {
      final open = lastClose;
      final change = (_random.nextDouble() - 0.45) * 0.25;
      final close = (open + change).clamp(0.15, 0.85);
      final high = max(open, close) + _random.nextDouble() * 0.08;
      final low = min(open, close) - _random.nextDouble() * 0.08;
      candles.add(_CandleData(
        open: open,
        close: close,
        high: high.clamp(0.0, 1.0),
        low: low.clamp(0.0, 1.0),
        isGreen: close >= open,
        // Setiap candle punya phase offset berbeda supaya animasi
        // naik-turunnya tidak serempak (lebih natural/organik)
        phaseOffset: _random.nextDouble(),
      ));
      lastClose = close;
    }
    return candles;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.opacity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _CandlestickPainter(
              candles: _candles,
              animationValue: _controller.value,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _CandleData {
  final double open;
  final double close;
  final double high;
  final double low;
  final bool isGreen;
  final double phaseOffset;

  _CandleData({
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.isGreen,
    required this.phaseOffset,
  });
}

class _CandlestickPainter extends CustomPainter {
  final List<_CandleData> candles;
  final double animationValue;

  _CandlestickPainter({required this.candles, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final candleWidth = size.width / candles.length;
    final bodyWidth = candleWidth * 0.55;

    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final centerX = candleWidth * i + candleWidth / 2;

      // Naik-turun halus (efek "bernafas") berbasis sine wave, dengan
      // phase offset unik per candle supaya tidak serempak.
      final wave =
          sin((animationValue + candle.phaseOffset) * 2 * pi) * 0.04;

      final openY = size.height * (1 - (candle.open + wave));
      final closeY = size.height * (1 - (candle.close + wave));
      final highY = size.height * (1 - (candle.high + wave));
      final lowY = size.height * (1 - (candle.low + wave));

      final color =
          candle.isGreen ? AppColors.primaryGreen : AppColors.dangerRed;

      final wickPaint = Paint()
        ..color = color.withOpacity(0.7)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(centerX, highY),
        Offset(centerX, lowY),
        wickPaint,
      );

      final bodyPaint = Paint()..color = color.withOpacity(0.55);
      final bodyTop = min(openY, closeY);
      final bodyBottom = max(openY, closeY);
      final bodyHeight = (bodyBottom - bodyTop).clamp(2.0, double.infinity);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centerX - bodyWidth / 2,
            bodyTop,
            bodyWidth,
            bodyHeight,
          ),
          const Radius.circular(2),
        ),
        bodyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) => true;
}
