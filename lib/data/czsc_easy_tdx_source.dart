import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models/bi.dart';
import '../core/models/chan_snapshot.dart';
import '../core/models/fx.dart';
import '../core/models/merged_bar.dart';
import '../core/models/raw_bar.dart';
import '../core/models/seg.dart';
import '../core/models/zs.dart';

class CzscAnalyzeResult {
  final String freq;
  final ChanSnapshot snapshot;
  final String sourceLabel;
  final Map<String, String> signals;
  final String? engineWarning;

  const CzscAnalyzeResult({
    required this.freq,
    required this.snapshot,
    required this.sourceLabel,
    required this.signals,
    this.engineWarning,
  });
}

class CzscMultiAnalyzeResult {
  final String symbol;
  final List<String> freqs;
  final Map<String, CzscAnalyzeResult> results;

  const CzscMultiAnalyzeResult({
    required this.symbol,
    required this.freqs,
    required this.results,
  });
}

class CzscEasyTdxSource {
  final String baseUrl;
  final http.Client _client;

  CzscEasyTdxSource({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<CzscAnalyzeResult> analyze({
    required String symbol,
    required String market,
    required String freq,
    required String adjust,
    required int count,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final uri = Uri.parse(_join(baseUrl, '/api/czsc/analyze')).replace(
      queryParameters: {
        'symbol': symbol.trim(),
        'market': market,
        'freq': freq,
        'adjust': adjust,
        'count': '$count',
        if (startDate != null) 'start': _fmtDate(startDate),
        if (endDate != null) 'end': _fmtDate(endDate),
      },
    );
    final json = await _getJson(uri);
    return _parseResult(json, fallbackFreq: freq);
  }

  Future<CzscMultiAnalyzeResult> analyzeMulti({
    required String symbol,
    required String market,
    required List<String> freqs,
    required String adjust,
    required int count,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final normalizedFreqs = _uniqueFreqs(freqs);
    final uri = Uri.parse(_join(baseUrl, '/api/czsc/multi')).replace(
      queryParameters: {
        'symbol': symbol.trim(),
        'market': market,
        'freqs': normalizedFreqs.join(','),
        'adjust': adjust,
        'count': '$count',
        if (startDate != null) 'start': _fmtDate(startDate),
        if (endDate != null) 'end': _fmtDate(endDate),
      },
    );
    final json = await _getJson(uri);
    final rawResults = json['results'];
    final results = <String, CzscAnalyzeResult>{};
    if (rawResults is Map) {
      for (final entry in rawResults.entries) {
        final freq = '${entry.key}'.toUpperCase();
        final value = entry.value;
        if (value is Map) {
          results[freq] = _parseResult(
            Map<String, dynamic>.from(value),
            fallbackFreq: freq,
          );
        }
      }
    }
    return CzscMultiAnalyzeResult(
      symbol: '${json['symbol'] ?? symbol}',
      freqs: normalizedFreqs.where(results.containsKey).toList(),
      results: results,
    );
  }

  void close() => _client.close();

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('后端返回 ${response.statusCode}: ${response.body}');
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map<String, dynamic>) {
      throw StateError('后端返回结构不是 JSON 对象');
    }
    return json;
  }

  CzscAnalyzeResult _parseResult(
    Map<String, dynamic> json, {
    required String fallbackFreq,
  }) {
    final rawBars = _parseBars(_list(json['bars']));
    final mergedBars = _rawToMerged(rawBars);
    final fxs = _parseFx(_list(json['fx']), rawBars, mergedBars);
    final bis = _parseBi(_list(json['bi']), rawBars, fxs);
    final segs = _parseSeg(_list(json['seg'] ?? json['segs']), bis);
    final zss = _parseZs(_list(json['zs'] ?? json['zss']), rawBars);
    final signals = <String, String>{};
    final rawSignals = json['signals'];
    if (rawSignals is Map) {
      for (final entry in rawSignals.entries) {
        signals['${entry.key}'] = '${entry.value}';
      }
    }

    final source = json['source'];
    final freq = '${json['freq'] ?? fallbackFreq}'.toUpperCase();
    final sourceLabel = source is Map
        ? '${source['name'] ?? 'easy-tdx'} ${source['symbol'] ?? json['symbol'] ?? ''} ${source['freq'] ?? freq} ${source['count'] ?? rawBars.length}根'
        : '${json['symbol'] ?? ''} $freq ${rawBars.length}根';

    return CzscAnalyzeResult(
      freq: freq,
      snapshot: ChanSnapshot(
        rawBars: rawBars,
        mergedBars: mergedBars,
        fxs: fxs,
        bis: bis,
        segs: segs,
        zss: zss,
      ),
      sourceLabel: 'CZSC/$sourceLabel',
      signals: signals,
      engineWarning: json['engine_warning']?.toString(),
    );
  }

  List<RawBar> _parseBars(List<dynamic> rows) {
    final bars = <RawBar>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! Map) continue;
      bars.add(
        RawBar(
          index: _int(row['id'], i),
          time: _dt(row['dt']),
          open: _double(row['open']),
          high: _double(row['high']),
          low: _double(row['low']),
          close: _double(row['close']),
          volume: _double(row['vol'] ?? row['volume']),
        ),
      );
    }
    bars.sort((a, b) => a.index.compareTo(b.index));
    return [
      for (var i = 0; i < bars.length; i++) bars[i].copyWith(index: i),
    ];
  }

  List<MergedBar> _rawToMerged(List<RawBar> bars) {
    return [
      for (final bar in bars)
        MergedBar(
          index: bar.index,
          startRawIndex: bar.index,
          endRawIndex: bar.index,
          time: bar.time,
          open: bar.open,
          high: bar.high,
          low: bar.low,
          close: bar.close,
          volume: bar.volume,
        ),
    ];
  }

  List<FX> _parseFx(
    List<dynamic> rows,
    List<RawBar> bars,
    List<MergedBar> mergedBars,
  ) {
    if (bars.isEmpty || mergedBars.isEmpty) return const [];
    final fxs = <FX>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! Map) continue;
      final rawIndex = _barIndex(row['bar_id'] ?? row['raw_index'], bars.length);
      final center = mergedBars[rawIndex];
      final left = mergedBars[(rawIndex - 1).clamp(0, mergedBars.length - 1).toInt()];
      final right = mergedBars[(rawIndex + 1).clamp(0, mergedBars.length - 1).toInt()];
      final typeText = '${row['type'] ?? row['mark']}'.toLowerCase();
      final type = typeText.contains('top') || typeText.contains('顶') || typeText == 'g'
          ? FxType.top
          : FxType.bottom;
      fxs.add(
        FX(
          index: _int(row['index'], i),
          rawIndex: rawIndex,
          time: _dt(row['dt'] ?? bars[rawIndex].time),
          type: type,
          price: _double(row['price'], type == FxType.top ? bars[rawIndex].high : bars[rawIndex].low),
          left: left,
          center: center,
          right: right,
          confirmed: _bool(row['confirmed'], true),
        ),
      );
    }
    fxs.sort((a, b) => a.rawIndex.compareTo(b.rawIndex));
    return fxs;
  }

  List<BI> _parseBi(List<dynamic> rows, List<RawBar> bars, List<FX> fxs) {
    if (bars.isEmpty || fxs.isEmpty) return const [];
    final bis = <BI>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! Map) continue;
      final startRaw = _barIndex(row['start_bar_id'] ?? row['start_raw_index'], bars.length);
      final endRaw = _barIndex(row['end_bar_id'] ?? row['end_raw_index'], bars.length);
      final direction = _direction(row['direction']);
      final startPrice = _double(row['start_price'], bars[startRaw].close);
      final endPrice = _double(row['end_price'], bars[endRaw].close);
      final startFx = _nearestFx(
        fxs,
        rawIndex: startRaw,
        price: startPrice,
        prefer: direction == BiDirection.up ? FxType.bottom : FxType.top,
      );
      final endFx = _nearestFx(
        fxs,
        rawIndex: endRaw,
        price: endPrice,
        prefer: direction == BiDirection.up ? FxType.top : FxType.bottom,
      );
      if (startFx == null || endFx == null) continue;
      bis.add(
        BI(
          index: _int(row['index'], i),
          start: startFx,
          end: endFx,
          direction: direction,
          isSure: _bool(row['is_sure'] ?? row['confirmed'], true),
        ),
      );
    }
    bis.sort((a, b) => a.index.compareTo(b.index));
    return [
      for (var i = 0; i < bis.length; i++)
        bis[i].copyWith(
          prevIndex: i == 0 ? null : i - 1,
          clearPrevIndex: i == 0,
          nextIndex: i == bis.length - 1 ? null : i + 1,
          clearNextIndex: i == bis.length - 1,
        ),
    ];
  }

  List<SEG> _parseSeg(List<dynamic> rows, List<BI> bis) {
    if (bis.isEmpty) return const [];
    final segs = <SEG>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! Map) continue;
      final startBiIndex = _int(row['start_bi_index'], 0).clamp(0, bis.length - 1).toInt();
      final endBiIndex = _int(row['end_bi_index'], startBiIndex).clamp(startBiIndex, bis.length - 1).toInt();
      final directionText = '${row['direction']}'.toLowerCase();
      final direction = directionText.contains('up') || directionText.contains('向上')
          ? SegDirection.up
          : SegDirection.down;
      segs.add(
        SEG(
          index: _int(row['index'], i),
          startBi: bis[startBiIndex],
          endBi: bis[endBiIndex],
          direction: direction,
          isSure: _bool(row['is_sure'] ?? row['confirmed'], true),
          reason: '${row['reason'] ?? 'czsc'}',
          biList: bis.sublist(startBiIndex, endBiIndex + 1),
        ),
      );
    }
    segs.sort((a, b) => a.index.compareTo(b.index));
    return [
      for (var i = 0; i < segs.length; i++)
        segs[i].copyWith(
          prevIndex: i == 0 ? null : i - 1,
          clearPrevIndex: i == 0,
          nextIndex: i == segs.length - 1 ? null : i + 1,
          clearNextIndex: i == segs.length - 1,
        ),
    ];
  }

  List<ZS> _parseZs(List<dynamic> rows, List<RawBar> bars) {
    if (bars.isEmpty) return const [];
    final zss = <ZS>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! Map) continue;
      final startRaw = _barIndex(row['start_bar_id'] ?? row['start_raw_index'], bars.length);
      final endRaw = _barIndex(row['end_bar_id'] ?? row['end_raw_index'], bars.length);
      zss.add(
        ZS(
          index: _int(row['index'], i),
          startBiIndex: _int(row['start_bi_index'], 0),
          endBiIndex: _int(row['end_bi_index'], 0),
          startRawIndex: startRaw,
          endRawIndex: endRaw < startRaw ? startRaw : endRaw,
          zg: _double(row['zg'] ?? row['high']),
          zd: _double(row['zd'] ?? row['low']),
          gg: _double(row['gg'] ?? row['peak_high'] ?? row['zg'] ?? row['high']),
          dd: _double(row['dd'] ?? row['peak_low'] ?? row['zd'] ?? row['low']),
          confirmed: _bool(row['confirmed'] ?? row['is_sure'], true),
          biInIndex: _nullableInt(row['bi_in_index']),
          biOutIndex: _nullableInt(row['bi_out_index']),
          startSegIndex: _nullableInt(row['start_seg_index']),
          endSegIndex: _nullableInt(row['end_seg_index']),
        ),
      );
    }
    return zss;
  }

  FX? _nearestFx(
    List<FX> fxs, {
    required int rawIndex,
    required double price,
    required FxType prefer,
  }) {
    FX? best;
    var bestScore = double.infinity;
    for (final fx in fxs) {
      final typePenalty = fx.type == prefer ? 0.0 : 100000.0;
      final score = (fx.rawIndex - rawIndex).abs() * 1000.0 + (fx.price - price).abs() + typePenalty;
      if (score < bestScore) {
        best = fx;
        bestScore = score;
      }
    }
    return best;
  }

  String _join(String base, String path) {
    final left = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$left$path';
  }

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  List<String> _uniqueFreqs(List<String> freqs) {
    final result = <String>[];
    for (final freq in freqs) {
      final text = freq.trim().toUpperCase();
      if (text.isNotEmpty && !result.contains(text)) result.add(text);
    }
    return result.isEmpty ? ['DAILY'] : result;
  }

  List<dynamic> _list(Object? value) => value is List ? value : const [];

  DateTime _dt(Object? value) {
    if (value is DateTime) return value;
    final text = '${value ?? ''}'.trim().replaceFirst(' ', 'T');
    return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _barIndex(Object? value, int length) => _int(value, 0).clamp(0, length - 1).toInt();

  int _int(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }

  int? _nullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  double _double(Object? value, [double fallback = 0]) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? fallback;
  }

  bool _bool(Object? value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = '${value ?? ''}'.toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return fallback;
  }

  BiDirection _direction(Object? value) {
    final text = '${value ?? ''}'.toLowerCase();
    return text.contains('up') || text.contains('向上') ? BiDirection.up : BiDirection.down;
  }
}
