import 'package:flutter/material.dart';
import '../models/strategy_parameters.dart';
import '../models/strategy_signal.dart';
import '../services/parameters_service.dart';
import '../theme/app_colors.dart';

/// Halaman tuning parameter strategi. Dipanggil dari icon gear di
/// bawah tombol Analyze di LandingPage - satu halaman per mode
/// (Spot atau Futures). Setelah Save/Default, Navigator.pop() kembali
/// ke LandingPage dengan parameter terbaru.
class ParameterTuningPage extends StatefulWidget {
  final MarketType mode;
  final StrategyParameters initialParams;

  const ParameterTuningPage({
    super.key,
    required this.mode,
    required this.initialParams,
  });

  @override
  State<ParameterTuningPage> createState() => _ParameterTuningPageState();
}

class _ParameterTuningPageState extends State<ParameterTuningPage> {
  final _parametersService = ParametersService();
  late StrategyParameters _params;
  bool _isSaving = false;
  bool _hasChanges = false;

  bool get _isSpot => widget.mode == MarketType.spot;

  @override
  void initState() {
    super.initState();
    _params = widget.initialParams;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await _parametersService.save(_params);
    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(_params);
  }

  Future<void> _resetToDefault() async {
    setState(() {
      _params = _isSpot
          ? _params.copyWith(
              spotRsiLower: StrategyParameters.defaults.spotRsiLower,
              spotRsiUpper: StrategyParameters.defaults.spotRsiUpper,
              spotVolumeMultiplier:
                  StrategyParameters.defaults.spotVolumeMultiplier,
              spotWhaleBidAskRatio:
                  StrategyParameters.defaults.spotWhaleBidAskRatio,
              spotSidewaysMaxRangePercent:
                  StrategyParameters.defaults.spotSidewaysMaxRangePercent,
            )
          : _params.copyWith(
              futuresPriceChange4h:
                  StrategyParameters.defaults.futuresPriceChange4h,
              futuresOiChange4h:
                  StrategyParameters.defaults.futuresOiChange4h,
              futuresFundingExtremeLong:
                  StrategyParameters.defaults.futuresFundingExtremeLong,
              futuresFundingExtremeShort:
                  StrategyParameters.defaults.futuresFundingExtremeShort,
              futuresLowCapPriceChange1h:
                  StrategyParameters.defaults.futuresLowCapPriceChange1h,
            );
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Parameter ${_isSpot ? "SPOT" : "FUTURES"}',
          style: TextStyle(
            color: _isSpot ? AppColors.primaryGreen : AppColors.warningAmber,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 16),
          if (_isSpot) ..._buildSpotParams() else ..._buildFuturesParams(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.textMuted, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Nilai default sudah dioptimasi. Ubah hanya jika kamu '
              'memahami implikasinya terhadap sensitivitas sinyal.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSpotParams() {
    return [
      _SectionHeader(
        title: 'Momentum Breakout',
        subtitle: 'Filter kekuatan momentum via RSI & volume',
        color: AppColors.primaryGreen,
      ),
      _ParamSlider(
        label: 'RSI Batas Bawah',
        description:
            'RSI harus DI ATAS nilai ini agar sinyal dianggap valid. '
            'Lebih tinggi = lebih selektif (hanya momentum kuat).',
        value: _params.spotRsiLower,
        min: 45,
        max: 65,
        divisions: 20,
        unit: '',
        defaultValue: StrategyParameters.defaults.spotRsiLower,
        onChanged: (v) => setState(() {
          _params = _params.copyWith(spotRsiLower: v);
          _hasChanges = true;
        }),
      ),
      _ParamSlider(
        label: 'RSI Batas Atas',
        description:
            'RSI harus DI BAWAH nilai ini (belum overbought). '
            'Lebih rendah = hindari entry di zona jenuh beli.',
        value: _params.spotRsiUpper,
        min: 65,
        max: 85,
        divisions: 20,
        unit: '',
        defaultValue: StrategyParameters.defaults.spotRsiUpper,
        onChanged: (v) => setState(() {
          _params = _params.copyWith(spotRsiUpper: v);
          _hasChanges = true;
        }),
      ),
      _ParamSlider(
        label: 'Volume Multiplier',
        description:
            'Volume saat ini harus sekian kali rata-rata 7 hari. '
            'Lebih tinggi = hanya sinyal dengan lonjakan volume besar.',
        value: _params.spotVolumeMultiplier,
        min: 1.5,
        max: 5.0,
        divisions: 35,
        unit: 'x',
        defaultValue: StrategyParameters.defaults.spotVolumeMultiplier,
        onChanged: (v) => setState(() {
          _params = _params.copyWith(spotVolumeMultiplier: v);
          _hasChanges = true;
        }),
      ),
      const SizedBox(height: 8),
      _SectionHeader(
        title: 'Whale Watch',
        subtitle: 'Deteksi akumulasi besar via order book',
        color: AppColors.primaryGreen,
      ),
      _ParamSlider(
        label: 'Min Bid/Ask Ratio',
        description:
            'Total bid dalam 1% dari harga harus sekian kali total ask. '
            'Lebih tinggi = hanya wall beli yang jauh lebih dominan.',
        value: _params.spotWhaleBidAskRatio,
        min: 2.0,
        max: 6.0,
        divisions: 40,
        unit: 'x',
        defaultValue: StrategyParameters.defaults.spotWhaleBidAskRatio,
        onChanged: (v) => setState(() {
          _params = _params.copyWith(spotWhaleBidAskRatio: v);
          _hasChanges = true;
        }),
      ),
      const SizedBox(height: 8),
      _SectionHeader(
        title: 'Accumulation Zone',
        subtitle: 'Deteksi BB squeeze + konsolidasi sideways',
        color: AppColors.primaryGreen,
      ),
      _ParamSlider(
        label: 'Maks Range Sideways',
        description:
            'Range high-low 6 jam terakhir harus di BAWAH nilai ini. '
            'Lebih kecil = hanya konsolidasi yang benar-benar ketat.',
        value: _params.spotSidewaysMaxRangePercent,
        min: 2.0,
        max: 8.0,
        divisions: 60,
        unit: '%',
        defaultValue: StrategyParameters.defaults.spotSidewaysMaxRangePercent,
        onChanged: (v) => setState(() {
          _params = _params.copyWith(spotSidewaysMaxRangePercent: v);
          _hasChanges = true;
        }),
      ),
    ];
  }

  List<Widget> _buildFuturesParams() {
    return [
      _SectionHeader(
        title: 'Trend Confirm',
        subtitle: 'Filter tren sehat via OI + price change',
        color: AppColors.warningAmber,
      ),
      _ParamSlider(
        label: 'Min Price Change 4h',
        description:
            'Perubahan harga dalam 4 jam harus melebihi nilai ini. '
            'Lebih tinggi = hanya tren yang bergerak lebih agresif.',
        value: _params.futuresPriceChange4h,
        min: 1.5,
        max: 6.0,
        divisions: 45,
        unit: '%',
        defaultValue: StrategyParameters.defaults.futuresPriceChange4h,
        onChanged: (v) => setState(() {
          _params = _params.copyWith(futuresPriceChange4h: v);
          _hasChanges = true;
        }),
      ),
      _ParamSlider(
        label: 'Min OI Change 4h',
        description:
            'Open Interest harus naik sekian persen dalam 4 jam. '
            'Konfirmasi ada uang baru masuk, bukan short covering.',
        value: _params.futuresOiChange4h,
        min: 3.0,
        max: 10.0,
        divisions: 70,
        unit: '%',
        defaultValue: StrategyParameters.defaults.futuresOiChange4h,
        onChanged: (v) => setState(() {
          _params = _params.copyWith(futuresOiChange4h: v);
          _hasChanges = true;
        }),
      ),
      const SizedBox(height: 8),
      _SectionHeader(
        title: 'Squeeze Radar',
        subtitle: 'Deteksi funding rate ekstrem rawan reversal',
        color: AppColors.warningAmber,
      ),
      _ParamSlider(
        label: 'Funding Ekstrem Long',
        description:
            'Funding rate di ATAS nilai ini = terlalu banyak long, '
            'rawan long squeeze. Lebih rendah = lebih sensitif.',
        value: _params.futuresFundingExtremeLong,
        min: 0.05,
        max: 0.20,
        divisions: 30,
        unit: '%',
        defaultValue: StrategyParameters.defaults.futuresFundingExtremeLong,
        onChanged: (v) => setState(() {
          _params = _params.copyWith(futuresFundingExtremeLong: v);
          _hasChanges = true;
        }),
      ),
      _ParamSlider(
        label: 'Funding Ekstrem Short',
        description:
            'Magnitude funding negatif di ATAS nilai ini (tanpa minus) '
            '= terlalu banyak short, rawan short squeeze.',
        value: _params.futuresFundingExtremeShort.abs(),
        min: 0.03,
        max: 0.15,
        divisions: 24,
        unit: '%',
        defaultValue:
            StrategyParameters.defaults.futuresFundingExtremeShort.abs(),
        onChanged: (v) => setState(() {
          // Disimpan sebagai nilai negatif di model, ditampilkan
          // sebagai positif di slider supaya tidak membingungkan user.
          _params = _params.copyWith(futuresFundingExtremeShort: -v);
          _hasChanges = true;
        }),
      ),
      const SizedBox(height: 8),
      _SectionHeader(
        title: 'Low Cap Momentum',
        subtitle: 'Lonjakan agresif altcoin kecil di Futures',
        color: AppColors.warningAmber,
      ),
      _ParamSlider(
        label: 'Min Price Change 1h',
        description:
            'Perubahan harga dalam 1 jam untuk altcoin kecil Futures. '
            'Lebih tinggi = hanya lonjakan yang benar-benar ekstrem.',
        value: _params.futuresLowCapPriceChange1h,
        min: 5.0,
        max: 15.0,
        divisions: 100,
        unit: '%',
        defaultValue: StrategyParameters.defaults.futuresLowCapPriceChange1h,
        onChanged: (v) => setState(() {
          _params = _params.copyWith(futuresLowCapPriceChange1h: v);
          _hasChanges = true;
        }),
      ),
    ];
  }

  Widget _buildBottomBar() {
    final accentColor = _isSpot ? AppColors.primaryGreen : AppColors.warningAmber;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _resetToDefault,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Default'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isSaving ? 'Menyimpan...' : 'Simpan & Kembali'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header section per strategi di halaman parameter.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slider tunggal untuk satu parameter dengan label, deskripsi,
/// nilai saat ini, dan indikator apakah sudah diubah dari default.
class _ParamSlider extends StatelessWidget {
  final String label;
  final String description;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final double defaultValue;
  final ValueChanged<double> onChanged;

  const _ParamSlider({
    required this.label,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.defaultValue,
    required this.onChanged,
  });

  bool get _isModified => (value - defaultValue).abs() > 0.001;
  String get _displayValue => value < 1
      ? value.toStringAsFixed(2)
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isModified
              ? AppColors.primaryGreen.withOpacity(0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Row(
                children: [
                  if (_isModified)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'diubah',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    '$_displayValue$unit',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppColors.primaryGreen,
            inactiveColor: AppColors.surfaceElevated,
            onChanged: onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${min < 1 ? min.toStringAsFixed(2) : min.toStringAsFixed(1)}$unit',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
              Text(
                'default: ${defaultValue < 1 ? defaultValue.toStringAsFixed(2) : defaultValue.toStringAsFixed(1)}$unit',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
              Text(
                '${max < 1 ? max.toStringAsFixed(2) : max.toStringAsFixed(1)}$unit',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
