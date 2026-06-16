import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/analysis/chip_distribution.dart';
import '../../core/analysis/chip_online_replay_adapter.dart';
import '../../core/models/chan_snapshot.dart';
import '../../core/models/multi_level_chan_snapshot.dart';
import '../../core/runtime/runtime_path.dart';
import '../../data/python_multi_level_chan_analysis_source.dart';

class ChipDistributionPage extends StatefulWidget {
  const ChipDistributionPage({super.key});

  @override
  State<ChipDistributionPage> createState() => _ChipDistributionPageState();
}

class _ChipDistributionPageState extends State<ChipDistributionPage> {
  final ChipDistributionEngine _engine = const ChipDistributionEngine();
  final _backendUrlController =
          TextEditingController(text: 'app-managed bundled Python'),
      _symbolController = TextEditingController(text: '600340'),
      _marketController = TextEditingController(text: 'SH'),
      _levelsController = TextEditingController(text: 'DAILY,MIN30,MIN5'),
      _startController = TextEditingController(text: '2026-01-01'),
      _endController = TextEditingController(
          text: DateTime.now()
              .subtract(const Duration(days: 2))
              .toIso8601String()
              .split('T')
              .first);

  PythonMultiLevelChanAnalysis? _analysis;
  String _mode = 'step';
  String _activeLevel = 'DAILY';
  String _status = '未加载在线复盘数据';
  bool _loading = false;
  int _frameIndex = 0;
  int _binCount = 80;
  int? _crosshairIndex;
  int? _viewEndIndex;
  double _ageDecay = 0.0;

  @override
  void dispose() {
    _backendUrlController.dispose();
    _symbolController.dispose();
    _marketController.dispose();
    _levelsController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  MultiLevelChanSnapshot? get _currentSnapshot {
    final a = _analysis;
    if (a == null) return null;
    if (_mode == 'step' && a.frames.isNotEmpty) {
      return a.frames[_safeFrameIndex];
    }
    return a.snapshot;
  }

  int get _safeFrameIndex {
    final count = _analysis?.frames.length ?? 0;
    if (count <= 0) return 0;
    return _frameIndex.clamp(0, count - 1).toInt();
  }

  List<String> get _loadedLevels {
    final levels = _currentSnapshot?.levels ?? _analysis?.snapshot.levels ?? const <String>[];
    final out = [
      for (final level in levels)
        if (level.trim().isNotEmpty) level.trim().toUpperCase(),
    ];
    if (out.isNotEmpty) return out;
    return _parseLevels();
  }

  ChanSnapshot? get _activeSnapshot {
    final c = _currentSnapshot;
    if (c == null) return null;
    final level = c.snapshots.containsKey(_activeLevel) ? _activeLevel : c.safeActiveLevel;
    return c.of(level);
  }

  List<ChipDistributionBar> get _onlineBars => ChipOnlineReplayAdapter.fromSnapshot(_activeSnapshot);

  int get _targetIndex {
    final bars = _onlineBars;
    return ChipOnlineReplayAdapter.resolveTargetIndex(
      total: bars.length,
      isStepMode: _mode == 'step',
      stepIndex: bars.isEmpty ? 0 : bars.length - 1,
      crosshairIndex: _crosshairIndex,
      viewEndIndex: _viewEndIndex,
    );
  }

  String get _targetPolicy {
    if (_mode == 'step') return 'step 当前K';
    if (_crosshairIndex != null) return '十字线K';
    if (_viewEndIndex != null) return '视觉最右K';
    return '最后一根K';
  }

  ChipDistributionResult get _result => _engine.calculate(
        _onlineBars,
        targetIndex: _targetIndex,
        options: ChipDistributionOptions(
          binCount: _binCount,
          lookback: 1000000,
          ageDecay: _ageDecay,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bars = _onlineBars;
    final result = _result;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(context),
              const SizedBox(height: 12),
              _buildOnlineControlCard(bars),
              const SizedBox(height: 12),
              _buildMetricCard(result, bars),
              const SizedBox(height: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF131722),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: result.isEmpty
                        ? const Center(
                            child: Text('载入在线 analyze_multi 数据后显示筹码分布',
                                style: TextStyle(color: Colors.white54)))
                        : CustomPaint(
                            painter: _ChipDistributionPainter(result),
                            child: const SizedBox.expand(),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildPolicyText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.stacked_bar_chart, color: Color(0xFF8AB4FF)),
        const SizedBox(width: 8),
        Text(
          '筹码分布 - 在线 analyze_multi',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const Spacer(),
        const Tooltip(
          message: '只使用在线 analyze_multi 返回的 K 线；不读取离线分笔文件。目标K优先级：step当前K > 十字线K > 视觉最右K。',
          child: Icon(Icons.info_outline, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildOnlineControlCard(List<ChipDistributionBar> bars) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              _input(_backendUrlController, 'backend', width: 210, enabled: false),
              _input(_symbolController, 'symbol', width: 96),
              _input(_marketController, 'market', width: 78),
              _input(_levelsController, 'levels', width: 170),
              _input(_startController, 'start', width: 116),
              _input(_endController, 'end', width: 116),
              _modeChip('once'),
              _modeChip('step'),
              FilledButton.icon(
                onPressed: _loading ? null : _loadOnlineReplay,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_download, size: 16),
                label: const Text('载入在线数据'),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              for (final level in _loadedLevels) _levelChip(level),
              _MetricChip(label: '状态', value: _status),
            ]),
            if (_mode == 'step' && (_analysis?.frames.isNotEmpty == true))
              _LabeledSlider(
                label: 'step帧',
                value: _safeFrameIndex.toDouble(),
                min: 0,
                max: ((_analysis?.frames.length ?? 1) - 1).toDouble(),
                divisions: math.max(1, (_analysis?.frames.length ?? 1) - 1),
                display: '${_safeFrameIndex + 1}/${_analysis?.frames.length ?? 0}',
                onChanged: (v) => setState(() {
                  _frameIndex = v.round();
                  _crosshairIndex = null;
                  _viewEndIndex = null;
                }),
              ),
            if (_mode != 'step' && bars.isNotEmpty) ...[
              _LabeledSlider(
                label: '十字线K',
                value: (_crosshairIndex ?? _targetIndex).toDouble(),
                min: 0,
                max: (bars.length - 1).toDouble(),
                divisions: math.max(1, bars.length - 1),
                display: _crosshairIndex == null ? '未激活' : '${_crosshairIndex! + 1}',
                onChanged: (v) => setState(() => _crosshairIndex = v.round()),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _crosshairIndex = null),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('关闭十字线，改用视觉最右K'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(ChipDistributionResult result, List<ChipDistributionBar> bars) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                _MetricChip(label: '目标来源', value: _targetPolicy),
                _MetricChip(label: '目标K线', value: bars.isEmpty ? '-' : '${result.targetIndex + 1}/${bars.length}'),
                _MetricChip(label: '现价', value: result.currentPrice.toStringAsFixed(2)),
                _MetricChip(label: '平均成本', value: result.averageCost.toStringAsFixed(2)),
                _MetricChip(label: '峰值价位', value: result.pocPrice.toStringAsFixed(2)),
                _MetricChip(label: '获利筹码', value: '${(result.profitRatio * 100).toStringAsFixed(1)}%'),
                _MetricChip(label: '卖侧筹码', value: result.sellWeight.toStringAsFixed(0)),
                _MetricChip(label: '买侧筹码', value: result.buyWeight.toStringAsFixed(0)),
              ],
            ),
            _LabeledSlider(
              label: '价格桶数',
              value: _binCount.toDouble(),
              min: 24,
              max: 160,
              divisions: 136,
              display: '$_binCount',
              onChanged: (v) => setState(() => _binCount = v.round()),
            ),
            _LabeledSlider(
              label: '旧筹码衰减',
              value: _ageDecay,
              min: 0,
              max: 0.03,
              divisions: 30,
              display: _ageDecay.toStringAsFixed(3),
              onChanged: (v) => setState(() => _ageDecay = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyText() {
    return const Text(
      '在线阶段：只使用 analyze_multi 返回的 bars 累计“首根 -> 当前K”；不接入离线 tick 文件。若后端返回 chip_tick_bins(p/s/b/w)，同一计算引擎可直接消费。',
      style: TextStyle(color: Colors.white54, fontSize: 12),
    );
  }

  Future<void> _loadOnlineReplay() async {
    if (_loading) return;
    final levels = _parseLevels();
    if (levels.length < 2) {
      _showMessage('至少输入两个级别，例如 DAILY,MIN30,MIN5');
      return;
    }
    final start = DateTime.tryParse(_startController.text.trim());
    final end = DateTime.tryParse(_endController.text.trim());
    if (start == null || end == null || start.isAfter(end)) {
      _showMessage('日期无效：请使用 YYYY-MM-DD，且 start <= end');
      return;
    }
    setState(() {
      _loading = true;
      _status = 'loading online analyze_multi ${_mode.toUpperCase()}...';
    });
    final source = PythonMultiLevelChanAnalysisSource(baseUrl: _backendUrlController.text.trim());
    try {
      final a = await source.analyzeMulti(
        mode: _mode,
        market: _marketController.text.trim().toUpperCase(),
        code: _symbolController.text.trim(),
        levels: levels,
        adjust: 'QFQ',
        mainLevel: levels.first,
        clockLevel: levels.first,
        startDate: start,
        endDate: end,
        runtimePath: RuntimePathController.current,
        config: const <String, dynamic>{
          'bi_algo': 'normal',
          'seg_algo': 'chan',
          'zs_algo': 'normal',
        },
      );
      if (!mounted) return;
      final snap = _mode == 'step' && a.frames.isNotEmpty ? a.frames.first : a.snapshot;
      setState(() {
        _analysis = a;
        _frameIndex = 0;
        _activeLevel = snap.safeActiveLevel;
        _crosshairIndex = null;
        _viewEndIndex = null;
        _status = 'loaded online bars:${_onlineBars.length} frames:${a.frames.length} active:$_activeLevel';
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'load failed: $e');
    } finally {
      source.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _parseLevels() => [
        for (final item in _levelsController.text.split(','))
          if (item.trim().isNotEmpty) item.trim().toUpperCase(),
      ];

  Widget _input(TextEditingController c, String label, {double width = 120, bool enabled = true}) => SizedBox(
        width: width,
        height: 42,
        child: TextField(
          controller: c,
          enabled: enabled,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          decoration: InputDecoration(labelText: label, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        ),
      );

  Widget _modeChip(String mode) {
    final selected = _mode == mode;
    return ChoiceChip(
      label: Text(mode),
      selected: selected,
      onSelected: _loading
          ? null
          : (_) => setState(() {
                _mode = mode;
                _frameIndex = 0;
                _crosshairIndex = null;
                _viewEndIndex = null;
              }),
    );
  }

  Widget _levelChip(String level) {
    final selected = _activeLevel == level;
    return ChoiceChip(
      label: Text(level),
      selected: selected,
      onSelected: (_) => setState(() {
        _activeLevel = level;
        _crosshairIndex = null;
        _viewEndIndex = null;
      }),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0D10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Text('$label: $value', style: const TextStyle(color: Colors.white70, fontSize: 12)),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String display;
  final ValueChanged<double> onChanged;

  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 88,
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 70,
          child: Text(display, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      ],
    );
  }
}

class _ChipDistributionPainter extends CustomPainter {
  final ChipDistributionResult result;

  const _ChipDistributionPainter(this.result);

  @override
  void paint(Canvas canvas, Size size) {
    final bins = result.bins.where((b) => b.weight > 0).toList(growable: false);
    if (bins.isEmpty || size.width <= 0 || size.height <= 0) return;

    final minPrice = result.bins.first.price;
    final maxPrice = result.bins.last.price;
    final maxRatio = bins.map((b) => b.ratio).fold<double>(0, math.max);
    final chartLeft = 72.0;
    final chartRight = size.width - 18.0;
    final chartTop = 14.0;
    final chartBottom = size.height - 24.0;
    final chartWidth = math.max(1.0, chartRight - chartLeft);
    final chartHeight = math.max(1.0, chartBottom - chartTop);

    final axisPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(Offset(chartLeft, chartTop), Offset(chartLeft, chartBottom), axisPaint);
    canvas.drawLine(Offset(chartLeft, chartBottom), Offset(chartRight, chartBottom), axisPaint);

    final sellPaint = Paint()..color = const Color(0xFF26A69A).withOpacity(0.62);
    final buyPaint = Paint()..color = const Color(0xFFEF5350).withOpacity(0.62);
    final pocPaint = Paint()..color = const Color(0xFFFFB300).withOpacity(0.90);
    final currentPaint = Paint()
      ..color = const Color(0xFF66BB6A)
      ..strokeWidth = 1.4;

    final barGap = chartHeight / result.bins.length;
    for (var i = 0; i < result.bins.length; i++) {
      final bin = result.bins[i];
      final y = chartBottom - (i + 0.5) * barGap;
      final totalWidth = maxRatio <= 0 ? 0.0 : chartWidth * (bin.ratio / maxRatio);
      final sellWidth = bin.weight <= 0 ? 0.0 : totalWidth * (bin.sellWeight / bin.weight);
      final buyWidth = math.max(0.0, totalWidth - sellWidth);
      final h = math.max(1.0, barGap * 0.68);
      final top = y - math.max(1.0, barGap * 0.34);
      final isPoc = (bin.price - result.pocPrice).abs() <= (maxPrice - minPrice) / result.bins.length;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(chartLeft, top, sellWidth, h), const Radius.circular(2)),
        isPoc ? pocPaint : sellPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(chartLeft + sellWidth, top, buyWidth, h), const Radius.circular(2)),
        isPoc ? pocPaint : buyPaint,
      );
    }

    final currentY = _priceToY(result.currentPrice, minPrice, maxPrice, chartTop, chartBottom);
    canvas.drawLine(Offset(chartLeft, currentY), Offset(chartRight, currentY), currentPaint);
    _drawText(canvas, '现价 ${result.currentPrice.toStringAsFixed(2)}', Offset(chartRight - 94, currentY - 18), const Color(0xFF66BB6A));
    _drawText(canvas, '价格', Offset(18, chartTop), Colors.white54);
    _drawText(canvas, maxPrice.toStringAsFixed(2), Offset(12, chartTop + 4), Colors.white70);
    _drawText(canvas, minPrice.toStringAsFixed(2), Offset(12, chartBottom - 18), Colors.white70);
    _drawText(canvas, '卖侧/买侧筹码权重', Offset(chartLeft, size.height - 18), Colors.white54);
  }

  double _priceToY(double price, double minPrice, double maxPrice, double top, double bottom) {
    if ((maxPrice - minPrice).abs() < 1e-9) return (top + bottom) / 2;
    final t = ((price - minPrice) / (maxPrice - minPrice)).clamp(0.0, 1.0).toDouble();
    return bottom - (bottom - top) * t;
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 180);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ChipDistributionPainter oldDelegate) => oldDelegate.result != result;
}
