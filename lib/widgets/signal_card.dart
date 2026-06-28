import 'package:flutter/material.dart';
import '../models/strategy_signal.dart';
import '../theme/app_colors.dart';
import 'disclaimer_banner.dart';

/// Card untuk menampilkan satu StrategySignal. Dipakai di
/// AnalyzePage untuk hasil analisis Spot maupun Futures.
class SignalCard extends StatelessWidget {
  final StrategySignal signal;

  const SignalCard({super.key, required this.signal});

  Color get _accentColor {
    switch (signal.direction) {
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
    final accentColor = _accentColor;

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
                  signal.symbol,
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
                    signal.label,
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
              signal.strategyName,
              style: const TextStyle(
                color: AppColors.secondaryGreen,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              signal.reasoning,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (signal.isHighRisk) ...[
              const SizedBox(height: 10),
              DisclaimerBanner.highRiskVolatility(),
            ],
          ],
        ),
      ),
    );
  }
}
