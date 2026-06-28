import 'dart:math';
import '../models/kline_model.dart';

/// Kumpulan fungsi kalkulasi indikator teknikal generik.
/// Semua fungsi menerima List<KlineModel> terurut dari LAMA -> BARU
/// (sesuai urutan default response Binance klines).
class Indicators {
  /// Exponential Moving Average. [period] umum: 9, 21.
  /// Return list EMA sepanjang input (candle awal sebelum warm-up
  /// memakai SMA sebagai seed).
  static List<double> ema(List<double> closes, int period) {
    if (closes.length < period) return [];
    final result = <double>[];
    final multiplier = 2 / (period + 1);

    // Seed pertama pakai SMA dari [period] candle pertama
    double sma = closes.take(period).reduce((a, b) => a + b) / period;
    result.add(sma);

    for (int i = period; i < closes.length; i++) {
      final emaValue =
          (closes[i] - result.last) * multiplier + result.last;
      result.add(emaValue);
    }
    return result;
  }

  /// EMA terakhir saja (yang paling sering dibutuhkan strategi).
  static double? lastEma(List<double> closes, int period) {
    final result = ema(closes, period);
    return result.isEmpty ? null : result.last;
  }

  /// Relative Strength Index, standar Wilder smoothing. [period] umum: 14.
  static double? rsi(List<double> closes, int period) {
    if (closes.length < period + 1) return null;

    double gainSum = 0;
    double lossSum = 0;

    // Average gain/loss awal dari [period] candle pertama
    for (int i = 1; i <= period; i++) {
      final diff = closes[i] - closes[i - 1];
      if (diff >= 0) {
        gainSum += diff;
      } else {
        lossSum += diff.abs();
      }
    }
    double avgGain = gainSum / period;
    double avgLoss = lossSum / period;

    // Wilder smoothing untuk candle sisanya
    for (int i = period + 1; i < closes.length; i++) {
      final diff = closes[i] - closes[i - 1];
      final gain = diff >= 0 ? diff : 0.0;
      final loss = diff < 0 ? diff.abs() : 0.0;
      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;
    }

    if (avgLoss == 0) return 100;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  /// Average True Range. [period] umum: 14. Butuh high, low, close.
  static double? atr(List<KlineModel> klines, int period) {
    if (klines.length < period + 1) return null;

    final trueRanges = <double>[];
    for (int i = 1; i < klines.length; i++) {
      final high = klines[i].high;
      final low = klines[i].low;
      final prevClose = klines[i - 1].close;
      final tr = [
        high - low,
        (high - prevClose).abs(),
        (low - prevClose).abs(),
      ].reduce(max);
      trueRanges.add(tr);
    }

    if (trueRanges.length < period) return null;

    // Wilder smoothing, sama pola dengan RSI
    double atrValue =
        trueRanges.take(period).reduce((a, b) => a + b) / period;
    for (int i = period; i < trueRanges.length; i++) {
      atrValue = (atrValue * (period - 1) + trueRanges[i]) / period;
    }
    return atrValue;
  }

  /// ATR dalam bentuk persen dari harga close terakhir. Dipakai Low Cap
  /// Hunter untuk konfirmasi volatilitas asli (bukan anomali data).
  static double? atrPercent(List<KlineModel> klines, int period) {
    final atrValue = atr(klines, period);
    if (atrValue == null || klines.isEmpty) return null;
    final lastClose = klines.last.close;
    if (lastClose == 0) return null;
    return (atrValue / lastClose) * 100;
  }

  /// Bollinger Bands: return (middle, upper, lower, width).
  /// [period] umum: 20, [stdDevMultiplier] umum: 2.
  static BollingerBandsResult? bollingerBands(
    List<double> closes,
    int period, {
    double stdDevMultiplier = 2,
  }) {
    if (closes.length < period) return null;

    final window = closes.sublist(closes.length - period);
    final middle = window.reduce((a, b) => a + b) / period;
    final variance =
        window.map((c) => pow(c - middle, 2)).reduce((a, b) => a + b) /
            period;
    final stdDev = sqrt(variance);

    final upper = middle + (stdDev * stdDevMultiplier);
    final lower = middle - (stdDev * stdDevMultiplier);
    final width = middle == 0 ? 0.0 : ((upper - lower) / middle) * 100;

    return BollingerBandsResult(
      middle: middle,
      upper: upper,
      lower: lower,
      widthPercent: width,
    );
  }

  /// Hitung persentil suatu nilai dalam list histori. Dipakai
  /// Accumulation Zone untuk cek BB Width ada di persentil 20%
  /// terendah dari 30 hari terakhir.
  ///
  /// Return nilai 0-100 yang menyatakan posisi [currentValue] relatif
  /// terhadap [historicalValues] (semakin rendah = semakin sempit
  /// dibanding histori).
  static double percentileRank(
    List<double> historicalValues,
    double currentValue,
  ) {
    if (historicalValues.isEmpty) return 50;
    final sorted = List<double>.from(historicalValues)..sort();
    int countBelow = sorted.where((v) => v < currentValue).length;
    return (countBelow / sorted.length) * 100;
  }

  /// Simple Moving Average sederhana, dipakai untuk hitung rata-rata
  /// volume (bukan harga) di hampir semua strategi.
  static double sma(List<double> values, {int? period}) {
    final window =
        period == null ? values : values.sublist(max(0, values.length - period));
    if (window.isEmpty) return 0;
    return window.reduce((a, b) => a + b) / window.length;
  }
}

class BollingerBandsResult {
  final double middle;
  final double upper;
  final double lower;
  final double widthPercent;

  BollingerBandsResult({
    required this.middle,
    required this.upper,
    required this.lower,
    required this.widthPercent,
  });
}
