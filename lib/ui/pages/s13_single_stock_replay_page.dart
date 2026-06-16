import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/bsp.dart';
import '../../core/models/chan_snapshot.dart';
import '../../core/models/level_relation.dart';
import '../../core/models/multi_level_chan_snapshot.dart';
import '../../core/models/rhythm.dart';
import '../../core/runtime/runtime_path.dart';
import '../../data/python_multi_level_chan_analysis_source.dart';
import '../drawing/drawing_object.dart';
import '../drawing/tradingview_drawing_tool.dart';
import 's13_nested_marker_numbering_policy.dart';
import '../widgets/recursive_seg_origin_kline_chart.dart';
import '../widgets/s13_chip_distribution_panel.dart';

class S13SingleStockReplayPage extends StatefulWidget {
  final int currentRouteIndex;
  final ValueChanged<int>? onOpenRoute;

  const S13SingleStockReplayPage({
    super.key,
    this.currentRouteIndex = 1,
    this.onOpenRoute,
  });

  @override
  State<S13SingleStockReplayPage> createState() =>
      _S13SingleStockReplayPageState();
}

class _S13SingleStockReplayPageState extends State<S13SingleStockReplayPage> {
  static const _levelOptions = <String>[
    'DAILY',
    'MIN60',
    'MIN30',
    'MIN15',
    'MIN5',
    'MIN1',
  ];
  static const _levelOptionSet = <String>{
    'DAILY',
    'MIN60',
    'MIN30',
    'MIN15',
    'MIN5',
    'MIN1',
  };
  static const _evidenceHeader = 'S13_INTERVAL_NEST_MARKER_EVIDENCE';
  static final _defaultStartDate = DateTime(2026, 1, 1);
  static const String _rhythmPolicy =
      'backend exports rhythm_lines/rhythm_hits; Dart only parses and renders DrawingObject overlays';
  final _backendUrlController =
          TextEditingController(text: 'app-managed bundled Python'),
      _symbolController = TextEditingController(text: '600340'),
      _marketController = TextEditingController(text: 'SH');
  final _selectedLevels = <String>['DAILY', 'MIN30', 'MIN5'];
  final _enabledEasyTdxIndicators = <String>{};
  final ValueNotifier<int> _toolboxOpenSignal = ValueNotifier<int>(0);
  final _nestedNumberingPolicy = const S13NestedMarkerNumberingPolicy();

  PythonMultiLevelChanAnalysis? _analysis;
  String _mode = 'step',
      _activeLevel = 'DAILY',
      _status = '未加载',
      _lastLevelValidation = '级别组合待校验';
  bool _loading = false,
      _showBspCandidateTrail = true,
      _showRhythmLines = true,
      _show1382Hits = true,
      _showChipDistribution = false,
      _panelOpen = false,
      _playing = false;
  int _frameIndex = 0, _windowSize = 90;
  double _playSpeed = 1.0, _priceScale = 1.0;
  int? _viewEndIndex, _crosshairIndex;
  DateTime? _startDate, _endDate;
  Timer? _playTimer;
  Offset _floatingToolbarOffset = const Offset(12, 54);
  final Map<String, Offset> _replayControlOffsets = <String, Offset>{};

  @override
  void dispose() {
    _backendUrlController.dispose();
    _symbolController.dispose();
    _marketController.dispose();
    _toolboxOpenSignal.dispose();
    _playTimer?.cancel();
    super.dispose();
  }

  DateTime get _defaultEndDate =>
      DateTime.now().subtract(const Duration(days: 2));
  int get _frameCount => _analysis?.frames.length ?? 0;
  bool get _isStepMode => _mode == 'step';
  bool get _hasStepFrames => _isStepMode && _frameCount > 0;
  int get _safeFrameIndex =>
      _frameCount <= 0 ? 0 : _frameIndex.clamp(0, _frameCount - 1).toInt();
  int get _currentFrameSource => _hasStepFrames ? _safeFrameIndex : -1;
  String get _stepFrameLabel => !_isStepMode
      ? 'once final snapshot'
      : (_frameCount <= 0
          ? 'step no frames'
          : '${_safeFrameIndex + 1}/$_frameCount');

  List<String> get _normalizedLevels => <String>[
        for (final level in _levelOptions)
          if (_selectedLevels
              .map((v) => v.trim().toUpperCase())
              .contains(level))
            level,
      ];

  List<String> get _loadedLevels {
    final levels = _currentSnapshot?.levels ??
        _analysis?.snapshot.levels ??
        const <String>[];
    final normalized = levels
        .map((level) => level.trim().toUpperCase())
        .where((level) => level.isNotEmpty)
        .toList(growable: false);
    return normalized.isEmpty ? _normalizedLevels : normalized;
  }

  MultiLevelChanSnapshot? get _currentSnapshot {
    final a = _analysis;
    if (a == null) return null;
    if (_isStepMode) {
      if (a.frames.isEmpty) return null;
      return a.frames[_safeFrameIndex];
    }
    return a.snapshot;
  }

  ChanSnapshot? get _activeSnapshot {
    final c = _currentSnapshot;
    if (c == null) return null;
    final level = c.snapshots.containsKey(_activeLevel)
        ? _activeLevel
        : c.safeActiveLevel;
    return c.of(level);
  }

  ChanSnapshot? get _displaySnapshot {
    final s = _activeSnapshot;
    if (s == null) return null;
    final trail = _bspCandidateTrail(s);
    if (trail.isEmpty) return s;
    return ChanSnapshot(
      rawBars: s.rawBars,
      mergedBars: s.mergedBars,
      fxs: s.fxs,
      bis: s.bis,
      segs: s.segs,
      zss: s.zss,
      bsps: <BspPoint>[...trail, ...s.bsps],
      segZss: s.segZss,
      eigenBoxes: s.eigenBoxes,
      segEigenBoxes: s.segEigenBoxes,
      indicators: s.indicators,
    );
  }

  int get _bspCandidateTrailCount {
    final s = _activeSnapshot;
    return s == null ? 0 : _bspCandidateTrail(s).length;
  }

  List<BspPoint> _bspCandidateTrail(ChanSnapshot current) {
    return _bspCandidateTrailObservationsForLevel(_activeLevel, current)
        .map((o) => o.bsp)
        .toList(growable: false);
  }

  List<_BspObservation> _bspCandidateTrailObservationsForLevel(
    String rawLevel,
    ChanSnapshot current,
  ) {
    final a = _analysis;
    if (!_showBspCandidateTrail ||
        !_isStepMode ||
        a == null ||
        a.frames.isEmpty) {
      return const <_BspObservation>[];
    }
    final level = rawLevel.trim().toUpperCase();
    final live = current.bsps.map((p) => _bspKeyForLevel(level, p)).toSet();
    final trail = <String, _BspObservation>{};
    for (var frame = 0;
        frame <= _safeFrameIndex && frame < a.frames.length;
        frame++) {
      final s = a.frames[frame].of(level);
      if (s == null) continue;
      for (final p in s.bsps) {
        final key = _bspKeyForLevel(level, p);
        trail.putIfAbsent(
          key,
          () => _BspObservation(
            level: level,
            bsp: _trailPoint(p, level),
            state: S13NestedMarkerTriggerState.candidateTrail,
            bspSourceFrame: frame,
            bspKey: key,
          ),
        );
      }
    }
    for (final key in live) {
      trail.remove(key);
    }
    return trail.values.toList(growable: false)
      ..sort((a, b) => a.bsp.rawIndex.compareTo(b.bsp.rawIndex));
  }

  List<_BspObservation> _snapshotBspObservationsWithTrail(String rawLevel) {
    final level = rawLevel.trim().toUpperCase();
    final snap = _currentSnapshot?.of(level);
    if (snap == null) return const <_BspObservation>[];
    final current = <_BspObservation>[
      for (final p in snap.bsps)
        _BspObservation(
          level: level,
          bsp: p,
          state: S13NestedMarkerTriggerState.current,
          bspSourceFrame: _currentFrameSource,
          bspKey: _bspKeyForLevel(level, p),
        ),
    ];
    return <_BspObservation>[
      ..._bspCandidateTrailObservationsForLevel(level, snap),
      ...current,
    ];
  }

  String _baseBspType(BspPoint p) =>
      p.type.replaceAll('候选轨迹', '').trim().isEmpty
          ? 'BSP'
          : p.type.replaceAll('候选轨迹', '').trim();

  String _bspKeyForLevel(String fallbackLevel, BspPoint p) {
    final level = p.level.trim().isEmpty
        ? fallbackLevel.trim().toUpperCase()
        : p.level.trim().toUpperCase();
    final side = p.isSell ? 'sell' : (p.isBuy ? 'buy' : 'bsp');
    return '${level.toLowerCase()}|$side|${_baseBspType(p).toLowerCase()}|${p.rawIndex}|${p.biIndex ?? -1}|${p.segIndex ?? -1}|${p.zsIndex ?? -1}';
  }

  String _bspKey(BspPoint p) => _bspKeyForLevel(p.level, p);

  BspPoint _trailPoint(BspPoint p, String fallbackLevel) {
    final type = _baseBspType(p);
    return BspPoint(
      index: p.index,
      rawIndex: p.rawIndex,
      time: p.time,
      price: p.price,
      type: '$type候选轨迹',
      level: p.level.trim().isEmpty ? fallbackLevel : p.level,
      biIndex: p.biIndex,
      segIndex: p.segIndex,
      zsIndex: p.zsIndex,
      confirmed: p.confirmed,
    );
  }

  S13NestedMarkerTriggerState _nestedTriggerState(
          _BspObservation observation) =>
      observation.state;

  _BspObservation? _bspObservationAt(String level, int rawIndex) {
    for (final observation in _snapshotBspObservationsWithTrail(level)) {
      if (observation.bsp.rawIndex == rawIndex) return observation;
    }
    return null;
  }

  bool _hasAdjacentRelationEdge(String parentLevel, String childLevel) {
    final c = _currentSnapshot;
    if (c == null) return false;
    final parent = parentLevel.trim().toUpperCase();
    final child = childLevel.trim().toUpperCase();
    return c.relations.any(
      (r) =>
          r.parentLevel.trim().toUpperCase() == parent &&
          r.childLevel.trim().toUpperCase() == child,
    );
  }

  List<String> _missingAdjacentRelationEdges() {
    final levels = _loadedLevels;
    final missing = <String>[];
    for (var i = 0; i < levels.length - 1; i++) {
      if (!_hasAdjacentRelationEdge(levels[i], levels[i + 1])) {
        missing.add('${levels[i]}->${levels[i + 1]}');
      }
    }
    return missing;
  }

  LevelRelation? _relationDown(
    String parentLevel,
    int parentRawIndex, {
    int? targetChildRawIndex,
  }) {
    final c = _currentSnapshot;
    if (c == null) return null;
    final levels = _loadedLevels;
    final parent = parentLevel.trim().toUpperCase();
    final parentIndex = levels.indexOf(parent);
    if (parentIndex < 0 || parentIndex >= levels.length - 1) return null;
    final childLevel = levels[parentIndex + 1];
    if (!_hasAdjacentRelationEdge(parent, childLevel)) return null;
    final matches = c.relations
        .where(
          (r) =>
              r.parentLevel.trim().toUpperCase() == parent &&
              r.childLevel.trim().toUpperCase() == childLevel &&
              r.parentRawIndex == parentRawIndex,
        )
        .toList(growable: false)
      ..sort((a, b) => a.childStartRawIndex.compareTo(b.childStartRawIndex));
    if (matches.isEmpty) return null;
    if (targetChildRawIndex == null) {
      return matches.length == 1 ? matches.first : null;
    }
    final containsChildRawIndex = matches
        .where((r) => r.coversChildRawIndex(targetChildRawIndex))
        .toList(growable: false)
      ..sort((a, b) {
        final aw = a.childEndRawIndex - a.childStartRawIndex;
        final bw = b.childEndRawIndex - b.childStartRawIndex;
        if (aw != bw) return aw.compareTo(bw);
        return a.childStartRawIndex.compareTo(b.childStartRawIndex);
      });
    return containsChildRawIndex.length == 1
        ? containsChildRawIndex.first
        : null;
  }

  LevelRelation? _relationUp(String childLevel, int childRawIndex) {
    final c = _currentSnapshot;
    if (c == null) return null;
    final levels = _loadedLevels;
    final child = childLevel.trim().toUpperCase();
    final childIndex = levels.indexOf(child);
    if (childIndex <= 0) return null;
    final parentLevel = levels[childIndex - 1];
    if (!_hasAdjacentRelationEdge(parentLevel, child)) return null;
    final matches = c.relations
        .where(
          (r) =>
              r.parentLevel.trim().toUpperCase() == parentLevel &&
              r.childLevel.trim().toUpperCase() == child &&
              r.coversChildRawIndex(childRawIndex),
        )
        .toList(growable: false)
      ..sort((a, b) => a.parentRawIndex.compareTo(b.parentRawIndex));
    return matches.isEmpty ? null : matches.first;
  }

  int? _mapRawIndexToLevel(String fromLevel, int rawIndex, String toLevel) {
    final levels = _loadedLevels;
    final from = levels.indexOf(fromLevel.trim().toUpperCase());
    final to = levels.indexOf(toLevel.trim().toUpperCase());
    if (from < 0 || to < 0) return null;
    if (from == to) return rawIndex;
    var currentRaw = rawIndex;
    if (from > to) {
      for (var i = from; i > to; i--) {
        final relation = _relationUp(levels[i], currentRaw);
        if (relation == null) return null;
        currentRaw = relation.parentRawIndex;
      }
      return currentRaw;
    }
    for (var i = from; i < to; i++) {
      final relation = _relationDown(levels[i], currentRaw);
      if (relation == null) return null;
      currentRaw = relation.childStartRawIndex;
    }
    return currentRaw;
  }

  List<_NestedBspMarker> get _nestedBspMarkers {
    final c = _currentSnapshot;
    final active = _activeSnapshot;
    final levels = _loadedLevels;
    final activeIndex = levels.indexOf(_activeLevel);
    if (!_hasStepFrames || c == null || active == null || activeIndex < 0) {
      return const <_NestedBspMarker>[];
    }
    final triggers = <_NestedBspTrigger>[];
    for (final level in levels) {
      for (final observation in _snapshotBspObservationsWithTrail(level)) {
        final activeRaw = _mapRawIndexToLevel(
          level,
          observation.bsp.rawIndex,
          _activeLevel,
        );
        if (activeRaw == null) continue;
        triggers.add(
          _NestedBspTrigger(
            activeRawIndex: activeRaw,
            sourceLevel: level,
            sourceRawIndex: observation.bsp.rawIndex,
            observation: observation,
            state: _nestedTriggerState(observation),
            relationSourceFrame: _currentFrameSource,
            bspSourceFrame: observation.bspSourceFrame,
            anchorKind: 'bsp',
          ),
        );
      }
    }
    triggers.sort((a, b) {
      if (a.activeRawIndex != b.activeRawIndex) {
        return a.activeRawIndex.compareTo(b.activeRawIndex);
      }
      final stateCompare =
          _nestedNumberingPolicy.compareTriggerState(a.state, b.state);
      if (stateCompare != 0) return stateCompare;
      final ai = levels.indexOf(a.sourceLevel),
          bi = levels.indexOf(b.sourceLevel);
      if (ai != bi) return ai.compareTo(bi);
      final rawCompare = _nestedNumberingPolicy.compareTriggerRawIndex(
        a.sourceRawIndex,
        b.sourceRawIndex,
      );
      if (rawCompare != 0) return rawCompare;
      return a.observation.bspKey.compareTo(b.observation.bspKey);
    });

    final totalByActiveRaw = <int, int>{};
    for (final trigger in triggers) {
      totalByActiveRaw[trigger.activeRawIndex] =
          (totalByActiveRaw[trigger.activeRawIndex] ?? 0) + 1;
    }
    final sequenceByActiveRaw = <int, int>{};
    final markers = <_NestedBspMarker>[];
    final seen = <String>{};
    for (final trigger in triggers) {
      final total = totalByActiveRaw[trigger.activeRawIndex] ?? 1;
      final sequence = (sequenceByActiveRaw[trigger.activeRawIndex] ?? 0) + 1;
      sequenceByActiveRaw[trigger.activeRawIndex] = sequence;
      final sourceIndex = levels.indexOf(trigger.sourceLevel);
      if (sourceIndex < 0) continue;
      final rawByLevel = <String, int>{
        _activeLevel: trigger.activeRawIndex,
        trigger.sourceLevel: trigger.sourceRawIndex,
      };
      final intervalAnchorByLevel = <String, bool>{};
      for (var i = sourceIndex; i > 0; i--) {
        final child = levels[i];
        final childRaw = rawByLevel[child];
        if (childRaw == null) break;
        final up = _relationUp(child, childRaw);
        if (up == null) break;
        rawByLevel[levels[i - 1]] = up.parentRawIndex;
      }
      for (var i = sourceIndex; i < levels.length - 1; i++) {
        final parent = levels[i];
        final parentRaw = rawByLevel[parent];
        if (parentRaw == null) break;
        final down = _relationDown(parent, parentRaw);
        if (down == null) break;
        final child = levels[i + 1];
        rawByLevel[child] = down.childStartRawIndex;
        intervalAnchorByLevel[child] = true;
      }
      final rows = <_NestedBspMarkerRow>[];
      for (var i = 0; i < levels.length; i++) {
        final level = levels[i];
        final raw = rawByLevel[level];
        final isIntervalAnchor = intervalAnchorByLevel[level] == true &&
            !(level == trigger.sourceLevel && raw == trigger.sourceRawIndex);
        final isTriggerSource =
            level == trigger.sourceLevel && raw == trigger.sourceRawIndex;
        final observation = raw == null || isIntervalAnchor
            ? null
            : (isTriggerSource
                ? trigger.observation
                : _bspObservationAt(level, raw));
        rows.add(
          _NestedBspMarkerRow(
            level: level,
            rawIndex: raw,
            bsp: observation?.bsp,
            isActiveLevel: i == activeIndex,
            directionDown: _nestedArrowDown(i, activeIndex),
            isIntervalAnchor: isIntervalAnchor,
            isTriggerSource: isTriggerSource,
            sequenceLabel: isTriggerSource
                ? _nestedNumberingPolicy.sequenceLabel(
                    sequenceNumber: sequence,
                    sequenceTotal: total,
                  )
                : null,
            triggerState: isTriggerSource ? trigger.state : null,
            anchorKind: isIntervalAnchor ? 'interval' : 'bsp',
          ),
        );
      }
      final key =
          '${trigger.activeRawIndex}|${trigger.sourceLevel}:${trigger.sourceRawIndex}:${trigger.state.name}|$sequence/$total|${trigger.observation.bspKey}';
      if (!seen.add(key)) continue;
      markers.add(
        _NestedBspMarker(
          rawIndex: trigger.activeRawIndex,
          rows: rows,
          targetLevel: trigger.sourceLevel,
          targetRawIndex: trigger.sourceRawIndex,
          targetEndRawIndex: trigger.sourceRawIndex,
          sequenceNumber: sequence,
          sequenceTotal: total,
          triggerState: trigger.state,
          bspKey: trigger.observation.bspKey,
          relationSourceFrame: trigger.relationSourceFrame,
          bspSourceFrame: trigger.bspSourceFrame,
          sourceLevel: trigger.sourceLevel,
          sourceRawIndex: trigger.sourceRawIndex,
          anchorKind: trigger.anchorKind,
        ),
      );
    }
    return markers;
  }

  bool _nestedArrowDown(int levelIndex, int activeIndex) {
    if (activeIndex == 0) return true;
    return levelIndex == activeIndex;
  }

  DateTime _dateOrDefault(DateTime? value, DateTime fallback) =>
      value ?? fallback;
  String _fmtDate(DateTime v) => v.toIso8601String().split('T').first;
  String get _effectiveWindowText =>
      '${_fmtDate(_dateOrDefault(_startDate, _defaultStartDate))}~${_fmtDate(_dateOrDefault(_endDate, _defaultEndDate))}';

  _LevelValidationResult _validateSelectedLevels() {
    final raw = [for (final l in _selectedLevels) l.trim().toUpperCase()];
    final n = _normalizedLevels;
    if (raw.isEmpty) {
      return _LevelValidationResult(false, n, '????????');
    }
    final bad =
        raw.where((l) => !_levelOptionSet.contains(l)).toList(growable: false);
    if (bad.isNotEmpty) {
      return _LevelValidationResult(false, n, '??????: ${bad.join(',')}');
    }
    if (raw.toSet().length != raw.length) {
      return _LevelValidationResult(false, n, '??????');
    }
    if (n.length == 1) {
      return _LevelValidationResult(true, n, '?????: ${n.first}');
    }
    if (n.length != raw.length) {
      return _LevelValidationResult(true, n, '????????: ${n.join(',')}');
    }
    return _LevelValidationResult(true, n, '??????: ${n.join(',')}');
  }

  String _requestModeFor(_LevelValidationResult lv) =>
      lv.normalizedLevels.length == 1 ? 'once' : _mode;

  Future<void> _loadReplay() async {
    if (_loading) return;
    _stopPlay();
    final lv = _validateSelectedLevels();
    setState(() => _lastLevelValidation = lv.message);
    if (!lv.ok) {
      _showMessage(lv.message);
      return;
    }
    final startDate = _dateOrDefault(_startDate, _defaultStartDate);
    final endDate = _dateOrDefault(_endDate, _defaultEndDate);
    if (startDate.isAfter(endDate)) {
      _showMessage('时间窗口无效：开始时间不能晚于结束时间');
      return;
    }
    final requestMode = _requestModeFor(lv);
    setState(() {
      _loading = true;
      _mode = requestMode;
      _status =
          'S13 loading analyze_multi ${requestMode.toUpperCase()} levels:${lv.normalizedLevels.join(',')} window:${_fmtDate(startDate)}~${_fmtDate(endDate)} runtime:${RuntimePathController.current.wireName}';
    });
    final source = PythonMultiLevelChanAnalysisSource(
      baseUrl: _backendUrlController.text.trim(),
    );
    try {
      final a = await source.analyzeMulti(
          mode: requestMode,
          market: _marketController.text.trim().toUpperCase(),
          code: _symbolController.text.trim(),
          levels: lv.normalizedLevels,
          adjust: 'QFQ',
          mainLevel: lv.normalizedLevels.first,
          clockLevel: lv.normalizedLevels.first,
          startDate: startDate,
          endDate: endDate,
          runtimePath: RuntimePathController.current,
          config: <String, dynamic>{
            'bi_algo': 'normal',
            'seg_algo': 'chan',
            'zs_algo': 'normal',
            'recursive_seg_max_level': 4,
            'enable_rhythm_1382': true,
            'rhythm_calc_mode': 'normal',
            'rhythm_max_lines': 160,
            'rhythm_max_hits_per_line': 3,
          });
      if (!mounted) return;
      setState(() {
        _analysis = a;
        _frameIndex = 0;
        final init = _currentSnapshot ?? a.snapshot;
        _activeLevel = init.safeActiveLevel;
        _viewEndIndex = null;
        _crosshairIndex = null;
        _priceScale = 1.0;
        _status = _buildStatus(a, startDate, endDate);
      });
      _showMessage('S13 replay loaded');
    } catch (e) {
      if (!mounted) return;
      final detail = _friendlyLoadError(e);
      setState(() => _status = detail);
      _showMessage(detail);
    } finally {
      source.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyLoadError(Object e) =>
      'S13 replay load failed: $e | request: symbol=${_symbolController.text.trim()} market=${_marketController.text.trim().toUpperCase()} mode=${_requestModeFor(_validateSelectedLevels())} levels=${_normalizedLevels.join(',')} window=$_effectiveWindowText runtime_path=${RuntimePathController.current.wireName}';
  void _setReplayMode(String v) {
    if (_mode == v) return;
    _stopPlay();
    setState(() {
      _mode = v;
      _frameIndex = 0;
      _viewEndIndex = null;
      _crosshairIndex = null;
      _priceScale = 1.0;
      final c = _currentSnapshot;
      if (c != null) {
        _activeLevel = c.snapshots.containsKey(_activeLevel)
            ? _activeLevel
            : c.safeActiveLevel;
      }
    });
  }

  void _setFrameIndex(int index) {
    final a = _analysis;
    if (a == null || a.frames.isEmpty) return;
    final next = index.clamp(0, a.frames.length - 1).toInt();
    final f = a.frames[next];
    final level = f.snapshots.containsKey(_activeLevel)
        ? _activeLevel
        : f.safeActiveLevel;
    setState(() {
      _frameIndex = next;
      _activeLevel = level;
      _viewEndIndex = null;
      _crosshairIndex = null;
      _priceScale = 1.0;
      _status =
          'S13 step frame ${next + 1}/${a.frames.length} active:$level relations:${f.relations.length} nested_markers:${_nestedBspMarkers.length} candidate_trail:$_bspCandidateTrailCount missing_edges:${_missingAdjacentRelationEdges().join(',')}';
    });
  }

  void _stepFrameBy(int delta) => _setFrameIndex(_safeFrameIndex + delta);
  void _jumpToLatestFrame() => _setFrameIndex(_frameCount - 1);
  void _jumpToFirstFrame() => _setFrameIndex(0);

  void _togglePlay() {
    if (_playing) {
      _stopPlay();
      return;
    }
    if (!_isStepMode || _frameCount <= 0) {
      _showInfo('请先以 step 模式载入复盘数据。');
      return;
    }
    setState(() => _playing = true);
    _playTimer?.cancel();
    _playTimer = Timer.periodic(_playInterval, (_) {
      if (!mounted || !_playing) return;
      if (_safeFrameIndex >= _frameCount - 1) {
        _stopPlay();
        return;
      }
      _stepFrameBy(1);
    });
  }

  Duration get _playInterval {
    final ms = (800 / _playSpeed.clamp(0.25, 4.0)).round();
    return Duration(milliseconds: ms);
  }

  void _stopPlay() {
    _playTimer?.cancel();
    if (mounted) setState(() => _playing = false);
  }

  void _setPlaySpeed(double value) {
    final wasPlaying = _playing;
    setState(() {
      _playSpeed = value;
      if (wasPlaying) _playing = false;
    });
    if (wasPlaying) _togglePlay();
  }

  void _jumpNestedMarker(_NestedBspMarker marker) {
    final level = marker.targetLevel;
    final rawIndex = marker.targetRawIndex;
    if (level == null || rawIndex == null) {
      _showMessage('当前 marker 没有可跳转的小级别买卖点。');
      return;
    }
    final s = _currentSnapshot?.of(level);
    if (s == null || s.rawBars.isEmpty) {
      _showMessage('小级别当前帧无K线：$level');
      return;
    }
    final max = s.rawBars.length - 1;
    final end = (marker.targetEndRawIndex ?? rawIndex).clamp(0, max).toInt();
    setState(() {
      _activeLevel = level;
      _viewEndIndex = end;
      _crosshairIndex = rawIndex.clamp(0, max).toInt();
      _priceScale = 1.0;
      _panelOpen = false;
    });
  }

  void _jumpNestedMarkerRow(_NestedBspMarkerRow row) {
    final rawIndex = row.bsp?.rawIndex ?? row.rawIndex;
    if (rawIndex == null) return;
    final s = _currentSnapshot?.of(row.level);
    if (s == null || s.rawBars.isEmpty) {
      _showMessage('当前帧无K线：${row.level}');
      return;
    }
    final max = s.rawBars.length - 1;
    setState(() {
      _activeLevel = row.level;
      _viewEndIndex = rawIndex.clamp(0, max).toInt();
      _crosshairIndex = rawIndex.clamp(0, max).toInt();
      _priceScale = 1.0;
      _panelOpen = false;
    });
  }

  Future<void> _copyS13IntervalNestMarkerEvidence() async {
    final evidence = _buildS13IntervalNestMarkerEvidence();
    await Clipboard.setData(ClipboardData(text: evidence));
    if (!mounted) return;
    final firstLines = evidence.split('\n').take(12).join('\n');
    _showInfo('S13 marker evidence copied.\n\n$firstLines');
  }

  String _buildS13IntervalNestMarkerEvidence() {
    final c = _currentSnapshot;
    final markers = _nestedBspMarkers;
    final missingEdges = _missingAdjacentRelationEdges();
    final buffer = StringBuffer()
      ..writeln(_evidenceHeader)
      ..writeln(
          'request_params: symbol=${_symbolController.text.trim()} market=${_marketController.text.trim().toUpperCase()} mode=$_mode adjust=QFQ levels=${_normalizedLevels.join(',')} window=$_effectiveWindowText')
      ..writeln('runtime_path=${RuntimePathController.current.wireName}')
      ..writeln('current_frame=${_hasStepFrames ? _safeFrameIndex + 1 : 0}')
      ..writeln('frame_total=$_frameCount')
      ..writeln('active_level=$_activeLevel')
      ..writeln('loaded_levels=${_loadedLevels.join(',')}')
      ..writeln('relation_count=${c?.relations.length ?? 0}')
      ..writeln('nested_marker_count=${markers.length}')
      ..writeln('candidate_trail_count=$_bspCandidateTrailCount')
      ..writeln(
          'missing_relation_edges=${missingEdges.isEmpty ? 'none' : missingEdges.join(',')}')
      ..writeln(
          'missing relation edge diagnostic=${missingEdges.isEmpty ? 'none' : missingEdges.join(',')}');
    final sampleCount = math.min(12, markers.length);
    if (sampleCount == 0) {
      buffer.writeln('marker_trigger_samples=none');
    } else {
      for (var i = 0; i < sampleCount; i++) {
        final marker = markers[i];
        buffer.writeln(
          'marker_trigger_sample[${i + 1}]: activeRawIndex=${marker.rawIndex} sourceLevel=${marker.sourceLevel} sourceRawIndex=${marker.sourceRawIndex} trigger_state=${_triggerStateText(marker.triggerState)} sequenceNumber=${marker.sequenceNumber} sequenceTotal=${marker.sequenceTotal} bsp_key=${marker.bspKey} relation_source_frame=${marker.relationSourceFrame} bsp_source_frame=${marker.bspSourceFrame} anchor_kind=${marker.anchorKind} rows=${_markerRowsEvidence(marker.rows)}',
        );
      }
    }
    return buffer.toString();
  }

  String _markerRowsEvidence(List<_NestedBspMarkerRow> rows) {
    return rows.map((row) {
      final kind = row.isIntervalAnchor
          ? 'interval'
          : (row.bsp == null ? 'missing' : 'bsp');
      return '${row.level}:raw=${row.rawIndex ?? 'null'}:anchor_kind=$kind';
    }).join('|');
  }

  String _triggerStateText(S13NestedMarkerTriggerState state) {
    switch (state) {
      case S13NestedMarkerTriggerState.current:
        return 'current';
      case S13NestedMarkerTriggerState.candidateTrail:
        return 'candidate_trail';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: _chartPanel(_displaySnapshot)),
              if (_panelOpen)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => setState(() => _panelOpen = false),
                  ),
                ),
              _titleLevelSwitcher(),
              _floatingToolbar(),
            ],
          ),
        ),
      );

  Widget _floatingToolbar() => Positioned(
        left: _floatingToolbarOffset.dx,
        top: _floatingToolbarOffset.dy,
        child: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                GestureDetector(
                  onPanUpdate: _dragFloatingToolbar,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _floatingIcon(
                        Icons.tune,
                        '工具栏',
                        () => setState(() => _panelOpen = !_panelOpen),
                      ),
                      const SizedBox(width: 6),
                      _floatingIcon(
                        Icons.architecture,
                        '画线工具',
                        () => _toolboxOpenSignal.value++,
                      ),
                      const SizedBox(width: 6),
                      _floatingIcon(
                        Icons.stacked_bar_chart,
                        _showChipDistribution ? '关闭筹码分布' : '筹码分布',
                        () => setState(() =>
                            _showChipDistribution = !_showChipDistribution),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.drag_indicator,
                          size: 18, color: Colors.white54),
                    ],
                  ),
                ),
                if (_panelOpen)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 390,
                      height: math.min(
                          600, MediaQuery.sizeOf(context).height - 120),
                      child: _settingsPanel(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  void _dragFloatingToolbar(DragUpdateDetails details) {
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _floatingToolbarOffset = Offset(
        (_floatingToolbarOffset.dx + details.delta.dx)
            .clamp(0.0, size.width - 400),
        (_floatingToolbarOffset.dy + details.delta.dy)
            .clamp(0.0, size.height - 80),
      );
    });
  }

  Widget _floatingIcon(IconData icon, String tip, VoidCallback onPressed) =>
      Tooltip(
        message: tip,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
          color: Colors.white70,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0x99111722),
            side: const BorderSide(color: Colors.white24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
        ),
      );

  Widget _titleLevelSwitcher() => Positioned(
        top: 8,
        left: 0,
        right: 0,
        child: IgnorePointer(
          ignoring: _loadedLevels.isEmpty,
          child: Center(
            child: Opacity(
              opacity: 0.72,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Wrap(
                    spacing: 4,
                    children: <Widget>[
                      for (final level in _loadedLevels)
                        _titleLevelButton(level),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _titleLevelButton(String level) {
    final selected = _activeLevel == level;
    final canSelect = _currentSnapshot?.snapshots.containsKey(level) == true;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: canSelect
          ? () => setState(() {
                _activeLevel = level;
                _viewEndIndex = null;
                _crosshairIndex = null;
                _priceScale = 1.0;
              })
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFD54F).withValues(alpha: 0.88)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          level,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _settingsPanel() => _panelBox('工具栏', _unifiedToolPanel());

  Widget _unifiedToolPanel() => ListView(
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          children: <Widget>[
            _sectionTitle('股票'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _input(_backendUrlController, 'backend',
                    width: 210, enabled: false),
                _input(_symbolController, 'symbol', width: 104),
                _input(_marketController, 'market', width: 78),
                _dateButton(
                    'start', _startDate, () => _pickDate(isStart: true)),
                _dateButton('end', _endDate, () => _pickDate(isStart: false)),
                _runtimePathButton(),
                _infoButton('窗口', _effectiveWindowText),
                _infoButton('状态', _status),
              ],
            ),
            _sectionGap(),
            _sectionTitle('级别'),
            Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
              for (final level in _levelOptions) _levelChip(level),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
              for (final level in _loadedLevels) _activeLevelChip(level),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              _infoButton('校验', _lastLevelValidation),
              _infoButton('当前', _loadedLevels.join(',')),
            ]),
            _sectionGap(),
            _sectionTitle('复盘 / marker'),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              _modeChip('once'),
              _modeChip('step'),
              FilledButton.icon(
                onPressed: _loading ? null : _loadReplay,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow, size: 16),
                label: const Text('载入复盘'),
              ),
              OutlinedButton.icon(
                onPressed: _copyS13IntervalNestMarkerEvidence,
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('复制 marker 证据'),
              ),
              _infoButton('step', _stepFrameLabel),
              _infoButton('marker', '${_nestedBspMarkers.length}'),
              _infoButton(
                  '1.382', _rhythmSummaryFor(_activeSnapshot).shortText),
            ]),
            _sectionGap(),
            _sectionTitle('图层'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final n in const <String>['MA', 'BOLL', 'VOL', 'MACD'])
                _indicatorChip(n)
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
              FilterChip(
                  label: const Text('节奏线'),
                  selected: _showRhythmLines,
                  onSelected: _loading
                      ? null
                      : (v) => setState(() => _showRhythmLines = v)),
              FilterChip(
                  label: const Text('1.382命中'),
                  selected: _show1382Hits,
                  onSelected: _loading
                      ? null
                      : (v) => setState(() => _show1382Hits = v)),
              FilterChip(
                  label: const Text('筹码分布'),
                  selected: _showChipDistribution,
                  onSelected: _loading
                      ? null
                      : (v) => setState(() => _showChipDistribution = v)),
            ]),
            SwitchListTile(
                value: _showBspCandidateTrail,
                onChanged: _loading
                    ? null
                    : (v) => setState(() => _showBspCandidateTrail = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('BSP 候选轨迹层',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700))),
            _sectionGap(),
            _sectionTitle('画线'),
            Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                    onPressed: () => _toolboxOpenSignal.value++,
                    icon: const Icon(Icons.architecture, size: 18),
                    label: const Text('打开画线工具'))),
            _sectionGap(),
            _sectionTitle('页面'),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              _routeButton('复盘', Icons.candlestick_chart, 0),
              _routeButton('单股多级别', Icons.account_tree, 1),
              _routeButton('扫描器', Icons.radar, 2),
              _routeButton('批量候选', Icons.view_list, 3),
              _routeButton('研究', Icons.science, 4),
            ]),
          ]);
  Widget _chartPanel(ChanSnapshot? s) {
    if (s == null || s.rawBars.isEmpty)
      return _panelBox(
          'Chart',
          const Center(
              child: Text('Load replay to show chart.',
                  style: TextStyle(color: Colors.white54))));
    return Stack(children: <Widget>[
      Positioned.fill(
          child: RecursiveSegOriginKlineChart(
              snapshot: s,
              showFx: true,
              showFxLine: true,
              showFxText: true,
              showBi: true,
              showBiText: false,
              showSeg: true,
              showSegText: true,
              showZs: true,
              showBiBsp: true,
              showSegBsp: true,
              showMergedBars: false,
              showEasyTdxIndicators: _enabledEasyTdxIndicators.isNotEmpty,
              easyTdxSubPanelCount: 2,
              enabledEasyTdxIndicators: _enabledEasyTdxIndicators,
              onEasyTdxIndicatorToggled: _toggleEasyTdxIndicator,
              toolboxOpenSignal: _toolboxOpenSignal,
              onToolboxQuickToolAdded: (_) {},
              drawingObjects: _rhythmDrawingObjects(s),
              drawingStorageKey: 's13_${_symbolController.text}_$_activeLevel',
              symbolLabel: '${_symbolController.text.trim()} $_activeLevel',
              windowSize: _windowSize,
              priceScale: _priceScale,
              viewEndIndex: _viewEndIndex,
              crosshairIndex: _crosshairIndex,
              onCrosshairChanged: (v) => setState(() => _crosshairIndex = v),
              onPanBars: _panChartByBars,
              onWindowSizeChanged: (v) => setState(() => _windowSize = v),
              onPriceScaleChanged: (v) => setState(() => _priceScale = v))),
      S13ChipDistributionPanel(
        snapshot: _activeSnapshot,
        enabled: _showChipDistribution,
        isStepMode: _isStepMode,
        stepIndex:
            (s.rawBars.length - 1).clamp(0, s.rawBars.length - 1).toInt(),
        crosshairIndex: _crosshairIndex,
        visibleRightIndex: (_viewEndIndex ?? s.rawBars.length - 1)
            .clamp(0, s.rawBars.length - 1)
            .toInt(),
        onClose: () => setState(() => _showChipDistribution = false),
      ),
      _nestedBspMarkerOverlay(),
      _replayControlOverlay()
    ]);
  }

  Widget _nestedBspMarkerOverlay() {
    final markers = _nestedBspMarkers;
    final active = _activeSnapshot;
    if (markers.isEmpty || active == null || active.rawBars.isEmpty) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          if (width <= 120 || height <= 120) return const SizedBox.shrink();
          final end = (_viewEndIndex ?? active.rawBars.length - 1)
              .clamp(0, active.rawBars.length - 1)
              .toInt();
          final start = (end - _windowSize + 1).clamp(0, end).toInt();
          final visibleCount = end - start + 1;
          const leftPad = 4.0;
          const rightPad = 58.0;
          const topPad = 32.0;
          final chartWidth = width - leftPad - rightPad;
          if (chartWidth <= 0 || visibleCount <= 0) {
            return const SizedBox.shrink();
          }
          final step = chartWidth / visibleCount;
          final visibleByRawIndex = <int, List<_NestedBspMarker>>{};
          for (final marker in markers) {
            if (marker.rawIndex < start || marker.rawIndex > end) continue;
            visibleByRawIndex
                .putIfAbsent(marker.rawIndex, () => <_NestedBspMarker>[])
                .add(marker);
          }
          return Stack(
            children: <Widget>[
              for (final entry in visibleByRawIndex.entries)
                Positioned(
                  left: (leftPad + (entry.key - start + 0.5) * step - 18)
                      .clamp(0.0, width - 44),
                  top: topPad + 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final marker in entry.value)
                        _nestedBspMarkerButton(marker),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _nestedBspMarkerButton(_NestedBspMarker marker) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _jumpNestedMarker(marker),
        child: Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final row in marker.rows) _nestedBspMarkerGlyph(row),
            ],
          ),
        ),
      );

  Widget _nestedBspMarkerGlyph(_NestedBspMarkerRow row) {
    final bsp = row.bsp;
    if (bsp == null) {
      return SizedBox(
        height: row.isActiveLevel ? 18 : 15,
        child: Text(
          row.isIntervalAnchor ? '-' : '',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    final color = _bspNestedColor(bsp);
    final icon =
        row.directionDown ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up;
    final alpha = _nestedBspAlpha(bsp);
    final label = row.isTriggerSource ? row.sequenceLabel : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _jumpNestedMarkerRow(row),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: row.isActiveLevel ? 24 : 18,
            color: color.withValues(alpha: alpha),
            weight: row.isActiveLevel ? 900 : 500,
          ),
          if (label != null)
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: alpha),
                fontSize: row.isActiveLevel ? 11 : 10,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }

  double _nestedBspAlpha(BspPoint bsp) {
    final historical = bsp.type.contains('候选轨迹');
    if (historical) return bsp.confirmed ? 0.60 : 0.34;
    return bsp.confirmed ? 0.92 : 0.78;
  }

  Color _bspNestedColor(BspPoint bsp) {
    if (bsp.isSell) return const Color(0xFF00E676);
    if (bsp.isBuy) return const Color(0xFFFF5252);
    return const Color(0xFFFFD54F);
  }

  Widget _replayControlOverlay() {
    final enabled = _isStepMode && _frameCount > 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        const item = Size(46, 46);
        final centerX = constraints.maxWidth / 2;
        final y = constraints.maxHeight - item.height - 14;
        final defaults = <String, Offset>{
          'first': Offset(centerX - 142, y),
          'prev': Offset(centerX - 92, y),
          'play': Offset(centerX - 42, y),
          'next': Offset(centerX + 8, y),
          'last': Offset(centerX + 58, y),
          'speed': Offset(centerX + 112, y),
        };
        return Stack(
          children: <Widget>[
            _draggableReplayControl(
              id: 'first',
              defaultOffset: defaults['first']!,
              constraints: constraints,
              child: _replayIcon(
                Icons.first_page,
                '第一帧',
                enabled && _safeFrameIndex > 0 ? _jumpToFirstFrame : null,
                alpha: 0.50,
              ),
            ),
            _draggableReplayControl(
              id: 'prev',
              defaultOffset: defaults['prev']!,
              constraints: constraints,
              child: _replayIcon(
                Icons.chevron_left,
                '上一帧',
                enabled && _safeFrameIndex > 0 ? () => _stepFrameBy(-1) : null,
              ),
            ),
            _draggableReplayControl(
              id: 'play',
              defaultOffset: defaults['play']!,
              constraints: constraints,
              child: _replayIcon(
                _playing ? Icons.pause : Icons.play_arrow,
                '播放',
                enabled ? _togglePlay : null,
              ),
            ),
            _draggableReplayControl(
              id: 'next',
              defaultOffset: defaults['next']!,
              constraints: constraints,
              child: _replayIcon(
                Icons.chevron_right,
                '下一帧',
                enabled && _safeFrameIndex < _frameCount - 1
                    ? () => _stepFrameBy(1)
                    : null,
              ),
            ),
            _draggableReplayControl(
              id: 'last',
              defaultOffset: defaults['last']!,
              constraints: constraints,
              child: _replayIcon(
                Icons.last_page,
                '最新帧',
                enabled && _safeFrameIndex < _frameCount - 1
                    ? _jumpToLatestFrame
                    : null,
                alpha: 0.50,
              ),
            ),
            _draggableReplayControl(
              id: 'speed',
              defaultOffset: defaults['speed']!,
              constraints: constraints,
              child: _speedButton(),
            ),
          ],
        );
      },
    );
  }

  Widget _draggableReplayControl({
    required String id,
    required Offset defaultOffset,
    required BoxConstraints constraints,
    required Widget child,
  }) {
    const size = 46.0;
    final offset = _replayControlOffsets[id] ?? defaultOffset;
    return Positioned(
      left: offset.dx.clamp(0.0, constraints.maxWidth - size),
      top: offset.dy.clamp(0.0, constraints.maxHeight - size),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (details) {
          setState(() {
            final next = offset + details.delta;
            _replayControlOffsets[id] = Offset(
              next.dx.clamp(0.0, constraints.maxWidth - size),
              next.dy.clamp(0.0, constraints.maxHeight - size),
            );
          });
        },
        child: child,
      ),
    );
  }

  Widget _speedButton() => PopupMenuButton<double>(
        tooltip: '播放速度',
        onSelected: _setPlaySpeed,
        itemBuilder: (context) => const <PopupMenuEntry<double>>[
          PopupMenuItem(value: 0.25, child: Text('0.25x')),
          PopupMenuItem(value: 0.5, child: Text('0.5x')),
          PopupMenuItem(value: 1.0, child: Text('1x')),
          PopupMenuItem(value: 2.0, child: Text('2x')),
          PopupMenuItem(value: 4.0, child: Text('4x')),
        ],
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            shape: BoxShape.circle,
          ),
          child: Text(
            '${_playSpeed.toStringAsFixed(2)}x',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );

  Widget _replayIcon(
    IconData icon,
    String tip,
    VoidCallback? onPressed, {
    double alpha = 0.82,
  }) =>
      Tooltip(
        message: tip,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 22),
          color:
              Colors.white.withValues(alpha: onPressed == null ? 0.22 : alpha),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.28),
            minimumSize: const Size(42, 42),
            shape: const CircleBorder(),
          ),
        ),
      );

  Widget _levelChip(String level) {
    final selected = _selectedLevels.contains(level);
    return FilterChip(
      label: Text(level),
      selected: selected,
      onSelected: _loading
          ? null
          : (value) => setState(() {
                if (value) {
                  if (!_selectedLevels.contains(level)) {
                    _selectedLevels.add(level);
                  }
                } else if (_selectedLevels.length > 1) {
                  _selectedLevels.remove(level);
                  if (_selectedLevels.length == 1 && _mode == 'step') {
                    _mode = 'once';
                  }
                  if (_activeLevel == level && _selectedLevels.isNotEmpty) {
                    _activeLevel = _normalizedLevels.first;
                  }
                }
                _lastLevelValidation = _validateSelectedLevels().message;
              }),
      selectedColor: const Color(0xFFFFD54F),
      backgroundColor: const Color(0xFF20242E),
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white70,
        fontSize: 12,
      ),
    );
  }

  Widget _activeLevelChip(String level) {
    final selected = _activeLevel == level;
    final canSelect = _currentSnapshot?.snapshots.containsKey(level) == true;
    return ChoiceChip(
      label: Text(level),
      selected: selected,
      onSelected: canSelect
          ? (_) => setState(() {
                _activeLevel = level;
                _viewEndIndex = null;
                _crosshairIndex = null;
                _priceScale = 1.0;
              })
          : null,
      selectedColor: const Color(0xFFFFD54F),
      backgroundColor: const Color(0xFF20242E),
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white70,
        fontSize: 12,
      ),
    );
  }

  Widget _modeChip(String value) {
    final selected = _mode == value;
    return ChoiceChip(
      label: Text(value),
      selected: selected,
      onSelected: _loading ? null : (_) => _setReplayMode(value),
      selectedColor: const Color(0xFFFFD54F),
      backgroundColor: const Color(0xFF20242E),
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white70,
        fontSize: 12,
      ),
    );
  }

  Widget _indicatorChip(String name) {
    final selected = _enabledEasyTdxIndicators.contains(name);
    return FilterChip(
      label: Text(name),
      selected: selected,
      onSelected: (_) => _toggleEasyTdxIndicator(name),
      selectedColor: const Color(0xFFFFD54F),
      backgroundColor: const Color(0xFF20242E),
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white70,
        fontSize: 12,
      ),
    );
  }

  List<DrawingObject> _rhythmDrawingObjects(ChanSnapshot snapshot) {
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    final objects = <DrawingObject>[];
    if (_showRhythmLines) {
      for (final line in snapshot.rhythmLines.take(120)) {
        objects.add(DrawingObject(
          id: 'auto_${line.id}',
          tool: TradingViewDrawingTool.trendLine,
          anchors: <DrawingAnchor>[
            DrawingAnchor.chart(rawIndex: line.x1, price: line.y1),
            DrawingAnchor.chart(rawIndex: line.x2, price: line.y2),
          ],
          style: DrawingStyle(
            colorValue: line.dir == 'UP' ? 0xFF66BB6A : 0xFFEF5350,
            strokeWidth: 1.2 + line.layer.clamp(0, 3) * 0.35,
            opacity: 0.88,
            dashed: true,
            fontSize: 11,
          ),
          text: line.displayLabel,
          locked: true,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
    if (_show1382Hits) {
      for (final hit in snapshot.rhythmHits.take(80)) {
        objects.add(DrawingObject(
          id: 'auto_${hit.id}',
          tool: TradingViewDrawingTool.priceLabel,
          anchors: <DrawingAnchor>[
            DrawingAnchor.chart(
              rawIndex: hit.rawIndex,
              price: hit.price == 0 ? hit.threshold : hit.price,
            ),
          ],
          style: const DrawingStyle(
            colorValue: 0xFF8AB4FF,
            strokeWidth: 1.0,
            opacity: 0.95,
            fontSize: 10,
          ),
          text: '1.382 ${hit.displayLabel}',
          locked: true,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
    return objects;
  }

  _RhythmSummary _rhythmSummaryFor(ChanSnapshot? snapshot) {
    if (snapshot == null) return const _RhythmSummary.empty();
    return _RhythmSummary(
      lines: snapshot.rhythmLines,
      hits: snapshot.rhythmHits,
    );
  }

  void _toggleEasyTdxIndicator(String n) {
    final k = n.trim().toUpperCase();
    if (k.isEmpty) return;
    setState(() {
      if (_enabledEasyTdxIndicators.contains(k)) {
        _enabledEasyTdxIndicators.remove(k);
      } else {
        _enabledEasyTdxIndicators.add(k);
      }
    });
  }

  void _panChartByBars(int bars) {
    final s = _activeSnapshot;
    if (bars == 0 || s == null || s.rawBars.isEmpty) return;
    final max = s.rawBars.length - 1;
    final current = _viewEndIndex ?? max;
    final next = (current + bars).clamp(0, max).toInt();
    if (next != current) setState(() => _viewEndIndex = next);
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFFFD54F),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _sectionGap() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1, color: Colors.white12),
      );

  Widget _infoButton(String label, String message) => OutlinedButton.icon(
        onPressed: () => _showInfo('$label\n$message'),
        icon: const Icon(Icons.error_outline, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white24),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      );

  Widget _routeButton(String label, IconData icon, int routeIndex) {
    final selected = widget.currentRouteIndex == routeIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.tonalIcon(
        onPressed: selected
            ? null
            : () {
                setState(() => _panelOpen = false);
                widget.onOpenRoute?.call(routeIndex);
              },
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          alignment: Alignment.centerLeft,
          backgroundColor:
              selected ? const Color(0xAAFFD54F) : const Color(0x661C2330),
          foregroundColor: selected ? Colors.black : Colors.white70,
        ),
      ),
    );
  }

  Widget _dateButton(String label, DateTime? value, VoidCallback onPressed) =>
      SizedBox(
        width: 132,
        child: OutlinedButton.icon(
          onPressed: _loading ? null : onPressed,
          icon: const Icon(Icons.calendar_month, size: 16),
          label: Text(
            value == null ? label : _fmtDate(value),
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          ),
        ),
      );

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final current =
        isStart ? (_startDate ?? _defaultStartDate) : (_endDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1990, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Widget _runtimePathButton() => ValueListenableBuilder<RuntimePath>(
        valueListenable: RuntimePathController.selected,
        builder: (context, path, _) => PopupMenuButton<RuntimePath>(
          tooltip: 'runtime path',
          onSelected: RuntimePathController.set,
          itemBuilder: (context) => const <PopupMenuEntry<RuntimePath>>[
            PopupMenuItem(
              value: RuntimePath.highSpeed,
              child: Text('高速路（默认）'),
            ),
            PopupMenuItem(
              value: RuntimePath.slowPath,
              child: Text('慢速路（调试）'),
            ),
          ],
          child: Container(
            width: 178,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2330),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: path.isHighSpeed
                    ? const Color(0xFF66BB6A)
                    : const Color(0xFFFFB74D),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.speed,
                  size: 16,
                  color: path.isHighSpeed
                      ? const Color(0xFF66BB6A)
                      : const Color(0xFFFFB74D),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    path.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _input(TextEditingController controller, String label,
          {required double width, bool enabled = true}) =>
      SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          enabled: enabled && !_loading,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: _decoration(label),
        ),
      );

  Widget _panelBox(String title, Widget child) => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF2111722),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '收起工具栏',
                    onPressed: () => setState(() => _panelOpen = false),
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.white70,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(child: child),
            ],
          ),
        ),
      );

  InputDecoration _decoration(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFF1C2330),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12)));
  String _buildStatus(PythonMultiLevelChanAnalysis a, DateTime s, DateTime e) {
    final m = a.meta;
    final rhythm = _rhythmSummaryFor(_activeSnapshot);
    return 'S13 analyze_multi ${_mode.toUpperCase()} runtime_path:${_runtimePathText(a)} native:${m['native_cchan_lv_list']} fallback:${m['fallback_to_bridge'] ?? false} frames:${a.frames.length} active_frame:$_stepFrameLabel levels:${a.snapshot.levels.join(',')} window:${_fmtDate(s)}~${_fmtDate(e)} nested_markers:${_nestedBspMarkers.length} candidate_trail:$_bspCandidateTrailCount rhythm_1382_line_count:${rhythm.lineCount} rhythm_1382_hit_count:${rhythm.hitCount} rhythm_1382_visible_lines:$_showRhythmLines rhythm_1382_visible_hits:$_show1382Hits rhythm_1382_backend_route_ms:${m['backend_route_rhythm_1382_overlay_ms'] ?? 'unknown'} rhythm_1382_overlay_policy:$_rhythmPolicy dart_chan_calculation_authority: false';
  }

  String _runtimePathText(PythonMultiLevelChanAnalysis analysis) {
    final raw =
        '${analysis.meta['runtime_path'] ?? analysis.snapshot.meta['runtime_path'] ?? RuntimePathController.current.wireName}'
            .trim();
    return raw == 'slow_path' ? 'slow_path' : 'high_speed';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    _showInfo(message);
  }

  Future<void> _showInfo(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131722),
        title: const Row(
          children: <Widget>[
            Icon(Icons.error_outline, color: Color(0xFFFFD54F)),
            SizedBox(width: 8),
            Text('提示', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _RhythmSummary {
  final List<RhythmLine> lines;
  final List<RhythmHit> hits;

  const _RhythmSummary({required this.lines, required this.hits});
  const _RhythmSummary.empty()
      : lines = const <RhythmLine>[],
        hits = const <RhythmHit>[];

  int get lineCount => lines.length;
  int get hitCount => hits.length;
  RhythmLine? get sampleLine => lines.isEmpty ? null : lines.first;
  RhythmHit? get sampleHit => hits.isEmpty ? null : hits.first;
  String get shortText =>
      'lines=$lineCount hits=$hitCount sample=${sampleLine?.displayLabel ?? sampleHit?.displayLabel ?? 'none'}';
}

class _LevelValidationResult {
  final bool ok;
  final List<String> normalizedLevels;
  final String message;

  const _LevelValidationResult(this.ok, this.normalizedLevels, this.message);
}

class _BspObservation {
  final String level;
  final BspPoint bsp;
  final S13NestedMarkerTriggerState state;
  final int bspSourceFrame;
  final String bspKey;

  const _BspObservation({
    required this.level,
    required this.bsp,
    required this.state,
    required this.bspSourceFrame,
    required this.bspKey,
  });
}

class _NestedBspTrigger {
  final int activeRawIndex;
  final String sourceLevel;
  final int sourceRawIndex;
  final _BspObservation observation;
  final S13NestedMarkerTriggerState state;
  final int relationSourceFrame;
  final int bspSourceFrame;
  final String anchorKind;

  const _NestedBspTrigger({
    required this.activeRawIndex,
    required this.sourceLevel,
    required this.sourceRawIndex,
    required this.observation,
    required this.state,
    required this.relationSourceFrame,
    required this.bspSourceFrame,
    required this.anchorKind,
  });
}

class _NestedBspMarker {
  final int rawIndex;
  final List<_NestedBspMarkerRow> rows;
  final String? targetLevel;
  final int? targetRawIndex;
  final int? targetEndRawIndex;
  final int sequenceNumber;
  final int sequenceTotal;
  final S13NestedMarkerTriggerState triggerState;
  final String bspKey;
  final int relationSourceFrame;
  final int bspSourceFrame;
  final String sourceLevel;
  final int sourceRawIndex;
  final String anchorKind;

  const _NestedBspMarker({
    required this.rawIndex,
    required this.rows,
    required this.targetLevel,
    required this.targetRawIndex,
    required this.targetEndRawIndex,
    required this.sequenceNumber,
    required this.sequenceTotal,
    required this.triggerState,
    required this.bspKey,
    required this.relationSourceFrame,
    required this.bspSourceFrame,
    required this.sourceLevel,
    required this.sourceRawIndex,
    required this.anchorKind,
  });
}

class _NestedBspMarkerRow {
  final String level;
  final int? rawIndex;
  final BspPoint? bsp;
  final bool isActiveLevel;
  final bool directionDown;
  final bool isIntervalAnchor;
  final bool isTriggerSource;
  final String? sequenceLabel;
  final S13NestedMarkerTriggerState? triggerState;
  final String anchorKind;

  const _NestedBspMarkerRow({
    required this.level,
    required this.rawIndex,
    required this.bsp,
    required this.isActiveLevel,
    required this.directionDown,
    required this.isIntervalAnchor,
    required this.isTriggerSource,
    required this.sequenceLabel,
    required this.triggerState,
    required this.anchorKind,
  });
}
