import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/analysis/chip_distribution.dart';
import '../../core/analysis/chip_online_replay_adapter.dart';
import '../../core/models/chan_snapshot.dart';
import '../../core/models/raw_bar.dart';

/// S13 单股多级别复盘内嵌筹码 overlay。
///
/// 不再以独立右侧卡片显示，而是直接绘制在 K 线主图区右侧：
/// - 只在用户打开筹码图层后懒计算；关闭时不计算、不绘制；
/// - 使用当前 active level 的 easy-tdx K 线作为筹码量来源；
/// - 默认统计区间为该级别首根可用 K 线到当前显示截止 K；
/// - 有 chip_tick_bins / chipTickBins 时，优先使用 a_replay_trainer.py 风格 p/s/b/w；
/// - 没有逐价桶时，使用 OHLCV 成交量兜底；
/// - 使用 IgnorePointer，不拦截十字线、拖拽、画线工具等主图交互。
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
  List<RawBar> _loadedRawBars = const <RawBar>[];
  List<ChipDistributionBar> _loadedChipBars = const <ChipDistributionBar>[];
  _ChipLazyLoadInfo? _loadInfo;
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
    final chartRawBars = widget.snapshot?.rawBars ?? const <RawBar>[];
    final result = _loadedChipBars.isEmpty
        ? const ChipDistributionResult.empty()
        : const ChipDistributionEngine().calculate(
            _loadedChipBars,
            targetIndex: _loadedChipBars.length - 1,
            options: ChipDistributionOptions(
              binCount: widget.binCount,
              lookback: 1000000,
              ageDecay: widget.ageDecay,
            ),
          );
    final exactBarCount = _loadedChipBars.where((bar) => bar.hasExactChipBins).length;
    final targetPolicy = _targetPolicy(
      isStepMode: widget.isStepMode,
      crosshairIndex: widget.crosshairIndex,
      visibleRightIndex: widget.visibleRightIndex,
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _InChartChipDistributionPainter(
            rawBars: chartRawBars,
            result: result,
            exactBarCount: exactBarCount,
            targetPolicy: targetPolicy,
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
    if (!mounted || !widget.enabled) return;
    final snapshot = widget.snapshot;
    final rawBars = snapshot?.rawBars ?? const <RawBar>[];
    if (rawBars.isEmpty) return;
    final targetIndex = _targetIndex(rawBars.length);
    final targetBar = rawBars[targetIndex];
    final firstBar = rawBars.first;
    final key = [
      identityHashCode(snapshot),
      rawBars.length,
      firstBar.time.toIso8601String(),
      targetIndex,
      targetBar.time.toIso8601String(),
      widget.binCount,
      widget.ageDecay,
    ].join('|');
    if (_loadedKey == key || _loading) return;
    setState(() {
      _loading = true;
      _loadError = null;
      _loadedKey = key;
      _loadedRawBars = const <RawBar>[];
      _loadedChipBars = const <ChipDistributionBar>[];
      _loadInfo = null;
    });
    Future<void>.delayed(Duration.zero, () {
      if (!mounted || !widget.enabled || _loadedKey != key) return;
      try {
        final clippedRawBars = rawBars.sublist(0, targetIndex + 1);
        final chipBars = ChipOnlineReplayAdapter.fromSnapshot(
          ChanSnapshot(
            rawBars: clippedRawBars,
            mergedBars: const [],
            fxs: const [],
            bis: const [],
            segs: const [],
            zss: const [],
            indicators: snapshot?.indicators ?? const dynamic,
          ),
        );
        final info = _ChipLazyLoadInfo(
          startDate: clippedRawBars.first.time,
          endDate: clippedRawBars.last.time,
          rawBarCount: clippedRawBars.length,
          sourceText: 'easy-tdx ${_levelFromBars(clippedRawBars)} K线成交量',
        );
        if (!mounted || _loadedKey != key) return;
        setState(() {
          _loading = false;
          _loadedRawBars = clippedRawBars;
          _loadedChipBars = chipBars;
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

  int _targetIndex(int total) {
    if (total <= 0) return 0;
    final raw = widget.isStepMode
        ? widget.stepIndex
        : (widget.crosshairIndex ?? widget.visibleRightIndex ?? total - 1);
    return raw.clamp(0, total - 1).toInt();
  }

  void _announceLoadedRange(String key, _ChipLazyLoadInfo info) {
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

  static String _targetPolicy({
    required bool isStepMode,
    required int? crosshairIndex,
    required int? visibleRightIndex,
  }) {
    if (isStepMode) return 'step';
    if (crosshairIndex != null) return '十字线';
    if (visibleRightIndex != null) return '右侧K';
    return '末K';
  }

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
    final m = samples[samples.length ~/ 2];
    if (m <= 2) return 'MIN1';
    if (m <= 7) return 'MIN5';
    if (m <= 20) return 'MIN15';
    if (m <= 45) return 'MIN30';
    if (m <= 90) return 'MIN60';
    return 'DAILY';
  }
}

class _InChartChipDistributionPainter extends CustomPainter {
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
  final _ChipLazyLoadInfo? loadInfo;

  const _InChartChipDistributionPainter({
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
    final chart = _visibleChartMeta(size);
    if (chart == null || chart.rect.width <= 0 || chart.rect.height <= 0) return;

    final overlayWidth = math.min(190.0, math.max(72.0, chart.rect.width * 0.28));
    final overlayRight = chart.rect.right - 2;
    final overlayLeft = overlayRight - overlayWidth;
    final overlayRect = Rect.fromLTRB(
      overlayLeft,
      chart.rect.top + 2,
      overlayRight,
      chart.rect.bottom - 2,
    );

    _drawBackground(canvas, overlayRect);
    if (loading) {
      _drawText(
        canvas,
        '筹码懒加载中…',
        Offset(overlayRect.left + 8, overlayRect.top + 8),
        const Color(0xCCFFFFFF),
        11,
      );
      return;
    }
    if (errorText.isNotEmpty) {
      _drawText(
        canvas,
        errorText,
        Offset(overlayRect.left + 8, overlayRect.top + 8),
        const Color(0xFFFFAB91),
        10.5,
      );
      return;
    }
    if (result.isEmpty) {
      _drawText(
        canvas,
        '筹码：暂无数据',
        Offset(overlayRect.left + 8, overlayRect.top + 8),
        const Color(0xCCFFFFFF),
        11,
      );
      return;
    }

    final nonZero = result.bins.where((bin) => bin.weight > 0).toList(growable: false);
    if (nonZero.isEmpty) return;
    final maxWeight = nonZero.map((bin) => bin.weight).fold<double>(0, math.max);
    if (maxWeight <= 0) return;

    final priceStep = result.bins.length >= 2
        ? (result.bins[1].price - result.bins[0].price).abs()
        : math.max(result.currentPrice.abs() * 0.002, 0.01);
    final minBarHeight = math.max(1.0, overlayRect.height / math.max(90, result.bins.length) * 0.72);

    final sellPaint = Paint()..color = const Color(0xFF26A69A).withValues(alpha: 0.36);
    final buyPaint = Paint()..color = const Color(0xFFEF5350).withValues(alpha: 0.38);
    final pocPaint = Paint()..color = const Color(0xFFFFC107).withValues(alpha: 0.58);
    final targetLinePaint = Paint()
      ..color = const Color(0xFF66BB6A).withValues(alpha: 0.70)
      ..strokeWidth = 1.0;
    final pocLinePaint = Paint()
      ..color = const Color(0xFFFFC107).withValues(alpha: 0.58)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

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
      final firstPaint = isPoc ? pocPaint : sellPaint;
      final secondPaint = isPoc ? pocPaint : buyPaint;
      canvas.drawRect(Rect.fromLTWH(right - totalW, y0, sellW, h), firstPaint);
      canvas.drawRect(Rect.fromLTWH(right - totalW + sellW, y0, buyW, h), secondPaint);
    }

    final targetY = chart.priceToY(result.currentPrice);
    if (targetY >= chart.rect.top && targetY <= chart.rect.bottom) {
      canvas.drawLine(Offset(overlayLeft, targetY), Offset(overlayRight, targetY), targetLinePaint);
    }
    final pocY = chart.priceToY(result.pocPrice);
    if (pocY >= chart.rect.top && pocY <= chart.rect.bottom) {
      canvas.drawLine(Offset(overlayLeft, pocY), Offset(overlayRight, pocY), pocLinePaint);
    }
    canvas.restore();

    _drawHeader(canvas, chart.rect, overlayRect);
  }

  _ChipChartMeta? _visibleChartMeta(Size size) {
    final activeSubPanels = showEasyTdxIndicators ? easyTdxSubPanelCount.clamp(0, 4).toInt() : 0;
    final totalSubHeight = activeSubPanels == 0
        ? 0.0
        : activeSubPanels * S13ChipDistributionPanel._subPanelHeight +
            (activeSubPanels - 1) * S13ChipDistributionPanel._panelGap;
    final contentWidth = math.max(
      0.0,
      size.width - S13ChipDistributionPanel._leftPad - S13ChipDistributionPanel._rightPad,
    );
    final mainHeight = math.max(
      0.0,
      size.height -
          S13ChipDistributionPanel._topPad -
          S13ChipDistributionPanel._bottomPad -
          totalSubHeight -
          (activeSubPanels > 0 ? S13ChipDistributionPanel._panelGap : 0),
    );
    final rect = Rect.fromLTWH(
      S13ChipDistributionPanel._leftPad,
      S13ChipDistributionPanel._topPad,
      contentWidth,
      mainHeight,
    );
    if (rect.width <= 0 || rect.height <= 0) return null;

    final end = (viewEndIndex ?? rawBars.length - 1).clamp(0, rawBars.length - 1).toInt();
    final safeWindow = windowSize.clamp(24, 360).toInt();
    final start = math.max(0, end - safeWindow + 1).toInt();
    final visible = rawBars.sublist(start, end + 1);
    if (visible.isEmpty) return null;
    final low = visible.map((bar) => bar.low).reduce(math.min);
    final high = visible.map((bar) => bar.high).reduce(math.max);
    final center = (high + low) / 2;
    final rawRange = math.max(high - low, high.abs() * 0.002);
    final scaledRange = rawRange / priceScale.clamp(0.35, 5.0);
    final padding = math.max(scaledRange * 0.08, high.abs() * 0.001);
    final minPrice = center - scaledRange / 2 - padding;
    final maxPrice = center + scaledRange / 2 + padding;
    return _ChipChartMeta(rect: rect, minPrice: minPrice, maxPrice: maxPrice);
  }

  void _drawBackground(Canvas canvas, Rect rect) {
    final bgPaint = Paint()..color = const Color(0xFF111722).withValues(alpha: 0.16);
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), bgPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), borderPaint);
  }

  void _drawHeader(Canvas canvas, Rect chartRect, Rect overlayRect) {
    final exact = loadInfo == null ? '-' : '$exactBarCount/${loadInfo!.rawBarCount}';
    final line1 = '筹码 $targetPolicy  ${result.targetIndex + 1}/${loadInfo?.rawBarCount ?? rawBars.length}';
    final line2 = '精确桶 $exact  获利 ${(result.profitRatio * 100).toStringAsFixed(1)}%';
    final line3 = '均 ${result.averageCost.toStringAsFixed(2)}  峰 ${result.pocPrice.toStringAsFixed(2)}';
    final line4 = loadInfo == null
        ? ''
        : '${_fmtDate(loadInfo!.startDate)}-${_fmtDate(loadInfo!.endDate)}';
    final left = overlayRect.left + 8;
    final top = chartRect.top + 7;
    final badgeHeight = line4.isEmpty ? 48.0 : 63.0;
    final badgeRect = Rect.fromLTWH(left - 6, top - 4, overlayRect.width - 10, badgeHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(7)),
      Paint()..color = const Color(0xCC0D1117).withValues(alpha: 0.54),
    );
    _drawText(canvas, line1, Offset(left, top), const Color(0xE6FFFFFF), 10.5);
    _drawText(canvas, line2, Offset(left, top + 15), const Color(0xCCFFFFFF), 10.0);
    _drawText(canvas, line3, Offset(left, top + 30), const Color(0xAAFFFFFF), 10.0);
    if (line4.isNotEmpty) {
      _drawText(canvas, line4, Offset(left, top + 45), const Color(0x99FFFFFF), 9.5);
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 178);
    painter.paint(canvas, offset);
  }

  static String _fmtDate(DateTime value) => value.toIso8601String().split('T').first;

  @override
  bool shouldRepaint(covariant _InChartChipDistributionPainter oldDelegate) {
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

class _ChipLazyLoadInfo {
  final DateTime startDate;
  final DateTime endDate;
  final int rawBarCount;
  final String sourceText;

  const _ChipLazyLoadInfo({
    required this.startDate,
    required this.endDate,
    required this.rawBarCount,
    required this.sourceText,
  });
}

class _ChipChartMeta {
  final Rect rect;
  final double minPrice;
  final double maxPrice;

  const _ChipChartMeta({
    required this.rect,
    required this.minPrice,
    required this.maxPrice,
  });

  double priceToY(double price) {
    final range = math.max(maxPrice - minPrice, 0.0000001);
    return rect.bottom - (price - minPrice) / range * rect.height;
  }
}
