import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/analysis/chip_distribution.dart';
import '../drawing/drawing_object.dart';
import '../drawing/tradingview_drawing_tool.dart';

class S13ChipChartContext {
  final String symbol;
  final String? market;
  final String period;
  final int rawBarCount;

  const S13ChipChartContext({
    required this.symbol,
    required this.market,
    required this.period,
    required this.rawBarCount,
  });

  String get key => '${symbol.trim()}|${market ?? ''}|${period.trim().toUpperCase()}|$rawBarCount';
}

class S13ChipDistributionSpec {
  final String symbol;
  final String? market;
  final String period;
  final ChipDistributionResult result;
  final int exactBarCount;
  final String targetPolicy;
  final DateTime startDate;
  final DateTime endDate;
  final int rawBarCount;
  final String sourceText;
  final int targetRawIndex;

  const S13ChipDistributionSpec({
    required this.symbol,
    required this.market,
    required this.period,
    required this.result,
    required this.exactBarCount,
    required this.targetPolicy,
    required this.startDate,
    required this.endDate,
    required this.rawBarCount,
    required this.sourceText,
    required this.targetRawIndex,
  });

  bool matches(S13ChipChartContext? context) {
    if (context == null) return false;
    return context.symbol == symbol &&
        context.period.toUpperCase() == period.toUpperCase();
  }

  List<DrawingObject> toDrawingObjects({required int chartRawBarCount}) {
    if (result.isEmpty || result.bins.isEmpty || chartRawBarCount <= 0) {
      return const <DrawingObject>[];
    }
    final nonZero = result.bins.where((bin) => bin.weight > 0).toList(growable: false);
    if (nonZero.isEmpty) return const <DrawingObject>[];
    final maxWeight = nonZero.map((bin) => bin.weight).fold<double>(0, math.max);
    if (maxWeight <= 0) return const <DrawingObject>[];

    final now = DateTime.fromMillisecondsSinceEpoch(0);
    final rightRaw = targetRawIndex.clamp(0, chartRawBarCount - 1).toInt();
    final maxSpan = math.max(8, math.min(44, (chartRawBarCount * 0.22).round())).toInt();
    final priceStep = result.bins.length >= 2
        ? (result.bins[1].price - result.bins[0].price).abs()
        : math.max(result.currentPrice.abs() * 0.002, 0.01);
    final objects = <DrawingObject>[];

    for (final bin in nonZero) {
      final span = math.max(1, (bin.weight / maxWeight * maxSpan).round()).toInt();
      final leftRaw = math.max(0, rightRaw - span).toInt();
      if (leftRaw >= rightRaw) continue;
      final half = math.max(priceStep * 0.38, bin.price.abs() * 0.00012);
      final isPoc = (bin.price - result.pocPrice).abs() <= priceStep * 0.6;
      final color = isPoc ? 0xFFFFC107 : 0xFF90CAF9;
      final opacity = isPoc ? 0.42 : 0.22;
      objects.add(DrawingObject(
        id: 's13_chip_${symbol}_${period}_${rightRaw}_${objects.length}',
        tool: TradingViewDrawingTool.rectangle,
        anchors: <DrawingAnchor>[
          DrawingAnchor.chart(rawIndex: leftRaw, price: bin.price - half),
          DrawingAnchor.chart(rawIndex: rightRaw, price: bin.price + half),
        ],
        style: DrawingStyle(
          colorValue: color,
          strokeWidth: isPoc ? 0.9 : 0.35,
          opacity: isPoc ? 0.86 : 0.34,
          filled: true,
          fillColorValue: color,
          fillOpacity: opacity,
        ),
        text: '',
        locked: true,
        hidden: false,
        selected: false,
        createdAt: now,
        updatedAt: now,
      ));
    }
    return objects;
  }
}

class S13ChipDistributionStore {
  static final ValueNotifier<S13ChipDistributionSpec?> listenable =
      ValueNotifier<S13ChipDistributionSpec?>(null);

  static S13ChipChartContext? _context;

  static S13ChipChartContext? get context => _context;

  static void updateChartContext({
    required String symbolLabel,
    required int rawBarCount,
  }) {
    final parsed = _parseSymbolLabel(symbolLabel);
    if (parsed == null || rawBarCount <= 0) return;
    final next = S13ChipChartContext(
      symbol: parsed.symbol,
      market: parsed.market,
      period: parsed.period,
      rawBarCount: rawBarCount,
    );
    if (_context?.key == next.key) return;
    _context = next;
  }

  static void publish(S13ChipDistributionSpec spec) {
    listenable.value = spec;
  }

  static void clearForCurrentContext() {
    final current = listenable.value;
    if (current == null || !current.matches(_context)) return;
    listenable.value = null;
  }

  static _ParsedSymbolLabel? _parseSymbolLabel(String raw) {
    final head = raw.split('|').first.trim();
    if (head.isEmpty) return null;
    final parts = head.split(RegExp(r'\s+')).where((v) => v.trim().isNotEmpty).toList(growable: false);
    if (parts.isEmpty) return null;
    final symbol = parts.first.trim();
    if (symbol.isEmpty) return null;
    final period = parts.length >= 2 ? parts[1].trim().toUpperCase() : 'DAILY';
    final market = _inferMarket(symbol);
    return _ParsedSymbolLabel(symbol: symbol, market: market, period: period.isEmpty ? 'DAILY' : period);
  }

  static String? _inferMarket(String symbol) {
    if (!RegExp(r'^\d{6}$').hasMatch(symbol)) return null;
    if (symbol.startsWith('6') || symbol.startsWith('5') || symbol.startsWith('9')) return 'SH';
    if (symbol.startsWith('0') || symbol.startsWith('1') || symbol.startsWith('2') || symbol.startsWith('3')) return 'SZ';
    return null;
  }
}

class _ParsedSymbolLabel {
  final String symbol;
  final String? market;
  final String period;

  const _ParsedSymbolLabel({
    required this.symbol,
    required this.market,
    required this.period,
  });
}
