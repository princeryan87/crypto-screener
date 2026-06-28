import '../../models/kline_model.dart';
import '../../models/ticker_model.dart';
import '../../models/strategy_signal.dart';
import '../../utils/indicators.dart';
import '../strategy_base.dart';

/// SPOT #4: Volume Surge
/// Pengganti Big Money Flow - deteksi lonjakan minat beli besar.
///
/// Kondisi:
/// - Volume 24h >= 2.5x rata-rata volume 24h 7 hari terakhir
/// - Price change 24h positif tapi belum ekstrem (+2% s/d +8%)
/// - Minimal 4 dari 6 candle 4h terakhir hijau (akumulasi bertahap)
///
/// Data dibutuhkan: ticker (untuk price change & volume 24h saat ini)
/// + klines 4h (minimal 7 hari = 42 candle untuk rata-rata volume +
/// cek 6 candle terakhir).
class VolumeSurgeStrategy {
  static const double minVolumeMultiplier = 2.5;
  static const double minPriceChangePercent = 2.0;
  static const double maxPriceChangePercent = 8.0;
  static const int minGreenCandlesOutOf6 = 4;
  static const int volumeAvgLookbackCandles = 42; // 7 hari x 6 candle 4h

  StrategySignal? evaluate({
    required String symbol,
    required TickerModel ticker,
    required List<KlineModel> klines4h, // urutan lama -> baru
  }) {
    if (klines4h.length < volumeAvgLookbackCandles) return null;

    // 1. Price change 24h dalam rentang sehat (belum FOMO ekstrem)
    if (ticker.priceChangePercent < minPriceChangePercent ||
        ticker.priceChangePercent > maxPriceChangePercent) {
      return null;
    }

    // 2. Volume 24h vs rata-rata 7 hari. Pendekatan: jumlahkan volume
    // 6 candle 4h terakhir sebagai proxy volume 24h, bandingkan
    // dengan rata-rata volume per-blok-24h dari histori 7 hari.
    final last6 = klines4h.sublist(klines4h.length - 6);
    final volume24hNow = last6.fold(0.0, (sum, k) => sum + k.volume);

    final historicalBlocks = <double>[];
    // Iterasi blok 6-candle (=24 jam) dari histori sebelum 6 candle
    // terakhir, mundur sejauh data tersedia.
    final usableHistory = klines4h.sublist(0, klines4h.length - 6);
    for (int i = 0; i + 6 <= usableHistory.length; i += 6) {
      final block = usableHistory.sublist(i, i + 6);
      historicalBlocks.add(block.fold(0.0, (sum, k) => sum + k.volume));
    }
    if (historicalBlocks.isEmpty) return null;

    final avgVolume24h = Indicators.sma(historicalBlocks);
    final volumeRatio =
        avgVolume24h == 0 ? 0 : volume24hNow / avgVolume24h;
    if (volumeRatio < minVolumeMultiplier) return null;

    // 3. Konsistensi: minimal 4 dari 6 candle 4h terakhir hijau
    final greenCount = last6.where((k) => k.isGreen).length;
    if (greenCount < minGreenCandlesOutOf6) return null;

    return StrategySignal(
      symbol: symbol,
      strategyName: StrategyName.volumeSurge,
      market: MarketType.spot,
      direction: SignalDirection.buy,
      label: 'BUY',
      reasoning:
          'Price +${ticker.priceChangePercent.toStringAsFixed(2)}% (24h), '
          'volume ${volumeRatio.toStringAsFixed(2)}x rata-rata 7d, '
          '$greenCount/6 candle 4h hijau (akumulasi bertahap)',
      indicatorValues: {
        'priceChangePercent24h': ticker.priceChangePercent,
        'volumeRatio': volumeRatio.toDouble(),
        'greenCandleCount': greenCount.toDouble(),
      },
    );
  }
}
