import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/bsp.dart';
import '../../core/models/chan_snapshot.dart';
import '../../data/python_chan_analysis_source.dart';
import '../../data/scanner_backend_client.dart';
import '../drawing/drawing_object.dart';
import '../drawing/tradingview_drawing_tool.dart';
import '../widgets/origin_kline_chart.dart';

class AshareBspScannerPage extends StatefulWidget {
  const AshareBspScannerPage({super.key});

  @override
  State<AshareBspScannerPage> createState() => _AshareBspScannerPageState();
}

class _AshareBspScannerPageState extends State<AshareBspScannerPage> {
  static bool get _isAndroidApp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static String get _defaultBackendBaseUrl =>
      _isAndroidApp ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';

  final TextEditingController _backendUrlController =
      TextEditingController(text: _defaultBackendBaseUrl);
  final TextEditingController _codeController =
      TextEditingController(text: '000001');
  final TextEditingController _limitController =
      TextEditingController(text: '300');

  final List<_ScanResult> _results = <_ScanResult>[];
  final List<String> _logs = <String>[];

  bool _biStrict = true;
  bool _scanning = false;
  bool _analyzing = false;
  int _scanSerial = 0;

  _ScanResult? _selectedResult;
  ChanSnapshot _snapshot = ChanSnapshot.empty();
  String _status = '就绪 - 点击"开始扫描"分析股票';

  bool _showBi = true;
  bool _showSeg = true;
  bool _showZs = true;
  bool _showBsp = true;
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
        ..add('正在启动/连接 Python chan.py 后端...')
        ..add('正在获取股票列表...');
      _selectedResult = null;
      _status = '正在启动/连接 Python chan.py 后端...';
    });

    final client = ScannerBackendClient(
      baseUrl: _backendUrlController.text.trim(),
    );
    try {
      final decoded = await client.scanBsp(
        days: 365,
        recentDays: 3,
        limit: int.tryParse(_limitController.text.trim()) ?? 300,
        biStrict: _biStrict,
        config: _scannerConfig,
      );
      if (serial != _scanSerial) return;

      final rows = decoded['results'];
      final logRows = decoded['logs'];
      setState(() {
        _results
          ..clear()
          ..addAll(rows is List
              ? rows
                  .whereType<Map>()
                  .map((e) => _ScanResult.fromJson(Map<String, dynamic>.from(e)))
              : const <_ScanResult>[]);
        _logs
          ..clear()
          ..addAll(logRows is List ? logRows.map((e) => '$e') : const <String>[]);
        _status = '扫描完成: 成功${decoded['success_count'] ?? 0}只, '
            '跳过${decoded['fail_count'] ?? 0}只, '
            '发现${decoded['found_count'] ?? _results.length}只买点股票';
      });
    } catch (e) {
      if (!mounted || serial != _scanSerial) return;
      setState(() {
        _logs.add('❌ 扫描失败: $e');
        _status = '扫描失败: $e';
      });
    } finally {
      client.close();
      if (mounted && serial == _scanSerial) {
        setState(() => _scanning = false);
      }
    }
  }

  void _stopScan() {
    if (!_scanning) return;
    _scanSerial++;
    setState(() {
      _scanning = false;
      _status = '正在停止扫描...';
      _logs.add('⏹️ 已请求停止扫描');
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
    await _loadChartFor(code: result.code, market: result.market, target: result);
  }

  Future<void> _loadChartFor({
    required String code,
    required String market,
    required _ScanResult? target,
  }) async {
    if (_analyzing) return;
    final source = PythonChanAnalysisSource(
      baseUrl: _backendUrlController.text.trim(),
    );
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
          _viewEndIndex =
              (focus + math.max(20, _windowSize ~/ 2)).clamp(0, maxEnd).toInt();
        } else {
          _crosshairIndex = null;
          _viewEndIndex = null;
        }
        _status = target == null
            ? '分析完成: $code'
            : '显示: ${target.code} ${target.name} ${target.bspType} ${_fmtDate(target.bspTime)}';
      });
    } catch (e) {
      if (mounted) _showMessage('分析失败: $e');
    } finally {
      source.close();
      if (mounted) setState(() => _analyzing = false);
    }
  }

  BspPoint? _matchBsp(ChanSnapshot snapshot, _ScanResult result) {
    for (final bsp in snapshot.bsps) {
      if (bsp.rawIndex == result.rawIndex &&
          (result.bspType.isEmpty ||
              bsp.type == result.bspType ||
              bsp.type.contains(result.bspType))) {
        return bsp;
      }
    }
    for (final bsp in snapshot.bsps) {
      if (bsp.rawIndex == result.rawIndex) return bsp;
    }
    final rawIndex = result.rawIndex;
    if (rawIndex == null || snapshot.rawBars.isEmpty) return null;
    final raw = rawIndex.clamp(0, snapshot.rawBars.length - 1).toInt();
    return BspPoint(
      index: -1,
      rawIndex: raw,
      time: result.bspTime,
      price: result.bspPrice ?? snapshot.rawBars[raw].close,
      type: result.bspType.isEmpty ? 'BSP' : result.bspType,
      level: result.level,
    );
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
        style: const DrawingStyle(
          colorValue: 0xFFFFD54F,
          strokeWidth: 2.4,
          filled: true,
          fillColorValue: 0x22FFD54F,
          fillOpacity: 0.14,
        ),
        locked: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
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
          SizedBox(width: 440, child: _buildLeftPanel()),
          const VerticalDivider(width: 1, color: Colors.white12),
          Expanded(child: _buildChartPanel()),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          _section(
            '扫描设置',
            children: [
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _biStrict,
                onChanged: _scanning
                    ? null
                    : (v) => setState(() => _biStrict = v ?? _biStrict),
                title: const Text('笔严格模式'),
              ),
              TextField(
                controller: _backendUrlController,
                enabled: !_scanning && !_isAndroidApp,
                decoration: const InputDecoration(
                  labelText: 'Windows Python chan.py 服务地址',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _limitController,
                enabled: !_scanning,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '扫描数量上限',
                  helperText: '默认 300；后端过滤 ST / 科创 / 北交 / B股 / 停牌',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _scanning ? null : _startScan,
                      icon: _scanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: const Text('开始扫描'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _scanning ? _stopScan : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('停止'),
                    ),
                  ),
                ],
              ),
              if (_scanning)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _section(
            '单只股票分析',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      enabled: !_analyzing && !_scanning,
                      decoration: const InputDecoration(
                        labelText: '股票代码',
                        hintText: '如: 000001',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _analyzing || _scanning ? null : _analyzeSingle,
                    child: _analyzing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('分析'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildResultSection()),
          const SizedBox(height: 8),
          SizedBox(height: 176, child: _buildLogSection()),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _status,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    return _section(
      '买点股票列表',
      trailing: TextButton.icon(
        onPressed: _results.isEmpty || _scanning
            ? null
            : () => setState(() {
                  _results.clear();
                  _selectedResult = null;
                }),
        icon: const Icon(Icons.clear_all, size: 16),
        label: const Text('清空列表'),
      ),
      children: [
        Expanded(
          child: _results.isEmpty
              ? const Center(
                  child: Text('暂无买点结果', style: TextStyle(color: Colors.white54)),
                )
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
                        columns: const [
                          DataColumn(label: Text('代码')),
                          DataColumn(label: Text('名称')),
                          DataColumn(label: Text('现价')),
                          DataColumn(label: Text('涨跌%')),
                          DataColumn(label: Text('买点')),
                        ],
                        rows: [
                          for (final result in _results)
                            DataRow(
                              selected: identical(result, _selectedResult),
                              onSelectChanged: (_) => _openResult(result),
                              cells: [
                                DataCell(Text(result.code)),
                                DataCell(Text(result.name, overflow: TextOverflow.ellipsis)),
                                DataCell(Text(_fmtNum(result.price))),
                                DataCell(Text(_fmtNum(result.change))),
                                DataCell(Text('${result.bspType} (${_fmtDate(result.bspTime)})')),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLogSection() {
    return _section(
      '扫描日志',
      trailing: TextButton.icon(
        onPressed: _logs.isEmpty ? null : () => setState(() => _logs.clear()),
        icon: const Icon(Icons.delete_outline, size: 16),
        label: const Text('清空日志'),
      ),
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0D10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(
                _logs.join('\n'),
                style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.35),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        children: [
          _buildChartToolbar(),
          const SizedBox(height: 8),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF131722),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _snapshot.rawBars.isEmpty
                    ? const Center(
                        child: Text(
                          '点击扫描结果或单股分析后显示 chan.py 图表',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : OriginKlineChart(
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
                        showMergedBars: true,
                        drawingObjects: _highlightObjects(),
                        drawingStorageKey: _drawingStorageKey,
                        symbolLabel: _chartSymbolLabel,
                        windowSize: _windowSize,
                        priceScale: _priceScale,
                        viewEndIndex: _viewEndIndex,
                        crosshairIndex: _crosshairIndex,
                        onCrosshairChanged: (v) => setState(() => _crosshairIndex = v),
                        onPanBars: _panChartByBars,
                        onWindowSizeChanged: (v) => setState(() => _windowSize = v),
                        onPriceScaleChanged: (v) => setState(() => _priceScale = v),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _disabledCheck('K线', true, 'K线为主图基础层，当前不可关闭'),
          _check('笔', _showBi, (v) => setState(() => _showBi = v)),
          _check('线段', _showSeg, (v) => setState(() => _showSeg = v)),
          _check('中枢', _showZs, (v) => setState(() => _showZs = v)),
          _check('买卖点', _showBsp, (v) => setState(() => _showBsp = v)),
          _disabledCheck('MACD', true, 'MACD 副图当前未接入 OriginKlineChart，保留原扫描器入口占位'),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _snapshot.rawBars.isEmpty || _analyzing
                ? null
                : () {
                    final result = _selectedResult;
                    if (result == null) {
                      _analyzeSingle();
                    } else {
                      _openResult(result);
                    }
                  },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('刷新图表'),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, {required List<Widget> children, Widget? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _check(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? value),
              visualDensity: VisualDensity.compact,
            ),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _disabledCheck(String label, bool value, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(value: value, onChanged: null, visualDensity: VisualDensity.compact),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String get _drawingStorageKey {
    final result = _selectedResult;
    if (result == null) return 'scanner_empty';
    return 'scanner_${result.market}_${result.code}_DAILY_QFQ';
  }

  String get _chartSymbolLabel {
    final result = _selectedResult;
    if (result == null) return '扫描器';
    return '${result.name} ${result.market}${result.code} ${result.bspType} ${_fmtDate(result.bspTime)}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E3A8A),
      ),
    );
  }

  static String? _normalizeCode(String value) {
    final code = value
        .trim()
        .toUpperCase()
        .replaceAll('.SZ', '')
        .replaceAll('.SH', '')
        .replaceAll(RegExp(r'[^0-9]'), '');
    if (code.length < 6) return null;
    return code.substring(code.length - 6);
  }

  static String _inferMarket(String code) =>
      code.startsWith(RegExp(r'[569]')) ? 'SH' : 'SZ';

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

  const _ScanResult({
    required this.code,
    required this.market,
    required this.name,
    required this.price,
    required this.change,
    required this.bspType,
    required this.bspTime,
    required this.rawIndex,
    required this.bspPrice,
    required this.level,
  });

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
    final text = '${value ?? ''}'
        .trim()
        .replaceFirst(' ', 'T')
        .replaceAll('/', '-');
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return DateTime.tryParse(text);
  }

  static String _inferMarket(String code) =>
      code.startsWith(RegExp(r'[569]')) ? 'SH' : 'SZ';
}
