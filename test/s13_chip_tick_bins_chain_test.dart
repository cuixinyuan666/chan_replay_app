import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chan_replay_app/core/analysis/chip_distribution.dart';
import 'package:chan_replay_app/core/analysis/chip_online_replay_adapter.dart';
import 'package:chan_replay_app/core/models/raw_bar.dart';
import 'package:chan_replay_app/data/chan_snapshot_json_parser.dart';

String _read(String path) => File(path).readAsStringSync();

Map<String, dynamic> _barJson(
  int i, {
  required double close,
  Map<String, dynamic>? chipTickBins,
}) {
  return <String, dynamic>{
    'dt': '2026-01-01 09:${(30 + i).toString().padLeft(2, '0')}',
    'open': close,
    'high': close + 0.05,
    'low': close - 0.05,
    'close': close,
    'volume': 100,
    if (chipTickBins != null) 'chip_tick_bins': chipTickBins,
  };
}

void main() {
  test('RawBar carries chipTickBins and copyWith preserves it', () {
    final raw = RawBar(
      index: 0,
      time: DateTime(2026, 1, 1, 9, 30),
      open: 1,
      high: 1.1,
      low: 0.9,
      close: 1.05,
      volume: 100,
      chipTickBins: const <String, dynamic>{
        'p': <double>[1.0],
        'b': <double>[10],
      },
    );

    final copied = raw.copyWith(index: 9);

    expect(copied.index, 9);
    expect(copied.chipTickBins, isNotNull);
    expect(copied.chipTickBins!['p'], <double>[1.0]);
  });

  test('ChanSnapshotJsonParser preserves backend chip_tick_bins on raw bars',
      () {
    final snapshot = ChanSnapshotJsonParser.parse(<String, dynamic>{
      'bars': <Map<String, dynamic>>[
        _barJson(
          0,
          close: 1.0,
          chipTickBins: const <String, dynamic>{
            'p': <double>[1.0, 1.1],
            's': <double>[10, 0],
            'b': <double>[0, 20],
            'w': <double>[10, 20],
          },
        ),
        _barJson(1, close: 1.2),
      ],
    });

    expect(snapshot.rawBars.length, 2);
    expect(snapshot.rawBars.first.chipTickBins, isNotNull);
    expect(snapshot.rawBars.first.chipTickBins!['p'], <double>[1.0, 1.1]);
    expect(snapshot.rawBars[1].chipTickBins, isNull);
  });

  test('ChipOnlineReplayAdapter upgrades exact bars and keeps fallback bars',
      () {
    final snapshot = ChanSnapshotJsonParser.parse(<String, dynamic>{
      'bars': <Map<String, dynamic>>[
        _barJson(
          0,
          close: 1.0,
          chipTickBins: const <String, dynamic>{
            'p': <double>[1.0, 1.1],
            's': <double>[10, 0],
            'b': <double>[0, 20],
          },
        ),
        _barJson(1, close: 1.2),
      ],
    });

    final bars = ChipOnlineReplayAdapter.fromSnapshot(snapshot);

    expect(bars.first.hasExactChipBins, isTrue);
    expect(bars.first.priceSellVolume[1.0], 10);
    expect(bars.first.priceBuyVolume[1.1], 20);
    expect(bars[1].hasExactChipBins, isFalse);
  });

  test('ChipDistributionEngine consumes exact chip bins from parsed snapshot',
      () {
    final snapshot = ChanSnapshotJsonParser.parse(<String, dynamic>{
      'bars': <Map<String, dynamic>>[
        _barJson(
          0,
          close: 1.05,
          chipTickBins: const <String, dynamic>{
            'p': <double>[1.0, 1.1],
            's': <double>[10, 0],
            'b': <double>[0, 20],
          },
        ),
      ],
    });

    final bars = ChipOnlineReplayAdapter.fromSnapshot(snapshot);
    final result = const ChipDistributionEngine().calculate(
      bars,
      targetIndex: 0,
      options: const ChipDistributionOptions(binCount: 20),
    );

    expect(result.totalWeight, closeTo(30, 1e-9));
    expect(result.sellWeight, closeTo(10, 1e-9));
    expect(result.buyWeight, closeTo(20, 1e-9));
    expect(result.isEmpty, isFalse);
  });

  test('source chain contains chipTickBins in model, parsers, and adapter', () {
    final rawBar = _read('lib/core/models/raw_bar.dart');
    final parser = _read('lib/data/chan_snapshot_json_parser.dart');
    final legacyParser = _read('lib/data/python_chan_engine_source.dart');
    final adapter = _read('lib/core/analysis/chip_online_replay_adapter.dart');

    expect(rawBar, contains('chipTickBins'));
    expect(parser, contains("row['chip_tick_bins'] ?? row['chipTickBins']"));
    expect(
        legacyParser, contains("row['chip_tick_bins'] ?? row['chipTickBins']"));
    expect(adapter, contains('ChipDistributionBar.fromJson'));
  });
}
