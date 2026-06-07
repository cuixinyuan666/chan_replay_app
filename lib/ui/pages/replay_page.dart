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
import '../../data/tencent_kline_source.dart';
import '../widgets/kline_chart.dart';
import '../widgets/replay_controller_bar.dart';

enum ReplayDisplayMode { full, step }

enum MarketDataSourceKind { embeddedEasyTdx, easyTdxBackend, tencent, sampleCsv }

class ReplayPage extends StatefulWidget {
  const ReplayPage({super.key});

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {
  static final Uri _candlesticksDocsUri = Uri.parse('https://pub.dev/packages/candlesticks');

  final ChanReplayEngine _engine = ChanReplayEngine();
  final TextEditingController _stockCodeController = TextEditingController(text: '000001');
  final TextEditingController _startDateController = TextEditingController(text: '2020-01-01');
  final TextEditingController _endDateController = TextEditingController();
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
  ReplayDisplayMode _displayMode = ReplayDisplayMode.step;
  MarketDataSourceKind _dataSourceKind = _defaultSourceKind;
  Timer? _timer;

  ChanConfig _config = ChanConfig.chanPyDefault();
  String _market = 'SZ';
  String _period = 'DAILY';
  String _adjust = 'QFQ';
  int _count = 800;
  String _dataSourceLabel = '未加载';

  static bool get _isAndroidApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
      MarketDataSourceKind.tencent,
      MarketDataSourceKind.sampleCsv,
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadSample();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stockCodeController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _easyTdxBaseUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSample() async {
    final bars = await CsvLoader.loadFromAsset('assets/sample_data/000001_daily.csv');
    if (!mounted) return;
    setState(() {
      _dataSourceKind = MarketDataSourceKind.sampleCsv;
      _applyBars(bars, sourceLabel: '示例CSV / Vespa本地引擎');
    });
  }

  Future<void> _importCsv() async {
    final bars = await CsvLoader.pickAndLoadCsv();
    if (bars == null || bars.isEmpty) {
      if (!mounted) return;
      _showSnack('未读取到有效CSV数据');
      return;
    }
    setState(() {
      _dataSourceKind = MarketDataSourceKind.sampleCsv;
      _applyBars(bars, sourceLabel: '本地CSV / Vespa本地引擎');
    });
  }

  Future<void> _loadMarketData() async {
    if (_loadingRemote) return;
    switch (_dataSourceKind) {
      case MarketDataSourceKind.sampleCsv:
        await _loadSample();
        return;
      case MarketDataSourceKind.tencent:
        await _loadTencent();
        return;
      case MarketDataSourceKind.easyTdxBackend:
        await _loadEasyTdxBackend();
        return;
      case MarketDataSourceKind.embeddedEasyTdx:
        if (!_isAndroidApp) {
          _showSnack('内置 Python easy-tdx 仅支持 Android；Windows 请使用 easy-tdx 后端备用（可自动后台启动本机服务）');
          return;
        }
        await _loadEmbeddedEasyTdx();
        return;
    }
  }

  Future<void> _loadEmbeddedEasyTdx() async {
    final request = _buildMarketRequest(requireBackend: false);
    if (request == null) return;
    setState(() => _loadingRemote = true);
    final source = EmbeddedEasyTdxSource();
    try {
      final bars = await source.loadKline(
        market: _market,
        code: request.code,
        period: _period,
        adjust: _adjust,
        count: _count,
        startDate: request.startDate,
        endDate: request.endDate,
      );
      if (!mounted) return;
      if (bars.isEmpty) {
        _showSnack('内置 easy-tdx 未返回有效K线数据，请检查网络、市场、代码、起止时间和K线数量');
        return;
      }
      setState(() {
        _applyBars(
          bars,
          sourceLabel: 'Android内置easy-tdx $_market${request.code} $_period $_adjust ${bars.length}根${_dateRangeLabel(request.startDate, request.endDate)} / Vespa本地引擎',
        );
      });
    } catch (e) {
      if (mounted) _showSnack('内置 easy-tdx 加载失败：$e');
    } finally {
      if (mounted) setState(() => _loadingRemote = false);
    }
  }

  Future<void> _loadTencent() async {
    final request = _buildMarketRequest(requireBackend: false);
    if (request == null) return;
    setState(() => _loadingRemote = true);
    final source = TencentKlineSource();
    try {
      final bars = await source.loadKline(
        market: _market,
        code: request.code,
        period: _period,
        adjust: _adjust,
        count: _count,
        startDate: request.startDate,
        endDate: request.endDate,
      );
      if (!mounted) return;
      if (bars.isEmpty) {
        _showSnack('腾讯行情未返回有效K线数据，请检查市场、代码、起止时间和K线数量');
        return;
      }
      setState(() {
        _applyBars(
          bars,
          sourceLabel: '腾讯行情 $_market${request.code} $_period $_adjust ${bars.length}根${_dateRangeLabel(request.startDate, request.endDate)} / Vespa本地引擎',
        );
      });
    } catch (e) {
      if (mounted) _showSnack('腾讯行情加载失败：$e');
    } finally {
      source.close();
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
        market: _market,
        code: request.code,
        period: _period,
        adjust: _adjust,
        count: _count,
        startDate: request.startDate,
        endDate: request.endDate,
      );
      if (!mounted) return;
      if (bars.isEmpty) {
        _showSnack('easy-tdx 后端未返回有效K线数据，请检查后端、市场、代码、起止时间和K线数量');
        return;
      }
      setState(() {
        _applyBars(
          bars,
          sourceLabel: '${_isAndroidApp ? 'Android调试后端' : 'Windows自动本机后端'} easy-tdx $_market${request.code} $_period $_adjust ${bars.length}根${_dateRangeLabel(request.startDate, request.endDate)} / Vespa本地引擎',
        );
      });
    } catch (e) {
      if (mounted) _showSnack('easy-tdx 后端加载失败：$e');
    } finally {
      source.close();
      if (mounted) setState(() => _loadingRemote = false);
    }
  }

  _MarketRequest? _buildMarketRequest({required bool requireBackend}) {
    final code = _stockCodeController.text.trim();
    if (code.isEmpty) {
      _showSnack('请填写股票代码');
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
    final baseUrl = _easyTdxBaseUrlController.text.trim();
    if (requireBackend && baseUrl.isEmpty) {
      _showSnack('请填写 easy-tdx 后端地址');
      return null;
    }
    return _MarketRequest(code: code, startDate: startDate, endDate: endDate, baseUrl: requireBackend ? baseUrl : null);
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
    if (_displayMode == mode) return;
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

  void _openDataSourcePanel() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      builder: (context) {
        var sourceKind = _availableSourceKinds.contains(_dataSourceKind) ? _dataSourceKind : _defaultSourceKind;
        var market = _market;
        var period = _period;
        var adjust = _adjust;
        var count = _count;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isSample = sourceKind == MarketDataSourceKind.sampleCsv;
            final usesBackend = sourceKind == MarketDataSourceKind.easyTdxBackend;
            final sourceItems = _availableSourceKinds
                .map((kind) => DropdownMenuItem(value: kind, child: Text(_sourceLongLabel(kind))))
                .toList(growable: false);
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
                        decoration: const InputDecoration(labelText: '数据源（唯一入口）', border: OutlineInputBorder()),
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
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: market,
                              decoration: const InputDecoration(labelText: '市场', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'SZ', child: Text('深市 SZ')),
                                DropdownMenuItem(value: 'SH', child: Text('沪市 SH')),
                              ],
                              onChanged: isSample || _loadingRemote ? null : (v) => setSheetState(() => market = v ?? market),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _stockCodeController,
                              enabled: !isSample && !_loadingRemote,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: '代码', hintText: '000001', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
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
                              onChanged: isSample || _loadingRemote ? null : (v) => setSheetState(() => period = v ?? period),
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
                              onChanged: isSample || _loadingRemote ? null : (v) => setSheetState(() => adjust = v ?? adjust),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _startDateController,
                              enabled: !isSample && !_loadingRemote,
                              keyboardType: TextInputType.datetime,
                              decoration: const InputDecoration(labelText: '开始日期', hintText: 'yyyy-MM-dd', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _endDateController,
                              enabled: !isSample && !_loadingRemote,
                              keyboardType: TextInputType.datetime,
                              decoration: const InputDecoration(labelText: '结束日期', hintText: '留空为最新', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ListTile(
                        enabled: !isSample && !_loadingRemote,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('读取K线数量'),
                        subtitle: Slider(
                          min: 100,
                          max: 5000,
                          divisions: 49,
                          label: '$count',
                          value: count.toDouble().clamp(100.0, 5000.0).toDouble(),
                          onChanged: isSample || _loadingRemote ? null : (v) => setSheetState(() => count = v.round()),
                        ),
                        trailing: Text('$count'),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _loadingRemote
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      _loadSample();
                                    },
                              icon: const Icon(Icons.dataset),
                              label: const Text('示例CSV'),
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
                                        _market = market;
                                        _period = period;
                                        _adjust = adjust;
                                        _count = count;
                                      });
                                      _loadMarketData();
                                    },
                              icon: _loadingRemote
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.cloud_download),
                              label: const Text('加载K线'),
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
    if (!ok && mounted) _showSnack('无法打开 candlesticks 文档：$_candlesticksDocsUri');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: AppBar(
          toolbarHeight: 52,
          elevation: 0,
          titleSpacing: 0,
          backgroundColor: const Color(0xFF131722),
          title: _buildTopToolbar(context),
        ),
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
                  ReplayControllerBar(
                    enabled: _isStepMode && _hasBars,
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

  Widget _buildTopToolbar(BuildContext context) {
    final code = _stockCodeController.text.trim().isEmpty ? '000001' : _stockCodeController.text.trim();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 8),
          _toolbarButton(label: '$_market:$code', icon: Icons.search, selected: true, onTap: _openDataSourcePanel),
          const SizedBox(width: 6),
          _toolbarButton(label: '一次性', selected: _displayMode == ReplayDisplayMode.full, onTap: () => _setDisplayMode(ReplayDisplayMode.full)),
          _toolbarButton(label: '逐K', selected: _displayMode == ReplayDisplayMode.step, onTap: () => _setDisplayMode(ReplayDisplayMode.step)),
          const SizedBox(width: 6),
          _toolbarButton(label: _sourceShortLabel(_dataSourceKind), icon: Icons.storage, onTap: _openDataSourcePanel),
          _toolbarButton(label: 'CSV', icon: Icons.upload_file, onTap: _loadingRemote ? null : _importCsv),
          _toolbarButton(label: '最新', icon: Icons.keyboard_double_arrow_right, onTap: _hasBars ? _goToLatest : null),
          _toolbarButton(label: '设置', icon: Icons.settings, onTap: _openSettings),
          const SizedBox(width: 10),
          Text(_dataSourceLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _toolbarButton({required String label, IconData? icon, bool selected = false, required VoidCallback? onTap}) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.38,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF2962FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: Colors.white70),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                ),
              ],
            ),
          ),
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
                _toolIcon(tooltip: '清除十字光标', icon: Icons.add, selected: _crosshairIndex != null, onPressed: _hasBars ? () => setState(() => _crosshairIndex = null) : null),
                _toolIcon(tooltip: '显示分型顶底', icon: Icons.trip_origin, selected: _showFx, onPressed: () => setState(() => _showFx = !_showFx)),
                _toolIcon(tooltip: '显示分型顶底文字', icon: Icons.title, selected: _showFxText, onPressed: _showFx ? () => setState(() => _showFxText = !_showFxText) : null),
                _toolIcon(tooltip: '显示分型顶底连线', icon: Icons.timeline, selected: _showFxLine, onPressed: () => setState(() => _showFxLine = !_showFxLine)),
                _toolIcon(tooltip: '显示笔', icon: Icons.show_chart, selected: _showBi, onPressed: () => setState(() => _showBi = !_showBi)),
                _toolIcon(tooltip: '显示笔端点文字', icon: Icons.text_fields, selected: _showBiText, onPressed: _showBi ? () => setState(() => _showBiText = !_showBiText) : null),
                _toolIcon(tooltip: '显示线段', icon: Icons.multiline_chart, selected: _showSeg, onPressed: () => setState(() => _showSeg = !_showSeg)),
                _toolIcon(tooltip: '显示线段端点文字', icon: Icons.font_download_outlined, selected: _showSegText, onPressed: _showSeg ? () => setState(() => _showSegText = !_showSegText) : null),
                _toolIcon(tooltip: '显示中枢', icon: Icons.crop_square, selected: _showZs, onPressed: () => setState(() => _showZs = !_showZs)),
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

  void _showSnack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

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

  String _dateRangeLabel(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    return ' ${_fmtDate(start) ?? '开始'}~${_fmtDate(end) ?? '最新'}';
  }

  String? _fmtDate(DateTime? dt) {
    if (dt == null) return null;
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _periodLabel(String value) {
    return switch (value) {
      'MIN1' => '1分',
      'MIN5' => '5分',
      'MIN15' => '15分',
      'MIN30' => '30分',
      'MIN60' => '60分',
      'DAILY' => '日线',
      'WEEKLY' => '周线',
      'MONTHLY' => '月线',
      _ => value,
    };
  }

  String _sourceShortLabel(MarketDataSourceKind kind) {
    return switch (kind) {
      MarketDataSourceKind.embeddedEasyTdx => 'Android内置TDX',
      MarketDataSourceKind.easyTdxBackend => defaultTargetPlatform == TargetPlatform.windows ? 'Windows本机TDX' : 'TDX后端',
      MarketDataSourceKind.tencent => '腾讯',
      MarketDataSourceKind.sampleCsv => 'CSV',
    };
  }

  String _sourceLongLabel(MarketDataSourceKind kind) {
    return switch (kind) {
      MarketDataSourceKind.embeddedEasyTdx => 'Android：内置 Python easy-tdx（无需外部后端）',
      MarketDataSourceKind.easyTdxBackend => defaultTargetPlatform == TargetPlatform.windows
          ? 'Windows：本机 easy-tdx 后端（可自动后台启动）'
          : 'easy-tdx 后端备用（Android模拟器/调试）',
      MarketDataSourceKind.tencent => '腾讯行情直连（备用数据源）',
      MarketDataSourceKind.sampleCsv => '示例CSV / 本地CSV（离线复盘）',
    };
  }

  String get _platformSourceHelp {
    if (_isAndroidApp) {
      return 'Android 默认使用内置 Python easy-tdx；Windows 项不会显示该选项。所有数据源只提供K线，缠论结构统一由本地 Vespa/Dart 引擎计算。';
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return 'Windows 使用本机 easy-tdx 后端。若 127.0.0.1:8000 无服务，程序会后台启动随机端口服务并在加载后释放。';
    }
    return '当前平台不支持 Android 内置 Python；请使用 easy-tdx 后端、腾讯行情或CSV。';
  }
}

class _MarketRequest {
  final String code;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? baseUrl;

  const _MarketRequest({required this.code, this.startDate, this.endDate, this.baseUrl});
}
