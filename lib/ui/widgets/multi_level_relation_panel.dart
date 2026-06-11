import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/level_relation.dart';
import '../../core/models/multi_level_chan_snapshot.dart';

class MultiLevelRelationPanel extends StatefulWidget {
  final MultiLevelChanSnapshot snapshot;
  final String mode;
  final int? frameIndex;
  final int? frameCount;
  final String symbol;
  final ValueChanged<_RelationLocateRequest> onLocate;

  const MultiLevelRelationPanel({
    super.key,
    required this.snapshot,
    required this.mode,
    required this.onLocate,
    this.frameIndex,
    this.frameCount,
    this.symbol = '',
  });

  @override
  State<MultiLevelRelationPanel> createState() => _MultiLevelRelationPanelState();
}

class _MultiLevelRelationPanelState extends State<MultiLevelRelationPanel> {
  static const _structureTypes = ['K', 'BI', 'SEG', 'ZS', 'BSP'];

  int _pairIndex = 0;
  String _structureType = 'K';
  int _targetIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pairs = _pairs(widget.snapshot.levels);
    if (pairs.isEmpty) return const SizedBox.shrink();
    if (_pairIndex >= pairs.length) _pairIndex = pairs.length - 1;
    final pair = pairs[_pairIndex];
    final targets = _buildTargets(pair.parentLevel, pair.childLevel, _structureType);
    if (_targetIndex >= targets.length) _targetIndex = targets.isEmpty ? 0 : targets.length - 1;
    final target = targets.isEmpty ? null : targets[_targetIndex];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(48, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x221B5E20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x6655AA66)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Relation targeting',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          _pairDropdown(pairs),
          _structureDropdown(),
          _chip('source', 'native relations', true),
          _chip('targets', '${targets.length}', targets.isNotEmpty),
          _chip('selected', target == null ? '-' : '${_targetIndex + 1}/${targets.length}', target != null),
          if (target != null) _chip('parent', '${target.parentLevel} ${target.structureType}#${target.structureIndex} raw:${target.parentStartRawIndex}-${target.parentEndRawIndex}', true),
          if (target != null) _chip('child', '${target.childLevel} raw:${target.childStartRawIndex}-${target.childEndRawIndex}', true),
          _smallButton('Prev', targets.isEmpty ? null : () => _setTarget(_targetIndex - 1, targets.length)),
          _smallButton('Next', targets.isEmpty ? null : () => _setTarget(_targetIndex + 1, targets.length)),
          _smallButton('Locate Parent', target == null ? null : () => widget.onLocate(_RelationLocateRequest(target.parentLevel, target.parentStartRawIndex, target.parentEndRawIndex))),
          _smallButton('Locate Child', target == null ? null : () => widget.onLocate(_RelationLocateRequest(target.childLevel, target.childStartRawIndex, target.childEndRawIndex))),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _copyText(pair, targets, target)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Relation diagnostics copied'), duration: Duration(seconds: 3)),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('Copy Relation'),
            style: _buttonStyle(),
          ),
        ],
      ),
    );
  }

  List<_LevelPair> _pairs(List<String> levels) {
    final result = <_LevelPair>[];
    for (var i = 0; i < levels.length - 1; i++) {
      result.add(_LevelPair(levels[i], levels[i + 1]));
    }
    return result;
  }

  Widget _pairDropdown(List<_LevelPair> pairs) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<int>(
        initialValue: _pairIndex.clamp(0, pairs.length - 1).toInt(),
        dropdownColor: const Color(0xFF1C2330),
        style: const TextStyle(color: Colors.white, fontSize: 11),
        decoration: _decoration('pair'),
        items: [
          for (var i = 0; i < pairs.length; i++)
            DropdownMenuItem(value: i, child: Text('${pairs[i].parentLevel}->${pairs[i].childLevel}')),
        ],
        onChanged: (v) => setState(() {
          _pairIndex = v ?? _pairIndex;
          _targetIndex = 0;
        }),
      ),
    );
  }

  Widget _structureDropdown() {
    return SizedBox(
      width: 90,
      child: DropdownButtonFormField<String>(
        initialValue: _structureType,
        dropdownColor: const Color(0xFF1C2330),
        style: const TextStyle(color: Colors.white, fontSize: 11),
        decoration: _decoration('parent'),
        items: [
          for (final v in _structureTypes) DropdownMenuItem(value: v, child: Text(v)),
        ],
        onChanged: (v) => setState(() {
          _structureType = v ?? _structureType;
          _targetIndex = 0;
        }),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 10),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFF1C2330),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white24),
      ),
    );
  }

  List<_RelationTarget> _buildTargets(String parentLevel, String childLevel, String structureType) {
    final parent = widget.snapshot.of(parentLevel);
    if (parent == null) return const [];
    final ranges = <_ParentRange>[];
    if (structureType == 'K') {
      final parentIndexes = widget.snapshot.relations
          .where((r) => r.parentLevel == parentLevel && r.childLevel == childLevel)
          .map((r) => r.parentRawIndex)
          .toSet()
          .toList()
        ..sort();
      for (final rawIndex in parentIndexes) {
        ranges.add(_ParentRange(structureType, rawIndex, rawIndex, rawIndex));
      }
    } else if (structureType == 'BI') {
      for (final bi in parent.bis) {
        ranges.add(_ParentRange(structureType, bi.index, bi.startRawIndex, bi.endRawIndex));
      }
    } else if (structureType == 'SEG') {
      for (final seg in parent.segs) {
        ranges.add(_ParentRange(structureType, seg.index, seg.startRawIndex, seg.endRawIndex));
      }
    } else if (structureType == 'ZS') {
      for (final zs in parent.zss) {
        ranges.add(_ParentRange(structureType, zs.index, zs.startRawIndex, zs.endRawIndex));
      }
    } else if (structureType == 'BSP') {
      for (final bsp in parent.bsps) {
        ranges.add(_ParentRange(structureType, bsp.index, bsp.rawIndex, bsp.rawIndex));
      }
    }

    final targets = <_RelationTarget>[];
    for (final range in ranges) {
      final relations = widget.snapshot.relationsForParentRange(
        parentLevel: parentLevel,
        childLevel: childLevel,
        startParentRawIndex: range.startRawIndex,
        endParentRawIndex: range.endRawIndex,
      );
      if (relations.isEmpty) continue;
      final childStart = relations.map((r) => r.childStartRawIndex).reduce((a, b) => a < b ? a : b);
      final childEnd = relations.map((r) => r.childEndRawIndex).reduce((a, b) => a > b ? a : b);
      targets.add(_RelationTarget(
        parentLevel: parentLevel,
        childLevel: childLevel,
        structureType: range.structureType,
        structureIndex: range.structureIndex,
        parentStartRawIndex: range.startRawIndex,
        parentEndRawIndex: range.endRawIndex,
        childStartRawIndex: childStart,
        childEndRawIndex: childEnd,
        relations: relations,
        parentStartTime: _barTime(parentLevel, range.startRawIndex),
        parentEndTime: _barTime(parentLevel, range.endRawIndex),
        childStartTime: _barTime(childLevel, childStart),
        childEndTime: _barTime(childLevel, childEnd),
      ));
    }
    targets.sort((a, b) => a.parentStartRawIndex.compareTo(b.parentStartRawIndex));
    return targets;
  }

  DateTime? _barTime(String level, int rawIndex) {
    final snapshot = widget.snapshot.of(level);
    if (snapshot == null) return null;
    for (final bar in snapshot.rawBars) {
      if (bar.index == rawIndex) return bar.time;
    }
    if (rawIndex >= 0 && rawIndex < snapshot.rawBars.length) {
      return snapshot.rawBars[rawIndex].time;
    }
    return null;
  }

  void _setTarget(int next, int total) {
    if (total <= 0) return;
    setState(() => _targetIndex = next.clamp(0, total - 1).toInt());
  }

  String _copyText(_LevelPair pair, List<_RelationTarget> targets, _RelationTarget? target) {
    final meta = widget.snapshot.meta;
    return [
      'manual relation diagnostics',
      'button: Copy Relation',
      'mode: ${widget.mode}',
      'symbol: ${widget.symbol}',
      'frame.index.local: ${widget.frameIndex ?? ''}',
      'frame.count.local: ${widget.frameCount ?? ''}',
      'relation_source: native chan_parent_child LevelRelation',
      'level_relation_mode: ${meta['level_relation_mode'] ?? ''}',
      'native_cchan_lv_list: ${meta['native_cchan_lv_list'] ?? ''}',
      'pair: ${pair.parentLevel}->${pair.childLevel}',
      'parent_structure: $_structureType',
      'available_targets: ${targets.length}',
      'selected_target.local: ${target == null ? '' : _targetIndex + 1}',
      'parent_level: ${target?.parentLevel ?? pair.parentLevel}',
      'parent_structure_index: ${target?.structureIndex ?? ''}',
      'parent_raw_range: ${target == null ? '' : '${target.parentStartRawIndex}-${target.parentEndRawIndex}'}',
      'parent_time_range: ${target == null ? '' : '${target.parentStartTime ?? ''} -> ${target.parentEndTime ?? ''}'}',
      'child_level: ${target?.childLevel ?? pair.childLevel}',
      'child_raw_range: ${target == null ? '' : '${target.childStartRawIndex}-${target.childEndRawIndex}'}',
      'child_time_range: ${target == null ? '' : '${target.childStartTime ?? ''} -> ${target.childEndTime ?? ''}'}',
      'relation_count_for_target: ${target?.relations.length ?? 0}',
      'snapshot.relations.length: ${widget.snapshot.relations.length}',
      'status: ${target == null ? 'no target for selected pair/structure' : 'ok'}',
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

class _LevelPair {
  final String parentLevel;
  final String childLevel;

  const _LevelPair(this.parentLevel, this.childLevel);
}

class _ParentRange {
  final String structureType;
  final int structureIndex;
  final int startRawIndex;
  final int endRawIndex;

  const _ParentRange(this.structureType, this.structureIndex, this.startRawIndex, this.endRawIndex);
}

class _RelationTarget {
  final String parentLevel;
  final String childLevel;
  final String structureType;
  final int structureIndex;
  final int parentStartRawIndex;
  final int parentEndRawIndex;
  final int childStartRawIndex;
  final int childEndRawIndex;
  final List<LevelRelation> relations;
  final DateTime? parentStartTime;
  final DateTime? parentEndTime;
  final DateTime? childStartTime;
  final DateTime? childEndTime;

  const _RelationTarget({
    required this.parentLevel,
    required this.childLevel,
    required this.structureType,
    required this.structureIndex,
    required this.parentStartRawIndex,
    required this.parentEndRawIndex,
    required this.childStartRawIndex,
    required this.childEndRawIndex,
    required this.relations,
    this.parentStartTime,
    this.parentEndTime,
    this.childStartTime,
    this.childEndTime,
  });
}

class _RelationLocateRequest {
  final String level;
  final int startRawIndex;
  final int endRawIndex;

  const _RelationLocateRequest(this.level, this.startRawIndex, this.endRawIndex);
}
