/// Cache sederhana in-memory dengan TTL (Time To Live).
///
/// Tujuan: hindari fetch ulang ke Binance saat user refresh screening
/// berkali-kali dalam waktu singkat. Bukan persistent cache (hilang
/// saat app ditutup) - cukup untuk fase 1, karena data screening
/// crypto memang cepat basi (beda dengan data saham yang cuma update
/// per sesi).
///
/// TTL disarankan PER JENIS DATA (lebih pendek untuk data yang lebih
/// cepat berubah):
/// - Ticker 24hr / funding rate (broad filter): 30-60 detik
/// - Klines (deep filter): 1-3 menit, tergantung timeframe yang
///   dipakai (semakin besar timeframe, semakin lama valid)
/// - Order book: 15-30 detik saja (paling cepat basi)
/// - Daftar tradable symbols (exchangeInfo): 1 jam (jarang berubah)
class CacheService {
  final Map<String, _CacheEntry> _store = {};

  /// Ambil dari cache jika masih valid, kalau tidak panggil [fetcher]
  /// dan simpan hasilnya dengan [ttl] baru.
  Future<T> getOrFetch<T>({
    required String key,
    required Duration ttl,
    required Future<T> Function() fetcher,
  }) async {
    final cached = _store[key];
    if (cached != null && !cached.isExpired) {
      return cached.value as T;
    }

    final fresh = await fetcher();
    _store[key] = _CacheEntry(value: fresh, expiresAt: DateTime.now().add(ttl));
    return fresh;
  }

  /// Hapus satu entry tertentu, misal saat user pull-to-refresh manual
  /// dan ingin memaksa fetch ulang walau TTL belum habis.
  void invalidate(String key) => _store.remove(key);

  /// Hapus semua cache.
  void clear() => _store.clear();
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;

  _CacheEntry({required this.value, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Konstanta TTL yang disarankan, dipakai konsisten di seluruh app.
class CacheTtl {
  static const Duration tickerBroadFilter = Duration(seconds: 45);
  static const Duration fundingRate = Duration(seconds: 45);
  static const Duration klinesShortTimeframe = Duration(minutes: 2);
  static const Duration klinesDailyTimeframe = Duration(minutes: 30);
  static const Duration orderBook = Duration(seconds: 20);
  static const Duration tradableSymbols = Duration(hours: 1);
}
