import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk simpan & ambil API key Gemini (BYOK) secara lokal
/// di HP, persist antar sesi app (berbeda dengan CacheService yang
/// hilang saat app ditutup).
///
/// CATATAN KEAMANAN: SharedPreferences menyimpan data TIDAK
/// terenkripsi di storage app. Untuk API key Gemini (BYOK, risiko
/// rendah - bukan secret key exchange dengan akses dana) ini cukup
/// memadai, sama dengan pola yang kemungkinan dipakai Cuanstrat untuk
/// field Gemini API Key-nya. JANGAN pakai pola ini untuk Binance
/// Secret Key di fase mendatang (auto-trade) - itu wajib pakai
/// flutter_secure_storage karena risikonya jauh lebih tinggi (akses
/// dana langsung).
class SettingsService {
  static const String _geminiApiKeyKey = 'gemini_api_key';

  Future<String?> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_geminiApiKeyKey);
  }

  Future<void> setGeminiApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_geminiApiKeyKey, apiKey);
  }

  Future<void> clearGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_geminiApiKeyKey);
  }
}
