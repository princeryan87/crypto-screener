import '../../models/funding_rate_model.dart';
import '../../models/strategy_signal.dart';
import '../strategy_base.dart';

/// FUTURES #4: Divergence Hunter
/// Tujuan: filter kualitas, bedakan rally asli vs rally palsu (short
/// covering). Sifatnya label tambahan, bisa dipakai bersilang dengan
/// hasil strategi #1-3 (misal menandai sinyal Trend Confirm sebagai
/// "Weak Rally" jika ternyata juga match kondisi divergence).
///
/// Kondisi:
/// - Price change 4h >= +3% TAPI OI change 4h <= -3% -> "Weak Rally"
///   (short covering, bukan minat beli baru)
/// - Price change 4h <= -3% TAPI OI change 4h >= +5% dengan funding
///   negatif memburuk -> "Squeeze Setup" (potensi short squeeze)
///
/// Data dibutuhkan: price change 4h, OI sekarang + OI 4 jam lalu,
/// funding rate saat ini DAN funding rate sebelumnya (untuk cek
/// "memburuk" / semakin negatif).
class DivergenceHunterStrategy {
  static const double priceThreshold = 3.0;
  static const double weakRallyOiDropThreshold = -3.0;
  static const double squeezeSetupOiRiseThreshold = 5.0;

  StrategySignal? evaluate({
    required String symbol,
    required double priceChange4hPercent,
    required double oiNow,
    required double oi4hAgo,
    required FundingRateModel currentFundingRate,
    required double previousFundingRatePercent,
  }) {
    final oiChangePercent =
        oi4hAgo == 0 ? 0.0 : ((oiNow - oi4hAgo) / oi4hAgo) * 100;

    // Kondisi 1: Weak Rally (rally naik tapi OI turun = short
    // covering, bukan minat beli baru)
    if (priceChange4hPercent >= priceThreshold &&
        oiChangePercent <= weakRallyOiDropThreshold) {
      return StrategySignal(
        symbol: symbol,
        strategyName: StrategyName.divergenceHunter,
        market: MarketType.futures,
        direction: SignalDirection.warning,
        label: 'WEAK RALLY',
        reasoning:
            'Price +${priceChange4hPercent.toStringAsFixed(2)}% (4h) tapi '
            'OI ${oiChangePercent.toStringAsFixed(2)}% (4h) - rally '
            'kemungkinan dari short covering, bukan minat beli baru',
        indicatorValues: {
          'priceChange4hPercent': priceChange4hPercent,
          'oiChangePercent4h': oiChangePercent,
        },
      );
    }

    // Kondisi 2: Squeeze Setup (harga turun tapi OI naik + funding
    // negatif memburuk = potensi short squeeze terbentuk)
    final fundingWorsening = currentFundingRate.fundingRatePercent <
        previousFundingRatePercent;
    if (priceChange4hPercent <= -priceThreshold &&
        oiChangePercent >= squeezeSetupOiRiseThreshold &&
        currentFundingRate.fundingRatePercent < 0 &&
        fundingWorsening) {
      return StrategySignal(
        symbol: symbol,
        strategyName: StrategyName.divergenceHunter,
        market: MarketType.futures,
        direction: SignalDirection.watch,
        label: 'SQUEEZE SETUP',
        reasoning:
            'Price ${priceChange4hPercent.toStringAsFixed(2)}% (4h) tapi '
            'OI +${oiChangePercent.toStringAsFixed(2)}% (4h), funding '
            '${currentFundingRate.fundingRatePercent.toStringAsFixed(3)}% '
            'makin negatif - potensi short squeeze terbentuk',
        indicatorValues: {
          'priceChange4hPercent': priceChange4hPercent,
          'oiChangePercent4h': oiChangePercent,
          'fundingRatePercent': currentFundingRate.fundingRatePercent,
        },
      );
    }

    return null;
  }
}
