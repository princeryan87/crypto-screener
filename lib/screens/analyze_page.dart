import 'package:flutter/material.dart';
import '../models/strategy_signal.dart';
import '../screening/screening_engine.dart';
import '../services/settings_service.dart';
import '../services/gemini_analysis_service.dart';
import '../theme/app_colors.dart';
import '../widgets/pulse_heartbeat_loader.dart';
import '../widgets/signal_card.dart';
import '../widgets/disclaimer_banner.dart';

/// Halaman Analyze - dipanggil dari tombol "ANALYZE" di Landing Page.
/// Menjalankan SEMUA strategi (Spot + Futures) untuk SATU pair yang
/// dipilih user, menampilkan hasil dalam list scrollable, lalu (jika
/// API key Gemini sudah di-set di Settings) menambahkan analisis AI +
/// rekomendasi Do's & Don'ts di bagian paling akhir.
class AnalyzePage extends StatefulWidget {
  final String symbol;

  const AnalyzePage({super.key, required this.symbol});

  @override
  State<AnalyzePage> createState() => _AnalyzePageState();
}

enum _LoadStage { fetchingSignals, fetchingGeminiAnalysis, done, error }

class _AnalyzePageState extends State<AnalyzePage> {
  final _engine = ScreeningEngine();
  final _settingsService = SettingsService();
  final _geminiService = GeminiAnalysisService();

  _LoadStage _stage = _LoadStage.fetchingSignals;
  List<StrategySignal> _signals = [];
  String? _geminiAnalysis;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _stage = _LoadStage.fetchingSignals;
      _errorMessage = null;
    });

    try {
      final results = await _engine.analyzeSinglePair(widget.symbol);
      setState(() => _signals = results);
    } catch (e) {
      setState(() {
        _stage = _LoadStage.error;
        _errorMessage = e.toString();
      });
      return;
    }

    // Cek apakah API key Gemini sudah di-set - jika ya, lanjut minta
    // analisis AI. Jika tidak, langsung selesai tanpa section Gemini.
    final apiKey = await _settingsService.getGeminiApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      setState(() => _stage = _LoadStage.done);
      return;
    }

    setState(() => _stage = _LoadStage.fetchingGeminiAnalysis);
    try {
      final analysis = await _geminiService.analyzeSignals(
        apiKey: apiKey.trim(),
        symbol: widget.symbol,
        signals: _signals,
      );
      setState(() {
        _geminiAnalysis = analysis;
        _stage = _LoadStage.done;
      });
    } catch (e) {
      // Gemini gagal BUKAN error fatal - hasil strategi tetap
      // ditampilkan, cuma section Gemini-nya diisi pesan error kecil.
      setState(() {
        _geminiAnalysis = 'Analisis AI gagal dimuat: $e';
        _stage = _LoadStage.done;
      });
    }
  }

  String get _loadingLabel {
    switch (_stage) {
      case _LoadStage.fetchingSignals:
        return 'Mengambil & menganalisis data ${widget.symbol}...';
      case _LoadStage.fetchingGeminiAnalysis:
        return 'Meminta analisis AI dari Gemini...';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _stage == _LoadStage.fetchingSignals ||
        _stage == _LoadStage.fetchingGeminiAnalysis;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.symbol,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: PulseHeartbeatLoader(label: _loadingLabel),
                ),
              )
            : _stage == _LoadStage.error
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.dangerRed,
                            size: 36,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Gagal menganalisis: $_errorMessage',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.dangerRed,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _runAnalysis,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildResultList(),
      ),
    );
  }

  Widget _buildResultList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${_signals.length} sinyal ditemukan dari 9 strategi',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        if (_signals.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'Tidak ada strategi yang match untuk pair ini saat ini. '
              'Kondisi pasar mungkin netral / tidak ada sinyal kuat.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          )
        else
          ..._signals.map((s) => SignalCard(signal: s)),
        if (_geminiAnalysis != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.primaryGreen,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'ANALISIS AI (GEMINI)',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryGreen.withOpacity(0.3),
              ),
            ),
            child: Text(
              _geminiAnalysis!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const DisclaimerBanner(
            message:
                'Analisis di atas dihasilkan AI dan BUKAN nasihat '
                'finansial. Selalu lakukan riset sendiri (DYOR) '
                'sebelum mengambil keputusan trading.',
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
