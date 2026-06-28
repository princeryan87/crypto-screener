import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Dialog donasi QRIS, ditampilkan saat user menekan tombol back di
/// LandingPage (halaman root) - kesempatan terakhir untuk minta
/// dukungan sebelum app benar-benar ditutup. Mengikuti pola yang
/// sudah dipakai di Cuanstrat (popup donasi QRIS).
///
/// Return value: true jika user pilih "Keluar App" (app harus
/// ditutup), false/null jika user batal (tetap di app).
Future<bool?> showDonationDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite_rounded,
              color: AppColors.primaryGreen,
              size: 32,
            ),
            const SizedBox(height: 10),
            const Text(
              'Dukung Cryptostrat',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Aplikasi ini gratis & terus dikembangkan. Kalau '
              'bermanfaat, donasi seikhlasnya lewat QRIS di bawah ini '
              'sangat membantu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryGreen.withOpacity(0.3),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/qris.png',
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'SATU QRIS UNTUK SEMUA',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Nanti Saja'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Keluar App'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
