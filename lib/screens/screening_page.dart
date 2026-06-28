import 'package:flutter/material.dart';
import '../models/strategy_signal.dart';
import '../screening/screening_engine.dart';
import '../theme/app_colors.dart';
import '../widgets/signal_card.dart';
import '../widgets/disclaimer_banner.dart';
import 'settings_page.dart';

/// Halaman utama setelah user pilih mode dari LandingPage. Berisi 2
/// tab via BottomNavigationBar: Screening (daftar sinyal) & Settings.
class ScreeningPage extends StatefulWidget {
  final MarketType market;

  const ScreeningPage({super.key, required this.market});

  @override
  State<ScreeningPage> createState() => _ScreeningPageState();
}

class _ScreeningPageState extends State<ScreeningPage> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _ScreeningTab(market: widget.market),
      const SettingsPage(),
    ];

    return Scaffold(
      body: pages[_selectedTabIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) => setState(() => _selectedTabIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.candlestick_chart_outlined),
            activeIcon: Icon(Icons.candlestick_chart),
            label: 'Screening',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Tab Screening - isi utama: daftar sinyal hasil scan, pull-to-
/// refresh, dan disclaimer leverage khusus mode Futures.
class _ScreeningTab extends StatefulWidget {
  final MarketType market;

  const _ScreeningTab({required this.market});

  @override
  State<_ScreeningTab> createState() => _ScreeningTabState();
}

class _ScreeningTabState extends State<_ScreeningTab> {
  final _engine = ScreeningEngine();
  bool _isLoading = false;
  String? _errorMessage;
  List<StrategySignal> _signals = [];
  bool _hasRunOnce = false;

  bool get _isFutures => widget.market == MarketType.futures;

  @override
  void initState() {
    super.initState();
    _runScreening();
  }

  Future<void> _runScreening() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = _isFutures
          ? await _engine.runFuturesScreening()
          : await _engine.runSpotScreening();
      setState(() {
        _signals = results;
        _hasRunOnce = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              _isFutures ? 'FUTURES' : 'SPOT',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_signals.length} sinyal',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _runScreening,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: () => Navigator.of(context).popUntil(
              (route) => route.isFirst,
            ),
            tooltip: 'Ganti Mode',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        backgroundColor: AppColors.surface,
        onRefresh: _runScreening,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isFutures) ...[
                DisclaimerBanner.leverage(),
                const SizedBox(height: 14),
              ],
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(
                    color: AppColors.primaryGreen,
                    backgroundColor: AppColors.surfaceElevated,
                  ),
                ),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.dangerRed.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    'Gagal mengambil data: $_errorMessage',
                    style: const TextStyle(
                      color: AppColors.dangerRed,
                      fontSize: 12,
                    ),
                  ),
                ),
              Expanded(
                child: !_hasRunOnce && _isLoading
                    ? const Center(
                        child: Text(
                          'Memindai pasar...',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : _signals.isEmpty
                        ? Center(
                            child: Text(
                              _hasRunOnce
                                  ? 'Tidak ada sinyal saat ini.\nTarik ke '
                                      'bawah untuk refresh.'
                                  : 'Tarik ke bawah untuk mulai screening.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _signals.length,
                            itemBuilder: (context, index) =>
                                SignalCard(signal: _signals[index]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
