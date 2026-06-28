import 'package:flutter/material.dart';
import 'screening/screening_engine.dart';
import 'models/strategy_signal.dart';

// Entry point minimal supaya project ini BISA di-compile jadi APK
// oleh GitHub Actions. UI di sini SENGAJA dibuat sederhana/placeholder
// - tujuannya cuma untuk validasi bahwa semua kode (models, services,
// strategies, screening engine) bisa di-build tanpa error.
//
// UI sesungguhnya (mode switching Spot/Futures, hasil sinyal per
// strategi, settings, dll - mengikuti gaya Cuanstrat) BELUM dibuat di
// sini, masih perlu didiskusikan & dibangun terpisah.

void main() {
  runApp(const CryptostratApp());
}

// Palet warna tema hijau-hitam, terinspirasi dari estetika trading
// terminal (candlestick hijau = bullish) dan dashboard crypto gelap.
class AppColors {
  static const Color background = Color(0xFF0A0F0D); // hitam kehijauan gelap
  static const Color surface = Color(0xFF131A17); // permukaan card
  static const Color surfaceElevated = Color(0xFF1B2420);
  static const Color primaryGreen = Color(0xFF00E676); // hijau neon/terang
  static const Color secondaryGreen = Color(0xFF1DB954); // hijau lebih kalem
  static const Color textPrimary = Color(0xFFE8F5E9);
  static const Color textSecondary = Color(0xFF8FA89B);
  static const Color warningAmber = Color(0xFFFFB300);
  static const Color dangerRed = Color(0xFFFF5252);
}

class CryptostratApp extends StatelessWidget {
  const CryptostratApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cryptostrat',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          brightness: Brightness.dark,
          primary: AppColors.primaryGreen,
          secondary: AppColors.secondaryGreen,
          surface: AppColors.surface,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: AppColors.primaryGreen.withOpacity(0.12),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textPrimary),
          titleMedium: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      home: const ScreeningTestPage(),
    );
  }
}

/// Halaman test sederhana untuk memverifikasi ScreeningEngine bisa
/// dipanggil dan menampilkan hasil mentah - BUKAN UI final, tapi
/// sudah memakai tema hijau-hitam sebagai dasar gaya visual app.
class ScreeningTestPage extends StatefulWidget {
  const ScreeningTestPage({super.key});

  @override
  State<ScreeningTestPage> createState() => _ScreeningTestPageState();
}

class _ScreeningTestPageState extends State<ScreeningTestPage> {
  final _engine = ScreeningEngine();
  bool _isLoading = false;
  String _statusMessage = 'Tekan tombol untuk mulai screening test.';
  List<StrategySignal> _signals = [];

  Future<void> _runSpotTest() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Menjalankan Spot screening...';
    });
    try {
      final results = await _engine.runSpotScreening();
      setState(() {
        _signals = results;
        _statusMessage = 'Selesai. ${results.length} sinyal ditemukan.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runFuturesTest() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Menjalankan Futures screening...';
    });
    try {
      final results = await _engine.runFuturesScreening();
      setState(() {
        _signals = results;
        _statusMessage = 'Selesai. ${results.length} sinyal ditemukan.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _colorForDirection(SignalDirection direction) {
    switch (direction) {
      case SignalDirection.buy:
        return AppColors.primaryGreen;
      case SignalDirection.sell:
        return AppColors.dangerRed;
      case SignalDirection.warning:
        return AppColors.warningAmber;
      case SignalDirection.watch:
        return AppColors.secondaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CRYPTOSTRAT',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _runSpotTest,
                    child: const Text('TEST SPOT'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                    ),
                    onPressed: _isLoading ? null : _runFuturesTest,
                    child: const Text('TEST FUTURES'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const LinearProgressIndicator(
                color: AppColors.primaryGreen,
                backgroundColor: AppColors.surfaceElevated,
              ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _signals.length,
                itemBuilder: (context, index) {
                  final s = _signals[index];
                  final accentColor = _colorForDirection(s.direction);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                s.symbol,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: accentColor),
                                ),
                                child: Text(
                                  s.label,
                                  style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.strategyName,
                            style: const TextStyle(
                              color: AppColors.secondaryGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.reasoning,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

