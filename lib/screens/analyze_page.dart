import 'package:flutter/material.dart';
import '../models/strategy_signal.dart';
import '../models/strategy_parameters.dart';
import '../screening/screening_engine.dart';
import '../services/settings_service.dart';
import '../services/gemini_analysis_service.dart';
import '../theme/app_colors.dart';
import '../widgets/pulse_heartbeat_loader.dart';
import '../widgets/signal_card.dart';
import '../widgets/disclaimer_banner.dart';

/// Halaman Analyze - dipanggil dari salah satu tombol "ANALYZE SPOT"
/// atau "ANALYZE FUTURES" di Landing Page. Menjalankan strategi
/// SESUAI MODE yang dipilih (Spot: 5 strategi, Futures: 4 strategi)
/// untuk SATU pair, menampilkan hasil dalam list scrollable, lalu
/// (jika API key Gemini sudah di-set di Settings) menambahkan
/// analisis AI + rekomendasi Do's & Don'ts di bagian paling akhir.
class AnalyzePage extends StatefulWidget {
  final String symbol;
  final MarketType mode;
  final StrategyParameters params;

  const AnalyzePage({
    super.key,
    required this.symbol,
    required this.mode,
    required this.params,
  });

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
  GeminiAnalysisResult? _geminiResult;
  String? _geminiErrorMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  @override
  void dispose() {
    _geminiService.close();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _stage = _LoadStage.fetchingSignals;
      _errorMessage = null;
    });

    try {
      final results = widget.mode == MarketType.spot
          ? await _engine.analyzeSpotPair(widget.symbol, widget.params)
          : await _engine.analyzeFuturesPair(widget.symbol, widget.params);
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
    final result = await _geminiService.analyze(
      apiKey: apiKey.trim(),
      symbol: widget.symbol,
      signals: _signals,
    );
    // analyze() TIDAK PERNAH throw - mengikuti pola Cuanstrat, semua
    // kegagalan (key tidak valid, network error, rate limit, format
    // tak terduga) sudah ditangani di dalam service dan dikembalikan
    // sebagai null. Hasil strategi tetap ditampilkan walau Gemini
    // gagal; cuma section Gemini-nya berisi pesan singkat.
    setState(() {
      _geminiResult = result;
      _geminiErrorMessage = result == null
          ? 'Analisis AI tidak tersedia saat ini (API key tidak valid, '
              'limit tercapai, atau Gemini sedang bermasalah). Hasil '
              'strategi di atas tetap berlaku.'
          : null;
      _stage = _LoadStage.done;
    });
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.symbol,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.mode == MarketType.spot
                    ? AppColors.primaryGreen.withOpacity(0.15)
                    : AppColors.warningAmber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.mode == MarketType.spot ? 'SPOT' : 'FUTURES',
                style: TextStyle(
                  color: widget.mode == MarketType.spot
                      ? AppColors.primaryGreen
                      : AppColors.warningAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
    final totalStrategies = widget.mode == MarketType.spot ? 5 : 4;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.mode == MarketType.futures) ...[
          DisclaimerBanner.leverage(),
          const SizedBox(height: 14),
        ],
        Text(
          '${_signals.length} sinyal ditemukan dari $totalStrategies strategi '
          '${widget.mode == MarketType.spot ? "Spot" : "Futures"}',
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
        if (_geminiResult != null || _geminiErrorMessage != null) ...[
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
          if (_geminiResult != null)
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _geminiResult!.text,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  if (_geminiResult!.sources.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 8),
                    const Text(
                      'Sumber berita yang dirujuk:',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._geminiResult!.sources.map(
                      (source) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '• $source',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _geminiErrorMessage!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
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
