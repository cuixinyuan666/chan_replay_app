import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/engine/chan_config.dart';
import '../../core/engine/chan_replay_engine.dart';
import '../../core/models/chan_snapshot.dart';
import '../../core/models/raw_bar.dart';
import '../../data/csv_loader.dart';
import '../../data/easy_tdx_kline_source.dart';
import '../../data/embedded_easy_tdx_source.dart';
import '../widgets/kline_chart.dart';
import '../widgets/replay_controller_bar.dart';

enum ReplayDisplayMode { full, step }

enum MarketDataSourceKind { embeddedEasyTdx, easyTdxBackend, localCsv }

class ReplayPage extends StatefulWidget {
  const ReplayPage({super.key});

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {
  static final Uri _candlesticksDocsUri = Uri.parse('https://pub.dev/packages/candlesticks');
  static final DateTime _defaultStartDate = DateTime(2020, 1, 1);
  static final DateTime _defaultEndDate = DateTime(2026, 6, 6);
  static const int _hiddenMaxCount = 5000;

  final ChanReplayEngine _engine = ChanReplayEngine();
  final TextEditingController _stockCodeController = TextEditingController(text: '000001');
  final TextEditingController _easyTdxBaseUrlController = TextEditingController(text: _defaultBackendBaseUrl);

  List<RawBar> _allBars = [];
  ChanSnapshot _snapshot = ChanSnapshot.empty();
  int _cursor = 0;
  int _windowSize = 90;
  double _priceScale = 1.0;
  int? _viewEndIndex;
  int? _crosshairIndex;
  bool _playing = false;
  bool _showFx = true;
  bool _showFxLine = true;
  bool _showFxText = true;
  bool _showBi = true;
  bool _showBiText = false;
  bool _showSeg = true;
  bool _showSegText = true;
  bool _showZs = true;
  bool _toolbarExpanded = true;
  bool _loadingRemote = false;
  ReplayDisplayMode _displayMode = ReplayDisplayMode.full;
  MarketDataSourceKind _dataSourceKind = _defaultSourceKind;
  Timer? _timer;

  ChanConfig _config = ChanConfig.chanPyDefault();
  String _period = 'DAILY';
  String _adjust = 'QFQ';
  DateTime _startDate = _defaultStartDate;
  DateTime _endDate = _defaultEndDate;
  String _dataSourceLabel = '未获取数据源';

  static bool get _isAndroidApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _isWindowsApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static MarketDataSourceKind get _defaultSourceKind {
    return _isAndroidApp ? MarketDataSourceKind.embeddedEasyTdx : MarketDataSourceKind.easyTdxBackend;
  }

  static String get _defaultBackendBaseUrl {
    return _isAndroidApp ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';
  }

  bool get _isStepMode => _displayMode == ReplayDisplayMode.step;
  bool get _hasBars => _allBars.isNotEmpty;
  int get _effectiveCursor => _displayMode == ReplayDisplayMode.full ? _allBars.length : _cursor;

  List<MarketDataSourceKind> get _availableSourceKinds {
    return [
      if (_isAndroidApp) MarketDataSourceKind.embeddedEasyTdx,
      MarketDataSourceKind.easyTdxBackend,
      MarketDataSourceKind.localCsv,
    ];
  }

  @override
  void initState() {
    super.initState();
    // 默认保持空图。只有用户显式选择数据源并加载成功后才显示K线。
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stockCodeController.dispose();
    _easyTdxBaseUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadMarketData() async {
    if (_loadingRemote) return;
    switch (_dataSourceKind) {
      case MarketDataSourceKind.localCsv:
        await _importCsv();
        return;
      case MarketDataSourceKind.easyTdxBackend:
        await _loadEasyTdxBackend();
        return;
      case MarketDataSourceKind.embeddedEasyTdx:
        if (!_isAndroidApp) {
          _showLoadResult(ok: false, message: '× 内置 Python easy-tdx 仅支持 Android；Windows 请使用本机 easy-tdx 后端');
          return;
        }
        await _loadEmbeddedEasyTdx();
        return;
    }
  }

  Future<void> _importCsv() async {
    final bars = await CsvLoader.pickAndLoadCsv();
    if (bars == null || bars.isEmpty) {
      if (!mounted) return;
      _showLoadResult(ok: false, message: '× 本地CSV未读取到有效K线数据');
      return;
    }
    if (!mounted) return;
    setState(() {
      _dataSourceKind = MarketDataSourceKind.localCsv;
      _applyBars(bars, sourceLabel: '本地CSV / Vespa本地引擎');
    });
    _showLoadResult(
      ok: true,
      message: '√ 本地CSV获取${_targetDisplayName(_stockCodeController.text)}在${_barsRangeLabel(bars)}的CSV数据成功',
    );
  }

  Future<void> _loadEmbeddedEasyTdx() async {
    final request = _buildMarketRequest(requireBackend: false);
    if (request == null) return;
    setState(() => _loadingRemote = true);
    final source = EmbeddedEasyTdxSource();
    try {
      final bars = await source.loadKline(
        market: request.market,
        code: request.code,
        period: _period,
        adjust: _adjust,
        count: _hiddenMaxCount,
        startDate: _startDate,
        endDate: _endDate,
      );
      _handleLoadedBars(
        bars: bars,
        request: request,
        sourceName: _sourceLongLabel(MarketDataSourceKind.embeddedEasyTdx),
      );
    } catch (e) {
      if (mounted) {
        _showLoadResult(
          ok: false,
          message: '× ${_sourceLongLabel(MarketDataSourceKind.embeddedEasyTdx)}获取${_targetDisplayName(request.code)}在${_dateRangeLabel(_startDate, _endDate)}的${_periodAdjustLabel}失败：$e',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRemote = false);
    }
  }

  Future<void> _loadEasyTdxBackend() async {
    final request = _buildMarketRequest(requireBackend: true);
    if (request == null) return;
    setState(() => _loadingRemote = true);
    final source = EasyTdxKlineSource(baseUrl: request.baseUrl!);
    try {
      final bars = await source.loadKline(
        market: request.market,
        code: request.code,
        period: _period,
        adjust: _adjust,
        count: _hiddenMaxCount,
        startDate: _startDate,
        endDate: _endDate,
      );
      _handleLoadedBars(
        bars: bars,
        request: request,
        sourceName: _sourceLongLabel(MarketDataSourceKind.easyTdxBackend),
      );
    } catch (e) {
      if (mounted) {
        _showLoadResult(
          ok: false,
          message: '× ${_sourceLongLabel(MarketDataSourceKind.easyTdxBackend)}获取${_targetDisplayName(request.code)}在${_dateRangeLabel(_startDate, _endDate)}的${_periodAdjustLabel}失败：$e',
        );
      }
    } finally {
      source.close();
      if (mounted) setState(() => _loadingRemote = false);
    }
  }

  void _handleLoadedBars({required List<RawBar> bars, required _MarketRequest request, required String sourceName}) {
    if (!mounted) return;
    if (bars.isEmpty) {
      _showLoadResult(
        ok: false,
        message: '× $sourceName获取${_targetDisplayName(request.code)}在${_dateRangeLabel(_startDate, _endDate)}的${_periodAdjustLabel}失败：未返回有效K线',
      );
      return;
    }
    setState(() {
      _applyBars(
        bars,
        sourceLabel: '$sourceName ${request.market}${request.code} ${_periodAdjustLabel} ${bars.length}根 / Vespa本地引擎',
      );
    });
    _showLoadResult(
      ok: true,
      message: '√ $sourceName获取${_targetDisplayName(request.code)}在${_barsRangeLabel(bars)}的${_periodAdjustLabel}成功',
    );
  }

  _MarketRequest? _buildMarketRequest({required bool requireBackend}) {
    final symbol = _parseSymbol(_stockCodeController.text);
    if (symbol == null) {
      _showLoadResult(ok: false, message: '× 代码格式错误：请输入6位A股代码，例如 000001 或 600000');
      return null;
    }
    if (_startDate.isAfter(_endDate)) {
      _showLoadResult(ok: false, message: '× 开始日期不能晚于结束日期');
      return null;
    }
    final baseUrl = _easyTdxBaseUrlController.text.trim();
    if (requireBackend && baseUrl.isEmpty) {
      _showLoadResult(ok: false, message: '× 请填写 easy-tdx 后端地址');
      return null;
    }
    return _MarketRequest(code: symbol.code, market: symbol.market, baseUrl: requireBackend ? baseUrl : null);
  }

  void _applyBars(List<RawBar> bars, {required String sourceLabel}) {
    _stopPlay();
    _allBars = [for (var i = 0; i < bars.length; i++) bars[i].copyWith(index: i)];
    _cursor = _displayMode == ReplayDisplayMode.full ? _allBars.length : math.min(120, _allBars.length).toInt();
    _dataSourceLabel = sourceLabel;
    _viewEndIndex = null;
    _crosshairIndex = null;
    _priceScale = 1.0;
    _rebuildSnapshot();
  }

  void _rebuildSnapshot() {
    _engine.setConfig(_config);
    final cursor = _effectiveCursor.clamp(0, _allBars.length).toInt();
    _snapshot = _engine.feedMany(_allBars.take(cursor).toList());
    final maxIndex = math.max(0, _snapshot.rawBars.length - 1).toInt();
    _crosshairIndex = _crosshairIndex?.clamp(0, maxIndex).toInt();
    _viewEndIndex = _viewEndIndex?.clamp(0, maxIndex).toInt();
  }

  void _reset() {
    if (!_isStepMode || !_hasBars) return;
    setState(() {
      _stopPlay();
      _cursor = math.min(30, _allBars.length).toInt();
      _viewEndIndex = null;
      _crosshairIndex = null;
      _priceScale = 1.0;
      _rebuildSnapshot();
    });
  }

  void _stepForward() {
    if (!_isStepMode || !_hasBars) return;
    if (_cursor >= _allBars.length) {
      _stopPlay();
      return;
    }
    setState(() {
      _cursor += 1;
      _snapshot = _engine.feed(_allBars[_cursor - 1]);
    });
  }

  void _stepBack() {
    if (!_isStepMode || !_hasBars || _cursor <= 0) return;
    setState(() {
      _cursor -= 1;
      _snapshot = _engine.undo();
      final maxIndex = math.max(0, _snapshot.rawBars.length - 1).toInt();
      _crosshairIndex = _crosshairIndex?.clamp(0, maxIndex).toInt();
      _viewEndIndex = _viewEndIndex?.clamp(0, maxIndex).toInt();
    });
  }

  void _jumpTo(int nextCursor) {
    if (!_isStepMode || !_hasBars) return;
    setState(() {
      _cursor = nextCursor.clamp(0, _allBars.length).toInt();
      _viewEndIndex = null;
      _crosshairIndex = null;
      _rebuildSnapshot();
    });
  }

  void _togglePlay() {
    if (!_isStepMode || !_hasBars) return;
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

  void _setDisplayMode(ReplayDisplayMode mode) {
    if (!_hasBars || _displayMode == mode) return;
    setState(() {
      _stopPlay();
      _displayMode = mode;
      if (mode == ReplayDisplayMode.full) {
        _cursor = _allBars.length;
      } else if (_cursor <= 0 || _cursor > _allBars.length) {
        _cursor = math.min(120, _allBars.length).toInt();
      }
      _viewEndIndex = null;
      _crosshairIndex = null;
      _rebuildSnapshot();
    });
  }

  void _panChartByBars(int bars) {
    if (bars == 0 || _snapshot.rawBars.isEmpty) return;
    final maxEnd = _snapshot.rawBars.length - 1;
    final current = _viewEndIndex ?? maxEnd;
    final next = (current + bars).clamp(0, maxEnd).toInt();
    if (next == current) return;
    setState(() => _viewEndIndex = next);
  }

  void _changeWindowSize(int next) {
    if (!_hasBars) return;
    final value = next.clamp(24, 360).toInt();
    if (value == _windowSize) return;
    setState(() => _windowSize = value);
  }

  void _changePriceScale(double next) {
    if (!_hasBars) return;
    final value = next.clamp(0.35, 5.0).toDouble();
    if ((value - _priceScale).abs() < 0.001) return;
    setState(() => _priceScale = value);
  }

  void _resetChartZoom() {
    if (!_hasBars) return;
    setState(() {
      _windowSize = 90;
      _priceScale = 1.0;
      _viewEndIndex = null;
    });
  }

  void _goToLatest() {
    if (!_hasBars) return;
    setState(() {
      _viewEndIndex = null;
      _crosshairIndex = null;
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await _pickDate(initialDate: _startDate);
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_startDate.isAfter(_endDate)) _endDate = picked;
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await _pickDate(initialDate: _endDate);
    if (picked == null) return;
    setState(() {
      _endDate = picked;
      if (_startDate.isAfter(_endDate)) _startDate = picked;
    });
  }

  Future<DateTime?> _pickDate({required DateTime initialDate}) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1990, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
  }

  void _openDataSourcePanel() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      builder: (context) {
        var sourceKind = _availableSourceKinds.contains(_dataSourceKind) ? _dataSourceKind : _defaultSourceKind;
        var period = _period;
        var adjust = _adjust;
        var start = _startDate;
        var end = _endDate;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isCsv = sourceKind == MarketDataSourceKind.localCsv;
            final usesBackend = sourceKind == MarketDataSourceKind.easyTdxBackend;
            final sourceItems = _availableSourceKinds.map((kind) {
              return DropdownMenuItem(value: kind, child: Text(_sourceLongLabel(kind)));
            }).toList(growable: false);
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('本地复盘数据源', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_platformSourceHelp, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<MarketDataSourceKind>(
                        initialValue: sourceKind,
                        decoration: const InputDecoration(labelText: '数据源', border: OutlineInputBorder()),
                        items: sourceItems,
                        onChanged: _loadingRemote ? null : (v) => setSheetState(() => sourceKind = v ?? sourceKind),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _easyTdxBaseUrlController,
                        enabled: usesBackend && !_loadingRemote,
                        decoration: InputDecoration(
                          labelText: usesBackend ? 'easy-tdx 后端地址（Windows可自动后台启动）' : 'easy-tdx 后端地址（当前数据源不使用）',
                          hintText: 'http://127.0.0.1:8000 或 http://10.0.2.2:8000',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _stockCodeController,
                        enabled: !isCsv && !_loadingRemote,
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          labelText: '代码（自动识别市场）',
                          hintText: '000001 / 600000 / SZ000001 / 600000.SH',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: period,
                              decoration: const InputDecoration(labelText: '周期', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'MIN1', child: Text('1分钟')),
                                DropdownMenuItem(value: 'MIN5', child: Text('5分钟')),
                                DropdownMenuItem(value: 'MIN15', child: Text('15分钟')),
                                DropdownMenuItem(value: 'MIN30', child: Text('30分钟')),
                                DropdownMenuItem(value: 'MIN60', child: Text('60分钟')),
                                DropdownMenuItem(value: 'DAILY', child: Text('日线')),
                                DropdownMenuItem(value: 'WEEKLY', child: Text('周线')),
                                DropdownMenuItem(value: 'MONTHLY', child: Text('月线')),
                              ],
                              onChanged: isCsv || _loadingRemote ? null : (v) => setSheetState(() => period = v ?? period),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: adjust,
                              decoration: const InputDecoration(labelText: '复权', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'QFQ', child: Text('前复权')),
                                DropdownMenuItem(value: 'HFQ', child: Text('后复权')),
                                DropdownMenuItem(value: 'NONE', child: Text('不复权')),
                              ],
                              onChanged: isCsv || _loadingRemote ? null : (v) => setSheetState(() => adjust = v ?? adjust),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _dateTile(
                              title: '开始日期',
                              value: start,
                              enabled: !isCsv && !_loadingRemote,
                              onTap: () async {
                                final picked = await _pickDate(initialDate: start);
                                if (picked == null) return;
                                setSheetState(() {
                                  start = picked;
                                  if (start.isAfter(end)) end = picked;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dateTile(
                              title: '结束日期',
                              value: end,
                              enabled: !isCsv && !_loadingRemote,
                              onTap: () async {
                                final picked = await _pickDate(initialDate: end);
                                if (picked == null) return;
                                setSheetState(() {
                                  end = picked;
                                  if (start.isAfter(end)) start = picked;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _loadingRemote
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      setState(() => _dataSourceKind = MarketDataSourceKind.localCsv);
                                      _importCsv();
                                    },
                              icon: const Icon(Icons.upload_file),
                              label: const Text('选择CSV'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _loadingRemote
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      setState(() {
                                        _dataSourceKind = sourceKind;
                                        _period = period;
                                        _adjust = adjust;
                                        _startDate = start;
                                        _endDate = end;
                                      });
                                      _loadMarketData();
                                    },
                              icon: _loadingRemote
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.cloud_download),
                              label: Text(isCsv ? '选择CSV' : '加载K线'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dateTile({required String title, required DateTime value, required bool enabled, required VoidCallback onTap}) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.38,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(labelText: title, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_month)),
          child: Text(_fmtDate(value), style: const TextStyle(fontSize: 14)),
        ),
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      builder: (context) {
        var temp = _config;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Vespa/chan.py 引擎参数', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('缠论计算逻辑只允许对齐 Vespa/chan.py；前端可调整显示、数据源和 candlesticks 图表。', style: TextStyle(color: Colors.white70)),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('candlesticks 官方帮助文档'),
                      subtitle: Text(_candlesticksDocsUri.toString()),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: _openCandlesticksDocs,
                    ),
                    SwitchListTile(
                      title: const Text('处理包含关系'),
                      value: temp.enableInclude,
                      onChanged: (v) => setSheetState(() => temp = temp.copyWith(enableInclude: v)),
                    ),
                    SwitchListTile(
                      title: const Text('严格分型/严格成笔'),
                      subtitle: const Text('映射到 chan.py bi_strict'),
                      value: temp.strictFx,
                      onChanged: (v) => setSheetState(() => temp = temp.copyWith(strictFx: v)),
                    ),
                    ListTile(
                      title: const Text('成笔最小合并K线间隔'),
                      subtitle: Slider(
                        min: 3,
                        max: 7,
                        divisions: 4,
                        label: '${temp.minKCountForBi}',
                        value: temp.minKCountForBi.toDouble(),
                        onChanged: (v) => setSheetState(() => temp = temp.copyWith(minKCountForBi: v.round())),
                      ),
                      trailing: Text('${temp.minKCountForBi}'),
                    ),
                    SwitchListTile(
                      title: const Text('允许单笔中枢'),
                      subtitle: const Text('映射到 chan.py one_bi_zs'),
                      value: temp.allowOneBiZs,
                      onChanged: (v) => setSheetState(() => temp = temp.copyWith(allowOneBiZs: v)),
                    ),
                    SwitchListTile(
                      title: const Text('允许跨段中枢'),
                      subtitle: const Text('开启后使用 over_seg；禁止自造非 Vespa 规则'),
                      value: temp.allowCrossSegZs,
                      onChanged: (v) => setSheetState(() => temp = temp.copyWith(allowCrossSegZs: v)),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _config = temp;
                          _rebuildSnapshot();
                        });
                      },
                      child: const Text('应用'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCandlesticksDocs() async {
    final ok = await launchUrl(_candlesticksDocsUri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _showLoadResult(ok: false, message: '× 无法打开 candlesticks 文档：$_candlesticksDocsUri');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      appBar: AppBar(
        toolbarHeight: 40,
        elevation: 0,
        backgroundColor: const Color(0xFF131722),
        title: Text(_dataSourceLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54)),
      ),
      body: SafeArea(
        top: false,
        child: Row(
          children: [
            _buildLeftToolbar(),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildChartPanel()),
                  if (_isStepMode)
                    ReplayControllerBar(
                      enabled: _hasBars,
                      playing: _playing,
                      cursor: _effectiveCursor,
                      total: _allBars.length,
                      onReset: _reset,
                      onStepBack: _stepBack,
                      onStepForward: _stepForward,
                      onTogglePlay: _togglePlay,
                      onSliderChanged: (v) => _jumpTo(v.round()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftToolbar() {
    final width = _toolbarExpanded ? 48.0 : 28.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              _arrowToggle(),
              if (_toolbarExpanded) ...[
                const Divider(height: 12, color: Colors.white12),
                _toolIcon(tooltip: '数据源/标的/周期/日期', icon: Icons.search, onPressed: _loadingRemote ? null : _openDataSourcePanel),
                _toolIcon(tooltip: '一次性显示', icon: Icons.fullscreen, selected: _displayMode == ReplayDisplayMode.full, onPressed: _hasBars ? () => _setDisplayMode(ReplayDisplayMode.full) : null),
                _toolIcon(tooltip: '逐K回放', icon: Icons.play_circle_outline, selected: _displayMode == ReplayDisplayMode.step, onPressed: _hasBars ? () => _setDisplayMode(ReplayDisplayMode.step) : null),
                _toolIcon(tooltip: '引擎参数/帮助', icon: Icons.settings, onPressed: _openSettings),
                const Divider(height: 18, color: Colors.white12),
                _toolIcon(tooltip: '清除十字光标', icon: Icons.add, selected: _crosshairIndex != null, onPressed: _hasBars ? () => setState(() => _crosshairIndex = null) : null),
                _toolIcon(tooltip: '显示分型顶底', icon: Icons.trip_origin, selected: _showFx, onPressed: _hasBars ? () => setState(() => _showFx = !_showFx) : null),
                _toolIcon(tooltip: '显示分型顶底文字', icon: Icons.title, selected: _showFxText, onPressed: _hasBars && _showFx ? () => setState(() => _showFxText = !_showFxText) : null),
                _toolIcon(tooltip: '显示分型顶底连线', icon: Icons.timeline, selected: _showFxLine, onPressed: _hasBars ? () => setState(() => _showFxLine = !_showFxLine) : null),
                _toolIcon(tooltip: '显示笔', icon: Icons.show_chart, selected: _showBi, onPressed: _hasBars ? () => setState(() => _showBi = !_showBi) : null),
                _toolIcon(tooltip: '显示笔端点文字', icon: Icons.text_fields, selected: _showBiText, onPressed: _hasBars && _showBi ? () => setState(() => _showBiText = !_showBiText) : null),
                _toolIcon(tooltip: '显示线段', icon: Icons.multiline_chart, selected: _showSeg, onPressed: _hasBars ? () => setState(() => _showSeg = !_showSeg) : null),
                _toolIcon(tooltip: '显示线段端点文字', icon: Icons.font_download_outlined, selected: _showSegText, onPressed: _hasBars && _showSeg ? () => setState(() => _showSegText = !_showSegText) : null),
                _toolIcon(tooltip: '显示中枢', icon: Icons.crop_square, selected: _showZs, onPressed: _hasBars ? () => setState(() => _showZs = !_showZs) : null),
                const Divider(height: 18, color: Colors.white12),
                _toolIcon(tooltip: '左右放大', icon: Icons.zoom_in, onPressed: _hasBars ? () => _changeWindowSize(_windowSize - 15) : null),
                _toolIcon(tooltip: '左右缩小', icon: Icons.zoom_out, onPressed: _hasBars ? () => _changeWindowSize(_windowSize + 15) : null),
                _toolIcon(tooltip: '上下放大', icon: Icons.keyboard_arrow_up, onPressed: _hasBars ? () => _changePriceScale(_priceScale * 1.18) : null),
                _toolIcon(tooltip: '上下缩小', icon: Icons.keyboard_arrow_down, onPressed: _hasBars ? () => _changePriceScale(_priceScale / 1.18) : null),
                _toolIcon(tooltip: '重置缩放', icon: Icons.center_focus_strong, onPressed: _hasBars ? _resetChartZoom : null),
                _toolIcon(tooltip: '回到最新K线', icon: Icons.my_location, onPressed: _hasBars ? _goToLatest : null),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrowToggle() {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _toolbarExpanded = !_toolbarExpanded),
      child: SizedBox(
        width: _toolbarExpanded ? 36 : 24,
        height: 30,
        child: Center(
          child: Text(_toolbarExpanded ? '<-' : '->', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _toolIcon({required String tooltip, required IconData icon, bool selected = false, required VoidCallback? onPressed}) {
    final enabled = onPressed != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Tooltip(
        message: enabled ? tooltip : '$tooltip（当前不可用）',
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
          color: selected ? Colors.white : Colors.white60,
          disabledColor: Colors.white24,
          style: IconButton.styleFrom(
            backgroundColor: selected ? const Color(0xFF2962FF) : Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }

  Widget _buildChartPanel() {
    return Padding(
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
            snapshot: _snapshot,
            showFx: _showFx,
            showFxLine: _showFxLine,
            showFxText: _showFxText,
            showBi: _showBi,
            showBiText: _showBiText,
            showSeg: _showSeg,
            showSegText: _showSegText,
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
    );
  }

  void _showLoadResult({required bool ok, required String message}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
      ),
    );
  }

  String _dateRangeLabel(DateTime start, DateTime end) => '${_fmtDate(start)}~${_fmtDate(end)}';

  String _barsRangeLabel(List<RawBar> bars) {
    if (bars.isEmpty) return _dateRangeLabel(_startDate, _endDate);
    return '${_fmtDate(bars.first.time)}~${_fmtDate(bars.last.time)}';
  }

  String _fmtDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String get _periodAdjustLabel => '${_periodLabel(_period)}${_adjustLabel(_adjust)}';

  String _periodLabel(String value) {
    return switch (value) {
      'MIN1' => '1分钟',
      'MIN5' => '5分钟',
      'MIN15' => '15分钟',
      'MIN30' => '30分钟',
      'MIN60' => '60分钟',
      'DAILY' => '日线',
      'WEEKLY' => '周线',
      'MONTHLY' => '月线',
      _ => value,
    };
  }

  String _adjustLabel(String value) {
    return switch (value) {
      'QFQ' => '前复权',
      'HFQ' => '后复权',
      'NONE' => '不复权',
      _ => value,
    };
  }

  String _sourceLongLabel(MarketDataSourceKind kind) {
    return switch (kind) {
      MarketDataSourceKind.embeddedEasyTdx => 'Android内置Python easy-tdx',
      MarketDataSourceKind.easyTdxBackend => _isWindowsApp ? 'Windows本机TDX' : 'easy-tdx后端备用',
      MarketDataSourceKind.localCsv => '本地CSV',
    };
  }

  String get _platformSourceHelp {
    if (_isAndroidApp) {
      return 'Android 默认使用内置 Python easy-tdx。所有数据源只提供K线，缠论结构统一由本地 Vespa/Dart 引擎计算。';
    }
    if (_isWindowsApp) {
      return 'Windows 使用本机 easy-tdx 后端。若 127.0.0.1:8000 无服务，程序会后台启动随机端口服务并在加载后释放。';
    }
    return '当前平台不支持 Android 内置 Python；请使用 easy-tdx 后端或CSV。';
  }

  _SymbolSpec? _parseSymbol(String input) {
    var text = input.trim().toUpperCase().replaceAll(' ', '');
    if (text.isEmpty) return null;
    String? market;
    if (text.endsWith('.SH') || text.endsWith('.SS')) {
      market = 'SH';
      text = text.substring(0, text.length - 3);
    } else if (text.endsWith('.SZ')) {
      market = 'SZ';
      text = text.substring(0, text.length - 3);
    } else if (text.startsWith('SH')) {
      market = 'SH';
      text = text.substring(2);
    } else if (text.startsWith('SZ')) {
      market = 'SZ';
      text = text.substring(2);
    }
    if (!RegExp(r'^\d{6}$').hasMatch(text)) return null;
    market ??= _inferMarket(text);
    return _SymbolSpec(code: text, market: market);
  }

  String _inferMarket(String code) {
    if (code.startsWith('6') || code.startsWith('5') || code.startsWith('9')) return 'SH';
    return 'SZ';
  }

  String _targetDisplayName(String codeInput) {
    final parsed = _parseSymbol(codeInput);
    final code = parsed?.code ?? codeInput.trim();
    const known = {
      '000001': '平安银行',
      '000002': '万科A',
      '600000': '浦发银行',
      '600519': '贵州茅台',
      '300750': '宁德时代',
    };
    return '${known[code] ?? 'A股标的'}$code';
  }
}

class _MarketRequest {
  final String code;
  final String market;
  final String? baseUrl;

  const _MarketRequest({required this.code, required this.market, this.baseUrl});
}

class _SymbolSpec {
  final String code;
  final String market;

  const _SymbolSpec({required this.code, required this.market});
}
