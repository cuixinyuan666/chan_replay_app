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
  static bool get _isAndroidApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static String get _defaultBackend => _isAndroidApp ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';

  final _backend = TextEditingController(text: _defaultBackend);
  final _symbol = TextEditingController(text: '600340');
  final _count = TextEditingController(text: '320');

  String _market = 'SH';
  String _freq = 'DAILY';
  String _adjust = 'QFQ';
  String _status = '等待加载 easy-tdx 指标';
  bool _loading = false;
  bool _showMa = true;
  bool _showBoll = true;
  bool _showVol = true;
  bool _showMacd = true;
  bool _showAmount = false;
  bool _showTurnover = false;
  int? _crossIndex;
  List<_Bar> _bars = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _backend.dispose();
    _symbol.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    final symbol = _symbol.text.trim();
    if (symbol.isEmpty) return;
    setState(() {
      _loading = true;
      _status = '正在加载 $symbol.$_market $_freq 指标...';
    });
    try {
      final base = _backend.text.trim().replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/api/tdx/kline').replace(queryParameters: {
        'symbol': symbol,
        'market': _market,
        'freq': _freq,
        'adjust': _adjust,
        'count': '${int.tryParse(_count.text.trim())?.clamp(30, 5000).toInt() ?? 320}',
      });
      final resp = await http.get(uri).timeout(const Duration(seconds: 45));
      final body = utf8.decode(resp.bodyBytes);
      if (resp.statusCode < 200 || resp.statusCode >= 300) throw Exception('HTTP ${resp.statusCode}: $body');
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) throw const FormatException('后端返回不是 JSON 对象');
      if (json['ok'] == false) throw Exception(json['error'] ?? 'easy-tdx 请求失败');
      final parsed = _parse(json);
      if (parsed.isEmpty) throw const FormatException('没有有效 K线');
      setState(() {
        _bars = parsed;
        _crossIndex = parsed.length - 1;
        _status = '已加载 $symbol.$_market $_freq $_adjust K:${parsed.length}；MA/BOLL/MACD 支持后端返回，缺失时本页展示层本地补算';
      });
    } catch (e) {
      setState(() => _status = '加载失败：$e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败：$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Bar> _parse(Map<String, dynamic> root) {
    final rows = root['bars'];
    if (rows is! List) return const [];
    final ind = root['indicators'] is Map ? root['indicators'] as Map : const {};
    final vol = _point(ind['vol']);
    final amount = _point(ind['amount']);
    final turnover = _point(ind['turnover']);
    final ma = _maMap(ind['ma']);
    final boll = _bollMap(ind['boll']);
    final macd = _macdMap(ind['macd']);
    final out = <_Bar>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      if (r is! Map) continue;
      final o = _num(r['open'] ?? r['o']);
      final h = _num(r['high'] ?? r['h']);
      final l = _num(r['low'] ?? r['l']);
      final c = _num(r['close'] ?? r['c']);
      if (o == null || h == null || l == null || c == null) continue;
      final raw = _int(r['raw_index'] ?? r['rawIndex'] ?? r['id']) ?? out.length;
      out.add(_Bar(
        rawIndex: raw,
        time: _time(r['time'] ?? r['dt'] ?? r['date'] ?? r['datetime']),
        open: o,
        high: math.max(h, math.max(o, c)),
        low: math.min(l, math.min(o, c)),
        close: c,
        volume: vol[raw] ?? _num(r['volume'] ?? r['vol'] ?? r['v']),
        amount: amount[raw] ?? _num(r['amount'] ?? r['money']),
        turnover: turnover[raw] ?? _num(r['turnover'] ?? r['turnover_rate']),
        ma: {for (final e in ma.entries) e.key: e.value[raw]},
        boll: boll[raw],
        macd: macd[raw],
      ));
    }
    return _fallbackIndicators(out);
  }

  List<_Bar> _fallbackIndicators(List<_Bar> bars) {
    if (bars.isEmpty) return bars;
    final closes = [for (final b in bars) b.close];
    final ma = {5: _ma(closes, 5), 10: _ma(closes, 10), 20: _ma(closes, 20), 60: _ma(closes, 60)};
    final boll = _boll(closes, 20);
    final macd = _macd(closes, 12, 26, 9);
    return [
      for (var i = 0; i < bars.length; i++)
        bars[i].copyWith(
          ma: {for (final p in const [5, 10, 20, 60]) p: bars[i].ma[p] ?? ma[p]?[i]},
          boll: bars[i].boll ?? boll[i],
          macd: bars[i].macd ?? macd[i],
        ),
    ];
  }

  Map<int, double?> _point(Object? v) {
    if (v is! List) return const {};
    final out = <int, double?>{};
    for (var i = 0; i < v.length; i++) {
      final r = v[i];
      if (r is Map) out[_int(r['raw_index'] ?? r['rawIndex']) ?? i] = _num(r['value']);
    }
    return out;
  }

  Map<int, Map<int, double?>> _maMap(Object? v) {
    if (v is! Map) return const {};
    return {for (final e in v.entries) if (_int(e.key) != null) _int(e.key)!: _point(e.value)};
  }

  Map<int, _Boll> _bollMap(Object? v) {
    if (v is! List) return const {};
    final out = <int, _Boll>{};
    for (var i = 0; i < v.length; i++) {
      final r = v[i];
      if (r is Map) out[_int(r['raw_index'] ?? r['rawIndex']) ?? i] = _Boll(_num(r['upper']), _num(r['mid']), _num(r['lower']));
    }
    return out;
  }

  Map<int, _Macd> _macdMap(Object? v) {
    if (v is! List) return const {};
    final out = <int, _Macd>{};
    for (var i = 0; i < v.length; i++) {
      final r = v[i];
      if (r is Map) out[_int(r['raw_index'] ?? r['rawIndex']) ?? i] = _Macd(_num(r['dif'] ?? r['diff']), _num(r['dea']), _num(r['hist'] ?? r['macd']));
    }
    return out;
  }

  List<double?> _ma(List<double> values, int n) {
    final out = <double?>[];
    final q = <double>[];
    for (final v in values) {
      q.add(v);
      if (q.length > n) q.removeAt(0);
      out.add(q.length < n ? null : q.reduce((a, b) => a + b) / n);
    }
    return out;
  }

  List<_Boll> _boll(List<double> values, int n) {
    final out = <_Boll>[];
    final q = <double>[];
    for (final v in values) {
      q.add(v);
      if (q.length > n) q.removeAt(0);
      if (q.length < n) {
        out.add(const _Boll(null, null, null));
        continue;
      }
      final mid = q.reduce((a, b) => a + b) / q.length;
      final variance = q.map((e) => (e - mid) * (e - mid)).reduce((a, b) => a + b) / q.length;
      final delta = 2 * math.sqrt(variance);
      out.add(_Boll(mid + delta, mid, mid - delta));
    }
    return out;
  }

  List<_Macd> _macd(List<double> values, int fast, int slow, int signal) {
    final out = <_Macd>[];
    double? ef;
    double? es;
    double? dea;
    double ema(double? prev, double v, int n) {
      final a = 2.0 / (n + 1.0);
      return prev == null ? v : a * v + (1 - a) * prev;
    }

    for (final close in values) {
      ef = ema(ef, close, fast);
      es = ema(es, close, slow);
      final dif = ef - es;
      dea = ema(dea, dif, signal);
      out.add(_Macd(dif, dea, dif - dea));
    }
    return out;
  }

  double? _num(Object? v) {
    if (v is num) return v.toDouble();
    final text = '${v ?? ''}'.trim().replaceAll(',', '');
    if (text.isEmpty || text == '-' || text == '--' || text == 'null' || text.toLowerCase() == 'nan') return null;
    return double.tryParse(text);
  }

  int? _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}'.trim());
  }

  String _time(Object? v) {
    final text = '${v ?? ''}'.trim();
    return text.length > 19 ? text.substring(0, 19) : text;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _bars.length > 260 ? _bars.sublist(_bars.length - 260) : _bars;
    final offset = _bars.length > 260 ? _bars.length - 260 : 0;
    final cross = _crossIndex == null ? null : (_crossIndex! - offset).clamp(0, math.max(0, visible.length - 1)).toInt();
    return Container(
      color: const Color(0xFF0B0F16),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 10),
              _controls(),
              const SizedBox(height: 10),
              _switches(),
              const SizedBox(height: 8),
              Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: const Color(0xFF101722), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: visible.isEmpty
                        ? const Center(child: Text('暂无指标数据', style: TextStyle(color: Colors.white54)))
                        : _IndicatorCanvas(
                            bars: visible,
                            crossIndex: cross,
                            showMa: _showMa,
                            showBoll: _showBoll,
                            showVol: _showVol,
                            showMacd: _showMacd,
                            showAmount: _showAmount,
                            showTurnover: _showTurnover,
                            onCross: (i) => setState(() => _crossIndex = offset + i),
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

  Widget _header() {
    return Row(
      children: [
        const Icon(Icons.insights, color: Color(0xFF8AB4FF), size: 26),
        const SizedBox(width: 8),
        const Text('easy-tdx 指标', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        const Text('展示指标，不参与 chan.py 缠论计算', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const Spacer(),
        if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ],
    );
  }

  Widget _controls() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _input(_backend, '后端', 220),
        _input(_symbol, '代码', 110),
        _drop('市场', _market, const ['SH', 'SZ'], (v) => setState(() => _market = v)),
        _drop('周期', _freq, const ['MIN1', 'MIN5', 'MIN15', 'MIN30', 'MIN60', 'DAILY', 'WEEKLY', 'MONTHLY'], (v) => setState(() => _freq = v), width: 116),
        _drop('复权', _adjust, const ['QFQ', 'HFQ', 'NONE'], (v) => setState(() => _adjust = v)),
        _input(_count, '数量', 82),
        FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('加载指标')),
      ],
    );
  }

  Widget _switches() {
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

  Widget _input(TextEditingController c, String label, double width) => SizedBox(
        width: width,
        height: 42,
        child: TextField(
          controller: c,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF151B26), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        ),
      );

  Widget _drop(String label, String value, List<String> items, ValueChanged<String> onChanged, {double width = 86}) => SizedBox(
        width: width,
        height: 42,
        child: DropdownButtonFormField<String>(
          value: value,
          dropdownColor: const Color(0xFF151B26),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF151B26), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5)),
          items: [for (final item in items) DropdownMenuItem(value: item, child: Text(item))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );

  Widget _chip(String label, bool selected, ValueChanged<bool> onSelected) => FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        backgroundColor: const Color(0xFF151B26),
        selectedColor: const Color(0xFF2962FF),
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w700),
      );
}

class _IndicatorCanvas extends StatelessWidget {
  final List<_Bar> bars;
  final int? crossIndex;
  final bool showMa;
  final bool showBoll;
  final bool showVol;
  final bool showMacd;
  final bool showAmount;
  final bool showTurnover;
  final ValueChanged<int> onCross;

  const _IndicatorCanvas({required this.bars, required this.crossIndex, required this.showMa, required this.showBoll, required this.showVol, required this.showMacd, required this.showAmount, required this.showTurnover, required this.onCross});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _setCross(d.localPosition, size),
        onPanUpdate: (d) => _setCross(d.localPosition, size),
        child: CustomPaint(size: Size.infinite, painter: _IndicatorPainter(bars, crossIndex, showMa, showBoll, showVol, showMacd, showAmount, showTurnover)),
      );
    });
  }

  void _setCross(Offset p, Size s) {
    const left = 48.0;
    const right = 68.0;
    final width = math.max(1.0, s.width - left - right);
    final step = width / math.max(1, bars.length);
    onCross(((p.dx - left) / step).floor().clamp(0, bars.length - 1).toInt());
  }
}

class _IndicatorPainter extends CustomPainter {
  final List<_Bar> bars;
  final int? cross;
  final bool showMa;
  final bool showBoll;
  final bool showVol;
  final bool showMacd;
  final bool showAmount;
  final bool showTurnover;

  _IndicatorPainter(this.bars, this.cross, this.showMa, this.showBoll, this.showVol, this.showMacd, this.showAmount, this.showTurnover);

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const left = 48.0;
    const right = 68.0;
    const top = 24.0;
    const bottom = 22.0;
    final subCount = [showVol, showMacd, showAmount, showTurnover].where((e) => e).length;
    final subH = subCount == 0 ? 0.0 : math.min(82.0, math.max(52.0, size.height * 0.16));
    final gap = subCount == 0 ? 0.0 : 8.0;
    final mainH = math.max(80.0, size.height - top - bottom - subH * subCount - gap * subCount);
    final main = Rect.fromLTWH(left, top, math.max(1.0, size.width - left - right), mainH);
    final step = main.width / math.max(1, bars.length);
    double x(int i) => main.left + (i + 0.5) * step;

    final priceExtras = <double>[];
    if (showMa) {
      for (final b in bars) {
        for (final v in b.ma.values) {
          if (v != null) priceExtras.add(v);
        }
      }
    }
    if (showBoll) {
      for (final b in bars) {
        if (b.boll?.upper != null) priceExtras.add(b.boll!.upper!);
        if (b.boll?.lower != null) priceExtras.add(b.boll!.lower!);
      }
    }
    final minP = [bars.map((e) => e.low).reduce(math.min), ...priceExtras].reduce(math.min);
    final maxP = [bars.map((e) => e.high).reduce(math.max), ...priceExtras].reduce(math.max);
    final pad = math.max(maxP - minP, maxP.abs() * 0.01) * 0.08;
    double py(double v) => main.bottom - (v - minP + pad) / math.max(0.000001, maxP - minP + pad * 2) * main.height;

    _panel(canvas, main, 'PRICE');
    _axis(canvas, main, minP - pad, maxP + pad);
    _candles(canvas, main, step, x, py);
    if (showBoll) _bollLines(canvas, x, py);
    if (showMa) _maLines(canvas, x, py);

    var y = main.bottom + gap;
    if (showVol) {
      _vol(canvas, Rect.fromLTWH(left, y, main.width, subH), step, x);
      y += subH + gap;
    }
    if (showMacd) {
      _macd(canvas, Rect.fromLTWH(left, y, main.width, subH), step, x);
      y += subH + gap;
    }
    if (showAmount) {
      _linePanel(canvas, Rect.fromLTWH(left, y, main.width, subH), x, 'AMOUNT', (b) => b.amount);
      y += subH + gap;
    }
    if (showTurnover) _linePanel(canvas, Rect.fromLTWH(left, y, main.width, subH), x, 'TURNOVER', (b) => b.turnover);

    _text(canvas, bars.first.time.substring(0, math.min(10, bars.first.time.length)), Offset(main.left, main.bottom + 6), 10, Colors.white38);
    _text(canvas, bars.last.time.substring(0, math.min(10, bars.last.time.length)), Offset(main.right - 66, main.bottom + 6), 10, Colors.white38);
    _text(canvas, [if (showMa) 'MA', if (showBoll) 'BOLL', if (showVol) 'VOL', if (showMacd) 'MACD', if (showAmount) 'amount', if (showTurnover) 'turnover'].join('  '), Offset(main.left + 64, main.top + 4), 10, Colors.white54);
    _cross(canvas, size, main, x, py);
  }

  void _panel(Canvas c, Rect r, String title) {
    c.drawRect(r, Paint()..color = const Color(0xFF0D1320));
    c.drawRect(r, Paint()..color = Colors.white.withValues(alpha: 0.08)..style = PaintingStyle.stroke);
    final p = Paint()..color = Colors.white.withValues(alpha: 0.08)..strokeWidth = 0.7;
    for (var i = 1; i < 4; i++) c.drawLine(Offset(r.left, r.top + r.height * i / 4), Offset(r.right, r.top + r.height * i / 4), p);
    _text(c, title, Offset(r.left + 6, r.top + 4), 10, Colors.white54);
  }

  void _axis(Canvas c, Rect r, double min, double max) {
    for (var i = 0; i <= 4; i++) _text(c, (max - (max - min) * i / 4).toStringAsFixed(2), Offset(r.right + 5, r.top + r.height * i / 4 - 6), 10, Colors.white54);
  }

  void _candles(Canvas c, Rect r, double step, double Function(int) x, double Function(double) py) {
    final up = Paint()..color = const Color(0xFF26A69A);
    final down = Paint()..color = const Color(0xFFEF5350);
    final wick = Paint()..strokeWidth = math.max(0.8, step * 0.08);
    final w = math.max(1.0, math.min(step * 0.66, step - 1));
    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      final p = b.close >= b.open ? up : down;
      final cx = x(i);
      wick.color = p.color;
      c.drawLine(Offset(cx, py(b.high)), Offset(cx, py(b.low)), wick);
      final o = py(b.open);
      final cl = py(b.close);
      c.drawRect(Rect.fromLTRB(cx - w / 2, math.min(o, cl), cx + w / 2, math.max(math.min(o, cl) + 1, math.max(o, cl))), p);
    }
  }

  void _maLines(Canvas c, double Function(int) x, double Function(double) y) {
    final colors = {5: const Color(0xFFFFD54F), 10: const Color(0xFF64B5F6), 20: const Color(0xFFBA68C8), 60: const Color(0xFFFF8A65)};
    for (final p in const [5, 10, 20, 60]) _series(c, x, y, (b) => b.ma[p], colors[p] ?? Colors.white, 1.1);
  }

  void _bollLines(Canvas c, double Function(int) x, double Function(double) y) {
    _series(c, x, y, (b) => b.boll?.upper, const Color(0xFF90CAF9), 0.9);
    _series(c, x, y, (b) => b.boll?.mid, Colors.white54, 0.8);
    _series(c, x, y, (b) => b.boll?.lower, const Color(0xFF90CAF9), 0.9);
  }

  void _vol(Canvas c, Rect r, double step, double Function(int) x) {
    _panel(c, r, 'VOL');
    final maxV = bars.map((e) => e.volume ?? 0.0).fold<double>(0.0, (a, b) => math.max(a, b));
    if (maxV <= 0) return;
    final w = math.max(1.0, math.min(step * 0.62, step - 1));
    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      final h = (b.volume ?? 0.0) / maxV * (r.height - 18);
      c.drawRect(Rect.fromLTRB(x(i) - w / 2, r.bottom - h, x(i) + w / 2, r.bottom), Paint()..color = (b.close >= b.open ? const Color(0xFF26A69A) : const Color(0xFFEF5350)).withValues(alpha: 0.72));
    }
    _text(c, _compact(maxV), Offset(r.right + 5, r.top + 2), 10, Colors.white38);
  }

  void _macd(Canvas c, Rect r, double step, double Function(int) x) {
    _panel(c, r, 'MACD');
    final vals = <double>[];
    for (final b in bars) {
      if (b.macd?.dif != null) vals.add(b.macd!.dif!);
      if (b.macd?.dea != null) vals.add(b.macd!.dea!);
      if (b.macd?.hist != null) vals.add(b.macd!.hist!);
    }
    if (vals.isEmpty) return;
    final maxAbs = math.max(0.0000001, vals.map((e) => e.abs()).reduce(math.max));
    final zero = r.top + r.height / 2;
    double y(double v) => zero - v / maxAbs * (r.height * 0.42);
    c.drawLine(Offset(r.left, zero), Offset(r.right, zero), Paint()..color = Colors.white.withValues(alpha: 0.16));
    final w = math.max(1.0, math.min(step * 0.58, step - 1));
    for (var i = 0; i < bars.length; i++) {
      final h = bars[i].macd?.hist;
      if (h == null) continue;
      final yy = y(h);
      c.drawRect(Rect.fromLTRB(x(i) - w / 2, math.min(zero, yy), x(i) + w / 2, math.max(zero, yy)), Paint()..color = (h >= 0 ? const Color(0xFF26A69A) : const Color(0xFFEF5350)).withValues(alpha: 0.78));
    }
    _series(c, x, y, (b) => b.macd?.dif, const Color(0xFFFFD54F), 1.0);
    _series(c, x, y, (b) => b.macd?.dea, const Color(0xFF64B5F6), 1.0);
  }

  void _linePanel(Canvas c, Rect r, double Function(int) x, String title, double? Function(_Bar) val) {
    _panel(c, r, title);
    final vals = bars.map(val).whereType<double>().toList();
    if (vals.isEmpty) {
      _text(c, '--', Offset(r.center.dx - 8, r.center.dy - 7), 11, Colors.white38);
      return;
    }
    final minV = vals.reduce(math.min);
    final maxV = vals.reduce(math.max);
    final range = math.max(0.0000001, maxV - minV);
    double y(double v) => r.bottom - (v - minV) / range * (r.height - 18) - 4;
    _series(c, x, y, val, const Color(0xFF81C784), 1.0);
    _text(c, _compact(maxV), Offset(r.right + 5, r.top + 2), 10, Colors.white38);
  }

  void _series(Canvas c, double Function(int) x, double Function(double) y, double? Function(_Bar) val, Color color, double width) {
    final path = Path();
    var started = false;
    for (var i = 0; i < bars.length; i++) {
      final v = val(bars[i]);
      if (v == null) {
        started = false;
        continue;
      }
      final p = Offset(x(i), y(v));
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    c.drawPath(path, Paint()..color = color..strokeWidth = width..style = PaintingStyle.stroke);
  }

  void _cross(Canvas c, Size s, Rect main, double Function(int) x, double Function(double) py) {
    final i = cross;
    if (i == null || i < 0 || i >= bars.length) return;
    final b = bars[i];
    final cx = x(i);
    c.drawLine(Offset(cx, 0), Offset(cx, s.height), Paint()..color = Colors.white.withValues(alpha: 0.22));
    c.drawLine(Offset(main.left, py(b.close)), Offset(main.right, py(b.close)), Paint()..color = Colors.white.withValues(alpha: 0.16));
    final lines = <String>[
      b.time,
      'O:${b.open.toStringAsFixed(2)} H:${b.high.toStringAsFixed(2)} L:${b.low.toStringAsFixed(2)} C:${b.close.toStringAsFixed(2)}',
      if (showMa) 'MA5:${_fmt(b.ma[5])} MA10:${_fmt(b.ma[10])} MA20:${_fmt(b.ma[20])} MA60:${_fmt(b.ma[60])}',
      if (showBoll) 'BOLL U:${_fmt(b.boll?.upper)} M:${_fmt(b.boll?.mid)} L:${_fmt(b.boll?.lower)}',
      if (showVol) 'VOL:${_compact(b.volume)}',
      if (showMacd) 'MACD DIF:${_fmt(b.macd?.dif)} DEA:${_fmt(b.macd?.dea)} HIST:${_fmt(b.macd?.hist)}',
      if (showAmount) 'amount:${_compact(b.amount)}',
      if (showTurnover) 'turnover:${_fmt(b.turnover)}',
    ];
    const boxW = 318.0;
    final boxH = 18.0 + lines.length * 16.0;
    final rawLeft = cx + boxW + 16 < s.width ? cx + 10 : cx - boxW - 10;
    final left = rawLeft.clamp(4.0, math.max(4.0, s.width - boxW - 4)).toDouble();
    final r = Rect.fromLTWH(left, main.top + 8, boxW, boxH);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), Paint()..color = const Color(0xE6111722));
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), Paint()..color = const Color(0xFF2962FF).withValues(alpha: 0.34)..style = PaintingStyle.stroke);
    for (var n = 0; n < lines.length; n++) _text(c, lines[n], Offset(r.left + 8, r.top + 8 + n * 16), 11, n == 0 ? const Color(0xFF8AB4FF) : Colors.white70);
  }

  String _fmt(double? v) => v == null ? '--' : v.toStringAsFixed(v.abs() >= 100 ? 2 : 3);
  String _compact(double? v) {
    if (v == null) return '--';
    final a = v.abs();
    if (a >= 100000000) return '${(v / 100000000).toStringAsFixed(2)}亿';
    if (a >= 10000) return '${(v / 10000).toStringAsFixed(2)}万';
    return v.toStringAsFixed(2);
  }

  void _text(Canvas c, String text, Offset o, double size, Color color) {
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)), textDirection: TextDirection.ltr, maxLines: 1)..layout(maxWidth: 420);
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _IndicatorPainter old) => old.bars != bars || old.cross != cross || old.showMa != showMa || old.showBoll != showBoll || old.showVol != showVol || old.showMacd != showMacd || old.showAmount != showAmount || old.showTurnover != showTurnover;
}

class _Bar {
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
  final _Boll? boll;
  final _Macd? macd;

  const _Bar({required this.rawIndex, required this.time, required this.open, required this.high, required this.low, required this.close, required this.volume, required this.amount, required this.turnover, required this.ma, required this.boll, required this.macd});

  _Bar copyWith({Map<int, double?>? ma, _Boll? boll, _Macd? macd}) => _Bar(rawIndex: rawIndex, time: time, open: open, high: high, low: low, close: close, volume: volume, amount: amount, turnover: turnover, ma: ma ?? this.ma, boll: boll ?? this.boll, macd: macd ?? this.macd);
}

class _Boll {
  final double? upper;
  final double? mid;
  final double? lower;
  const _Boll(this.upper, this.mid, this.lower);
}

class _Macd {
  final double? dif;
  final double? dea;
  final double? hist;
  const _Macd(this.dif, this.dea, this.hist);
}
