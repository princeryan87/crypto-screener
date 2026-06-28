import '../../models/kline_model.dart';
import '../../models/strategy_signal.dart';
import '../../utils/indicators.dart';
import '../strategy_base.dart';

/// SPOT #5: Accumulation Zone
/// Pengganti Akumulasi Sesi 2 - pakai Bollinger Band squeeze tanpa
/// syarat sesi waktu.
///
/// Kondisi:
/// - BB Width (20, 2) di persentil 20% terendah dari 30 hari terakhir
/// - Price sideways ketat (high-low 24h <= 4%) selama minimal 6 jam
///   terakhir
/// - Volume naik perlahan 3 candle 1h terakhir (tren naik, bukan
///   spike)
///
/// Data dibutuhkan: klines 1d (35 candle, untuk persentil 30 hari)
/// DAN klines 1h (minimal 6+ candle untuk cek sideways & volume tren).
///
/// CATATAN: ini satu-satunya strategi yang butuh DUA timeframe klines
/// berbeda sekaligus (1d untuk BB Width histori, 1h untuk kondisi
/// sideways & volume jangka pendek) - sesuai keputusan "jumlah candle
/// per kebutuhan indikator", bukan satu angka universal.
class AccumulationZoneStrategy {
  static const int bbPeriod = 20;
  static const double bbStdDevMultiplier = 2.0;
  static const double maxBbWidthPercentileRank = 20.0;
  static const double maxSidewaysRangePercent = 4.0;
  static const int minSidewaysHours = 6;
  static const int dailyHistoryDays = 30;

  StrategySignal? evaluate({
    required String symbol,
    required List<KlineModel> klinesDaily, // 35 candle 1d, lama -> baru
    required List<KlineModel> klines1h, // minimal 6+ candle, lama -> baru
  }) {
    if (klinesDaily.length < dailyHistoryDays + bbPeriod) return null;
    if (klines1h.length < minSidewaysHours) return null;

    // 1. Hitung BB Width untuk setiap hari dalam 30 hari terakhir,
    // lalu cek persentil BB Width HARI INI dibanding histori tersebut.
    final dailyCloses = klinesDaily.map((k) => k.close).toList();
    final bbWidthHistory = <double>[];

    for (int i = bbPeriod; i <= dailyCloses.length; i++) {
      final window = dailyCloses.sublist(0, i);
      final bb = Indicators.bollingerBands(
        window,
        bbPeriod,
        stdDevMultiplier: bbStdDevMultiplier,
      );
      if (bb != null) bbWidthHistory.add(bb.widthPercent);
    }

    if (bbWidthHistory.length < dailyHistoryDays) return null;

    final currentBbWidth = bbWidthHistory.last;
    final last30DaysWidths =
        bbWidthHistory.sublist(bbWidthHistory.length - dailyHistoryDays);
    final percentileRank = Indicators.percentileRank(
      last30DaysWidths,
      currentBbWidth,
    );
    if (percentileRank > maxBbWidthPercentileRank) return null;

    // 2. Sideways ketat minimal 6 jam terakhir (pakai klines 1h)
    final recentHours = klines1h.sublist(klines1h.length - minSidewaysHours);
    final highestHigh =
        recentHours.map((k) => k.high).reduce((a, b) => a > b ? a : b);
    final lowestLow =
        recentHours.map((k) => k.low).reduce((a, b) => a < b ? a : b);
    final sidewaysRangePercent =
        lowestLow == 0 ? 100.0 : ((highestHigh - lowestLow) / lowestLow) * 100;
    if (sidewaysRangePercent > maxSidewaysRangePercent) return null;

    // 3. Volume naik perlahan 3 candle 1h terakhir (tren naik halus,
    // bukan spike tunggal)
    if (klines1h.length < 3) return null;
    final last3Volumes =
        klines1h.sublist(klines1h.length - 3).map((k) => k.volume).toList();
    final isVolumeTrendingUp =
        last3Volumes[0] < last3Volumes[1] && last3Volumes[1] < last3Volumes[2];
    if (!isVolumeTrendingUp) return null;

    return StrategySignal(
      symbol: symbol,
      strategyName: StrategyName.accumulationZone,
      market: MarketType.spot,
      direction: SignalDirection.watch,
      label: 'WATCH',
      reasoning:
          'BB Width persentil ${percentileRank.toStringAsFixed(1)}% '
          '(30 hari terakhir), sideways '
          '${sidewaysRangePercent.toStringAsFixed(2)}% selama '
          '$minSidewaysHours jam, volume naik bertahap - breakout setup, '
          'arah belum pasti',
      indicatorValues: {
        'bbWidthPercentileRank': percentileRank,
        'sidewaysRangePercent': sidewaysRangePercent,
        'currentBbWidth': currentBbWidth,
      },
    );
  }
}
