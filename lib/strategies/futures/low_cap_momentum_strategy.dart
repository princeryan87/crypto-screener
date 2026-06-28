import '../../models/kline_model.dart';
import '../../models/strategy_signal.dart';
import '../../utils/indicators.dart';
import '../strategy_base.dart';

/// FUTURES #3: Low Cap Momentum
/// Tujuan: versi spekulatif altcoin kecil di futures. HIGH RISK -
/// disclaimer leverage wajib ditampilkan tegas.
///
/// Kondisi:
/// - Di luar top 20 market cap/volume (disuplai dari luar sebagai
///   [isTopMarketCap])
/// - Price change 1h >= +8%
/// - OI change 1h >= +15%
/// - Volume surge >= 3x rata-rata 1h sebelumnya
///
/// Data dibutuhkan: klines 1h (untuk price change & volume), OI
/// sekarang + OI 1 jam lalu.
class LowCapMomentumFuturesStrategy {
  static const double minPriceChange1hPercent = 8.0;
  static const double minOiChange1hPercent = 15.0;
  static const double minVolumeMultiplier = 3.0;
  static const int volumeAvgLookbackCandles = 24; // 24 jam candle 1h

  StrategySignal? evaluate({
    required String symbol,
    required List<KlineModel> klines1h, // urutan lama -> baru
    required double oiNow,
    required double oi1hAgo,
    required bool isTopMarketCap,
  }) {
    if (isTopMarketCap) return null;
    if (klines1h.length < volumeAvgLookbackCandles + 1) return null;

    final lastCandle = klines1h.last;
    final volumes = klines1h.map((k) => k.volume).toList();

    // 1. Price change 1h
    final priceChangePercent = lastCandle.open == 0
        ? 0.0
        : ((lastCandle.close - lastCandle.open) / lastCandle.open) * 100;
    if (priceChangePercent < minPriceChange1hPercent) return null;

    // 2. OI change 1h - lonjakan posisi sangat tajam
    final oiChangePercent =
        oi1hAgo == 0 ? 0.0 : ((oiNow - oi1hAgo) / oi1hAgo) * 100;
    if (oiChangePercent < minOiChange1hPercent) return null;

    // 3. Volume surge
    final avgVolume1h = Indicators.sma(
      volumes.sublist(0, volumes.length - 1),
      period: volumeAvgLookbackCandles,
    );
    final volumeRatio =
        avgVolume1h == 0 ? 0.0 : lastCandle.volume / avgVolume1h;
    if (volumeRatio < minVolumeMultiplier) return null;

    return StrategySignal(
      symbol: symbol,
      strategyName: StrategyName.lowCapMomentumFutures,
      market: MarketType.futures,
      direction: SignalDirection.buy,
      label: 'HIGH RISK MOMENTUM',
      reasoning:
          'Price +${priceChangePercent.toStringAsFixed(2)}% (1h), '
          'OI +${oiChangePercent.toStringAsFixed(2)}% (1h), '
          'volume ${volumeRatio.toStringAsFixed(2)}x rata-rata 24h - '
          'leverage tinggi, risiko likuidasi besar',
      indicatorValues: {
        'priceChangePercent1h': priceChangePercent,
        'oiChangePercent1h': oiChangePercent,
        'volumeRatio': volumeRatio,
      },
      isHighRisk: true,
    );
  }
}
