import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ticker_model.dart';
import '../models/kline_model.dart';
import '../models/funding_rate_model.dart';
import '../models/open_interest_model.dart';
import '../models/orderbook_model.dart';

enum BinanceMarket { spot, futures }

/// Service utama untuk semua komunikasi ke Binance public API.
/// TIDAK butuh API key sama sekali (semua endpoint di sini public).
///
/// Desain mengikuti keputusan "strategi fetch hybrid 2 tahap":
/// - Method dengan suffix "All" / tanpa parameter symbol -> dipanggil
///   SEKALI untuk broad filter (murah, semua pairs sekaligus).
/// - Method dengan parameter symbol tunggal -> dipanggil per-koin,
///   HANYA untuk shortlist hasil broad filter (lebih mahal weight).
class BinanceApiService {
  static const String _spotBaseUrl = 'https://api.binance.com';
  static const String _futuresBaseUrl = 'https://fapi.binance.com';

  String _baseUrl(BinanceMarket market) =>
      market == BinanceMarket.spot ? _spotBaseUrl : _futuresBaseUrl;

  // ---------------------------------------------------------------
  // TAHAP 1: BROAD FILTER (murah, semua pairs sekaligus)
  // ---------------------------------------------------------------

  /// Fetch ticker 24hr untuk SEMUA pairs sekaligus.
  /// Spot: GET /api/v3/ticker/24hr (tanpa symbol)
  /// Futures: GET /fapi/v1/ticker/24hr (tanpa symbol)
  /// Weight murah (~40) untuk ratusan pairs.
  Future<List<TickerModel>> fetchAllTickers(BinanceMarket market) async {
    final path = market == BinanceMarket.spot
        ? '/api/v3/ticker/24hr'
        : '/fapi/v1/ticker/24hr';
    final uri = Uri.parse('${_baseUrl(market)}$path');
    final response = await http.get(uri);
    _checkResponse(response, 'fetchAllTickers');

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => TickerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch funding rate untuk SEMUA pairs futures sekaligus.
  /// GET /fapi/v1/premiumIndex (tanpa symbol). Futures only.
  Future<List<FundingRateModel>> fetchAllFundingRates() async {
    final uri = Uri.parse('$_futuresBaseUrl/fapi/v1/premiumIndex');
    final response = await http.get(uri);
    _checkResponse(response, 'fetchAllFundingRates');

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => FundingRateModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch daftar semua symbol yang tradeable (status TRADING) beserta
  /// filter dasar (tick size, lot size). Dipakai sebagai sumber dynamic
  /// list koin, BUKAN dari CSV manual.
  Future<List<String>> fetchTradableSymbols(BinanceMarket market) async {
    final path = market == BinanceMarket.spot
        ? '/api/v3/exchangeInfo'
        : '/fapi/v1/exchangeInfo';
    final uri = Uri.parse('${_baseUrl(market)}$path');
    final response = await http.get(uri);
    _checkResponse(response, 'fetchTradableSymbols');

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> symbols = data['symbols'] as List<dynamic>;

    return symbols
        .where((s) {
          final symbolMap = s as Map<String, dynamic>;
          final status = symbolMap['status'] as String?;
          // Futures pakai status "TRADING", Spot juga "TRADING"
          final isUsdtPair =
              (symbolMap['quoteAsset'] as String?) == 'USDT';
          return status == 'TRADING' && isUsdtPair;
        })
        .map((s) => (s as Map<String, dynamic>)['symbol'] as String)
        .toList();
  }

  // ---------------------------------------------------------------
  // TAHAP 2: DEEP FILTER (per-symbol, HANYA untuk shortlist)
  // ---------------------------------------------------------------

  /// Fetch candlestick untuk SATU symbol.
  /// [interval] contoh: '15m', '1h', '4h', '1d'.
  /// [limit] default 100, override ke 35 khusus Accumulation Zone
  /// dengan interval '1d'.
  Future<List<KlineModel>> fetchKlines({
    required BinanceMarket market,
    required String symbol,
    required String interval,
    int limit = 100,
  }) async {
    final path =
        market == BinanceMarket.spot ? '/api/v3/klines' : '/fapi/v1/klines';
    final uri = Uri.parse('${_baseUrl(market)}$path').replace(
      queryParameters: {
        'symbol': symbol,
        'interval': interval,
        'limit': limit.toString(),
      },
    );
    final response = await http.get(uri);
    _checkResponse(response, 'fetchKlines($symbol)');

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return parseKlinesResponse(data);
  }

  /// Batch fetch klines untuk BANYAK symbol sekaligus, dengan
  /// concurrency terbatas supaya tidak burst rate limit.
  /// [concurrency] default 5 (5 request paralel per batch).
  Future<Map<String, List<KlineModel>>> batchFetchKlines({
    required BinanceMarket market,
    required List<String> symbols,
    required String interval,
    int limit = 100,
    int concurrency = 5,
    Duration delayBetweenBatches = const Duration(milliseconds: 200),
  }) async {
    final result = <String, List<KlineModel>>{};

    for (int i = 0; i < symbols.length; i += concurrency) {
      final batch = symbols.skip(i).take(concurrency).toList();
      final futures = batch.map((symbol) async {
        try {
          final klines = await fetchKlines(
            market: market,
            symbol: symbol,
            interval: interval,
            limit: limit,
          );
          return MapEntry(symbol, klines);
        } catch (e) {
          // Satu symbol gagal tidak boleh menggagalkan seluruh batch.
          // Symbol ini cukup dilewati dari hasil screening.
          return MapEntry(symbol, <KlineModel>[]);
        }
      });

      final batchResults = await Future.wait(futures);
      for (final entry in batchResults) {
        if (entry.value.isNotEmpty) {
          result[entry.key] = entry.value;
        }
      }

      // Jeda kecil antar batch supaya tidak burst ke rate limit,
      // kecuali ini batch terakhir.
      if (i + concurrency < symbols.length) {
        await Future.delayed(delayBetweenBatches);
      }
    }

    return result;
  }

  /// Fetch order book untuk SATU symbol. HANYA dipanggil untuk koin
  /// yang relevan ke strategi Whale Watch, bukan semua koin.
  /// [limit] valid values Binance: 5,10,20,50,100,500,1000,5000.
  Future<OrderBookModel> fetchOrderBook({
    required BinanceMarket market,
    required String symbol,
    int limit = 100,
  }) async {
    final path =
        market == BinanceMarket.spot ? '/api/v3/depth' : '/fapi/v1/depth';
    final uri = Uri.parse('${_baseUrl(market)}$path').replace(
      queryParameters: {'symbol': symbol, 'limit': limit.toString()},
    );
    final response = await http.get(uri);
    _checkResponse(response, 'fetchOrderBook($symbol)');

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return OrderBookModel.fromJson(symbol, data);
  }

  /// Fetch OI snapshot saat ini untuk SATU symbol. Futures only.
  Future<OpenInterestModel> fetchOpenInterest(String symbol) async {
    final uri = Uri.parse('$_futuresBaseUrl/fapi/v1/openInterest')
        .replace(queryParameters: {'symbol': symbol});
    final response = await http.get(uri);
    _checkResponse(response, 'fetchOpenInterest($symbol)');

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return OpenInterestModel.fromSnapshotJson(data);
  }

  /// Fetch histori OI untuk SATU symbol, dipakai hitung % change OI.
  /// [period] contoh: '5m','15m','1h','4h'. [limit] max 500.
  /// Futures only.
  Future<List<OpenInterestModel>> fetchOpenInterestHistory({
    required String symbol,
    required String period,
    int limit = 30,
  }) async {
    final uri =
        Uri.parse('$_futuresBaseUrl/futures/data/openInterestHist').replace(
      queryParameters: {
        'symbol': symbol,
        'period': period,
        'limit': limit.toString(),
      },
    );
    final response = await http.get(uri);
    _checkResponse(response, 'fetchOpenInterestHistory($symbol)');

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) =>
            OpenInterestModel.fromHistJson(e as Map<String, dynamic>))
        .toList();
  }

  void _checkResponse(http.Response response, String context) {
    if (response.statusCode != 200) {
      throw BinanceApiException(
        'Binance API error di $context: HTTP ${response.statusCode} - '
        '${response.body}',
      );
    }
  }
}

class BinanceApiException implements Exception {
  final String message;
  BinanceApiException(this.message);

  @override
  String toString() => 'BinanceApiException: $message';
}
