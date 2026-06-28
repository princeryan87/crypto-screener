import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/settings_service.dart';

/// Halaman Settings - BYOK (Bring Your Own Key) untuk Gemini API,
/// dipakai fitur AI analysis (mengikuti pola Cuanstrat). Disimpan
/// lokal di HP via SharedPreferences.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settingsService = SettingsService();
  final _apiKeyController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureApiKey = true;
  String? _savedMessage;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final apiKey = await _settingsService.getGeminiApiKey();
    setState(() {
      _apiKeyController.text = apiKey ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveApiKey() async {
    setState(() {
      _isSaving = true;
      _savedMessage = null;
    });
    await _settingsService.setGeminiApiKey(_apiKeyController.text.trim());
    setState(() {
      _isSaving = false;
      _savedMessage = 'Tersimpan';
    });
  }

  Future<void> _clearApiKey() async {
    await _settingsService.clearGeminiApiKey();
    setState(() {
      _apiKeyController.clear();
      _savedMessage = 'Dihapus';
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionLabel(label: 'AI ANALYSIS (BYOK)'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: AppColors.primaryGreen,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Gemini API Key',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Dipakai untuk fitur analisis AI pada sinyal '
                        'screening. Key kamu disimpan HANYA di HP ini, '
                        'tidak pernah dikirim ke server manapun selain '
                        'langsung ke Google.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _apiKeyController,
                        obscureText: _obscureApiKey,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Tempel API key Gemini di sini',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureApiKey
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscureApiKey = !_obscureApiKey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveApiKey,
                              child: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: _clearApiKey,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.dangerRed,
                            ),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                      if (_savedMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _savedMessage!,
                          style: const TextStyle(
                            color: AppColors.secondaryGreen,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _SectionLabel(label: 'TENTANG'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cryptostrat v1.0.0',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Data screening bersumber dari Binance Public '
                        'API. App ini TIDAK menyimpan API key atau '
                        'akses ke akun Binance kamu - murni read-only '
                        'untuk tujuan analisis.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}
