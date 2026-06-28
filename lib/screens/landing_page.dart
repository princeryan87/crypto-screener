import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/animated_candlestick_background.dart';
import 'screening_page.dart';
import '../screening/screening_engine.dart';

/// Landing/splash page - pintu masuk pertama app. User pilih mode
/// SPOT atau FUTURES sebelum masuk ke halaman screening.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _navigateToMode(BuildContext context, MarketType market) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScreeningPage(market: market),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Animasi candlestick bergerak sebagai background, samar
          // supaya tidak mengganggu keterbacaan teks/tombol di atasnya
          const Positioned.fill(
            child: AnimatedCandlestickBackground(opacity: 0.28),
          ),
          // Gradient overlay supaya bagian atas (logo) dan bawah
          // (tombol) tetap kontras tinggi terhadap background animasi
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
                        child: const Icon(
                          Icons.candlestick_chart_rounded,
                          color: AppColors.primaryGreen,
                          size: 40,
                        ),
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
                        'Crypto Screener untuk Binance\nSpot & Futures',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 3),
                  const Text(
                    'PILIH MODE',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ModeCard(
                    title: 'SPOT',
                    subtitle: '5 strategi - Momentum, Whale Watch, dll',
                    icon: Icons.trending_up_rounded,
                    accentColor: AppColors.primaryGreen,
                    onTap: () => _navigateToMode(context, MarketType.spot),
                  ),
                  const SizedBox(height: 14),
                  _ModeCard(
                    title: 'FUTURES',
                    subtitle: '4 strategi - Funding Rate, Open Interest',
                    icon: Icons.bolt_rounded,
                    accentColor: AppColors.warningAmber,
                    onTap: () => _navigateToMode(context, MarketType.futures),
                    badge: 'LEVERAGE',
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final String? badge;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warningAmber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: AppColors.warningAmber,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: accentColor.withOpacity(0.6),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
