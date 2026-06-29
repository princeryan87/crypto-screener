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
/// (tidak lewat server perantara apapun). API key user tidak pernah
/// dikirim ke pihak lain selain Google.
///
/// Pola implementasi (cara kirim API key, timeout, fallback null
/// daripada throw, Google Search grounding) DISELARASKAN dengan
/// gemini_analyst.dart di Cuanstrat supaya konsisten dan sama-sama
/// tangguh terhadap kegagalan API - lihat README untuk detail
/// perbandingan.
class GeminiAnalysisResult {
  final String text;
  final List<String> sources; // judul sumber berita yang dipakai Gemini

  const GeminiAnalysisResult({required this.text, required this.sources});
}

class GeminiAnalysisService {
  final http.Client _client;

  // Gemini 2.5 Flash: cepat & murah, mendukung google_search
  // grounding. CATATAN: gemini-2.0-flash SUDAH DEPRECATED & DIHENTIKAN
  // dari free tier Google per awal Juni 2026 - JANGAN dikembalikan ke
  // model itu. Kalau gemini-2.5-flash di masa depan juga di-deprecate,
  // cek model terbaru yang masih free tier di
  // https://ai.google.dev/gemini-api/docs/pricing dan ganti nilai
  // konstanta ini saja (tidak ada bagian lain yang perlu diubah).
  static const String model = 'gemini-2.5-flash';

  GeminiAnalysisService({http.Client? client})
      : _client = client ?? http.Client();

  /// Kirim ringkasan sinyal screening ke Gemini dengan Google Search
  /// grounding aktif, supaya analisis mempertimbangkan berita/sentimen
  /// TERBARU di luar data teknikal murni - sangat relevan untuk
  /// crypto, di mana sentimen pasar/berita sering jadi penggerak harga
  /// yang lebih besar daripada sinyal teknikal semata.
  ///
  /// Mengikuti pola Cuanstrat: return null pada SEMUA jenis kegagalan
  /// (key tidak valid, network error, rate limit, format tak terduga)
  /// supaya caller (AnalyzePage) bisa fallback dengan baik ke hasil
  /// strategi math-only, TANPA menampilkan JSON error mentah ke user.
  Future<GeminiAnalysisResult?> analyze({
    required String apiKey,
    required String symbol,
    required List<StrategySignal> signals,
  }) async {
    if (apiKey.trim().isEmpty) return null;

    final prompt = _buildPrompt(symbol, signals);
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$model:generateContent',
    );

    try {
      final resp = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey.trim(),
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [{'text': prompt}],
                },
              ],
              'tools': [
                {'google_search': {}},
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) return null;

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;

      final candidate = candidates[0] as Map<String, dynamic>;
      final content = candidate['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return null;

      final text = parts
          .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
          .join('\n')
          .trim();
      if (text.isEmpty) return null;

      final sources = <String>[];
      final groundingMetadata =
          candidate['groundingMetadata'] as Map<String, dynamic>?;
      final chunks = groundingMetadata?['groundingChunks'] as List<dynamic>?;
      if (chunks != null) {
        for (final c in chunks) {
          final web =
              (c as Map<String, dynamic>)['web'] as Map<String, dynamic>?;
          final title = web?['title'] as String?;
          if (title != null && title.isNotEmpty) sources.add(title);
        }
      }

      return GeminiAnalysisResult(text: text, sources: sources);
    } catch (_) {
      return null;
    }
  }

  String _buildPrompt(String symbol, List<StrategySignal> signals) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Saya melakukan screening teknikal otomatis untuk pair crypto '
      'berikut di Binance. Data di bawah sudah dihitung secara '
      'matematis dari indikator teknikal (JANGAN dihitung ulang):',
    );
    buffer.writeln();
    buffer.writeln('Pair: $symbol');
    buffer.writeln();

    if (signals.isEmpty) {
      buffer.writeln(
        'Tidak ada sinyal yang terdeteksi dari strategi manapun saat '
        'ini untuk pair ini.',
      );
    } else {
      buffer.writeln('Hasil strategi screening teknikal:');
      for (final s in signals) {
        buffer.writeln('- [${s.strategyName}] ${s.label}: ${s.reasoning}');
      }
    }

    buffer.writeln();
    buffer.writeln('''
Tugas Anda:
1. Cari berita atau sentimen TERBARU (beberapa hari terakhir) terkait
   pair $symbol atau aset dasarnya, termasuk berita proyek, sektor
   crypto terkait, atau kondisi makro yang relevan.
2. Pertimbangkan hasil teknikal di atas BERSAMA dengan berita/sentimen
   yang Anda temukan.
3. Tulis analisis singkat dalam Bahasa Indonesia (maksimal 150 kata)
   yang merangkum kondisi pair ini berdasarkan gabungan sinyal
   teknikal dan berita/sentimen tersebut.
4. SETELAH analisis, tambahkan section terpisah berjudul
   "REKOMENDASI" dengan format:
DO:
- (poin do 1)
- (poin do 2)
DONT:
- (poin dont 1)
- (poin dont 2)

PENTING: ini BUKAN nasihat finansial, jangan beri kepastian arah
harga, selalu ingatkan risiko (termasuk risiko leverage jika relevan).
Selalu akhiri dengan kalimat: "Ini bukan nasihat keuangan, lakukan
riset sendiri." Jangan gunakan markdown bold/italic, tulis sebagai
teks polos saja, tanpa basa-basi pembuka.
''');

    return buffer.toString();
  }

  void close() => _client.close();
}
