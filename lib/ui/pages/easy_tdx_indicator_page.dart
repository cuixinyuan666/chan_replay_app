import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../../data/python_chan_analysis_source.dart';

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
  bool _showKdj = false;
  bool _showRsi = false;
  bool _showDmi = false;
  bool _showAtr = false;
  bool _showWr = false;
  bool _showCci = false;
  bool _showBias = false;
  bool _showObv = false;
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
      _status = '正在通过复盘同款 Python 通道加载 $symbol.$_market $_freq 指标...';
    });
    final source = PythonChanAnalysisSource(baseUrl: _cleanBaseUrl(_backend.text));
    try {
      final analysis = await source.analyze(
        mode: 'once',
        market: _market,
        code: symbol,
        period: _freq,
        adjust: _adjust,
        count: int.tryParse(_count.text.trim())?.clamp(30, 5000).toInt() ?? 320,
        config: const {'boll_n': 20, 'macd_fast': 12, 'macd_slow': 26, 'macd_signal': 9},
      );
      final parsed = _fromSnapshot(analysis.snapshot);
      if (parsed.isEmpty) throw const FormatException('没有有效 K线');
      setState(() {
        _bars = parsed;
        _crossIndex = parsed.length - 1;
        _status = '已加载 $symbol.$_market $_freq $_adjust K:${parsed.length}；指标来源已标注，且不参与 chan.py 缠论结构计算';
      });
    } catch (e) {
      setState(() => _status = '加载失败：$e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败：$e')));
    } finally {
      source.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cleanBaseUrl(String input) {
    final text = input.trim().replaceAll(RegExp(r'\s+'), '');
    return text.isEmpty ? _defaultBackend : text.replaceAll(RegExp(r'/+$'), '');
  }

  List<_Bar> _fromSnapshot(ChanSnapshot snapshot) {
    final indicators = snapshot.indicators;
    final vol = {for (final p in indicators.vol) p.rawIndex: p.value};
    final amount = {for (final p in indicators.amount) p.rawIndex: p.value};
    final turnover = {for (final p in indicators.turnover) p.rawIndex: p.value};
    final ma = {for (final entry in indicators.ma.entries) entry.key: {for (final p in entry.value) p.rawIndex: p.value}};
    final boll = {for (final p in indicators.boll) p.rawIndex: _Boll(p.upper, p.mid, p.lower)};
    final macd = {for (final p in indicators.macd) p.rawIndex: _Macd(p.dif, p.dea, p.hist)};
    final named = {for (final entry in indicators.namedSeries.entries) entry.key: {for (final p in entry.value) p.rawIndex: p.values}};
    final bars = <_Bar>[];
    for (final raw in snapshot.rawBars) {
      final rawIndex = raw.index;
      bars.add(_Bar(
        rawIndex: rawIndex,
        time: _fmtTime(raw.time),
        open: raw.open,
        high: raw.high,
        low: raw.low,
        close: raw.close,
        volume: vol[rawIndex] ?? raw.volume,
        amount: amount[rawIndex],
        turnover: turnover[rawIndex],
        ma: {for (final entry in ma.entries) entry.key: entry.value[rawIndex]},
        boll: boll[rawIndex],
        macd: macd[rawIndex],
        extra: {for (final entry in named.entries) entry.key: entry.value[rawIndex] ?? const <String, double?>{}},
      ));
    }
    return _fallbackIndicators(bars);
  }

  String _fmtTime(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return time.hour == 0 && time.minute == 0 && time.second == 0 ? '$y-$m-$d' : '$y-$m-$d $hh:$mm';
  }

  List<_Bar> _fallbackIndicators(List<_Bar> bars) {
    if (bars.isEmpty) return bars;
    final close = [for (final b in bars) b.close];
    final high = [for (final b in bars) b.high];
    final low = [for (final b in bars) b.low];
    final volume = [for (final b in bars) b.volume];
    final ma = {5: _ma(close, 5), 10: _ma(close, 10), 20: _ma(close, 20), 60: _ma(close, 60)};
    final boll = _boll(close, 20);
    final macd = _macd(close, 12, 26, 9);
    final extras = {
      'KDJ': _kdj(close, high, low),
      'RSI': _rsi(close),
      'DMI': _dmi(close, high, low),
      'ATR': _atr(close, high, low),
      'WR': _wr(close, high, low),
      'CCI': _cci(close, high, low),
      'BIAS': _bias(close),
      'OBV': _obv(close, volume),
    };
    return [
      for (var i = 0; i < bars.length; i++)
        bars[i].copyWith(
          ma: {for (final p in const [5, 10, 20, 60]) p: bars[i].ma[p] ?? ma[p]?[i]},
          boll: bars[i].boll ?? boll[i],
          macd: bars[i].macd ?? macd[i],
          extra: {
            for (final key in extras.keys)
              key: (bars[i].extra[key]?.isNotEmpty ?? false) ? bars[i].extra[key]! : extras[key]![i],
          },
        ),
    ];
  }

  List<double?> _ma(List<double> values, int n) => [for (var i = 0; i < values.length; i++) i + 1 < n ? null : values.sublist(i + 1 - n, i + 1).reduce((a, b) => a + b) / n];

  List<_Boll> _boll(List<double> values, int n) {
    final out = <_Boll>[];
    for (var i = 0; i < values.length; i++) {
      if (i + 1 < n) { out.add(const _Boll(null, null, null)); continue; }
      final rows = values.sublist(i + 1 - n, i + 1);
      final mid = rows.reduce((a, b) => a + b) / n;
      final std = math.sqrt(rows.map((e) => (e - mid) * (e - mid)).reduce((a, b) => a + b) / n);
      out.add(_Boll(mid + 2 * std, mid, mid - 2 * std));
    }
    return out;
  }

  List<_Macd> _macd(List<double> values, int fast, int slow, int signal) {
    final out = <_Macd>[];
    double? ef, es, dea;
    double ema(double? prev, double v, int n) => prev == null ? v : (2.0 / (n + 1.0)) * v + (1 - 2.0 / (n + 1.0)) * prev;
    for (final close in values) {
      ef = ema(ef, close, fast);
      es = ema(es, close, slow);
      final dif = ef! - es!;
      dea = ema(dea, dif, signal);
      out.add(_Macd(dif, dea, dif - dea!));
    }
    return out;
  }

  List<Map<String, double?>> _kdj(List<double> c, List<double> h, List<double> l) {
    final rsv = <double?>[];
    for (var i = 0; i < c.length; i++) {
      if (i + 1 < 9) { rsv.add(null); continue; }
      final hh = h.sublist(i - 8, i + 1).reduce(math.max);
      final ll = l.sublist(i - 8, i + 1).reduce(math.min);
      rsv.add((hh - ll).abs() < 1e-12 ? 50 : (c[i] - ll) / (hh - ll) * 100);
    }
    final k = _emaNullable(rsv, 5);
    final d = _emaNullable(k, 5);
    return [for (var i = 0; i < c.length; i++) {'KDJ_K': _rd(k[i]), 'KDJ_D': _rd(d[i]), 'KDJ_J': _rd(k[i] == null || d[i] == null ? null : 3 * k[i]! - 2 * d[i]!)}];
  }

  List<Map<String, double?>> _rsi(List<double> c) {
    final dif = <double?>[null];
    for (var i = 1; i < c.length; i++) dif.add(c[i] - c[i - 1]);
    final pos = [for (final d in dif) d == null ? null : math.max(d, 0)];
    final absD = [for (final d in dif) d?.abs()];
    final ps = _smaNullable(pos, 24);
    final as = _smaNullable(absD, 24);
    return [for (var i = 0; i < c.length; i++) {'RSI': _rd(as[i] == null ? null : (as[i]!.abs() < 1e-12 ? 50 : (ps[i] ?? 0) / as[i]! * 100))}];
  }

  List<Map<String, double?>> _atr(List<double> c, List<double> h, List<double> l) => [for (final v in _maNullable(_tr(c, h, l), 20)) {'ATR': _rd(v)}];

  List<Map<String, double?>> _dmi(List<double> c, List<double> h, List<double> l) {
    final trSum = _sumNullable(_tr(c, h, l), 14);
    final dmp = <double?>[null], dmm = <double?>[null];
    for (var i = 1; i < c.length; i++) {
      final hd = h[i] - h[i - 1], ld = l[i - 1] - l[i];
      dmp.add(hd > 0 && hd > ld ? hd : 0);
      dmm.add(ld > 0 && ld > hd ? ld : 0);
    }
    final dmpSum = _sumNullable(dmp, 14), dmmSum = _sumNullable(dmm, 14);
    final pdi = <double?>[], mdi = <double?>[], dx = <double?>[];
    for (var i = 0; i < c.length; i++) {
      pdi.add(trSum[i] == null || trSum[i]!.abs() < 1e-12 ? null : (dmpSum[i] ?? 0) * 100 / trSum[i]!);
      mdi.add(trSum[i] == null || trSum[i]!.abs() < 1e-12 ? null : (dmmSum[i] ?? 0) * 100 / trSum[i]!);
      dx.add(pdi[i] == null || mdi[i] == null || (pdi[i]! + mdi[i]!).abs() < 1e-12 ? null : (mdi[i]! - pdi[i]!).abs() / (pdi[i]! + mdi[i]!) * 100);
    }
    final adx = _maNullable(dx, 6);
    return [for (var i = 0; i < c.length; i++) {'DMI_PDI': _rd(pdi[i]), 'DMI_MDI': _rd(mdi[i]), 'DMI_ADX': _rd(adx[i]), 'DMI_ADXR': _rd(i < 6 || adx[i] == null || adx[i - 6] == null ? null : (adx[i]! + adx[i - 6]!) / 2)}];
  }

  List<Map<String, double?>> _wr(List<double> c, List<double> h, List<double> l) {
    List<double?> calc(int n) => [for (var i = 0; i < c.length; i++) if (i + 1 < n) null else _wrAt(c[i], h.sublist(i + 1 - n, i + 1), l.sublist(i + 1 - n, i + 1))];
    final wr1 = calc(10), wr2 = calc(6);
    return [for (var i = 0; i < c.length; i++) {'WR1': _rd(wr1[i]), 'WR2': _rd(wr2[i])}];
  }

  double _wrAt(double close, List<double> highs, List<double> lows) {
    final hh = highs.reduce(math.max), ll = lows.reduce(math.min);
    return (hh - ll).abs() < 1e-12 ? 50 : (hh - close) / (hh - ll) * 100;
  }

  List<Map<String, double?>> _cci(List<double> c, List<double> h, List<double> l) {
    final tp = [for (var i = 0; i < c.length; i++) (h[i] + l[i] + c[i]) / 3];
    final ma = _ma(tp, 14);
    final out = <Map<String, double?>>[];
    for (var i = 0; i < c.length; i++) {
      if (i + 1 < 14 || ma[i] == null) { out.add({'CCI': null}); continue; }
      final rows = tp.sublist(i - 13, i + 1);
      final avedev = rows.map((e) => (e - ma[i]!).abs()).reduce((a, b) => a + b) / 14;
      out.add({'CCI': _rd(avedev.abs() < 1e-12 ? null : (tp[i] - ma[i]!) / (0.015 * avedev))});
    }
    return out;
  }

  List<Map<String, double?>> _bias(List<double> c) {
    final m6 = _ma(c, 6), m12 = _ma(c, 12), m24 = _ma(c, 24);
    double? calc(double close, double? ma) => ma == null || ma.abs() < 1e-12 ? null : (close - ma) / ma * 100;
    return [for (var i = 0; i < c.length; i++) {'BIAS1': _rd(calc(c[i], m6[i])), 'BIAS2': _rd(calc(c[i], m12[i])), 'BIAS3': _rd(calc(c[i], m24[i]))}];
  }

  List<Map<String, double?>> _obv(List<double> c, List<double?> v) {
    var total = 0.0;
    final out = <Map<String, double?>>[];
    for (var i = 0; i < c.length; i++) {
      if (i > 0 && v[i] != null) {
        if (c[i] > c[i - 1]) total += v[i]!;
        if (c[i] < c[i - 1]) total -= v[i]!;
      }
      out.add({'OBV': _rd(total / 10000)});
    }
    return out;
  }

  List<double?> _tr(List<double> c, List<double> h, List<double> l) => [for (var i = 0; i < c.length; i++) math.max(h[i] - l[i], math.max((h[i] - (i == 0 ? c[i] : c[i - 1])).abs(), (l[i] - (i == 0 ? c[i] : c[i - 1])).abs()))];
  List<double?> _emaNullable(List<double?> values, int n) { double? prev; return [for (final v in values) if (v == null) null else prev = prev == null ? v : (2 / (n + 1)) * v + (1 - 2 / (n + 1)) * prev!]; }
  List<double?> _smaNullable(List<double?> values, int n) { double? prev; return [for (final v in values) if (v == null) null else prev = prev == null ? v : (1 / n) * v + (1 - 1 / n) * prev!]; }
  List<double?> _maNullable(List<double?> values, int n) => [for (var i = 0; i < values.length; i++) i + 1 < n || values.sublist(i + 1 - n, i + 1).any((e) => e == null) ? null : values.sublist(i + 1 - n, i + 1).whereType<double>().reduce((a, b) => a + b) / n];
  List<double?> _sumNullable(List<double?> values, int n) => [for (var i = 0; i < values.length; i++) i + 1 < n || values.sublist(i + 1 - n, i + 1).any((e) => e == null) ? null : values.sublist(i + 1 - n, i + 1).whereType<double>().reduce((a, b) => a + b)];
  double? _rd(double? v) => v == null ? null : double.parse(v.toStringAsFixed(3));

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
              _header(), const SizedBox(height: 10), _controls(), const SizedBox(height: 10), _switches(), const SizedBox(height: 8),
              Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 4), _sourceLine(), const SizedBox(height: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: const Color(0xFF101722), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                  child: ClipRRect(borderRadius: BorderRadius.circular(12), child: visible.isEmpty ? const Center(child: Text('暂无指标数据', style: TextStyle(color: Colors.white54))) : _IndicatorCanvas(bars: visible, crossIndex: cross, showMa: _showMa, showBoll: _showBoll, showVol: _showVol, showMacd: _showMacd, showAmount: _showAmount, showTurnover: _showTurnover, showExtra: _showExtraMap, onCross: (i) => setState(() => _crossIndex = offset + i))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, bool> get _showExtraMap => {'KDJ': _showKdj, 'RSI': _showRsi, 'DMI': _showDmi, 'ATR': _showAtr, 'WR': _showWr, 'CCI': _showCci, 'BIAS': _showBias, 'OBV': _showObv};

  Widget _header() => Row(children: [const Icon(Icons.insights, color: Color(0xFF8AB4FF), size: 26), const SizedBox(width: 8), const Text('easy-tdx 指标', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(width: 10), const Text('复用复盘页 Python 调用链', style: TextStyle(color: Colors.white54, fontSize: 12)), const Spacer(), if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))]);

  Widget _controls() => SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_input(_backend, '后端/自动内置Python', 220), _gap(), _input(_symbol, '代码', 110), _gap(), _drop('市场', _market, const ['SH', 'SZ'], (v) => setState(() => _market = v)), _gap(), _drop('周期', _freq, const ['MIN1', 'MIN5', 'MIN15', 'MIN30', 'MIN60', 'DAILY', 'WEEKLY', 'MONTHLY'], (v) => setState(() => _freq = v), width: 116), _gap(), _drop('复权', _adjust, const ['QFQ', 'HFQ', 'NONE'], (v) => setState(() => _adjust = v)), _gap(), _input(_count, '数量', 82), _gap(), FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('加载指标'))]));

  Widget _switches() => SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_chip('MA', _showMa, (v) => setState(() => _showMa = v)), _chip('BOLL', _showBoll, (v) => setState(() => _showBoll = v)), _chip('VOL', _showVol, (v) => setState(() => _showVol = v)), _chip('MACD', _showMacd, (v) => setState(() => _showMacd = v)), _chip('KDJ', _showKdj, (v) => setState(() => _showKdj = v)), _chip('RSI', _showRsi, (v) => setState(() => _showRsi = v)), _chip('DMI', _showDmi, (v) => setState(() => _showDmi = v)), _chip('ATR', _showAtr, (v) => setState(() => _showAtr = v)), _chip('WR', _showWr, (v) => setState(() => _showWr = v)), _chip('CCI', _showCci, (v) => setState(() => _showCci = v)), _chip('BIAS', _showBias, (v) => setState(() => _showBias = v)), _chip('OBV', _showObv, (v) => setState(() => _showObv = v)), _chip('amount', _showAmount, (v) => setState(() => _showAmount = v)), _chip('turnover', _showTurnover, (v) => setState(() => _showTurnover = v))]));

  Widget _sourceLine() => SingleChildScrollView(scrollDirection: Axis.horizontal, child: Text('来源：VOL/amount/turnover=easy-tdx K线原始字段；MA=easy-tdx OHLCV close 展示层均线；BOLL/MACD/KDJ/RSI/DMI/ATR/WR/CCI/BIAS/OBV=对齐 easy_tdx.indicator 注册表名称/outputs/默认参数，由 App 根据 easy-tdx OHLCV 展示层计算；全部不参与 chan.py 结构计算。', style: const TextStyle(color: Colors.white54, fontSize: 11)));
  Widget _gap() => const SizedBox(width: 8);
  Widget _input(TextEditingController c, String label, double width) => SizedBox(width: width, height: 42, child: TextField(controller: c, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF151B26), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8))));
  Widget _drop(String label, String value, List<String> items, ValueChanged<String> onChanged, {double width = 86}) => SizedBox(width: width, height: 42, child: DropdownButtonFormField<String>(initialValue: value, dropdownColor: const Color(0xFF151B26), style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF151B26), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5)), items: [for (final item in items) DropdownMenuItem(value: item, child: Text(item))], onChanged: (v) { if (v != null) onChanged(v); }));
  Widget _chip(String label, bool selected, ValueChanged<bool> onSelected) => Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(label), selected: selected, onSelected: onSelected, backgroundColor: const Color(0xFF151B26), selectedColor: const Color(0xFF2962FF), checkmarkColor: Colors.white, labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w700)));
}

class _IndicatorCanvas extends StatelessWidget {
  final List<_Bar> bars;
  final int? crossIndex;
  final bool showMa, showBoll, showVol, showMacd, showAmount, showTurnover;
  final Map<String, bool> showExtra;
  final ValueChanged<int> onCross;
  const _IndicatorCanvas({required this.bars, required this.crossIndex, required this.showMa, required this.showBoll, required this.showVol, required this.showMacd, required this.showAmount, required this.showTurnover, required this.showExtra, required this.onCross});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) { final size = Size(constraints.maxWidth, constraints.maxHeight); return GestureDetector(behavior: HitTestBehavior.opaque, onTapDown: (d) => _setCross(d.localPosition, size), onPanUpdate: (d) => _setCross(d.localPosition, size), child: CustomPaint(size: Size.infinite, painter: _IndicatorPainter(bars, crossIndex, showMa, showBoll, showVol, showMacd, showAmount, showTurnover, showExtra))); });
  void _setCross(Offset p, Size s) { const left = 48.0, right = 68.0; final step = math.max(1.0, s.width - left - right) / math.max(1, bars.length); onCross(((p.dx - left) / step).floor().clamp(0, bars.length - 1).toInt()); }
}

class _IndicatorPainter extends CustomPainter {
  final List<_Bar> bars;
  final int? cross;
  final bool showMa, showBoll, showVol, showMacd, showAmount, showTurnover;
  final Map<String, bool> showExtra;
  _IndicatorPainter(this.bars, this.cross, this.showMa, this.showBoll, this.showVol, this.showMacd, this.showAmount, this.showTurnover, this.showExtra);

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const left = 48.0, right = 68.0, top = 24.0, bottom = 22.0;
    final extraShown = showExtra.entries.where((e) => e.value).map((e) => e.key).toList();
    final subCount = [showVol, showMacd, showAmount, showTurnover].where((e) => e).length + extraShown.length;
    final subH = subCount == 0 ? 0.0 : math.min(78.0, math.max(48.0, size.height * 0.14));
    final gap = subCount == 0 ? 0.0 : 8.0;
    final main = Rect.fromLTWH(left, top, math.max(1.0, size.width - left - right), math.max(80.0, size.height - top - bottom - subH * subCount - gap * subCount));
    final step = main.width / math.max(1, bars.length);
    double x(int i) => main.left + (i + 0.5) * step;
    final extras = <double>[];
    if (showMa) for (final b in bars) for (final v in b.ma.values) if (v != null) extras.add(v);
    if (showBoll) for (final b in bars) { if (b.boll?.upper != null) extras.add(b.boll!.upper!); if (b.boll?.lower != null) extras.add(b.boll!.lower!); }
    final minP = [bars.map((e) => e.low).reduce(math.min), ...extras].reduce(math.min);
    final maxP = [bars.map((e) => e.high).reduce(math.max), ...extras].reduce(math.max);
    final pad = math.max(maxP - minP, maxP.abs() * 0.01) * 0.08;
    double py(double v) => main.bottom - (v - minP + pad) / math.max(0.000001, maxP - minP + pad * 2) * main.height;
    _panel(canvas, main, 'PRICE'); _axis(canvas, main, minP - pad, maxP + pad); _candles(canvas, main, step, x, py); if (showBoll) _bollLines(canvas, x, py); if (showMa) _maLines(canvas, x, py);
    var y = main.bottom + gap;
    if (showVol) { _vol(canvas, Rect.fromLTWH(left, y, main.width, subH), step, x); y += subH + gap; }
    if (showMacd) { _macd(canvas, Rect.fromLTWH(left, y, main.width, subH), step, x); y += subH + gap; }
    for (final key in extraShown) { _extraPanel(canvas, Rect.fromLTWH(left, y, main.width, subH), x, key); y += subH + gap; }
    if (showAmount) { _linePanel(canvas, Rect.fromLTWH(left, y, main.width, subH), x, 'AMOUNT', (b) => b.amount); y += subH + gap; }
    if (showTurnover) _linePanel(canvas, Rect.fromLTWH(left, y, main.width, subH), x, 'TURNOVER', (b) => b.turnover);
    _text(canvas, bars.first.time.substring(0, math.min(10, bars.first.time.length)), Offset(main.left, main.bottom + 6), 10, Colors.white38); _text(canvas, bars.last.time.substring(0, math.min(10, bars.last.time.length)), Offset(main.right - 66, main.bottom + 6), 10, Colors.white38); _text(canvas, [if (showMa) 'MA', if (showBoll) 'BOLL', if (showVol) 'VOL', if (showMacd) 'MACD', ...extraShown, if (showAmount) 'amount', if (showTurnover) 'turnover'].join('  '), Offset(main.left + 64, main.top + 4), 10, Colors.white54); _cross(canvas, size, main, x, py);
  }

  void _panel(Canvas c, Rect r, String title) { c.drawRect(r, Paint()..color = const Color(0xFF0D1320)); c.drawRect(r, Paint()..color = Colors.white.withValues(alpha: 0.08)..style = PaintingStyle.stroke); final p = Paint()..color = Colors.white.withValues(alpha: 0.08)..strokeWidth = 0.7; for (var i = 1; i < 4; i++) c.drawLine(Offset(r.left, r.top + r.height * i / 4), Offset(r.right, r.top + r.height * i / 4), p); _text(c, title, Offset(r.left + 6, r.top + 4), 10, Colors.white54); }
  void _axis(Canvas c, Rect r, double min, double max) { for (var i = 0; i <= 4; i++) _text(c, (max - (max - min) * i / 4).toStringAsFixed(2), Offset(r.right + 5, r.top + r.height * i / 4 - 6), 10, Colors.white54); }
  void _candles(Canvas c, Rect r, double step, double Function(int) x, double Function(double) py) { final up = Paint()..color = const Color(0xFF26A69A); final down = Paint()..color = const Color(0xFFEF5350); final wick = Paint()..strokeWidth = math.max(0.8, step * 0.08); final w = math.max(1.0, math.min(step * 0.66, step - 1)); for (var i = 0; i < bars.length; i++) { final b = bars[i], p = b.close >= b.open ? up : down; final cx = x(i); wick.color = p.color; c.drawLine(Offset(cx, py(b.high)), Offset(cx, py(b.low)), wick); final o = py(b.open), cl = py(b.close); c.drawRect(Rect.fromLTRB(cx - w / 2, math.min(o, cl), cx + w / 2, math.max(math.min(o, cl) + 1, math.max(o, cl))), p); } }
  void _maLines(Canvas c, double Function(int) x, double Function(double) y) { final colors = {5: const Color(0xFFFFD54F), 10: const Color(0xFF64B5F6), 20: const Color(0xFFBA68C8), 60: const Color(0xFFFF8A65)}; for (final p in const [5, 10, 20, 60]) _series(c, x, y, (b) => b.ma[p], colors[p] ?? Colors.white, 1.1); }
  void _bollLines(Canvas c, double Function(int) x, double Function(double) y) { _series(c, x, y, (b) => b.boll?.upper, const Color(0xFF90CAF9), 0.9); _series(c, x, y, (b) => b.boll?.mid, Colors.white54, 0.8); _series(c, x, y, (b) => b.boll?.lower, const Color(0xFF90CAF9), 0.9); }
  void _vol(Canvas c, Rect r, double step, double Function(int) x) { _panel(c, r, 'VOL'); final maxV = bars.map((e) => e.volume ?? 0.0).fold<double>(0.0, math.max); if (maxV <= 0) return; final w = math.max(1.0, math.min(step * 0.62, step - 1)); for (var i = 0; i < bars.length; i++) { final b = bars[i]; final h = (b.volume ?? 0.0) / maxV * (r.height - 18); c.drawRect(Rect.fromLTRB(x(i) - w / 2, r.bottom - h, x(i) + w / 2, r.bottom), Paint()..color = (b.close >= b.open ? const Color(0xFF26A69A) : const Color(0xFFEF5350)).withValues(alpha: 0.72)); } _text(c, _compact(maxV), Offset(r.right + 5, r.top + 2), 10, Colors.white38); }
  void _macd(Canvas c, Rect r, double step, double Function(int) x) { _panel(c, r, 'MACD'); final vals = <double>[]; for (final b in bars) { if (b.macd?.dif != null) vals.add(b.macd!.dif!); if (b.macd?.dea != null) vals.add(b.macd!.dea!); if (b.macd?.hist != null) vals.add(b.macd!.hist!); } if (vals.isEmpty) return; final maxAbs = math.max(0.0000001, vals.map((e) => e.abs()).reduce(math.max)); final zero = r.top + r.height / 2; double y(double v) => zero - v / maxAbs * (r.height * 0.42); c.drawLine(Offset(r.left, zero), Offset(r.right, zero), Paint()..color = Colors.white.withValues(alpha: 0.16)); final w = math.max(1.0, math.min(step * 0.58, step - 1)); for (var i = 0; i < bars.length; i++) { final h = bars[i].macd?.hist; if (h == null) continue; final yy = y(h); c.drawRect(Rect.fromLTRB(x(i) - w / 2, math.min(zero, yy), x(i) + w / 2, math.max(zero, yy)), Paint()..color = (h >= 0 ? const Color(0xFF26A69A) : const Color(0xFFEF5350)).withValues(alpha: 0.78)); } _series(c, x, y, (b) => b.macd?.dif, const Color(0xFFFFD54F), 1.0); _series(c, x, y, (b) => b.macd?.dea, const Color(0xFF64B5F6), 1.0); }
  void _extraPanel(Canvas c, Rect r, double Function(int) x, String key) { final names = bars.expand((b) => b.extra[key]?.keys ?? const Iterable<String>.empty()).toSet().toList(); _panel(c, r, key); if (names.isEmpty) { _text(c, '--', Offset(r.center.dx - 8, r.center.dy - 7), 11, Colors.white38); return; } final vals = [for (final b in bars) for (final n in names) if (b.extra[key]?[n] != null) b.extra[key]![n]!]; if (vals.isEmpty) return; final minV = vals.reduce(math.min), maxV = vals.reduce(math.max), range = math.max(0.0000001, maxV - minV); double y(double v) => r.bottom - (v - minV) / range * (r.height - 18) - 4; final colors = [const Color(0xFFFFD54F), const Color(0xFF64B5F6), const Color(0xFFBA68C8), const Color(0xFFFF8A65), const Color(0xFF81C784)]; for (var i = 0; i < names.length; i++) _series(c, x, y, (b) => b.extra[key]?[names[i]], colors[i % colors.length], 1.0); _text(c, names.join('/'), Offset(r.left + 44, r.top + 4), 10, Colors.white54); }
  void _linePanel(Canvas c, Rect r, double Function(int) x, String title, double? Function(_Bar) val) { _panel(c, r, title); final vals = bars.map(val).whereType<double>().toList(); if (vals.isEmpty) { _text(c, '--', Offset(r.center.dx - 8, r.center.dy - 7), 11, Colors.white38); return; } final minV = vals.reduce(math.min), maxV = vals.reduce(math.max), range = math.max(0.0000001, maxV - minV); double y(double v) => r.bottom - (v - minV) / range * (r.height - 18) - 4; _series(c, x, y, val, const Color(0xFF81C784), 1.0); _text(c, _compact(maxV), Offset(r.right + 5, r.top + 2), 10, Colors.white38); }
  void _series(Canvas c, double Function(int) x, double Function(double) y, double? Function(_Bar) val, Color color, double width) { final path = Path(); var started = false; for (var i = 0; i < bars.length; i++) { final v = val(bars[i]); if (v == null) { started = false; continue; } final p = Offset(x(i), y(v)); if (!started) { path.moveTo(p.dx, p.dy); started = true; } else { path.lineTo(p.dx, p.dy); } } c.drawPath(path, Paint()..color = color..strokeWidth = width..style = PaintingStyle.stroke); }
  void _cross(Canvas c, Size s, Rect main, double Function(int) x, double Function(double) py) { final i = cross; if (i == null || i < 0 || i >= bars.length) return; final b = bars[i], cx = x(i); c.drawLine(Offset(cx, 0), Offset(cx, s.height), Paint()..color = Colors.white.withValues(alpha: 0.22)); c.drawLine(Offset(main.left, py(b.close)), Offset(main.right, py(b.close)), Paint()..color = Colors.white.withValues(alpha: 0.16)); final lines = <String>[b.time, 'O:${b.open.toStringAsFixed(2)} H:${b.high.toStringAsFixed(2)} L:${b.low.toStringAsFixed(2)} C:${b.close.toStringAsFixed(2)}', if (showMa) 'MA5:${_fmt(b.ma[5])} MA10:${_fmt(b.ma[10])} MA20:${_fmt(b.ma[20])} MA60:${_fmt(b.ma[60])}', if (showBoll) 'BOLL U:${_fmt(b.boll?.upper)} M:${_fmt(b.boll?.mid)} L:${_fmt(b.boll?.lower)}', if (showVol) 'VOL:${_compact(b.volume)}', if (showMacd) 'MACD DIF:${_fmt(b.macd?.dif)} DEA:${_fmt(b.macd?.dea)} HIST:${_fmt(b.macd?.hist)}', for (final e in showExtra.entries) if (e.value) '${e.key} ${_fmtMap(b.extra[e.key])}', if (showAmount) 'amount:${_compact(b.amount)}', if (showTurnover) 'turnover:${_fmt(b.turnover)}']; const boxW = 360.0; final boxH = 18.0 + lines.length * 16.0; final rawLeft = cx + boxW + 16 < s.width ? cx + 10 : cx - boxW - 10; final left = rawLeft.clamp(4.0, math.max(4.0, s.width - boxW - 4)).toDouble(); final r = Rect.fromLTWH(left, main.top + 8, boxW, boxH); c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), Paint()..color = const Color(0xE6111722)); c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), Paint()..color = const Color(0xFF2962FF).withValues(alpha: 0.34)..style = PaintingStyle.stroke); for (var n = 0; n < lines.length; n++) _text(c, lines[n], Offset(r.left + 8, r.top + 8 + n * 16), 11, n == 0 ? const Color(0xFF8AB4FF) : Colors.white70); }
  String _fmtMap(Map<String, double?>? values) => values == null || values.isEmpty ? '--' : values.entries.map((e) => '${e.key}:${_fmt(e.value)}').join(' ');
  String _fmt(double? v) => v == null ? '--' : v.toStringAsFixed(v.abs() >= 100 ? 2 : 3);
  String _compact(double? v) { if (v == null) return '--'; final a = v.abs(); if (a >= 100000000) return '${(v / 100000000).toStringAsFixed(2)}亿'; if (a >= 10000) return '${(v / 10000).toStringAsFixed(2)}万'; return v.toStringAsFixed(2); }
  void _text(Canvas c, String text, Offset o, double size, Color color) { final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)), textDirection: TextDirection.ltr, maxLines: 1)..layout(maxWidth: 520); tp.paint(c, o); }
  @override
  bool shouldRepaint(covariant _IndicatorPainter old) => old.bars != bars || old.cross != cross || old.showMa != showMa || old.showBoll != showBoll || old.showVol != showVol || old.showMacd != showMacd || old.showAmount != showAmount || old.showTurnover != showTurnover || old.showExtra != showExtra;
}

class _Bar {
  final int rawIndex;
  final String time;
  final double open, high, low, close;
  final double? volume, amount, turnover;
  final Map<int, double?> ma;
  final _Boll? boll;
  final _Macd? macd;
  final Map<String, Map<String, double?>> extra;
  const _Bar({required this.rawIndex, required this.time, required this.open, required this.high, required this.low, required this.close, required this.volume, required this.amount, required this.turnover, required this.ma, required this.boll, required this.macd, required this.extra});
  _Bar copyWith({Map<int, double?>? ma, _Boll? boll, _Macd? macd, Map<String, Map<String, double?>>? extra}) => _Bar(rawIndex: rawIndex, time: time, open: open, high: high, low: low, close: close, volume: volume, amount: amount, turnover: turnover, ma: ma ?? this.ma, boll: boll ?? this.boll, macd: macd ?? this.macd, extra: extra ?? this.extra);
}

class _Boll { final double? upper, mid, lower; const _Boll(this.upper, this.mid, this.lower); }
class _Macd { final double? dif, dea, hist; const _Macd(this.dif, this.dea, this.hist); }
