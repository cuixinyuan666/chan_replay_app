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

  @override
  Widget build(BuildContext context) {
    final signals = _buildSignals();
    if (_selectedIndex >= signals.length) _selectedIndex = signals.isEmpty ? 0 : signals.length - 1;
    final selected = signals.isEmpty ? null : signals[_selectedIndex];

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
          const Text(
            'Interval signal MVP',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          _chip('source', 'chan.py BSP + native relation', true),
          _chip('scope', 'DAILY->MIN30', true),
          _chip('signals', '${signals.length}', signals.isNotEmpty),
          if (selected != null) _chip('selected', '${_selectedIndex + 1}/${signals.length}', true),
          if (selected != null) _chip('state', selected.signal.state.wireName, selected.signal.state != SignalVisibilityState.invalid),
          if (selected != null) _chip('pattern', '${selected.signal.highPattern}+${selected.signal.lowTrigger}', true),
          if (selected != null) _chip('parent', 'raw:${selected.parentRelation.parentRawIndex}', true),
          if (selected != null) _chip('child', 'raw:${selected.lowBsp.rawIndex}', true),
          _smallButton('Prev', signals.isEmpty ? null : () => _setSelected(_selectedIndex - 1, signals.length)),
          _smallButton('Next', signals.isEmpty ? null : () => _setSelected(_selectedIndex + 1, signals.length)),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _copySignalText(signals, selected)));
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

  List<_SignalMatch> _buildSignals() {
    final highLevel = widget.snapshot.levels.contains('DAILY') ? 'DAILY' : (widget.snapshot.levels.isNotEmpty ? widget.snapshot.levels.first : '');
    final lowLevel = widget.snapshot.levels.contains('MIN30') ? 'MIN30' : (widget.snapshot.levels.length > 1 ? widget.snapshot.levels[1] : '');
    final high = widget.snapshot.of(highLevel);
    final low = widget.snapshot.of(lowLevel);
    if (high == null || low == null || high.bsps.isEmpty || low.bsps.isEmpty) return const [];

    final result = <_SignalMatch>[];
    for (final highBsp in high.bsps.where((b) => b.isBuy && (_isType2(b) || _isType3(b)))) {
      final relations = widget.snapshot.relationsForParentRange(
        parentLevel: highLevel,
        childLevel: lowLevel,
        startParentRawIndex: highBsp.rawIndex,
        endParentRawIndex: highBsp.rawIndex,
      );
      if (relations.isEmpty) continue;
      final childStart = relations.map((r) => r.childStartRawIndex).reduce((a, b) => a < b ? a : b);
      final childEnd = relations.map((r) => r.childEndRawIndex).reduce((a, b) => a > b ? a : b);
      final lowCandidates = low.bsps.where((b) {
        if (!b.isBuy) return false;
        if (b.rawIndex < childStart || b.rawIndex > childEnd) return false;
        if (_isType2(highBsp)) return _isType1(b);
        if (_isType3(highBsp)) return _isType1(b) || _isType2(b);
        return false;
      });
      for (final lowBsp in lowCandidates) {
        final state = highBsp.confirmed && lowBsp.confirmed
            ? SignalVisibilityState.confirmed
            : SignalVisibilityState.candidate;
        final highPattern = _isType2(highBsp) ? '2-buy' : '3-buy';
        final lowTrigger = _isType1(lowBsp) ? '1-buy' : '2-buy';
        final relation = _relationContaining(relations, lowBsp.rawIndex) ?? relations.first;
        final signal = IntervalNestSignal(
          direction: 'buy',
          highLevel: highLevel,
          lowLevel: lowLevel,
          highPattern: highPattern,
          lowTrigger: lowTrigger,
          highRawIndex: highBsp.rawIndex,
          lowRawIndex: lowBsp.rawIndex,
          score: state == SignalVisibilityState.confirmed ? 1.0 : 0.5,
          state: state,
          reasons: const [
            'high level BSP is from original chan.py output',
            'low level BSP is from original chan.py output',
            'high-low range is bound by native LevelRelation',
          ],
          warnings: const [
            'MVP signal only; no trading plan or quality score yet',
            'Accepted on current lightweight step frame only',
          ],
          observedAtCursor: widget.frameIndex,
          confirmedAtCursor: state == SignalVisibilityState.confirmed ? widget.frameIndex : null,
          meta: {
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

  LevelRelation? _relationContaining(List<LevelRelation> relations, int childRawIndex) {
    for (final relation in relations) {
      if (childRawIndex >= relation.childStartRawIndex && childRawIndex <= relation.childEndRawIndex) {
        return relation;
      }
    }
    return null;
  }

  bool _isType1(BspPoint point) => _normalizedType(point).contains('1');
  bool _isType2(BspPoint point) => _normalizedType(point).contains('2');
  bool _isType3(BspPoint point) => _normalizedType(point).contains('3');

  String _normalizedType(BspPoint point) {
    return point.type.toLowerCase().replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '');
  }

  void _setSelected(int next, int total) {
    if (total <= 0) return;
    setState(() => _selectedIndex = next.clamp(0, total - 1).toInt());
  }

  String _copySignalText(List<_SignalMatch> signals, _SignalMatch? selected) {
    if (selected == null) {
      return [
        'manual interval signal diagnostics',
        'button: Copy Signal',
        'mode: ${widget.mode}',
        'symbol: ${widget.symbol}',
        'frame.index.local: ${widget.frameIndex ?? ''}',
        'frame.count.local: ${widget.frameCount ?? ''}',
        'signal_source: original chan.py BSP + native LevelRelation',
        'available_signals: 0',
        'status: no signal for DAILY/MIN30 MVP scope',
      ].join('\n');
    }
    final signal = selected.signal;
    return [
      'manual interval signal diagnostics',
      'button: Copy Signal',
      'mode: ${widget.mode}',
      'symbol: ${widget.symbol}',
      'frame.index.local: ${widget.frameIndex ?? ''}',
      'frame.count.local: ${widget.frameCount ?? ''}',
      'signal_source: original chan.py BSP + native LevelRelation',
      'signal_scope: DAILY/MIN30 MVP',
      'available_signals: ${signals.length}',
      'selected_signal.local: ${_selectedIndex + 1}',
      'direction: ${signal.direction}',
      'state: ${signal.state.wireName}',
      'score: ${signal.score}',
      'high_level: ${signal.highLevel}',
      'high_pattern: ${signal.highPattern}',
      'high_bsp_index: ${selected.highBsp.index}',
      'high_bsp_type: ${selected.highBsp.type}',
      'high_raw_index: ${selected.highBsp.rawIndex}',
      'high_time: ${selected.highBsp.time ?? ''}',
      'low_level: ${signal.lowLevel}',
      'low_trigger: ${signal.lowTrigger}',
      'low_bsp_index: ${selected.lowBsp.index}',
      'low_bsp_type: ${selected.lowBsp.type}',
      'low_raw_index: ${selected.lowBsp.rawIndex}',
      'low_time: ${selected.lowBsp.time ?? ''}',
      'parent_relation_range: ${selected.parentRelation.parentRawIndex}-${selected.parentRelation.parentRawIndex}',
      'child_relation_range: ${selected.parentRelation.childStartRawIndex}-${selected.parentRelation.childEndRawIndex}',
      'child_union_range: ${selected.childStartRawIndex}-${selected.childEndRawIndex}',
      'relation_count_for_parent: ${selected.relationCount}',
      'visibleAt.frame: ${signal.observedAtCursor ?? ''}',
      'confirmedAt.frame: ${signal.confirmedAtCursor ?? ''}',
      'invalidatedAt.frame: ${signal.invalidatedAtCursor ?? ''}',
      'future_function_policy: current frame only; no final snapshot signal confirmation',
      'reasons: ${signal.reasons.join(' | ')}',
      'warnings: ${signal.warnings.join(' | ')}',
      'status: ok',
    ].join('\n');
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
