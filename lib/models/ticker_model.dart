/// Model untuk response /api/v3/ticker/24hr (Spot) atau
/// /fapi/v1/ticker/24hr (Futures).
///
/// Endpoint ini bisa dipanggil TANPA parameter `symbol` untuk
/// mengambil data SEMUA trading pairs sekaligus dalam satu request
/// (weight sangat murah dibanding fetch satu-satu).
class TickerModel {
  final String symbol;
  final double lastPrice;
  final double priceChangePercent;
  final double highPrice;
  final double lowPrice;
  final double volume; // volume dalam base asset (misal BTC)
  final double quoteVolume; // volume dalam quote asset (misal USDT)

  TickerModel({
    required this.symbol,
    required this.lastPrice,
    required this.priceChangePercent,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
    required this.quoteVolume,
  });

  factory TickerModel.fromJson(Map<String, dynamic> json) {
    return TickerModel(
      symbol: json['symbol'] as String,
      lastPrice: double.parse(json['lastPrice'].toString()),
      priceChangePercent: double.parse(json['priceChangePercent'].toString()),
      highPrice: double.parse(json['highPrice'].toString()),
      lowPrice: double.parse(json['lowPrice'].toString()),
      volume: double.parse(json['volume'].toString()),
      quoteVolume: double.parse(json['quoteVolume'].toString()),
    );
  }

  /// Range harga 24h dalam persen, dipakai untuk cek kondisi
  /// "sideways ketat" di strategi Accumulation Zone.
  double get high24hLowRangePercent {
    if (lowPrice == 0) return 0;
    return ((highPrice - lowPrice) / lowPrice) * 100;
  }
}
