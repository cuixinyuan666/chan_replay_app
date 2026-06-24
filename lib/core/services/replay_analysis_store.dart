import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

class LatestAnalysisJson {
  final DateTime savedAt;
  final Map<String, dynamic> analysis;
  final String symbol;
  final String market;
  final String period;
  final String adjust;

  const LatestAnalysisJson({
    required this.savedAt,
    required this.analysis,
    required this.symbol,
    required this.market,
    required this.period,
    required this.adjust,
  });

  String get displaySymbol {
    final m = market.trim().toUpperCase();
    final s = symbol.trim().toUpperCase();
    if (m.isEmpty) return s.isEmpty ? '--' : s;
    if (s.isEmpty) return m;
    return '$m$s';
  }

  Map<String, dynamic> toPayload() => {'analysis': analysis};

  String toPrettyPayloadJson() =>
      const JsonEncoder.withIndent('  ').convert(toPayload());
}

class BacktestRecord {
  final String id;
  final DateTime createdAt;
  final String symbol;
  final String period;
  final String source;
  final int tradeCount;
  final double? winRate;
  final double? totalReturn;
  final double? finalEquity;
  final double? maxDrawdown;
  final double? profitFactor;
  final Map<String, dynamic> result;

  const BacktestRecord({
    required this.id,
    required this.createdAt,
    required this.symbol,
    required this.period,
    required this.source,
    required this.tradeCount,
    required this.winRate,
    required this.totalReturn,
    required this.finalEquity,
    required this.maxDrawdown,
    required this.profitFactor,
    required this.result,
  });

  factory BacktestRecord.fromPipeline({
    required Map<String, dynamic> result,
    required LatestAnalysisJson? latestAnalysis,
  }) {
    return BacktestRecord.fromResearchResult(
      result: result,
      latestAnalysis: latestAnalysis,
      source: 'pipeline',
    );
  }

  factory BacktestRecord.fromResearchResult({
    required Map<String, dynamic> result,
    required LatestAnalysisJson? latestAnalysis,
    required String source,
    String? symbol,
    String? market,
    String? period,
  }) {
    final backtest = result['backtest'] is Map
        ? Map<String, dynamic>.from(result['backtest'] as Map)
        : result;
    final summary = backtest['summary'] is Map
        ? Map<String, dynamic>.from(backtest['summary'] as Map)
        : <String, dynamic>{};
    final meta = backtest['meta'] is Map
        ? Map<String, dynamic>.from(backtest['meta'] as Map)
        : <String, dynamic>{};
    final createdAt = DateTime.now();
    final displaySymbol = _displaySymbol(
      symbol ??
          _string(meta['symbol']) ??
          _string(summary['symbol']) ??
          latestAnalysis?.symbol ??
          '--',
      market ??
          _string(meta['market']) ??
          _string(summary['market']) ??
          latestAnalysis?.market ??
          '',
      latestAnalysis: latestAnalysis,
    );
    final maxDrawdown = _double(summary['max_drawdown']);
    final profitFactor = _double(summary['profit_factor']);
    final basePeriod = period ??
        _string(meta['period']) ??
        _string(meta['level']) ??
        _string(summary['period']) ??
        latestAnalysis?.period ??
        '--';
    return BacktestRecord(
      id: createdAt.microsecondsSinceEpoch.toString(),
      createdAt: createdAt,
      symbol: displaySymbol,
      period: _recordPeriodLabel(
        basePeriod: basePeriod,
        source: source,
        maxDrawdown: maxDrawdown,
        profitFactor: profitFactor,
      ),
      source: source,
      tradeCount:
          _int(summary['trade_count']) ?? _rows(backtest['trades']).length,
      winRate: _double(summary['win_rate']),
      totalReturn: _double(summary['total_return']),
      finalEquity: _double(summary['final_equity']),
      maxDrawdown: maxDrawdown,
      profitFactor: profitFactor,
      result: _deepCopyMap(result),
    );
  }
}

class KlineLocationRequest {
  final int nonce;
  final String symbol;
  final String market;
  final String level;
  final int rawIndex;
  final DateTime? time;
  final DateTime? startDate;
  final DateTime? endDate;
  final String label;
  final String mode;
  final int? frameIndex;
  final int? visibleStartRawIndex;
  final int? visibleEndRawIndex;
  final Map<String, dynamic>? analysisPayload;
  final String source;

  const KlineLocationRequest({
    required this.nonce,
    required this.symbol,
    required this.market,
    required this.level,
    required this.rawIndex,
    this.time,
    this.startDate,
    this.endDate,
    this.label = '',
    this.mode = 'once',
    this.frameIndex,
    this.visibleStartRawIndex,
    this.visibleEndRawIndex,
    this.analysisPayload,
    this.source = '',
  });
}

class ReplayAnalysisStore {
  static final ValueNotifier<LatestAnalysisJson?> latestAnalysis =
      ValueNotifier<LatestAnalysisJson?>(null);
  static final ValueNotifier<List<BacktestRecord>> backtestRecords =
      ValueNotifier<List<BacktestRecord>>(const []);
  static final ValueNotifier<KlineLocationRequest?> klineLocation =
      ValueNotifier<KlineLocationRequest?>(null);

  static void saveLatestAnalysis(Map<String, dynamic> analysis) {
    latestAnalysis.value = LatestAnalysisJson(
      savedAt: DateTime.now(),
      analysis: _deepCopyMap(analysis),
      symbol: _analysisString(analysis, const ['meta', 'symbol']) ??
          _analysisString(analysis, const ['symbol']) ??
          _analysisString(analysis, const ['meta', 'code']) ??
          '--',
      market: _analysisString(analysis, const ['meta', 'market']) ??
          _analysisString(analysis, const ['market']) ??
          '',
      period: _analysisString(analysis, const ['meta', 'freq']) ??
          _analysisString(analysis, const ['meta', 'period']) ??
          _analysisString(analysis, const ['freq']) ??
          _analysisString(analysis, const ['period']) ??
          '--',
      adjust: _analysisString(analysis, const ['meta', 'adjust']) ??
          _analysisString(analysis, const ['adjust']) ??
          '',
    );
  }

  static void addBacktestRecord(BacktestRecord record) {
    backtestRecords.value = UnmodifiableListView<BacktestRecord>([
      record,
      ...backtestRecords.value,
    ]);
  }

  static void clearBacktestRecords() {
    backtestRecords.value = const [];
  }

  static void requestKlineLocation({
    required String symbol,
    required String market,
    required String level,
    required int rawIndex,
    DateTime? time,
    DateTime? startDate,
    DateTime? endDate,
    String label = '',
    String mode = 'once',
    int? frameIndex,
    int? visibleStartRawIndex,
    int? visibleEndRawIndex,
    Map<String, dynamic>? analysisPayload,
    String source = '',
  }) {
    klineLocation.value = KlineLocationRequest(
      nonce: DateTime.now().microsecondsSinceEpoch,
      symbol: symbol,
      market: market,
      level: level,
      rawIndex: rawIndex,
      time: time,
      startDate: startDate,
      endDate: endDate,
      label: label,
      mode: mode.trim().isEmpty ? 'once' : mode.trim().toLowerCase(),
      frameIndex: frameIndex,
      visibleStartRawIndex: visibleStartRawIndex,
      visibleEndRawIndex: visibleEndRawIndex,
      analysisPayload: analysisPayload == null ? null : _deepCopyMap(analysisPayload),
      source: source,
    );
  }
}

Map<String, dynamic> _deepCopyMap(Map<String, dynamic> source) {
  return Map<String, dynamic>.from(jsonDecode(jsonEncode(source)) as Map);
}

String? _string(Object? value, {String? fallback}) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty || text == 'null') return fallback;
  return text;
}

String _displaySymbol(
  String symbol,
  String market, {
  LatestAnalysisJson? latestAnalysis,
}) {
  if (latestAnalysis != null &&
      symbol == latestAnalysis.symbol &&
      market == latestAnalysis.market) {
    return latestAnalysis.displaySymbol;
  }
  final m = market.trim().toUpperCase();
  final s = symbol.trim().toUpperCase();
  if (m.isEmpty) return s.isEmpty ? '--' : s;
  if (s.isEmpty) return m;
  return '$m$s';
}

String _recordPeriodLabel({
  required String basePeriod,
  required String source,
  required double? maxDrawdown,
  required double? profitFactor,
}) {
  final parts = <String>[basePeriod, source];
  if (maxDrawdown != null) {
    parts.add('DD ${(maxDrawdown * 100).toStringAsFixed(1)}%');
  }
  if (profitFactor != null) {
    parts.add('PF ${profitFactor.toStringAsFixed(2)}');
  }
  return parts.where((part) => part.trim().isNotEmpty).join(' · ');
}

String? _analysisString(Map<String, dynamic> source, List<String> path) {
  Object? cursor = source;
  for (final key in path) {
    if (cursor is! Map) return null;
    cursor = cursor[key];
  }
  return _string(cursor);
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}

double? _double(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}');
}

List<dynamic> _rows(Object? value) => value is List ? value : const [];
