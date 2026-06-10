import '../core/models/bi.dart';
import '../core/models/bsp.dart';
import '../core/models/chan_snapshot.dart';
import '../core/models/easy_tdx_indicator.dart';
import '../core/models/fx.dart';
import '../core/models/merged_bar.dart';
import '../core/models/raw_bar.dart';
import '../core/models/seg.dart';
import '../core/models/zs.dart';
import 'python_chan_analysis_source.dart';

PythonChanAnalysis parseChanAnalysisJson(Map<String, dynamic> data) {
  final snapshot = _parseSnapshot(data);
  final frames = <ChanSnapshot>[];
  final rawFrames = data['frames'];
  if (rawFrames is List) {
    for (final frame in rawFrames) {
      if (frame is Map<String, dynamic>) {
        frames.add(_parseSnapshot(frame));
      } else if (frame is Map) {
        frames.add(_parseSnapshot(Map<String, dynamic>.from(frame)));
      }
    }
  }
  return PythonChanAnalysis(
    snapshot: snapshot,
    frames: frames,
    meta: data['meta'] is Map
        ? Map<String, dynamic>.from(data['meta'] as Map)
        : const {},
  );
}

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

  final backendMergedBars = <MergedBar>[];
  final mergedRows = data['merged_bars'] ?? data['mergedBars'];
  if (mergedRows is List) {
    for (final row in mergedRows) {
      if (row is Map) {
        final merged = _parseMergedBar(row, bars);
        if (merged != null) backendMergedBars.add(merged);
      }
    }
  }

  final structuralMergedBars = backendMergedBars.isNotEmpty
      ? backendMergedBars
      : [for (final bar in bars) _dummyMergedBar(bar)];

  final fxs = <FX>[];
  final fxRows = data['fx'];
  if (fxRows is List) {
    for (final row in fxRows) {
      if (row is Map) {
        final fx = _parseFx(row, structuralMergedBars);
        if (fx != null) fxs.add(fx);
      }
    }
  }

  final bis = <BI>[];
  final biRows = data['bi'];
  if (biRows is List) {
    for (final row in biRows) {
      if (row is Map) {
        final bi = _parseBi(row, bis.length, structuralMergedBars);
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

  final bsps = <BspPoint>[];
  final bspRows = data['bsp'] ?? data['bsps'];
  if (bspRows is List) {
    for (final row in bspRows) {
      if (row is Map) {
        final bsp = _parseBsp(row, bsps.length);
        if (bsp != null) bsps.add(bsp);
      }
    }
  }

  return ChanSnapshot(
    rawBars: bars,
    mergedBars: backendMergedBars,
    fxs: fxs,
    bis: linkedBis,
    segs: segs,
    zss: zss,
    bsps: bsps,
    indicators: EasyTdxIndicators.fromJson(data['indicators']),
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

MergedBar? _parseMergedBar(Map row, List<RawBar> bars) {
  final index = _int(row['index']) ?? _int(row['idx']);
  final startRaw = _int(row['start_raw_index'] ?? row['startRawIndex']);
  final endRaw = _int(row['end_raw_index'] ?? row['endRawIndex']);
  final high = _num(row['high']);
  final low = _num(row['low']);
  if (index == null || startRaw == null || endRaw == null || high == null || low == null || bars.isEmpty) return null;
  final raw = bars[startRaw.clamp(0, bars.length - 1).toInt()];
  return MergedBar(
    index: index,
    startRawIndex: startRaw,
    endRawIndex: endRaw,
    highRawIndex: _int(row['high_raw_index'] ?? row['highRawIndex']) ?? startRaw,
    lowRawIndex: _int(row['low_raw_index'] ?? row['lowRawIndex']) ?? startRaw,
    time: _parseTime(row['time']) ?? raw.time,
    highTime: _parseTime(row['high_time'] ?? row['highTime']) ?? raw.time,
    lowTime: _parseTime(row['low_time'] ?? row['lowTime']) ?? raw.time,
    open: _num(row['open']) ?? raw.open,
    high: high,
    low: low,
    close: _num(row['close']) ?? raw.close,
    volume: _num(row['volume'] ?? row['vol']) ?? raw.volume,
  );
}

FX? _parseFx(Map row, List<MergedBar> mergedBars) {
  final rawIndex = _int(row['raw_index'] ?? row['rawIndex']);
  final price = _num(row['price']);
  if (rawIndex == null || price == null || mergedBars.isEmpty) return null;
  final isTop = '${row['type'] ?? ''}'.toLowerCase().contains('top');
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
  final isDown = '${row['direction'] ?? ''}'.toLowerCase().contains('down');
  final startMerged = _mergedAt(mergedBars, startRaw);
  final endMerged = _mergedAt(mergedBars, endRaw);
  final startFx = FX(index: startMerged.index, rawIndex: startRaw, time: _parseTime(row['start_time'] ?? row['startTime']) ?? startMerged.time, type: isDown ? FxType.top : FxType.bottom, price: startPrice, left: startMerged, center: startMerged, right: startMerged, confirmed: true);
  final endFx = FX(index: endMerged.index, rawIndex: endRaw, time: _parseTime(row['end_time'] ?? row['endTime']) ?? endMerged.time, type: isDown ? FxType.bottom : FxType.top, price: endPrice, left: endMerged, center: endMerged, right: endMerged, confirmed: row['is_sure'] != false);
  return BI(index: _int(row['index']) ?? index, start: startFx, end: endFx, direction: isDown ? BiDirection.down : BiDirection.up, isSure: row['is_sure'] != false);
}

SEG? _parseSeg(Map row, int index, List<BI> bis) {
  final start = _int(row['start_bi_index'] ?? row['startBiIndex']);
  final end = _int(row['end_bi_index'] ?? row['endBiIndex']);
  if (start == null || end == null || start < 0 || end < start || end >= bis.length) return null;
  final isDown = '${row['direction'] ?? ''}'.toLowerCase().contains('down');
  return SEG(index: _int(row['index']) ?? index, startBi: bis[start], endBi: bis[end], direction: isDown ? SegDirection.down : SegDirection.up, isSure: row['is_sure'] == true, reason: '${row['reason'] ?? 'chan.py'}', biList: bis.sublist(start, end + 1));
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

BspPoint? _parseBsp(Map row, int index) {
  final rawIndex = _int(row['raw_index'] ?? row['rawIndex']);
  final price = _num(row['price']);
  if (rawIndex == null || price == null) return null;
  return BspPoint(
    index: _int(row['index']) ?? index,
    rawIndex: rawIndex,
    time: _parseTime(row['time']),
    price: price,
    type: '${row['type'] ?? 'BSP'}',
    level: '${row['level'] ?? ''}',
    biIndex: _int(row['bi_index'] ?? row['biIndex']),
    segIndex: _int(row['seg_index'] ?? row['segIndex']),
    zsIndex: _int(row['zs_index'] ?? row['zsIndex']),
    confirmed: row['confirmed'] != false,
  );
}

MergedBar _dummyMergedBar(RawBar bar) => MergedBar(index: bar.index, startRawIndex: bar.index, endRawIndex: bar.index, highRawIndex: bar.index, lowRawIndex: bar.index, time: bar.time, highTime: bar.time, lowTime: bar.time, open: bar.open, high: bar.high, low: bar.low, close: bar.close, volume: bar.volume);

MergedBar _mergedAt(List<MergedBar> bars, int rawIndex) {
  for (final bar in bars) {
    if (rawIndex >= bar.startRawIndex && rawIndex <= bar.endRawIndex) return bar;
  }
  return bars[rawIndex.clamp(0, bars.length - 1).toInt()];
}

DateTime? _parseTime(Object? value) {
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
