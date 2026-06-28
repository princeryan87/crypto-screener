/// Model untuk response /fapi/v1/premiumIndex (Futures only).
///
/// Endpoint ini juga bisa dipanggil TANPA parameter `symbol` untuk
/// mengambil funding rate SEMUA pairs sekaligus (weight murah),
/// dipakai di tahap broad filter pada hybrid fetch.
class FundingRateModel {
  final String symbol;
  final double markPrice;
  final double lastFundingRate; // dalam desimal, misal 0.0010 = 0.10%
  final DateTime nextFundingTime;

  FundingRateModel({
    required this.symbol,
    required this.markPrice,
    required this.lastFundingRate,
    required this.nextFundingTime,
  });

  factory FundingRateModel.fromJson(Map<String, dynamic> json) {
    return FundingRateModel(
      symbol: json['symbol'] as String,
      markPrice: double.parse(json['markPrice'].toString()),
      lastFundingRate: double.parse(json['lastFundingRate'].toString()),
      nextFundingTime: DateTime.fromMillisecondsSinceEpoch(
        json['nextFundingTime'] as int,
      ),
    );
  }

  /// Funding rate dalam bentuk persen (misal 0.10 bukan 0.0010),
  /// supaya gampang dibandingkan dengan threshold strategi.
  double get fundingRatePercent => lastFundingRate * 100;

  /// Helper untuk Squeeze Radar: funding sangat ekstrem ke arah long.
  bool isExtremeLongFunding({double threshold = 0.10}) =>
      fundingRatePercent >= threshold;

  /// Helper untuk Squeeze Radar: funding sangat ekstrem ke arah short.
  bool isExtremeShortFunding({double threshold = -0.08}) =>
      fundingRatePercent <= threshold;

  /// Helper untuk Trend Confirm: funding masih dalam rentang wajar,
  /// belum FOMO ekstrem.
  bool isFundingNormalRange({double min = -0.03, double max = 0.05}) =>
      fundingRatePercent >= min && fundingRatePercent <= max;
}
