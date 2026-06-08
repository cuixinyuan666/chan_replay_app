import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models/bi.dart';
import '../core/models/chan_snapshot.dart';
import '../core/models/fx.dart';
import '../core/models/merged_bar.dart';
import '../core/models/raw_bar.dart';
import '../core/models/seg.dart';
import '../core/models/zs.dart';

class PythonChanEngineSource {
  final String baseUrl;
  final http.Client _client;

  PythonChanEngineSource({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<ChanSnapshot> analyze({
    required String mode,
    required String market,
    required String code,
    String period = 'DAILY',
    String adjust = 'QFQ',
    int count = 5000,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = {
      'mode': mode,
      'symbol': code.trim(),
      'market': market.trim().toUpperCase(),
      'freq': period.trim().toUpperCase(),
      'adjust': adjust.trim().toUpperCase(),
      'count': '$count',
      if (startDate != null) 'start': _fmtDate(startDate),
      if (endDate != null) 'end': _fmtDate(endDate),
    };
    final uri = Uri.parse(_join(baseUrl, '/api/chan/analyze')).replace(queryParameters: query);
    final response = await _client.get(uri).timeout(const Duration(seconds: 60));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('chan.py 引擎返回 ${response.statusCode}: $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('chan.py 引擎返回结构不是 JSON 对象');
    }
    if (decoded['ok'] == false) {
      throw Exception(decoded['error'] ?? 'chan.py 引擎计算失败');
    }
    return _parseSnapshot(decoded);
  }

  void close() => _client.close();

  ChanSnapshot _parseSnapshot(Map<String, dynamic> data) {
    final bars = <RawBar>[];
    final rawRows = data['bars'];
    if (rawRows is List) {
      for (final row in rawRows) {
        if (row is Map) {
          final bar = _parseRawBar(row, bars.length);
          if (bar != null) bars.add(bar.copyWith(index: bars.length));
        }
      }
    }

    final mergedBars = [for (final bar in bars) _dummyMergedBar(bar)];
    final fxs = <FX>[];
    final fxRows = data['fx'];
    if (fxRows is List) {
      for (final row in fxRows) {
        if (row is Map) {
          final fx = _parseFx(row, mergedBars);
          if (fx != null) fxs.add(fx);
        }
      }
    }

    final bis = <BI>[];
    final biRows = data['bi'];
    if (biRows is List) {
      for (final row in biRows) {
        if (row is Map) {
          final bi = _parseBi(row, bis.length, mergedBars);
          if (bi != null) bis.add(bi);
        }
      }
    }

    final linkedBis = [
      for (var i = 0; i < bis.length; i++)
        bis[i].copyWith(
          prevIndex: i > 0 ? i - 1 : null,
          clearPrevIndex: i == 0,
          nextIndex: i + 1 < bis.length ? i + 1 : null,
          clearNextIndex: i + 1 >= bis.length,
        ),
    ];

    final segs = <SEG>[];
    final segRows = data['seg'];
    if (segRows is List) {
      for (final row in segRows) {
        if (row is Map) {
          final seg = _parseSeg(row, segs.length, linkedBis);
          if (seg != null) segs.add(seg);
        }
      }
    }

    final zss = <ZS>[];
    final zsRows = data['zs'];
    if (zsRows is List) {
      for (final row in zsRows) {
        if (row is Map) {
          final zs = _parseZs(row, zss.length);
          if (zs != null) zss.add(zs);
        }
      }
    }

    return ChanSnapshot(
      rawBars: bars,
      mergedBars: mergedBars,
      fxs: fxs,
      bis: linkedBis,
      segs: segs,
      zss: zss,
    );
  }

  RawBar? _parseRawBar(Map row, int index) {
    final time = _parseTime(row['dt'] ?? row['datetime'] ?? row['date'] ?? row['time']);
    final open = _num(row['open'] ?? row['o']);
    final high = _num(row['high'] ?? row['h']);
    final low = _num(row['low'] ?? row['l']);
    final close = _num(row['close'] ?? row['c']);
    final volume = _num(row['vol'] ?? row['volume'] ?? row['v']) ?? 0.0;
    if (time == null || open == null || high == null || low == null || close == null) return null;
    return RawBar(index: index, time: time, open: open, high: high, low: low, close: close, volume: volume);
  }

  FX? _parseFx(Map row, List<MergedBar> mergedBars) {
    final rawIndex = _int(row['raw_index'] ?? row['rawIndex']);
    final price = _num(row['price']);
    if (rawIndex == null || price == null || mergedBars.isEmpty) return null;
    final typeText = '${row['type'] ?? ''}'.toLowerCase();
    final isTop = typeText.contains('top');
    final center = _mergedAt(mergedBars, rawIndex);
    return FX(
      index: _int(row['index']) ?? center.index,
      rawIndex: rawIndex,
      time: _parseTime(row['time']) ?? center.time,
      type: isTop ? FxType.top : FxType.bottom,
      price: price,
      left: center,
      center: center,
      right: center,
      confirmed: row['confirmed'] != false,
    );
  }

  BI? _parseBi(Map row, int index, List<MergedBar> mergedBars) {
    final startRaw = _int(row['start_raw_index'] ?? row['startRawIndex']);
    final endRaw = _int(row['end_raw_index'] ?? row['endRawIndex']);
    final startPrice = _num(row['start_price'] ?? row['startPrice']);
    final endPrice = _num(row['end_price'] ?? row['endPrice']);
    if (startRaw == null || endRaw == null || startPrice == null || endPrice == null || mergedBars.isEmpty) return null;
    final dirText = '${row['direction'] ?? ''}'.toLowerCase();
    final isDown = dirText.contains('down');
    final startMerged = _mergedAt(mergedBars, startRaw);
    final endMerged = _mergedAt(mergedBars, endRaw);
    final startFx = FX(
      index: startMerged.index,
      rawIndex: startRaw,
      time: _parseTime(row['start_time'] ?? row['startTime']) ?? startMerged.time,
      type: isDown ? FxType.top : FxType.bottom,
      price: startPrice,
      left: startMerged,
      center: startMerged,
      right: startMerged,
      confirmed: true,
    );
    final endFx = FX(
      index: endMerged.index,
      rawIndex: endRaw,
      time: _parseTime(row['end_time'] ?? row['endTime']) ?? endMerged.time,
      type: isDown ? FxType.bottom : FxType.top,
      price: endPrice,
      left: endMerged,
      center: endMerged,
      right: endMerged,
      confirmed: row['is_sure'] != false,
    );
    return BI(
      index: _int(row['index']) ?? index,
      start: startFx,
      end: endFx,
      direction: isDown ? BiDirection.down : BiDirection.up,
      isSure: row['is_sure'] != false,
    );
  }

  SEG? _parseSeg(Map row, int index, List<BI> bis) {
    final start = _int(row['start_bi_index'] ?? row['startBiIndex']);
    final end = _int(row['end_bi_index'] ?? row['endBiIndex']);
    if (start == null || end == null || start < 0 || end < start || end >= bis.length) return null;
    final dirText = '${row['direction'] ?? ''}'.toLowerCase();
    final items = bis.sublist(start, end + 1);
    return SEG(
      index: _int(row['index']) ?? index,
      startBi: bis[start],
      endBi: bis[end],
      direction: dirText.contains('down') ? SegDirection.down : SegDirection.up,
      isSure: row['is_sure'] == true,
      reason: '${row['reason'] ?? 'chan.py'}',
      biList: items,
    );
  }

  ZS? _parseZs(Map row, int index) {
    final startBi = _int(row['start_bi_index'] ?? row['startBiIndex']);
    final endBi = _int(row['end_bi_index'] ?? row['endBiIndex']);
    final zg = _num(row['zg']);
    final zd = _num(row['zd']);
    final gg = _num(row['gg']);
    final dd = _num(row['dd']);
    if (startBi == null || endBi == null || zg == null || zd == null || gg == null || dd == null) return null;
    return ZS(
      index: _int(row['index']) ?? index,
      startBiIndex: startBi,
      endBiIndex: endBi,
      startRawIndex: _int(row['start_raw_index'] ?? row['startRawIndex']) ?? 0,
      endRawIndex: _int(row['end_raw_index'] ?? row['endRawIndex']) ?? 0,
      zg: zg,
      zd: zd,
      gg: gg,
      dd: dd,
      confirmed: row['confirmed'] == true,
      biInIndex: _int(row['bi_in_index'] ?? row['biInIndex']),
      biOutIndex: _int(row['bi_out_index'] ?? row['biOutIndex']),
      startSegIndex: _int(row['start_seg_index'] ?? row['startSegIndex']),
      endSegIndex: _int(row['end_seg_index'] ?? row['endSegIndex']),
    );
  }

  MergedBar _dummyMergedBar(RawBar bar) {
    return MergedBar(
      index: bar.index,
      startRawIndex: bar.index,
      endRawIndex: bar.index,
      highRawIndex: bar.index,
      lowRawIndex: bar.index,
      time: bar.time,
      highTime: bar.time,
      lowTime: bar.time,
      open: bar.open,
      high: bar.high,
      low: bar.low,
      close: bar.close,
      volume: bar.volume,
    );
  }

  MergedBar _mergedAt(List<MergedBar> bars, int rawIndex) {
    if (bars.isEmpty) throw StateError('empty bars');
    final index = rawIndex.clamp(0, bars.length - 1).toInt();
    return bars[index];
  }

  DateTime? _parseTime(Object? value) {
    if (value is DateTime) return value;
    final text = '${value ?? ''}'.trim().replaceFirst(' ', 'T').replaceAll('/', '-');
    if (text.isEmpty || text == 'null') return null;
    return DateTime.tryParse(text);
  }

  double? _num(Object? value) {
    if (value is num) return value.toDouble();
    final text = '${value ?? ''}'.trim().replaceAll(',', '');
    if (text.isEmpty || text == '-' || text.toLowerCase() == 'nan' || text == 'null') return null;
    return double.tryParse(text);
  }

  int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim());
  }

  String _join(String base, String path) {
    final left = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$left$path';
  }

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}
