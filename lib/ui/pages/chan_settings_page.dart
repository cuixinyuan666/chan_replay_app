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
                      itemBuilder: (context, index) => _groupCard(groups[index]),
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
              '从 origin_vespa_tdx（后续 hichan）历史演进线的 zhibiao 复盘页抽取 CChanConfig 默认值和控件语义。当前页面写入共享配置仓库，单股多级别复盘的 analyze_multi 将以该配置作为缠论计算基础。',
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
            ),
            if (invalid.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text('请先修正非法项：${invalid.join(', ')}',
                  style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12)),
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
    final changed = _values[key] != ChanConfigStore.defaultValues[key];
    final valid = ChanConfigStore.isValidValue(key, _values[key]);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: !valid
            ? const Color(0x33B00020)
            : changed
                ? const Color(0x333F51B5)
                : const Color(0x661C2330),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: !valid
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
                child: SelectableText(key,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
              _badge(!valid ? '非法' : (changed ? '已改' : '默认'),
                  _fmt(ChanConfigStore.defaultValues[key]), changed, valid),
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
    final defaultValue = ChanConfigStore.defaultValues[key];
    final value = _values[key] ?? defaultValue;
    final options = ChanConfigStore.options[key];
    if (defaultValue is bool) {
      return SwitchListTile(
        value: value == true,
        onChanged: (next) => _setValue(key, next),
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
          if (next != null) _setValue(key, next);
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
        onChanged: (raw) {
          final text = raw.trim();
          _setValue(key, int.tryParse(text) ?? text);
        },
      );
    }
    return TextFormField(
      key: ValueKey<String>('$key:${_fmt(value)}'),
      initialValue: _fmt(value),
      minLines: key == 'bsp_advanced' ? 2 : 1,
      maxLines: key == 'bsp_advanced' ? 6 : 1,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(key == 'bsp_advanced' ? '每行 key-suffix=value' : '文本'),
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
    if (key == 'max_kl_misalgin_cnt') return '历史字段保持原拼写，避免和 Python 配置键不一致。';
    if (key == 'bs_type') return '逗号分隔：1,1p,2,2s,3a,3b。';
    if (key == 'bsp_advanced') return '高级覆盖项：每行 key-suffix=value；后端请求时会展开，不会把 bsp_advanced 原文作为配置键传入。';
    if (key.startsWith('bsp') || key.startsWith('bs') || key.contains('divergence')) return '买卖点配置，直接对应历史复盘页 CChanConfig。';
    if (key.startsWith('macd') || key.startsWith('cal_') || key.contains('cycle') || key.startsWith('demark') || key == 'boll_n') return '指标计算配置，沿用历史复盘页默认值。';
    return '历史复盘页 CChanConfig 设置项。';
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
      await Clipboard.setData(ClipboardData(text: ChanConfigStore.currentJson(backend: true)));
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
