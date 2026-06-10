import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/bsp.dart';
import '../../core/models/chan_snapshot.dart';
import '../../data/chan_analysis_json_parser.dart';
import '../../data/python_chan_analysis_source.dart';
import '../../data/scanner_backend_client.dart';
import '../drawing/drawing_object.dart';
import '../drawing/tradingview_drawing_tool.dart';
import '../widgets/easy_macd_panel.dart';
import '../widgets/origin_kline_chart.dart';

class AshareBspScannerPage extends StatefulWidget {
  const AshareBspScannerPage({super.key});

  @override
  State<AshareBspScannerPage> createState() => _AshareBspScannerPageState();
}

class _AshareBspScannerPageState extends State<AshareBspScannerPage> {
  static bool get _isAndroidApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static String get _defaultBackendBaseUrl => _isAndroidApp ? 'android-chaquopy' : 'http://127.0.0.1:8000';

  final TextEditingController _backendUrlController = TextEditingController(text: _defaultBackendBaseUrl);
  final TextEditingController _codeController = TextEditingController(text: '000001');
  final TextEditingController _limitController = TextEditingController(text: '300');

  final List<_ScanResult> _results = <_ScanResult>[];
  final List<String> _logs = <String>[];
  final Map<String, PythonChanAnalysis> _analysisCache = <String, PythonChanAnalysis>{};

  bool _biStrict = true;
  bool _scanning = false;
  bool _analyzing = false;
  int _scanSerial = 0;
  int _scanIndex = 0;
  int _scanTotal = 0;
  int _scanSuccessCount = 0;
  int _scanFailCount = 0;
  int _scanFoundCount = 0;
  String _scanCurrent = '';

  _ScanResult? _selectedResult;
  ChanSnapshot _snapshot = ChanSnapshot.empty();
  String _status = '就绪 - 点击“开始扫描”分析股票';
  String _chartLabel = '扫描器';

  bool _showBi = true;
  bool _showSeg = true;
  bool _showZs = true;
  bool _showBsp = true;
  bool _showMergedBars = false;
  bool _showMacd = true;
  int _windowSize = 90;
  double _priceScale = 1.0;
  int? _viewEndIndex;
  int? _crosshairIndex;

  Map<String, dynamic> get _scannerConfig => <String, dynamic>{
        'bi_strict': _biStrict,
        'trigger_step': false,
        'skip_step': 0,
        'divergence_rate': '1e18',
        'bsp2_follow_1': false,
        'bsp3_follow_1': false,
        'min_zs_cnt': 0,
        'bs1_peak': false,
        'macd_algo': 'peak',
        'bs_type': '1,1p,2,2s,3a,3b',
        'print_warning': false,
        'zs_algo': 'normal',
      };

  @override
  void dispose() {
    _backendUrlController.dispose();
    _codeController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    final serial = ++_scanSerial;
    setState(() {
      _scanning = true;
      _results.clear();
      _logs
        ..clear()
        ..add(_isAndroidApp ? '正在调用 Android Chaquopy 批量扫描...' : '正在启动/连接 Python chan.py 后端...');
      _analysisCache.clear();
      _selectedResult = null;
      _scanIndex = 0;
      _scanTotal = 0;
      _scanSuccessCount = 0;
      _scanFailCount = 0;
      _scanFoundCount = 0;
      _scanCurrent = '';
      _status = _logs.last;
    });

    final client = ScannerBackendClient(baseUrl: _backendUrlController.text.trim());
    try {
      await for (final event in client.scanBspStream(
        days: 365,
        recentDays: 3,
        limit: int.tryParse(_limitController.text.trim()) ?? 300,
        biStrict: _biStrict,
        config: _scannerConfig,
      )) {
        if (!mounted || serial != _scanSerial) break;
        _applyScanEvent(event);
      }
    } catch (e) {
      if (!mounted || serial != _scanSerial) return;
      setState(() {
        _appendLog('❌ 扫描失败: $e');
        _status = '扫描失败: $e';
      });
    } finally {
      client.close();
      if (mounted && serial == _scanSerial) setState(() => _scanning = false);
    }
  }

  void _applyScanEvent(Map<String, dynamic> event) {
    setState(() {
      final type = '${event['type'] ?? ''}';
      if (type == 'start') {
        _scanTotal = _toInt(event['total']) ?? _scanTotal;
        _status = '${event['message'] ?? '开始扫描...'}';
        _appendLog(_status);
      } else if (type == 'progress') {
        _scanIndex = _toInt(event['index']) ?? _scanIndex;
        _scanTotal = _toInt(event['total']) ?? _scanTotal;
        _scanSuccessCount = _toInt(event['success_count']) ?? _scanSuccessCount;
        _scanFailCount = _toInt(event['fail_count']) ?? _scanFailCount;
        _scanFoundCount = _toInt(event['found_count']) ?? _scanFoundCount;
        _scanCurrent = '${event['code'] ?? ''} ${event['name'] ?? ''}'.trim();
        _status = '${event['message'] ?? '扫描中...'}';
      } else if (type == 'log') {
        _appendLog('${event['message'] ?? ''}');
      } else if (type == 'result') {
        final row = event['row'];
        if (row is Map) {
          final result = _ScanResult.fromJson(Map<String, dynamic>.from(row));
          if (!_results.any((item) => item.sameSignal(result))) _results.add(result);
          _cacheAnalysis(result, event['analysis'] ?? row['analysis']);
        }
        _scanIndex = _toInt(event['index']) ?? _scanIndex;
        _scanTotal = _toInt(event['total']) ?? _scanTotal;
        _scanSuccessCount = _toInt(event['success_count']) ?? _scanSuccessCount;
        _scanFailCount = _toInt(event['fail_count']) ?? _scanFailCount;
        _scanFoundCount = _toInt(event['found_count']) ?? _results.length;
        _status = '发现买点 $_scanFoundCount 个，可直接点击结果查看K线；扫描继续运行';
      } else if (type == 'error') {
        _appendLog('❌ ${event['message'] ?? '扫描失败'}');
        _status = '${event['message'] ?? '扫描失败'}';
      } else if (type == 'done') {
        _scanTotal = _toInt(event['total']) ?? _scanTotal;
        _scanSuccessCount = _toInt(event['success_count']) ?? _scanSuccessCount;
        _scanFailCount = _toInt(event['fail_count']) ?? _scanFailCount;
        _scanFoundCount = _toInt(event['found_count']) ?? _results.length;
        final rows = event['results'];
        if (rows is List) {
          for (final row in rows.whereType<Map>()) {
            final result = _ScanResult.fromJson(Map<String, dynamic>.from(row));
            if (!_results.any((item) => item.sameSignal(result))) _results.add(result);
            _cacheAnalysis(result, row['analysis']);
          }
        }
        _scanIndex = _scanTotal;
        _status = '扫描完成: 成功$_scanSuccessCount只, 跳过$_scanFailCount只, 发现$_scanFoundCount只买点股票';
      }
    });
  }

  void _cacheAnalysis(_ScanResult result, Object? rawAnalysis) {
    if (rawAnalysis is! Map) return;
    try {
      _analysisCache[result.cacheKey] = parseChanAnalysisJson(Map<String, dynamic>.from(rawAnalysis));
    } catch (e) {
      _appendLog('⚠️ ${result.code} 缓存分析结果解析失败，将在点击时重新分析: $e');
    }
  }

  void _appendLog(String message) {
    final text = message.trim();
    if (text.isEmpty) return;
    _logs.add(text);
    if (_logs.length > 1400) _logs.removeRange(0, _logs.length - 1400);
  }

  void _stopScan() {
    if (!_scanning) return;
    _scanSerial++;
    setState(() {
      _scanning = false;
      _status = '正在停止扫描...';
      _appendLog('⏹️ 已请求停止扫描');
    });
  }

  Future<void> _analyzeSingle() async {
    final code = _normalizeCode(_codeController.text);
    if (code == null) {
      _showMessage('请输入股票代码，如 000001');
      return;
    }
    await _loadChartFor(code: code, market: _inferMarket(code), target: null);
  }

  Future<void> _openResult(_ScanResult result) async {
    final cached = _analysisCache[result.cacheKey];
    if (cached != null) {
      _applyAnalysis(cached, target: result, fromCache: true);
      return;
    }
    await _loadChartFor(code: result.code, market: result.market, target: result);
  }

  Future<void> _loadChartFor({required String code, required String market, required _ScanResult? target}) async {
    if (_analyzing) return;
    final source = PythonChanAnalysisSource(baseUrl: _backendUrlController.text.trim());
    setState(() {
      _analyzing = true;
      _status = '正在分析 $code...';
    });
    try {
      final now = DateTime.now();
      final analysis = await source.analyze(
        mode: 'once',
        market: market,
        code: code,
        period: 'DAILY',
        adjust: 'QFQ',
        startDate: now.subtract(const Duration(days: 365)),
        endDate: now,
        config: _scannerConfig,
      );
      if (!mounted) return;
      _applyAnalysis(analysis, target: target, fromCache: false);
    } catch (e) {
      if (mounted) _showMessage('分析失败: $e');
    } finally {
      source.close();
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _applyAnalysis(PythonChanAnalysis analysis, {required _ScanResult? target, required bool fromCache}) {
    final snapshot = analysis.snapshot;
    final targetBsp = target == null ? null : _matchBsp(snapshot, target);
    final rawIndex = targetBsp?.rawIndex ?? target?.rawIndex;
    setState(() {
      _snapshot = snapshot;
      _selectedResult = target;
      _priceScale = 1.0;
      if (rawIndex != null && snapshot.rawBars.isNotEmpty) {
        final maxEnd = snapshot.rawBars.length - 1;
        final focus = rawIndex.clamp(0, maxEnd).toInt();
        _crosshairIndex = focus;
        _viewEndIndex = (focus + math.max(20, _windowSize ~/ 2)).clamp(0, maxEnd).toInt();
      } else {
        _crosshairIndex = null;
        _viewEndIndex = null;
      }
      _chartLabel = target == null ? '单股分析' : '${target.name} ${target.market}${target.code} ${target.bspType} ${_fmtDate(target.bspTime)}';
      _status = target == null
          ? '分析完成'
          : '显示: ${target.code} ${target.name} ${target.bspType} ${_fmtDate(target.bspTime)}${fromCache ? '（复用扫描缓存）' : '（重新分析）'}';
    });
  }

  BspPoint? _matchBsp(ChanSnapshot snapshot, _ScanResult result) {
    for (final bsp in snapshot.bsps) {
      if (bsp.rawIndex == result.rawIndex && (result.bspType.isEmpty || bsp.type == result.bspType || bsp.type.contains(result.bspType))) return bsp;
    }
    for (final bsp in snapshot.bsps) {
      if (bsp.rawIndex == result.rawIndex) return bsp;
    }
    final rawIndex = result.rawIndex;
    if (rawIndex == null || snapshot.rawBars.isEmpty) return null;
    final raw = rawIndex.clamp(0, snapshot.rawBars.length - 1).toInt();
    return BspPoint(index: -1, rawIndex: raw, time: result.bspTime, price: result.bspPrice ?? snapshot.rawBars[raw].close, type: result.bspType.isEmpty ? 'BSP' : result.bspType, level: result.level);
  }

  List<DrawingObject> _highlightObjects() {
    final result = _selectedResult;
    if (result == null || _snapshot.rawBars.isEmpty) return const [];
    final bsp = _matchBsp(_snapshot, result);
    if (bsp == null) return const [];
    final maxRaw = _snapshot.rawBars.length - 1;
    final leftRaw = math.max(0, bsp.rawIndex - 1).toInt();
    final rightRaw = math.min(maxRaw, bsp.rawIndex + 1).toInt();
    final pricePad = math.max(bsp.price.abs() * 0.012, 0.01);
    final now = DateTime.now();
    return <DrawingObject>[
      DrawingObject(
        id: 'scanner_bsp_circle_${result.code}_${bsp.rawIndex}',
        tool: TradingViewDrawingTool.circle,
        anchors: <DrawingAnchor>[
          DrawingAnchor.chart(rawIndex: leftRaw, price: bsp.price - pricePad),
          DrawingAnchor.chart(rawIndex: rightRaw, price: bsp.price + pricePad),
        ],
        style: const DrawingStyle(colorValue: 0xFFFFD54F, strokeWidth: 2.4, filled: true, fillColorValue: 0x22FFD54F, fillOpacity: 0.14),
        locked: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  void _refresh(VoidCallback action) {
    if (!mounted) return;
    setState(action);
  }

  void _panChartByBars(int bars) {
    if (bars == 0 || _snapshot.rawBars.isEmpty) return;
    final maxEnd = _snapshot.rawBars.length - 1;
    final current = _viewEndIndex ?? maxEnd;
    final next = (current + bars).clamp(0, maxEnd).toInt();
    if (next != current) setState(() => _viewEndIndex = next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0D10),
      child: Row(
        children: [
          SizedBox(width: 520, child: _buildLeftPanel()),
          Container(width: 1, color: Colors.white.withValues(alpha: 0.08)),
          Expanded(child: _buildChartPanel()),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() => Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            SizedBox(height: 150, child: _scanControlPanel()),
            const SizedBox(height: 8),
            SizedBox(height: 158, child: _settingsPanel()),
            const SizedBox(height: 8),
            SizedBox(height: 100, child: _singleAnalysisPanel()),
            const SizedBox(height: 8),
            Expanded(child: _resultsPanel()),
            const SizedBox(height: 8),
            SizedBox(height: 170, child: _logsPanel()),
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerLeft, child: Text(_status, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          ],
        ),
      );

  Widget _panel(String title, {required Widget child, Widget? trailing}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF131722), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), const Spacer(), if (trailing != null) trailing]),
          const SizedBox(height: 8),
          Expanded(child: child),
        ]),
      );

  Widget _scanControlPanel() => _panel(
        '扫描控制',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: _scanning ? null : _startScan, icon: _scanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow), label: const Text('开始扫描'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.tonalIcon(onPressed: _scanning ? _stopScan : null, icon: const Icon(Icons.stop), label: const Text('停止'))),
            ]),
            const SizedBox(height: 8),
            _progressBlock(),
          ],
        ),
      );

  Widget _settingsPanel() => _panel(
        '扫描参数',
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: _biStrict, onChanged: _scanning ? null : (v) => setState(() => _biStrict = v ?? _biStrict), title: const Text('笔严格模式')),
            TextField(controller: _backendUrlController, enabled: !_scanning && !_isAndroidApp, decoration: InputDecoration(labelText: _isAndroidApp ? 'Android Chaquopy 本地引擎' : 'Windows Python chan.py 服务地址', border: const OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _limitController, enabled: !_scanning, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '扫描数量上限', helperText: '默认 300；支持最大 5000', border: OutlineInputBorder())),
          ]),
        ),
      );

  Widget _singleAnalysisPanel() => _panel(
        '单股分析',
        child: Row(children: [
          Expanded(child: TextField(controller: _codeController, enabled: !_analyzing, decoration: const InputDecoration(labelText: '单股分析代码', hintText: '如: 000001', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          SizedBox(width: 88, height: 48, child: FilledButton(onPressed: _analyzing ? null : _analyzeSingle, child: _analyzing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('分析'))),
        ]),
      );

  Widget _progressBlock() {
    final progress = _scanTotal > 0 ? (_scanIndex / _scanTotal).clamp(0.0, 1.0).toDouble() : null;
    final percent = progress == null ? '--' : '${(progress * 100).toStringAsFixed(1)}%';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LinearProgressIndicator(value: _scanning ? progress : (_scanTotal > 0 ? progress : 0.0)),
      const SizedBox(height: 6),
      Text('进度 $percent  $_scanIndex/$_scanTotal  成功$_scanSuccessCount  跳过$_scanFailCount  买点$_scanFoundCount', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      if (_scanCurrent.isNotEmpty) Text('当前: $_scanCurrent', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }

  Widget _resultsPanel() => _panel(
        '买点股票列表',
        trailing: TextButton.icon(onPressed: _results.isEmpty ? null : () => setState(() { _results.clear(); _selectedResult = null; _scanFoundCount = 0; _analysisCache.clear(); }), icon: const Icon(Icons.clear_all, size: 16), label: const Text('清空列表')),
        child: _results.isEmpty
            ? const Center(child: Text('暂无买点结果；扫描中一旦发现会实时出现在这里', style: TextStyle(color: Colors.white54)))
            : Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowHeight: 32,
                      dataRowMinHeight: 34,
                      dataRowMaxHeight: 42,
                      columnSpacing: 14,
                      columns: const [DataColumn(label: Text('代码')), DataColumn(label: Text('名称')), DataColumn(label: Text('现价')), DataColumn(label: Text('涨跌%')), DataColumn(label: Text('买点'))],
                      rows: [
                        for (final result in _results)
                          DataRow(selected: result.sameSignal(_selectedResult), onSelectChanged: (_) => _openResult(result), cells: [
                            DataCell(Text(result.code)),
                            DataCell(Text(result.name, overflow: TextOverflow.ellipsis)),
                            DataCell(Text(_fmtNum(result.price))),
                            DataCell(Text(_fmtNum(result.change))),
                            DataCell(Text('${result.bspType} (${_fmtDate(result.bspTime)})${_analysisCache.containsKey(result.cacheKey) ? ' 缓存' : ''}')),
                          ]),
                      ],
                    ),
                  ),
                ),
              ),
      );

  Widget _logsPanel() => _panel(
        '扫描日志',
        trailing: TextButton.icon(onPressed: _logs.isEmpty ? null : () => setState(() => _logs.clear()), icon: const Icon(Icons.delete_outline, size: 16), label: const Text('清空日志')),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF0B0D10), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: SingleChildScrollView(reverse: true, child: SelectableText(_logs.isEmpty ? '暂无日志' : _logs.join('\n'), style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.35))),
        ),
      );

  Widget _buildChartPanel() => Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(children: [_chartToolbar(), const SizedBox(height: 8), Expanded(child: _chartCanvas())]),
      );

  Widget _chartCanvas() => DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xFF131722), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _snapshot.rawBars.isEmpty
              ? const Center(child: Text('点击扫描结果或单股分析后显示 chan.py 图表', style: TextStyle(color: Colors.white70)))
              : Column(children: [
                  Expanded(
                    child: OriginKlineChart(
                      snapshot: _snapshot,
                      showFx: false,
                      showFxLine: false,
                      showFxText: false,
                      showBi: _showBi,
                      showBiText: false,
                      showSeg: _showSeg,
                      showSegText: true,
                      showZs: _showZs,
                      showBiBsp: _showBsp,
                      showSegBsp: _showBsp,
                      showMergedBars: _showMergedBars,
                      drawingObjects: _highlightObjects(),
                      drawingStorageKey: _drawingStorageKey,
                      symbolLabel: _chartLabel,
                      windowSize: _windowSize,
                      priceScale: _priceScale,
                      viewEndIndex: _viewEndIndex,
                      crosshairIndex: _crosshairIndex,
                      onCrosshairChanged: (v) => _refresh(() => _crosshairIndex = v),
                      onPanBars: _panChartByBars,
                      onWindowSizeChanged: (v) => _refresh(() => _windowSize = v),
                      onPriceScaleChanged: (v) => _refresh(() => _priceScale = v),
                    ),
                  ),
                  if (_showMacd)
                    SizedBox(
                      height: 138,
                      child: DecoratedBox(
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
                        child: EasyMacdPanel(snapshot: _snapshot, windowSize: _windowSize, viewEndIndex: _viewEndIndex),
                      ),
                    ),
                ]),
        ),
      );

  Widget _chartToolbar() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFF131722), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
        child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _disabledCheck('K线', true, 'K线为主图基础层，当前不可关闭'),
          _check('合并K线', _showMergedBars, (v) => setState(() => _showMergedBars = v)),
          _check('笔', _showBi, (v) => setState(() => _showBi = v)),
          _check('线段', _showSeg, (v) => setState(() => _showSeg = v)),
          _check('中枢', _showZs, (v) => setState(() => _showZs = v)),
          _check('买卖点', _showBsp, (v) => setState(() => _showBsp = v)),
          _check('MACD', _showMacd, (v) => setState(() => _showMacd = v)),
          OutlinedButton.icon(onPressed: _snapshot.rawBars.isEmpty || _analyzing ? null : () { final result = _selectedResult; result == null ? _analyzeSingle() : _openResult(result); }, icon: const Icon(Icons.refresh, size: 16), label: const Text('刷新图表')),
        ]),
      );

  Widget _check(String label, bool value, ValueChanged<bool> onChanged) => InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Checkbox(value: value, onChanged: (v) => onChanged(v ?? value), visualDensity: VisualDensity.compact), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))]),
        ),
      );

  Widget _disabledCheck(String label, bool value, String tooltip) => Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Checkbox(value: value, onChanged: null, visualDensity: VisualDensity.compact), Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12))]),
        ),
      );

  String get _drawingStorageKey {
    final result = _selectedResult;
    if (result == null) return 'scanner_single';
    return 'scanner_${result.market}_${result.code}_DAILY_QFQ';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF1E3A8A)));
  }

  static String? _normalizeCode(String value) {
    final code = value.trim().toUpperCase().replaceAll('.SZ', '').replaceAll('.SH', '').replaceAll(RegExp(r'[^0-9]'), '');
    if (code.length < 6) return null;
    return code.substring(code.length - 6);
  }

  static String _inferMarket(String code) => code.startsWith(RegExp(r'[569]')) ? 'SH' : 'SZ';

  static int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim());
  }

  static String _fmtNum(num? value) => value == null ? '-' : value.toStringAsFixed(2);

  static String _fmtDate(DateTime? value) {
    if (value == null) return '-';
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}

class _ScanResult {
  final String code;
  final String market;
  final String name;
  final double? price;
  final double? change;
  final String bspType;
  final DateTime? bspTime;
  final int? rawIndex;
  final double? bspPrice;
  final String level;

  const _ScanResult({required this.code, required this.market, required this.name, required this.price, required this.change, required this.bspType, required this.bspTime, required this.rawIndex, required this.bspPrice, required this.level});

  factory _ScanResult.fromJson(Map<String, dynamic> json) {
    final code = _string(json['code']);
    final market = _string(json['market']);
    return _ScanResult(
      code: code,
      market: market.isEmpty ? _inferMarket(code) : market,
      name: _string(json['name']).isEmpty ? code : _string(json['name']),
      price: _double(json['price']),
      change: _double(json['change']),
      bspType: _string(json['bsp_type'] ?? json['bspType']),
      bspTime: _date(json['bsp_time'] ?? json['bspTime']),
      rawIndex: _int(json['raw_index'] ?? json['rawIndex']),
      bspPrice: _double(json['bsp_price'] ?? json['bspPrice']),
      level: _string(json['level']),
    );
  }

  String get cacheKey => '$market:$code:${rawIndex ?? -1}:$bspType:$level';

  bool sameSignal(_ScanResult? other) {
    if (other == null) return false;
    return code == other.code && market == other.market && rawIndex == other.rawIndex && bspType == other.bspType && level == other.level;
  }

  static String _string(Object? value) => '${value ?? ''}'.trim();

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    final text = '${value ?? ''}'.replaceAll(',', '').trim();
    if (text.isEmpty || text == '-' || text.toLowerCase() == 'null') return null;
    return double.tryParse(text);
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim());
  }

  static DateTime? _date(Object? value) {
    final text = '${value ?? ''}'.trim().replaceFirst(' ', 'T').replaceAll('/', '-');
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return DateTime.tryParse(text);
  }

  static String _inferMarket(String code) => code.startsWith(RegExp(r'[569]')) ? 'SH' : 'SZ';
}
