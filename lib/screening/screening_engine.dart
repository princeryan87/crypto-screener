import '../models/strategy_signal.dart';
import '../models/strategy_parameters.dart';
import '../models/ticker_model.dart';
import '../models/open_interest_model.dart';
import '../services/binance_api_service.dart';
import '../strategies/spot/momentum_breakout_strategy.dart';
import '../strategies/spot/whale_watch_strategy.dart';
import '../strategies/spot/low_cap_hunter_strategy.dart';
import '../strategies/spot/volume_surge_strategy.dart';
import '../strategies/spot/accumulation_zone_strategy.dart';
import '../strategies/futures/trend_confirm_strategy.dart';
import '../strategies/futures/squeeze_radar_strategy.dart';
import '../strategies/futures/low_cap_momentum_strategy.dart';
import '../strategies/futures/divergence_hunter_strategy.dart';

/// Orchestrator untuk analisis ON-DEMAND per pair tunggal.
///
/// PERUBAHAN ARSITEKTUR (dari versi screening massal sebelumnya):
/// screening semua pair sekaligus (broad filter -> shortlist -> deep
/// filter) DIHAPUS. Pendekatan itu cocok untuk saham IDX (jumlah
/// emiten terbatas, user mau "ditemukan kandidat baru"), tapi untuk
/// crypto kurang cocok karena: (1) jumlah pair Binance jauh lebih
/// banyak sehingga screening makan waktu 1-2 menit dan terasa
/// membosankan, (2) user crypto pada umumnya SUDAH punya target
/// koin spesifik di kepala, bukan mencari kandidat baru dari nol.
///
/// Sebagai gantinya, user menentukan SENDIRI pair yang mau dianalisis
/// (lewat 2 text field base+quote di LandingPage), lalu memilih
/// SENDIRI mode Spot atau Futures (2 tombol Analyze terpisah). Engine
/// ini hanya menjalankan strategi yang relevan untuk SATU pair & SATU
/// mode itu saja - jauh lebih cepat (hitungan detik, bukan menit).
///
/// CATATAN PENTING - belum diimplementasikan, perlu sumber data
/// tambahan:
/// - "isTopMarketCap" (dibutuhkan Low Cap Hunter & Low Cap Momentum)
///   TIDAK tersedia dari endpoint Binance manapun secara langsung.
///   Saat ini dipakai daftar hardcode 20 simbol sebagai placeholder.
class ScreeningEngine {
  final BinanceApiService _api = BinanceApiService();

  // Strategi yang parameternya tidak di-expose ke user (pakai
  // default tetap) - tetap sebagai field.
  final _lowCapHunter = LowCapHunterStrategy();
  final _volumeSurge = VolumeSurgeStrategy();
  final _divergenceHunter = DivergenceHunterStrategy();

  // Strategi dengan parameter yang bisa di-tune user (MomentumBreakout,
  // WhaleWatch, AccumulationZone, TrendConfirm, SqueezeRadar,
  // LowCapMomentumFutures) dibuat inline saat analisis dijalankan
  // dengan params dari StrategyParameters - lihat analyzeSpotPair &
  // analyzeFuturesPair.

  // ---------------------------------------------------------------
  // VALIDASI PAIR
  // ---------------------------------------------------------------

  /// Cek apakah [symbol] (misal "BTCUSDT") benar-benar listed & aktif
  /// trading di Binance untuk [market] yang dipilih. Dipanggil SAAT
  /// tombol Analyze ditekan, SEBELUM proses analisis dimulai - supaya
  /// user dapat feedback jelas & cepat kalau pair-nya salah ketik
  /// atau memang tidak ada di Binance.
  Future<bool> validatePairExists({
    required String symbol,
    required BinanceMarket market,
  }) async {
    final tradableSymbols = await _api.fetchTradableSymbols(market);
    return tradableSymbols.contains(symbol);
  }

  // ---------------------------------------------------------------
  // ANALISIS SPOT - SATU PAIR
  // ---------------------------------------------------------------

  /// Jalankan SEMUA 5 strategi Spot untuk satu [symbol]. Dipanggil
  /// dari tombol "ANALYZE SPOT".
  Future<List<StrategySignal>> analyzeSpotPair(
    String symbol,
    StrategyParameters params,
  ) async {
    final signals = <StrategySignal>[];

    final allTickers = await _api.fetchAllTickers(BinanceMarket.spot);
    final ticker = allTickers.firstWhere(
      (t) => t.symbol == symbol,
      orElse: () => throw ScreeningException(
        'Pair $symbol tidak ditemukan di Binance Spot.',
      ),
    );

    final klines1h = await _api.fetchKlines(
      market: BinanceMarket.spot,
      symbol: symbol,
      interval: '1h',
      limit: 168, // 7 hari, kebutuhan terbesar (Momentum Breakout)
    );
    final klines4h = await _api.fetchKlines(
      market: BinanceMarket.spot,
      symbol: symbol,
      interval: '4h',
      limit: 42, // 7 hari (Volume Surge)
    );
    final klinesDaily = await _api.fetchKlines(
      market: BinanceMarket.spot,
      symbol: symbol,
      interval: '1d',
      limit: 55, // 30 hari + buffer warm-up BB (Accumulation Zone)
    );
    final isTopCap = _isLikelyTopMarketCapPlaceholder(symbol);

    final momentumSignal = MomentumBreakoutStrategy(
      rsiLowerBound: params.spotRsiLower,
      rsiUpperBound: params.spotRsiUpper,
      minVolumeMultiplier: params.spotVolumeMultiplier,
    ).evaluate(
      symbol: symbol,
      ticker: ticker,
      klines1h: klines1h,
    );
    if (momentumSignal != null) signals.add(momentumSignal);

    final volumeSignal = _volumeSurge.evaluate(
      symbol: symbol,
      ticker: ticker,
      klines4h: klines4h,
    );
    if (volumeSignal != null) signals.add(volumeSignal);

    final accumulationSignal = AccumulationZoneStrategy(
      maxSidewaysRangePercent: params.spotSidewaysMaxRangePercent,
    ).evaluate(
      symbol: symbol,
      klinesDaily: klinesDaily,
      klines1h: klines1h.length > 24
          ? klines1h.sublist(klines1h.length - 24)
          : klines1h,
    );
    if (accumulationSignal != null) signals.add(accumulationSignal);

    final lowCapSignal = _lowCapHunter.evaluate(
      symbol: symbol,
      klines1h: klines1h,
      isTopMarketCap: isTopCap,
    );
    if (lowCapSignal != null) signals.add(lowCapSignal);

    try {
      final orderBook = await _api.fetchOrderBook(
        market: BinanceMarket.spot,
        symbol: symbol,
      );
      final klines15m = await _api.fetchKlines(
        market: BinanceMarket.spot,
        symbol: symbol,
        interval: '15m',
        limit: 30,
      );
      final whaleSignal = WhaleWatchStrategy(
        minBidAskImbalanceRatio: params.spotWhaleBidAskRatio,
      ).evaluate(
        symbol: symbol,
        orderBook: orderBook,
        klines15m: klines15m,
      );
      if (whaleSignal != null) signals.add(whaleSignal);
    } catch (_) {
      // Order book gagal di-fetch - lewati strategi Whale Watch saja,
      // strategi lain tetap valid dan dikembalikan.
    }

    return signals;
  }

  // ---------------------------------------------------------------
  // ANALISIS FUTURES - SATU PAIR
  // ---------------------------------------------------------------

  /// Jalankan SEMUA 4 strategi Futures untuk satu [symbol]. Dipanggil
  /// dari tombol "ANALYZE FUTURES".
  Future<List<StrategySignal>> analyzeFuturesPair(
    String symbol,
    StrategyParameters params,
  ) async {
    final signals = <StrategySignal>[];

    final allTickers = await _api.fetchAllTickers(BinanceMarket.futures);
    final ticker = allTickers.firstWhere(
      (t) => t.symbol == symbol,
      orElse: () => throw ScreeningException(
        'Pair $symbol tidak ditemukan di Binance Futures.',
      ),
    );

    final allFundingRates = await _api.fetchAllFundingRates();
    final fundingRate = allFundingRates.firstWhere(
      (f) => f.symbol == symbol,
      orElse: () => throw ScreeningException(
        'Data funding rate untuk $symbol tidak ditemukan.',
      ),
    );

    final klines1h = await _api.fetchKlines(
      market: BinanceMarket.futures,
      symbol: symbol,
      interval: '1h',
      limit: 30,
    );
    final klines4h = await _api.fetchKlines(
      market: BinanceMarket.futures,
      symbol: symbol,
      interval: '4h',
      limit: 10,
    );
    final oiHist = await _api.fetchOpenInterestHistory(
      symbol: symbol,
      period: '1h',
      limit: 30,
    );

    if (oiHist.length < 5) {
      // Data OI histori belum cukup untuk hitung % change - kembalikan
      // list kosong daripada error, karena pair-nya valid (sudah lolos
      // validatePairExists), cuma datanya belum lengkap.
      return signals;
    }

    final oiNow = oiHist.last.openInterest;
    final oi1hAgo = oiHist[oiHist.length - 2].openInterest;
    final oi4hAgo = oiHist[oiHist.length - 5].openInterest;
    final oi24hAgo = oiHist.first.openInterest;

    final priceChange4h = klines4h.length >= 2
        ? ((klines4h.last.close - klines4h[klines4h.length - 2].close) /
                klines4h[klines4h.length - 2].close) *
            100
        : 0.0;

    final trendSignal = TrendConfirmStrategy(
      minPriceChange4hPercent: params.futuresPriceChange4h,
      minOiChange4hPercent: params.futuresOiChange4h,
    ).evaluate(
      symbol: symbol,
      priceChange4hPercent: priceChange4h,
      fundingRate: fundingRate,
      oiNow: oiNow,
      oi4hAgo: oi4hAgo,
      currentVolume24h: ticker.quoteVolume,
      avgVolume7d: ticker.quoteVolume,
    );
    if (trendSignal != null) signals.add(trendSignal);

    if (klines1h.length >= 2) {
      final lastCandle = klines1h.last;
      final prevCandle = klines1h[klines1h.length - 2];
      final lastChange =
          ((lastCandle.close - lastCandle.open) / lastCandle.open) * 100;
      final prevChange =
          ((prevCandle.close - prevCandle.open) / prevCandle.open) * 100;

      final squeezeSignal = SqueezeRadarStrategy(
        extremeLongFundingThreshold: params.futuresFundingExtremeLong,
        extremeShortFundingThreshold: params.futuresFundingExtremeShort,
      ).evaluate(
        symbol: symbol,
        fundingRate: fundingRate,
        oiNow: oiNow,
        oi24hAgo: oi24hAgo,
        priceChange1hLastCandlePercent: lastChange,
        priceChange1hPreviousCandlePercent: prevChange,
      );
      if (squeezeSignal != null) signals.add(squeezeSignal);
    }

    final lowCapFuturesSignal = LowCapMomentumFuturesStrategy(
      minPriceChange1hPercent: params.futuresLowCapPriceChange1h,
    ).evaluate(
      symbol: symbol,
      klines1h: klines1h,
      oiNow: oiNow,
      oi1hAgo: oi1hAgo,
      isTopMarketCap: _isLikelyTopMarketCapPlaceholder(symbol),
    );
    if (lowCapFuturesSignal != null) signals.add(lowCapFuturesSignal);

    final divergenceSignal = _divergenceHunter.evaluate(
      symbol: symbol,
      priceChange4hPercent: priceChange4h,
      oiNow: oiNow,
      oi4hAgo: oi4hAgo,
      currentFundingRate: fundingRate,
      // TODO: histori funding rate asli, saat ini placeholder pakai
      // funding rate saat ini. Lihat README untuk detail.
      previousFundingRatePercent: fundingRate.fundingRatePercent,
    );
    if (divergenceSignal != null) signals.add(divergenceSignal);

    return signals;
  }

  /// PLACEHOLDER sementara untuk status top market cap. Lihat catatan
  /// kelas di atas - keputusan final perlu didiskusikan: pakai daftar
  /// hardcode atau proxy quoteVolume.
  bool _isLikelyTopMarketCapPlaceholder(String symbol) {
    const topSymbols = {
      'BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'SOLUSDT', 'XRPUSDT',
      'ADAUSDT', 'DOGEUSDT', 'AVAXUSDT', 'TRXUSDT', 'DOTUSDT',
      'LINKUSDT', 'MATICUSDT', 'TONUSDT', 'SHIBUSDT', 'LTCUSDT',
      'BCHUSDT', 'NEARUSDT', 'UNIUSDT', 'ATOMUSDT', 'XLMUSDT',
    };
    return topSymbols.contains(symbol);
  }
}

class ScreeningException implements Exception {
  final String message;
  ScreeningException(this.message);

  @override
  String toString() => message;
}
