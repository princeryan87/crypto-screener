import '../../models/funding_rate_model.dart';
import '../../models/strategy_signal.dart';
import '../strategy_base.dart';

/// FUTURES #2: Long/Short Squeeze Radar
/// Tujuan: cari titik rawan likuidasi berantai (kontrarian, scalp
/// cepat).
///
/// Kondisi:
/// - Funding rate ekstrem: >= +0.10% (rawan long squeeze) atau
///   <= -0.08% (rawan short squeeze)
/// - OI 24h >= +10% (leverage menumpuk cepat)
/// - Price change 1h mulai melambat/stagnan dibanding momentum
///   sebelumnya (tanda kehabisan tenaga)
///
/// Data dibutuhkan: funding rate saat ini, OI sekarang + OI 24h lalu,
/// price change 1h candle terakhir DAN candle sebelumnya (untuk
/// deteksi momentum melambat).
class SqueezeRadarStrategy {
  final double extremeLongFundingThreshold;
  final double extremeShortFundingThreshold;
  static const double minOiChange24hPercent = 10.0;
  static const double momentumSlowdownRatio = 0.5;

  const SqueezeRadarStrategy({
    this.extremeLongFundingThreshold = 0.10,
    this.extremeShortFundingThreshold = -0.08,
  });

  StrategySignal? evaluate({
    required String symbol,
    required FundingRateModel fundingRate,
    required double oiNow,
    required double oi24hAgo,
    required double priceChange1hLastCandlePercent,
    required double priceChange1hPreviousCandlePercent,
  }) {
    // 1. Funding rate harus ekstrem ke salah satu arah
    final isExtremeLong = fundingRate.isExtremeLongFunding(
      threshold: extremeLongFundingThreshold,
    );
    final isExtremeShort = fundingRate.isExtremeShortFunding(
      threshold: extremeShortFundingThreshold,
    );
    if (!isExtremeLong && !isExtremeShort) return null;

    // 2. OI naik signifikan dalam 24 jam (leverage menumpuk)
    final oiChangePercent =
        oi24hAgo == 0 ? 0.0 : ((oiNow - oi24hAgo) / oi24hAgo) * 100;
    if (oiChangePercent < minOiChange24hPercent) return null;

    // 3. Momentum mulai melambat dibanding candle sebelumnya (arah
    // sama tapi magnitude mengecil signifikan)
    final sameDirection = (priceChange1hLastCandlePercent >= 0) ==
        (priceChange1hPreviousCandlePercent >= 0);
    if (!sameDirection) return null;

    final lastMagnitude = priceChange1hLastCandlePercent.abs();
    final prevMagnitude = priceChange1hPreviousCandlePercent.abs();
    if (prevMagnitude == 0) return null;

    final isSlowingDown =
        (lastMagnitude / prevMagnitude) <= momentumSlowdownRatio;
    if (!isSlowingDown) return null;

    final warningDirection = isExtremeLong
        ? 'LONG SQUEEZE (potensi koreksi turun)'
        : 'SHORT SQUEEZE (potensi rebound naik)';

    return StrategySignal(
      symbol: symbol,
      strategyName: StrategyName.squeezeRadar,
      market: MarketType.futures,
      direction: SignalDirection.warning,
      label: 'WARNING REVERSAL',
      reasoning:
          'Funding ${fundingRate.fundingRatePercent.toStringAsFixed(3)}% '
          'ekstrem, OI +${oiChangePercent.toStringAsFixed(2)}% (24h), '
          'momentum melambat - indikasi $warningDirection',
      indicatorValues: {
        'fundingRatePercent': fundingRate.fundingRatePercent,
        'oiChangePercent24h': oiChangePercent,
        'lastCandleMagnitude': lastMagnitude,
        'prevCandleMagnitude': prevMagnitude,
      },
    );
  }
}
