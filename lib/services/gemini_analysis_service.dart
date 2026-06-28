import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/strategy_signal.dart';

/// Service untuk memanggil Gemini API (BYOK - pakai API key milik
/// user sendiri, disimpan via SettingsService). Dipakai di
/// AnalyzePage untuk memberi analisis naratif + rekomendasi Do's &
/// Don'ts berdasarkan kumpulan StrategySignal yang sudah dihasilkan
/// ScreeningEngine.
///
/// PENTING: Gemini API dipanggil LANGSUNG dari HP user ke Google
/// (tidak lewat server perantara apapun), konsisten dengan model BYOK
/// yang sudah dipakai Cuanstrat - API key user tidak pernah dikirim
/// ke pihak lain selain Google.
class GeminiAnalysisService {
  // Model "flash" dipilih karena cepat & murah, cocok untuk analisis
  // ringkas seperti ini (bukan reasoning kompleks/multi-step).
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.0-flash:generateContent';

  Future<String> analyzeSignals({
    required String apiKey,
    required String symbol,
    required List<StrategySignal> signals,
  }) async {
    final prompt = _buildPrompt(symbol, signals);

    final uri = Uri.parse('$_baseUrl?key=$apiKey');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [{'text': prompt}],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw GeminiApiException(
        'Gemini API error: HTTP ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    try {
      final candidates = data['candidates'] as List<dynamic>;
      final content = candidates.first['content'] as Map<String, dynamic>;
      final parts = content['parts'] as List<dynamic>;
      return (parts.first['text'] as String).trim();
    } catch (e) {
      throw GeminiApiException(
        'Format response Gemini tidak terduga: $e',
      );
    }
  }

  String _buildPrompt(String symbol, List<StrategySignal> signals) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Kamu adalah asisten analisis trading crypto. Berikut hasil '
      'screening teknikal untuk pair $symbol dari beberapa strategi '
      'berbeda (Spot dan Futures):',
    );
    buffer.writeln();

    if (signals.isEmpty) {
      buffer.writeln(
        'Tidak ada sinyal yang terdeteksi dari strategi manapun saat '
        'ini untuk pair ini.',
      );
    } else {
      for (final s in signals) {
        buffer.writeln(
          '- [${s.strategyName}] ${s.label}: ${s.reasoning}',
        );
      }
    }

    buffer.writeln();
    buffer.writeln(
      'Tulis analisis singkat dalam Bahasa Indonesia (maksimal 150 '
      'kata) yang merangkum kondisi pair ini berdasarkan sinyal di '
      'atas. SETELAH analisis, tambahkan section terpisah berjudul '
      '"REKOMENDASI" dengan format:\n'
      'DO:\n- (poin do 1)\n- (poin do 2)\n'
      'DONT:\n- (poin dont 1)\n- (poin dont 2)\n\n'
      'PENTING: ini BUKAN nasihat finansial, jangan beri kepastian '
      'arah harga, selalu ingatkan risiko. Jangan gunakan markdown '
      'bold/italic, tulis sebagai teks polos saja.',
    );

    return buffer.toString();
  }
}

class GeminiApiException implements Exception {
  final String message;
  GeminiApiException(this.message);

  @override
  String toString() => 'GeminiApiException: $message';
}
