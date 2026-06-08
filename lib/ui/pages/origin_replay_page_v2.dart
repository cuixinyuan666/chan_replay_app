import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../../core/models/raw_bar.dart';
import '../../data/python_chan_analysis_source.dart';
import '../widgets/origin_kline_chart.dart';
import '../widgets/replay_controller_bar.dart';

class OriginReplayPageV2 extends StatefulWidget {
  const OriginReplayPageV2({super.key});

  @override
  State<OriginReplayPageV2> createState() => _OriginReplayPageV2State();
}

class _OriginReplayPageV2State extends State<OriginReplayPageV2> {
  static final DateTime _defaultStartDate = DateTime(2020, 1, 1);
  static final DateTime _defaultEndDate = DateTime(2026, 6, 6);

  final TextEditingController _stockCodeController = TextEditingController(text: '000001');
  final TextEditingController _backendUrlController = TextEditingController(text: _defaultBackendBaseUrl);

  ChanSnapshot _snapshot = ChanSnapshot.empty();
  ChanSnapshot _fullSnapshot = ChanSnapshot.empty();
  List<ChanSnapshot> _frames = const [];
  List<RawBar>? _localCsvBars;
  String _localCsvName = '';

  int _cursor = 0;
  int _windowSize = 90;
  double _priceScale = 1.0;
  int? _viewEndIndex;
  int? _crosshairIndex;
  bool _loading = false;
  bool _playing = false;
  bool _toolbarExpanded = true;
  bool _showFx = true;
  bool _showFxLine = true;
  bool _showFxText = true;
  bool _showBi = true;
  bool _showBiText = false;
  bool _showSeg = true;
  bool _showSegText = true;
  bool _showZs = true;
  bool _showBsp = true;
  bool _showMergedBars = false;
  Timer? _timer;

  String _mode = 'once';
  String _dataSource = 'easy_tdx';
  String _period = 'DAILY';
  String _adjust = 'QFQ';
  DateTime _startDate = _defaultStartDate;
  DateTime _endDate = _defaultEndDate;
  String _status = 'Python chan.py 引擎未加载';

  String _biAlgo = 'normal';
  bool _biStrict = true;
  String _segAlgo = 'chan';
  String _zsAlgo = 'normal';
  bool _zsCombine = true;
  String _zsCombineMode = 'zs';
  bool _oneBiZs = false;

  String _bsType = '1,1p,2,2s,3a,3b';
  String _divergenceRate = '1e18';
  int _minZsCnt = 1;
  String _maxBs2Rate = '0.9999';
  bool _bs1Peak = true;
  bool _bsp2Follow1 = true;
  bool _bsp3Follow1 = true;
  bool _bsp3Peak = false;
  bool _bsp2sFollow2 = false;
  bool _strictBsp3 = false;
  int _bsp3aMaxZsCnt = 1;
  String _macdAlgo = 'peak';

  static bool get _isAndroidApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static String get _defaultBackendBaseUrl => _isAndroidApp ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';
  bool get _isStepMode => _mode == 'step';
  bool get _hasBars => _fullSnapshot.rawBars.isNotEmpty;
  int get _stepTotal => _frames.isNotEmpty ? _frames.length : _fullSnapshot.rawBars.length;

  Map<String, dynamic> get _chanConfig => {
        'bi_algo': _biAlgo,
        'bi_strict': _biStrict,
        'seg_algo': _segAlgo,
        'zs_algo': _zsAlgo,
        'zs_combine': _zsCombine,
        'zs_combine_mode': _zsCombineMode,
        'one_bi_zs': _oneBiZs,
        'bs_type': _bsType,
        'divergence_rate': _divergenceRate,
        'min_zs_cnt': _minZsCnt,
        'max_bs2_rate': _maxBs2Rate,
        'bs1_peak': _bs1Peak,
        'bsp2_follow_1': _bsp2Follow1,
        'bsp3_follow_1': _bsp3Follow1,
        'bsp3_peak': _bsp3Peak,
        'bsp2s_follow_2': _bsp2sFollow2,
        'strict_bsp3': _strictBsp3,
        'bsp3a_max_zs_cnt': _bsp3aMaxZsCnt,
        'macd_algo': _macdAlgo,
      };

  @override
  void dispose() {
    _timer?.cancel();
    _stockCodeController.dispose();
    _backendUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    if (_startDate.isAfter(_endDate)) {
      _showMessage('× 开始日期不能晚于结束日期');
      return;
    }
    final symbol = _parseSymbol(_stockCodeController.text.trim());
    if (_dataSource != 'csv' && symbol == null) {
      _showMessage('× 代码格式错误：请输入 000001 / 600000 / SZ000001 / 600000.SH');
      return;
    }
    if (_dataSource == 'csv' && (_localCsvBars == null || _localCsvBars!.isEmpty)) {
      _showMessage('× 请先选择本地 CSV');
      return;
    }

    setState(() => _loading = true);
    final source = PythonChanAnalysisSource(baseUrl: _backendUrlController.text.trim());
    try {
      final analysis = _dataSource == 'csv'
          ? await source.analyzeBars(
              mode: _mode,
              symbol: _localCsvName.isEmpty ? 'local_csv' : _localCsvName,
              market: 'LOCAL',
              period: _period,
              adjust: _adjust,
              bars: _localCsvBars!,
              config: _chanConfig,
            )
          : await source.analyze(
              mode: _mode,
              market: symbol!.market,
              code: symbol.code,
              period: _period,
              adjust: _adjust,
              startDate: _startDate,
              endDate: _endDate,
              config: _chanConfig,
            );
      if (!mounted) return;
      setState(() {
        _stopPlay();
        _fullSnapshot = analysis.snapshot;
        _frames = analysis.frames;
        if (_isStepMode && _frames.isNotEmpty) {
          _cursor = 0;
          _snapshot = _frames.first;
        } else {
          _cursor = _isStepMode ? math.min(120, analysis.snapshot.rawBars.length).toInt() : analysis.snapshot.rawBars.length;
          _snapshot = _isStepMode ? _sliceSnapshot(analysis.snapshot, _cursor) : analysis.snapshot;
        }
        _viewEndIndex = null;
        _crosshairIndex = null;
        _priceScale = 1.0;
        final name = _dataSource == 'csv' ? (_localCsvName.isEmpty ? '本地CSV' : _localCsvName) : '${symbol!.market}${symbol.code}';
        _status = 'chan.py 获取$name $_periodAdjustLabel K:${_snapshot.rawBars.length} MB:${_snapshot.mergedBars.length} FX:${_snapshot.fxs.length} BI:${_snapshot.bis.length} SEG:${_snapshot.segs.length} ZS:${_snapshot.zss.length} BSP:${_snapshot.bsps.length}';
      });
      _showMessage('√ $_status');
    } catch (e) {
      if (mounted) _showMessage('× Python chan.py 引擎失败：$e');
    } finally {
      source.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _showMessage('× 读取 CSV 失败：未返回文件内容');
      return;
    }
    try {
      final rows = _parseCsvBars(utf8.decode(bytes, allowMalformed: true));
      if (rows.isEmpty) {
        _showMessage('× CSV 未识别到 K线，请检查列名 time/open/high/low/close');
        return;
      }
      setState(() {
        _dataSource = 'csv';
        _localCsvName = file.name;
        _localCsvBars = rows;
        _status = '已读取本地CSV ${file.name}，${rows.length} 根K线，等待 Python chan.py 分析';
      });
      await _load();
    } catch (e) {
      _showMessage('× CSV 解析失败：$e');
    }
  }

  List<RawBar> _parseCsvBars(String text) {
    final lines = const LineSplitter().convert(text).where((e) => e.trim().isNotEmpty).toList();
    if (lines.length < 2) return [];
    final sep = lines.first.contains('\t') ? '\t' : ',';
    final headers = lines.first.split(sep).map((e) => e.trim().toLowerCase()).toList();
    int col(List<String> names) => headers.indexWhere((h) => names.contains(h));
    final timeCol = col(['time', 'dt', 'date', 'datetime', 'trade_date']);
    final openCol = col(['open', 'o']);
    final highCol = col(['high', 'h']);
    final lowCol = col(['low', 'l']);
    final closeCol = col(['close', 'c']);
    final volCol = col(['vol', 'volume', 'v']);
    if ([timeCol, openCol, highCol, lowCol, closeCol].any((e) => e < 0)) return [];
    final bars = <RawBar>[];
    for (var i = 1; i < lines.length; i++) {
      final cells = lines[i].split(sep).map((e) => e.trim()).toList();
      if (cells.length <= [timeCol, openCol, highCol, lowCol, closeCol].reduce(math.max)) continue;
      final time = DateTime.tryParse(cells[timeCol].replaceAll('/', '-').replaceFirst(' ', 'T'));
      final open = double.tryParse(cells[openCol].replaceAll(',', ''));
      final high = double.tryParse(cells[highCol].replaceAll(',', ''));
      final low = double.tryParse(cells[lowCol].replaceAll(',', ''));
      final close = double.tryParse(cells[closeCol].replaceAll(',', ''));
      final vol = volCol >= 0 && volCol < cells.length ? double.tryParse(cells[volCol].replaceAll(',', '')) ?? 0 : 0.0;
      if (time == null || open == null || high == null || low == null || close == null) continue;
      bars.add(RawBar(index: bars.length, time: time, open: open, high: math.max(math.max(open, high), math.max(low, close)), low: math.min(math.min(open, high), math.min(low, close)), close: close, volume: vol));
    }
    return bars;
  }

  ChanSnapshot _sliceSnapshot(ChanSnapshot source, int cursor) {
    final c = cursor.clamp(0, source.rawBars.length).toInt();
    bool inCursor(int rawIndex) => rawIndex < c;
    return ChanSnapshot(
      rawBars: source.rawBars.take(c).toList(),
      mergedBars: source.mergedBars.where((e) => e.endRawIndex < c).toList(),
      fxs: source.fxs.where((e) => inCursor(e.rawIndex)).toList(),
      bis: source.bis.where((e) => inCursor(e.endRawIndex)).toList(),
      segs: source.segs.where((e) => inCursor(e.endRawIndex)).toList(),
      zss: source.zss.where((e) => inCursor(e.endRawIndex)).toList(),
      bsps: source.bsps.where((e) => inCursor(e.rawIndex)).toList(),
    );
  }

  void _reset() {
    if (!_isStepMode || !_hasBars) return;
    setState(() {
      _stopPlay();
      _cursor = 0;
      _snapshot = _frames.isNotEmpty ? _frames.first : _sliceSnapshot(_fullSnapshot, 0);
      _viewEndIndex = null;
      _crosshairIndex = null;
    });
  }

  void _stepForward() {
    if (!_isStepMode || !_hasBars) return;
    if (_cursor + 1 >= _stepTotal) {
      _stopPlay();
      return;
    }
    setState(() {
      _cursor += 1;
      _snapshot = _frames.isNotEmpty ? _frames[_cursor] : _sliceSnapshot(_fullSnapshot, _cursor);
    });
  }

  void _stepBack() {
    if (!_isStepMode || !_hasBars || _cursor <= 0) return;
    setState(() {
      _cursor -= 1;
      _snapshot = _frames.isNotEmpty ? _frames[_cursor] : _sliceSnapshot(_fullSnapshot, _cursor);
    });
  }

  void _jumpTo(int value) {
    if (!_isStepMode || !_hasBars) return;
    setState(() {
      _cursor = value.clamp(0, math.max(0, _stepTotal - 1)).toInt();
      _snapshot = _frames.isNotEmpty ? _frames[_cursor] : _sliceSnapshot(_fullSnapshot, _cursor);
    });
  }

  void _togglePlay() {
    if (!_isStepMode || !_hasBars) return;
    setState(() {
      _playing = !_playing;
      _timer?.cancel();
      _timer = _playing ? Timer.periodic(const Duration(milliseconds: 450), (_) => _stepForward()) : null;
    });
  }

  void _stopPlay() {
    _playing = false;
    _timer?.cancel();
    _timer = null;
  }

  void _panChartByBars(int bars) {
    if (bars == 0 || _snapshot.rawBars.isEmpty) return;
    final maxEnd = _snapshot.rawBars.length - 1;
    final current = _viewEndIndex ?? maxEnd;
    final next = (current + bars).clamp(0, maxEnd).toInt();
    if (next != current) setState(() => _viewEndIndex = next);
  }

  Future<void> _openDataPanel() => _showSettingsPanel(initialTab: 0);
  Future<void> _openConfigPanel() => _showSettingsPanel(initialTab: 1);

  Future<void> _showSettingsPanel({required int initialTab}) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      builder: (context) {
        var dataSource = _dataSource;
        var mode = _mode;
        var period = _period;
        var adjust = _adjust;
        var start = _startDate;
        var end = _endDate;
        var biAlgo = _biAlgo;
        var biStrict = _biStrict;
        var segAlgo = _segAlgo;
        var zsAlgo = _zsAlgo;
        var zsCombine = _zsCombine;
        var zsCombineMode = _zsCombineMode;
        var oneBiZs = _oneBiZs;
        var bsType = _bsType;
        var divergenceRate = _divergenceRate;
        var minZsCnt = _minZsCnt;
        var maxBs2Rate = _maxBs2Rate;
        var bs1Peak = _bs1Peak;
        var bsp2Follow1 = _bsp2Follow1;
        var bsp3Follow1 = _bsp3Follow1;
        var bsp3Peak = _bsp3Peak;
        var bsp2sFollow2 = _bsp2sFollow2;
        var strictBsp3 = _strictBsp3;
        var bsp3aMaxZsCnt = _bsp3aMaxZsCnt;
        var macdAlgo = _macdAlgo;
        return DefaultTabController(
          initialIndex: initialTab,
          length: 2,
          child: StatefulBuilder(builder: (context, setSheetState) {
            void applyAndReload() {
              Navigator.pop(context);
              setState(() {
                _dataSource = dataSource;
                _mode = mode;
                _period = period;
                _adjust = adjust;
                _startDate = start;
                _endDate = end;
                _biAlgo = biAlgo;
                _biStrict = biStrict;
                _segAlgo = segAlgo;
                _zsAlgo = zsAlgo;
                _zsCombine = zsCombine;
                _zsCombineMode = zsCombineMode;
                _oneBiZs = oneBiZs;
                _bsType = bsType;
                _divergenceRate = divergenceRate;
                _minZsCnt = minZsCnt;
                _maxBs2Rate = maxBs2Rate;
                _bs1Peak = bs1Peak;
                _bsp2Follow1 = bsp2Follow1;
                _bsp3Follow1 = bsp3Follow1;
                _bsp3Peak = bsp3Peak;
                _bsp2sFollow2 = bsp2sFollow2;
                _strictBsp3 = strictBsp3;
                _bsp3aMaxZsCnt = bsp3aMaxZsCnt;
                _macdAlgo = macdAlgo;
              });
              _load();
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.80,
                  child: Column(children: [
                    const TabBar(tabs: [Tab(text: '数据'), Tab(text: 'CChanConfig')]),
                    Expanded(
                      child: TabBarView(children: [
                        SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SizedBox(height: 12),
                          _dropdown('数据源', dataSource, const ['easy_tdx', 'csv'], (v) => setSheetState(() => dataSource = v ?? dataSource), labels: const {'easy_tdx': 'easy-tdx / Python chan.py', 'csv': '本地 CSV / Python chan.py'}),
                          const SizedBox(height: 10),
                          TextField(controller: _backendUrlController, enabled: !_loading && !_isAndroidApp, decoration: const InputDecoration(labelText: 'Windows Python chan.py 服务地址', border: OutlineInputBorder())),
                          const SizedBox(height: 10),
                          TextField(controller: _stockCodeController, enabled: !_loading && dataSource != 'csv', decoration: const InputDecoration(labelText: '代码（自动识别市场）', border: OutlineInputBorder())),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(onPressed: _loading ? null : _pickCsv, icon: const Icon(Icons.upload_file), label: Text(_localCsvName.isEmpty ? '选择本地 CSV' : '已选 $_localCsvName')),
                          const SizedBox(height: 10),
                          _dropdown('模式', mode, const ['once', 'step'], (v) => setSheetState(() => mode = v ?? mode), labels: const {'once': '一次性', 'step': '严格逐K trigger_step / step_load'}),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _dropdown('周期', period, const ['MIN1', 'MIN5', 'MIN15', 'MIN30', 'MIN60', 'DAILY', 'WEEKLY', 'MONTHLY'], (v) => setSheetState(() => period = v ?? period), labels: const {'MIN1': '1分钟', 'MIN5': '5分钟', 'MIN15': '15分钟', 'MIN30': '30分钟', 'MIN60': '60分钟', 'DAILY': '日线', 'WEEKLY': '周线', 'MONTHLY': '月线'})),
                            const SizedBox(width: 10),
                            Expanded(child: _dropdown('复权', adjust, const ['QFQ', 'HFQ', 'NONE'], (v) => setSheetState(() => adjust = v ?? adjust), labels: const {'QFQ': '前复权', 'HFQ': '后复权', 'NONE': '不复权'})),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _dateTile('开始日期', start, !_loading, () async { final picked = await _pickDate(start); if (picked != null) setSheetState(() => start = picked); })),
                            const SizedBox(width: 10),
                            Expanded(child: _dateTile('结束日期', end, !_loading, () async { final picked = await _pickDate(end); if (picked != null) setSheetState(() => end = picked); })),
                          ]),
                        ])),
                        SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SizedBox(height: 12),
                          const Text('这些设置直接传给 Python CChanConfig；加载前或加载后修改都会重新请求 chan.py。', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 12),
                          _sectionTitle('结构识别'),
                          _dropdown('bi_algo', biAlgo, const ['normal', 'fx'], (v) => setSheetState(() => biAlgo = v ?? biAlgo)),
                          SwitchListTile(value: biStrict, onChanged: _loading ? null : (v) => setSheetState(() => biStrict = v), title: const Text('bi_strict')),
                          _dropdown('seg_algo', segAlgo, const ['chan', '1+1', 'break'], (v) => setSheetState(() => segAlgo = v ?? segAlgo)),
                          const SizedBox(height: 10),
                          _sectionTitle('中枢 ZS'),
                          _dropdown('zs_algo', zsAlgo, const ['normal', 'over_seg', 'auto'], (v) => setSheetState(() => zsAlgo = v ?? zsAlgo)),
                          SwitchListTile(value: zsCombine, onChanged: _loading ? null : (v) => setSheetState(() => zsCombine = v), title: const Text('zs_combine')),
                          _dropdown('zs_combine_mode', zsCombineMode, const ['zs', 'peak'], (v) => setSheetState(() => zsCombineMode = v ?? zsCombineMode)),
                          SwitchListTile(value: oneBiZs, onChanged: _loading ? null : (v) => setSheetState(() => oneBiZs = v), title: const Text('one_bi_zs')),
                          const SizedBox(height: 8),
                          _sectionTitle('买卖点 BSP'),
                          TextFormField(initialValue: bsType, enabled: !_loading, decoration: const InputDecoration(labelText: 'bs_type', helperText: '例如 1,1p,2,2s,3a,3b', border: OutlineInputBorder()), onChanged: (v) => bsType = v.trim()),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: TextFormField(initialValue: divergenceRate, enabled: !_loading, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'divergence_rate', border: OutlineInputBorder()), onChanged: (v) => divergenceRate = v.trim())),
                            const SizedBox(width: 10),
                            Expanded(child: TextFormField(initialValue: maxBs2Rate, enabled: !_loading, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'max_bs2_rate', border: OutlineInputBorder()), onChanged: (v) => maxBs2Rate = v.trim())),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: TextFormField(initialValue: '$minZsCnt', enabled: !_loading, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'min_zs_cnt', border: OutlineInputBorder()), onChanged: (v) => minZsCnt = int.tryParse(v.trim()) ?? minZsCnt)),
                            const SizedBox(width: 10),
                            Expanded(child: TextFormField(initialValue: '$bsp3aMaxZsCnt', enabled: !_loading, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'bsp3a_max_zs_cnt', border: OutlineInputBorder()), onChanged: (v) => bsp3aMaxZsCnt = int.tryParse(v.trim()) ?? bsp3aMaxZsCnt)),
                          ]),
                          const SizedBox(height: 10),
                          _dropdown('macd_algo', macdAlgo, const ['peak', 'area', 'full_area', 'slope'], (v) => setSheetState(() => macdAlgo = v ?? macdAlgo)),
                          SwitchListTile(value: bs1Peak, onChanged: _loading ? null : (v) => setSheetState(() => bs1Peak = v), title: const Text('bs1_peak')),
                          SwitchListTile(value: bsp2Follow1, onChanged: _loading ? null : (v) => setSheetState(() => bsp2Follow1 = v), title: const Text('bsp2_follow_1')),
                          SwitchListTile(value: bsp3Follow1, onChanged: _loading ? null : (v) => setSheetState(() => bsp3Follow1 = v), title: const Text('bsp3_follow_1')),
                          SwitchListTile(value: bsp3Peak, onChanged: _loading ? null : (v) => setSheetState(() => bsp3Peak = v), title: const Text('bsp3_peak')),
                          SwitchListTile(value: bsp2sFollow2, onChanged: _loading ? null : (v) => setSheetState(() => bsp2sFollow2 = v), title: const Text('bsp2s_follow_2')),
                          SwitchListTile(value: strictBsp3, onChanged: _loading ? null : (v) => setSheetState(() => strictBsp3 = v), title: const Text('strict_bsp3')),
                        ])),
                      ]),
                    ),
                    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _loading ? null : applyAndReload, icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh), label: const Text('应用并重新计算'))),
                  ]),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _dropdown(String label, String value, List<String> values, ValueChanged<String?>? onChanged, {Map<String, String> labels = const {}}) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: values.map((v) => DropdownMenuItem(value: v, child: Text(labels[v] ?? v))).toList(),
      onChanged: _loading ? null : onChanged,
    );
  }

  Widget _sectionTitle(String text) => Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)));

  Widget _dateTile(String title, DateTime value, bool enabled, VoidCallback onTap) => Opacity(opacity: enabled ? 1 : 0.38, child: InkWell(onTap: enabled ? onTap : null, child: InputDecorator(decoration: InputDecoration(labelText: title, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_month)), child: Text(_fmtDate(value)))));

  Future<DateTime?> _pickDate(DateTime initialDate) => showDatePicker(context: context, initialDate: initialDate, firstDate: DateTime(1990, 1, 1), lastDate: DateTime(2035, 12, 31), initialEntryMode: DatePickerEntryMode.calendarOnly, helpText: '选择日期', cancelText: '取消', confirmText: '确定');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      appBar: AppBar(toolbarHeight: 40, elevation: 0, backgroundColor: const Color(0xFF131722), title: Text(_status, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54))),
      body: SafeArea(top: false, child: Row(children: [
        _buildLeftToolbar(),
        Expanded(child: Column(children: [
          Expanded(child: _buildChartPanel()),
          if (_isStepMode) ReplayControllerBar(enabled: _hasBars, playing: _playing, cursor: _cursor, total: _stepTotal, onReset: _reset, onStepBack: _stepBack, onStepForward: _stepForward, onTogglePlay: _togglePlay, onSliderChanged: (v) => _jumpTo(v.round())),
        ])),
      ])),
    );
  }

  Widget _buildLeftToolbar() {
    return AnimatedContainer(duration: const Duration(milliseconds: 160), width: _toolbarExpanded ? 48 : 28, color: const Color(0xFF131722), child: SingleChildScrollView(child: Column(children: [
      const SizedBox(height: 6),
      InkWell(onTap: () => setState(() => _toolbarExpanded = !_toolbarExpanded), child: SizedBox(width: _toolbarExpanded ? 36 : 24, height: 30, child: Center(child: Text(_toolbarExpanded ? '<-' : '->', style: const TextStyle(color: Colors.white70))))),
      if (_toolbarExpanded) ...[
        const Divider(height: 12, color: Colors.white12),
        _toolIcon('数据/标的/周期/日期', Icons.search, _loading ? null : _openDataPanel),
        _toolIcon('CChanConfig 设置', Icons.tune, _loading ? null : _openConfigPanel),
        _toolIcon('本地CSV上传', Icons.upload_file, _loading ? null : _pickCsv),
        _toolIcon('一次性显示', Icons.fullscreen, _hasBars ? () => setState(() { _mode = 'once'; _cursor = _fullSnapshot.rawBars.length; _snapshot = _fullSnapshot; }) : null, selected: _mode == 'once'),
        _toolIcon('严格逐K', Icons.play_circle_outline, _hasBars ? () => setState(() { _mode = 'step'; _cursor = 0; _snapshot = _frames.isNotEmpty ? _frames.first : _sliceSnapshot(_fullSnapshot, 0); }) : null, selected: _mode == 'step'),
        const Divider(height: 18, color: Colors.white12),
        _toolIcon('显示分型顶底', Icons.trip_origin, _hasBars ? () => setState(() => _showFx = !_showFx) : null, selected: _showFx),
        _toolIcon('显示分型顶底文字', Icons.title, _hasBars && _showFx ? () => setState(() => _showFxText = !_showFxText) : null, selected: _showFxText),
        _toolIcon('显示分型顶底连线', Icons.timeline, _hasBars ? () => setState(() => _showFxLine = !_showFxLine) : null, selected: _showFxLine),
        _toolIcon('显示笔', Icons.show_chart, _hasBars ? () => setState(() => _showBi = !_showBi) : null, selected: _showBi),
        _toolIcon('显示笔端点文字', Icons.text_fields, _hasBars && _showBi ? () => setState(() => _showBiText = !_showBiText) : null, selected: _showBiText),
        _toolIcon('显示线段', Icons.multiline_chart, _hasBars ? () => setState(() => _showSeg = !_showSeg) : null, selected: _showSeg),
        _toolIcon('显示线段端点文字', Icons.font_download_outlined, _hasBars && _showSeg ? () => setState(() => _showSegText = !_showSegText) : null, selected: _showSegText),
        _toolIcon('显示中枢', Icons.crop_square, _hasBars ? () => setState(() => _showZs = !_showZs) : null, selected: _showZs),
        _toolIcon('显示买卖点BSP', Icons.change_circle, _hasBars ? () => setState(() => _showBsp = !_showBsp) : null, selected: _showBsp),
        _toolIcon('显示合并K线', Icons.filter_none, _hasBars && _snapshot.mergedBars.isNotEmpty ? () => setState(() => _showMergedBars = !_showMergedBars) : null, selected: _showMergedBars && _snapshot.mergedBars.isNotEmpty),
        const Divider(height: 18, color: Colors.white12),
        _toolIcon('左右放大', Icons.zoom_in, _hasBars ? () => setState(() => _windowSize = (_windowSize - 15).clamp(24, 360).toInt()) : null),
        _toolIcon('左右缩小', Icons.zoom_out, _hasBars ? () => setState(() => _windowSize = (_windowSize + 15).clamp(24, 360).toInt()) : null),
        _toolIcon('上下放大', Icons.keyboard_arrow_up, _hasBars ? () => setState(() => _priceScale = (_priceScale * 1.18).clamp(0.35, 5.0).toDouble()) : null),
        _toolIcon('上下缩小', Icons.keyboard_arrow_down, _hasBars ? () => setState(() => _priceScale = (_priceScale / 1.18).clamp(0.35, 5.0).toDouble()) : null),
        _toolIcon('重置缩放', Icons.center_focus_strong, _hasBars ? () => setState(() { _windowSize = 90; _priceScale = 1.0; _viewEndIndex = null; }) : null),
      ],
    ])));
  }

  Widget _toolIcon(String tooltip, IconData icon, VoidCallback? onPressed, {bool selected = false}) => Tooltip(message: onPressed == null ? '$tooltip（当前不可用）' : tooltip, child: IconButton(onPressed: onPressed, icon: Icon(icon, size: 19), color: selected ? Colors.white : Colors.white60, disabledColor: Colors.white24, style: IconButton.styleFrom(backgroundColor: selected ? const Color(0xFF2962FF) : Colors.transparent, visualDensity: VisualDensity.compact)));

  Widget _buildChartPanel() => Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 2), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: DecoratedBox(decoration: BoxDecoration(color: const Color(0xFF0B0D10), border: Border.all(color: Colors.white.withValues(alpha: 0.08))), child: OriginKlineChart(snapshot: _snapshot, showFx: _showFx, showFxLine: _showFxLine, showFxText: _showFxText, showBi: _showBi, showBiText: _showBiText, showSeg: _showSeg, showSegText: _showSegText, showZs: _showZs, showBsp: _showBsp, showMergedBars: _showMergedBars, windowSize: _windowSize, priceScale: _priceScale, viewEndIndex: _viewEndIndex, crosshairIndex: _crosshairIndex, onCrosshairChanged: (i) => setState(() => _crosshairIndex = i), onPanBars: _panChartByBars, onWindowSizeChanged: (v) => setState(() => _windowSize = v), onPriceScaleChanged: (v) => setState(() => _priceScale = v)))));

  _Symbol? _parseSymbol(String input) {
    var text = input.trim().toUpperCase();
    if (text.endsWith('.SZ') || text.endsWith('.SH')) text = text.substring(0, 6);
    if (text.startsWith('SZ') || text.startsWith('SH')) text = text.substring(2);
    if (!RegExp(r'^\d{6}$').hasMatch(text)) return null;
    return _Symbol(code: text, market: text.startsWith(RegExp(r'[569]')) ? 'SH' : 'SZ');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
  }

  String get _periodAdjustLabel => '${_periodLabel(_period)} ${_adjustLabel(_adjust)}';
  String _periodLabel(String p) => {'MIN1': '1分钟', 'MIN5': '5分钟', 'MIN15': '15分钟', 'MIN30': '30分钟', 'MIN60': '60分钟', 'DAILY': '日线', 'WEEKLY': '周线', 'MONTHLY': '月线'}[p] ?? p;
  String _adjustLabel(String a) => {'QFQ': '前复权', 'HFQ': '后复权', 'NONE': '不复权'}[a] ?? a;
  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _Symbol {
  final String code;
  final String market;
  const _Symbol({required this.code, required this.market});
}
