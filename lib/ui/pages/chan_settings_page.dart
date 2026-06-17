import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/settings/chan_config_store.dart';

class ChanSettingsPage extends StatefulWidget {
  const ChanSettingsPage({super.key});

  @override
  State<ChanSettingsPage> createState() => _ChanSettingsPageState();
}

class _ChanSettingsPageState extends State<ChanSettingsPage> {
  final TextEditingController _searchController = TextEditingController();
  late Map<String, Object?> _values;

  @override
  void initState() {
    super.initState();
    _values = Map<String, Object?>.from(ChanConfigStore.values);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _changedCount => ChanConfigStore.changedCount;
  List<String> get _invalidKeys => ChanConfigStore.invalidKeys(_values);

  @override
  Widget build(BuildContext context) {
    final groups = _visibleGroups();
    final invalid = _invalidKeys;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _header(invalid),
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
                      itemBuilder: (context, index) => FractionallySizedBox(
                        widthFactor: 0.25,
                        alignment: Alignment.centerLeft,
                        child: _groupCard(groups[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(List<String> invalid) => Container(
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
                _pill('来源: ${ChanConfigStore.sourceBranch}'),
                const SizedBox(width: 8),
                _pill('改动: $_changedCount'),
                const SizedBox(width: 8),
                _pill(invalid.isEmpty ? '配置有效' : '非法: ${invalid.length}'),
                const Spacer(),
                TextButton.icon(
                  onPressed: invalid.isEmpty ? _copyBackendJson : null,
                  icon: const Icon(Icons.copy, size: 17),
                  label: const Text('复制后端 JSON'),
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
              '当前页面写入共享缠论配置仓库；单股、多级别复盘、扫描器等前端构建 analyze/analyze_multi 请求时会读取这些配置。将鼠标悬停在设置项上可查看 chan.py 逻辑说明。',
              style:
                  TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
            ),
            if (invalid.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text('请先修正非法项：${invalid.join(', ')}',
                  style:
                      const TextStyle(color: Color(0xFFFF8A80), fontSize: 12)),
            ],
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
                _pill(ChanConfigStore.sourceFile),
              ],
            ),
          ],
        ),
      );

  List<ChanSettingGroup> _visibleGroups() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return ChanConfigStore.groups;
    return <ChanSettingGroup>[
      for (final group in ChanConfigStore.groups)
        ChanSettingGroup(
          group.title,
          group.note,
          group.keys.where((key) {
            final haystack = '${group.title} ${group.note} $key '
                    '${ChanConfigStore.defaultValues[key]} '
                    '${ChanConfigStore.options[key] ?? const <String>[]}'
                .toLowerCase();
            return haystack.contains(query);
          }).toList(growable: false),
        ),
    ].where((group) => group.keys.isNotEmpty).toList(growable: false);
  }

  Widget _groupCard(ChanSettingGroup group) => DecoratedBox(
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
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: <Widget>[
                      for (final key in group.keys)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: _settingTile(key),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );

  static const Map<String, String> _settingTooltips = <String, String>{
    'skip_step': 'step_load / trigger_step 场景下跳过前 N 步输出；once 复盘通常不关注。',
    'bi_algo':
        '笔算法。normal 会调用 satisfy_bi_span() 检查成笔跨度；fx 会跳过跨度检查，但仍会检查分型有效性和端点极值。',
    'bi_strict':
        'normal 笔算法下的严格成笔跨度开关。true 要求更严格的合并K线跨度；bi_algo=fx 时 satisfy_bi_span() 被跳过，本项不参与。',
    'bi_fx_check':
        '分型有效性检查强度：loss 最宽松，half 中等，strict 默认严格，totally 最严格。normal 和 fx 都会使用。',
    'gap_as_kl':
        '是否把跳空也计入 normal 成笔跨度。该项只影响 satisfy_bi_span()；bi_algo=fx 时不参与。',
    'bi_end_is_peak': '笔端点是否必须是区间极值。开启后，候选笔终点必须是上一端点到当前端点之间的最高/最低端点。',
    'bi_allow_sub_peak': '是否允许子峰口径。关闭时 chan.py 会尝试用 update_peak 修正末笔峰谷。',
    'seg_algo': '线段算法。chan 为标准特征序列线段，1+1 / break 为其他线段算法口径。',
    'left_seg_method': '左侧线段选择方法。peak 偏向峰值端点，all 保留更多左侧候选。',
    'zs_algo': '中枢算法。normal 普通中枢，over_seg 跨段中枢，auto 自动口径。',
    'zs_combine': '是否合并相邻/重叠中枢。关闭时 zs_combine_mode 不参与。',
    'zs_combine_mode':
        '中枢合并模式。zs 按中枢区间合并，peak 按峰谷扩展口径合并；仅 zs_combine=true 时有效。',
    'one_bi_zs': '是否允许单笔中枢。',
    'kl_data_check':
        '是否检查多级别 K线对齐和一致性。关闭时 misalign/inconsistent 阈值及自动跳过非法子级别不参与。',
    'max_kl_misalgin_cnt': '允许的 K线错位数量阈值。仅 kl_data_check=true 时参与。',
    'max_kl_inconsistent_cnt': '允许的 K线不一致数量阈值。仅 kl_data_check=true 时参与。',
    'auto_skip_illegal_sub_lv': '遇到非法子级别时是否自动跳过。仅 kl_data_check=true 时参与。',
    'print_warning': '是否输出 chan.py warning。',
    'print_err_time': '是否打印错误发生时间。',
    'mean_metrics': '均线周期列表，逗号分隔，例如 5,10,20。',
    'trend_metrics': '趋势高低点模型周期列表，逗号分隔。',
    'macd_fast': 'MACD 快线周期。MACD 默认参与指标模型。',
    'macd_slow': 'MACD 慢线周期。MACD 默认参与指标模型。',
    'macd_signal': 'MACD signal 周期。MACD 默认参与指标模型。',
    'cal_demark': '是否计算 Demark 指标。关闭时 Demark 相关参数不参与。',
    'demark_len': 'Demark 计算长度。仅 cal_demark=true 时参与。',
    'demark_setup_bias': 'Demark setup bias。仅 cal_demark=true 时参与。',
    'demark_countdown_bias': 'Demark countdown bias。仅 cal_demark=true 时参与。',
    'demark_max_countdown': 'Demark 最大 countdown。仅 cal_demark=true 时参与。',
    'demark_tiaokong_st': 'Demark 跳空 setup 处理。仅 cal_demark=true 时参与。',
    'demark_setup_cmp2close':
        'Demark setup 是否用 close 比较。仅 cal_demark=true 时参与。',
    'demark_countdown_cmp2close':
        'Demark countdown 是否用 close 比较。仅 cal_demark=true 时参与。',
    'cal_rsi': '是否计算 RSI。关闭时 rsi_cycle 不参与。',
    'rsi_cycle': 'RSI 周期。仅 cal_rsi=true 时参与。',
    'cal_kdj': '是否计算 KDJ。关闭时 kdj_cycle 不参与。',
    'kdj_cycle': 'KDJ 周期。仅 cal_kdj=true 时参与。',
    'boll_n': 'BOLL 周期。',
    'bs_type': '买卖点类型，逗号分隔：1,1p,2,2s,3a,3b。',
    'divergence_rate': '背驰比例阈值。越严格，买卖点越少。',
    'min_zs_cnt': '买卖点要求的最小中枢数量。',
    'bsp1_only_multibi_zs': '一类买卖点是否仅使用多笔中枢。',
    'max_bs2_rate': '二类买卖点最大回抽比例，默认 0.9999。',
    'bs1_peak': '一类买卖点是否要求峰谷端点。',
    'bsp2_follow_1': '二类买卖点是否要求跟随一类买卖点。',
    'bsp3_follow_1': '三类买卖点是否要求跟随一类买卖点。',
    'bsp3_peak': '三类买卖点是否要求峰谷端点。',
    'bsp2s_follow_2': '二卖/二买加强型是否要求跟随二类买卖点。',
    'max_bsp2s_lv': '二卖/二买加强型最大级别限制；空值表示不限制。',
    'strict_bsp3': '是否使用严格三类买卖点。',
    'bsp3a_max_zs_cnt': '3a 买卖点允许的最大中枢数量。',
    'macd_algo': '买卖点背驰所用 MACD 算法，如 peak、area、diff、slope 等。',
    'bsp_advanced':
        '高级覆盖项，每行 key-suffix=value。后端会展开为 key-buy/key-sell/key-seg 等配置。',
  };

  String? _disabledReasonFor(String key) {
    final biAlgo =
        '${_values['bi_algo'] ?? ChanConfigStore.defaultValues['bi_algo']}';
    if (biAlgo == 'fx' && (key == 'bi_strict' || key == 'gap_as_kl')) {
      return 'bi_algo=fx 时会跳过 satisfy_bi_span() 成笔跨度检查，本项不参与计算。';
    }

    if (key == 'zs_combine_mode' && _values['zs_combine'] != true) {
      return 'zs_combine=false 时不执行中枢合并，本项不参与计算。';
    }

    if ((key == 'max_kl_misalgin_cnt' ||
            key == 'max_kl_inconsistent_cnt' ||
            key == 'auto_skip_illegal_sub_lv') &&
        _values['kl_data_check'] != true) {
      return 'kl_data_check=false 时不执行 K线一致性检查，本项不参与计算。';
    }

    if ((key == 'demark_len' ||
            key == 'demark_setup_bias' ||
            key == 'demark_countdown_bias' ||
            key == 'demark_max_countdown' ||
            key == 'demark_tiaokong_st' ||
            key == 'demark_setup_cmp2close' ||
            key == 'demark_countdown_cmp2close') &&
        _values['cal_demark'] != true) {
      return 'cal_demark=false 时不计算 Demark，本项不参与计算。';
    }

    if (key == 'rsi_cycle' && _values['cal_rsi'] != true) {
      return 'cal_rsi=false 时不计算 RSI，本项不参与计算。';
    }

    if (key == 'kdj_cycle' && _values['cal_kdj'] != true) {
      return 'cal_kdj=false 时不计算 KDJ，本项不参与计算。';
    }

    return null;
  }

  String _tooltipFor(String key) {
    final base = _settingTooltips[key] ?? '直接透传给后端 chan.py 配置。';
    final disabled = _disabledReasonFor(key);
    return disabled == null ? base : '$base\n\n当前灰度原因：$disabled';
  }

  Widget _settingTile(String key) {
    final changed = _values[key] != ChanConfigStore.defaultValues[key];
    final valid = ChanConfigStore.isValidValue(key, _values[key]);
    final disabledReason = _disabledReasonFor(key);
    final disabled = disabledReason != null;
    final tile = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: disabled
            ? const Color(0x331C2330)
            : !valid
                ? const Color(0x33B00020)
                : changed
                    ? const Color(0x333F51B5)
                    : const Color(0x661C2330),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: disabled
              ? Colors.white10
              : !valid
                  ? const Color(0xFFFF8A80)
                  : changed
                      ? const Color(0xFF8AB4FF)
                      : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: SelectableText(
                  key,
                  style: TextStyle(
                    color: disabled ? Colors.white38 : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              _badge(
                !valid ? '非法' : (disabled ? '灰度' : (changed ? '已改' : '默认')),
                _fmt(ChanConfigStore.defaultValues[key]),
                changed,
                valid && !disabled,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            disabledReason ?? _hintFor(key),
            style: TextStyle(
              color: disabled ? Colors.white38 : Colors.white60,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          _control(key),
        ],
      ),
    );

    return Tooltip(
      message: _tooltipFor(key),
      waitDuration: const Duration(milliseconds: 350),
      child: Opacity(
        opacity: disabled ? 0.58 : 1.0,
        child: tile,
      ),
    );
  }

  Widget _control(String key) {
    final defaultValue = ChanConfigStore.defaultValues[key];
    final value = _values[key] ?? defaultValue;
    final options = ChanConfigStore.options[key];
    final enabled = _disabledReasonFor(key) == null;

    if (defaultValue is bool) {
      return SwitchListTile(
        value: value == true,
        onChanged: enabled ? (next) => _setValue(key, next) : null,
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(
          value == true ? '启用' : '关闭',
          style: TextStyle(
            color: enabled ? Colors.white70 : Colors.white38,
            fontSize: 12,
          ),
        ),
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
        onChanged: enabled
            ? (next) {
                if (next != null) _setValue(key, next);
              }
            : null,
      );
    }

    if (defaultValue is int) {
      return TextFormField(
        key: ValueKey<String>('$key:${_fmt(value)}'),
        initialValue: _fmt(value),
        enabled: enabled,
        keyboardType: TextInputType.number,
        style: TextStyle(color: enabled ? Colors.white : Colors.white38),
        decoration: _decoration('整数'),
        onChanged: (raw) {
          final text = raw.trim();
          _setValue(key, int.tryParse(text) ?? text);
        },
      );
    }

    return TextFormField(
      key: ValueKey<String>('$key:${_fmt(value)}'),
      initialValue: _fmt(value),
      enabled: enabled,
      minLines: key == 'bsp_advanced' ? 2 : 1,
      maxLines: key == 'bsp_advanced' ? 6 : 1,
      style: TextStyle(color: enabled ? Colors.white : Colors.white38),
      decoration:
          _decoration(key == 'bsp_advanced' ? '每行 key-suffix=value' : '文本'),
      onChanged: (raw) => _setValue(key, raw.trim()),
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

  Widget _badge(String state, String defaultText, bool changed, bool valid) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: !valid
              ? const Color(0x22FF8A80)
              : changed
                  ? const Color(0x332962FF)
                  : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: !valid
                  ? const Color(0xFFFF8A80)
                  : changed
                      ? const Color(0xFF8AB4FF)
                      : Colors.white12),
        ),
        child: Text('$state: $defaultText',
            style: TextStyle(
                color: !valid
                    ? const Color(0xFFFF8A80)
                    : changed
                        ? const Color(0xFF8AB4FF)
                        : Colors.white54,
                fontSize: 10)),
      );

  String _hintFor(String key) {
    if (key == 'max_kl_misalgin_cnt')
      return '保持 chan.py 字段拼写，避免和 Python 配置键不一致。';
    if (key == 'bs_type') return '逗号分隔：1,1p,2,2s,3a,3b。';
    if (key == 'bsp_advanced') return '高级覆盖项：每行 key-suffix=value；后端请求时会展开。';
    if (key.startsWith('bsp') ||
        key.startsWith('bs') ||
        key.contains('divergence')) {
      return '买卖点配置；详细逻辑见悬停提示。';
    }
    if (key.startsWith('macd') ||
        key.startsWith('cal_') ||
        key.contains('cycle') ||
        key.startsWith('demark') ||
        key == 'boll_n') {
      return '指标计算配置；详细逻辑见悬停提示。';
    }
    return 'chan.py 计算配置；详细逻辑见悬停提示。';
  }

  String _fmt(Object? value) => value == null ? '' : '$value';

  void _setValue(String key, Object? value) {
    setState(() {
      _values[key] = value;
      ChanConfigStore.replace(_values);
    });
  }

  void _resetDefaults() {
    setState(() {
      ChanConfigStore.reset();
      _values = Map<String, Object?>.from(ChanConfigStore.values);
    });
  }

  Future<void> _copyBackendJson() async {
    try {
      await Clipboard.setData(
          ClipboardData(text: ChanConfigStore.currentJson(backend: true)));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制后端 CChanConfig JSON')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('配置非法，无法复制后端 JSON：$e')),
      );
    }
  }
}
