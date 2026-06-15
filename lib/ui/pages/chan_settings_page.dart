import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChanSettingsPage extends StatefulWidget {
  const ChanSettingsPage({super.key});

  @override
  State<ChanSettingsPage> createState() => _ChanSettingsPageState();
}

class _ChanSettingsPageState extends State<ChanSettingsPage> {
  static const String _sourceBranch = 'zhibiao';
  static const String _sourceFile = 'lib/ui/pages/origin_replay_page_v2.dart';

  static const Map<String, Object?> _defaults = <String, Object?>{
    'skip_step': 0,
    'bi_algo': 'normal',
    'bi_strict': true,
    'bi_fx_check': 'strict',
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

  static const Map<String, List<String>> _options = <String, List<String>>{
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

  static const List<_SettingGroup> _groups = <_SettingGroup>[
    _SettingGroup(
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
    _SettingGroup(
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
    _SettingGroup(
      '线段 SEG',
      '线段算法和左侧线段选择方法。',
      <String>['seg_algo', 'left_seg_method'],
    ),
    _SettingGroup(
      '中枢 ZS',
      '普通中枢、跨段中枢、合并口径和单笔中枢开关。',
      <String>['zs_algo', 'zs_combine_mode', 'zs_combine', 'one_bi_zs'],
    ),
    _SettingGroup(
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
    _SettingGroup(
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

  final TextEditingController _searchController = TextEditingController();
  late Map<String, Object?> _values;

  @override
  void initState() {
    super.initState();
    _values = Map<String, Object?>.from(_defaults);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _changedCount =>
      _defaults.keys.where((key) => _values[key] != _defaults[key]).length;

  @override
  Widget build(BuildContext context) {
    final groups = _visibleGroups();
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _header(),
            Expanded(
              child: groups.isEmpty
                  ? const Center(
                      child: Text('没有匹配的设置项',
                          style: TextStyle(color: Colors.white54)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(48, 12, 16, 20),
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _groupCard(groups[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(48, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Color(0xFF111722),
          border: Border(bottom: BorderSide(color: Colors.white12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.settings, color: Color(0xFFFFD54F), size: 20),
                const SizedBox(width: 8),
                const Text('设置',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 12),
                _pill('来源: $_sourceBranch'),
                const SizedBox(width: 8),
                _pill('改动: $_changedCount'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _copyJson,
                  icon: const Icon(Icons.copy, size: 17),
                  label: const Text('复制 JSON'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _changedCount == 0 ? null : _resetDefaults,
                  icon: const Icon(Icons.restore, size: 17),
                  label: const Text('恢复默认'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '从历史 zhibiao 分支“复盘”页抽取 CChanConfig 默认值和控件语义，先独立落到同级“设置”页，减少与 hichan 及同级功能分支的复盘核心逻辑冲突。',
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _decoration('搜索设置项 / key / 默认值').copyWith(
                      prefixIcon: const Icon(Icons.search, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _pill(_sourceFile),
              ],
            ),
          ],
        ),
      );

  List<_SettingGroup> _visibleGroups() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _groups;
    return <_SettingGroup>[
      for (final group in _groups)
        _SettingGroup(
          group.title,
          group.note,
          group.keys.where((key) {
            final haystack = '${group.title} ${group.note} $key '
                    '${_defaults[key]} ${_options[key] ?? const <String>[]}'
                .toLowerCase();
            return haystack.contains(query);
          }).toList(growable: false),
        ),
    ].where((group) => group.keys.isNotEmpty).toList(growable: false);
  }

  Widget _groupCard(_SettingGroup group) => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF2111722),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(group.title,
                      style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  _pill('${group.keys.length} 项'),
                ],
              ),
              const SizedBox(height: 6),
              Text(group.note,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12, height: 1.35)),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 860;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      for (final key in group.keys)
                        SizedBox(
                          width: twoColumns
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth,
                          child: _settingTile(key),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );

  Widget _settingTile(String key) {
    final changed = _values[key] != _defaults[key];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: changed ? const Color(0x333F51B5) : const Color(0x661C2330),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: changed ? const Color(0xFF8AB4FF) : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: SelectableText(key,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
              _badge(changed ? '已改' : '默认', _fmt(_defaults[key]), changed),
            ],
          ),
          const SizedBox(height: 6),
          Text(_hintFor(key),
              style: const TextStyle(
                  color: Colors.white60, fontSize: 12, height: 1.35)),
          const SizedBox(height: 10),
          _control(key),
        ],
      ),
    );
  }

  Widget _control(String key) {
    final defaultValue = _defaults[key];
    final value = _values[key] ?? defaultValue;
    final options = _options[key];
    if (defaultValue is bool) {
      return SwitchListTile(
        value: value == true,
        onChanged: (next) => setState(() => _values[key] = next),
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(value == true ? '启用' : '关闭',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      );
    }
    if (options != null) {
      final current = options.contains(value) ? '$value' : null;
      return DropdownButtonFormField<String>(
        value: current,
        dropdownColor: const Color(0xFF1C2330),
        decoration: _decoration('选择 $key'),
        items: <DropdownMenuItem<String>>[
          for (final item in options)
            DropdownMenuItem<String>(value: item, child: Text(item)),
        ],
        onChanged: (next) {
          if (next != null) setState(() => _values[key] = next);
        },
      );
    }
    if (defaultValue is int) {
      return TextFormField(
        key: ValueKey<String>('$key:${_fmt(value)}'),
        initialValue: _fmt(value),
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: _decoration('整数'),
        onChanged: (raw) => _values[key] = int.tryParse(raw.trim()) ?? raw.trim(),
        onEditingComplete: () => setState(() {}),
      );
    }
    return TextFormField(
      key: ValueKey<String>('$key:${_fmt(value)}'),
      initialValue: _fmt(value),
      minLines: key == 'bsp_advanced' ? 2 : 1,
      maxLines: key == 'bsp_advanced' ? 4 : 1,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration('文本'),
      onChanged: (raw) => _values[key] = raw.trim(),
      onEditingComplete: () => setState(() {}),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFF0D1117),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
      );

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2330),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            overflow: TextOverflow.ellipsis),
      );

  Widget _badge(String state, String defaultText, bool changed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: changed
              ? const Color(0x332962FF)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: changed ? const Color(0xFF8AB4FF) : Colors.white12),
        ),
        child: Text('$state: $defaultText',
            style: TextStyle(
                color: changed ? const Color(0xFF8AB4FF) : Colors.white54,
                fontSize: 10)),
      );

  String _hintFor(String key) {
    if (key == 'max_kl_misalgin_cnt') {
      return '历史字段保持原拼写，避免和 Python 配置键不一致。';
    }
    if (key == 'bs_type') return '逗号分隔：1,1p,2,2s,3a,3b。';
    if (key == 'bsp_advanced') {
      return '高级覆盖项，历史分支支持 buy/sell/segbuy/segsell/seg 后缀。';
    }
    if (key.startsWith('bsp') ||
        key.startsWith('bs') ||
        key.contains('divergence')) {
      return '买卖点配置，直接对应历史复盘页 CChanConfig。';
    }
    if (key.startsWith('macd') ||
        key.startsWith('cal_') ||
        key.contains('cycle') ||
        key.startsWith('demark') ||
        key == 'boll_n') {
      return '指标计算配置，沿用历史复盘页默认值。';
    }
    return '历史复盘页 CChanConfig 设置项。';
  }

  String _fmt(Object? value) => value == null ? '' : '$value';

  void _resetDefaults() {
    setState(() => _values = Map<String, Object?>.from(_defaults));
  }

  Future<void> _copyJson() async {
    const encoder = JsonEncoder.withIndent('  ');
    await Clipboard.setData(ClipboardData(text: encoder.convert(_values)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制当前 CChanConfig JSON')),
    );
  }
}

class _SettingGroup {
  final String title;
  final String note;
  final List<String> keys;

  const _SettingGroup(this.title, this.note, this.keys);
}
