import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/chan_snapshot.dart';
import '../../core/runtime/runtime_path.dart';
import '../../data/python_multi_level_chan_analysis_source.dart';
import '../widgets/recursive_seg_origin_kline_chart.dart';

class LevelPromoterPage extends StatefulWidget {
  const LevelPromoterPage({super.key});

  @override
  State<LevelPromoterPage> createState() => _LevelPromoterPageState();
}

class _LevelPromoterPageState extends State<LevelPromoterPage> {
  final _code = TextEditingController(text: '000001');
  final _market = TextEditingController(text: 'SZ');
  final _levels = TextEditingController(text: 'DAILY,MIN30,MIN5');
  final _start = TextEditingController(text: '2022-01-01');
  final _end = TextEditingController(text: '2025-12-31');
  final _count = TextEditingController(text: '900');
  final _maxLayer = TextEditingController(text: '8');

  PythonMultiLevelChanAnalysis? _analysis;
  String _activeLevel = 'DAILY';
  String _status = '级别推进器就绪';
  bool _loading = false;
  int _windowSize = 120;
  double _priceScale = 1.0;
  int? _viewEndIndex;
  int? _crosshairIndex;

  @override
  void dispose() {
    for (final c in [_code, _market, _levels, _start, _end, _count, _maxLayer]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    final code = _code.text.trim();
    final levelList = _levels.text.replaceAll('，', ',').split(',').map((e) => e.trim().toUpperCase()).where((e) => e.isNotEmpty).toList();
    final n = int.tryParse(_maxLayer.text.trim()) ?? 4;
    if (code.isEmpty || levelList.isEmpty || n < 2) {
      _show('代码、级别不能为空，N 必须 >= 2');
      return;
    }
    setState(() {
      _loading = true;
      _status = '正在推进到 $n 段...';
    });
    final source = PythonMultiLevelChanAnalysisSource(baseUrl: 'app-managed bundled Python');
    try {
      final result = await source.analyzeMulti(
        mode: 'once',
        market: _market.text.trim().toUpperCase().isEmpty ? _inferMarket(code) : _market.text.trim().toUpperCase(),
        code: code,
        levels: levelList,
        adjust: 'QFQ',
        mainLevel: levelList.first,
        clockLevel: levelList.first,
        count: int.tryParse(_count.text.trim()) ?? 900,
        startDate: _date(_start.text),
        endDate: _date(_end.text),
        runtimePath: RuntimePathController.current,
        config: {
          'bi_algo': 'normal',
          'seg_algo': 'chan',
          'zs_algo': 'normal',
          'level_promoter_max_level': n,
          'recursive_seg_max_level': n,
          'seg_recursive_max_level': n,
        },
      );
      if (!mounted) return;
      setState(() {
        _analysis = result;
        _activeLevel = result.snapshot.safeActiveLevel;
        _viewEndIndex = null;
        _crosshairIndex = null;
        _status = _summary(result.snapshot.of(_activeLevel));
      });
    } catch (e) {
      if (mounted) setState(() => _status = '级别推进失败: $e');
    } finally {
      source.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _analysis?.snapshot.of(_activeLevel);
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(52, 10, 10, 10),
          child: Row(children: [
            SizedBox(width: 430, child: _left(snapshot)),
            const SizedBox(width: 10),
            Expanded(child: _chart(snapshot)),
          ]),
        ),
      ),
    );
  }

  Widget _left(ChanSnapshot? snapshot) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _box('级别推进器', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            _input(_code, '代码', 110),
            _input(_market, '市场', 70),
            _input(_levels, '级别', 190),
            _input(_start, '开始', 120),
            _input(_end, '结束', 120),
            _input(_count, 'count', 80),
            _input(_maxLayer, 'N段', 80),
            FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.account_tree), label: Text(_loading ? '推进中' : '推进')),
          ]),
          const SizedBox(height: 8),
          Text(_status, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]), expand: false),
        const SizedBox(height: 8),
        _tabs(),
        const SizedBox(height: 8),
        Expanded(child: _box('segN_bsp 验收证据', _evidence(snapshot), trailing: OutlinedButton.icon(onPressed: snapshot == null ? null : () => _copy(_evidenceText(snapshot)), icon: const Icon(Icons.copy, size: 16), label: const Text('复制证据')))),
      ]);

  Widget _tabs() {
    final levels = _analysis?.snapshot.levels ?? const <String>[];
    return Wrap(spacing: 8, children: [
      for (final level in levels) ChoiceChip(label: Text(level), selected: level == _activeLevel, onSelected: (_) => setState(() => _activeLevel = level)),
    ]);
  }

  Widget _evidence(ChanSnapshot? snapshot) => SingleChildScrollView(
        child: SelectableText(snapshot == null ? '暂无证据' : _evidenceText(snapshot), style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.35)),
      );

  Widget _chart(ChanSnapshot? snapshot) => DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xFF131722), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: snapshot == null || snapshot.rawBars.isEmpty
              ? const Center(child: Text('加载后显示 2段、3段、4段...N段和 segN_bsp 标记', style: TextStyle(color: Colors.white60)))
              : RecursiveSegOriginKlineChart(
                  snapshot: snapshot,
                  showFx: true,
                  showBi: true,
                  showSeg: true,
                  showZs: true,
                  showBiBsp: true,
                  showSegBsp: true,
                  showEasyTdxIndicators: true,
                  drawingStorageKey: 'level_promoter_${_code.text}_$_activeLevel',
                  symbolLabel: '${_code.text} $_activeLevel',
                  minRecursiveSegLayer: 2,
                  maxRecursiveSegLayer: int.tryParse(_maxLayer.text.trim()) ?? 4,
                  showRecursiveSegLayers: true,
                  showRecursiveSegBsp: true,
                  windowSize: _windowSize,
                  priceScale: _priceScale,
                  viewEndIndex: _viewEndIndex,
                  crosshairIndex: _crosshairIndex,
                  onCrosshairChanged: (v) => setState(() => _crosshairIndex = v),
                  onPanBars: _pan,
                  onWindowSizeChanged: (v) => setState(() => _windowSize = v),
                  onPriceScaleChanged: (v) => setState(() => _priceScale = v),
                ),
        ),
      );

  void _pan(int bars) {
    final snapshot = _analysis?.snapshot.of(_activeLevel);
    if (snapshot == null || snapshot.rawBars.isEmpty || bars == 0) return;
    final maxEnd = snapshot.rawBars.length - 1;
    final current = _viewEndIndex ?? maxEnd;
    final next = (current + bars).clamp(0, maxEnd).toInt();
    if (next != current) setState(() => _viewEndIndex = next);
  }

  Widget _box(String title, Widget child, {Widget? trailing, bool expand = true}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF131722), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))), if (trailing != null) trailing]),
          const SizedBox(height: 8),
          if (expand) Expanded(child: child) else child,
        ]),
      );

  Widget _input(TextEditingController controller, String label, double width) => SizedBox(width: width, child: TextField(controller: controller, enabled: !_loading, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: label, isDense: true, filled: true, fillColor: const Color(0xFF1C2330), border: const OutlineInputBorder())));

  String _summary(ChanSnapshot? snapshot) {
    if (snapshot == null) return '无数据';
    final n = int.tryParse(_maxLayer.text.trim()) ?? 4;
    return [for (var i = 2; i <= n; i++) 'L$i:${snapshot.recursiveSegLayers[i]?.length ?? 0}'].join(' | ');
  }

  String _evidenceText(ChanSnapshot snapshot) {
    final n = int.tryParse(_maxLayer.text.trim()) ?? 4;
    return [
      'manual level promoter evidence',
      'entry_name: 级别推进器',
      'code: ${_code.text.trim()}',
      'active_level: $_activeLevel',
      'max_requested_layer: $n',
      'source_policy: backend a_* adapter only; no chan.py source pollution',
      'segN_bsp_policy: independent fields seg2_bsp..segN_bsp; native bsp unchanged',
      for (var i = 2; i <= n; i++) 'layer_$i: seg_count=${snapshot.recursiveSegLayers[i]?.length ?? 0}; seg${i}_bsp_count=${snapshot.recursiveSegBsps[i]?.length ?? snapshot.recursiveSegLayers[i]?.length ?? 0}',
    ].join('\n');
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _show('证据已复制');
  }

  DateTime? _date(String text) => DateTime.tryParse(text.trim().replaceAll('/', '-'));
  static String _inferMarket(String code) => code.startsWith(RegExp(r'[569]')) ? 'SH' : 'SZ';
  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
