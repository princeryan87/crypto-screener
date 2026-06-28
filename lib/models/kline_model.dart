/// Model untuk satu candle dari response /api/v3/klines atau
/// /fapi/v1/klines.
///
/// Format response Binance untuk setiap candle adalah Array, bukan
/// Object, dengan urutan index yang FIXED:
/// [0]=openTime, [1]=open, [2]=high, [3]=low, [4]=close, [5]=volume,
/// [6]=closeTime, [7]=quoteVolume, [8]=numTrades, ...
class KlineModel {
  final DateTime openTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final DateTime closeTime;

  KlineModel({
    required this.openTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.closeTime,
  });

  /// Parsing dari raw array Binance (BUKAN dari Map/JSON object).
  factory KlineModel.fromRawArray(List<dynamic> raw) {
    return KlineModel(
      openTime: DateTime.fromMillisecondsSinceEpoch(raw[0] as int),
      open: double.parse(raw[1].toString()),
      high: double.parse(raw[2].toString()),
      low: double.parse(raw[3].toString()),
      close: double.parse(raw[4].toString()),
      volume: double.parse(raw[5].toString()),
      closeTime: DateTime.fromMillisecondsSinceEpoch(raw[6] as int),
    );
  }

  /// Body candle (jarak open-close), dipakai untuk cek kondisi
  /// breakout di Momentum Breakout (body >= 1.5x ATR).
  double get bodySize => (close - open).abs();

  bool get isGreen => close > open;
  bool get isRed => close < open;
}

/// Helper untuk parsing list mentah hasil decode JSON klines.
List<KlineModel> parseKlinesResponse(List<dynamic> rawList) {
  return rawList
      .map((e) => KlineModel.fromRawArray(e as List<dynamic>))
      .toList();
}
