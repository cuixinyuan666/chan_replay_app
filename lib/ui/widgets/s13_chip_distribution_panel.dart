import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/analysis/chip_distribution.dart';
import '../../core/models/chan_snapshot.dart';
import '../../core/models/raw_bar.dart';

/// S13 单股多级别复盘内嵌筹码 overlay。
///
/// 设计目标：
/// - 懒加载：只有用户打开筹码图层后才计算；关闭时不计算、不绘制；
/// - 数据源：使用当前 active level 的 easy-tdx K 线成交量；
/// - 默认区间：该级别首根可用 K 线到当前显示截止 K；
/// - 精确桶：若后端 rawBars 携带 chip_tick_bins / chipTickBins，则优先使用 p/s/b/w；
/// - 兜底：没有逐价桶时使用 OHLCV 三角分摊；
/// - 交互：IgnorePointer 不拦截十字线、缩放、拖拽、画线工具。
class S13ChipDistributionPanel extends StatefulWidget {
  static const double _topPad = 32;
  static const double _bottomPad = 28;
  static const double _leftPad = 4;
  static const double _rightPad = 58;
  static const double _subPanelHeight = 74;
  static const double _panelGap = 6;

  final ChanSnapshot? snapshot;
  final bool enabled;
  final bool isStepMode;
  final int stepIndex;
  final int? crosshairIndex;
  final int? visibleRightIndex;
  final int binCount;
  final double ageDecay;
  final int windowSize;
  final double priceScale;
  final bool showEasyTdxIndicators;
  final int easyTdxSubPanelCount;
  final VoidCallback? onClose;

  const S13ChipDistributionPanel({
    super.key,
    required this.snapshot,
    required this.enabled,
    required this.isStepMode,
    required this.stepIndex,
    required this.crosshairIndex,
    required this.visibleRightIndex,
    this.binCount = 80,
    this.ageDecay = 0.0,
    this.windowSize = 90,
    this.priceScale = 1.0,
    this.showEasyTdxIndicators = false,
    this.easyTdxSubPanelCount = 0,
    this.onClose,
  });

  @override
  State<S13ChipDistributionPanel> createState() => _S13ChipDistributionPanelState();
}

class _S13ChipDistributionPanelState extends State<S13ChipDistributionPanel> {
  String? _loadedKey;
  bool _loading = false;
  Object? _loadError;
  List<ChipDistributionBar> _loadedBars = const <ChipDistributionBar>[];
  _ChipLoadInfo? _loadInfo;
  final Set<String> _announcedKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _scheduleLazyLoad();
  }

  @override
  void didUpdateWidget(covariant S13ChipDistributionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleLazyLoad();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    _scheduleLazyLoad();

    final rawBars = widget.snapshot?.rawBars ?? const <RawBar>[];
    final result = _loadedBars.isEmpty
        ? _emptyResult()
        : const ChipDistributionEngine().calculate(
            _loadedBars,
            targetIndex: _loadedBars.length - 1,
            options: ChipDistributionOptions(
              binCount: widget.binCount,
              lookback: 1000000,
              ageDecay: widget.ageDecay,
            ),
          );

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _ChipOverlayPainter(
            rawBars: rawBars,
            result: result,
            exactBarCount: _loadedBars.where((bar) => bar.hasExactChipBins).length,
            targetPolicy: _targetPolicy(),
            windowSize: widget.windowSize,
            priceScale: widget.priceScale,
            viewEndIndex: widget.visibleRightIndex,
            showEasyTdxIndicators: widget.showEasyTdxIndicators,
            easyTdxSubPanelCount: widget.easyTdxSubPanelCount,
            loading: _loading,
            errorText: _loadError == null ? '' : '筹码加载失败：$_loadError',
            loadInfo: _loadInfo,
          ),
        ),
      ),
    );
  }

  void _scheduleLazyLoad() {
    if (!mounted || !widget.enabled) return;
    scheduleMicrotask(_ensureLazyLoaded);
  }

  void _ensureLazyLoaded() {
    if (!mounted || !widget.enabled || _loading) return;
    final rawBars = widget.snapshot?.rawBars ?? const <RawBar>[];
    if (rawBars.isEmpty) return;

    final targetIndex = _targetIndex(rawBars.length);
    final key = <Object?>[
      identityHashCode(widget.snapshot),
      rawBars.length,
      rawBars.first.time.toIso8601String(),
      targetIndex,
      rawBars[targetIndex].time.toIso8601String(),
      widget.binCount,
      widget.ageDecay,
    ].join('|');
    if (_loadedKey == key) return;

    setState(() {
      _loadedKey = key;
      _loading = true;
      _loadError = null;
      _loadedBars = const <ChipDistributionBar>[];
      _loadInfo = null;
    });

    Future<void>.delayed(Duration.zero, () {
      if (!mounted || !widget.enabled || _loadedKey != key) return;
      try {
        final rangeBars = rawBars.sublist(0, targetIndex + 1);
        final chipBars = _chipBarsFromRawBars(rangeBars);
        final info = _ChipLoadInfo(
          startDate: rangeBars.first.time,
          endDate: rangeBars.last.time,
          rawBarCount: rangeBars.length,
          sourceText: 'easy-tdx ${_levelFromBars(rangeBars)} K线成交量',
        );
        if (!mounted || _loadedKey != key) return;
        setState(() {
          _loading = false;
          _loadedBars = chipBars;
          _loadInfo = info;
        });
        _announceLoadedRange(key, info);
      } catch (e) {
        if (!mounted || _loadedKey != key) return;
        setState(() {
          _loading = false;
          _loadError = e;
        });
      }
    });
  }

  List<ChipDistributionBar> _chipBarsFromRawBars(List<RawBar> rawBars) => <ChipDistributionBar>[
        for (final bar in rawBars)
          ChipDistributionBar(
            index: bar.index,
            time: bar.time,
            open: bar.open,
            high: bar.high,
            low: bar.low,
            close: bar.close,
            volume: bar.volume,
            priceVolume: bar.chipTickBins.totalByPrice,
            priceSellVolume: bar.chipTickBins.sellByPrice,
            priceBuyVolume: bar.chipTickBins.buyByPrice,
          ),
      ];

  int _targetIndex(int total) {
    if (total <= 0) return 0;
    final raw = widget.isStepMode
        ? widget.stepIndex
        : (widget.crosshairIndex ?? widget.visibleRightIndex ?? total - 1);
    return raw.clamp(0, total - 1).toInt();
  }

  void _announceLoadedRange(String key, _ChipLoadInfo info) {
    if (!_announcedKeys.add(key)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('筹码分布加载成功'),
          content: Text(
            '筹码分布的获取区间为: ${_fmtDate(info.startDate)}-${_fmtDate(info.endDate)}\n'
            '数据源: ${info.sourceText}\n'
            'K线数量: ${info.rawBarCount}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    });
  }

  String _targetPolicy() {
    if (widget.isStepMode) return 'step';
    if (widget.crosshairIndex != null) return '十字线';
    if (widget.visibleRightIndex != null) return '右侧K';
    return '末K';
  }

  static ChipDistributionResult _emptyResult() => const ChipDistributionResult(
        targetIndex: 0,
        currentPrice: 0,
        totalWeight: 0,
        sellWeight: 0,
        buyWeight: 0,
        averageCost: 0,
        pocPrice: 0,
        profitRatio: 0,
        bins: <ChipDistributionBin>[],
      );

  static String _fmtDate(DateTime value) => value.toIso8601String().split('T').first;

  static String _levelFromBars(List<RawBar> bars) {
    if (bars.length < 2) return '当前级别';
    final samples = <int>[];
    for (var i = 1; i < bars.length && samples.length < 24; i++) {
      final minutes = bars[i].time.difference(bars[i - 1].time).inMinutes.abs();
      if (minutes > 0) samples.add(minutes);
    }
    if (samples.isEmpty) return '当前级别';
    samples.sort();
    final median = samples[samples.length ~/ 2];
    if (median <= 2) return 'MIN1';
    if (median <= 7) return 'MIN5';
    if (median <= 20) return 'MIN15';
    if (median <= 45) return 'MIN30';
    if (median <= 90) return 'MIN60';
    return 'DAILY';
  }
}

class _ChipOverlayPainter extends CustomPainter {
  final List<RawBar> rawBars;
  final ChipDistributionResult result;
  final int exactBarCount;
  final String targetPolicy;
  final int windowSize;
  final double priceScale;
  final int? viewEndIndex;
  final bool showEasyTdxIndicators;
  final int easyTdxSubPanelCount;
  final bool loading;
  final String errorText;
  final _ChipLoadInfo? loadInfo;

  const _ChipOverlayPainter({
    required this.rawBars,
    required this.result,
    required this.exactBarCount,
    required this.targetPolicy,
    required this.windowSize,
    required this.priceScale,
    required this.viewEndIndex,
    required this.showEasyTdxIndicators,
    required this.easyTdxSubPanelCount,
    required this.loading,
    required this.errorText,
    required this.loadInfo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rawBars.isEmpty || size.width <= 0 || size.height <= 0) return;
    final chart = _visibleChart(size);
    if (chart == null) return;

    final overlayWidth = math.min(190.0, math.max(72.0, chart.rect.width * 0.28));
    final overlayRight = chart.rect.right - 2;
    final overlayLeft = overlayRight - overlayWidth;
    final overlayRect = Rect.fromLTRB(overlayLeft, chart.rect.top + 2, overlayRight, chart.rect.bottom - 2);
    _drawBackground(canvas, overlayRect);

    if (loading) {
      _drawText(canvas, '筹码懒加载中…', Offset(overlayRect.left + 8, overlayRect.top + 8), const Color(0xCCFFFFFF), 11);
      return;
    }
    if (errorText.isNotEmpty) {
      _drawText(canvas, errorText, Offset(overlayRect.left + 8, overlayRect.top + 8), const Color(0xFFFFAB91), 10.5);
      return;
    }
    if (result.isEmpty) {
      _drawText(canvas, '筹码：暂无数据', Offset(overlayRect.left + 8, overlayRect.top + 8), const Color(0xCCFFFFFF), 11);
      return;
    }

    final nonZero = result.bins.where((bin) => bin.weight > 0).toList(growable: false);
    final maxWeight = nonZero.map((bin) => bin.weight).fold<double>(0, math.max);
    if (maxWeight <= 0) return;

    final priceStep = result.bins.length >= 2
        ? (result.bins[1].price - result.bins[0].price).abs()
        : math.max(result.currentPrice.abs() * 0.002, 0.01);
    final minBarHeight = math.max(1.0, overlayRect.height / math.max(90, result.bins.length) * 0.72);
    final sellPaint = Paint()..color = const Color(0xFF26A69A).withValues(alpha: 0.36);
    final buyPaint = Paint()..color = const Color(0xFFEF5350).withValues(alpha: 0.38);
    final pocPaint = Paint()..color = const Color(0xFFFFC107).withValues(alpha: 0.58);

    canvas.save();
    canvas.clipRect(chart.rect);
    for (final bin in result.bins) {
      if (bin.weight <= 0) continue;
      final y = chart.priceToY(bin.price);
      if (y < chart.rect.top - 2 || y > chart.rect.bottom + 2) continue;
      final yHigh = chart.priceToY(bin.price + priceStep / 2);
      final yLow = chart.priceToY(bin.price - priceStep / 2);
      final h = math.max(minBarHeight, (yLow - yHigh).abs() * 0.76);
      final totalW = overlayWidth * 0.92 * (bin.weight / maxWeight);
      final sellW = bin.weight <= 0 ? 0.0 : totalW * (bin.sellWeight / bin.weight);
      final buyW = math.max(0.0, totalW - sellW);
      final right = overlayRight - 4;
      final y0 = (y - h / 2).clamp(chart.rect.top, chart.rect.bottom).toDouble();
      final isPoc = (bin.price - result.pocPrice).abs() <= priceStep * 0.6;
      canvas.drawRect(Rect.fromLTWH(right - totalW, y0, sellW, h), isPoc ? pocPaint : sellPaint);
      canvas.drawRect(Rect.fromLTWH(right - totalW + sellW, y0, buyW, h), isPoc ? pocPaint : buyPaint);
    }

    _drawPriceLine(canvas, overlayLeft, overlayRight, chart, result.currentPrice, const Color(0xFF66BB6A));
    _drawPriceLine(canvas, overlayLeft, overlayRight, chart, result.pocPrice, const Color(0xFFFFC107));
    canvas.restore();
    _drawHeader(canvas, chart.rect, overlayRect);
  }

  _ChipChart? _visibleChart(Size size) {
    final activeSubPanels = showEasyTdxIndicators ? easyTdxSubPanelCount.clamp(0, 4).toInt() : 0;
    final totalSubHeight = activeSubPanels == 0
        ? 0.0
        : activeSubPanels * S13ChipDistributionPanel._subPanelHeight +
            (activeSubPanels - 1) * S13ChipDistributionPanel._panelGap;
    final rect = Rect.fromLTWH(
      S13ChipDistributionPanel._leftPad,
      S13ChipDistributionPanel._topPad,
      math.max(0.0, size.width - S13ChipDistributionPanel._leftPad - S13ChipDistributionPanel._rightPad),
      math.max(
        0.0,
        size.height -
            S13ChipDistributionPanel._topPad -
            S13ChipDistributionPanel._bottomPad -
            totalSubHeight -
            (activeSubPanels > 0 ? S13ChipDistributionPanel._panelGap : 0),
      ),
    );
    if (rect.width <= 0 || rect.height <= 0) return null;

    final end = (viewEndIndex ?? rawBars.length - 1).clamp(0, rawBars.length - 1).toInt();
    final start = math.max(0, end - windowSize.clamp(24, 360).toInt() + 1).toInt();
    final visible = rawBars.sublist(start, end + 1);
    if (visible.isEmpty) return null;
    final low = visible.map((bar) => bar.low).reduce(math.min);
    final high = visible.map((bar) => bar.high).reduce(math.max);
    final center = (high + low) / 2;
    final rawRange = math.max(high - low, high.abs() * 0.002);
    final scaledRange = rawRange / priceScale.clamp(0.35, 5.0);
    final padding = math.max(scaledRange * 0.08, high.abs() * 0.001);
    return _ChipChart(rect: rect, minPrice: center - scaledRange / 2 - padding, maxPrice: center + scaledRange / 2 + padding);
  }

  void _drawPriceLine(Canvas canvas, double left, double right, _ChipChart chart, double price, Color color) {
    final y = chart.priceToY(price);
    if (y < chart.rect.top || y > chart.rect.bottom) return;
    canvas.drawLine(
      Offset(left, y),
      Offset(right, y),
      Paint()
        ..color = color.withValues(alpha: 0.62)
        ..strokeWidth = 1,
    );
  }

  void _drawBackground(Canvas canvas, Rect rect) {
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), Paint()..color = const Color(0xFF111722).withValues(alpha: 0.16));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawHeader(Canvas canvas, Rect chartRect, Rect overlayRect) {
    final info = loadInfo;
    final exact = info == null ? '-' : '$exactBarCount/${info.rawBarCount}';
    final line1 = '筹码 $targetPolicy ${result.targetIndex + 1}/${info?.rawBarCount ?? rawBars.length}';
    final line2 = '精确桶 $exact 获利 ${(result.profitRatio * 100).toStringAsFixed(1)}%';
    final line3 = '均 ${result.averageCost.toStringAsFixed(2)} 峰 ${result.pocPrice.toStringAsFixed(2)}';
    final line4 = info == null ? '' : '${_fmtDate(info.startDate)}-${_fmtDate(info.endDate)}';
    final left = overlayRect.left + 8;
    final top = chartRect.top + 7;
    final badgeHeight = line4.isEmpty ? 48.0 : 63.0;
    final badgeRect = Rect.fromLTWH(left - 6, top - 4, overlayRect.width - 10, badgeHeight);
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(7)), Paint()..color = const Color(0xCC0D1117).withValues(alpha: 0.54));
    _drawText(canvas, line1, Offset(left, top), const Color(0xE6FFFFFF), 10.5);
    _drawText(canvas, line2, Offset(left, top + 15), const Color(0xCCFFFFFF), 10);
    _drawText(canvas, line3, Offset(left, top + 30), const Color(0xAAFFFFFF), 10);
    if (line4.isNotEmpty) _drawText(canvas, line4, Offset(left, top + 45), const Color(0x99FFFFFF), 9.5);
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color, double size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 178);
    painter.paint(canvas, offset);
  }

  static String _fmtDate(DateTime value) => value.toIso8601String().split('T').first;

  @override
  bool shouldRepaint(covariant _ChipOverlayPainter oldDelegate) {
    return oldDelegate.rawBars != rawBars ||
        oldDelegate.result != result ||
        oldDelegate.exactBarCount != exactBarCount ||
        oldDelegate.targetPolicy != targetPolicy ||
        oldDelegate.windowSize != windowSize ||
        oldDelegate.priceScale != priceScale ||
        oldDelegate.viewEndIndex != viewEndIndex ||
        oldDelegate.showEasyTdxIndicators != showEasyTdxIndicators ||
        oldDelegate.easyTdxSubPanelCount != easyTdxSubPanelCount ||
        oldDelegate.loading != loading ||
        oldDelegate.errorText != errorText ||
        oldDelegate.loadInfo != loadInfo;
  }
}

class _ChipLoadInfo {
  final DateTime startDate;
  final DateTime endDate;
  final int rawBarCount;
  final String sourceText;

  const _ChipLoadInfo({required this.startDate, required this.endDate, required this.rawBarCount, required this.sourceText});
}

class _ChipChart {
  final Rect rect;
  final double minPrice;
  final double maxPrice;

  const _ChipChart({required this.rect, required this.minPrice, required this.maxPrice});

  double priceToY(double price) {
    final range = math.max(maxPrice - minPrice, 0.0000001);
    return rect.bottom - (price - minPrice) / range * rect.height;
  }
}
