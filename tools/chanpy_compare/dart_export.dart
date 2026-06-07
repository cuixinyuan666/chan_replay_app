import 'dart:convert';
import 'dart:io';

import 'package:chan_replay_app/core/engine/chan_config.dart';
import 'package:chan_replay_app/core/engine/chan_replay_engine.dart';
import 'package:chan_replay_app/core/models/raw_bar.dart';

void main(List<String> args) async {
  final opts = _parseArgs(args);
  final csvPath = opts['csv'] ?? 'assets/sample_data/000001_daily.csv';
  final outPath = opts['out'] ?? 'build/chanpy_compare/dart.json';

  final bars = _loadCsv(File(csvPath));
  final engine = ChanReplayEngine(config: ChanConfig.chanPyDefault());
  final snapshot = engine.feedMany(bars);

  final output = <String, dynamic>{
    'engine': 'dart_chan_replay_engine',
    'csv': csvPath,
    'bar_count': bars.length,
    'fx': snapshot.fxs
        .map((fx) => {
              'index': fx.index,
              'raw_index': fx.rawIndex,
              'time': fx.time.toIso8601String(),
              'type': fx.isTop ? 'top' : 'bottom',
              'price': fx.price,
            })
        .toList(),
    'bi': snapshot.bis
        .map((bi) => {
              'index': bi.index,
              'start_raw_index': bi.startRawIndex,
              'end_raw_index': bi.endRawIndex,
              'start_time': bi.start.time.toIso8601String(),
              'end_time': bi.end.time.toIso8601String(),
              'start_price': bi.startPrice,
              'end_price': bi.endPrice,
              'direction': bi.isUp ? 'up' : 'down',
              'is_sure': bi.isSure,
            })
        .toList(),
    'seg': snapshot.segs
        .map((seg) => {
              'index': seg.index,
              'start_bi_index': seg.startBiIndex,
              'end_bi_index': seg.endBiIndex,
              'start_raw_index': seg.startRawIndex,
              'end_raw_index': seg.endRawIndex,
              'start_price': seg.startPrice,
              'end_price': seg.endPrice,
              'direction': seg.isUp ? 'up' : 'down',
              'is_sure': seg.isSure,
              'reason': seg.reason,
            })
        .toList(),
    'zs': snapshot.zss
        .map((zs) => {
              'index': zs.index,
              'start_bi_index': zs.startBiIndex,
              'end_bi_index': zs.endBiIndex,
              'start_raw_index': zs.startRawIndex,
              'end_raw_index': zs.endRawIndex,
              'zg': zs.zg,
              'zd': zs.zd,
              'gg': zs.gg,
              'dd': zs.dd,
              'confirmed': zs.confirmed,
              'bi_in_index': zs.biInIndex,
              'bi_out_index': zs.biOutIndex,
              'start_seg_index': zs.startSegIndex,
              'end_seg_index': zs.endSegIndex,
            })
        .toList(),
  };

  final out = File(outPath);
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  stdout.writeln('Dart export written: ${out.path}');
}

Map<String, String> _parseArgs(List<String> args) {
  final result = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final key = arg.substring(2);
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      result[key] = args[++i];
    } else {
      result[key] = 'true';
    }
  }
  return result;
}

List<RawBar> _loadCsv(File file) {
  if (!file.existsSync()) {
    throw ArgumentError('CSV not found: ${file.path}');
  }
  final lines = file.readAsLinesSync().where((line) => line.trim().isNotEmpty).toList();
  if (lines.length <= 1) return [];
  final header = _splitCsvLine(lines.first).map((e) => e.trim().toLowerCase()).toList();
  int col(String name) {
    final idx = header.indexOf(name);
    if (idx < 0) throw FormatException('CSV missing column: $name');
    return idx;
  }

  final timeCol = col('time');
  final openCol = col('open');
  final highCol = col('high');
  final lowCol = col('low');
  final closeCol = col('close');
  final volumeCol = header.contains('volume') ? header.indexOf('volume') : -1;
  final volCol = header.contains('vol') ? header.indexOf('vol') : volumeCol;

  final bars = <RawBar>[];
  for (var rowIdx = 1; rowIdx < lines.length; rowIdx++) {
    final row = _splitCsvLine(lines[rowIdx]);
    if (row.length < header.length) continue;
    final time = DateTime.tryParse(row[timeCol].trim().replaceFirst(' ', 'T')) ?? DateTime.tryParse(row[timeCol].trim());
    if (time == null) continue;
    bars.add(RawBar(
      index: bars.length,
      time: time,
      open: double.parse(row[openCol].trim()),
      high: double.parse(row[highCol].trim()),
      low: double.parse(row[lowCol].trim()),
      close: double.parse(row[closeCol].trim()),
      volume: volCol >= 0 ? double.tryParse(row[volCol].trim()) ?? 0.0 : 0.0,
    ));
  }
  return bars;
}

List<String> _splitCsvLine(String line) {
  final result = <String>[];
  final buffer = StringBuffer();
  var inQuote = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      inQuote = !inQuote;
      continue;
    }
    if (ch == ',' && !inQuote) {
      result.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(ch);
  }
  result.add(buffer.toString());
  return result;
}
