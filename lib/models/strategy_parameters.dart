/// Model untuk semua parameter strategi yang bisa di-tune oleh user.
/// Nilai default adalah parameter yang sudah dioptimasi dan dipakai
/// sebagai baseline — user bisa ubah tapi selalu bisa reset ke sini.
///
/// SPOT - 5 parameter yang paling berpengaruh:
/// 1. Momentum Breakout - RSI range (batas bawah & atas)
/// 2. Momentum Breakout - Volume multiplier vs rata-rata 7 hari
/// 3. Whale Watch - Minimum bid/ask imbalance ratio
/// 4. Volume Surge - Volume multiplier vs rata-rata 7 hari
/// 5. Accumulation Zone - Maksimum sideways range (%)
///
/// FUTURES - 5 parameter yang paling berpengaruh:
/// 1. Trend Confirm - Minimum price change 4h (%)
/// 2. Trend Confirm - Minimum OI change 4h (%)
/// 3. Squeeze Radar - Funding rate ekstrem long threshold (%)
/// 4. Squeeze Radar - Funding rate ekstrem short threshold (%)
/// 5. Low Cap Momentum - Minimum price change 1h (%)

class StrategyParameters {
  // ---------------------------------------------------------------
  // SPOT PARAMETERS
  // ---------------------------------------------------------------

  /// [Momentum Breakout] RSI lower bound - momentum dianggap valid
  /// kalau RSI di ATAS nilai ini. Default 55.
  /// Range yang disarankan: 45 - 65.
  final double spotRsiLower;

  /// [Momentum Breakout] RSI upper bound - momentum dianggap belum
  /// jenuh beli kalau RSI di BAWAH nilai ini. Default 75.
  /// Range yang disarankan: 65 - 85.
  final double spotRsiUpper;

  /// [Momentum Breakout & Volume Surge] Volume multiplier vs rata-rata
  /// 7 hari. Default 2.0 (harus 2x rata-rata). Nilai lebih tinggi =
  /// lebih selektif.
  /// Range yang disarankan: 1.5 - 5.0.
  final double spotVolumeMultiplier;

  /// [Whale Watch] Minimum bid/ask imbalance ratio. Default 3.0 (bid
  /// harus 3x ask dalam 1% range). Nilai lebih tinggi = lebih selektif.
  /// Range yang disarankan: 2.0 - 6.0.
  final double spotWhaleBidAskRatio;

  /// [Accumulation Zone] Maksimum range harga sideways dalam 6 jam
  /// terakhir (%). Default 4.0%. Nilai lebih kecil = kondisi sideways
  /// lebih ketat.
  /// Range yang disarankan: 2.0 - 8.0.
  final double spotSidewaysMaxRangePercent;

  // ---------------------------------------------------------------
  // FUTURES PARAMETERS
  // ---------------------------------------------------------------

  /// [Trend Confirm] Minimum price change dalam 4 jam (%). Default
  /// 3.0%. Nilai lebih tinggi = hanya tangkap tren yang lebih kuat.
  /// Range yang disarankan: 1.5 - 6.0.
  final double futuresPriceChange4h;

  /// [Trend Confirm] Minimum OI change dalam 4 jam (%). Default 5.0%.
  /// Konfirmasi bahwa ada uang baru masuk (bukan short covering).
  /// Range yang disarankan: 3.0 - 10.0.
  final double futuresOiChange4h;

  /// [Squeeze Radar] Funding rate ekstrem ke arah LONG (%). Default
  /// 0.10%. Di atas nilai ini = rawan long squeeze.
  /// Range yang disarankan: 0.05 - 0.20.
  final double futuresFundingExtremeLong;

  /// [Squeeze Radar] Funding rate ekstrem ke arah SHORT (%, nilai
  /// negatif). Default -0.08%. Di bawah nilai ini = rawan short
  /// squeeze.
  /// Range yang disarankan: -0.03 - -0.15 (tulis tanpa minus di UI).
  final double futuresFundingExtremeShort;

  /// [Low Cap Momentum] Minimum price change dalam 1 jam (%). Default
  /// 8.0%. Untuk altcoin kecil Futures yang bergerak agresif.
  /// Range yang disarankan: 5.0 - 15.0.
  final double futuresLowCapPriceChange1h;

  const StrategyParameters({
    // Spot defaults
    this.spotRsiLower = 55,
    this.spotRsiUpper = 75,
    this.spotVolumeMultiplier = 2.0,
    this.spotWhaleBidAskRatio = 3.0,
    this.spotSidewaysMaxRangePercent = 4.0,
    // Futures defaults
    this.futuresPriceChange4h = 3.0,
    this.futuresOiChange4h = 5.0,
    this.futuresFundingExtremeLong = 0.10,
    this.futuresFundingExtremeShort = -0.08,
    this.futuresLowCapPriceChange1h = 8.0,
  });

  /// Nilai default — dipakai tombol "Default" di halaman parameter.
  static const StrategyParameters defaults = StrategyParameters();

  /// Buat salinan dengan nilai tertentu yang diubah.
  StrategyParameters copyWith({
    double? spotRsiLower,
    double? spotRsiUpper,
    double? spotVolumeMultiplier,
    double? spotWhaleBidAskRatio,
    double? spotSidewaysMaxRangePercent,
    double? futuresPriceChange4h,
    double? futuresOiChange4h,
    double? futuresFundingExtremeLong,
    double? futuresFundingExtremeShort,
    double? futuresLowCapPriceChange1h,
  }) {
    return StrategyParameters(
      spotRsiLower: spotRsiLower ?? this.spotRsiLower,
      spotRsiUpper: spotRsiUpper ?? this.spotRsiUpper,
      spotVolumeMultiplier: spotVolumeMultiplier ?? this.spotVolumeMultiplier,
      spotWhaleBidAskRatio: spotWhaleBidAskRatio ?? this.spotWhaleBidAskRatio,
      spotSidewaysMaxRangePercent:
          spotSidewaysMaxRangePercent ?? this.spotSidewaysMaxRangePercent,
      futuresPriceChange4h: futuresPriceChange4h ?? this.futuresPriceChange4h,
      futuresOiChange4h: futuresOiChange4h ?? this.futuresOiChange4h,
      futuresFundingExtremeLong:
          futuresFundingExtremeLong ?? this.futuresFundingExtremeLong,
      futuresFundingExtremeShort:
          futuresFundingExtremeShort ?? this.futuresFundingExtremeShort,
      futuresLowCapPriceChange1h:
          futuresLowCapPriceChange1h ?? this.futuresLowCapPriceChange1h,
    );
  }
}
