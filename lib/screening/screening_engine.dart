import '../models/strategy_signal.dart';
import '../models/ticker_model.dart';
import '../models/open_interest_model.dart';
import '../services/binance_api_service.dart';
import '../services/cache_service.dart';
import '../strategies/spot/momentum_breakout_strategy.dart';
import '../strategies/spot/whale_watch_strategy.dart';
import '../strategies/spot/low_cap_hunter_strategy.dart';
import '../strategies/spot/volume_surge_strategy.dart';
import '../strategies/spot/accumulation_zone_strategy.dart';
import '../strategies/futures/trend_confirm_strategy.dart';
import '../strategies/futures/squeeze_radar_strategy.dart';
import '../strategies/futures/low_cap_momentum_strategy.dart';
import '../strategies/futures/divergence_hunter_strategy.dart';

/// Orchestrator utama yang menjalankan alur hybrid 2 tahap:
///
/// TAHAP 1 (broad filter): fetch ticker 24hr + funding rate (Futures)
/// untuk SEMUA pairs sekaligus, filter kasar by price change & volume
/// untuk hasilkan shortlist kandidat.
///
/// TAHAP 2 (deep filter): fetch klines/order book/OI HANYA untuk
/// shortlist, jalankan semua strategi, kumpulkan sinyal.
///
/// CATATAN PENTING - belum diimplementasikan di sini, perlu sumber
/// data tambahan:
/// - "isTopMarketCap" (dibutuhkan Low Cap Hunter & Low Cap Momentum)
///   TIDAK tersedia dari endpoint Binance manapun secara langsung.
///   Pendekatan paling praktis: hardcode daftar simbol top N (misal
///   top 20-30 by market cap dari CoinMarketCap/CoinGecko, di-update
///   manual sesekali) ATAU pakai ranking berdasarkan quoteVolume dari
///   ticker 24hr sebagai PROXY market cap (tidak akurat 100% tapi
///   tidak butuh API eksternal tambahan). Keputusan ini belum
///   difinalkan - perlu didiskusikan di sesi berikutnya.
class ScreeningEngine {
  final BinanceApiService _api = BinanceApiService();
  final CacheService _cache = CacheService();

  // Spot strategies
  final _momentumBreakout = MomentumBreakoutStrategy();
  final _whaleWatch = WhaleWatchStrategy();
  final _lowCapHunter = LowCapHunterStrategy();
  final _volumeSurge = VolumeSurgeStrategy();
  final _accumulationZone = AccumulationZoneStrategy();

  // Futures strategies
  final _trendConfirm = TrendConfirmStrategy();
  final _squeezeRadar = SqueezeRadarStrategy();
  final _lowCapMomentumFutures = LowCapMomentumFuturesStrategy();
  final _divergenceHunter = DivergenceHunterStrategy();

  /// Threshold broad filter tahap 1 - longgar, tujuannya cuma
  /// mempersempit dari ratusan pairs jadi puluhan kandidat sebelum
  /// fetch detail yang lebih mahal. Threshold detail per-strategi
  /// yang sebenarnya tetap dicek di tahap 2 oleh masing-masing kelas
  /// strategi.
  static const double broadFilterMinAbsPriceChangePercent = 2.0;

  // ---------------------------------------------------------------
  // SPOT SCREENING
  // ---------------------------------------------------------------

  Future<List<StrategySignal>> runSpotScreening() async {
    // TAHAP 1: broad filter
    final allTickers = await _cache.getOrFetch(
      key: 'spot_tickers_all',
      ttl: CacheTtl.tickerBroadFilter,
      fetcher: () => _api.fetchAllTickers(BinanceMarket.spot),
    );

    final usdtTickers = allTickers
        .where((t) => t.symbol.endsWith('USDT'))
        .toList();

    final shortlist = usdtTickers
        .where((t) =>
            t.priceChangePercent.abs() >= broadFilterMinAbsPriceChangePercent ||
            t.quoteVolume > 0) // volume surge butuh ini, threshold
        // detail dicek di tahap 2 oleh masing-masing strategi
        .toList();

    final shortlistSymbols = shortlist.map((t) => t.symbol).toList();

    // TAHAP 2: deep filter - fetch klines untuk shortlist
    final klines1h = await _api.batchFetchKlines(
      market: BinanceMarket.spot,
      symbols: shortlistSymbols,
      interval: '1h',
      limit: 168, // 7 hari, kebutuhan terbesar (Momentum Breakout)
    );

    final klines4h = await _api.batchFetchKlines(
      market: BinanceMarket.spot,
      symbols: shortlistSymbols,
      interval: '4h',
      limit: 42, // 7 hari (Volume Surge)
    );

    final klinesDaily = await _api.batchFetchKlines(
      market: BinanceMarket.spot,
      symbols: shortlistSymbols,
      interval: '1d',
      limit: 55, // 30 hari + 20 warm-up BB (Accumulation Zone)
    );

    final signals = <StrategySignal>[];
    final tickerBySymbol = {for (final t in shortlist) t.symbol: t};

    for (final symbol in shortlistSymbols) {
      final ticker = tickerBySymbol[symbol];
      if (ticker == null) continue;

      // Momentum Breakout butuh klines1h lengkap
      final k1h = klines1h[symbol];
      if (k1h != null) {
        final signal = _momentumBreakout.evaluate(
          symbol: symbol,
          ticker: ticker,
          klines1h: k1h,
        );
        if (signal != null) signals.add(signal);
      }

      // Volume Surge butuh ticker + klines4h
      final k4h = klines4h[symbol];
      if (k4h != null) {
        final signal = _volumeSurge.evaluate(
          symbol: symbol,
          ticker: ticker,
          klines4h: k4h,
        );
        if (signal != null) signals.add(signal);
      }

      // Accumulation Zone butuh klinesDaily + klines1h
      final kDaily = klinesDaily[symbol];
      if (kDaily != null && k1h != null) {
        final signal = _accumulationZone.evaluate(
          symbol: symbol,
          klinesDaily: kDaily,
          klines1h: k1h.length > 24 ? k1h.sublist(k1h.length - 24) : k1h,
        );
        if (signal != null) signals.add(signal);
      }

      // Low Cap Hunter butuh klines1h + status top market cap
      // (TODO: ganti hardcode placeholder ini, lihat catatan di atas)
      if (k1h != null) {
        final signal = _lowCapHunter.evaluate(
          symbol: symbol,
          klines1h: k1h,
          isTopMarketCap: _isLikelyTopMarketCapPlaceholder(symbol),
        );
        if (signal != null) signals.add(signal);
      }

      // Whale Watch butuh order book - HANYA dipanggil untuk symbol
      // yang sudah punya minat awal (price change cukup besar ATAU
      // volume cukup besar), supaya tidak fetch order book untuk
      // semua shortlist (mahal weight-nya).
      final worthCheckingOrderBook =
          ticker.priceChangePercent.abs() >= 1.0 || ticker.quoteVolume > 0;
      if (worthCheckingOrderBook && k1h != null && k1h.length >= 30) {
        try {
          final orderBook = await _api.fetchOrderBook(
            market: BinanceMarket.spot,
            symbol: symbol,
          );
          // Whale Watch butuh klines15m yang belum kita fetch di atas
          // - perlu fetch tambahan terpisah HANYA untuk kandidat ini.
          final klines15m = await _api.fetchKlines(
            market: BinanceMarket.spot,
            symbol: symbol,
            interval: '15m',
            limit: 30,
          );
          final signal = _whaleWatch.evaluate(
            symbol: symbol,
            orderBook: orderBook,
            klines15m: klines15m,
          );
          if (signal != null) signals.add(signal);
        } catch (_) {
          // Lewati symbol ini jika order book gagal di-fetch, jangan
          // gagalkan seluruh proses screening.
        }
      }
    }

    return signals;
  }

  // ---------------------------------------------------------------
  // FUTURES SCREENING
  // ---------------------------------------------------------------

  Future<List<StrategySignal>> runFuturesScreening() async {
    // TAHAP 1: broad filter
    final allTickers = await _cache.getOrFetch(
      key: 'futures_tickers_all',
      ttl: CacheTtl.tickerBroadFilter,
      fetcher: () => _api.fetchAllTickers(BinanceMarket.futures),
    );
    final allFundingRates = await _cache.getOrFetch(
      key: 'futures_funding_all',
      ttl: CacheTtl.fundingRate,
      fetcher: () => _api.fetchAllFundingRates(),
    );

    final usdtTickers =
        allTickers.where((t) => t.symbol.endsWith('USDT')).toList();
    final fundingBySymbol = {
      for (final f in allFundingRates) f.symbol: f,
    };

    final shortlist = usdtTickers
        .where((t) =>
            t.priceChangePercent.abs() >= broadFilterMinAbsPriceChangePercent)
        .toList();
    final shortlistSymbols = shortlist.map((t) => t.symbol).toList();

    // TAHAP 2: deep filter
    final klines1h = await _api.batchFetchKlines(
      market: BinanceMarket.futures,
      symbols: shortlistSymbols,
      interval: '1h',
      limit: 30,
    );
    final klines4h = await _api.batchFetchKlines(
      market: BinanceMarket.futures,
      symbols: shortlistSymbols,
      interval: '4h',
      limit: 10,
    );

    final signals = <StrategySignal>[];
    final tickerBySymbol = {for (final t in shortlist) t.symbol: t};

    for (final symbol in shortlistSymbols) {
      final ticker = tickerBySymbol[symbol];
      final fundingRate = fundingBySymbol[symbol];
      if (ticker == null || fundingRate == null) continue;

      // Fetch OI histori - per-symbol, HANYA untuk shortlist
      List<OpenInterestModel> oiHist;
      try {
        oiHist = await _api.fetchOpenInterestHistory(
          symbol: symbol,
          period: '1h',
          limit: 30,
        );
      } catch (_) {
        continue; // lewati symbol ini jika OI histori gagal di-fetch
      }
      if (oiHist.length < 5) continue;

      final oiNow = oiHist.last.openInterest;
      final oi1hAgo = oiHist[oiHist.length - 2].openInterest;
      final oi4hAgo = oiHist.length >= 5
          ? oiHist[oiHist.length - 5].openInterest
          : oi1hAgo;
      final oi24hAgo = oiHist.first.openInterest;

      final k4h = klines4h[symbol];
      final priceChange4h = k4h != null && k4h.length >= 2
          ? ((k4h.last.close - k4h[k4h.length - 2].close) /
                  k4h[k4h.length - 2].close) *
              100
          : 0.0;

      // Strategi 1: Trend Confirm
      final avgVolume7dPlaceholder = ticker.quoteVolume; // TODO: ganti
      // dengan rata-rata volume 7 hari asli dari klines histori lebih
      // panjang - disederhanakan di skeleton ini.
      final trendSignal = _trendConfirm.evaluate(
        symbol: symbol,
        priceChange4hPercent: priceChange4h,
        fundingRate: fundingRate,
        oiNow: oiNow,
        oi4hAgo: oi4hAgo,
        currentVolume24h: ticker.quoteVolume,
        avgVolume7d: avgVolume7dPlaceholder,
      );
      if (trendSignal != null) signals.add(trendSignal);

      // Strategi 2: Squeeze Radar
      final k1h = klines1h[symbol];
      if (k1h != null && k1h.length >= 2) {
        final lastChange = ((k1h.last.close - k1h.last.open) /
                k1h.last.open) *
            100;
        final prevCandle = k1h[k1h.length - 2];
        final prevChange =
            ((prevCandle.close - prevCandle.open) / prevCandle.open) * 100;

        final squeezeSignal = _squeezeRadar.evaluate(
          symbol: symbol,
          fundingRate: fundingRate,
          oiNow: oiNow,
          oi24hAgo: oi24hAgo,
          priceChange1hLastCandlePercent: lastChange,
          priceChange1hPreviousCandlePercent: prevChange,
        );
        if (squeezeSignal != null) signals.add(squeezeSignal);
      }

      // Strategi 3: Low Cap Momentum
      if (k1h != null) {
        final lowCapSignal = _lowCapMomentumFutures.evaluate(
          symbol: symbol,
          klines1h: k1h,
          oiNow: oiNow,
          oi1hAgo: oi1hAgo,
          isTopMarketCap: _isLikelyTopMarketCapPlaceholder(symbol),
        );
        if (lowCapSignal != null) signals.add(lowCapSignal);
      }

      // Strategi 4: Divergence Hunter
      // TODO: previousFundingRatePercent idealnya dari histori funding
      // rate asli (Binance punya /fapi/v1/fundingRate untuk histori),
      // disederhanakan pakai funding rate saat ini sebagai placeholder.
      final divergenceSignal = _divergenceHunter.evaluate(
        symbol: symbol,
        priceChange4hPercent: priceChange4h,
        oiNow: oiNow,
        oi4hAgo: oi4hAgo,
        currentFundingRate: fundingRate,
        previousFundingRatePercent: fundingRate.fundingRatePercent,
      );
      if (divergenceSignal != null) signals.add(divergenceSignal);
    }

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
