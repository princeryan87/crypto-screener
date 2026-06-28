/// Model untuk response /fapi/v1/openInterest (snapshot saat ini)
/// dan /futures/data/openInterestHist (histori, untuk hitung % change).
///
/// CATATAN: kedua endpoint ini TIDAK punya mode "semua pairs sekaligus"
/// - harus dipanggil per-symbol. Oleh karena itu hanya dipanggil untuk
/// koin yang sudah lolos shortlist di tahap broad filter.
class OpenInterestModel {
  final String symbol;
  final double openInterest; // dalam jumlah kontrak/coin, bukan USD
  final DateTime timestamp;

  OpenInterestModel({
    required this.symbol,
    required this.openInterest,
    required this.timestamp,
  });

  /// Untuk snapshot real-time dari /fapi/v1/openInterest
  factory OpenInterestModel.fromSnapshotJson(Map<String, dynamic> json) {
    return OpenInterestModel(
      symbol: json['symbol'] as String,
      openInterest: double.parse(json['openInterest'].toString()),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['time'] as int),
    );
  }

  /// Untuk satu entri histori dari /futures/data/openInterestHist
  factory OpenInterestModel.fromHistJson(Map<String, dynamic> json) {
    return OpenInterestModel(
      symbol: json['symbol'] as String,
      openInterest: double.parse(json['sumOpenInterest'].toString()),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] as int,
      ),
    );
  }
}

/// Helper untuk menghitung % perubahan OI antara dua titik waktu.
/// Dipakai oleh strategi 1, 2, 3, 4 di Futures (semua butuh OI change).
double calculateOiChangePercent({
  required double oiNow,
  required double oiBefore,
}) {
  if (oiBefore == 0) return 0;
  return ((oiNow - oiBefore) / oiBefore) * 100;
}
