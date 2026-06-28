import '../../models/kline_model.dart';
import '../../models/orderbook_model.dart';
import '../../models/strategy_signal.dart';
import '../../utils/indicators.dart';
import '../strategy_base.dart';

/// SPOT #2: Whale Watch (Order Book + Volume)
/// Pengganti Bandarmology - deteksi akumulasi besar via order book.
///
/// Kondisi:
/// - Order book imbalance: bid volume dalam 1% dari harga >= 3x ask
///   volume di range yang sama (wall beli besar)
/// - Volume spike candle 15m >= 4x rata-rata, tapi price change kecil
///   (<1%) -> indikasi absorption/akumulasi diam-diam
/// - Bid/ask spread menyempit dibanding rata-rata 1h
///
/// Data dibutuhkan: order book snapshot + klines 15m (minimal ~30
/// candle untuk rata-rata volume & spread historis).
///
/// CATATAN: order book hanya snapshot SAAT INI (tidak ada histori
/// spread dari Binance), jadi perbandingan "spread menyempit vs
/// rata-rata 1h" didekati dengan membandingkan range high-low candle
/// 15m sebagai proxy volatilitas/likuiditas, BUKAN spread historis
/// asli (Binance tidak punya endpoint historical order book gratis).
class WhaleWatchStrategy {
  static const double minBidAskImbalanceRatio = 3.0;
  static const double minVolumeSpikeMultiplier = 4.0;
  static const double maxPriceChangePercent = 1.0;
  static const double orderBookRangePercent = 1.0;
  static const int volumeAvgLookbackCandles = 28; // ~7 jam candle 15m

  StrategySignal? evaluate({
    required String symbol,
    required OrderBookModel orderBook,
    required List<KlineModel> klines15m, // urutan lama -> baru
  }) {
    if (klines15m.length < volumeAvgLookbackCandles + 1) return null;

    final lastCandle = klines15m.last;
    final volumes = klines15m.map((k) => k.volume).toList();

    // 1. Order book imbalance
    final imbalanceRatio = orderBook.bidAskImbalanceRatio(
      priceRangePercent: orderBookRangePercent,
    );
    if (imbalanceRatio < minBidAskImbalanceRatio) return null;

    // 2. Volume spike tapi price change kecil (absorption pattern)
    final avgVolume = Indicators.sma(
      volumes.sublist(0, volumes.length - 1),
      period: volumeAvgLookbackCandles,
    );
    final volumeRatio = avgVolume == 0 ? 0 : lastCandle.volume / avgVolume;
    if (volumeRatio < minVolumeSpikeMultiplier) return null;

    final priceChangePercent = lastCandle.open == 0
        ? 0
        : ((lastCandle.close - lastCandle.open) / lastCandle.open).abs() *
            100;
    if (priceChangePercent >= maxPriceChangePercent) return null;

    // 3. Spread saat ini relatif sempit (proxy likuiditas padat)
    final currentSpread = orderBook.spreadPercent;
    // Threshold spread sempit: di bawah 0.15% dianggap padat untuk
    // pair USDT mayoritas. Disesuaikan kasar karena tidak ada histori
    // spread asli dari Binance public API.
    if (currentSpread > 0.15) return null;

    return StrategySignal(
      symbol: symbol,
      strategyName: StrategyName.whaleWatch,
      market: MarketType.spot,
      direction: SignalDirection.watch,
      label: 'ACCUMULATION DETECTED',
      reasoning:
          'Bid/ask imbalance ${imbalanceRatio.toStringAsFixed(2)}x, '
          'volume spike ${volumeRatio.toStringAsFixed(2)}x dengan price '
          'change hanya ${priceChangePercent.toStringAsFixed(2)}%, '
          'spread ${currentSpread.toStringAsFixed(3)}%',
      indicatorValues: {
        'bidAskImbalanceRatio': imbalanceRatio,
        'volumeRatio': volumeRatio.toDouble(),
        'priceChangePercent': priceChangePercent.toDouble(),
        'spreadPercent': currentSpread,
      },
    );
  }
}
