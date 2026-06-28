/// Model output umum untuk SEMUA strategi (Spot maupun Futures).
/// Setiap strategi mengembalikan StrategySignal? (null jika tidak ada
/// sinyal / kondisi tidak terpenuhi).
enum MarketType { spot, futures }

enum SignalDirection { buy, sell, watch, warning }

class StrategySignal {
  final String symbol;
  final String strategyName;
  final MarketType market;
  final SignalDirection direction;
  final String label; // contoh: "BUY", "ACCUMULATION DETECTED",
  // "WARNING REVERSAL", "WEAK RALLY", "WATCH"
  final String reasoning; // ringkasan kondisi yang terpenuhi, untuk
  // ditampilkan ke user
  final Map<String, double> indicatorValues; // nilai mentah indikator,
  // untuk debugging & ditampilkan detail ke user
  final bool isHighRisk; // true untuk strategi yang butuh disclaimer
  // tegas (Low Cap Hunter, Low Cap Momentum Futures)
  final DateTime generatedAt;

  StrategySignal({
    required this.symbol,
    required this.strategyName,
    required this.market,
    required this.direction,
    required this.label,
    required this.reasoning,
    required this.indicatorValues,
    this.isHighRisk = false,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  @override
  String toString() =>
      '[$strategyName] $symbol -> $label ($reasoning)';
}
