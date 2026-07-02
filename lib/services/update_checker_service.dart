import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Service untuk cek update versi terbaru, baca dari version.json di
/// public release repo GitHub (mengikuti pola Cuanstrat).
///
/// CATATAN INTEGRASI: file ini BELUM otomatis terhubung ke
/// LandingPage atau halaman manapun di app - perlu dipanggil manual
/// (misal di initState LandingPage) kalau update checker mau aktif.
/// Lihat contoh pemanggilan di komentar bawah class.
///
/// PENTING: ganti USERNAME di [_versionJsonUrl] dengan username
/// GitHub kamu setelah public repo dibuat.
class UpdateCheckerService {
  static const String _versionJsonUrl =
      'https://raw.githubusercontent.com/princeryan87/cryptostrat/main/version.json';

  /// Cek apakah ada versi baru yang tersedia. Return null kalau gagal
  /// fetch (network error, dll) - JANGAN ganggu pengalaman user kalau
  /// update checker gagal, app tetap harus jalan normal.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(_versionJsonUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      final latestVersionCode = json['latest_version_code'] as int;
      final isUpdateAvailable = latestVersionCode > currentVersionCode;

      final minSupportedCode = json['min_supported_version_code'] as int? ?? 0;
      final isForceUpdate = currentVersionCode < minSupportedCode ||
          (json['force_update'] as bool? ?? false);

      if (!isUpdateAvailable) return null;

      return UpdateInfo(
        latestVersion: json['latest_version'] as String,
        releaseNotes: json['release_notes'] as String? ?? '',
        downloadUrl: json['download_url'] as String,
        isForceUpdate: isForceUpdate,
      );
    } catch (_) {
      return null;
    }
  }
}

class UpdateInfo {
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;
  final bool isForceUpdate;

  UpdateInfo({
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.isForceUpdate,
  });
}

// Contoh integrasi di LandingPage (BELUM diterapkan otomatis):
//
// @override
// void initState() {
//   super.initState();
//   _checkForUpdate();
// }
//
// Future<void> _checkForUpdate() async {
//   final updateInfo = await UpdateCheckerService().checkForUpdate();
//   if (updateInfo != null && mounted) {
//     // Tampilkan dialog update di sini, mirip showDonationDialog
//   }
// }
