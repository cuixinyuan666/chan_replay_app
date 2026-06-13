import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/bsp.dart';
import '../../core/models/level_relation.dart';
import '../../core/models/multi_level_chan_snapshot.dart';

class MultiLevelStrategySignalSelection {
  final String ruleModeName;
  final String sourceBspIdentifiers;
  final String sourceTargetLevels;
  final String nativeRelationRange;
  final String strictStepVisibility;
  final String state;
  final String highLevel;
  final String lowLevel;
  final int highRawIndex;
  final int lowRawIndex;
  final double highPrice;
  final double lowPrice;
  final String highTime;
  final String lowTime;

  const MultiLevelStrategySignalSelection({
    required this.ruleModeName,
    required this.sourceBspIdentifiers,
    required this.sourceTargetLevels,
    required this.nativeRelationRange,
    required this.strictStepVisibility,
    required this.state,
    required this.highLevel,
    required this.lowLevel,
    required this.highRawIndex,
    required this.lowRawIndex,
    required this.highPrice,
    required this.lowPrice,
    required this.highTime,
    required this.lowTime,
  });

  String get markerId => 's7_strategy_signal_marker_${ruleModeName}_${highLevel}_${highRawIndex}_${lowLevel}_$lowRawIndex';

  String toEvidenceText() {
    return [
      'rule_mode_name: $ruleModeName',
      'source_bsp_identifiers: $sourceBspIdentifiers',
      'source_target_levels: $sourceTargetLevels',
      'native_relation_range: $nativeRelationRange',
      'strict_step_visibility: $strictStepVisibility',
      'state: $state',
      'high_level: $highLevel',
      'high_raw_index: $highRawIndex',
      'high_time: $highTime',
      'high_price: $highPrice',
      'low_level: $lowLevel',
      'low_raw_index: $lowRawIndex',
      'low_time: $lowTime',
      'low_price: $lowPrice',
      'chart_marker_id: $markerId',
    ].join('\n');
  }
}

class MultiLevelIntervalSignalPanel extends StatefulWidget {
  final MultiLevelChanSnapshot snapshot;
  final String mode;
  final String symbol;
  final int? frameIndex;
  final int? frameCount;
  final ValueChanged<MultiLevelStrategySignalSelection?>? onSelectedSignalChanged;
  final ValueChanged<MultiLevelStrategySignalSelection>? onJumpToSignal;

  const MultiLevelIntervalSignalPanel({
    super.key,
    required this.snapshot,
    required this.mode,
    this.symbol = '',
    this.frameIndex,
    this.frameCount,
    this.onSelectedSignalChanged,
    this.onJumpToSignal,
  });

  @override
  State<MultiLevelIntervalSignalPanel> createState() => _MultiLevelIntervalSignalPanelState();
}

class _MultiLevelIntervalSignalPanelState extends State<MultiLevelIntervalSignalPanel> {
  int _selectedIndex = 0;
  int _pairIndex = 0;
  String _ruleMode = 'strategy';
  String _strategyRuleName = 'DAILY_2B_MIN30_1B';
  String _directionFilter = 'same';
  String _highTypeFilter = 'ANY';
  String _lowTypeFilter = 'ANY';
  String _lastEmittedKey = '';

  bool get _isScanMode => widget.mode == 'signal_scan_once';
  bool get _isStrategyMode => _ruleMode == 'strategy';
  String get _signalRuleMode => _isStrategyMode ? 'strategy_interval_nest_buy' : 'validation_any_bsp_pair';
  String get _ruleChipLabel => _isStrategyMode ? 'strategy interval buy' : 'any BSP pair';

  static const List<String> _strategyRules = [
    'DAILY_2B_MIN30_1B',
    'DAILY_3B_MIN30_1B',
    'DAILY_3B_MIN30_2B',
  ];

  @override
  void didUpdateWidget(covariant MultiLevelIntervalSignalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.snapshot, widget.snapshot) || oldWidget.mode != widget.mode) {
      _selectedIndex = 0;
      _lastEmittedKey = '';
    }
  }

  Map<String, dynamic>? get _timeLog {
    final raw = widget.snapshot.meta['time_log'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String _runtimePath(Map<String, dynamic>? log) {
    final value = '${log?['runtime_path'] ?? widget.snapshot.meta['runtime_path'] ?? 'high_speed'}'.trim();
    return value.isEmpty ? 'high_speed' : value;
  }

  List<String> _runtimePathLines(Map<String, dynamic>? log) {
    final path = _runtimePath(log);
    return [
      'runtime_path: $path',
      'high_speed_enabled: ${path != 'slow_path'}',
      'slow_path_enabled: ${path == 'slow_path'}',
      'runtime_path_default: high_speed',
      'runtime_path_policy: high_speed_default_slow_path_debug_only',
    ];
  }

  Object? _compactMeta(String key, [Map<String, dynamic>? log]) {
    return (log == null ? null : log[key]) ?? widget.snapshot.meta[key] ?? '';
  }

  List<_LevelPair> get _pairs {
    final relationPairs = <String, _LevelPair>{};
    for (final r in widget.snapshot.relations) {
      relationPairs['${r.parentLevel}->${r.childLevel}'] = _LevelPair(r.parentLevel, r.childLevel);
    }
    if (relationPairs.isNotEmpty) return relationPairs.values.toList();
    final levels = widget.snapshot.levels;
    return [for (var i = 0; i < levels.length - 1; i++) _LevelPair(levels[i], levels[i + 1])];
  }

  _LevelPair? get _selectedPair {
    if (_isStrategyMode) return const _LevelPair('DAILY', 'MIN30');
    final pairs = _pairs;
    if (pairs.isEmpty) return null;
    if (_pairIndex >= pairs.length) _pairIndex = pairs.length - 1;
    return pairs[_pairIndex.clamp(0, pairs.length - 1).toInt()];
  }

  @override
  Widget build(BuildContext context) {
    final pair = _selectedPair;
    final signals = _buildSignals(pair);
    if (_selectedIndex >= signals.length) _selectedIndex = signals.isEmpty ? 0 : signals.length - 1;
    final selected = signals.isEmpty ? null : signals[_selectedIndex];
    final selection = selected == null || pair == null ? null : _toSelection(pair, selected);
    _emitSelected(selection);

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
          Text(_isStrategyMode ? 'Interval strategy' : 'Interval validation', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          _chip('rule', _ruleChipLabel, true),
          _chip('source', 'chan.py BSP + native relation', true),
          _chip('runtime_path', _runtimePath(_timeLog), _runtimePath(_timeLog) != 'slow_path'),
          if (pair != null) _chip('pair', pair.label, true),
          _chip('signals', '${signals.length}', signals.isNotEmpty),
          _ruleModeDropdown(),
          if (_isStrategyMode) _strategyRuleDropdown(),
          if (!_isStrategyMode) _pairDropdown(),
          if (!_isStrategyMode) _directionDropdown(),
          if (_isStrategyMode) _chip('high', _highStrategyType, true),
          if (_isStrategyMode) _chip('low', _lowTriggerType, true),
          if (selected != null) _chip('selected', '${_selectedIndex + 1}/${signals.length}', true),
          if (selected != null) _chip('state', selected.state, selected.confirmed),
          if (selected != null) _chip('pattern', '${selected.highBsp.type}->${selected.lowBsp.type}', true),
          _smallButton('Prev', signals.isEmpty ? null : () => _setSelected(_selectedIndex - 1, signals.length)),
          _smallButton('Next', signals.isEmpty ? null : () => _setSelected(_selectedIndex + 1, signals.length)),
          OutlinedButton.icon(
            onPressed: selection == null ? null : () => widget.onJumpToSignal?.call(selection),
            icon: const Icon(Icons.my_location, size: 14),
            label: const Text('Jump 定位'),
            style: _primaryButtonStyle(),
          ),
          OutlinedButton.icon(
            onPressed: () => _copy(context, _copyS1EvidenceText(pair, signals, selected, selection), 'S1/S7 evidence copied'),
            icon: const Icon(Icons.fact_check, size: 15),
            label: const Text('S1一键复制'),
            style: _primaryButtonStyle(),
          ),
          OutlinedButton.icon(
            onPressed: () => _copy(context, _copySignalText(pair, signals, selected, selection), 'Debug signal diagnostics copied'),
            icon: const Icon(Icons.copy, size: 13),
            label: const Text('Debug: Copy Signal'),
            style: _debugButtonStyle(),
          ),
        ],
      ),
    );
  }

  void _emitSelected(MultiLevelStrategySignalSelection? selection) {
    final key = selection?.markerId ?? 'none';
    if (key == _lastEmittedKey) return;
    _lastEmittedKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onSelectedSignalChanged?.call(selection);
    });
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
        result.add(_SignalMatch(highBsp: highBsp, lowBsp: lowBsp, relation: relation, relationCount: relations.length, childStartRawIndex: childStart, childEndRawIndex: childEnd));
      }
    }
    result.sort((a, b) {
      final byHigh = a.highBsp.rawIndex.compareTo(b.highBsp.rawIndex);
      if (byHigh != 0) return byHigh;
      return a.lowBsp.rawIndex.compareTo(b.lowBsp.rawIndex);
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
    if (_directionFilter == 'all') return true;
    if (_directionFilter == 'buy') return highPoint.isBuy && lowPoint.isBuy;
    if (_directionFilter == 'sell') return highPoint.isSell && lowPoint.isSell;
    if (_directionFilter == 'mixed') return (highPoint.isBuy && lowPoint.isSell) || (highPoint.isSell && lowPoint.isBuy);
    return (highPoint.isBuy && lowPoint.isBuy) || (highPoint.isSell && lowPoint.isSell);
  }

  LevelRelation? _relationContaining(List<LevelRelation> relations, int childRawIndex) {
    for (final relation in relations) {
      if (childRawIndex >= relation.childStartRawIndex && childRawIndex <= relation.childEndRawIndex) return relation;
    }
    return null;
  }

  MultiLevelStrategySignalSelection _toSelection(_LevelPair pair, _SignalMatch selected) {
    return MultiLevelStrategySignalSelection(
      ruleModeName: _isStrategyMode ? _strategyRuleName : _signalRuleMode,
      sourceBspIdentifiers: '${pair.parentLevel}#${selected.highBsp.index}:raw=${selected.highBsp.rawIndex}:type=${selected.highBsp.type};${pair.childLevel}#${selected.lowBsp.index}:raw=${selected.lowBsp.rawIndex}:type=${selected.lowBsp.type}',
      sourceTargetLevels: '${pair.parentLevel}->${pair.childLevel}',
      nativeRelationRange: 'parent=${selected.relation.parentRawIndex}:child=${selected.relation.childStartRawIndex}-${selected.relation.childEndRawIndex}',
      strictStepVisibility: _isScanMode ? 'scan once snapshot; not strict step confirmation' : 'current strict step frame only; no final snapshot signal confirmation',
      state: selected.state,
      highLevel: pair.parentLevel,
      lowLevel: pair.childLevel,
      highRawIndex: selected.highBsp.rawIndex,
      lowRawIndex: selected.lowBsp.rawIndex,
      highPrice: selected.highBsp.price,
      lowPrice: selected.lowBsp.price,
      highTime: '${selected.highBsp.time ?? ''}',
      lowTime: '${selected.lowBsp.time ?? ''}',
    );
  }

  void _setSelected(int next, int total) {
    if (total <= 0) return;
    setState(() => _selectedIndex = next.clamp(0, total - 1).toInt());
  }

  String _copyS1EvidenceText(_LevelPair? pair, List<_SignalMatch> signals, _SignalMatch? selected, MultiLevelStrategySignalSelection? selection) {
    return [
      'manual S1/S7 evidence diagnostics',
      'button: S1一键复制',
      's7_phase: app_strategy_signal_display_loop',
      'rule_mode_ui: $_ruleMode',
      'signal_rule_mode: $_signalRuleMode',
      'strategy_rule_name: ${_isStrategyMode ? _strategyRuleName : ''}',
      'strategy_traceability_required: source_bsp_identifiers,source_target_levels,native_relation_range,strict_step_visibility,state,rule_mode_name',
      ..._runtimePathLines(_timeLog),
      'frame_source: ${_isScanMode ? 'scan_snapshot' : 'native_step_frame'}',
      'final_snapshot_rendered_as_step: false',
      'selected_pair: ${pair?.label ?? ''}',
      'available_signals: ${signals.length}',
      'status: ${selection == null ? 'no signal for current rule scope' : 'ok'}',
      if (selection != null) selection.toEvidenceText(),
      '--- Copy Signal ---',
      _copySignalText(pair, signals, selected, selection),
    ].join('\n');
  }

  String _copySignalText(_LevelPair? pair, List<_SignalMatch> signals, _SignalMatch? selected, MultiLevelStrategySignalSelection? selection) {
    if (pair == null || selected == null || selection == null) {
      return [
        'manual interval signal diagnostics',
        'signal_rule_mode: $_signalRuleMode',
        'available_signals: 0',
        'source_bsp_identifiers: none',
        'target_levels: ${pair?.label ?? ''}',
        'source_policy: original chan.py BSP + native LevelRelation only',
        'status: no signal for current rule scope',
      ].join('\n');
    }
    return [
      'manual interval signal diagnostics',
      'signal_rule_mode: $_signalRuleMode',
      'rule_mode_name: ${selection.ruleModeName}',
      'available_signals: ${signals.length}',
      'selected_signal.local: ${_selectedIndex + 1}',
      'source_bsp_identifiers: ${selection.sourceBspIdentifiers}',
      'source_levels: ${pair.parentLevel},${pair.childLevel}',
      'target_levels: ${selection.sourceTargetLevels}',
      'source_target_levels: ${selection.sourceTargetLevels}',
      'native_relation_range: ${selection.nativeRelationRange}',
      'strict_step_visibility: ${selection.strictStepVisibility}',
      'strict_step_verified: ${_isScanMode ? 'false' : 'true'}',
      'state: ${selected.state}',
      'signal_state: ${selected.state}',
      'parent_relation_range: ${selected.relation.parentRawIndex}-${selected.relation.parentRawIndex}',
      'child_relation_range: ${selected.relation.childStartRawIndex}-${selected.relation.childEndRawIndex}',
      'child_union_range: ${selected.childStartRawIndex}-${selected.childEndRawIndex}',
      'relation_count_for_parent: ${selected.relationCount}',
      'visibleAt.frame: ${widget.frameIndex ?? ''}',
      'confirmedAt.frame: ${selected.confirmed ? widget.frameIndex ?? '' : ''}',
      'source_policy: original chan.py BSP + native LevelRelation only',
      'future_function_policy: candidate signal only; not a trading recommendation',
      'warnings: Strategy rule is a candidate signal only; not a trading recommendation',
      'status: ok',
    ].join('\n');
  }

  Future<void> _copy(BuildContext context, String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
    }
  }

  Set<String> get _strategyHighTypes => _strategyRuleName == 'DAILY_2B_MIN30_1B' ? const {'B2', 'B2s'} : const {'B3', 'B3s'};
  Set<String> get _strategyLowTypes => _strategyRuleName == 'DAILY_3B_MIN30_2B' ? const {'B2', 'B2s'} : const {'B1'};
  String get _highStrategyType => _strategyRuleName.contains('_2B_') ? '2-buy' : '3-buy';
  String get _lowTriggerType => _strategyRuleName.endsWith('_2B') ? '2-buy' : '1-buy';

  Widget _ruleModeDropdown() => _dropdown<String>('rule mode', _ruleMode, const ['validation', 'strategy'], (v) {
        setState(() {
          _ruleMode = v ?? 'strategy';
          _selectedIndex = 0;
          _lastEmittedKey = '';
        });
      }, width: 132);

  Widget _strategyRuleDropdown() => _dropdown<String>('strategy rule', _strategyRuleName, _strategyRules, (v) {
        setState(() {
          _strategyRuleName = v ?? _strategyRules.first;
          _selectedIndex = 0;
          _lastEmittedKey = '';
        });
      }, width: 180);

  Widget _pairDropdown() {
    final pairs = _pairs;
    if (pairs.isEmpty) return _chip('pair', 'none', false);
    return _dropdown<int>('level pair', _pairIndex.clamp(0, pairs.length - 1).toInt(), [for (var i = 0; i < pairs.length; i++) i], (v) {
      setState(() {
        _pairIndex = v ?? 0;
        _selectedIndex = 0;
        _lastEmittedKey = '';
      });
    }, width: 150, labelFor: (v) => pairs[v].label);
  }

  Widget _directionDropdown() => _dropdown<String>('direction', _directionFilter, const ['all', 'same', 'buy', 'sell', 'mixed'], (v) {
        setState(() {
          _directionFilter = v ?? 'same';
          _selectedIndex = 0;
          _lastEmittedKey = '';
        });
      }, width: 116);

  Widget _dropdown<T>(String label, T value, List<T> values, ValueChanged<T?> onChanged, {required double width, String Function(T value)? labelFor}) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        value: value,
        dropdownColor: const Color(0xFF20242E),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54, fontSize: 10), isDense: true, filled: true, fillColor: const Color(0xFF1C2330), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24))),
        items: [for (final item in values) DropdownMenuItem<T>(value: item, child: Text(labelFor == null ? '$item' : labelFor(item)))],
        onChanged: onChanged,
      ),
    );
  }

  Widget _smallButton(String text, VoidCallback? onPressed) => OutlinedButton(onPressed: onPressed, style: _debugButtonStyle(), child: Text(text));

  ButtonStyle _primaryButtonStyle() => OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8AB4FF), side: const BorderSide(color: Color(0x668AB4FF)), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700));

  ButtonStyle _debugButtonStyle() => OutlinedButton.styleFrom(foregroundColor: const Color(0xFF9AA0A6), side: const BorderSide(color: Color(0x449AA0A6)), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600));

  Widget _chip(String label, String value, bool ok) {
    final color = ok ? const Color(0xFF66BB6A) : const Color(0xFFFFB74D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.45))),
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
  final BspPoint highBsp;
  final BspPoint lowBsp;
  final LevelRelation relation;
  final int relationCount;
  final int childStartRawIndex;
  final int childEndRawIndex;

  const _SignalMatch({required this.highBsp, required this.lowBsp, required this.relation, required this.relationCount, required this.childStartRawIndex, required this.childEndRawIndex});

  bool get confirmed => highBsp.confirmed && lowBsp.confirmed;
  String get state => confirmed ? 'confirmed' : 'candidate';
}
