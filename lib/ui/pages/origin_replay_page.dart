import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../../data/python_chan_engine_source.dart';
import '../widgets/kline_chart.dart';
import '../widgets/replay_controller_bar.dart';

class OriginReplayPage extends StatefulWidget {
  const OriginReplayPage({super.key});

  @override
  State<OriginReplayPage> createState() => _OriginReplayPageState();
}

class _OriginReplayPageState extends State<OriginReplayPage> {
  static final DateTime _defaultStartDate = DateTime(2025, 5, 5);
  static final DateTime _defaultEndDate = DateTime(2026, 6, 6);

  final TextEditingController _stockCodeController =
      TextEditingController(text: '000001');
  final TextEditingController _backendUrlController =
      TextEditingController(text: _defaultBackendBaseUrl);

  ChanSnapshot _snapshot = ChanSnapshot.empty();
  ChanSnapshot _fullSnapshot = ChanSnapshot.empty();
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
  Timer? _timer;

  String _mode = 'once';
  String _period = 'DAILY';
  String _adjust = 'QFQ';
  DateTime _startDate = _defaultStartDate;
  DateTime _endDate = _defaultEndDate;
  String _status = 'Python chan.py 引擎未加载';

  static bool get _isAndroidApp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static String get _defaultBackendBaseUrl =>
      _isAndroidApp ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';
  bool get _isStepMode => _mode == 'step';
  bool get _hasBars => _fullSnapshot.rawBars.isNotEmpty;

  @override
  void dispose() {
    _timer?.cancel();
    _stockCodeController.dispose();
    _backendUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    final symbol = _parseSymbol(_stockCodeController.text.trim());
    if (symbol == null) {
      _showMessage('× 代码格式错误：请输入 000001 / 600000 / SZ000001 / 600000.SH');
      return;
    }
    if (_startDate.isAfter(_endDate)) {
      _showMessage('× 开始日期不能晚于结束日期');
      return;
    }
    setState(() => _loading = true);
    final source =
        PythonChanEngineSource(baseUrl: _backendUrlController.text.trim());
    try {
      final snapshot = await source.analyze(
        mode: _mode,
        market: symbol.market,
        code: symbol.code,
        period: _period,
        adjust: _adjust,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      setState(() {
        _stopPlay();
        _fullSnapshot = snapshot;
        _cursor = _isStepMode
            ? math.min(120, snapshot.rawBars.length).toInt()
            : snapshot.rawBars.length;
        _snapshot = _isStepMode ? _sliceSnapshot(snapshot, _cursor) : snapshot;
        _viewEndIndex = null;
        _crosshairIndex = null;
        _priceScale = 1.0;
        _status =
            'chan.py 获取${symbol.market}${symbol.code} ${_periodAdjustLabel} ${snapshot.rawBars.length}根 K线成功';
      });
      _showMessage('√ $_status');
    } catch (e) {
      if (mounted) _showMessage('× Python chan.py 引擎失败：$e');
    } finally {
      source.close();
      if (mounted) setState(() => _loading = false);
    }
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
    );
  }

  void _reset() {
    if (!_isStepMode || !_hasBars) return;
    setState(() {
      _stopPlay();
      _cursor = math.min(30, _fullSnapshot.rawBars.length).toInt();
      _snapshot = _sliceSnapshot(_fullSnapshot, _cursor);
      _viewEndIndex = null;
      _crosshairIndex = null;
    });
  }

  void _stepForward() {
    if (!_isStepMode || !_hasBars) return;
    if (_cursor >= _fullSnapshot.rawBars.length) {
      _stopPlay();
      return;
    }
    setState(() {
      _cursor += 1;
      _snapshot = _sliceSnapshot(_fullSnapshot, _cursor);
    });
  }

  void _stepBack() {
    if (!_isStepMode || !_hasBars || _cursor <= 0) return;
    setState(() {
      _cursor -= 1;
      _snapshot = _sliceSnapshot(_fullSnapshot, _cursor);
    });
  }

  void _jumpTo(int value) {
    if (!_isStepMode || !_hasBars) return;
    setState(() {
      _cursor = value.clamp(0, _fullSnapshot.rawBars.length).toInt();
      _snapshot = _sliceSnapshot(_fullSnapshot, _cursor);
    });
  }

  void _togglePlay() {
    if (!_isStepMode || !_hasBars) return;
    setState(() {
      _playing = !_playing;
      _timer?.cancel();
      _timer = _playing
          ? Timer.periodic(
              const Duration(milliseconds: 450), (_) => _stepForward())
          : null;
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
    if (next == current) return;
    setState(() => _viewEndIndex = next);
  }

  void _changeWindowSize(int next) {
    if (!_hasBars) return;
    setState(() => _windowSize = next.clamp(24, 360).toInt());
  }

  void _changePriceScale(double next) {
    if (!_hasBars) return;
    setState(() => _priceScale = next.clamp(0.35, 5.0).toDouble());
  }

  void _resetChartZoom() {
    if (!_hasBars) return;
    setState(() {
      _windowSize = 90;
      _priceScale = 1.0;
      _viewEndIndex = null;
    });
  }

  Future<void> _openDataPanel() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      builder: (context) {
        var mode = _mode;
        var period = _period;
        var adjust = _adjust;
        var start = _startDate;
        var end = _endDate;
        return StatefulBuilder(builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Python chan.py 数据与计算',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                        'Flutter 只负责显示；FX / BI / SEG / ZS 均来自 Python chan.py JSON。',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _backendUrlController,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                          labelText: 'Python chan.py 本地服务地址',
                          hintText: 'http://127.0.0.1:8000',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _stockCodeController,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                          labelText: '代码（自动识别市场）',
                          hintText: '000001 / 600000 / SZ000001 / 600000.SH',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: mode,
                      decoration: const InputDecoration(
                          labelText: '模式', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'once', child: Text('一次性')),
                        DropdownMenuItem(value: 'step', child: Text('严格逐K')),
                      ],
                      onChanged: _loading
                          ? null
                          : (v) => setSheetState(() => mode = v ?? mode),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: DropdownButtonFormField<String>(
                        initialValue: period,
                        decoration: const InputDecoration(
                            labelText: '周期', border: OutlineInputBorder()),
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
                        onChanged: _loading
                            ? null
                            : (v) => setSheetState(() => period = v ?? period),
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: DropdownButtonFormField<String>(
                        initialValue: adjust,
                        decoration: const InputDecoration(
                            labelText: '复权', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'QFQ', child: Text('前复权')),
                          DropdownMenuItem(value: 'HFQ', child: Text('后复权')),
                          DropdownMenuItem(value: 'NONE', child: Text('不复权')),
                        ],
                        onChanged: _loading
                            ? null
                            : (v) => setSheetState(() => adjust = v ?? adjust),
                      )),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: _dateTile('开始日期', start, !_loading, () async {
                        final picked = await _pickDate(start);
                        if (picked != null) setSheetState(() => start = picked);
                      })),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _dateTile('结束日期', end, !_loading, () async {
                        final picked = await _pickDate(end);
                        if (picked != null) setSheetState(() => end = picked);
                      })),
                    ]),
                    const SizedBox(height: 14),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _mode = mode;
                                    _period = period;
                                    _adjust = adjust;
                                    _startDate = start;
                                    _endDate = end;
                                  });
                                  _load();
                                },
                          icon: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cloud_download),
                          label: const Text('加载 Python chan.py 结果'),
                        )),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _dateTile(
      String title, DateTime value, bool enabled, VoidCallback onTap) {
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: title,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_month)),
          child: Text(_fmtDate(value)),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDate(DateTime initialDate) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      appBar: AppBar(
        toolbarHeight: 40,
        elevation: 0,
        backgroundColor: const Color(0xFF131722),
        title: Text(_status,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white54)),
      ),
      body: SafeArea(
        top: false,
        child: Row(children: [
          _buildLeftToolbar(),
          Expanded(
              child: Column(children: [
            Expanded(child: _buildChartPanel()),
            if (_isStepMode)
              ReplayControllerBar(
                enabled: _hasBars,
                playing: _playing,
                cursor: _cursor,
                total: _fullSnapshot.rawBars.length,
                onReset: _reset,
                onStepBack: _stepBack,
                onStepForward: _stepForward,
                onTogglePlay: _togglePlay,
                onSliderChanged: (v) => _jumpTo(v.round()),
              ),
          ])),
        ]),
      ),
    );
  }

  Widget _buildLeftToolbar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: _toolbarExpanded ? 48 : 28,
      color: const Color(0xFF131722),
      child: SingleChildScrollView(
          child: Column(children: [
        const SizedBox(height: 6),
        InkWell(
          onTap: () => setState(() => _toolbarExpanded = !_toolbarExpanded),
          child: SizedBox(
              width: _toolbarExpanded ? 36 : 24,
              height: 30,
              child: Center(
                  child: Text(_toolbarExpanded ? '<-' : '->',
                      style: const TextStyle(color: Colors.white70)))),
        ),
        if (_toolbarExpanded) ...[
          const Divider(height: 12, color: Colors.white12),
          _toolIcon(
              '数据源/标的/周期/日期', Icons.search, _loading ? null : _openDataPanel),
          _toolIcon(
              '一次性显示',
              Icons.fullscreen,
              _hasBars
                  ? () => setState(() {
                        _mode = 'once';
                        _cursor = _fullSnapshot.rawBars.length;
                        _snapshot = _fullSnapshot;
                      })
                  : null,
              selected: _mode == 'once'),
          _toolIcon(
              '严格逐K',
              Icons.play_circle_outline,
              _hasBars
                  ? () => setState(() {
                        _mode = 'step';
                        _cursor =
                            math.min(120, _fullSnapshot.rawBars.length).toInt();
                        _snapshot = _sliceSnapshot(_fullSnapshot, _cursor);
                      })
                  : null,
              selected: _mode == 'step'),
          const Divider(height: 18, color: Colors.white12),
          _toolIcon('显示分型顶底', Icons.trip_origin,
              _hasBars ? () => setState(() => _showFx = !_showFx) : null,
              selected: _showFx),
          _toolIcon(
              '显示分型顶底文字',
              Icons.title,
              _hasBars && _showFx
                  ? () => setState(() => _showFxText = !_showFxText)
                  : null,
              selected: _showFxText),
          _toolIcon(
              '显示分型顶底连线',
              Icons.timeline,
              _hasBars
                  ? () => setState(() => _showFxLine = !_showFxLine)
                  : null,
              selected: _showFxLine),
          _toolIcon('显示笔', Icons.show_chart,
              _hasBars ? () => setState(() => _showBi = !_showBi) : null,
              selected: _showBi),
          _toolIcon(
              '显示笔端点文字',
              Icons.text_fields,
              _hasBars && _showBi
                  ? () => setState(() => _showBiText = !_showBiText)
                  : null,
              selected: _showBiText),
          _toolIcon('显示线段', Icons.multiline_chart,
              _hasBars ? () => setState(() => _showSeg = !_showSeg) : null,
              selected: _showSeg),
          _toolIcon(
              '显示线段端点文字',
              Icons.font_download_outlined,
              _hasBars && _showSeg
                  ? () => setState(() => _showSegText = !_showSegText)
                  : null,
              selected: _showSegText),
          _toolIcon('显示中枢', Icons.crop_square,
              _hasBars ? () => setState(() => _showZs = !_showZs) : null,
              selected: _showZs),
          const Divider(height: 18, color: Colors.white12),
          _toolIcon('左右放大', Icons.zoom_in,
              _hasBars ? () => _changeWindowSize(_windowSize - 15) : null),
          _toolIcon('左右缩小', Icons.zoom_out,
              _hasBars ? () => _changeWindowSize(_windowSize + 15) : null),
          _toolIcon('上下放大', Icons.keyboard_arrow_up,
              _hasBars ? () => _changePriceScale(_priceScale * 1.18) : null),
          _toolIcon('上下缩小', Icons.keyboard_arrow_down,
              _hasBars ? () => _changePriceScale(_priceScale / 1.18) : null),
          _toolIcon('重置缩放', Icons.center_focus_strong,
              _hasBars ? _resetChartZoom : null),
          _toolIcon(
              '回到最新K线',
              Icons.my_location,
              _hasBars
                  ? () => setState(() {
                        _viewEndIndex = null;
                        _crosshairIndex = null;
                      })
                  : null),
        ],
      ])),
    );
  }

  Widget _toolIcon(String tooltip, IconData icon, VoidCallback? onPressed,
      {bool selected = false}) {
    return Tooltip(
      message: onPressed == null ? '$tooltip（当前不可用）' : tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        color: selected ? Colors.white : Colors.white60,
        disabledColor: Colors.white24,
        style: IconButton.styleFrom(
            backgroundColor:
                selected ? const Color(0xFF2962FF) : Colors.transparent,
            visualDensity: VisualDensity.compact),
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
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

  _Symbol? _parseSymbol(String input) {
    var text = input.trim().toUpperCase();
    if (text.endsWith('.SZ') || text.endsWith('.SH'))
      text = text.substring(0, 6);
    if (text.startsWith('SZ') || text.startsWith('SH'))
      text = text.substring(2);
    if (!RegExp(r'^\d{6}$').hasMatch(text)) return null;
    final market = text.startsWith(RegExp(r'[569]')) ? 'SH' : 'SZ';
    return _Symbol(code: text, market: market);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
  }

  String get _periodAdjustLabel =>
      '${_periodLabel(_period)} ${_adjustLabel(_adjust)}';
  String _periodLabel(String p) =>
      {
        'MIN1': '1分钟',
        'MIN5': '5分钟',
        'MIN15': '15分钟',
        'MIN30': '30分钟',
        'MIN60': '60分钟',
        'DAILY': '日线',
        'WEEKLY': '周线',
        'MONTHLY': '月线'
      }[p] ??
      p;
  String _adjustLabel(String a) =>
      {'QFQ': '前复权', 'HFQ': '后复权', 'NONE': '不复权'}[a] ?? a;
  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _Symbol {
  final String code;
  final String market;
  const _Symbol({required this.code, required this.market});
}
