import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/analysis/chip_distribution.dart';
import '../../core/analysis/chip_online_replay_adapter.dart';
import '../../core/models/bsp.dart';
import '../../core/models/bsp_step_review.dart';
import '../../core/models/chan_snapshot.dart';
import '../../core/models/level_relation.dart';
import '../../core/models/multi_level_chan_snapshot.dart';
import '../../core/models/raw_bar.dart';
import '../../core/models/rhythm.dart';
import '../../core/runtime/runtime_path.dart';
import '../../core/services/replay_analysis_store.dart';
import '../../core/settings/chan_config_store.dart';
import '../../core/settings/chip_distribution_settings.dart';
import '../../core/settings/level_promoter_settings.dart';
import '../../data/python_multi_level_chan_analysis_source.dart';
import '../drawing/drawing_object.dart';
import '../drawing/tradingview_drawing_tool.dart';
import 's13_nested_marker_numbering_policy.dart';
import 's13_rhythm_display_settings.dart';
import 's13_rhythm_viewport_selector.dart';
import '../widgets/auto_collapsible_side_toolbar.dart';
import '../widgets/bsp_bottom_label_overlay.dart';
import '../widgets/bsp_chart_label_adapter.dart';
import '../widgets/four_way_granular_sidebar_shell.dart';
import '../widgets/permanent_window_controls.dart';
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
    'TICK',
    'TICK_MIN1',
    'DAILY',
    'MIN60',
    'MIN30',
    'MIN15',
    'MIN5',
    'MIN1',
  ];
  static const _levelOptionSet = <String>{
    'TICK',
    'TICK_MIN1',
    'DAILY',
    'MIN60',
    'MIN30',
    'MIN15',
    'MIN5',
    'MIN1',
  };
  static const _evidenceHeader = 'S13_INTERVAL_NEST_MARKER_EVIDENCE';
  static final _defaultStartDate = DateTime(2026, 1, 1);
  static final _defaultEndDateValue = DateTime(2026, 6, 18);
  static const String _rhythmPolicy =
      'backend exports rhythm_lines/rhythm_hits; Dart only parses and renders DrawingObject overlays';
  static const List<String> _easyTdxIndicatorOptions = <String>[
    'MA',
    'BOLL',
    'VOL',
    'MACD',
    'KDJ',
    'RSI',
    'DMI',
    'ATR',
    'WR',
    'CCI',
    'BIAS',
    'OBV',
    'PSY',
    'TRIX',
    'DPO',
    'MTM',
    'ROC',
    'EXPMA',
    'BBI',
    'DFMA',
    'CR',
    'KTN',
    'XSII',
    'VR',
    'EMV',
    'MASS',
    'MFI',
    'BRAR',
    'ASI',
    'ZHUOYAO',
    'BIAS_SIGNAL',
    'TAQ',
  ];
  final _backendUrlController =
          TextEditingController(text: 'app-managed bundled Python'),
      _symbolController = TextEditingController(text: '600340'),
      _marketController = TextEditingController(text: 'SH');
  final _selectedLevels = <String>['MIN5'];
  final _enabledEasyTdxIndicators = <String>{};
  final ValueNotifier<int> _toolboxOpenSignal = ValueNotifier<int>(0);
  final ValueNotifier<TradingViewDrawingTool?> _toolboxSelectedToolSignal =
      ValueNotifier<TradingViewDrawingTool?>(null);
  final ValueNotifier<int> _sidebarRevision = ValueNotifier<int>(0);
  final _nestedNumberingPolicy = const S13NestedMarkerNumberingPolicy();

  PythonMultiLevelChanAnalysis? _analysis;
  String _mode = 'once',
      _activeLevel = 'MIN5',
      _status = '未加载',
      _lastLevelValidation = '级别组合待校验';
  bool _loading = false,
      _showBspCandidateTrail = true,
      _showRhythmLines = true,
      _show1382Hits = false,
      _showChipDistribution = false,
      _showIntervalNest = true,
      _showNativeZs = true,
      _showSeg2Zs = true,
      _showSegNZs = true,
      _panelOpen = false,
      _autoJudgeBspStepReview = true,
      _playing = false;
  int _frameIndex = 0, _windowSize = 90, _chartGeneration = 0;
  double _playSpeed = 1.0, _priceScale = 1.0, _priceOffset = 0.0;
  int? _viewEndIndex, _crosshairIndex;
  DateTime? _startDate = _defaultStartDate, _endDate = _defaultEndDateValue;
  Timer? _playTimer;
  bool _windowMaximized = false;
  int? _researchOverlayNonce;
  final List<Map<String, dynamic>> _researchOverlayMarkers =
      <Map<String, dynamic>>[];
  final Map<String, Offset> _replayControlOffsets = <String, Offset>{};
  final Map<String, BspStepReviewItem> _bspStepReviewItems =
      <String, BspStepReviewItem>{};
  final Set<String> _bspStepReviewCorrectKeys = <String>{};
  final Set<String> _bspStepReviewWrongKeys = <String>{};
  S13RhythmDisplaySettings _rhythmSettings = const S13RhythmDisplaySettings(
    biToSegEnabled: false,
    segToSegsegEnabled: false,
    maxLayer: 0,
    hit: S13RhythmHitStyle(enabled: false),
  );
  String _loadedRhythmCalcMode = 'not_loaded';
  bool? _loadedRhythmEnabled;
  String _loadedChanConfigFingerprint = '';
  bool _chanConfigDirtySinceLoad = false;
  Timer? _chanConfigChangeSnackTimer;

  @override
  void initState() {
    super.initState();
    _loadedChanConfigFingerprint = _chanConfigFingerprint();
    ChanConfigStore.notifier.addListener(_handleGlobalChanConfigChanged);
    LevelPromoterSettings.maxLayer.addListener(_handleGlobalChanConfigChanged);
    ReplayAnalysisStore.klineLocation.addListener(_handleKlineLocationRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        fourWaySidebarRegistry.register(this, _sidebarRegistrations());
        fourWayCornerRegistry.register(this, _sidebarCornerRegistrations());
      }
      _syncWindowMaximizedState();
    });
  }

  @override
  void dispose() {
    fourWaySidebarRegistry.unregister(this);
    fourWayCornerRegistry.unregister(this);
    ChanConfigStore.notifier.removeListener(_handleGlobalChanConfigChanged);
    LevelPromoterSettings.maxLayer
        .removeListener(_handleGlobalChanConfigChanged);
    ReplayAnalysisStore.klineLocation
        .removeListener(_handleKlineLocationRequest);
    _chanConfigChangeSnackTimer?.cancel();
    _backendUrlController.dispose();
    _symbolController.dispose();
    _marketController.dispose();
    _toolboxOpenSignal.dispose();
    _toolboxSelectedToolSignal.dispose();
    _sidebarRevision.dispose();
    _playTimer?.cancel();
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _sidebarRevision.value++;
    if (mounted) {
      fourWaySidebarRegistry.register(this, _sidebarRegistrations());
      fourWayCornerRegistry.register(this, _sidebarCornerRegistrations());
    }
  }

  List<SidebarCornerRegistration> _sidebarCornerRegistrations() =>
      <SidebarCornerRegistration>[
        SidebarCornerRegistration(
          id: 's13-load-replay-corner',
          corner: SidebarCorner.bottomRight,
          builder: (_) => IconButton(
            key: const ValueKey<String>('sidebar-corner-load-replay'),
            tooltip: '加载数据',
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow, size: 19),
            color: Colors.white70,
            onPressed: _loading ? null : _loadReplay,
          ),
        ),
      ];

  List<SidebarRegistration> _sidebarRegistrations() {
    SidebarRegistration action({
      required String id,
      required String label,
      required String category,
      required IconData icon,
      required SidebarEdge edge,
      required VoidCallback onActivate,
      bool compact = false,
      required Color accentColor,
      bool Function()? selectedBuilder,
    }) =>
        SidebarRegistration(
          id: id,
          label: label,
          category: category,
          icon: icon,
          edge: edge,
          onActivate: onActivate,
          compact: compact,
          accentColor: accentColor,
          selectedBuilder: selectedBuilder,
        );
    const cycleColor = Color(0xFF4DD0E1);
    const indicatorColor = Color(0xFFB388FF);
    const targetColor = Color(0xFFFFD54F);
    const modeColor = Color(0xFF81C784);
    const layerColor = Color(0xFF64B5F6);
    const toolColor = Color(0xFFFF8A80);
    return <SidebarRegistration>[
      action(
        id: 's13-start-date',
        label: 'start',
        category: '标的数据',
        icon: Icons.date_range,
        edge: SidebarEdge.right,
        accentColor: targetColor,
        onActivate: () => _pickDate(isStart: true),
      ),
      action(
        id: 's13-end-date',
        label: 'end',
        category: '标的数据',
        icon: Icons.event,
        edge: SidebarEdge.right,
        accentColor: targetColor,
        onActivate: () => _pickDate(isStart: false),
      ),
      action(
        id: 's13-runtime-fast',
        label: '高速',
        category: '标的数据',
        icon: Icons.speed,
        edge: SidebarEdge.right,
        accentColor: targetColor,
        selectedBuilder: () =>
            RuntimePathController.current == RuntimePath.highSpeed,
        onActivate: () =>
            setState(() => RuntimePathController.set(RuntimePath.highSpeed)),
      ),
      action(
        id: 's13-runtime-compat',
        label: '慢速',
        category: '标的数据',
        icon: Icons.route,
        edge: SidebarEdge.right,
        accentColor: targetColor,
        selectedBuilder: () =>
            RuntimePathController.current == RuntimePath.slowPath,
        onActivate: () =>
            setState(() => RuntimePathController.set(RuntimePath.slowPath)),
      ),
      action(
        id: 's13-copy-settings',
        label: '复制状态',
        category: '标的数据',
        icon: Icons.copy_all,
        edge: SidebarEdge.right,
        accentColor: targetColor,
        onActivate: _copyCurrentS13Settings,
      ),
      for (final level in _levelOptions)
        action(
          id: 's13-level-$level',
          label: level,
          category: '周期',
          icon: Icons.tune,
          edge: SidebarEdge.top,
          compact: true,
          accentColor: cycleColor,
          selectedBuilder: () => _selectedLevels.contains(level),
          onActivate: () => _toggleLevelFromSidebar(level),
        ),
      for (final level in _loadedLevels)
        action(
          id: 's13-active-level-$level',
          label: level,
          category: '周期',
          icon: Icons.adjust,
          edge: SidebarEdge.top,
          compact: true,
          accentColor: cycleColor,
          selectedBuilder: () => _activeLevel == level,
          onActivate: () => _activateLoadedLevelFromSidebar(level),
        ),
      action(
        id: 's13-mode-once',
        label: 'once',
        category: '复盘模式',
        icon: Icons.looks_one,
        edge: SidebarEdge.top,
        compact: true,
        accentColor: modeColor,
        selectedBuilder: () => _mode == 'once',
        onActivate: () => _setReplayMode('once'),
      ),
      action(
        id: 's13-mode-step',
        label: 'step',
        category: '复盘模式',
        icon: Icons.skip_next,
        edge: SidebarEdge.top,
        compact: true,
        accentColor: modeColor,
        selectedBuilder: () => _mode == 'step',
        onActivate: () => _setReplayMode('step'),
      ),
      for (final name in _easyTdxIndicatorOptions)
        action(
          id: 's13-indicator-$name',
          label: name,
          category: '指标',
          icon: Icons.analytics_outlined,
          edge: SidebarEdge.right,
          compact: true,
          accentColor: indicatorColor,
          selectedBuilder: () => _enabledEasyTdxIndicators.contains(name),
          onActivate: () => _toggleEasyTdxIndicator(name),
        ),
      action(
        id: 's13-show-interval-nest',
        label: '区间套',
        category: '图层',
        icon: Icons.account_tree,
        edge: SidebarEdge.right,
        accentColor: layerColor,
        selectedBuilder: () => _showIntervalNest,
        onActivate: () =>
            setState(() => _showIntervalNest = !_showIntervalNest),
      ),
      action(
        id: 's13-show-native-zs',
        label: '段中枢',
        category: '图层',
        icon: Icons.crop_square,
        edge: SidebarEdge.right,
        accentColor: layerColor,
        selectedBuilder: () => _showNativeZs,
        onActivate: () => setState(() => _showNativeZs = !_showNativeZs),
      ),
      action(
        id: 's13-show-seg2-zs',
        label: '2段中枢',
        category: '图层',
        icon: Icons.filter_2,
        edge: SidebarEdge.right,
        accentColor: layerColor,
        selectedBuilder: () => _showSeg2Zs,
        onActivate: () => setState(() => _showSeg2Zs = !_showSeg2Zs),
      ),
      action(
        id: 's13-show-segn-zs',
        label: 'N段中枢',
        category: '图层',
        icon: Icons.layers,
        edge: SidebarEdge.right,
        accentColor: layerColor,
        selectedBuilder: () => _showSegNZs,
        onActivate: () => setState(() => _showSegNZs = !_showSegNZs),
      ),
      action(
        id: 's13-show-rhythm-lines',
        label: '节奏线',
        category: '图层',
        icon: Icons.timeline,
        edge: SidebarEdge.right,
        accentColor: layerColor,
        selectedBuilder: () => _showRhythmLines,
        onActivate: () => setState(() => _showRhythmLines = !_showRhythmLines),
      ),
      action(
        id: 's13-show-1382-hits',
        label: '1.382',
        category: '图层',
        icon: Icons.my_location,
        edge: SidebarEdge.right,
        accentColor: layerColor,
        selectedBuilder: () => _show1382Hits,
        onActivate: () => setState(() => _show1382Hits = !_show1382Hits),
      ),
      action(
        id: 's13-show-chip-distribution',
        label: '筹码分布',
        category: '图层',
        icon: Icons.stacked_bar_chart,
        edge: SidebarEdge.right,
        accentColor: layerColor,
        selectedBuilder: () => _showChipDistribution,
        onActivate: () =>
            setState(() => _showChipDistribution = !_showChipDistribution),
      ),
      action(
        id: 's13-rhythm-settings',
        label: '节奏设置',
        category: '工具',
        icon: Icons.tune,
        edge: SidebarEdge.right,
        accentColor: toolColor,
        onActivate: () {
          if (!_loading) _openRhythmDisplaySettings();
        },
      ),
      action(
        id: 's13-auto-bsp-review',
        label: '自动BSP',
        category: '工具',
        icon: Icons.fact_check,
        edge: SidebarEdge.right,
        accentColor: toolColor,
        selectedBuilder: () => _autoJudgeBspStepReview,
        onActivate: () {
          if (_loading) return;
          setState(() => _autoJudgeBspStepReview = !_autoJudgeBspStepReview);
          if (_autoJudgeBspStepReview) {
            _updateCurrentBspStepReviews(notify: false);
          }
        },
      ),
      action(
        id: 's13-bsp-candidate-trail',
        label: 'BSP轨迹',
        category: '工具',
        icon: Icons.route,
        edge: SidebarEdge.right,
        accentColor: toolColor,
        selectedBuilder: () => _showBspCandidateTrail,
        onActivate: () =>
            setState(() => _showBspCandidateTrail = !_showBspCandidateTrail),
      ),
      action(
        id: 's13-drawing',
        label: '画线工具',
        category: '工具',
        icon: Icons.architecture,
        edge: SidebarEdge.right,
        accentColor: toolColor,
        onActivate: _openDrawingToolbox,
      ),
    ];
  }

  void _handleKlineLocationRequest() {
    final request = ReplayAnalysisStore.klineLocation.value;
    if (request == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyKlineLocationRequest(request);
    });
  }

  Future<void> _applyKlineLocationRequest(KlineLocationRequest request) async {
    final requestedLevel = request.level.trim().toUpperCase();
    final overlayMarkers = _researchMarkersFromRequest(request);
    final loadedSymbol = _symbolController.text.trim().toUpperCase();
    final loadedMarket = _marketController.text.trim().toUpperCase();
    final hasRequestedData = _analysis != null &&
        loadedSymbol == request.symbol.trim().toUpperCase() &&
        loadedMarket == request.market.trim().toUpperCase() &&
        (_analysis?.snapshot.snapshots.containsKey(requestedLevel) ?? false);
    setState(() {
      _researchOverlayNonce = request.nonce;
      _researchOverlayMarkers
        ..clear()
        ..addAll(overlayMarkers);
    });
    if (!hasRequestedData) {
      setState(() {
        _symbolController.text = request.symbol;
        _marketController.text = request.market;
        _selectedLevels
          ..clear()
          ..add(requestedLevel);
        _activeLevel = requestedLevel;
        _startDate = request.startDate ?? _startDate;
        _endDate = request.endDate ?? _endDate;
        _mode = 'once';
      });
      await _loadReplay();
      if (!mounted) return;
    }
    final snapshot = _analysis?.snapshot.of(requestedLevel);
    if (snapshot == null || snapshot.rawBars.isEmpty) {
      _showMessage('无法定位：$requestedLevel 没有K线数据');
      return;
    }
    var index = _barListIndexForRawIndex(snapshot, request.rawIndex);
    if (request.time != null) {
      final byTime = snapshot.rawBars.indexWhere(
        (bar) => !bar.time.isBefore(request.time!),
      );
      if (byTime >= 0) index = byTime;
    }
    final max = snapshot.rawBars.length - 1;
    setState(() {
      _activeLevel = requestedLevel;
      final requestedSpan = request.visibleStartRawIndex != null &&
              request.visibleEndRawIndex != null
          ? (request.visibleEndRawIndex! - request.visibleStartRawIndex!)
                  .abs() +
              1
          : 0;
      _windowSize = math
          .min(
            math.max(90, requestedSpan + 24),
            snapshot.rawBars.length,
          )
          .toInt();
      _viewEndIndex = (index + _windowSize ~/ 2).clamp(0, max).toInt();
      _crosshairIndex = index;
      _priceScale = 1.0;
      _priceOffset = 0.0;
      _chartGeneration++;
    });
    _showMessage(
        '${request.label.isEmpty ? '回测结果' : request.label}：已定位到 $requestedLevel raw=${request.rawIndex}');
  }

  List<Map<String, dynamic>> _researchMarkersFromRequest(
      KlineLocationRequest request) {
    final payload = request.analysisPayload;
    final rawMarkers =
        payload == null ? null : payload['_research_overlay_markers'];
    final rows = <Map<String, dynamic>>[];
    if (rawMarkers is List) {
      for (final marker in rawMarkers) {
        if (marker is Map) rows.add(Map<String, dynamic>.from(marker));
      }
    }
    if (rows.isEmpty) {
      rows.add(<String, dynamic>{
        'raw_index': request.rawIndex,
        'kind': request.label.contains('出') ? 'exit' : 'entry',
        'label': request.label.isEmpty ? 'research' : request.label,
        'ordinal': 1,
      });
    }
    final start = request.visibleStartRawIndex;
    final end = request.visibleEndRawIndex;
    if (start != null && end != null && start != end) {
      rows.addAll(<Map<String, dynamic>>[
        <String, dynamic>{
          'raw_index': start < end ? start : end,
          'kind': 'range_start',
          'label': 'range',
        },
        <String, dynamic>{
          'raw_index': start < end ? end : start,
          'kind': 'range_end',
          'label': 'range',
        },
      ]);
    }
    return rows;
  }

  bool get _supportsWindowManager =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<void> _syncWindowMaximizedState() async {
    if (!_supportsWindowManager || !mounted) return;
    final maximized = await windowManager.isMaximized();
    if (!mounted) return;
    setState(() => _windowMaximized = maximized);
  }

  Future<void> _minimizeWindow() async {
    if (_supportsWindowManager) {
      await windowManager.minimize();
    }
  }

  Future<void> _toggleWindowMaximizeRestore() async {
    if (!_supportsWindowManager) return;
    final maximized = await windowManager.isMaximized();
    if (maximized) {
      await windowManager.unmaximize();
      if (mounted) setState(() => _windowMaximized = false);
    } else {
      await windowManager.maximize();
      if (mounted) setState(() => _windowMaximized = true);
    }
  }

  Future<void> _closeWindow() async {
    if (_supportsWindowManager) {
      await windowManager.close();
    }
  }

  String _chanConfigFingerprint() {
    final entries = ChanConfigStore.values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final valuesText =
        entries.map((entry) => '${entry.key}=${entry.value}').join('|');
    return '$valuesText|level_promoter_max_level=${LevelPromoterSettings.currentMaxLayer}';
  }

  void _handleGlobalChanConfigChanged() {
    if (!mounted) return;

    final currentFingerprint = _chanConfigFingerprint();
    final hasLoadedReplay = _analysis != null;
    final dirty =
        hasLoadedReplay && currentFingerprint != _loadedChanConfigFingerprint;

    if (_chanConfigDirtySinceLoad != dirty) {
      setState(() {
        _chanConfigDirtySinceLoad = dirty;
        if (dirty) {
          _status = '缠论设置已变更，请重新加载';
        }
      });
    } else if (dirty && _status != '缠论设置已变更，请重新加载') {
      setState(() => _status = '缠论设置已变更，请重新加载');
    }

    if (dirty) {
      _showChanConfigChangedSnack();
    }
  }

  void _showChanConfigChangedSnack() {
    _chanConfigChangeSnackTimer?.cancel();
    _chanConfigChangeSnackTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('缠论设置已变更，请重新加载'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  DateTime get _defaultEndDate => _defaultEndDateValue;
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
      recursiveSegLayers: s.recursiveSegLayers,
      recursiveSegBsps: s.recursiveSegBsps,
      recursiveSegBspCandidates: s.recursiveSegBspCandidates,
      recursiveSegZss: s.recursiveSegZss,
      zss: s.zss,
      bsps: <BspPoint>[...trail, ...s.bsps],
      segZss: s.segZss,
      eigenBoxes: s.eigenBoxes,
      segEigenBoxes: s.segEigenBoxes,
      indicators: s.indicators,
      rhythmLines: s.rhythmLines,
      rhythmHits: s.rhythmHits,
    );
  }

  int get _bspCandidateTrailCount {
    final s = _activeSnapshot;
    return s == null ? 0 : _bspCandidateTrail(s).length;
  }

  String _bspReviewSide(BspPoint p) =>
      p.isSell ? 'sell' : (p.isBuy ? 'buy' : 'bsp');

  String _bspReviewSideText(BspPoint p) =>
      p.isSell ? '卖' : (p.isBuy ? '买' : '点');

  String _bspReviewJudgeKey(String level, BspPoint p) =>
      '${level.trim().toUpperCase()}|${p.rawIndex}|${_bspReviewSide(p)}';

  BspReviewStatus _bspReviewStatusFor(String judgeKey) {
    if (_bspStepReviewCorrectKeys.contains(judgeKey)) {
      return BspReviewStatus.correct;
    }
    if (_bspStepReviewWrongKeys.contains(judgeKey)) {
      return BspReviewStatus.wrong;
    }
    return BspReviewStatus.pending;
  }

  List<BspStepReviewItem> get _currentBspStepReviewItems {
    if (!_hasStepFrames) return const <BspStepReviewItem>[];
    final rows = <BspStepReviewItem>[];
    for (final observation in _snapshotBspObservationsWithTrail(_activeLevel)) {
      final bsp = observation.bsp;
      final judgeKey = _bspReviewJudgeKey(_activeLevel, bsp);
      final baseType = _baseBspType(bsp);
      final item = _bspStepReviewItems.putIfAbsent(
        judgeKey,
        () => BspStepReviewItem(
          key: '${observation.bspKey}|${observation.bspSourceFrame}',
          judgeKey: judgeKey,
          level: _activeLevel,
          anchorRawIndex: bsp.rawIndex,
          displayRawIndex: bsp.rawIndex,
          isBuy: !bsp.isSell,
          label: baseType,
          displayLabel: '${_bspReviewSideText(bsp)}$baseType',
          firstFrameIndex: observation.bspSourceFrame < 0
              ? _safeFrameIndex
              : observation.bspSourceFrame,
        ),
      );
      rows.add(item.copyWith(status: _bspReviewStatusFor(judgeKey)));
    }
    rows.sort((a, b) {
      if (a.displayRawIndex != b.displayRawIndex) {
        return a.displayRawIndex.compareTo(b.displayRawIndex);
      }
      return a.judgeKey.compareTo(b.judgeKey);
    });
    return rows;
  }

  List<BspBottomLabel> get _bspBottomLabels {
    final rows = <BspBottomLabel>[];
    for (final observation in _snapshotBspObservationsWithTrail(_activeLevel)) {
      final bsp = observation.bsp;
      final visualLevel = _bspVisualLevel(bsp);
      final judgeKey = _bspReviewJudgeKey(_activeLevel, bsp);
      rows.add(BspBottomLabel(
        rawIndex: bsp.rawIndex,
        anchorRawIndex: bsp.rawIndex,
        text: BspChartLabelAdapter.labelTextFor(
          levelPrefix: visualLevel,
          bsp: bsp,
        ),
        isBuy: bsp.isBuy,
        status: _bspReviewStatusFor(judgeKey),
        level: visualLevel,
      ));
    }
    final snap = _activeSnapshot;
    if (snap != null) {
      for (final entry in snap.recursiveSegBsps.entries) {
        final layer = entry.key;
        if (layer < 2) continue;
        final visualLevel = '${layer}段';
        for (final bsp in entry.value) {
          rows.add(BspBottomLabel(
            rawIndex: bsp.rawIndex,
            anchorRawIndex: bsp.rawIndex,
            text: BspChartLabelAdapter.labelTextFor(
              levelPrefix: visualLevel,
              bsp: bsp,
            ),
            isBuy: bsp.isBuy,
            status: BspReviewStatus.pending,
            level: visualLevel,
          ));
        }
      }
    }
    rows.sort((a, b) {
      if (a.rawIndex != b.rawIndex) return a.rawIndex.compareTo(b.rawIndex);
      return _bspVisualRank(a.level).compareTo(_bspVisualRank(b.level));
    });
    return rows;
  }

  String _bspVisualLevel(BspPoint p) => _isVisualSegBsp(p) ? '段' : '笔';

  bool _isVisualSegBsp(BspPoint p) {
    final level = p.level.trim().toLowerCase();
    return level == 'seg' || level == 'segment' || level.contains('seg');
  }

  int _bspVisualRank(String level) {
    final text = level.trim();
    if (text == '笔') return 0;
    if (text == '段') return 1;
    final match = RegExp(r'^(\d+)段$').firstMatch(text);
    if (match != null) return int.tryParse(match.group(1) ?? '') ?? 2;
    return text.contains('段') ? 1 : 0;
  }

  BspReviewStats get _bspReviewStats {
    final items = _currentBspStepReviewItems;
    final judged =
        items.where((item) => item.status != BspReviewStatus.pending).length;
    final correct =
        items.where((item) => item.status == BspReviewStatus.correct).length;
    final wrong =
        items.where((item) => item.status == BspReviewStatus.wrong).length;
    return BspReviewStats(
      appeared: items.length,
      judged: judged,
      correct: correct,
      wrong: wrong,
      rate: judged == 0 ? null : correct / judged,
      fromFrame: items.isEmpty
          ? _safeFrameIndex
          : items.map((item) => item.firstFrameIndex).reduce(math.min),
      toFrame: _safeFrameIndex,
      fromTime: _activeSnapshot?.rawBars.isEmpty == false
          ? _activeSnapshot!.rawBars.first.time
          : null,
      toTime: _activeSnapshot?.rawBars.isEmpty == false
          ? _activeSnapshot!.rawBars.last.time
          : null,
      reason: _hasStepFrames
          ? (_autoJudgeBspStepReview ? 'auto_step' : 'manual_current_frame')
          : 'not_step_mode',
    );
  }

  List<BspReviewBucketStats> get _bspReviewBucketStats {
    final buckets = <String, BspReviewBucketStats>{};
    for (final item in _bspStepReviewItems.values) {
      final status = _bspReviewStatusFor(item.judgeKey);
      final side = item.isBuy ? 'buy' : 'sell';
      final key = '${item.level}|$side|${item.label}';
      final current = buckets[key] ??
          BspReviewBucketStats(
            key: key,
            level: item.level,
            side: side,
            label: item.label,
          );
      buckets[key] = current.copyWith(
        appeared: current.appeared + 1,
        judged: current.judged + (status == BspReviewStatus.pending ? 0 : 1),
        correct: current.correct + (status == BspReviewStatus.correct ? 1 : 0),
        wrong: current.wrong + (status == BspReviewStatus.wrong ? 1 : 0),
      );
    }
    final rows = buckets.values.toList(growable: false);
    rows.sort((a, b) {
      if (a.level != b.level) return a.level.compareTo(b.level);
      if (a.side != b.side) return a.side.compareTo(b.side);
      return a.label.compareTo(b.label);
    });
    return rows;
  }

  String _bspReviewBucketStatsText() {
    final rows = _bspReviewBucketStats;
    if (rows.isEmpty) return 'bucket=none';
    return rows.map((row) {
      final rate =
          row.rate == null ? 'N/A' : '${(row.rate! * 100).toStringAsFixed(1)}%';
      return '${row.level}/${row.side}/${row.label}:${row.correct}/${row.judged}/$rate';
    }).join(' | ');
  }

  String _bspReviewStatsText() {
    final stats = _bspReviewStats;
    final rate = stats.rate == null
        ? 'N/A'
        : '${(stats.rate! * 100).toStringAsFixed(1)}%';
    return 'appeared=${stats.appeared} judged=${stats.judged} correct=${stats.correct} wrong=${stats.wrong} rate=$rate frame=${stats.fromFrame + 1}~${stats.toFrame + 1} reason=${stats.reason}';
  }

  int _updateCurrentBspStepReviews({required bool notify}) {
    if (!_hasStepFrames) {
      if (notify) _showInfo('请先以 step 模式载入复盘数据。');
      return 0;
    }
    final finalSnapshot = _analysis?.snapshot.of(_activeLevel);
    if (finalSnapshot == null || finalSnapshot.bsps.isEmpty) {
      if (notify) _showInfo('最终快照没有可用于对照的 BSP。');
      return 0;
    }
    final items = _currentBspStepReviewItems;
    if (items.isEmpty) {
      if (notify) _showInfo('当前帧没有可检查的 BSP。');
      return 0;
    }
    final finalJudgeKeys = <String>{
      for (final p in finalSnapshot.bsps) _bspReviewJudgeKey(_activeLevel, p),
    };
    var changed = 0;
    setState(() {
      for (final item in items) {
        final wasCorrect = _bspStepReviewCorrectKeys.contains(item.judgeKey);
        final wasWrong = _bspStepReviewWrongKeys.contains(item.judgeKey);
        final isCorrect = finalJudgeKeys.contains(item.judgeKey);
        if (isCorrect) {
          _bspStepReviewCorrectKeys.add(item.judgeKey);
          _bspStepReviewWrongKeys.remove(item.judgeKey);
        } else {
          _bspStepReviewWrongKeys.add(item.judgeKey);
          _bspStepReviewCorrectKeys.remove(item.judgeKey);
        }
        final nowCorrect = _bspStepReviewCorrectKeys.contains(item.judgeKey);
        final nowWrong = _bspStepReviewWrongKeys.contains(item.judgeKey);
        if (wasCorrect != nowCorrect || wasWrong != nowWrong) changed++;
      }
    });
    if (notify) {
      _showInfo(
          '当前买卖点检查完成\n${_bspReviewStatsText()}\n${_bspReviewBucketStatsText()}');
    }
    return changed;
  }

  void _judgeCurrentBspStepReviews() =>
      _updateCurrentBspStepReviews(notify: true);

  List<BspStepReviewItem> get _allBspStepReviewItems {
    final rows = _bspStepReviewItems.values
        .map(
            (item) => item.copyWith(status: _bspReviewStatusFor(item.judgeKey)))
        .toList(growable: false);
    rows.sort((a, b) {
      if (a.level != b.level) return a.level.compareTo(b.level);
      if (a.displayRawIndex != b.displayRawIndex) {
        return a.displayRawIndex.compareTo(b.displayRawIndex);
      }
      return a.judgeKey.compareTo(b.judgeKey);
    });
    return rows;
  }

  Map<String, dynamic> _bspReviewReportJson() {
    final stats = _bspReviewStats;
    return <String, dynamic>{
      'schema': 'chan_replay_app.bsp_review_report.v1',
      'generated_at': DateTime.now().toIso8601String(),
      'symbol': _symbolController.text.trim(),
      'market': _marketController.text.trim().toUpperCase(),
      'mode': _mode,
      'active_level': _activeLevel,
      'selected_levels': _normalizedLevels,
      'loaded_levels': _loadedLevels,
      'runtime_path': RuntimePathController.current.wireName,
      'window': _effectiveWindowText,
      'frame_index': _safeFrameIndex,
      'frame_count': _frameCount,
      'auto_judge': _autoJudgeBspStepReview,
      'judge_key': 'level|rawIndex|side',
      'stats': <String, dynamic>{
        'appeared': stats.appeared,
        'judged': stats.judged,
        'correct': stats.correct,
        'wrong': stats.wrong,
        'rate': stats.rate,
        'reason': stats.reason,
      },
      'buckets': <Map<String, dynamic>>[
        for (final row in _bspReviewBucketStats)
          <String, dynamic>{
            'key': row.key,
            'level': row.level,
            'side': row.side,
            'label': row.label,
            'appeared': row.appeared,
            'judged': row.judged,
            'correct': row.correct,
            'wrong': row.wrong,
            'rate': row.rate,
          },
      ],
      'items': <Map<String, dynamic>>[
        for (final item in _allBspStepReviewItems)
          <String, dynamic>{
            'key': item.key,
            'judge_key': item.judgeKey,
            'level': item.level,
            'display_raw_index': item.displayRawIndex,
            'anchor_raw_index': item.anchorRawIndex,
            'side': item.isBuy ? 'buy' : 'sell',
            'label': item.label,
            'display_label': item.displayLabel,
            'first_frame_index': item.firstFrameIndex,
            'status': item.status.name,
          },
      ],
    };
  }

  String _bspReviewReportText() {
    final stats = _bspReviewStats;
    final rate = stats.rate == null
        ? 'N/A'
        : '${(stats.rate! * 100).toStringAsFixed(1)}%';
    final buffer = StringBuffer()
      ..writeln('BSP_STEP_REVIEW_REPORT')
      ..writeln('generated_at=${DateTime.now().toIso8601String()}')
      ..writeln('symbol=${_symbolController.text.trim()}')
      ..writeln('market=${_marketController.text.trim().toUpperCase()}')
      ..writeln('mode=$_mode')
      ..writeln('active_level=$_activeLevel')
      ..writeln('frame=${_safeFrameIndex + 1}/$_frameCount')
      ..writeln('auto_judge=$_autoJudgeBspStepReview')
      ..writeln('judge_key=level|rawIndex|side')
      ..writeln(
          'stats appeared=${stats.appeared} judged=${stats.judged} correct=${stats.correct} wrong=${stats.wrong} rate=$rate')
      ..writeln('buckets=${_bspReviewBucketStatsText()}')
      ..writeln('items:');
    for (final item in _allBspStepReviewItems) {
      buffer.writeln(
          '${item.status.name} ${item.level} raw=${item.displayRawIndex} ${item.isBuy ? 'buy' : 'sell'} ${item.label} ${item.judgeKey}');
    }
    return buffer.toString();
  }

  Future<void> _copyBspReviewReport() async {
    final report = _bspReviewReportText();
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    _showInfo('BSP 检查报告已复制\n${report.split('\n').take(10).join('\n')}');
  }

  Future<void> _exportBspReviewReportJson() async {
    final reportText = _bspReviewReportText();
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: reportText));
      if (!mounted) return;
      _showInfo('Web 环境暂不写本地文件，已复制 BSP 检查报告。');
      return;
    }
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/chan_replay_bsp_reports');
      if (!await dir.exists()) await dir.create(recursive: true);
      final symbol = _symbolController.text.trim().isEmpty
          ? 'UNKNOWN'
          : _symbolController.text.trim();
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '')
          .replaceAll('.', '');
      final file =
          File('${dir.path}/bsp_review_${symbol}_${_activeLevel}_$stamp.json');
      final jsonText =
          const JsonEncoder.withIndent('  ').convert(_bspReviewReportJson());
      await file.writeAsString(jsonText);
      if (!mounted) return;
      _showInfo('BSP 检查 JSON 已导出\n${file.path}');
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: reportText));
      if (!mounted) return;
      _showInfo('BSP 报告导出失败，已复制文本报告。错误：$e');
    }
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
      buy: p.buy,
      source: p.source,
      derived: p.derived,
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

  void _openDrawingToolbox({
    TradingViewDrawingTool tool = TradingViewDrawingTool.trendLine,
  }) {
    _toolboxSelectedToolSignal.value = tool;
    _toolboxOpenSignal.value++;
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
      return _LevelValidationResult(false, n, '请至少选择一个级别');
    }
    final bad =
        raw.where((l) => !_levelOptionSet.contains(l)).toList(growable: false);
    if (bad.isNotEmpty) {
      return _LevelValidationResult(false, n, '存在无效级别: ${bad.join(',')}');
    }
    if (raw.toSet().length != raw.length) {
      return _LevelValidationResult(false, n, '级别不能重复');
    }
    if (n.length == 1) {
      return _LevelValidationResult(true, n, '单级别模式: ${n.first}');
    }
    if (n.length != raw.length) {
      return _LevelValidationResult(true, n, '级别已规范化: ${n.join(',')}');
    }
    return _LevelValidationResult(true, n, '级别组合有效: ${n.join(',')}');
  }

  String _requestModeFor(_LevelValidationResult lv) => _mode;

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
    final requestConfigFingerprint = _chanConfigFingerprint();
    final requestRhythmSettings = _rhythmSettings;
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
            ...requestRhythmSettings.backendCalculationConfig,
            'rhythm_max_lines': 160,
            'rhythm_max_hits_per_line': 3,
          });
      if (!mounted) return;
      setState(() {
        _analysis = a;
        _loadedRhythmCalcMode = requestRhythmSettings.calcMode;
        _loadedRhythmEnabled = requestRhythmSettings.enabled;
        _loadedChanConfigFingerprint = requestConfigFingerprint;
        _chanConfigDirtySinceLoad =
            _chanConfigFingerprint() != requestConfigFingerprint;
        _frameIndex = 0;
        final init = _currentSnapshot ?? a.snapshot;
        _activeLevel = init.safeActiveLevel;
        final initialActive = init.of(_activeLevel);
        _viewEndIndex = initialActive == null || initialActive.rawBars.isEmpty
            ? null
            : initialActive.rawBars.length - 1;
        _windowSize = initialActive == null
            ? 90
            : math.min(240, initialActive.rawBars.length);
        _crosshairIndex = null;
        _priceScale = 1.0;
        _priceOffset = 0.0;
        _bspStepReviewItems.clear();
        _bspStepReviewCorrectKeys.clear();
        _bspStepReviewWrongKeys.clear();
        _chartGeneration++;
        _status = _buildStatus(a, startDate, endDate);
      });
      if (_autoJudgeBspStepReview) {
        _updateCurrentBspStepReviews(notify: false);
      }
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
      _priceOffset = 0.0;
      _bspStepReviewItems.clear();
      _bspStepReviewCorrectKeys.clear();
      _bspStepReviewWrongKeys.clear();
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
      _priceOffset = 0.0;
      final activeBiCount = f.of(level)?.bis.length ?? 0;
      _status =
          'S13 step frame ${next + 1}/${a.frames.length} active:$level active_bi:$activeBiCount loaded_config:{${_loadedChanConfigSummary(a)}} final_bi_counts:{${_biCountSummary(a.snapshot)}} current_bi_counts:{${_biCountSummary(f)}} relations:${f.relations.length} nested_markers:${_nestedBspMarkers.length} candidate_trail:$_bspCandidateTrailCount missing_edges:${_missingAdjacentRelationEdges().join(',')} bsp_review:{${_bspReviewStatsText()}}';
    });
    if (_autoJudgeBspStepReview) {
      _updateCurrentBspStepReviews(notify: false);
    }
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
      _priceOffset = 0.0;
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
      _priceOffset = 0.0;
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
            ],
          ),
        ),
      );

  Future<void> _copyCurrentS13Settings() async {
    await Clipboard.setData(
      ClipboardData(text: _currentS13SettingsEvidenceText()),
    );
    if (!mounted) return;
    _showMessage('当前全部设置已复制');
  }

  List<({int layer, BspPoint bsp})> get _recursiveRealBspResults {
    final snapshot = _activeSnapshot;
    if (snapshot == null) return const [];
    final rows = <({int layer, BspPoint bsp})>[
      for (final entry in snapshot.recursiveSegBsps.entries)
        for (final bsp in entry.value) (layer: entry.key, bsp: bsp),
    ];
    rows.sort((a, b) => b.bsp.rawIndex.compareTo(a.bsp.rawIndex));
    return rows;
  }

  int _barListIndexForRawIndex(ChanSnapshot snapshot, int rawIndex) {
    for (var i = 0; i < snapshot.rawBars.length; i++) {
      if (snapshot.rawBars[i].index == rawIndex) return i;
    }
    return rawIndex.clamp(0, snapshot.rawBars.length - 1).toInt();
  }

  void _jumpToRecursiveBsp(int layer, BspPoint bsp) {
    final snapshot = _activeSnapshot;
    if (snapshot == null || snapshot.rawBars.isEmpty) return;
    final index = _barListIndexForRawIndex(snapshot, bsp.rawIndex);
    final max = snapshot.rawBars.length - 1;
    setState(() {
      _windowSize = math.min(180, snapshot.rawBars.length);
      _viewEndIndex = (index + _windowSize ~/ 3).clamp(0, max).toInt();
      _crosshairIndex = index;
      _priceScale = 1.0;
      _priceOffset = 0.0;
    });
    _showMessage('$layer段 ${bsp.type}：已定位 raw=${bsp.rawIndex}');
  }

  void _resetChartToLatest() {
    final snapshot = _activeSnapshot;
    if (snapshot == null || snapshot.rawBars.isEmpty) return;
    setState(() {
      _windowSize = math.min(240, snapshot.rawBars.length);
      _viewEndIndex = snapshot.rawBars.length - 1;
      _crosshairIndex = null;
      _priceScale = 1.0;
      _priceOffset = 0.0;
    });
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _chartEvidenceTime(DateTime time) {
    return '${time.year}-${_twoDigits(time.month)}-${_twoDigits(time.day)} '
        '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
  }

  String _snapshotTimeRange(ChanSnapshot? snapshot) {
    if (snapshot == null || snapshot.rawBars.isEmpty) return 'none';
    return '${_chartEvidenceTime(snapshot.rawBars.first.time)}'
        '~${_chartEvidenceTime(snapshot.rawBars.last.time)}';
  }

  String _visibleWindowTimeRange(ChanSnapshot? snapshot) {
    if (snapshot == null || snapshot.rawBars.isEmpty) return 'none';
    final max = snapshot.rawBars.length - 1;
    final end = (_viewEndIndex ?? max).clamp(0, max).toInt();
    final safeWindowSize = _windowSize < 1 ? 1 : _windowSize;
    final start = (end - safeWindowSize + 1).clamp(0, end).toInt();
    return '${_chartEvidenceTime(snapshot.rawBars[start].time)}'
        '~${_chartEvidenceTime(snapshot.rawBars[end].time)}';
  }

  String _timeForRawIndex(ChanSnapshot snapshot, int rawIndex) {
    if (snapshot.rawBars.isEmpty) return 'none';
    for (final bar in snapshot.rawBars) {
      if (bar.index == rawIndex) return _chartEvidenceTime(bar.time);
    }

    var nearest = snapshot.rawBars.first;
    var nearestDistance = (nearest.index - rawIndex).abs();
    for (final bar in snapshot.rawBars.skip(1)) {
      final distance = (bar.index - rawIndex).abs();
      if (distance < nearestDistance) {
        nearest = bar;
        nearestDistance = distance;
      }
    }
    return '${_chartEvidenceTime(nearest.time)}(nearest)';
  }

  String _biZsTimeSample(ChanSnapshot? snapshot) {
    if (snapshot == null || snapshot.zss.isEmpty) return 'none';
    return <String>[
      for (final zs in snapshot.zss)
        '笔@${_timeForRawIndex(snapshot, zs.startRawIndex)}'
            '~${_timeForRawIndex(snapshot, zs.endRawIndex)}'
            ':zg=${zs.zg}:zd=${zs.zd}',
    ].take(12).join(',');
  }

  String _nativeSegZsTimeSample(ChanSnapshot? snapshot) {
    if (snapshot == null || snapshot.segZss.isEmpty) return 'none';
    return <String>[
      for (final zs in snapshot.segZss)
        '段@${_timeForRawIndex(snapshot, zs.startRawIndex)}'
            '~${_timeForRawIndex(snapshot, zs.endRawIndex)}'
            ':zg=${zs.zg}:zd=${zs.zd}',
    ].take(12).join(',');
  }

  String _recursiveZsTimeSample(ChanSnapshot? snapshot) {
    if (snapshot == null || snapshot.recursiveSegZss.isEmpty) return 'none';
    final layers = snapshot.recursiveSegZss.keys.toList()..sort();
    final rows = <String>[
      for (final layer in layers)
        for (final zs in snapshot.recursiveSegZss[layer] ?? const [])
          '$layer段@${_timeForRawIndex(snapshot, zs.startRawIndex)}'
              '~${_timeForRawIndex(snapshot, zs.endRawIndex)}'
              ':zg=${zs.zg}:zd=${zs.zd}',
    ].take(12).toList();
    return rows.isEmpty ? 'none' : rows.join(',');
  }

  String _recursiveBspTimeSample(ChanSnapshot? snapshot) {
    if (snapshot == null || snapshot.recursiveSegBsps.isEmpty) return 'none';
    final layers = snapshot.recursiveSegBsps.keys.toList()..sort();
    final rows = <String>[
      for (final layer in layers)
        for (final bsp
            in snapshot.recursiveSegBsps[layer] ?? const <BspPoint>[])
          '$layer段@${_timeForRawIndex(snapshot, bsp.rawIndex)}:${bsp.type}',
    ].take(12).toList();
    return rows.isEmpty ? 'none' : rows.join(',');
  }

  String _chipNumber(num value) {
    if (!value.isFinite) return 'nan';
    final abs = value.abs();
    if (abs >= 1000000) return value.toStringAsFixed(2);
    if (abs >= 1000) return value.toStringAsFixed(4);
    return value.toStringAsFixed(6);
  }

  String _chipTargetSource(ChanSnapshot snapshot, int targetIndex) {
    if (_hasStepFrames) {
      final maxAllowed =
          _safeFrameIndex.clamp(0, snapshot.rawBars.length - 1).toInt();
      if (_crosshairIndex != null && _crosshairIndex! <= maxAllowed) {
        return 'step_crosshair';
      }
      if (_crosshairIndex != null && _crosshairIndex! > maxAllowed) {
        return 'step_clamped';
      }
      return 'step_frame';
    }
    if (_crosshairIndex != null) return 'crosshair';
    if (_viewEndIndex != null) return 'view_end';
    return 'last_bar';
  }

  Map<String, String> _chipDistributionEvidence(ChanSnapshot? snapshot) {
    final chipSettings = ChipDistributionSettingsController.current;
    final binCount = chipSettings.priceBucketCount;
    const lookback = 1000000;
    const ageDecay = 0.0;
    if (snapshot == null || snapshot.rawBars.isEmpty) {
      return <String, String>{
        'enabled': '$_showChipDistribution',
        'available': 'false',
        'target_source': 'none',
        'target_index': 'none',
        'target_time': 'none',
        'total_bars': '0',
        'input_mode': 'none',
        'bin_count': '$binCount',
        'bin_count_source': 'global_chip_distribution_settings',
        'minimal_ui': 'price_bucket_count_only',
        'lookback': '$lookback',
        'age_decay': '$ageDecay',
        'total_weight': '0',
        'poc_price': '0',
        'average_cost': '0',
        'profit_ratio': '0',
        'step_no_future': 'true',
      };
    }

    final bars = ChipOnlineReplayAdapter.fromSnapshot(snapshot);
    final targetIndex = ChipOnlineReplayAdapter.resolveTargetIndex(
      total: bars.length,
      isStepMode: _hasStepFrames,
      stepIndex: _safeFrameIndex,
      crosshairIndex: _crosshairIndex,
      viewEndIndex: _viewEndIndex,
    );
    final targetBar = snapshot.rawBars[targetIndex];
    final scopedBars = bars.take(targetIndex + 1).toList(growable: false);
    final hasExact = scopedBars.any((bar) => bar.hasExactChipBins);
    final hasFallback = scopedBars.any((bar) => !bar.hasExactChipBins);
    final inputMode = hasExact && hasFallback
        ? 'mixed'
        : (hasExact ? 'exact_tick_bins' : 'ohlcv_fallback');
    final result = const ChipDistributionEngine().calculate(
      bars,
      targetIndex: targetIndex,
      options: ChipDistributionOptions(
        binCount: binCount,
        lookback: lookback,
        ageDecay: ageDecay,
      ),
    );
    final stepMaxAllowed =
        _safeFrameIndex.clamp(0, snapshot.rawBars.length - 1).toInt();
    final stepNoFuture = !_hasStepFrames || targetIndex <= stepMaxAllowed;

    return <String, String>{
      'enabled': '$_showChipDistribution',
      'available': '${!result.isEmpty}',
      'target_source': _chipTargetSource(snapshot, targetIndex),
      'target_index': '$targetIndex',
      'target_time': _chartEvidenceTime(targetBar.time),
      'total_bars': '${snapshot.rawBars.length}',
      'input_mode': inputMode,
      'bin_count': '$binCount',
      'bin_count_source': 'global_chip_distribution_settings',
      'minimal_ui': 'price_bucket_count_only',
      'lookback': '$lookback',
      'age_decay': '$ageDecay',
      'total_weight': _chipNumber(result.totalWeight),
      'poc_price': _chipNumber(result.pocPrice),
      'average_cost': _chipNumber(result.averageCost),
      'profit_ratio': _chipNumber(result.profitRatio),
      'step_no_future': '$stepNoFuture',
    };
  }

  String _currentS13SettingsEvidenceText() {
    final active = _activeSnapshot;
    final current = _currentSnapshot;
    final rhythm = _rhythmSummaryFor(active);
    final startDate = _dateOrDefault(_startDate, _defaultStartDate);
    final endDate = _dateOrDefault(_endDate, _defaultEndDate);
    final chanEntries = ChanConfigStore.values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final recursiveLayers = <int>{
      ...?active?.recursiveSegLayers.keys,
      ...?active?.recursiveSegZss.keys,
      ...?active?.recursiveSegBsps.keys,
      ...?active?.recursiveSegBspCandidates.keys,
    }.toList()
      ..sort();
    String recursiveCounts<T>(Map<int, List<T>>? values) => recursiveLayers
        .map((layer) => '$layer:${values?[layer]?.length ?? 0}')
        .join(',');
    final recursiveBspSample = <String>[
      for (final layer in recursiveLayers)
        for (final bsp in active?.recursiveSegBsps[layer] ?? const <BspPoint>[])
          '$layer段@${bsp.rawIndex}:${bsp.type}',
    ].take(12).join(',');
    final visibleRecursiveZsLayers = <int>[
      if (_showSeg2Zs) 2,
      if (_showSegNZs)
        for (var layer = 3;
            layer <= LevelPromoterSettings.currentMaxLayer;
            layer++)
          layer,
    ].join(',');
    final activeDataTimeRange = _snapshotTimeRange(active);
    final visibleWindowTimeRange = _visibleWindowTimeRange(active);
    final activeBiZsTimeSample = _biZsTimeSample(active);
    final activeSegZsTimeSample = _nativeSegZsTimeSample(active);
    final recursiveZsTimeSample = _recursiveZsTimeSample(active);
    final recursiveBspTimeSample = _recursiveBspTimeSample(active);
    final chipEvidence = _chipDistributionEvidence(active);

    final buffer = StringBuffer()
      ..writeln('S13_CURRENT_SETTINGS_EVIDENCE')
      ..writeln('generated_at=${DateTime.now().toIso8601String()}')
      ..writeln()
      ..writeln('[状态]')
      ..writeln('status=$_status')
      ..writeln('last_level_validation=$_lastLevelValidation')
      ..writeln('chan_config_dirty_since_load=$_chanConfigDirtySinceLoad')
      ..writeln('loaded_chan_config_fingerprint=$_loadedChanConfigFingerprint')
      ..writeln('current_chan_config_fingerprint=${_chanConfigFingerprint()}')
      ..writeln()
      ..writeln('[股票]')
      ..writeln('backend=${_backendUrlController.text}')
      ..writeln('symbol=${_symbolController.text}')
      ..writeln('market=${_marketController.text}')
      ..writeln('start=${_fmtDate(startDate)}')
      ..writeln('end=${_fmtDate(endDate)}')
      ..writeln('effective_window=$_effectiveWindowText')
      ..writeln('runtime_path=${RuntimePathController.current.wireName}')
      ..writeln()
      ..writeln('[模式 / 级别]')
      ..writeln('mode=$_mode')
      ..writeln('selected_levels=${_normalizedLevels.join(',')}')
      ..writeln('loaded_levels=${_loadedLevels.join(',')}')
      ..writeln('active_level=$_activeLevel')
      ..writeln()
      ..writeln('[复盘]')
      ..writeln('loading=$_loading')
      ..writeln('playing=$_playing')
      ..writeln('play_speed=$_playSpeed')
      ..writeln('frame_index=$_frameIndex')
      ..writeln('safe_frame_index=$_safeFrameIndex')
      ..writeln('frame_count=$_frameCount')
      ..writeln('step_frame_label=$_stepFrameLabel')
      ..writeln('has_step_frames=$_hasStepFrames')
      ..writeln('current_frame_source=$_currentFrameSource')
      ..writeln()
      ..writeln('[图表视口]')
      ..writeln('window_size=$_windowSize')
      ..writeln('view_end_index=${_viewEndIndex ?? 'auto'}')
      ..writeln('crosshair_index=${_crosshairIndex ?? 'none'}')
      ..writeln('price_scale=$_priceScale')
      ..writeln('price_offset=$_priceOffset')
      ..writeln('visible_window_time_range=$visibleWindowTimeRange')
      ..writeln()
      ..writeln('[图层]')
      ..writeln('show_bsp_candidate_trail=$_showBspCandidateTrail')
      ..writeln('show_rhythm_lines=$_showRhythmLines')
      ..writeln('show_1382_hits=$_show1382Hits')
      ..writeln('show_chip_distribution=$_showChipDistribution')
      ..writeln('show_native_zs=$_showNativeZs')
      ..writeln('show_seg2_zs=$_showSeg2Zs')
      ..writeln('show_seg_n_zs=$_showSegNZs')
      ..writeln(
          'visible_recursive_zs_layers=${visibleRecursiveZsLayers.isEmpty ? 'none' : visibleRecursiveZsLayers}')
      ..writeln(
          'easy_tdx_indicators=${_enabledEasyTdxIndicators.toList()..sort()}')
      ..writeln()
      ..writeln('[筹码分布]')
      ..writeln("chip_enabled=${chipEvidence['enabled']}")
      ..writeln("chip_available=${chipEvidence['available']}")
      ..writeln("chip_target_source=${chipEvidence['target_source']}")
      ..writeln("chip_target_index=${chipEvidence['target_index']}")
      ..writeln("chip_target_time=${chipEvidence['target_time']}")
      ..writeln("chip_total_bars=${chipEvidence['total_bars']}")
      ..writeln("chip_input_mode=${chipEvidence['input_mode']}")
      ..writeln("chip_bin_count=${chipEvidence['bin_count']}")
      ..writeln("chip_bin_count_source=${chipEvidence['bin_count_source']}")
      ..writeln("chip_minimal_ui=${chipEvidence['minimal_ui']}")
      ..writeln("chip_lookback=${chipEvidence['lookback']}")
      ..writeln("chip_age_decay=${chipEvidence['age_decay']}")
      ..writeln("chip_total_weight=${chipEvidence['total_weight']}")
      ..writeln("chip_poc_price=${chipEvidence['poc_price']}")
      ..writeln("chip_average_cost=${chipEvidence['average_cost']}")
      ..writeln("chip_profit_ratio=${chipEvidence['profit_ratio']}")
      ..writeln("chip_step_no_future=${chipEvidence['step_no_future']}")
      ..writeln()
      ..writeln('[节奏线设置]')
      ..writeln('loaded_rhythm_enabled=${_loadedRhythmEnabled ?? 'not_loaded'}')
      ..writeln('loaded_rhythm_calc_mode=$_loadedRhythmCalcMode')
      ..writeln('rhythm_enabled=${_rhythmSettings.enabled}')
      ..writeln('rhythm_calc_mode=${_rhythmSettings.calcMode}')
      ..writeln('rhythm_max_layer=${_rhythmSettings.maxLayer}')
      ..writeln('rhythm_fract_to_bi=${_rhythmSettings.fractToBiEnabled}')
      ..writeln('rhythm_bi_to_seg=${_rhythmSettings.biToSegEnabled}')
      ..writeln('rhythm_seg_to_segseg=${_rhythmSettings.segToSegsegEnabled}')
      ..writeln(
          'rhythm_show_sequence_numbers=${_rhythmSettings.showSequenceNumbers}')
      ..writeln('hit_enabled=${_rhythmSettings.hit.enabled}')
      ..writeln('hit_color=${_rhythmSettings.hit.color}')
      ..writeln('hit_line_width=${_rhythmSettings.hit.lineWidth}')
      ..writeln('hit_overflow_limit=${_rhythmSettings.hit.overflowLimit}')
      ..writeln('hit_dashed=${_rhythmSettings.hit.dashed}')
      ..writeln('hit_font_size=${_rhythmSettings.hit.fontSize}')
      ..writeln('rhythm_line_count=${rhythm.lineCount}')
      ..writeln('rhythm_hit_count=${rhythm.hitCount}')
      ..writeln('rhythm_short=${rhythm.shortText}')
      ..writeln()
      ..writeln('[当前数据]')
      ..writeln('has_analysis=${_analysis != null}')
      ..writeln('has_current_snapshot=${current != null}')
      ..writeln('has_active_snapshot=${active != null}')
      ..writeln('active_raw_bars=${active?.rawBars.length ?? 0}')
      ..writeln('active_data_time_range=$activeDataTimeRange')
      ..writeln('active_bi_count=${active?.bis.length ?? 0}')
      ..writeln('active_seg_count=${active?.segs.length ?? 0}')
      ..writeln('active_zs_count=${active?.zss.length ?? 0}')
      ..writeln('active_bsp_count=${active?.bsps.length ?? 0}')
      ..writeln(
          'recursive_seg_counts=${recursiveCounts(active?.recursiveSegLayers)}')
      ..writeln(
          'recursive_zs_counts=${recursiveCounts(active?.recursiveSegZss)}')
      ..writeln('active_bi_zs_time_sample=$activeBiZsTimeSample')
      ..writeln('active_seg_zs_time_sample=$activeSegZsTimeSample')
      ..writeln('recursive_zs_time_sample=$recursiveZsTimeSample')
      ..writeln(
          'recursive_real_bsp_counts=${recursiveCounts(active?.recursiveSegBsps)}')
      ..writeln(
          'recursive_candidate_bsp_counts=${recursiveCounts(active?.recursiveSegBspCandidates)}')
      ..writeln('recursive_real_bsp_sample=$recursiveBspSample')
      ..writeln('recursive_real_bsp_time_sample=$recursiveBspTimeSample')
      ..writeln('nested_markers=${_nestedBspMarkers.length}')
      ..writeln('candidate_trail=$_bspCandidateTrailCount')
      ..writeln()
      ..writeln('[缠论全局设置]')
      ..writeln(
          'level_promoter_max_layer=${LevelPromoterSettings.currentMaxLayer}');

    for (var i = 0; i < _rhythmSettings.groups.length; i++) {
      final group = _rhythmSettings.groups[i];
      final number = i + 1;
      buffer
        ..writeln('rhythm_group_${number}_line_color=${group.lineColor}')
        ..writeln('rhythm_group_${number}_line_width=${group.lineWidth}')
        ..writeln('rhythm_group_${number}_dashed=${group.dashed}')
        ..writeln(
            'rhythm_group_${number}_text_font_size=${group.textFontSize}');
    }

    for (final entry in chanEntries) {
      buffer.writeln('${entry.key}=${entry.value}');
    }

    return buffer.toString();
  }

  List<SideToolbarSection> _s13ToolbarSections() => <SideToolbarSection>[
        SideToolbarSection(
          title: '股票',
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _input(_symbolController, 'symbol', width: 104),
                _input(_marketController, 'market', width: 78),
                _dateButton(
                    'start', _startDate, () => _pickDate(isStart: true)),
                _dateButton('end', _endDate, () => _pickDate(isStart: false)),
                _runtimePathButton(),
                _currentSettingsCopyButton(),
              ],
            ),
          ],
        ),
        SideToolbarSection(
          title: '级别',
          children: <Widget>[
            Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
              for (final level in _levelOptions) _levelChip(level),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
              for (final level in _loadedLevels) _activeLevelChip(level),
            ]),
          ],
        ),
        SideToolbarSection(
          title: '复盘 / marker',
          children: <Widget>[
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
            ]),
          ],
        ),
        SideToolbarSection(
          title: '图层',
          children: <Widget>[
            Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
              for (final n in _easyTdxIndicatorOptions) _indicatorChip(n),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
              FilterChip(
                label: const Text('区间套'),
                selected: _showIntervalNest,
                onSelected: _loading
                    ? null
                    : (v) => setState(() => _showIntervalNest = v),
              ),
              FilterChip(
                label: const Text('段中枢'),
                selected: _showNativeZs,
                onSelected: (v) => setState(() => _showNativeZs = v),
              ),
              FilterChip(
                label: const Text('2段中枢'),
                selected: _showSeg2Zs,
                onSelected: (v) => setState(() => _showSeg2Zs = v),
              ),
              FilterChip(
                label: const Text('N段中枢'),
                selected: _showSegNZs,
                onSelected: (v) => setState(() => _showSegNZs = v),
              ),
              FilterChip(
                label: const Text('节奏线'),
                selected: _showRhythmLines,
                onSelected: _loading
                    ? null
                    : (v) => setState(() => _showRhythmLines = v),
              ),
              FilterChip(
                label: const Text('1.382命中'),
                selected: _show1382Hits,
                onSelected:
                    _loading ? null : (v) => setState(() => _show1382Hits = v),
              ),
              FilterChip(
                label: const Text('筹码分布'),
                selected: _showChipDistribution,
                onSelected: _loading
                    ? null
                    : (v) => setState(() => _showChipDistribution = v),
              ),
              FilledButton.tonalIcon(
                onPressed: _loading ? null : _openRhythmDisplaySettings,
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('节奏线设置'),
              ),
            ]),
            SwitchListTile(
              value: _autoJudgeBspStepReview,
              onChanged: _loading
                  ? null
                  : (v) {
                      setState(() => _autoJudgeBspStepReview = v);
                      if (v) _updateCurrentBspStepReviews(notify: false);
                    },
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '自动检查 BSP',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SwitchListTile(
              value: _showBspCandidateTrail,
              onChanged: _loading
                  ? null
                  : (v) => setState(() => _showBspCandidateTrail = v),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'BSP 候选轨迹层',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ];

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
                _priceOffset = 0.0;
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

  Future<void> _openRhythmDisplaySettings() async {
    final previous = _rhythmSettings;
    final next = await showS13RhythmDisplaySettingsDialog(
      context: context,
      initial: _rhythmSettings,
    );
    if (next == null || !mounted) return;
    final calculationChanged =
        next.enabled != previous.enabled || next.calcMode != previous.calcMode;
    setState(() {
      _rhythmSettings = next;
      _showRhythmLines = next.enabled;
      _show1382Hits = next.hit.enabled;
    });
    if (calculationChanged && _analysis != null) {
      await _loadReplay();
    }
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
                _currentSettingsCopyButton(),
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
              FilledButton.tonalIcon(
                onPressed: _loading ? null : _openRhythmDisplaySettings,
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('节奏线设置'),
              ),
              FilterChip(
                  label: const Text('筹码分布'),
                  selected: _showChipDistribution,
                  onSelected: _loading
                      ? null
                      : (v) => setState(() => _showChipDistribution = v)),
            ]),
            SwitchListTile(
                value: _autoJudgeBspStepReview,
                onChanged: _loading
                    ? null
                    : (v) {
                        setState(() => _autoJudgeBspStepReview = v);
                        if (v) _updateCurrentBspStepReviews(notify: false);
                      },
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('自动检查 BSP',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700))),
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
                    onPressed: _openDrawingToolbox,
                    icon: const Icon(Icons.architecture, size: 18),
                    label: const Text('打开画线工具'))),
            _sectionGap(),
          ]);
  Widget _chartPanel(ChanSnapshot? s) {
    if (s == null || s.rawBars.isEmpty)
      return const Center(
          child: Text('Load replay to show chart.',
              style: TextStyle(color: Colors.white54)));
    return Stack(children: <Widget>[
      Positioned.fill(
          child: RecursiveSegOriginKlineChart(
              key: ValueKey('s13-chart-$_chartGeneration-$_activeLevel'),
              snapshot: s,
              showFx: true,
              showFxLine: true,
              showFxText: true,
              showBi: true,
              showBiText: false,
              showSeg: true,
              showSegText: true,
              showZs: _showNativeZs,
              showBiBsp: true,
              showSegBsp: true,
              showMergedBars: false,
              showEasyTdxIndicators: _enabledEasyTdxIndicators.isNotEmpty,
              easyTdxSubPanelCount: 2,
              enabledEasyTdxIndicators: _enabledEasyTdxIndicators,
              onEasyTdxIndicatorToggled: _toggleEasyTdxIndicator,
              toolboxOpenSignal: _toolboxOpenSignal,
              toolboxSelectedToolSignal: _toolboxSelectedToolSignal,
              drawingObjects: _chartDrawingObjects(s),
              drawingStorageKey: 's13_${_symbolController.text}_$_activeLevel',
              symbolLabel:
                  '模式:$_mode 时间:{time} 股票代码:${_symbolController.text.trim()}',
              windowSize: _windowSize,
              priceScale: _priceScale,
              priceOffset: _priceOffset,
              viewEndIndex: _viewEndIndex,
              crosshairIndex: _crosshairIndex,
              onCrosshairChanged: (v) {
                if (_crosshairIndex != v) {
                  setState(() => _crosshairIndex = v);
                }
              },
              visibleRecursiveSegZsLayers: <int>{
                if (_showSeg2Zs) 2,
                if (_showSegNZs)
                  for (var layer = 3;
                      layer <= LevelPromoterSettings.currentMaxLayer;
                      layer++)
                    layer,
              },
              onPanBars: _panChartByBars,
              onWindowSizeChanged: (v) => setState(() => _windowSize = v),
              onPriceScaleChanged: (v) => setState(() => _priceScale = v),
              onPriceOffsetChanged: (v) => setState(() => _priceOffset = v))),
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
        windowSize: _windowSize,
        priceScale: _priceScale,
        priceOffset: _priceOffset,
        easySubPanelCount: _enabledEasyTdxIndicators.isEmpty ? 0 : 2,
      ),
      BspBottomLabelOverlay(
        enabled: _hasStepFrames,
        labels: _bspBottomLabels,
        totalBars: s.rawBars.length,
        windowSize: _windowSize,
        viewEndIndex: _viewEndIndex,
        easySubPanelCount: _enabledEasyTdxIndicators.isEmpty ? 0 : 2,
      ),
      if (_showIntervalNest) _nestedBspMarkerOverlay(),
      _replayControlOverlay(),
      PermanentWindowControls(
        maximized: _windowMaximized,
        onMinimize: _supportsWindowManager ? _minimizeWindow : null,
        onMaximizeRestore:
            _supportsWindowManager ? _toggleWindowMaximizeRestore : null,
        onClose: _supportsWindowManager ? _closeWindow : null,
      ),
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
                } else {
                  _selectedLevels.remove(level);
                  if (_selectedLevels.length <= 1 && _mode == 'step') {
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

  void _toggleLevelFromSidebar(String level) {
    if (_loading) return;
    setState(() {
      if (_selectedLevels.contains(level)) {
        _selectedLevels.remove(level);
        if (_selectedLevels.length <= 1 && _mode == 'step') {
          _mode = 'once';
        }
        if (_activeLevel == level && _selectedLevels.isNotEmpty) {
          _activeLevel = _normalizedLevels.first;
        }
      } else {
        _selectedLevels.add(level);
      }
      _lastLevelValidation = _validateSelectedLevels().message;
    });
  }

  void _activateLoadedLevelFromSidebar(String level) {
    if (_currentSnapshot?.snapshots.containsKey(level) != true) return;
    setState(() {
      _activeLevel = level;
      _viewEndIndex = null;
      _crosshairIndex = null;
      _priceScale = 1.0;
      _priceOffset = 0.0;
    });
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
                _priceOffset = 0.0;
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

  List<DrawingObject> _chartDrawingObjects(ChanSnapshot snapshot) =>
      <DrawingObject>[
        ..._rhythmDrawingObjects(snapshot),
        ..._researchOverlayDrawingObjects(snapshot),
      ];

  List<DrawingObject> _researchOverlayDrawingObjects(ChanSnapshot snapshot) {
    if (_researchOverlayMarkers.isEmpty || snapshot.rawBars.isEmpty) {
      return const <DrawingObject>[];
    }
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    final nonce = _researchOverlayNonce ?? 0;
    final objects = <DrawingObject>[];
    for (var index = 0; index < _researchOverlayMarkers.length; index++) {
      final marker = _researchOverlayMarkers[index];
      final rawIndex = _intValue(marker['raw_index']);
      if (rawIndex == null) continue;
      final barIndex = _barListIndexForRawIndex(snapshot, rawIndex);
      if (barIndex < 0 || barIndex >= snapshot.rawBars.length) continue;
      final bar = snapshot.rawBars[barIndex];
      final kind = '${marker['kind'] ?? ''}';
      final isRange = kind == 'range_start' || kind == 'range_end';
      final low = bar.low;
      final high = bar.high;
      final price = _researchMarkerPrice(bar, kind);
      objects.add(DrawingObject(
        id: 's13_research_overlay_${nonce}_${index}_$rawIndex',
        tool: isRange
            ? TradingViewDrawingTool.verticalLine
            : TradingViewDrawingTool.iconFlag,
        anchors: isRange
            ? <DrawingAnchor>[
                DrawingAnchor.chart(rawIndex: bar.index, price: low),
                DrawingAnchor.chart(rawIndex: bar.index, price: high),
              ]
            : <DrawingAnchor>[
                DrawingAnchor.chart(rawIndex: bar.index, price: price),
              ],
        style: DrawingStyle(
          colorValue: _researchMarkerColor(kind),
          strokeWidth: isRange ? 1.7 : 2.0,
          opacity: isRange ? 0.72 : 0.96,
          dashed: isRange,
          fontSize: 12,
        ),
        text: _researchMarkerLabel(marker, kind),
        locked: true,
        createdAt: now,
        updatedAt: now,
      ));
    }
    return objects;
  }

  String _researchMarkerLabel(Map<String, dynamic> marker, String kind) {
    final ordinal = marker['ordinal'];
    final no = ordinal == null ? '' : '#$ordinal';
    switch (kind) {
      case 'entry':
      case 'trade_entry':
        return '入$no';
      case 'exit':
      case 'trade_exit':
        return '出$no';
      case 'range_start':
        return '区间起';
      case 'range_end':
        return '区间止';
    }
    final label = '${marker['label'] ?? ''}'.trim();
    return label.isEmpty ? '研究$no' : '$label$no';
  }

  double _researchMarkerPrice(RawBar bar, String kind) {
    switch (kind) {
      case 'entry':
      case 'trade_entry':
        return bar.low;
      case 'exit':
      case 'trade_exit':
        return bar.high;
    }
    return bar.close;
  }

  int _researchMarkerColor(String kind) {
    switch (kind) {
      case 'entry':
      case 'trade_entry':
        return 0xFF26A69A;
      case 'exit':
      case 'trade_exit':
        return 0xFFEF5350;
      case 'range_start':
      case 'range_end':
        return 0xFFFFD54F;
    }
    return 0xFF64B5F6;
  }

  int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  List<DrawingObject> _rhythmDrawingObjects(ChanSnapshot snapshot) {
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    final objects = <DrawingObject>[];
    final selection = S13RhythmViewportSelector.select(
      lines: snapshot.rhythmLines,
      hits: snapshot.rhythmHits,
      totalBars: snapshot.rawBars.length,
      viewEndIndex: _viewEndIndex,
      windowSize: _windowSize,
    );
    if (_showRhythmLines) {
      final visibleLines =
          selection.lines.where(_rhythmSettings.lineVisible).toList();
      final groups = <String, List<RhythmLine>>{};
      for (final line in visibleLines) {
        final key = '${line.parentKey}|'
            '${line.sourceKind.trim().toLowerCase()}->'
            '${line.parentLevel.trim().toLowerCase()}|${line.roundRef}';
        groups.putIfAbsent(key, () => <RhythmLine>[]).add(line);
      }
      for (final entry in groups.entries) {
        final lines = entry.value;
        final sharedStart = lines.map((line) => line.x1).reduce(math.min);
        final style = _rhythmSettings.lineStyle(lines.first);
        for (final line in lines) {
          objects.add(DrawingObject(
            id: 'auto_${line.id}',
            tool: TradingViewDrawingTool.trendLine,
            anchors: <DrawingAnchor>[
              DrawingAnchor.chart(rawIndex: sharedStart, price: line.y1),
              DrawingAnchor.chart(rawIndex: line.x2, price: line.y2),
            ],
            style: style,
            text: line.displayLabel,
            locked: true,
            createdAt: now,
            updatedAt: now,
          ));
          objects.add(DrawingObject(
            id: 'auto_rhythm_point_${line.id}',
            tool: TradingViewDrawingTool.iconCircle,
            anchors: <DrawingAnchor>[
              DrawingAnchor.chart(rawIndex: sharedStart, price: line.y1),
            ],
            style: style,
            text: _rhythmSettings.showSequenceNumbers ? line.labelLeft : '',
            locked: true,
            createdAt: now,
            updatedAt: now,
          ));
        }
        if (lines.length > 1) {
          final prices = lines.map((line) => line.y1).toList();
          objects.add(DrawingObject(
            id: 'auto_rhythm_group_${entry.key}_$sharedStart',
            tool: TradingViewDrawingTool.trendLine,
            anchors: <DrawingAnchor>[
              DrawingAnchor.chart(
                  rawIndex: sharedStart, price: prices.reduce(math.min)),
              DrawingAnchor.chart(
                  rawIndex: sharedStart, price: prices.reduce(math.max)),
            ],
            style: style,
            locked: true,
            createdAt: now,
            updatedAt: now,
          ));
        }
      }
    }
    if (_show1382Hits) {
      for (final hit in selection.hits.where(_rhythmSettings.hitVisible)) {
        objects.add(DrawingObject(
          id: 'auto_${hit.id}',
          tool: TradingViewDrawingTool.priceLabel,
          anchors: <DrawingAnchor>[
            DrawingAnchor.chart(
              rawIndex: hit.rawIndex,
              price: hit.price == 0 ? hit.threshold : hit.price,
            ),
          ],
          style: _rhythmSettings.hitStyle(hit),
          text: _rhythmSettings.hitText(hit),
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

  Widget _currentSettingsCopyButton() => OutlinedButton.icon(
        onPressed: _copyCurrentS13Settings,
        icon: const Icon(Icons.copy_all, size: 16),
        label: const Text('状态 / 一键复制'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFD54F),
          side: const BorderSide(color: Color(0x88FFD54F)),
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
  Object? _analysisTimeLogValue(
      PythonMultiLevelChanAnalysis analysis, String key) {
    final timeLog = analysis.meta['time_log'];
    if (timeLog is Map) return timeLog[key];
    return analysis.meta[key];
  }

  String _loadedChanConfigSummary(PythonMultiLevelChanAnalysis analysis) {
    final bi =
        _analysisTimeLogValue(analysis, 'chan_config_bi_algo') ?? 'unknown';
    final seg =
        _analysisTimeLogValue(analysis, 'chan_config_seg_algo') ?? 'unknown';
    final zs =
        _analysisTimeLogValue(analysis, 'chan_config_zs_algo') ?? 'unknown';
    final n = _analysisTimeLogValue(analysis, 'level_promoter_max_level') ??
        _analysisTimeLogValue(analysis, 'recursive_seg_max_level') ??
        'unknown';
    return 'bi_algo=$bi seg_algo=$seg zs_algo=$zs N=$n';
  }

  String _biCountSummary(MultiLevelChanSnapshot snapshot) {
    if (snapshot.levels.isEmpty) return 'none';
    return snapshot.levels.map((level) {
      final normalized = level.trim().toUpperCase();
      final snap = snapshot.snapshots[level] ?? snapshot.snapshots[normalized];
      return '$normalized:${snap?.bis.length ?? 0}';
    }).join(',');
  }

  String _buildStatus(PythonMultiLevelChanAnalysis a, DateTime s, DateTime e) {
    final m = a.meta;
    final rhythm = _rhythmSummaryFor(_activeSnapshot);
    final loadedConfig = _loadedChanConfigSummary(a);
    final finalBiCounts = _biCountSummary(a.snapshot);
    final current = _currentSnapshot;
    final currentBiCounts = current == null ? 'none' : _biCountSummary(current);
    final activeBiCount = _activeSnapshot?.bis.length ?? 0;
    return 'S13 analyze_multi ${_mode.toUpperCase()} runtime_path:${_runtimePathText(a)} native:${m['native_cchan_lv_list']} fallback:${m['fallback_to_bridge'] ?? false} loaded_config:{$loadedConfig} frames:${a.frames.length} active_frame:$_stepFrameLabel levels:${a.snapshot.levels.join(',')} window:${_fmtDate(s)}~${_fmtDate(e)} final_bi_counts:{$finalBiCounts} current_bi_counts:{$currentBiCounts} active_bi:$_activeLevel=$activeBiCount nested_markers:${_nestedBspMarkers.length} candidate_trail:$_bspCandidateTrailCount rhythm_1382_line_count:${rhythm.lineCount} rhythm_1382_hit_count:${rhythm.hitCount} rhythm_1382_visible_lines:$_showRhythmLines rhythm_1382_visible_hits:$_show1382Hits rhythm_1382_backend_route_ms:${m['backend_route_rhythm_1382_overlay_ms'] ?? 'unknown'} rhythm_1382_overlay_policy:$_rhythmPolicy dart_chan_calculation_authority: false';
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

class _S13RegisteredSectionPanel extends StatelessWidget {
  final ValueListenable<int> revision;
  final SideToolbarSection Function() sectionBuilder;

  const _S13RegisteredSectionPanel({
    required this.revision,
    required this.sectionBuilder,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: revision,
        builder: (context, _, __) {
          final section = sectionBuilder();
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: <Widget>[
              Row(children: <Widget>[
                const Expanded(child: Divider(color: Colors.white24)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    section.title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Colors.white24)),
              ]),
              const SizedBox(height: 8),
              ...section.children,
            ],
          );
        },
      );
}
