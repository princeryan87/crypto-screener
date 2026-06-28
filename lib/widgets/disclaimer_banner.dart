import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Banner disclaimer reusable. Dipakai untuk:
/// 1. Warning leverage di halaman Futures (selalu tampil, bisa
///    di-collapse tapi tidak bisa dihilangkan permanen - aspek
///    keselamatan finansial, bukan sekadar UX preference)
/// 2. Warning high-risk di sinyal Low Cap Hunter (Spot) & Low Cap
///    Momentum (Futures) - tampil di setiap card sinyal yang
///    isHighRisk == true
class DisclaimerBanner extends StatelessWidget {
  final String message;
  final DisclaimerSeverity severity;

  const DisclaimerBanner({
    super.key,
    required this.message,
    this.severity = DisclaimerSeverity.warning,
  });

  /// Disclaimer leverage untuk Futures - redaksi tegas sesuai
  /// keputusan project (disclaimer leverage wajib, bukan opsional).
  factory DisclaimerBanner.leverage() {
    return const DisclaimerBanner(
      message:
          'Trading Futures menggunakan LEVERAGE. Kerugian bisa melebihi '
          'modal awal kamu dan posisi bisa terlikuidasi secara otomatis. '
          'Sinyal di halaman ini BUKAN rekomendasi finansial - selalu '
          'lakukan riset sendiri (DYOR) dan gunakan position sizing yang '
          'wajar.',
      severity: DisclaimerSeverity.danger,
    );
  }

  /// Disclaimer untuk sinyal high-risk (Low Cap Hunter / Low Cap
  /// Momentum) - volatilitas ekstrem, bukan leverage.
  factory DisclaimerBanner.highRiskVolatility() {
    return const DisclaimerBanner(
      message:
          'Aset volatilitas tinggi - harga bisa berubah drastis dalam '
          'waktu sangat singkat. Risiko kerugian besar, termasuk modal '
          'habis dalam hitungan menit.',
      severity: DisclaimerSeverity.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = severity == DisclaimerSeverity.danger
        ? AppColors.dangerRed
        : AppColors.warningAmber;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum DisclaimerSeverity { warning, danger }
