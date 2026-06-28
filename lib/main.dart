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

class CryptostratApp extends StatelessWidget {
  const CryptostratApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cryptostrat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ScreeningTestPage(),
    );
  }
}

/// Halaman test sederhana untuk memverifikasi ScreeningEngine bisa
/// dipanggil dan menampilkan hasil mentah - BUKAN UI final.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cryptostrat - Test Build')),
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
                    child: const Text('Test Spot'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _runFuturesTest,
                    child: const Text('Test Futures'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading) const LinearProgressIndicator(),
            Text(_statusMessage),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _signals.length,
                itemBuilder: (context, index) {
                  final s = _signals[index];
                  return Card(
                    child: ListTile(
                      title: Text('${s.symbol} - ${s.label}'),
                      subtitle: Text(
                        '${s.strategyName}\n${s.reasoning}',
                      ),
                      isThreeLine: true,
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
