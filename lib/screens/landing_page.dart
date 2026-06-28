import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/animated_candlestick_background.dart';
import '../widgets/cryptostrat_logo.dart';
import '../screening/screening_engine.dart';
import '../services/binance_api_service.dart';
import '../models/strategy_signal.dart';
import 'analyze_page.dart';
import 'settings_page.dart';

/// Landing page - satu-satunya halaman utama app (mode screening
/// massal Spot/Futures sudah DIHAPUS, lihat catatan di
/// ScreeningEngine). User mengetik sendiri base+quote asset pair yang
/// mau dianalisis, lalu pilih mode lewat salah satu dari 2 tombol
/// Analyze terpisah (Spot / Futures) - validasi pair dilakukan SAAT
/// tombol ditekan, bukan saat mengetik.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _baseController = TextEditingController(text: 'BTC');
  final _quoteController = TextEditingController(text: 'USDT');
  final _engine = ScreeningEngine();

  bool _isValidating = false;
  String? _validationError;

  @override
  void dispose() {
    _baseController.dispose();
    _quoteController.dispose();
    super.dispose();
  }

  String get _composedSymbol =>
      '${_baseController.text.trim().toUpperCase()}'
      '${_quoteController.text.trim().toUpperCase()}';

  Future<void> _onAnalyzePressed(BuildContext context, MarketType mode) async {
    final base = _baseController.text.trim();
    final quote = _quoteController.text.trim();

    if (base.isEmpty || quote.isEmpty) {
      setState(() {
        _validationError = 'Isi dulu kedua kolom pair (contoh: BTC & USDT).';
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _validationError = null;
    });

    final symbol = _composedSymbol;
    final binanceMarket =
        mode == MarketType.spot ? BinanceMarket.spot : BinanceMarket.futures;

    try {
      final exists = await _engine.validatePairExists(
        symbol: symbol,
        market: binanceMarket,
      );

      if (!mounted) return;

      if (!exists) {
        setState(() {
          _isValidating = false;
          _validationError =
              'Pair $symbol tidak ditemukan di Binance '
              '${mode == MarketType.spot ? "Spot" : "Futures"}. '
              'Cek lagi penulisan base/quote asset-nya.';
        });
        return;
      }

      setState(() => _isValidating = false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AnalyzePage(symbol: symbol, mode: mode),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _validationError = 'Gagal memeriksa pair: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Animasi candlestick bergerak sebagai background, samar
          // supaya tidak mengganggu keterbacaan teks/input di atasnya
          const Positioned.fill(
            child: AnimatedCandlestickBackground(opacity: 0.28),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withOpacity(0.4),
                    AppColors.background.withOpacity(0.85),
                    AppColors.background,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          border: Border.all(
                            color: AppColors.primaryGreen.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const CryptostratLogo(size: 40),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'CRYPTOSTRAT',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Crypto Analyzer untuk Binance\nSpot & Futures',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                  _PairInputSection(
                    baseController: _baseController,
                    quoteController: _quoteController,
                    isValidating: _isValidating,
                    validationError: _validationError,
                    onAnalyzeSpot: () =>
                        _onAnalyzePressed(context, MarketType.spot),
                    onAnalyzeFutures: () =>
                        _onAnalyzePressed(context, MarketType.futures),
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PairInputSection extends StatelessWidget {
  final TextEditingController baseController;
  final TextEditingController quoteController;
  final bool isValidating;
  final String? validationError;
  final VoidCallback onAnalyzeSpot;
  final VoidCallback onAnalyzeFutures;

  const _PairInputSection({
    required this.baseController,
    required this.quoteController,
    required this.isValidating,
    required this.validationError,
    required this.onAnalyzeSpot,
    required this.onAnalyzeFutures,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.primaryGreen, size: 16),
              SizedBox(width: 6),
              Text(
                'MASUKKAN PAIR',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PairTextField(
                  controller: baseController,
                  hint: 'BTC',
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '/',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _PairTextField(
                  controller: quoteController,
                  hint: 'USDT',
                ),
              ),
            ],
          ),
          if (validationError != null) ...[
            const SizedBox(height: 10),
            Text(
              validationError!,
              style: const TextStyle(
                color: AppColors.dangerRed,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isValidating ? null : onAnalyzeSpot,
                  child: isValidating
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('ANALYZE SPOT'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceElevated,
                    foregroundColor: AppColors.warningAmber,
                    side: const BorderSide(color: AppColors.warningAmber),
                  ),
                  onPressed: isValidating ? null : onAnalyzeFutures,
                  child: isValidating
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.warningAmber,
                          ),
                        )
                      : const Text('ANALYZE FUTURES'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PairTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _PairTextField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
