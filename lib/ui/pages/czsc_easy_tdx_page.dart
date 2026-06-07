import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../../data/czsc_easy_tdx_source.dart';
import '../widgets/kline_chart.dart';

class CzscEasyTdxPage extends StatefulWidget {
  const CzscEasyTdxPage({super.key});

  @override
  State<CzscEasyTdxPage> createState() => _CzscEasyTdxPageState();
}

class _CzscEasyTdxPageState extends State<CzscEasyTdxPage> {
  final TextEditingController _baseUrlController =
      TextEditingController(text: 'http://10.0.2.2:8000');
  final TextEditingController _symbolController = TextEditingController(text: '000001');
  final TextEditingController _startDateController =
      TextEditingController(text: '2020-01-01');
  final TextEditingController _endDateController = TextEditingController();

  ChanSnapshot _snapshot = ChanSnapshot.empty();
  Map<String, String> _signals = const {};
  String _market = 'SZ';
  String _freq = 'DAILY';
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

  @override
  void dispose() {
    _baseUrlController.dispose();
    _symbolController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _loadFromBackend() async {
    final symbol = _symbolController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    if (symbol.isEmpty || baseUrl.isEmpty) {
      _showSnack('请填写后端地址和股票代码');
      return;
    }
    final startDate = _parseDateInput(_startDateController.text);
    final endDate = _parseDateInput(_endDateController.text);
    if (_startDateController.text.trim().isNotEmpty && startDate == null) {
      _showSnack('开始日期格式应为 yyyy-MM-dd');
      return;
    }
    if (_endDateController.text.trim().isNotEmpty && endDate == null) {
      _showSnack('结束日期格式应为 yyyy-MM-dd');
      return;
    }
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      _showSnack('开始日期不能晚于结束日期');
      return;
    }

    setState(() => _loading = true);
    final source = CzscEasyTdxSource(baseUrl: baseUrl);
    try {
      final result = await source.analyze(
        symbol: symbol,
        market: _market,
        freq: _freq,
        adjust: _adjust,
        count: _count,
        startDate: startDate,
        endDate: endDate,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = result.snapshot;
        _signals = result.signals;
        _label = result.sourceLabel;
        _warning = result.engineWarning;
        _viewEndIndex = null;
        _crosshairIndex = null;
      });
      if (result.snapshot.rawBars.isEmpty) {
        _showSnack('后端没有返回K线数据');
      } else if (result.engineWarning != null && result.engineWarning!.isNotEmpty) {
        _showSnack(result.engineWarning!);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('CZSC/easy-tdx 加载失败：$e');
    } finally {
      source.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      appBar: AppBar(
        titleSpacing: 12,
        title: const Text('CZSC / easy-tdx'),
        actions: [
          IconButton(
            tooltip: '加载后端 CZSC 元素',
            onPressed: _loading ? null : _loadFromBackend,
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
          _buildStatusBar(),
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
                    snapshot: _snapshot,
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
              _box(width: 126, child: _drop('周期', _freq, const ['MIN1', 'MIN5', 'MIN15', 'MIN30', 'MIN60', 'DAILY', 'WEEKLY', 'MONTHLY'], (v) => setState(() => _freq = v))),
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
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _loadFromBackend,
                icon: const Icon(Icons.cloud_download),
                label: const Text('加载'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFF0F131A),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$_label  K:${_snapshot.rawBars.length} FX:${_snapshot.fxs.length} BI:${_snapshot.bis.length} SEG:${_snapshot.segs.length} ZS:${_snapshot.zss.length} SIG:${_signals.length}',
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
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              const SizedBox(width: 8),
              _toggle('FX', _showFx, () => setState(() => _showFx = !_showFx)),
              _toggle('FX线', _showFxLine, () => setState(() => _showFxLine = !_showFxLine)),
              _toggle('BI', _showBi, () => setState(() => _showBi = !_showBi)),
              _toggle('SEG', _showSeg, () => setState(() => _showSeg = !_showSeg)),
              _toggle('ZS', _showZs, () => setState(() => _showZs = !_showZs)),
              const Spacer(),
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
        for (final item in values) DropdownMenuItem(value: item, child: Text(item)),
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
}
