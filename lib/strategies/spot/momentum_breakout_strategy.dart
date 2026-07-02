import '../../models/kline_model.dart';
import '../../models/ticker_model.dart';
import '../../models/strategy_signal.dart';
import '../../utils/indicators.dart';
import '../strategy_base.dart';

/// SPOT #1: Momentum Breakout
/// Pengganti BSJP - momentum murni tanpa syarat waktu/sesi.
///
/// Kondisi:
/// - Breakout: harga tembus resistance 24h high, body candle >= 1.5x ATR(14)
/// - Volume 1h >= 2x rata-rata volume 1h 7 hari terakhir
/// - RSI(14) antara 55-75 (momentum kuat, belum jenuh beli ekstrem)
/// - EMA9 > EMA21 (tren naik jangka pendek terkonfirmasi)
///
/// Data dibutuhkan: klines 1h (minimal 7 hari = 168 candle untuk
/// hitung rata-rata volume 7 hari + warm-up EMA21).
class MomentumBreakoutStrategy {
  final double minBodyToAtrRatio;
  final double minVolumeMultiplier;
  final double rsiLowerBound;
  final double rsiUpperBound;
  static const int atrPeriod = 14;
  static const int emaShortPeriod = 9;
  static const int emaLongPeriod = 21;
  static const int volumeAvgLookbackCandles = 168;

  const MomentumBreakoutStrategy({
    this.minBodyToAtrRatio = 1.5,
    this.minVolumeMultiplier = 2.0,
    this.rsiLowerBound = 55,
    this.rsiUpperBound = 75,
  });

  StrategySignal? evaluate({
    required String symbol,
    required TickerModel ticker,
    required List<KlineModel> klines1h, // urutan lama -> baru
  }) {
    if (klines1h.length < volumeAvgLookbackCandles) return null;

    final lastCandle = klines1h.last;
    final closes = klines1h.map((k) => k.close).toList();
    final volumes = klines1h.map((k) => k.volume).toList();

    // 1. Cek breakout terhadap resistance 24h high (dari ticker)
    final isBreakout = lastCandle.close > ticker.highPrice;
    if (!isBreakout) return null;

    // 2. Body candle vs ATR
    final atrValue = Indicators.atr(klines1h, atrPeriod);
    if (atrValue == null) return null;
    final bodyToAtrRatio = lastCandle.bodySize / atrValue;
    if (bodyToAtrRatio < minBodyToAtrRatio) return null;

    // 3. Volume 1h vs rata-rata 7 hari
    final avgVolume7d = Indicators.sma(
      volumes.sublist(0, volumes.length - 1),
      period: volumeAvgLookbackCandles,
    );
    final volumeRatio =
        avgVolume7d == 0 ? 0 : lastCandle.volume / avgVolume7d;
    if (volumeRatio < minVolumeMultiplier) return null;

    // 4. RSI dalam rentang momentum sehat
    final rsiValue = Indicators.rsi(closes, 14);
    if (rsiValue == null ||
        rsiValue < rsiLowerBound ||
        rsiValue > rsiUpperBound) {
      return null;
    }

    // 5. EMA9 > EMA21 (tren naik jangka pendek)
    final ema9 = Indicators.lastEma(closes, emaShortPeriod);
    final ema21 = Indicators.lastEma(closes, emaLongPeriod);
    if (ema9 == null || ema21 == null || ema9 <= ema21) return null;

    return StrategySignal(
      symbol: symbol,
      strategyName: StrategyName.momentumBreakout,
      market: MarketType.spot,
      direction: SignalDirection.buy,
      label: 'BUY',
      reasoning:
          'Breakout 24h high, body/ATR ${bodyToAtrRatio.toStringAsFixed(2)}x, '
          'volume ${volumeRatio.toStringAsFixed(2)}x rata-rata 7d, '
          'RSI ${rsiValue.toStringAsFixed(1)}, EMA9>EMA21',
      indicatorValues: {
        'bodyToAtrRatio': bodyToAtrRatio,
        'volumeRatio': volumeRatio.toDouble(),
        'rsi': rsiValue,
        'ema9': ema9,
        'ema21': ema21,
      },
    );
  }
}
