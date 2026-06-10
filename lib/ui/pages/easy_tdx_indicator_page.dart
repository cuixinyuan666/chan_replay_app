import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EasyTdxIndicatorPage extends StatefulWidget {
  const EasyTdxIndicatorPage({super.key});

  @override
  State<EasyTdxIndicatorPage> createState() => _EasyTdxIndicatorPageState();
}

class _EasyTdxIndicatorPageState extends State<EasyTdxIndicatorPage> {
  final TextEditingController _backendController = TextEditingController(text: _defaultBackendBaseUrl);
  final TextEditingController _symbolController = TextEditingController(text: '600340');
  final TextEditingController _countController = TextEditingController(text: '320');

  String _market = 'SH';
  String _freq = 'DAILY';
  String _adjust = 'QFQ';
  bool _loading = false;
  String _status = '等待加载 easy-tdx 指标';
  List<_IndicatorBar> _bars = const [];
  int? _crossIndex;

  bool _showMa = true;
  bool _showBoll = true;
  bool _showVol = true;
  bool _showMacd = true;
  bool _showAmount = false;
  bool _showTurnover = false;

  static bool get _isAndroidApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static String get _defaultBackendBaseUrl => _isAndroidApp ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _backendController.dispose();
    _symbolController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    final symbol = _symbolController.text.trim();
    if (symbol.isEmpty) {
      _showMessage('请输入股票代码');
      return;
    }
    final count = int.tryParse(_countController.text.trim())?.clamp(30, 5000).toInt() ?? 320;
    setState(() {
      _loading = true;
      _status = '正在请求 easy-tdx 指标 $symbol $_freq ...';
    });
    try {
      final base = _backendController.text.trim().replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/api/tdx/kline').replace(queryParameters: {
        'symbol': symbol,
        'market': _market,
        'freq': _freq,
        'adjust': _adjust,
        'count': '$count',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 45));
      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: $body');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) throw const FormatException('后端返回不是 JSON 对象');
      if (decoded['ok'] == false) throw Exception(decoded['error'] ?? 'easy-tdx 请求失败');
      final bars = _parseBars(decoded);
      if (bars.isEmpty) throw const FormatException('后端没有返回有效 K线');
      setState(() {
        _bars = bars;
        _crossIndex = bars.length - 1;
        _status = '已加载 $symbol.$_market $_freq $_adjust K:${bars.length} '
            'MA:${_hasAnyMa(bars) ? "有" : "无"} BOLL:${_hasAnyBoll(bars) ? "有" : "无"} '
            'VOL:${_hasAnyVol(bars) ? "有" : "无"} MACD:${_hasAnyMacd(bars) ? "有" : "无"}';
      });
    } catch (e) {
      setState(() => _status = '加载失败：$e');
      _showMessage('加载 easy-tdx 指标失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_IndicatorBar> _parseBars(Map<String, dynamic> root) {
    final rawBars = root['bars'];
    if (rawBars is! List) return const [];
    final indicators = root['indicators'] is Map ? root['indicators'] as Map : const {};
    final vol = _pointSeries(indicators['vol']);
    final amount = _pointSeries(indicators['amount']);
    final turnover = _pointSeries(indicators['turnover']);
    final ma = _maSeries(indicators['ma']);
    final boll = _bollSeries(indicators['boll']);
    final macd = _macdSeries(indicators['macd']);

    final bars = <_IndicatorBar>[];
    for (var i = 0; i < rawBars.length; i++) {
      final row = rawBars[i];
      if (row is! Map) continue;
      final open = _num(row['open'] ?? row['o']);
      final high = _num(row['high'] ?? row['h']);
      final low = _num(row['low'] ?? row['l']);
      final close = _num(row['close'] ?? row['c']);
      final time = _timeText(row['time'] ?? row['dt'] ?? row['date'] ?? row['datetime']);
      if (open == null || high == null || low == null || close == null || time.isEmpty) continue;
      final rawIndex = _int(row['raw_index'] ?? row['rawIndex'] ?? row['id']) ?? bars.length;
      bars.add(_IndicatorBar(
        rawIndex: rawIndex,
        time: time,
        open: open,
        high: math.max(high, math.max(open, close)),
        low: math.min(low, math.min(open, close)),
        close: close,
        volume: vol[rawIndex] ?? _num(row['volume'] ?? row['vol'] ?? row['v']),
        amount: amount[rawIndex] ?? _num(row['amount'] ?? row['money']),
        turnover: turnover[rawIndex] ?? _num(row['turnover'] ?? row['turnover_rate']),
        ma: {for (final entry in ma.entries) entry.key: entry.value[rawIndex]},
        boll: boll[rawIndex],
        macd: macd[rawIndex],
      ));
    }
    return _withLocalIndicatorFallback(bars);
  }

  List<_IndicatorBar> _withLocalIndicatorFallback(List<_IndicatorBar> source) {
    if (source.isEmpty) return source;
    final closes = [for (final bar in source) bar.close];
    final ma = {5: _ma(closes, 5), 10: _ma(closes, 10), 20: _ma(closes, 20), 60: _ma(closes, 60)};
    final boll = _boll(closes, 20);
    final macd = _macd(closes, 12, 26, 9);
    return [
      for (var i = 0; i < source.length; i++)
        source[i].copyWith(
          ma: {
            for (final period in const [5, 10, 20, 60])
              period: source[i].ma[period] ?? ma[period]?[i],
          },
          boll: source[i].boll ?? boll[i],
          macd: source[i].macd ?? macd[i],
        ),
    ];
  }

  Map<int, double?> _pointSeries(Object? value) {
    if (value is! List) return const {};
    final result = <int, double?>{};
    for (var i = 0; i < value.length; i++) {
      final row = value[i];
      if (row is! Map) continue;
      result[_int(row['raw_index'] ?? row['rawIndex']) ?? i] = _num(row['value']);
    }
    return result;
  }

  Map<int, Map<int, double?>> _maSeries(Object? value) {
    if (value is! Map) return const {};
    final result = <int, Map<int, double?>>{};
    for (final entry in value.entries) {
      final period = _int(entry.key);
      if (period == null) continue;
      result[period] = _pointSeries(entry.value);
    }
    return result;
  }

  Map<int, _BollValue> _bollSeries(Object? value) {
    if (value is! List) return const {};
    final result = <int, _BollValue>{};
    for (var i = 0; i < value.length; i++) {
      final row = value[i];
      if (row is! Map) continue;
      final rawIndex = _int(row['raw_index'] ?? row['rawIndex']) ?? i;
      result[rawIndex] = _BollValue(
        upper: _num(row['upper']),
        mid: _num(row['mid'] ?? row['middle']),
        lower: _num(row['lower']),
      );
    }
    return result;
  }

  Map<int, _MacdValue> _macdSeries(Object? value) {
    if (value is! List) return const {};
    final result = <int, _MacdValue>{};
    for (var i = 0; i < value.length; i++) {
      final row = value[i];
      if (row is! Map) continue;
      final rawIndex = _int(row['raw_index'] ?? row['rawIndex']) ?? i;
      result[rawIndex] = _MacdValue(
        dif: _num(row['dif'] ?? row['diff']),
        dea: _num(row['dea'] ?? row['signal']),
        hist: _num(row['hist'] ?? row['macd']),
      );
    }
    return result;
  }

  List<double?> _ma(List<double> values, int window) {
    final result = <double?>[];
    final queue = <double>[];
    for (final value in values) {
      queue.add(value);
      if (queue.length > window) queue.removeAt(0);
      result.add(queue.length < window ? null : queue.reduce((a, b) => a + b) / window);
    }
    return result;
  }

  List<_BollValue> _boll(List<double> values, int window) {
    final result = <_BollValue>[];
    final queue = <double>[];
    for (final value in values) {
      queue.add(value);
      if (queue.length > window) queue.removeAt(0);
      if (queue.length < window) {
        result.add(const _BollValue());
        continue;
      }
      final mid = queue.reduce((a, b) => a + b) / queue.length;
      final std = math.sqrt(queue.map((e) => math.pow(e - mid, 2)).reduce((a, b) => a + b) / queue.length);
      result.add(_BollValue(upper: mid + 2 * std, mid: mid, lower: mid - 2 * std));
    }
    return result;
  }

  List<_MacdValue> _macd(List<double> values, int fast, int slow, int signal) {
    final result = <_MacdValue>[];
    double? emaFast;
    double? emaSlow;
    double? dea;
    double ema(double? prev, double value, int n) {
      final alpha = 2.0 / (n + 1.0);
      return prev == null ? value : alpha * value + (1 - alpha) * prev;
    }

    for (final close in values) {
      emaFast = ema(emaFast, close, fast);
      emaSlow = ema(emaSlow, close, slow);
      final dif = emaFast - emaSlow;
      dea = ema(dea, dif, signal);
      result.add(_MacdValue(dif: dif, dea: dea, hist: dif - dea));
    }
    return result;
  }

  bool _hasAnyMa(List<_IndicatorBar> bars) => bars.any((bar) => bar.ma.values.any((v) => v != null));
  bool _hasAnyBoll(List<_IndicatorBar> bars) => bars.any((bar) => bar.boll?.mid != null);
  bool _hasAnyVol(List<_IndicatorBar> bars) => bars.any((bar) => bar.volume != null);
  bool _hasAnyMacd(List<_IndicatorBar> bars) => bars.any((bar) => bar.macd?.dif != null || bar.macd?.hist != null);

  double? _num(Object? value) {
    if (value is num) return value.toDouble();
    final text = '${value ?? ''}'.trim().replaceAll(',', '');
    if (text.isEmpty || text == '-' || text == '--' || text.toLowerCase() == 'nan' || text == 'null') return null;
    return double.tryParse(text);
  }

  int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim());
  }

  String _timeText(Object? value) {
    final text = '${value ?? ''}'.trim();
    if (text.length >= 10) return text.substring(0, math.min(19, text.length));
    return text;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0F16),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              _buildControls(),
              const SizedBox(height: 10),
              _buildSwitches(),
              const SizedBox(height: 8),
              Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101722),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _bars.isEmpty
                        ? const Center(child: Text('暂无指标数据', style: TextStyle(color: Colors.white54)))
                        : _IndicatorChart(
                            bars: _bars.length > 260 ? _bars.sublist(_bars.length - 260) : _bars,
                            showMa: _showMa,
                            showBoll: _showBoll,
                            showVol: _showVol,
                            showMacd: _showMacd,
                            showAmount: _showAmount,
                            showTurnover: _showTurnover,
                            crossIndex: _crossIndex,
                            onCrossIndexChanged: (index) => setState(() => _crossIndex = index),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.insights, color: Color(0xFF8AB4FF), size: 26),
        const SizedBox(width: 8),
        const Text('easy-tdx 指标', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFF2962FF).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
          child: const Text('展示指标，不参与 chan.py 缠论计算', style: TextStyle(color: Color(0xFF8AB4FF), fontSize: 11)),
        ),
        const Spacer(),
        if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ],
    );
  }

  Widget _buildControls() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _input(_backendController, '后端', width: 220),
        _input(_symbolController, '代码', width: 110),
        _dropdown('市场', _market, const ['SH', 'SZ'], (v) => setState(() => _market = v)),
        _dropdown('周期', _freq, const ['MIN1', 'MIN5', 'MIN15', 'MIN30', 'MIN60', 'DAILY', 'WEEKLY', 'MONTHLY'], (v) => setState(() => _freq = v)),
        _dropdown('复权', _adjust, const ['QFQ', 'HFQ', 'NONE'], (v) => setState(() => _adjust = v)),
        _input(_countController, '数量', width: 82),
        FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('加载指标')),
      ],
    );
  }

  Widget _buildSwitches() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('MA', _showMa, (v) => setState(() => _showMa = v)),
        _chip('BOLL', _showBoll, (v) => setState(() => _showBoll = v)),
        _chip('VOL', _showVol, (v) => setState(() => _showVol = v)),
        _chip('MACD', _showMacd, (v) => setState(() => _showMacd = v)),
        _chip('amount', _showAmount, (v) => setState(() => _showAmount = v)),
        _chip('turnover', _showTurnover, (v) => setState(() => _showTurnover = v)),
      ],
    );
  }

  Widget _input(TextEditingController controller, String label, {required double width}) {
    return SizedBox(
      width: width,
      height: 42,
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: const Color(0xFF151B26),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String> onChanged) {
    return SizedBox(
      width: label == '周期' ? 116 : 86,
      height: 42,
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: const Color(0xFF151B26),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: const Color(0xFF151B26),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        ),
        items: [for (final item in items) DropdownMenuItem(value: item, child: Text(item))],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, ValueChanged<bool> onSelected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w700),
      backgroundColor: const Color(0xFF151B26),
      selectedColor: const Color(0xFF2962FF),
      side: BorderSide(color: selected ? const Color(0xFF8AB4FF) : Colors.white.withValues(alpha: 0.12)),
      checkmarkColor: Colors.white,
    );
  }
}

class _IndicatorChart extends StatelessWidget {
  final List<_IndicatorBar> bars;
  final bool showMa;
  final bool showBoll;
  final bool showVol;
  final bool showMacd;
  final bool showAmount;
  final bool showTurnover;
  final int? crossIndex;
  final ValueChanged<int> onCrossIndexChanged;

  const _IndicatorChart({
    required this.bars,
    required this.showMa,
    required this.showBoll,
    required this.showVol,
    required this.showMacd,
    required this.showAmount,
    required this.showTurnover,
    required this.crossIndex,
    required this.onCrossIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _updateCross(details.localPosition, size),
          onPanUpdate: (details) => _updateCross(details.localPosition, size),
          child: CustomPaint(
            size: Size.infinite,
            painter: _IndicatorPainter(
              bars: bars,
              showMa: showMa,
              showBoll: showBoll,
              showVol: showVol,
              showMacd: showMacd,
              showAmount: showAmount,
              showTurnover: showTurnover,
              crossIndex: crossIndex,
            ),
          ),
        );
      },
    );
  }

  void _updateCross(Offset point, Size size) {
    const leftPad = 48.0;
    const rightPad = 68.0;
    final width = math.max(1.0, size.width - leftPad - rightPad);
    final step = width / math.max(1, bars.length);
    final idx = ((point.dx - leftPad) / step).floor().clamp(0, bars.length - 1).toInt();
    onCrossIndexChanged(idx);
  }
}

class _IndicatorPainter extends CustomPainter {
  final List<_IndicatorBar> bars;
  final bool showMa;
  final bool showBoll;
  final bool showVol;
  final bool showMacd;
  final bool showAmount;
  final bool showTurnover;
  final int? crossIndex;

  const _IndicatorPainter({
    required this.bars,
    required this.showMa,
    required this.showBoll,
    required this.showVol,
    required this.showMacd,
    required this.showAmount,
    required this.showTurnover,
    required this.crossIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const leftPad = 48.0;
    const rightPad = 68.0;
    const topPad = 24.0;
    const bottomPad = 22.0;
    final subCount = [showVol, showMacd, showAmount, showTurnover].where((e) => e).length;
    final subHeight = subCount == 0 ? 0.0 : math.min(86.0, math.max(54.0, size.height * 0.16));
    final subGap = subCount == 0 ? 0.0 : 8.0;
    final mainHeight = math.max(80.0, size.height - topPad - bottomPad - subHeight * subCount - subGap * subCount);
    final mainRect = Rect.fromLTWH(leftPad, topPad, math.max(1, size.width - leftPad - rightPad), mainHeight);
    final step = mainRect.width / math.max(1, bars.length);
    double xOf(int i) => mainRect.left + (i + 0.5) * step;

    final priceMin = bars.map((e) => e.low).reduce(math.min);
    final priceMax = bars.map((e) => e.high).reduce(math.max);
    final extraValues = <double>[];
    if (showMa) {
      for (final bar in bars) {
        for (final value in bar.ma.values) {
          if (value != null) extraValues.add(value);
        }
      }
    }
    if (showBoll) {
      for (final bar in bars) {
        final boll = bar.boll;
        if (boll != null) {
          if (boll.upper != null) extraValues.add(boll.upper!);
          if (boll.lower != null) extraValues.add(boll.lower!);
        }
      }
    }
    final minPrice = [priceMin, ...extraValues].reduce(math.min);
    final maxPrice = [priceMax, ...extraValues].reduce(math.max);
    final range = math.max(maxPrice - minPrice, maxPrice.abs() * 0.01);
    final yMin = minPrice - range * 0.06;
    final yMax = maxPrice + range * 0.06;
    double priceToY(double price) => mainRect.bottom - (price - yMin) / math.max(0.0000001, yMax - yMin) * mainRect.height;

    _drawPanel(canvas, mainRect, 'PRICE');
    _drawPriceAxis(canvas, mainRect, yMin, yMax);
    _drawCandles(canvas, mainRect, step, xOf, priceToY);
    if (showBoll) _drawBoll(canvas, mainRect, xOf, priceToY);
    if (showMa) _drawMa(canvas, mainRect, xOf, priceToY);

    var top = mainRect.bottom + subGap;
    if (showVol) {
      final rect = Rect.fromLTWH(leftPad, top, mainRect.width, subHeight);
      _drawVol(canvas, rect, step, xOf);
      top += subHeight + subGap;
    }
    if (showMacd) {
      final rect = Rect.fromLTWH(leftPad, top, mainRect.width, subHeight);
      _drawMacd(canvas, rect, step, xOf);
      top += subHeight + subGap;
    }
    if (showAmount) {
      final rect = Rect.fromLTWH(leftPad, top, mainRect.width, subHeight);
      _drawSingleLinePanel(canvas, rect, xOf, 'AMOUNT', (bar) => bar.amount);
      top += subHeight + subGap;
    }
    if (showTurnover) {
      final rect = Rect.fromLTWH(leftPad, top, mainRect.width, subHeight);
      _drawSingleLinePanel(canvas, rect, xOf, 'TURNOVER', (bar) => bar.turnover);
    }

    _drawDates(canvas, mainRect);
    _drawLegend(canvas, mainRect);
    _drawCrosshair(canvas, size, mainRect, xOf, priceToY);
  }

  void _drawPanel(Canvas canvas, Rect rect, String title) {
    final grid = Paint()..color = Colors.white.withValues(alpha: 0.08)..strokeWidth = 0.7;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0D1320));
    canvas.drawRect(rect, Paint()..color = Colors.white.withValues(alpha: 0.08)..style = PaintingStyle.stroke);
    for (var i = 1; i < 4; i++) {
      final y = rect.top + rect.height * i / 4;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }
    _text(canvas, title, Offset(rect.left + 6, rect.top + 4), 10, Colors.white54);
  }

  void _drawPriceAxis(Canvas canvas, Rect rect, double minPrice, double maxPrice) {
    for (var i = 0; i <= 4; i++) {
      final y = rect.top + rect.height * i / 4;
      final price = maxPrice - (maxPrice - minPrice) * i / 4;
      _text(canvas, price.toStringAsFixed(2), Offset(rect.right + 5, y - 6), 10, Colors.white54);
    }
  }

  void _drawCandles(Canvas canvas, Rect rect, double step, double Function(int) xOf, double Function(double) priceToY) {
    final up = Paint()..color = const Color(0xFF26A69A);
    final down = Paint()..color = const Color(0xFFEF5350);
    final wick = Paint()..strokeWidth = math.max(0.8, step * 0.08);
    final bodyWidth = math.max(1.0, math.min(step * 0.66, step - 1));
    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final x = xOf(i);
      final paint = bar.close >= bar.open ? up : down;
      wick.color = paint.color;
      canvas.drawLine(Offset(x, priceToY(bar.high)), Offset(x, priceToY(bar.low)), wick);
      final openY = priceToY(bar.open);
      final closeY = priceToY(bar.close);
      canvas.drawRect(Rect.fromLTRB(x - bodyWidth / 2, math.min(openY, closeY), x + bodyWidth / 2, math.max(math.min(openY, closeY) + 1, math.max(openY, closeY))), paint);
    }
  }

  void _drawMa(Canvas canvas, Rect rect, double Function(int) xOf, double Function(double) priceToY) {
    final colors = {5: const Color(0xFFFFD54F), 10: const Color(0xFF64B5F6), 20: const Color(0xFFBA68C8), 60: const Color(0xFFFF8A65)};
    for (final period in const [5, 10, 20, 60]) {
      _drawLine(canvas, xOf, priceToY, (bar) => bar.ma[period], Paint()..color = colors[period]!..strokeWidth = 1.1..style = PaintingStyle.stroke);
    }
  }

  void _drawBoll(Canvas canvas, Rect rect, double Function(int) xOf, double Function(double) priceToY) {
    final upperPaint = Paint()..color = const Color(0xFF90CAF9).withValues(alpha: 0.85)..strokeWidth = 0.9..style = PaintingStyle.stroke;
    final midPaint = Paint()..color = Colors.white.withValues(alpha: 0.45)..strokeWidth = 0.8..style = PaintingStyle.stroke;
    final lowerPaint = Paint()..color = const Color(0xFF90CAF9).withValues(alpha: 0.85)..strokeWidth = 0.9..style = PaintingStyle.stroke;
    _drawLine(canvas, xOf, priceToY, (bar) => bar.boll?.upper, upperPaint);
    _drawLine(canvas, xOf, priceToY, (bar) => bar.boll?.mid, midPaint);
    _drawLine(canvas, xOf, priceToY, (bar) => bar.boll?.lower, lowerPaint);
  }

  void _drawLine(Canvas canvas, double Function(int) xOf, double Function(double) yOf, double? Function(_IndicatorBar) valueOf, Paint paint) {
    final path = Path();
    var started = false;
    for (var i = 0; i < bars.length; i++) {
      final value = valueOf(bars[i]);
      if (value == null) {
        started = false;
        continue;
      }
      final p = Offset(xOf(i), yOf(value));
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawVol(Canvas canvas, Rect rect, double step, double Function(int) xOf) {
    _drawPanel(canvas, rect, 'VOL');
    final maxVol = bars.map((e) => e.volume ?? 0).fold<double>(0, math.max);
    if (maxVol <= 0) return;
    final width = math.max(1.0, math.min(step * 0.62, step - 1));
    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final value = bar.volume ?? 0;
      final x = xOf(i);
      final h = value / maxVol * (rect.height - 18);
      final paint = Paint()..color = (bar.close >= bar.open ? const Color(0xFF26A69A) : const Color(0xFFEF5350)).withValues(alpha: 0.72);
      canvas.drawRect(Rect.fromLTRB(x - width / 2, rect.bottom - h, x + width / 2, rect.bottom), paint);
    }
    _text(canvas, _compact(maxVol), Offset(rect.right + 5, rect.top + 2), 10, Colors.white38);
  }

  void _drawMacd(Canvas canvas, Rect rect, double step, double Function(int) xOf) {
    _drawPanel(canvas, rect, 'MACD');
    final values = <double>[];
    for (final bar in bars) {
      final macd = bar.macd;
      if (macd == null) continue;
      if (macd.dif != null) values.add(macd.dif!);
      if (macd.dea != null) values.add(macd.dea!);
      if (macd.hist != null) values.add(macd.hist!);
    }
    if (values.isEmpty) return;
    final maxAbs = math.max(0.0000001, values.map((e) => e.abs()).reduce(math.max));
    final zeroY = rect.top + rect.height / 2;
    double yOf(double v) => zeroY - v / maxAbs * (rect.height * 0.42);
    canvas.drawLine(Offset(rect.left, zeroY), Offset(rect.right, zeroY), Paint()..color = Colors.white.withValues(alpha: 0.16)..strokeWidth = 0.8);
    final histWidth = math.max(1.0, math.min(step * 0.58, step - 1));
    for (var i = 0; i < bars.length; i++) {
      final hist = bars[i].macd?.hist;
      if (hist == null) continue;
      final x = xOf(i);
      final y = yOf(hist);
      final paint = Paint()..color = (hist >= 0 ? const Color(0xFF26A69A) : const Color(0xFFEF5350)).withValues(alpha: 0.78);
      canvas.drawRect(Rect.fromLTRB(x - histWidth / 2, math.min(zeroY, y), x + histWidth / 2, math.max(zeroY, y)), paint);
    }
    _drawLine(canvas, xOf, yOf, (bar) => bar.macd?.dif, Paint()..color = const Color(0xFFFFD54F)..strokeWidth = 1.0..style = PaintingStyle.stroke);
    _drawLine(canvas, xOf, yOf, (bar) => bar.macd?.dea, Paint()..color = const Color(0xFF64B5F6)..strokeWidth = 1.0..style = PaintingStyle.stroke);
  }

  void _drawSingleLinePanel(Canvas canvas, Rect rect, double Function(int) xOf, String title, double? Function(_IndicatorBar) valueOf) {
    _drawPanel(canvas, rect, title);
    final values = bars.map(valueOf).whereType<double>().toList();
    if (values.isEmpty) {
      _text(canvas, '--', Offset(rect.center.dx - 8, rect.center.dy - 7), 11, Colors.white38);
      return;
    }
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(0.0000001, maxValue - minValue);
    double yOf(double value) => rect.bottom - (value - minValue) / range * (rect.height - 18) - 4;
    _drawLine(canvas, xOf, yOf, valueOf, Paint()..color = const Color(0xFF81C784)..strokeWidth = 1.0..style = PaintingStyle.stroke);
    _text(canvas, _compact(maxValue), Offset(rect.right + 5, rect.top + 2), 10, Colors.white38);
  }

  void _drawDates(Canvas canvas, Rect rect) {
    _text(canvas, bars.first.time.length > 10 ? bars.first.time.substring(0, 10) : bars.first.time, Offset(rect.left, rect.bottom + 6), 10, Colors.white38);
    final last = bars.last.time.length > 10 ? bars.last.time.substring(0, 10) : bars.last.time;
    _text(canvas, last, Offset(rect.right - 66, rect.bottom + 6), 10, Colors.white38);
  }

  void _drawLegend(Canvas canvas, Rect rect) {
    final parts = <String>[];
    if (showMa) parts.add('MA5/10/20/60');
    if (showBoll) parts.add('BOLL');
    if (showVol) parts.add('VOL');
    if (showMacd) parts.add('MACD');
    if (showAmount) parts.add('amount');
    if (showTurnover) parts.add('turnover');
    _text(canvas, parts.join('  '), Offset(rect.left + 60, rect.top + 4), 10, Colors.white54);
  }

  void _drawCrosshair(Canvas canvas, Size size, Rect mainRect, double Function(int) xOf, double Function(double) priceToY) {
    final idx = crossIndex;
    if (idx == null || idx < 0 || idx >= bars.length) return;
    final bar = bars[idx];
    final x = xOf(idx);
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()..color = Colors.white.withValues(alpha: 0.22)..strokeWidth = 0.8);
    final y = priceToY(bar.close);
    canvas.drawLine(Offset(mainRect.left, y), Offset(mainRect.right, y), Paint()..color = Colors.white.withValues(alpha: 0.16)..strokeWidth = 0.8);
    final lines = <String>[
      bar.time,
      'O:${bar.open.toStringAsFixed(2)} H:${bar.high.toStringAsFixed(2)} L:${bar.low.toStringAsFixed(2)} C:${bar.close.toStringAsFixed(2)}',
      if (showMa) 'MA5:${_fmt(bar.ma[5])} MA10:${_fmt(bar.ma[10])} MA20:${_fmt(bar.ma[20])} MA60:${_fmt(bar.ma[60])}',
      if (showBoll) 'BOLL U:${_fmt(bar.boll?.upper)} M:${_fmt(bar.boll?.mid)} L:${_fmt(bar.boll?.lower)}',
      if (showVol) 'VOL:${_compact(bar.volume)}',
      if (showMacd) 'MACD DIF:${_fmt(bar.macd?.dif)} DEA:${_fmt(bar.macd?.dea)} HIST:${_fmt(bar.macd?.hist)}',
      if (showAmount) 'amount:${_compact(bar.amount)}',
      if (showTurnover) 'turnover:${_fmt(bar.turnover)}',
    ];
    final boxWidth = 318.0;
    final boxHeight = 18.0 + lines.length * 16.0;
    final left = x + boxWidth + 16 < size.width ? x + 10 : x - boxWidth - 10;
    final top = math.max(8.0, mainRect.top + 8);
    final rect = Rect.fromLTWH(left.clamp(4.0, math.max(4.0, size.width - boxWidth - 4)).toDouble(), top, boxWidth, boxHeight);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), Paint()..color = const Color(0xE6111722));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), Paint()..color = const Color(0xFF2962FF).withValues(alpha: 0.34)..style = PaintingStyle.stroke);
    for (var i = 0; i < lines.length; i++) {
      _text(canvas, lines[i], Offset(rect.left + 8, rect.top + 8 + i * 16), 11, i == 0 ? const Color(0xFF8AB4FF) : Colors.white70);
    }
  }

  String _fmt(double? value) => value == null ? '--' : value.toStringAsFixed(value.abs() >= 100 ? 2 : 3);
  String _compact(double? value) {
    if (value == null) return '--';
    final abs = value.abs();
    if (abs >= 100000000) return '${(value / 100000000).toStringAsFixed(2)}亿';
    if (abs >= 10000) return '${(value / 10000).toStringAsFixed(2)}万';
    return value.toStringAsFixed(2);
  }

  void _text(Canvas canvas, String text, Offset offset, double size, Color color) {
    final span = TextSpan(text: text, style: TextStyle(color: color, fontSize: size));
    final painter = TextPainter(text: span, textDirection: TextDirection.ltr, maxLines: 1)..layout(maxWidth: 420);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _IndicatorPainter oldDelegate) {
    return oldDelegate.bars != bars ||
        oldDelegate.showMa != showMa ||
        oldDelegate.showBoll != showBoll ||
        oldDelegate.showVol != showVol ||
        oldDelegate.showMacd != showMacd ||
        oldDelegate.showAmount != showAmount ||
        oldDelegate.showTurnover != showTurnover ||
        oldDelegate.crossIndex != crossIndex;
  }
}

class _IndicatorBar {
  final int rawIndex;
  final String time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? volume;
  final double? amount;
  final double? turnover;
  final Map<int, double?> ma;
  final _BollValue? boll;
  final _MacdValue? macd;

  const _IndicatorBar({
    required this.rawIndex,
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.amount,
    required this.turnover,
    required this.ma,
    required this.boll,
    required this.macd,
  });

  _IndicatorBar copyWith({Map<int, double?>? ma, _BollValue? boll, _MacdValue? macd}) {
    return _IndicatorBar(
      rawIndex: rawIndex,
      time: time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
      amount: amount,
      turnover: turnover,
      ma: ma ?? this.ma,
      boll: boll ?? this.boll,
      macd: macd ?? this.macd,
    );
  }
}

class _BollValue {
  final double? upper;
  final double? mid;
  final double? lower;
  const _BollValue({this.upper, this.mid, this.lower});
}

class _MacdValue {
  final double? dif;
  final double? dea;
  final double? hist;
  const _MacdValue({this.dif, this.dea, this.hist});
}
