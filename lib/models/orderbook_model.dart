/// Model untuk response /api/v3/depth (Spot) atau /fapi/v1/depth
/// (Futures).
///
/// HANYA dipanggil untuk koin yang sudah lolos shortlist - endpoint
/// ini relatif mahal weight-nya dibanding ticker/klines.
class OrderBookModel {
  final String symbol;
  final List<OrderBookLevel> bids; // urutan harga tertinggi -> terendah
  final List<OrderBookLevel> asks; // urutan harga terendah -> tertinggi

  OrderBookModel({
    required this.symbol,
    required this.bids,
    required this.asks,
  });

  factory OrderBookModel.fromJson(String symbol, Map<String, dynamic> json) {
    return OrderBookModel(
      symbol: symbol,
      bids: (json['bids'] as List<dynamic>)
          .map((e) => OrderBookLevel.fromRawArray(e as List<dynamic>))
          .toList(),
      asks: (json['asks'] as List<dynamic>)
          .map((e) => OrderBookLevel.fromRawArray(e as List<dynamic>))
          .toList(),
    );
  }

  /// Total volume bid dalam rentang [priceRangePercent]% dari best bid.
  /// Dipakai untuk deteksi "wall" beli besar di Whale Watch.
  double totalBidVolumeWithinRange(double priceRangePercent) {
    if (bids.isEmpty) return 0;
    final bestBid = bids.first.price;
    final lowerBound = bestBid * (1 - priceRangePercent / 100);
    return bids
        .where((level) => level.price >= lowerBound)
        .fold(0.0, (sum, level) => sum + level.quantity);
  }

  /// Total volume ask dalam rentang [priceRangePercent]% dari best ask.
  double totalAskVolumeWithinRange(double priceRangePercent) {
    if (asks.isEmpty) return 0;
    final bestAsk = asks.first.price;
    final upperBound = bestAsk * (1 + priceRangePercent / 100);
    return asks
        .where((level) => level.price <= upperBound)
        .fold(0.0, (sum, level) => sum + level.quantity);
  }

  /// Rasio bid/ask volume dalam range tertentu. Whale Watch butuh
  /// rasio >= 3.0 untuk dianggap ada wall beli besar.
  double bidAskImbalanceRatio({double priceRangePercent = 1.0}) {
    final askVol = totalAskVolumeWithinRange(priceRangePercent);
    if (askVol == 0) return 0;
    return totalBidVolumeWithinRange(priceRangePercent) / askVol;
  }

  /// Spread antara best bid dan best ask, dalam persen.
  double get spreadPercent {
    if (bids.isEmpty || asks.isEmpty) return 0;
    final bestBid = bids.first.price;
    final bestAsk = asks.first.price;
    if (bestBid == 0) return 0;
    return ((bestAsk - bestBid) / bestBid) * 100;
  }
}

class OrderBookLevel {
  final double price;
  final double quantity;

  OrderBookLevel({required this.price, required this.quantity});

  factory OrderBookLevel.fromRawArray(List<dynamic> raw) {
    return OrderBookLevel(
      price: double.parse(raw[0].toString()),
      quantity: double.parse(raw[1].toString()),
    );
  }
}
