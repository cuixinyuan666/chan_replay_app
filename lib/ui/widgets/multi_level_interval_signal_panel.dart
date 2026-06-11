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
          _chip('source', 'chan.py BSP + native relation', true),
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
        items: [
          for (final value in values) DropdownMenuItem(value: value, child: Text(value)),
        ],
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
        items: [
          for (final value in _strategyRules) DropdownMenuItem(value: value, child: Text(value)),
        ],
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
        items: [
          for (var i = 0; i < pairs.length; i++) DropdownMenuItem(value: i, child: Text(pairs[i].label)),
        ],
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
        items: [
          for (final value in values) DropdownMenuItem(value: value, child: Text(value)),
        ],
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
        items: [
          for (final item in values) DropdownMenuItem(value: item, child: Text(item)),
        ],
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
        final state = highBsp.confirmed && lowBsp.confirmed
            ? SignalVisibilityState.confirmed
            : SignalVisibilityState.candidate;
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
            _isStrategyMode
                ? 'strategy_interval_nest_buy matched $_strategyRuleName'
                : 'validation mode accepts arbitrary BSP type combinations',
          ],
          warnings: [
            _isScanMode
                ? 'Scan snapshot candidate only; verify in strict step before formal step acceptance'
                : 'Visible in current strict step frame',
            _isStrategyMode
                ? 'Strategy rule is a candidate signal only; not a trading recommendation'
                : 'Validation mode only; not a trading plan',
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
      if (childRawIndex >= relation.childStartRawIndex && childRawIndex <= relation.childEndRawIndex) {
        return relation;
      }
    }
    return null;
  }

  void _setSelected(int next, int total) {
    if (total <= 0) return;
    setState(() => _selectedIndex = next.clamp(0, total - 1).toInt());
  }

  String _copySignalText(_LevelPair? pair, List<_SignalMatch> signals, _SignalMatch? selected) {
    final availablePairs = _pairs.map((p) => p.label).join(',');
    if (pair == null) {
      return [
        'manual interval signal diagnostics',
        'button: Copy Signal',
        'mode: ${widget.mode}',
        'symbol: ${widget.symbol}',
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
    final relationCount = widget.snapshot.relations
        .where((r) => r.parentLevel == pair.parentLevel && r.childLevel == pair.childLevel)
        .length;

    if (selected == null) {
      return [
        ..._copyHeader(pair, availablePairs),
        'available_signals: 0',
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

  List<String> _copyHeader(_LevelPair pair, String availablePairs) {
    return [
      'manual interval signal diagnostics',
      'button: Copy Signal',
      'mode: ${widget.mode}',
      'symbol: ${widget.symbol}',
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
    return OutlinedButton(
      onPressed: onPressed,
      style: _buttonStyle(),
      child: Text(label),
    );
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
