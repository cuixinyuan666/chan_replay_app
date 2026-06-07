import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../../data/czsc_easy_tdx_source.dart';
import '../widgets/kline_chart.dart';
import '../widgets/replay_controller_bar.dart';

enum BackendDisplayMode { full, step }

class CzscEasyTdxPage extends StatefulWidget {
  const CzscEasyTdxPage({super.key});

  @override
  State<CzscEasyTdxPage> createState() => _CzscEasyTdxPageState();
}

class _CzscEasyTdxPageState extends State<CzscEasyTdxPage> {
  static const List<String> _freqOptions = [
    'MIN1',
    'MIN5',
    'MIN15',
    'MIN30',
    'MIN60',
    'DAILY',
    'WEEKLY',
    'MONTHLY',
  ];

  final TextEditingController _baseUrlController =
      TextEditingController(text: _defaultBackendBaseUrl);
  final TextEditingController _symbolController = TextEditingController(text: '000001');
  final TextEditingController _startDateController =
      TextEditingController(text: '2020-01-01');
  final TextEditingController _endDateController = TextEditingController();

  final Map<String, CzscAnalyzeResult> _results = {};
  final List<CzscBackendPreset> _presets = [];
  final Set<String> _selectedFreqs = {'MIN5', 'MIN30', 'DAILY'};

  String _market = 'SZ';
  String _freq = 'DAILY';
  String _activeFreq = 'DAILY';
  String _adjust = 'QFQ';
  int _count = 800;
  bool _loading = false;
  String _label = 'CZSC/easy-tdx 未加载';
  String? _warning;

  bool _showFx = true;
  bool _showFxLine = true;
  bool _showBi = true;
  bool _showSeg = true;
  bool _showZs = true;
  int _windowSize = 120;
  double _priceScale = 1.0;
  int? _viewEndIndex;
  int? _crosshairIndex;

  BackendDisplayMode _displayMode = BackendDisplayMode.full;

  static String get _defaultBackendBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }
  int _cursor = 0;
  bool _playing = false;
  Timer? _timer;

  CzscAnalyzeResult? get _activeResult => _results[_activeFreq];
  ChanSnapshot get _fullSnapshot => _activeResult?.snapshot ?? ChanSnapshot.empty();
  bool get _isStepMode => _displayMode == BackendDisplayMode.step;
  int get _totalBars => _fullSnapshot.rawBars.length;
  int get _effectiveCursor => _isStepMode ? _cursor.clamp(0, _totalBars).toInt() : _totalBars;
  Map<String, String> get _signals => _activeResult?.signals ?? const {};
  ChanSnapshot get _displaySnapshot => _isStepMode
      ? _snapshotUntil(_fullSnapshot, _effectiveCursor)
      : _fullSnapshot;

  @override
  void dispose() {
    _timer?.cancel();
    _baseUrlController.dispose();
    _symbolController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _loadSingle() async {
    final request = _buildRequest();
    if (request == null) return;

    setState(() => _loading = true);
    final source = CzscEasyTdxSource(baseUrl: request.baseUrl);
    try {
      final result = await source.analyze(
        symbol: request.symbol,
        market: _market,
        freq: _freq,
        adjust: _adjust,
        count: _count,
        startDate: request.startDate,
        endDate: request.endDate,
      );
      if (!mounted) return;
      setState(() {
        _stopPlay();
        _results
          ..clear()
          ..[_freq] = result;
        _activeFreq = _freq;
        _label = result.sourceLabel;
        _warning = result.engineWarning;
        _resetViewStateForActive();
        _rememberPreset(request, auto: true);
      });
      _notifyAfterLoad(result);
    } catch (e) {
      if (!mounted) return;
      _showSnack('CZSC/easy-tdx 加载失败：$e');
    } finally {
      source.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMulti() async {
    final request = _buildRequest();
    if (request == null) return;
    final freqs = _orderedSelectedFreqs();
    if (freqs.isEmpty) {
      _showSnack('请至少选择一个多级别周期');
      return;
    }

    setState(() => _loading = true);
    final source = CzscEasyTdxSource(baseUrl: request.baseUrl);
    try {
      final result = await source.analyzeMulti(
        symbol: request.symbol,
        market: _market,
        freqs: freqs,
        adjust: _adjust,
        count: _count,
        startDate: request.startDate,
        endDate: request.endDate,
      );
      if (!mounted) return;
      if (result.results.isEmpty) {
        _showSnack('后端没有返回多级别结果');
        return;
      }
      setState(() {
        _stopPlay();
        _results
          ..clear()
          ..addAll(result.results);
        _activeFreq = result.results.containsKey(_freq) ? _freq : result.results.keys.first;
        final active = _activeResult;
        _label = 'CZSC多级别 ${result.symbol} ${result.results.keys.join('/')}';
        _warning = active?.engineWarning;
        _resetViewStateForActive();
        _rememberPreset(request, auto: true, multi: true);
      });
      final active = _activeResult;
      if (active != null) _notifyAfterLoad(active);
    } catch (e) {
      if (!mounted) return;
      _showSnack('CZSC/easy-tdx 多级别加载失败：$e');
    } finally {
      source.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  _BackendRequest? _buildRequest() {
    final symbol = _symbolController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    if (symbol.isEmpty || baseUrl.isEmpty) {
      _showSnack('请填写后端地址和股票代码');
      return null;
    }
    final startDate = _parseDateInput(_startDateController.text);
    final endDate = _parseDateInput(_endDateController.text);
    if (_startDateController.text.trim().isNotEmpty && startDate == null) {
      _showSnack('开始日期格式应为 yyyy-MM-dd');
      return null;
    }
    if (_endDateController.text.trim().isNotEmpty && endDate == null) {
      _showSnack('结束日期格式应为 yyyy-MM-dd');
      return null;
    }
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      _showSnack('开始日期不能晚于结束日期');
      return null;
    }
    return _BackendRequest(
      baseUrl: baseUrl,
      symbol: symbol,
      startDate: startDate,
      endDate: endDate,
    );
  }

  void _notifyAfterLoad(CzscAnalyzeResult result) {
    if (result.snapshot.rawBars.isEmpty) {
      _showSnack('后端没有返回K线数据');
    } else if (result.engineWarning != null && result.engineWarning!.isNotEmpty) {
      _showSnack(result.engineWarning!);
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _resetViewStateForActive() {
    _cursor = _displayMode == BackendDisplayMode.full
        ? _totalBars
        : math.min(120, _totalBars).toInt();
    _viewEndIndex = null;
    _crosshairIndex = null;
    _priceScale = 1.0;
    _warning = _activeResult?.engineWarning;
  }

  void _switchActiveFreq(String freq) {
    if (!_results.containsKey(freq)) return;
    setState(() {
      _stopPlay();
      _activeFreq = freq;
      _freq = freq;
      _label = _activeResult?.sourceLabel ?? _label;
      _resetViewStateForActive();
    });
  }

  void _setDisplayMode(BackendDisplayMode mode) {
    if (_displayMode == mode) return;
    setState(() {
      _stopPlay();
      _displayMode = mode;
      _cursor = mode == BackendDisplayMode.full ? _totalBars : math.min(120, _totalBars).toInt();
      _viewEndIndex = null;
      _crosshairIndex = null;
    });
  }

  void _resetReplay() {
    if (!_isStepMode) return;
    setState(() {
      _stopPlay();
      _cursor = math.min(30, _totalBars).toInt();
      _viewEndIndex = null;
      _crosshairIndex = null;
    });
  }

  void _stepForward() {
    if (!_isStepMode) return;
    if (_cursor >= _totalBars) {
      _stopPlay();
      return;
    }
    setState(() => _cursor += 1);
  }

  void _stepBack() {
    if (!_isStepMode || _cursor <= 0) return;
    setState(() {
      _cursor -= 1;
      final maxIndex = math.max(0, _effectiveCursor - 1).toInt();
      _crosshairIndex = _crosshairIndex?.clamp(0, maxIndex).toInt();
      _viewEndIndex = _viewEndIndex?.clamp(0, maxIndex).toInt();
    });
  }

  void _jumpTo(int nextCursor) {
    if (!_isStepMode) return;
    setState(() {
      _cursor = nextCursor.clamp(0, _totalBars).toInt();
      _viewEndIndex = null;
      _crosshairIndex = null;
    });
  }

  void _togglePlay() {
    if (!_isStepMode) return;
    setState(() {
      _playing = !_playing;
      if (_playing) {
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(milliseconds: 450), (_) => _stepForward());
      } else {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  void _stopPlay() {
    _playing = false;
    _timer?.cancel();
    _timer = null;
  }

  void _panChartByBars(int bars) {
    final snapshot = _displaySnapshot;
    if (bars == 0 || snapshot.rawBars.isEmpty) return;
    final maxEnd = snapshot.rawBars.length - 1;
    final current = _viewEndIndex ?? maxEnd;
    final next = (current + bars).clamp(0, maxEnd).toInt();
    if (next == current) return;
    setState(() => _viewEndIndex = next);
  }

  void _changeWindowSize(int next) {
    final value = next.clamp(24, 360).toInt();
    if (value == _windowSize) return;
    setState(() => _windowSize = value);
  }

  void _changePriceScale(double next) {
    final value = next.clamp(0.35, 5.0).toDouble();
    if ((value - _priceScale).abs() < 0.001) return;
    setState(() => _priceScale = value);
  }

  void _goToLatest() {
    setState(() {
      _viewEndIndex = null;
      _crosshairIndex = null;
    });
  }

  void _rememberCurrentPreset() {
    final request = _buildRequest();
    if (request == null) return;
    setState(() => _rememberPreset(request, auto: false, multi: _results.length > 1));
    _showSnack('已记录当前参数');
  }

  void _rememberPreset(_BackendRequest request, {required bool auto, bool multi = false}) {
    final preset = CzscBackendPreset(
      baseUrl: request.baseUrl,
      symbol: request.symbol,
      market: _market,
      freq: _freq,
      freqs: _orderedSelectedFreqs(),
      adjust: _adjust,
      count: _count,
      startDate: request.startDate,
      endDate: request.endDate,
      multi: multi,
      auto: auto,
    );
    _presets.removeWhere((item) => item.key == preset.key);
    _presets.insert(0, preset);
    if (_presets.length > 8) _presets.removeRange(8, _presets.length);
  }

  void _applyPreset(CzscBackendPreset preset) {
    setState(() {
      _baseUrlController.text = preset.baseUrl;
      _symbolController.text = preset.symbol;
      _market = preset.market;
      _freq = preset.freq;
      _adjust = preset.adjust;
      _count = preset.count;
      _startDateController.text = _fmtDate(preset.startDate) ?? '';
      _endDateController.text = _fmtDate(preset.endDate) ?? '';
      _selectedFreqs
        ..clear()
        ..addAll(preset.freqs);
    });
    if (preset.multi) {
      _loadMulti();
    } else {
      _loadSingle();
    }
  }

  List<String> _orderedSelectedFreqs() {
    return [
      for (final freq in _freqOptions)
        if (_selectedFreqs.contains(freq)) freq,
    ];
  }

  ChanSnapshot _snapshotUntil(ChanSnapshot full, int cursor) {
    final limit = cursor.clamp(0, full.rawBars.length).toInt();
    if (limit <= 0) return ChanSnapshot.empty();
    final maxRaw = limit - 1;
    return ChanSnapshot(
      rawBars: full.rawBars.take(limit).toList(),
      mergedBars: full.mergedBars.where((bar) => bar.endRawIndex <= maxRaw).toList(),
      fxs: full.fxs.where((fx) => fx.rawIndex <= maxRaw).toList(),
      bis: full.bis.where((bi) => bi.endRawIndex <= maxRaw).toList(),
      segs: full.segs.where((seg) => seg.endRawIndex <= maxRaw).toList(),
      zss: full.zss.where((zs) => zs.endRawIndex <= maxRaw).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displaySnapshot = _displaySnapshot;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      appBar: AppBar(
        titleSpacing: 12,
        title: const Text('CZSC / easy-tdx'),
        actions: [
          IconButton(
            tooltip: '信号面板',
            onPressed: _openSignalPanel,
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            tooltip: '加载后端 CZSC 元素',
            onPressed: _loading ? null : _loadSingle,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControlPanel(),
          _buildFetchBar(),
          _buildMultiFreqBar(),
          _buildPresetBar(),
          _buildStatusBar(displaySnapshot),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0D10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: KlineChart(
                    snapshot: displaySnapshot,
                    showFx: _showFx,
                    showFxLine: _showFxLine,
                    showFxText: true,
                    showBi: _showBi,
                    showBiText: false,
                    showSeg: _showSeg,
                    showSegText: true,
                    showZs: _showZs,
                    windowSize: _windowSize,
                    priceScale: _priceScale,
                    viewEndIndex: _viewEndIndex,
                    crosshairIndex: _crosshairIndex,
                    onCrosshairChanged: (i) => setState(() => _crosshairIndex = i),
                    onPanBars: _panChartByBars,
                    onWindowSizeChanged: _changeWindowSize,
                    onPriceScaleChanged: _changePriceScale,
                  ),
                ),
              ),
            ),
          ),
          _buildBottomTools(),
          ReplayControllerBar(
            enabled: _isStepMode && _totalBars > 0,
            playing: _playing,
            cursor: _effectiveCursor,
            total: _totalBars,
            onReset: _resetReplay,
            onStepBack: _stepBack,
            onStepForward: _stepForward,
            onTogglePlay: _togglePlay,
            onSliderChanged: (v) => _jumpTo(v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Material(
      color: const Color(0xFF131722),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _box(width: 210, child: _textField(_baseUrlController, '后端地址')),
              _box(width: 92, child: _drop('市场', _market, const ['SZ', 'SH'], (v) => setState(() => _market = v))),
              _box(width: 112, child: _textField(_symbolController, '代码')),
              _box(width: 126, child: _drop('主周期', _freq, _freqOptions, (v) => setState(() => _freq = v))),
              _box(width: 112, child: _drop('复权', _adjust, const ['QFQ', 'HFQ', 'NONE'], (v) => setState(() => _adjust = v))),
              _box(width: 132, child: _textField(_startDateController, '开始日期')),
              _box(width: 132, child: _textField(_endDateController, '结束日期')),
              SizedBox(
                width: 180,
                child: Row(
                  children: [
                    const Text('数量', style: TextStyle(color: Colors.white70)),
                    Expanded(
                      child: Slider(
                        min: 100,
                        max: 3000,
                        divisions: 29,
                        label: '$_count',
                        value: _count.toDouble().clamp(100.0, 3000.0).toDouble(),
                        onChanged: (v) => setState(() => _count = v.round()),
                      ),
                    ),
                    Text('$_count', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFetchBar() {
    return Material(
      color: const Color(0xFF111821),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Row(
          children: [
            FilledButton.icon(
              onPressed: _loading ? null : _loadSingle,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download),
              label: const Text('获取数据'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _loading ? null : _loadMulti,
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('获取多级别'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _rememberCurrentPreset,
              icon: const Icon(Icons.star_border),
              label: const Text('记住参数'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _totalBars == 0
                    ? '填写或确认参数后点击“获取数据”'
                    : '已获取 $_totalBars 根K线，当前显示 ${_displaySnapshot.rawBars.length} 根',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiFreqBar() {
    return Material(
      color: const Color(0xFF10141B),
      child: SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 8, top: 8),
              child: Text('多级别', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            for (final freq in _freqOptions)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(freq),
                  selected: _selectedFreqs.contains(freq),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedFreqs.add(freq);
                      } else {
                        _selectedFreqs.remove(freq);
                      }
                    });
                  },
                ),
              ),
            if (_results.length > 1) ...[
              const VerticalDivider(width: 18, color: Colors.white24),
              for (final freq in _results.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_periodLabel(freq)),
                    selected: _activeFreq == freq,
                    onSelected: (_) => _switchActiveFreq(freq),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetBar() {
    if (_presets.isEmpty) return const SizedBox.shrink();
    return Material(
      color: const Color(0xFF0F131A),
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 8, top: 8),
              child: Text('最近', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            for (final preset in _presets)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  avatar: Icon(preset.multi ? Icons.account_tree : Icons.show_chart, size: 16),
                  label: Text(preset.title),
                  onPressed: () => _applyPreset(preset),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(ChanSnapshot displaySnapshot) {
    final full = _fullSnapshot;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFF0F131A),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$_label  当前:${_periodLabel(_activeFreq)}  显示K:${displaySnapshot.rawBars.length}/${full.rawBars.length} FX:${displaySnapshot.fxs.length} BI:${displaySnapshot.bis.length} SEG:${displaySnapshot.segs.length} ZS:${displaySnapshot.zss.length} SIG:${_signals.length}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          if (_warning != null && _warning!.isNotEmpty)
            Tooltip(
              message: _warning!,
              child: const Icon(Icons.warning_amber, color: Colors.amber, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomTools() {
    return Material(
      color: const Color(0xFF131722),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          height: 50,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 8),
                _toggle('FX', _showFx, () => setState(() => _showFx = !_showFx)),
                _toggle('FX线', _showFxLine, () => setState(() => _showFxLine = !_showFxLine)),
                _toggle('BI', _showBi, () => setState(() => _showBi = !_showBi)),
                _toggle('SEG', _showSeg, () => setState(() => _showSeg = !_showSeg)),
                _toggle('ZS', _showZs, () => setState(() => _showZs = !_showZs)),
                const SizedBox(width: 8),
                _toggle('一次性', _displayMode == BackendDisplayMode.full, () => _setDisplayMode(BackendDisplayMode.full)),
                _toggle('逐K', _displayMode == BackendDisplayMode.step, () => _setDisplayMode(BackendDisplayMode.step)),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: '信号面板',
                  onPressed: _openSignalPanel,
                  icon: const Icon(Icons.analytics_outlined),
                ),
                IconButton(
                  tooltip: '左右放大',
                  onPressed: () => _changeWindowSize(_windowSize - 15),
                  icon: const Icon(Icons.zoom_in),
                ),
                IconButton(
                  tooltip: '左右缩小',
                  onPressed: () => _changeWindowSize(_windowSize + 15),
                  icon: const Icon(Icons.zoom_out),
                ),
                IconButton(
                  tooltip: '回到最新',
                  onPressed: _goToLatest,
                  icon: const Icon(Icons.keyboard_double_arrow_right),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSignalPanel() {
    final active = _activeResult;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      builder: (context) {
        final signals = active?.signals.entries.toList() ?? const <MapEntry<String, String>>[];
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        '信号面板 ${_periodLabel(_activeFreq)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text('共 ${signals.length} 项', style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 92,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final entry in _results.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Navigator.pop(context);
                              _switchActiveFreq(entry.key);
                            },
                            child: Container(
                              width: 150,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: entry.key == _activeFreq ? const Color(0xFF2962FF) : const Color(0xFF0B0D10),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_periodLabel(entry.key), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text(
                                    'K ${entry.value.snapshot.rawBars.length}  BI ${entry.value.snapshot.bis.length}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  Text(
                                    'ZS ${entry.value.snapshot.zss.length}  SIG ${entry.value.signals.length}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                Expanded(
                  child: signals.isEmpty
                      ? const Center(child: Text('当前结果暂无 signals 输出', style: TextStyle(color: Colors.white54)))
                      : ListView.separated(
                          itemCount: signals.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                          itemBuilder: (context, index) {
                            final item = signals[index];
                            return ListTile(
                              dense: true,
                              title: Text(item.key, style: const TextStyle(fontSize: 13)),
                              subtitle: Text(item.value, style: const TextStyle(color: Colors.white70)),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _box({required double width, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(width: width, child: child),
    );
  }

  Widget _textField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  Widget _drop(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isDense: true,
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: [
        for (final item in values) DropdownMenuItem(value: item, child: Text(_periodLabel(item))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _toggle(String label, bool value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: value,
        onSelected: (_) => onTap(),
      ),
    );
  }

  DateTime? _parseDateInput(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (match == null) return null;
    final y = int.tryParse(match.group(1)!);
    final m = int.tryParse(match.group(2)!);
    final d = int.tryParse(match.group(3)!);
    if (y == null || m == null || d == null) return null;
    final parsed = DateTime(y, m, d);
    if (parsed.year != y || parsed.month != m || parsed.day != d) return null;
    return parsed;
  }

  String? _fmtDate(DateTime? d) {
    if (d == null) return null;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  String _periodLabel(String period) {
    switch (period) {
      case 'MIN1':
        return '1m';
      case 'MIN5':
        return '5m';
      case 'MIN15':
        return '15m';
      case 'MIN30':
        return '30m';
      case 'MIN60':
        return '1h';
      case 'DAILY':
        return 'D';
      case 'WEEKLY':
        return 'W';
      case 'MONTHLY':
        return 'M';
      default:
        return period;
    }
  }
}

class _BackendRequest {
  final String baseUrl;
  final String symbol;
  final DateTime? startDate;
  final DateTime? endDate;

  const _BackendRequest({
    required this.baseUrl,
    required this.symbol,
    this.startDate,
    this.endDate,
  });
}

class CzscBackendPreset {
  final String baseUrl;
  final String symbol;
  final String market;
  final String freq;
  final List<String> freqs;
  final String adjust;
  final int count;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool multi;
  final bool auto;

  const CzscBackendPreset({
    required this.baseUrl,
    required this.symbol,
    required this.market,
    required this.freq,
    required this.freqs,
    required this.adjust,
    required this.count,
    this.startDate,
    this.endDate,
    this.multi = false,
    this.auto = false,
  });

  String get key => [
        baseUrl,
        symbol,
        market,
        freq,
        freqs.join('|'),
        adjust,
        '$count',
        startDate?.toIso8601String() ?? '',
        endDate?.toIso8601String() ?? '',
        '$multi',
      ].join('#');

  String get title => multi ? '$market:$symbol 多级别' : '$market:$symbol $freq';
}
