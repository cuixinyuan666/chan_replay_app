import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/bsp.dart';
import '../../core/models/interval_nest_signal.dart';
import '../../core/models/level_relation.dart';
import '../../core/models/multi_level_chan_snapshot.dart';
import '../../core/models/signal_visibility_state.dart';

class MultiLevelIntervalSignalPanel extends StatefulWidget {
  final MultiLevelChanSnapshot snapshot;
  final String mode;
  final String symbol;
  final int? frameIndex;
  final int? frameCount;

  const MultiLevelIntervalSignalPanel({
    super.key,
    required this.snapshot,
    required this.mode,
    this.symbol = '',
    this.frameIndex,
    this.frameCount,
  });

  @override
  State<MultiLevelIntervalSignalPanel> createState() => _MultiLevelIntervalSignalPanelState();
}

class _MultiLevelIntervalSignalPanelState extends State<MultiLevelIntervalSignalPanel> {
  int _selectedIndex = 0;
  int _pairIndex = 0;
  String _ruleMode = 'validation';
  String _strategyRuleName = 'DAILY_2B_MIN30_1B';
  String _directionFilter = 'same';
  String _highTypeFilter = 'ANY';
  String _lowTypeFilter = 'ANY';

  bool get _isScanMode => widget.mode == 'signal_scan_once';
  bool get _isStrategyMode => _ruleMode == 'strategy';
  String get _signalRuleMode => _isStrategyMode ? 'strategy_interval_nest_buy' : 'validation_any_bsp_pair';
  String get _ruleChipLabel => _isStrategyMode ? 'strategy interval buy' : 'any BSP pair';
  String get _effectiveDirectionFilter => _isStrategyMode ? 'buy' : _directionFilter;

  static const List<String> _strategyRules = [
    'DAILY_2B_MIN30_1B',
    'DAILY_3B_MIN30_1B',
    'DAILY_3B_MIN30_2B',
  ];

  Map<String, dynamic>? get _timeLog {
    final raw = widget.snapshot.meta['time_log'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  bool get _hasTimeLog => _timeLog != null;

  String _runtimePath(Map<String, dynamic>? log) {
    final value = '${log?['runtime_path'] ?? widget.snapshot.meta['runtime_path'] ?? 'high_speed'}'.trim();
    return value.isEmpty ? 'high_speed' : value;
  }

  bool _isHighSpeedPath(Map<String, dynamic>? log) => _runtimePath(log) != 'slow_path';

  List<String> _runtimePathLines(Map<String, dynamic>? log) {
    final path = _runtimePath(log);
    final high = _isHighSpeedPath(log);
    return [
      'runtime_path: $path',
      'high_speed_enabled: $high',
      'slow_path_enabled: ${!high}',
      'runtime_path_default: high_speed',
      'runtime_path_policy: high_speed_default_slow_path_debug_only',
    ];
  }

  Object? _compactMeta(String key, [Map<String, dynamic>? log]) {
    final fromLog = log == null ? null : log[key];
    return fromLog ?? widget.snapshot.meta[key] ?? '';
  }

  String _compactMetaText(String key, [Map<String, dynamic>? log]) => '${_compactMeta(key, log)}'.trim();

  List<_LevelPair> get _pairs {
    final relationPairs = <String, _LevelPair>{};
    for (final r in widget.snapshot.relations) {
      relationPairs['${r.parentLevel}->${r.childLevel}'] = _LevelPair(r.parentLevel, r.childLevel);
    }
    if (relationPairs.isNotEmpty) return relationPairs.values.toList();
    final levels = widget.snapshot.levels;
    return [
      for (var i = 0; i < levels.length - 1; i++) _LevelPair(levels[i], levels[i + 1]),
    ];
  }

  _LevelPair? get _selectedPair {
    if (_isStrategyMode) return const _LevelPair('DAILY', 'MIN30');
    final pairs = _pairs;
    if (pairs.isEmpty) return null;
    if (_pairIndex >= pairs.length) _pairIndex = pairs.length - 1;
    return pairs[_pairIndex.clamp(0, pairs.length - 1).toInt()];
  }

  List<String> _typeOptionsForLevel(String level) {
    final snapshot = widget.snapshot.of(level);
    final types = <String>{'ANY'};
    for (final bsp in snapshot?.bsps ?? const <BspPoint>[]) {
      final text = bsp.type.trim();
      if (text.isNotEmpty) types.add(text);
    }
    return types.toList();
  }

  @override
  Widget build(BuildContext context) {
    final pair = _selectedPair;
    final signals = _buildSignals(pair);
    if (_selectedIndex >= signals.length) _selectedIndex = signals.isEmpty ? 0 : signals.length - 1;
    final selected = signals.isEmpty ? null : signals[_selectedIndex];
    final highTypes = pair == null ? const <String>['ANY'] : _typeOptionsForLevel(pair.parentLevel);
    final lowTypes = pair == null ? const <String>['ANY'] : _typeOptionsForLevel(pair.childLevel);
    if (!highTypes.contains(_highTypeFilter)) _highTypeFilter = 'ANY';
    if (!lowTypes.contains(_lowTypeFilter)) _lowTypeFilter = 'ANY';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(48, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x222A3B68),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x667EA7FF)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            _isStrategyMode ? 'Interval strategy' : 'Interval validation',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          _chip('rule', _ruleChipLabel, true),
          _chip('runtime_path', _runtimePath(_timeLog), _isHighSpeedPath(_timeLog)),
          _chip('source', 'chan.py BSP + native relation', true),
          if (_hasTimeLog) _chip('time_log', 'ready', true),
          if (_isStrategyMode) _chip('strategy', 'candidate only', false),
          if (pair != null) _chip('pair', pair.label, true),
          _chip('signals', '${signals.length}', signals.isNotEmpty),
          _ruleModeDropdown(),
          if (_isStrategyMode) _strategyRuleDropdown(),
          if (!_isStrategyMode) _pairDropdown(),
          if (!_isStrategyMode) _directionDropdown(),
          if (!_isStrategyMode) _typeDropdown('high type', _highTypeFilter, highTypes, (v) => setState(() => _highTypeFilter = v)),
          if (!_isStrategyMode) _typeDropdown('low type', _lowTypeFilter, lowTypes, (v) => setState(() => _lowTypeFilter = v)),
          if (_isStrategyMode) _chip('high', _highStrategyType, true),
          if (_isStrategyMode) _chip('low', _lowTriggerType, true),
          if (selected != null) _chip('selected', '${_selectedIndex + 1}/${signals.length}', true),
          if (selected != null) _chip('state', selected.signal.state.wireName, selected.signal.state != SignalVisibilityState.invalid),
          if (selected != null) _chip('pattern', '${selected.highBsp.type}->${selected.lowBsp.type}', true),
          if (selected != null) _chip('parent', 'raw:${selected.parentRelation.parentRawIndex}', true),
          if (selected != null) _chip('child', 'raw:${selected.lowBsp.rawIndex}', true),
          _smallButton('Prev', signals.isEmpty ? null : () => _setSelected(_selectedIndex - 1, signals.length)),
          _smallButton('Next', signals.isEmpty ? null : () => _setSelected(_selectedIndex + 1, signals.length)),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _copySignalText(pair, signals, selected)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signal diagnostics copied'), duration: Duration(seconds: 3)),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('Copy Signal'),
            style: _buttonStyle(),
          ),
          OutlinedButton.icon(
            onPressed: _hasTimeLog
                ? () async {
                    await Clipboard.setData(ClipboardData(text: _copyTimeLogText()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Time Log copied'), duration: Duration(seconds: 3)),
                      );
                    }
                  }
                : null,
            icon: const Icon(Icons.timer, size: 14),
            label: const Text('Copy Time Log'),
            style: _buttonStyle(),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _copyResultValidationText(pair, signals)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Result validation copied'), duration: Duration(seconds: 3)),
                );
              }
            },
            icon: const Icon(Icons.verified, size: 14),
            label: const Text('Copy Result Validation'),
            style: _buttonStyle(),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _copyS1EvidenceText(pair, signals, selected)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('S1 evidence copied'), duration: Duration(seconds: 3)),
                );
              }
            },
            icon: const Icon(Icons.fact_check, size: 14),
            label: const Text('Copy S1 Evidence'),
            style: _buttonStyle(),
          ),
        ],
      ),
    );
  }

  Widget _ruleModeDropdown() {
    const values = ['validation', 'strategy'];
    return SizedBox(
      width: 132,
      child: DropdownButtonFormField<String>(
        value: _ruleMode,
        dropdownColor: const Color(0xFF20242E),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: _dropdownDecoration('rule mode'),
        items: [for (final value in values) DropdownMenuItem(value: value, child: Text(value))],
        onChanged: (v) => setState(() {
          _ruleMode = v ?? 'validation';
          _selectedIndex = 0;
          if (_isStrategyMode) {
            _directionFilter = 'same';
            _highTypeFilter = 'ANY';
            _lowTypeFilter = 'ANY';
          }
        }),
      ),
    );
  }

  Widget _strategyRuleDropdown() {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        value: _strategyRuleName,
        dropdownColor: const Color(0xFF20242E),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: _dropdownDecoration('strategy rule'),
        items: [for (final value in _strategyRules) DropdownMenuItem(value: value, child: Text(value))],
        onChanged: (v) => setState(() {
          _strategyRuleName = v ?? _strategyRules.first;
          _selectedIndex = 0;
        }),
      ),
    );
  }

  Widget _pairDropdown() {
    final pairs = _pairs;
    if (pairs.isEmpty) return _chip('pair', 'none', false);
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<int>(
        value: _pairIndex.clamp(0, pairs.length - 1).toInt(),
        dropdownColor: const Color(0xFF20242E),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: _dropdownDecoration('level pair'),
        items: [for (var i = 0; i < pairs.length; i++) DropdownMenuItem(value: i, child: Text(pairs[i].label))],
        onChanged: (v) => setState(() {
          _pairIndex = v ?? 0;
          _selectedIndex = 0;
          _highTypeFilter = 'ANY';
          _lowTypeFilter = 'ANY';
        }),
      ),
    );
  }

  Widget _directionDropdown() {
    const values = ['all', 'same', 'buy', 'sell', 'mixed'];
    return SizedBox(
      width: 116,
      child: DropdownButtonFormField<String>(
        value: _directionFilter,
        dropdownColor: const Color(0xFF20242E),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: _dropdownDecoration('direction'),
        items: [for (final value in values) DropdownMenuItem(value: value, child: Text(value))],
        onChanged: (v) => setState(() {
          _directionFilter = v ?? 'same';
          _selectedIndex = 0;
        }),
      ),
    );
  }

  Widget _typeDropdown(String label, String value, List<String> values, ValueChanged<String> onChanged) {
    return SizedBox(
      width: 126,
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: const Color(0xFF20242E),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: _dropdownDecoration(label),
        items: [for (final item in values) DropdownMenuItem(value: item, child: Text(item))],
        onChanged: (v) {
          if (v != null) {
            onChanged(v);
            _selectedIndex = 0;
          }
        },
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 10),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFF1C2330),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white24),
      ),
    );
  }

  List<_SignalMatch> _buildSignals(_LevelPair? pair) {
    if (pair == null) return const [];
    final high = widget.snapshot.of(pair.parentLevel);
    final low = widget.snapshot.of(pair.childLevel);
    if (high == null || low == null || high.bsps.isEmpty || low.bsps.isEmpty) return const [];

    final result = <_SignalMatch>[];
    for (final highBsp in high.bsps.where(_matchesHighFilter)) {
      final relations = widget.snapshot.relationsForParentRange(
        parentLevel: pair.parentLevel,
        childLevel: pair.childLevel,
        startParentRawIndex: highBsp.rawIndex,
        endParentRawIndex: highBsp.rawIndex,
      );
      if (relations.isEmpty) continue;
      final childStart = relations.map((r) => r.childStartRawIndex).reduce((a, b) => a < b ? a : b);
      final childEnd = relations.map((r) => r.childEndRawIndex).reduce((a, b) => a > b ? a : b);
      for (final lowBsp in low.bsps.where((b) => _matchesLowFilter(b, highBsp, childStart, childEnd))) {
        final relation = _relationContaining(relations, lowBsp.rawIndex) ?? relations.first;
        final state = highBsp.confirmed && lowBsp.confirmed ? SignalVisibilityState.confirmed : SignalVisibilityState.candidate;
        final direction = _directionOfPair(highBsp, lowBsp);
        final signal = IntervalNestSignal(
          direction: direction,
          highLevel: pair.parentLevel,
          lowLevel: pair.childLevel,
          highPattern: highBsp.type,
          lowTrigger: lowBsp.type,
          highRawIndex: highBsp.rawIndex,
          lowRawIndex: lowBsp.rawIndex,
          score: _scoreFor(state),
          state: state,
          reasons: [
            'high level BSP is from original chan.py output',
            'low level BSP is from original chan.py output',
            'high-low range is bound by native LevelRelation',
            _isStrategyMode ? 'strategy_interval_nest_buy matched $_strategyRuleName' : 'validation mode accepts arbitrary BSP type combinations',
          ],
          warnings: [
            _isScanMode ? 'Scan snapshot candidate only; verify in strict step before formal step acceptance' : 'Visible in current strict step frame',
            _isStrategyMode ? 'Strategy rule is a candidate signal only; not a trading recommendation' : 'Validation mode only; not a trading plan',
          ],
          observedAtCursor: _isScanMode ? null : widget.frameIndex,
          confirmedAtCursor: !_isScanMode && state == SignalVisibilityState.confirmed ? widget.frameIndex : null,
          meta: {
            'rule_mode': _signalRuleMode,
            'strategy_rule_name': _isStrategyMode ? _strategyRuleName : '',
            'high_strategy_type': _isStrategyMode ? _highStrategyType : '',
            'low_trigger_type': _isStrategyMode ? _lowTriggerType : '',
            'direction_filter': _effectiveDirectionFilter,
            'high_type_filter': _isStrategyMode ? 'strategy_rule' : _highTypeFilter,
            'low_type_filter': _isStrategyMode ? 'strategy_rule' : _lowTypeFilter,
            'relation_source': 'native chan_parent_child LevelRelation',
            'parent_relation_range': '${relation.parentRawIndex}-${relation.parentRawIndex}',
            'child_relation_range': '${relation.childStartRawIndex}-${relation.childEndRawIndex}',
            'child_union_range': '$childStart-$childEnd',
            'high_bsp_index': highBsp.index,
            'low_bsp_index': lowBsp.index,
            'high_bsp_type': highBsp.type,
            'low_bsp_type': lowBsp.type,
          },
        );
        result.add(_SignalMatch(
          signal: signal,
          highBsp: highBsp,
          lowBsp: lowBsp,
          parentRelation: relation,
          relationCount: relations.length,
          childStartRawIndex: childStart,
          childEndRawIndex: childEnd,
        ));
      }
    }
    result.sort((a, b) {
      final byHigh = a.signal.highRawIndex.compareTo(b.signal.highRawIndex);
      if (byHigh != 0) return byHigh;
      return (a.signal.lowRawIndex ?? 0).compareTo(b.signal.lowRawIndex ?? 0);
    });
    return result;
  }

  bool _matchesHighFilter(BspPoint point) {
    if (_isStrategyMode) return _strategyHighTypes.contains(point.type);
    if (_highTypeFilter != 'ANY' && point.type != _highTypeFilter) return false;
    if (_directionFilter == 'buy') return point.isBuy;
    if (_directionFilter == 'sell') return point.isSell;
    return true;
  }

  bool _matchesLowFilter(BspPoint lowPoint, BspPoint highPoint, int childStart, int childEnd) {
    if (lowPoint.rawIndex < childStart || lowPoint.rawIndex > childEnd) return false;
    if (_isStrategyMode) return _strategyHighTypes.contains(highPoint.type) && _strategyLowTypes.contains(lowPoint.type);
    if (_lowTypeFilter != 'ANY' && lowPoint.type != _lowTypeFilter) return false;
    return _matchesDirectionPair(highPoint, lowPoint);
  }

  Set<String> get _strategyHighTypes {
    if (_strategyRuleName == 'DAILY_2B_MIN30_1B') return const {'B2', 'B2s'};
    return const {'B3', 'B3s'};
  }

  Set<String> get _strategyLowTypes {
    if (_strategyRuleName == 'DAILY_3B_MIN30_2B') return const {'B2', 'B2s'};
    return const {'B1'};
  }

  String get _highStrategyType => _strategyRuleName.contains('_2B_') ? '2-buy' : '3-buy';
  String get _lowTriggerType => _strategyRuleName.endsWith('_2B') ? '2-buy' : '1-buy';

  bool _matchesDirectionPair(BspPoint highPoint, BspPoint lowPoint) {
    if (_directionFilter == 'all') return true;
    if (_directionFilter == 'buy') return highPoint.isBuy && lowPoint.isBuy;
    if (_directionFilter == 'sell') return highPoint.isSell && lowPoint.isSell;
    if (_directionFilter == 'same') {
      return (highPoint.isBuy && lowPoint.isBuy) || (highPoint.isSell && lowPoint.isSell);
    }
    if (_directionFilter == 'mixed') {
      return (highPoint.isBuy && lowPoint.isSell) || (highPoint.isSell && lowPoint.isBuy);
    }
    return true;
  }

  String _directionOfPair(BspPoint highPoint, BspPoint lowPoint) {
    if (highPoint.isBuy && lowPoint.isBuy) return 'buy';
    if (highPoint.isSell && lowPoint.isSell) return 'sell';
    if (highPoint.isBuy && lowPoint.isSell) return 'mixed_buy_sell';
    if (highPoint.isSell && lowPoint.isBuy) return 'mixed_sell_buy';
    return 'unknown';
  }

  double _scoreFor(SignalVisibilityState state) {
    final base = state == SignalVisibilityState.confirmed ? 1.0 : 0.5;
    return _isStrategyMode ? base + 0.25 : base;
  }

  LevelRelation? _relationContaining(List<LevelRelation> relations, int childRawIndex) {
    for (final relation in relations) {
      if (childRawIndex >= relation.childStartRawIndex && childRawIndex <= relation.childEndRawIndex) return relation;
    }
    return null;
  }

  void _setSelected(int next, int total) {
    if (total <= 0) return;
    setState(() => _selectedIndex = next.clamp(0, total - 1).toInt());
  }

  String _copyS1EvidenceText(_LevelPair? pair, List<_SignalMatch> signals, _SignalMatch? selected) {
    final log = _timeLog ?? const <String, dynamic>{};
    return [
      'manual S1 evidence diagnostics',
      'button: Copy S1 Evidence',
      's1_phase: strategy_mode_runtime_acceptance',
      'open_questions: none',
      'sample_data_supervisor_decision: accepted_for_this_S1_request',
      'sample_data_used: false',
      'evidence_payload: time_log + p0 + step + result_validation + signal',
      'rule_mode_ui: $_ruleMode',
      'signal_rule_mode: $_signalRuleMode',
      'strategy_rule_name: ${_isStrategyMode ? _strategyRuleName : ''}',
      ..._runtimePathLines(log),
      'runtime_acceptance_path: high_speed_only',
      'fallback_to_bridge: ${log['fallback_to_bridge'] ?? widget.snapshot.meta['fallback_to_bridge'] ?? false}',
      'native_cchan_lv_list: ${log['native_cchan_lv_list'] ?? widget.snapshot.meta['native_cchan_lv_list'] ?? ''}',
      'frame_source: ${_isScanMode ? 'scan_snapshot' : 'native_step_frame'}',
      'final_snapshot_rendered_as_step: false',
      'strategy_traceability_required: source_bsp_identifiers,source_target_levels,native_relation_range,strict_step_visibility,state,rule_mode_name',
      'status: pending_runtime_acceptance',
      '',
      '--- Copy Time Log ---',
      _copyTimeLogText(),
      '',
      '--- Copy P0 Summary ---',
      _copyP0SummaryText(pair, signals),
      '',
      '--- Copy Step Summary ---',
      _copyStepSummaryText(pair),
      '',
      '--- Copy Result Validation ---',
      _copyResultValidationText(pair, signals),
      '',
      '--- Copy Signal ---',
      _copySignalText(pair, signals, selected),
    ].join('\n');
  }

  String _copyP0SummaryText(_LevelPair? pair, List<_SignalMatch> signals) {
    final log = _timeLog ?? const <String, dynamic>{};
    return [
      'manual P0 diagnostics',
      'button: Copy S1 Evidence/P0 Summary',
      'copy_p0_visible: true',
      ..._runtimePathLines(log),
      'symbol: ${log['symbol'] ?? widget.symbol}',
      'market: ${log['market'] ?? ''}',
      'levels: ${_formatList(log['levels'].toString().isEmpty ? widget.snapshot.levels : log['levels'])}',
      'selected_pair: ${pair?.label ?? ''}',
      'native_cchan_lv_list: ${log['native_cchan_lv_list'] ?? widget.snapshot.meta['native_cchan_lv_list'] ?? ''}',
      'level_relation_mode: ${widget.snapshot.meta['level_relation_mode'] ?? log['level_relation_mode'] ?? 'chan_parent_child'}',
      'fallback_to_bridge: ${log['fallback_to_bridge'] ?? widget.snapshot.meta['fallback_to_bridge'] ?? false}',
      'python_runtime: ${log['python_runtime'] ?? ''}',
      'relations.length: ${widget.snapshot.relations.length}',
      'signals.length.current_rule: ${signals.length}',
      'status: ok',
    ].join('\n');
  }

  String _copyStepSummaryText(_LevelPair? pair) {
    final log = _timeLog ?? const <String, dynamic>{};
    return [
      'manual step diagnostics',
      'button: Copy S1 Evidence/Step Summary',
      'frame_source: ${_isScanMode ? 'scan_snapshot' : 'native_step_frame'}',
      'final_snapshot_rendered_as_step: false',
      'mode: ${widget.mode}',
      'symbol: ${log['symbol'] ?? widget.symbol}',
      'market: ${log['market'] ?? ''}',
      'levels: ${_formatList(log['levels'].toString().isEmpty ? widget.snapshot.levels : log['levels'])}',
      'selected_pair: ${pair?.label ?? ''}',
      ..._runtimePathLines(log),
      'frame.index.local: ${widget.frameIndex ?? ''}',
      'frame.count.local: ${widget.frameCount ?? ''}',
      'native_cchan_lv_list: ${log['native_cchan_lv_list'] ?? ''}',
      'fallback_to_bridge: ${log['fallback_to_bridge'] ?? false}',
      'step_frame_format: ${_compactMeta('step_frame_format', log)}',
      'frames_total: ${_compactMeta('frames_total', log)}',
      'frames_returned: ${_compactMeta('frames_returned', log)}',
      'compact_validation_status: ${_compactMeta('compact_validation_status', log)}',
      'compact_validation_mismatch_count: ${_compactMeta('compact_validation_mismatch_count', log)}',
      'status: ok',
    ].join('\n');
  }

  String _copySignalText(_LevelPair? pair, List<_SignalMatch> signals, _SignalMatch? selected) {
    final availablePairs = _pairs.map((p) => p.label).join(',');
    if (pair == null) {
      return [
        'manual interval signal diagnostics',
        'button: Copy Signal',
        'mode: ${widget.mode}',
        'symbol: ${widget.symbol}',
        ..._runtimePathLines(_timeLog),
        'signal_rule_mode: $_signalRuleMode',
        'rule_mode_ui: $_ruleMode',
        'available_pairs: $availablePairs',
        'status: no available native relation pair',
      ].join('\n');
    }
    final high = widget.snapshot.of(pair.parentLevel);
    final low = widget.snapshot.of(pair.childLevel);
    final highBsps = high?.bsps ?? const <BspPoint>[];
    final lowBsps = low?.bsps ?? const <BspPoint>[];
    final relationCount = widget.snapshot.relations.where((r) => r.parentLevel == pair.parentLevel && r.childLevel == pair.childLevel).length;

    if (selected == null) {
      return [
        ..._copyHeader(pair, availablePairs),
        'available_signals: 0',
        'source_bsp_identifiers: none',
        'source_levels: ${pair.parentLevel},${pair.childLevel}',
        'target_levels: ${pair.parentLevel}->${pair.childLevel}',
        'high_bsp_count: ${highBsps.length}',
        'high_buy_count: ${highBsps.where((b) => b.isBuy).length}',
        'high_sell_count: ${highBsps.where((b) => b.isSell).length}',
        'high_type_counts: ${_typeCounts(highBsps)}',
        'low_bsp_count: ${lowBsps.length}',
        'low_buy_count: ${lowBsps.where((b) => b.isBuy).length}',
        'low_sell_count: ${lowBsps.where((b) => b.isSell).length}',
        'low_type_counts: ${_typeCounts(lowBsps)}',
        'native_relation_count_for_pair: $relationCount',
        'candidate_rule: ${_candidateRuleText}',
        'source_policy: original chan.py BSP + native LevelRelation only',
        'strategy_caveat: ${_strategyCaveat}',
        'future_function_policy: ${_futurePolicy}',
        'diagnosis: no candidate matched current ${_isStrategyMode ? 'strategy rule' : 'custom validation filters'} in this ${_isScanMode ? 'scan snapshot' : 'step frame'}',
        'status: no signal for current rule scope',
      ].join('\n');
    }

    final signal = selected.signal;
    return [
      ..._copyHeader(pair, availablePairs),
      'available_signals: ${signals.length}',
      'selected_signal.local: ${_selectedIndex + 1}',
      'source_bsp_identifiers: high=${pair.parentLevel}#${selected.highBsp.index}:raw=${selected.highBsp.rawIndex}:type=${selected.highBsp.type};low=${pair.childLevel}#${selected.lowBsp.index}:raw=${selected.lowBsp.rawIndex}:type=${selected.lowBsp.type}',
      'source_levels: ${pair.parentLevel},${pair.childLevel}',
      'target_levels: ${pair.parentLevel}->${pair.childLevel}',
      'direction: ${signal.direction}',
      'signal_state: ${signal.state.wireName}',
      'state: ${signal.state.wireName}',
      'score: ${signal.score}',
      'strict_step_verified: ${_isScanMode ? 'false' : 'true'}',
      'high_level: ${signal.highLevel}',
      'high_strategy_type: ${_isStrategyMode ? _highStrategyType : ''}',
      'high_pattern: ${signal.highPattern}',
      'high_bsp_index: ${selected.highBsp.index}',
      'high_bsp_type: ${selected.highBsp.type}',
      'high_raw_index: ${selected.highBsp.rawIndex}',
      'high_time: ${selected.highBsp.time ?? ''}',
      'high_price: ${selected.highBsp.price}',
      'high_confirmed: ${selected.highBsp.confirmed}',
      'high_bi_index: ${selected.highBsp.biIndex ?? ''}',
      'high_seg_index: ${selected.highBsp.segIndex ?? ''}',
      'high_zs_index: ${selected.highBsp.zsIndex ?? ''}',
      'low_level: ${signal.lowLevel}',
      'low_trigger_type: ${_isStrategyMode ? _lowTriggerType : ''}',
      'low_trigger: ${signal.lowTrigger}',
      'low_bsp_index: ${selected.lowBsp.index}',
      'low_bsp_type: ${selected.lowBsp.type}',
      'low_raw_index: ${selected.lowBsp.rawIndex}',
      'low_time: ${selected.lowBsp.time ?? ''}',
      'low_price: ${selected.lowBsp.price}',
      'low_confirmed: ${selected.lowBsp.confirmed}',
      'low_bi_index: ${selected.lowBsp.biIndex ?? ''}',
      'low_seg_index: ${selected.lowBsp.segIndex ?? ''}',
      'low_zs_index: ${selected.lowBsp.zsIndex ?? ''}',
      'parent_relation_range: ${selected.parentRelation.parentRawIndex}-${selected.parentRelation.parentRawIndex}',
      'child_relation_range: ${selected.parentRelation.childStartRawIndex}-${selected.parentRelation.childEndRawIndex}',
      'child_union_range: ${selected.childStartRawIndex}-${selected.childEndRawIndex}',
      'low_in_child_range: ${selected.lowBsp.rawIndex >= selected.childStartRawIndex && selected.lowBsp.rawIndex <= selected.childEndRawIndex}',
      'relation_count_for_parent: ${selected.relationCount}',
      'native_relation_count_for_pair: $relationCount',
      'visibleAt.frame: ${signal.observedAtCursor ?? ''}',
      'confirmedAt.frame: ${signal.confirmedAtCursor ?? ''}',
      'invalidatedAt.frame: ${signal.invalidatedAtCursor ?? ''}',
      'invalidation_reason: ',
      'source_policy: original chan.py BSP + native LevelRelation only',
      'future_function_policy: ${_futurePolicy}',
      'candidate_rule: ${_candidateRuleText}',
      'strategy_caveat: ${_strategyCaveat}',
      'reasons: ${signal.reasons.join(' | ')}',
      'warnings: ${signal.warnings.join(' | ')}',
      'status: ok',
    ].join('\n');
  }

  String _copyTimeLogText() {
    final log = _timeLog;
    if (log == null) {
      return [
        'time log diagnostics',
        'button: Copy Time Log',
        'time_log_context: interval_signal_panel',
        'rule_mode_ui: $_ruleMode',
        'signal_rule_mode: $_signalRuleMode',
        ..._runtimePathLines(null),
        'status: missing time_log in snapshot.meta',
      ].join('\n');
    }
    final pair = _selectedPair;
    final stages = _stageMap(log['stages']);
    final slow = stages.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [
      'time log diagnostics',
      'button: Copy Time Log',
      'time_log_context: interval_signal_panel',
      'rule_mode_ui: $_ruleMode',
      'signal_rule_mode: $_signalRuleMode',
      'strategy_rule_name: ${_isStrategyMode ? _strategyRuleName : ''}',
      'strategy_high_type: ${_isStrategyMode ? _highStrategyType : ''}',
      'strategy_low_trigger_type: ${_isStrategyMode ? _lowTriggerType : ''}',
      ..._runtimePathLines(log),
      'selected_pair: ${pair?.label ?? ''}',
      'frame.index.local: ${widget.frameIndex ?? ''}',
      'frame.count.local: ${widget.frameCount ?? ''}',
      'backend_request_mode: ${log['mode'] ?? widget.mode}',
      'trace_id: ${log['trace_id'] ?? ''}',
      'mode: ${_isStrategyMode ? 'strategy' : widget.mode}',
      'symbol: ${log['symbol'] ?? widget.symbol}',
      'market: ${log['market'] ?? ''}',
      'levels: ${_formatList(log['levels'])}',
      'count: ${log['count'] ?? ''}',
      'max_step_frames: ${log['max_step_frames'] ?? ''}',
      'start: ${log['start'] ?? ''}',
      'end: ${log['end'] ?? ''}',
      'backend_url: ${log['backend_url'] ?? ''}',
      'python_runtime: ${log['python_runtime'] ?? ''}',
      'process_source: ${log['process_source'] ?? ''}',
      'backend_process_pid: ${log['backend_process_pid'] ?? ''}',
      'backend_process_start_count: ${log['backend_process_start_count'] ?? ''}',
      'backend_process_started_at: ${log['backend_process_started_at'] ?? ''}',
      'backend_process_ready_at: ${log['backend_process_ready_at'] ?? ''}',
      'backend_process_uptime_ms: ${log['backend_process_uptime_ms'] ?? ''}',
      'backend_startup_elapsed_ms: ${log['backend_startup_elapsed_ms'] ?? ''}',
      'backend_last_health_check_elapsed_ms: ${log['backend_last_health_check_elapsed_ms'] ?? ''}',
      'backend_health_check_count: ${log['backend_health_check_count'] ?? ''}',
      'backend_request_count: ${log['backend_request_count'] ?? ''}',
      'backend_last_request_reused: ${log['backend_last_request_reused'] ?? ''}',
      'backend_last_ready_elapsed_ms: ${log['backend_last_ready_elapsed_ms'] ?? ''}',
      'used_app_bundled_python: ${log['used_app_bundled_python'] ?? ''}',
      'native_cchan_lv_list: ${log['native_cchan_lv_list'] ?? ''}',
      'fallback_to_bridge: ${log['fallback_to_bridge'] ?? ''}',
      'step_frame_format: ${_compactMeta('step_frame_format', log)}',
      'frame_policy: ${_compactMeta('frame_policy', log)}',
      'frame_stride: ${_compactMeta('frame_stride', log)}',
      'frames_total: ${_compactMeta('frames_total', log)}',
      'frames_returned: ${_compactMeta('frames_returned', log)}',
      'frames_truncated: ${_compactMeta('frames_truncated', log)}',
      'include_bars_in_frames: ${_compactMeta('include_bars_in_frames', log)}',
      'include_indicators_in_frames: ${_compactMeta('include_indicators_in_frames', log)}',
      'response_bytes: ${log['response_bytes'] ?? ''}',
      'raw_frame_count: ${log['raw_frame_count'] ?? ''}',
      'parsed_frame_count: ${log['parsed_frame_count'] ?? ''}',
      'parsed_level_count: ${log['parsed_level_count'] ?? ''}',
      'lazy_frame_parsing: ${log['lazy_frame_parsing'] ?? ''}',
      'lazy_frame_cache_hits: ${log['lazy_frame_cache_hits'] ?? ''}',
      'lazy_frame_cache_misses: ${log['lazy_frame_cache_misses'] ?? ''}',
      'lazy_frame_parse_ms: ${log['lazy_frame_parse_ms'] ?? ''}',
      'lazy_frame_last_index: ${log['lazy_frame_last_index'] ?? ''}',
      'lazy_frame_last_parse_ms: ${log['lazy_frame_last_parse_ms'] ?? ''}',
      'total_elapsed_ms: ${log['total_elapsed_ms'] ?? ''}',
      'backend_elapsed_ms: ${log['backend_elapsed_ms'] ?? ''}',
      'frontend_elapsed_ms: ${log['frontend_elapsed_ms'] ?? ''}',
      'slowest_stages:',
      for (var i = 0; i < slow.length && i < 10; i++) '${i + 1}. ${slow[i].key}: ${slow[i].value}ms',
      'stages:',
      for (final entry in stages.entries) '${entry.key}: ${entry.value}ms',
      'status: ${log['status'] ?? 'ok'}',
    ].join('\n');
  }

  String _copyResultValidationText(_LevelPair? pair, List<_SignalMatch> signals) {
    final log = _timeLog ?? const <String, dynamic>{};
    final requestMode = log['mode'] ?? widget.mode;
    final levels = widget.snapshot.levels;
    final relationCountForPair = pair == null
        ? 0
        : widget.snapshot.relations.where((r) => r.parentLevel == pair.parentLevel && r.childLevel == pair.childLevel).length;
    final compactStatus = _compactMetaText('compact_validation_status', log);
    final hasCompactValidation = compactStatus.isNotEmpty;
    final compactScope = _compactMetaText('compact_validation_scope', log);
    final compactMismatchCount = _compactMetaText('compact_validation_mismatch_count', log);
    final compactFirstMismatch = _compactMetaText('compact_validation_first_mismatch', log);
    final finalStatus = hasCompactValidation ? (compactStatus == 'match' ? 'ok' : 'mismatch') : 'blocked';
    return [
      'result validation diagnostics',
      'button: Copy Result Validation',
      'validation_phase: ${hasCompactValidation ? 'F1a' : 'F0'}',
      'validation_scope: ${hasCompactValidation ? compactScope : 'baseline_vs_fast_candidate'}',
      'baseline_source: original chan.py analyze_multi',
      'fast_candidate_enabled: false',
      'fast_candidate_source: ',
      'compact_candidate_enabled: $hasCompactValidation',
      'compact_candidate_source: ${hasCompactValidation ? 'compact_v1 transport adapter' : ''}',
      'validation_status: ${hasCompactValidation ? compactStatus : 'blocked'}',
      'blocked_reason: ${hasCompactValidation ? '' : 'no fast candidate mode/cache/compact payload configured'}',
      'mismatch_count: ${hasCompactValidation ? compactMismatchCount : ''}',
      'first_mismatch: ${hasCompactValidation ? compactFirstMismatch : ''}',
      ..._runtimePathLines(log),
      'request.mode: $requestMode',
      'request.symbol: ${log['symbol'] ?? widget.symbol}',
      'request.market: ${log['market'] ?? ''}',
      'request.levels: ${_formatList(log['levels'])}',
      'request.count: ${log['count'] ?? ''}',
      'request.max_step_frames: ${log['max_step_frames'] ?? ''}',
      'request.start: ${log['start'] ?? ''}',
      'request.end: ${log['end'] ?? ''}',
      'ui.context: interval_signal_panel',
      'rule_mode_ui: $_ruleMode',
      'signal_rule_mode: $_signalRuleMode',
      'strategy_rule_name: ${_isStrategyMode ? _strategyRuleName : ''}',
      'selected_pair: ${pair?.label ?? ''}',
      'frame.index.local: ${widget.frameIndex ?? ''}',
      'frame.count.local: ${widget.frameCount ?? ''}',
      'step_frame_format: ${_compactMeta('step_frame_format', log)}',
      'frame_policy: ${_compactMeta('frame_policy', log)}',
      'frame_stride: ${_compactMeta('frame_stride', log)}',
      'frames_total: ${_compactMeta('frames_total', log)}',
      'frames_returned: ${_compactMeta('frames_returned', log)}',
      'frames_truncated: ${_compactMeta('frames_truncated', log)}',
      'include_bars_in_frames: ${_compactMeta('include_bars_in_frames', log)}',
      'include_indicators_in_frames: ${_compactMeta('include_indicators_in_frames', log)}',
      'compact_validation_scope: $compactScope',
      'compact_validation_status: $compactStatus',
      'compact_validation_mismatch_count: $compactMismatchCount',
      'compact_validation_first_mismatch: $compactFirstMismatch',
      'baseline.main_level: ${widget.snapshot.mainLevel}',
      'baseline.levels: ${levels.join(',')}',
      'baseline.level_count: ${levels.length}',
      'baseline.relation_count.total: ${widget.snapshot.relations.length}',
      'baseline.relation_count.selected_pair: $relationCountForPair',
      'baseline.signal_count.current_rule: ${signals.length}',
      'baseline.level_counts:',
      for (final level in levels) _levelCountsLine(level),
      'baseline.sample_bsp:',
      for (final level in levels) _sampleBspLine(level),
      'baseline.sample_relation:',
      _sampleRelationLine(pair),
      'acceptance_policy: no speed mode may be accepted until validation_status=match for the same request; compact transport match does not accept algorithmic speed mode',
      'status: $finalStatus',
    ].join('\n');
  }

  String _levelCountsLine(String level) {
    final s = widget.snapshot.of(level);
    if (s == null) return '$level: missing';
    return '$level: raw=${s.rawBars.length},k=${s.mergedBars.length},fx=${s.fxs.length},bi=${s.bis.length},seg=${s.segs.length},zs=${s.zss.length},bsp=${s.bsps.length}';
  }

  String _sampleBspLine(String level) {
    final s = widget.snapshot.of(level);
    if (s == null || s.bsps.isEmpty) return '$level: none';
    final sample = s.bsps.take(3).map((b) => '#${b.index}:${b.type}:raw=${b.rawIndex}:time=${b.time ?? ''}').join(' | ');
    return '$level: $sample';
  }

  String _sampleRelationLine(_LevelPair? pair) {
    final relations = pair == null
        ? widget.snapshot.relations.take(3).toList()
        : widget.snapshot.relations.where((r) => r.parentLevel == pair.parentLevel && r.childLevel == pair.childLevel).take(3).toList();
    if (relations.isEmpty) return 'none';
    return relations.map((r) => '${r.parentLevel}->${r.childLevel}:parent=${r.parentRawIndex}:child=${r.childStartRawIndex}-${r.childEndRawIndex}').join(' | ');
  }

  Map<String, int> _stageMap(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, int>{};
    for (final entry in raw.entries) {
      final key = '${entry.key}';
      if (key == 'frontend.response_bytes' || key.endsWith('.response_bytes')) continue;
      final value = entry.value;
      if (value is int) {
        result[key] = value;
      } else if (value is num) {
        result[key] = value.toInt();
      } else {
        final parsed = int.tryParse('$value');
        if (parsed != null) result[key] = parsed;
      }
    }
    return result;
  }

  String _formatList(Object? raw) {
    if (raw is Iterable) return raw.map((e) => '$e').join(',');
    return '${raw ?? ''}';
  }

  List<String> _copyHeader(_LevelPair pair, String availablePairs) {
    return [
      'manual interval signal diagnostics',
      'button: Copy Signal',
      'mode: ${widget.mode}',
      'symbol: ${widget.symbol}',
      ..._runtimePathLines(_timeLog),
      'frame.index.local: ${widget.frameIndex ?? ''}',
      'frame.count.local: ${widget.frameCount ?? ''}',
      'signal_source: original chan.py BSP + native LevelRelation',
      'signal_rule_mode: $_signalRuleMode',
      'rule_mode_ui: $_ruleMode',
      'strategy_rule_name: ${_isStrategyMode ? _strategyRuleName : ''}',
      'strategy_high_type: ${_isStrategyMode ? _highStrategyType : ''}',
      'strategy_low_trigger_type: ${_isStrategyMode ? _lowTriggerType : ''}',
      'signal_scope: ${_isStrategyMode ? 'strategy DAILY->MIN30 interval-nest buy' : 'arbitrary adjacent native relation pair'}',
      'scan_candidate_only: ${_isScanMode ? 'true' : 'false'}',
      'strict_step_frame_mode: ${_isScanMode ? 'false' : 'true'}',
      'available_pairs: $availablePairs',
      'selected_pair: ${pair.label}',
      'parent_level: ${pair.parentLevel}',
      'child_level: ${pair.childLevel}',
      'direction_filter: $_effectiveDirectionFilter',
      'high_type_filter: ${_isStrategyMode ? _strategyHighTypes.join('/') : _highTypeFilter}',
      'low_type_filter: ${_isStrategyMode ? _strategyLowTypes.join('/') : _lowTypeFilter}',
    ];
  }

  String get _futurePolicy => _isScanMode
      ? 'scan snapshot only; must be verified by strict step before step acceptance'
      : 'current strict step frame only; no final snapshot signal confirmation';

  String get _candidateRuleText => _isStrategyMode
      ? '$_strategyRuleName: $_highStrategyType at DAILY + $_lowTriggerType at MIN30; low trigger BSP must be inside native child range'
      : 'high BSP at parent level + low BSP inside native child range; arbitrary BSP type combination';

  String get _strategyCaveat => _isStrategyMode
      ? 'strategy signal candidate only; not a trading recommendation; requires backtest, risk policy, and execution rules'
      : 'validation mode only; not a trading recommendation';

  String _typeCounts(List<BspPoint> points) {
    final counts = <String, int>{};
    for (final point in points) {
      counts[point.type] = (counts[point.type] ?? 0) + 1;
    }
    return counts.entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  Widget _smallButton(String label, VoidCallback? onPressed) {
    return OutlinedButton(onPressed: onPressed, style: _buttonStyle(), child: Text(label));
  }

  ButtonStyle _buttonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF8AB4FF),
      side: const BorderSide(color: Color(0x668AB4FF)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    );
  }

  Widget _chip(String label, String value, bool ok) {
    final color = ok ? const Color(0xFF66BB6A) : const Color(0xFFFFB74D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text('$label: $value', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _LevelPair {
  final String parentLevel;
  final String childLevel;

  const _LevelPair(this.parentLevel, this.childLevel);

  String get label => '$parentLevel->$childLevel';
}

class _SignalMatch {
  final IntervalNestSignal signal;
  final BspPoint highBsp;
  final BspPoint lowBsp;
  final LevelRelation parentRelation;
  final int relationCount;
  final int childStartRawIndex;
  final int childEndRawIndex;

  const _SignalMatch({
    required this.signal,
    required this.highBsp,
    required this.lowBsp,
    required this.parentRelation,
    required this.relationCount,
    required this.childStartRawIndex,
    required this.childEndRawIndex,
  });
}
