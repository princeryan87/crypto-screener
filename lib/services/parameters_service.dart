import 'package:shared_preferences/shared_preferences.dart';
import '../models/strategy_parameters.dart';

/// Service untuk persist parameter strategi yang sudah di-tune user
/// ke SharedPreferences, sehingga tetap tersimpan antar sesi app.
class ParametersService {
  static const String _prefix = 'param_';

  Future<StrategyParameters> load() async {
    final prefs = await SharedPreferences.getInstance();
    return StrategyParameters(
      spotRsiLower:
          prefs.getDouble('${_prefix}spot_rsi_lower') ??
              StrategyParameters.defaults.spotRsiLower,
      spotRsiUpper:
          prefs.getDouble('${_prefix}spot_rsi_upper') ??
              StrategyParameters.defaults.spotRsiUpper,
      spotVolumeMultiplier:
          prefs.getDouble('${_prefix}spot_volume_multiplier') ??
              StrategyParameters.defaults.spotVolumeMultiplier,
      spotWhaleBidAskRatio:
          prefs.getDouble('${_prefix}spot_whale_ratio') ??
              StrategyParameters.defaults.spotWhaleBidAskRatio,
      spotSidewaysMaxRangePercent:
          prefs.getDouble('${_prefix}spot_sideways_range') ??
              StrategyParameters.defaults.spotSidewaysMaxRangePercent,
      futuresPriceChange4h:
          prefs.getDouble('${_prefix}fut_price_4h') ??
              StrategyParameters.defaults.futuresPriceChange4h,
      futuresOiChange4h:
          prefs.getDouble('${_prefix}fut_oi_4h') ??
              StrategyParameters.defaults.futuresOiChange4h,
      futuresFundingExtremeLong:
          prefs.getDouble('${_prefix}fut_funding_long') ??
              StrategyParameters.defaults.futuresFundingExtremeLong,
      futuresFundingExtremeShort:
          prefs.getDouble('${_prefix}fut_funding_short') ??
              StrategyParameters.defaults.futuresFundingExtremeShort,
      futuresLowCapPriceChange1h:
          prefs.getDouble('${_prefix}fut_lowcap_1h') ??
              StrategyParameters.defaults.futuresLowCapPriceChange1h,
    );
  }

  Future<void> save(StrategyParameters params) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
        '${_prefix}spot_rsi_lower', params.spotRsiLower);
    await prefs.setDouble(
        '${_prefix}spot_rsi_upper', params.spotRsiUpper);
    await prefs.setDouble(
        '${_prefix}spot_volume_multiplier', params.spotVolumeMultiplier);
    await prefs.setDouble(
        '${_prefix}spot_whale_ratio', params.spotWhaleBidAskRatio);
    await prefs.setDouble(
        '${_prefix}spot_sideways_range', params.spotSidewaysMaxRangePercent);
    await prefs.setDouble(
        '${_prefix}fut_price_4h', params.futuresPriceChange4h);
    await prefs.setDouble(
        '${_prefix}fut_oi_4h', params.futuresOiChange4h);
    await prefs.setDouble(
        '${_prefix}fut_funding_long', params.futuresFundingExtremeLong);
    await prefs.setDouble(
        '${_prefix}fut_funding_short', params.futuresFundingExtremeShort);
    await prefs.setDouble(
        '${_prefix}fut_lowcap_1h', params.futuresLowCapPriceChange1h);
  }

  Future<void> resetToDefaults() async {
    await save(StrategyParameters.defaults);
  }
}
