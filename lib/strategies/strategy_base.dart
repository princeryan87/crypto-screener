import '../models/strategy_signal.dart';

/// Kontrak dasar yang harus diimplementasikan setiap strategi.
/// Setiap strategi punya kebutuhan data yang berbeda (sebagian butuh
/// klines saja, sebagian butuh order book / funding / OI juga) -
/// jadi method `evaluate` masing-masing strategi punya signature
/// parameter sendiri-sendiri (tidak dipaksa satu interface generik
/// yang kaku), tapi semua WAJIB:
/// 1. Punya constant `strategyName` yang konsisten dipakai di UI
/// 2. Return StrategySignal? (nullable - null = tidak ada sinyal)
/// 3. Tidak melakukan fetch API sendiri - data harus sudah disuplai
///    dari ScreeningEngine (separation of concerns: strategi murni
///    logic, fetching terpusat di satu tempat untuk kontrol rate
///    limit & caching).
abstract class StrategyName {
  // Spot
  static const String momentumBreakout = 'Momentum Breakout';
  static const String whaleWatch = 'Whale Watch';
  static const String lowCapHunter = 'Low Cap Hunter';
  static const String volumeSurge = 'Volume Surge';
  static const String accumulationZone = 'Accumulation Zone';

  // Futures
  static const String trendConfirm = 'Trend Confirm';
  static const String squeezeRadar = 'Long/Short Squeeze Radar';
  static const String lowCapMomentumFutures = 'Low Cap Momentum';
  static const String divergenceHunter = 'Divergence Hunter';
}
