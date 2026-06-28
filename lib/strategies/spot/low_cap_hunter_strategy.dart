import '../../models/kline_model.dart';
import '../../models/ticker_model.dart';
import '../../models/strategy_signal.dart';
import '../../utils/indicators.dart';
import '../strategy_base.dart';

/// SPOT #3: Low Cap Hunter
/// Pengganti Gorengan Hunter - versi spot, lebih agresif dari
/// Momentum Breakout. HIGH RISK - disclaimer volatilitas wajib.
///
/// Kondisi:
/// - Di luar top 30 market cap (disuplai dari luar sebagai
///   [isTopMarketCap], karena market cap bukan dari endpoint
///   ticker/klines - perlu sumber data terpisah, lihat catatan di
///   ScreeningEngine)
/// - Price change 1h >= +10%
/// - Volume 1h >= 5x rata-rata 1h 24 jam sebelumnya
/// - ATR% (14, timeframe 1h) >= 5%
///
/// Data dibutuhkan: klines 1h (minimal 25 candle untuk rata-rata
/// volume 24h + ATR14).
class LowCapHunterStrategy {
  static const double minPriceChange1hPercent = 10.0;
  static const double minVolumeMultiplier = 5.0;
  static const double minAtrPercent = 5.0;
  static const int atrPeriod = 14;
  static const int volumeAvgLookbackCandles = 24; // 24 jam candle 1h

  StrategySignal? evaluate({
    required String symbol,
    required List<KlineModel> klines1h, // urutan lama -> baru
    required bool isTopMarketCap, // true jika termasuk top 30, hasil
    // filter strategi ini WAJIB false
  }) {
    if (isTopMarketCap) return null;
    if (klines1h.length < volumeAvgLookbackCandles + 1) return null;

    final lastCandle = klines1h.last;
    final volumes = klines1h.map((k) => k.volume).toList();

    // 1. Price change 1h candle terakhir
    final priceChangePercent = lastCandle.open == 0
        ? 0
        : ((lastCandle.close - lastCandle.open) / lastCandle.open) * 100;
    if (priceChangePercent < minPriceChange1hPercent) return null;

    // 2. Volume surge vs rata-rata 24 jam sebelumnya
    final avgVolume24h = Indicators.sma(
      volumes.sublist(0, volumes.length - 1),
      period: volumeAvgLookbackCandles,
    );
    final volumeRatio =
        avgVolume24h == 0 ? 0 : lastCandle.volume / avgVolume24h;
    if (volumeRatio < minVolumeMultiplier) return null;

    // 3. ATR% konfirmasi volatilitas asli
    final atrPct = Indicators.atrPercent(klines1h, atrPeriod);
    if (atrPct == null || atrPct < minAtrPercent) return null;

    return StrategySignal(
      symbol: symbol,
      strategyName: StrategyName.lowCapHunter,
      market: MarketType.spot,
      direction: SignalDirection.buy,
      label: 'HIGH RISK MOMENTUM',
      reasoning:
          'Price +${priceChangePercent.toStringAsFixed(2)}% (1h), '
          'volume ${volumeRatio.toStringAsFixed(2)}x rata-rata 24h, '
          'ATR ${atrPct.toStringAsFixed(2)}% (volatilitas terkonfirmasi)',
      indicatorValues: {
        'priceChangePercent1h': priceChangePercent.toDouble(),
        'volumeRatio': volumeRatio.toDouble(),
        'atrPercent': atrPct,
      },
      isHighRisk: true,
    );
  }
}
