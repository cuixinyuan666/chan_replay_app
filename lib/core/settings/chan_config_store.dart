import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'level_promoter_settings.dart';

class ChanSettingGroup {
  final String title;
  final String note;
  final List<String> keys;

  const ChanSettingGroup(this.title, this.note, this.keys);
}

class ChanConfigStore {
  static const String sourceBranch = 'origin_vespa_tdx/hichan → zhibiao';
  static const String sourceFile = 'lib/ui/pages/origin_replay_page_v2.dart';

  static const List<String> bspTypes = <String>['1', '1p', '2', '2s', '3a', '3b'];

  static const Set<String> bspAdvancedSuffixes = <String>{
    'buy',
    'sell',
    'segbuy',
    'segsell',
    'seg',
  };

  static const Map<String, String> bspAdvancedSuffixLabels = <String, String>{
    'buy': '买点覆盖 buy',
    'sell': '卖点覆盖 sell',
    'segbuy': '段买点覆盖 segbuy',
    'segsell': '段卖点覆盖 segsell',
    'seg': '线段默认覆盖 seg',
  };

  static const Set<String> bspAdvancedKeys = <String>{
    'divergence_rate',
    'min_zs_cnt',
    'bsp1_only_multibi_zs',
    'max_bs2_rate',
    'macd_algo',
    'bs1_peak',
    'bs_type',
    'bsp2_follow_1',
    'bsp3_follow_1',
    'bsp3_peak',
    'bsp2s_follow_2',
    'max_bsp2s_lv',
    'strict_bsp3',
    'bsp3a_max_zs_cnt',
  };

  static const Map<String, Object?> defaultValues = <String, Object?>{
    'skip_step': 0,
    'bi_algo': 'fx',
    'bi_strict': true,
    'bi_fx_check': 'loss',
    'gap_as_kl': false,
    'bi_end_is_peak': true,
    'bi_allow_sub_peak': true,
    'seg_algo': 'chan',
    'left_seg_method': 'peak',
    'zs_algo': 'normal',
    'zs_combine': true,
    'zs_combine_mode': 'zs',
    'one_bi_zs': false,
    'kl_data_check': true,
    'max_kl_misalgin_cnt': 2,
    'max_kl_inconsistent_cnt': 5,
    'auto_skip_illegal_sub_lv': false,
    'print_warning': true,
    'print_err_time': true,
    'mean_metrics': '',
    'trend_metrics': '',
    'macd_fast': 12,
    'macd_slow': 26,
    'macd_signal': 9,
    'cal_demark': false,
    'cal_rsi': false,
    'cal_kdj': false,
    'rsi_cycle': 14,
    'kdj_cycle': 9,
    'demark_len': 9,
    'demark_setup_bias': 4,
    'demark_countdown_bias': 2,
    'demark_max_countdown': 13,
    'demark_tiaokong_st': true,
    'demark_setup_cmp2close': true,
    'demark_countdown_cmp2close': true,
    'boll_n': 20,
    'bs_type': '1,1p,2,2s,3a,3b',
    'divergence_rate': '1e18',
    'min_zs_cnt': 1,
    'bsp1_only_multibi_zs': true,
    'max_bs2_rate': '0.9999',
    'bs1_peak': true,
    'bsp2_follow_1': true,
    'bsp3_follow_1': true,
    'bsp3_peak': false,
    'bsp2s_follow_2': false,
    'max_bsp2s_lv': '',
    'strict_bsp3': false,
    'bsp3a_max_zs_cnt': 1,
    'macd_algo': 'peak',
    'bsp_advanced': '',
  };

  static const Map<String, List<String>> options = <String, List<String>>{
    'bi_algo': <String>['normal', 'fx'],
    'bi_fx_check': <String>['strict', 'loss', 'half', 'totally'],
    'seg_algo': <String>['chan', '1+1', 'break'],
    'left_seg_method': <String>['peak', 'all'],
    'zs_algo': <String>['normal', 'over_seg', 'auto'],
    'zs_combine_mode': <String>['zs', 'peak'],
    'macd_algo': <String>[
      'area',
      'peak',
      'full_area',
      'diff',
      'slope',
      'amp',
      'volumn',
      'amount',
      'volumn_avg',
      'amount_avg',
      'turnrate_avg',
      'rsi',
    ],
  };

  static const List<ChanSettingGroup> groups = <ChanSettingGroup>[
    ChanSettingGroup(
      '回放 / 数据校验',
      'step_load / trigger_step 节奏、K线一致性检查和日志输出。',
      <String>[
        'skip_step',
        'kl_data_check',
        'max_kl_misalgin_cnt',
        'max_kl_inconsistent_cnt',
        'auto_skip_illegal_sub_lv',
        'print_warning',
        'print_err_time',
      ],
    ),
    ChanSettingGroup(
      '笔 BI',
      '分型成笔、缺口处理、笔端点和子峰口径。',
      <String>[
        'bi_algo',
        'bi_fx_check',
        'bi_strict',
        'gap_as_kl',
        'bi_end_is_peak',
        'bi_allow_sub_peak',
      ],
    ),
    ChanSettingGroup(
      '线段 SEG',
      '线段算法和左侧线段选择方法。',
      <String>['seg_algo', 'left_seg_method'],
    ),
    ChanSettingGroup(
      '中枢 ZS',
      '普通中枢、跨段中枢、合并口径和单笔中枢开关。',
      <String>['zs_algo', 'zs_combine_mode', 'zs_combine', 'one_bi_zs'],
    ),
    ChanSettingGroup(
      '指标模型',
      '均线、趋势、MACD、BOLL、RSI、KDJ 与 Demark 参数。',
      <String>[
        'mean_metrics',
        'trend_metrics',
        'macd_fast',
        'macd_slow',
        'macd_signal',
        'boll_n',
        'cal_demark',
        'cal_rsi',
        'cal_kdj',
        'rsi_cycle',
        'kdj_cycle',
        'demark_len',
        'demark_setup_bias',
        'demark_countdown_bias',
        'demark_max_countdown',
        'demark_tiaokong_st',
        'demark_setup_cmp2close',
        'demark_countdown_cmp2close',
      ],
    ),
    ChanSettingGroup(
      '买卖点 BSP',
      '买卖点类型、背驰阈值、2/3类跟随关系和高级覆盖。',
      <String>[
        'bs_type',
        'divergence_rate',
        'min_zs_cnt',
        'bsp1_only_multibi_zs',
        'max_bs2_rate',
        'bs1_peak',
        'bsp2_follow_1',
        'bsp3_follow_1',
        'bsp3_peak',
        'bsp2s_follow_2',
        'max_bsp2s_lv',
        'strict_bsp3',
        'bsp3a_max_zs_cnt',
        'macd_algo',
        'bsp_advanced',
      ],
    ),
  ];

  static final ValueNotifier<Map<String, Object?>> notifier =
      ValueNotifier<Map<String, Object?>>(Map<String, Object?>.from(defaultValues));

  static Map<String, Object?> get values => Map<String, Object?>.unmodifiable(notifier.value);

  static int get changedCount => defaultValues.keys
      .where((key) => notifier.value[key] != defaultValues[key])
      .length;

  static bool get hasChanges => changedCount > 0;

  static bool get isValid => invalidKeys(notifier.value).isEmpty;

  static List<String> invalidKeys([Map<String, Object?>? rawValues]) {
    final source = rawValues ?? notifier.value;
    return <String>[
      for (final key in defaultValues.keys)
        if (!isValidValue(key, source[key])) key,
    ];
  }

  static void replace(Map<String, Object?> nextValues) {
    final normalized = Map<String, Object?>.from(defaultValues);
    for (final entry in nextValues.entries) {
      if (defaultValues.containsKey(entry.key)) {
        normalized[entry.key] = entry.value;
      }
    }
    notifier.value = normalized;
  }

  static void setValue(String key, Object? value) {
    if (!defaultValues.containsKey(key)) return;
    final next = Map<String, Object?>.from(notifier.value)..[key] = value;
    replace(next);
  }

  static void reset() {
    notifier.value = Map<String, Object?>.from(defaultValues);
  }

  /// Builds the exact config payload for Python CChanConfig/analyze_multi.
  ///
  /// The UI-only `bsp_advanced` text is intentionally not sent as a raw key;
  /// it is expanded to the historical `key-suffix=value` override map first.
  /// Level promoter fields are appended last so the global N setting wins over
  /// older hard-coded page configs such as recursive_seg_max_level=4.
  static Map<String, dynamic> backendConfig({Map<String, dynamic> base = const <String, dynamic>{}}) {
    final invalid = invalidKeys();
    if (invalid.isNotEmpty) {
      throw FormatException('Invalid CChanConfig keys: ${invalid.join(', ')}');
    }
    final result = Map<String, dynamic>.from(base);
    final current = notifier.value;
    for (final key in defaultValues.keys) {
      if (key == 'bsp_advanced') continue;
      result[key] = current[key];
    }
    result.addAll(parseBspAdvancedText('${current['bsp_advanced'] ?? ''}'));
    result.addAll(LevelPromoterSettings.configFields);
    return result;
  }

  static String currentJson({bool backend = false}) {
    final data = backend ? backendConfig() : notifier.value;
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static bool isValidValue(String key, Object? value) {
    if (!defaultValues.containsKey(key)) return false;
    if (key == 'bsp_advanced') return parseBspAdvancedTextOrNull('$value') != null;
    final defaultValue = defaultValues[key];
    final optionValues = options[key];
    if (optionValues != null) return optionValues.contains('$value');
    if (defaultValue is bool) return value is bool;
    if (defaultValue is int) return value is int;
    switch (key) {
      case 'bs_type':
        return validBspTypeText('$value');
      case 'mean_metrics':
      case 'trend_metrics':
        return validIntListText('$value');
      case 'divergence_rate':
        return validDoubleText('$value');
      case 'max_bs2_rate':
        return validDoubleText('$value', max: 1);
      case 'max_bsp2s_lv':
        return validOptionalIntText('$value');
    }
    return value != null;
  }

  static List<String> csvTokens(String text) => text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  static bool validBspTypeText(String text) {
    final tokens = csvTokens(text);
    if (tokens.isEmpty) return false;
    return tokens.toSet().length == tokens.length &&
        tokens.every(bspTypes.contains);
  }

  static bool validIntListText(String text) {
    return csvTokens(text).every((token) => int.tryParse(token) != null);
  }

  static bool validDoubleText(String text, {double? max}) {
    final raw = text.trim().toLowerCase();
    if (raw.isEmpty) return false;
    if (raw == 'inf' || raw == 'infinity') return max == null;
    final value = double.tryParse(raw);
    if (value == null) return false;
    return max == null || value <= max;
  }

  static bool validOptionalIntText(String text) {
    final raw = text.trim().toLowerCase();
    return raw.isEmpty || raw == 'none' || raw == 'null' || int.tryParse(raw) != null;
  }

  static Map<String, String> parseBspAdvancedText(String text) {
    return parseBspAdvancedTextOrNull(text) ?? const <String, String>{};
  }

  static Map<String, String>? parseBspAdvancedTextOrNull(String text) {
    final result = <String, String>{};
    for (final line in const LineSplitter().convert(text)) {
      final raw = line.trim();
      if (raw.isEmpty || raw.startsWith('#')) continue;
      final sep = raw.indexOf('=');
      if (sep <= 0) return null;
      final key = raw.substring(0, sep).trim();
      final value = raw.substring(sep + 1).trim();
      if (value.isEmpty || !validBspAdvancedKey(key) || !validBspAdvancedValue(key, value)) {
        return null;
      }
      result[key] = value;
    }
    return result;
  }

  static bool validBspAdvancedKey(String key) {
    final dash = key.lastIndexOf('-');
    if (dash <= 0 || dash >= key.length - 1) return false;
    final name = key.substring(0, dash);
    final suffix = key.substring(dash + 1);
    return bspAdvancedKeys.contains(name) && bspAdvancedSuffixes.contains(suffix);
  }

  static bool validBspAdvancedValue(String key, String value) {
    final dash = key.lastIndexOf('-');
    if (dash <= 0 || dash >= key.length - 1) return false;
    final name = key.substring(0, dash);
    final suffix = key.substring(dash + 1);
    final raw = value.trim();
    if (raw.isEmpty) return false;
    switch (name) {
      case 'divergence_rate':
        return validDoubleText(raw);
      case 'max_bs2_rate':
        return validDoubleText(raw, max: 1);
      case 'min_zs_cnt':
        return int.tryParse(raw) != null;
      case 'bsp3a_max_zs_cnt':
        final parsed = int.tryParse(raw);
        return parsed != null && parsed >= 1;
      case 'max_bsp2s_lv':
        return validOptionalIntText(raw);
      case 'bs_type':
        return validBspTypeText(raw);
      case 'macd_algo':
        if (suffix == 'seg' || suffix == 'segbuy' || suffix == 'segsell') {
          return raw == 'slope';
        }
        return options['macd_algo']!.contains(raw);
      case 'bsp1_only_multibi_zs':
      case 'bs1_peak':
      case 'bsp2_follow_1':
      case 'bsp3_follow_1':
      case 'bsp3_peak':
      case 'bsp2s_follow_2':
      case 'strict_bsp3':
        return validBoolText(raw);
    }
    return false;
  }

  static bool validBoolText(String text) {
    return <String>{'true', 'false', '1', '0', 'yes', 'no', 'y', 'n', 'on', 'off'}
        .contains(text.trim().toLowerCase());
  }
}
