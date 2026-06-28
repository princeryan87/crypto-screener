import '../../models/ticker_model.dart';
import '../../models/funding_rate_model.dart';
import '../../models/open_interest_model.dart';
import '../../models/strategy_signal.dart';
import '../strategy_base.dart';

/// FUTURES #1: Trend Confirm (OI + Price)
/// Tujuan: tangkap tren sehat sebelum terlalu crowded.
///
/// Kondisi (simetris untuk LONG dan SHORT):
/// - Price change 4h >= +3% (LONG) atau <= -3% (SHORT)
/// - OI change 4h searah dengan price change, >= +5% (magnitude)
/// - Funding rate dalam rentang wajar: -0.03% s/d +0.05%
/// - Volume 24h >= 1.5x rata-rata volume 7 hari
///
/// Data dibutuhkan: ticker (volume 24h + proxy price change), funding
/// rate saat ini, OI sekarang + OI 4 jam lalu (dari openInterestHist),
/// dan rata-rata volume 7 hari (dihitung dari klines di luar method
/// ini, disuplai sebagai parameter agar strategi tidak perlu tahu
/// soal klines sama sekali).
class TrendConfirmStrategy {
  static const double minPriceChange4hPercent = 3.0;
  static const double minOiChange4hPercent = 5.0;
  static const double fundingMin = -0.03;
  static const double fundingMax = 0.05;
  static const double minVolumeMultiplier = 1.5;

  StrategySignal? evaluate({
    required String symbol,
    required double priceChange4hPercent, // dihitung dari klines 4h
    // candle terakhir vs candle 1 periode sebelumnya
    required FundingRateModel fundingRate,
    required double oiNow,
    required double oi4hAgo,
    required double currentVolume24h,
    required double avgVolume7d,
  }) {
    // 1. Tentukan arah berdasarkan price change 4h
    final isLongCandidate = priceChange4hPercent >= minPriceChange4hPercent;
    final isShortCandidate = priceChange4hPercent <= -minPriceChange4hPercent;
    if (!isLongCandidate && !isShortCandidate) return null;

    // 2. OI change harus searah dan signifikan
    final oiChangePercent = oi4hAgo == 0
        ? 0.0
        : ((oiNow - oi4hAgo) / oi4hAgo) * 100;

    if (isLongCandidate && oiChangePercent < minOiChange4hPercent) {
      return null;
    }
    if (isShortCandidate && oiChangePercent < minOiChange4hPercent) {
      // Untuk short, OI juga harus naik signifikan (posisi short baru
      // masuk, bukan cuma long yang ditutup / short covering).
      return null;
    }

    // 3. Funding rate masih wajar, belum FOMO ekstrem
    if (!fundingRate.isFundingNormalRange(min: fundingMin, max: fundingMax)) {
      return null;
    }

    // 4. Volume konfirmasi partisipasi pasar
    final volumeRatio =
        avgVolume7d == 0 ? 0.0 : currentVolume24h / avgVolume7d;
    if (volumeRatio < minVolumeMultiplier) return null;

    final direction =
        isLongCandidate ? SignalDirection.buy : SignalDirection.sell;
    final label = isLongCandidate ? 'LONG' : 'SHORT';

    return StrategySignal(
      symbol: symbol,
      strategyName: StrategyName.trendConfirm,
      market: MarketType.futures,
      direction: direction,
      label: label,
      reasoning:
          'Price ${priceChange4hPercent.toStringAsFixed(2)}% (4h), '
          'OI ${oiChangePercent.toStringAsFixed(2)}% (4h, searah), '
          'funding ${fundingRate.fundingRatePercent.toStringAsFixed(3)}% '
          '(wajar), volume ${volumeRatio.toStringAsFixed(2)}x rata-rata 7d',
      indicatorValues: {
        'priceChange4hPercent': priceChange4hPercent,
        'oiChangePercent4h': oiChangePercent,
        'fundingRatePercent': fundingRate.fundingRatePercent,
        'volumeRatio': volumeRatio,
      },
    );
  }
}
