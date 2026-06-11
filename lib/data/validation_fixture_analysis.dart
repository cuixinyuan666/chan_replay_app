import '../core/models/bsp.dart';
import '../core/models/chan_snapshot.dart';
import '../core/models/level_relation.dart';
import '../core/models/multi_level_chan_snapshot.dart';
import '../core/models/raw_bar.dart';
import 'python_multi_level_chan_analysis_source.dart';

PythonMultiLevelChanAnalysis buildValidationFixtureAnalysis() {
  final dailyBars = List<RawBar>.generate(6, (i) {
    final t = DateTime(2025, 10, 8 + i);
    final p = 100.0 + i;
    return RawBar(index: i, time: t, open: p, high: p + 1, low: p - 1, close: p + 0.5, volume: 1000 + i);
  });
  final m30Bars = <RawBar>[];
  final times = const [(10, 0), (10, 30), (11, 0), (11, 30), (13, 0), (13, 30), (14, 0), (14, 30)];
  var idx = 0;
  for (var d = 0; d < 6; d++) {
    for (final hm in times) {
      final t = DateTime(2025, 10, 8 + d, hm.$1, hm.$2);
      final p = 50.0 + idx / 10.0;
      m30Bars.add(RawBar(index: idx, time: t, open: p, high: p + 1, low: p - 1, close: p + 0.3, volume: 2000 + idx));
      idx++;
    }
  }
  const dailyBsp = BspPoint(index: 0, rawIndex: 5, time: DateTime(2025, 10, 13, 23, 59), price: 105.5, type: 'B2s', level: 'DAILY', confirmed: true);
  const m30Bsp = BspPoint(index: 0, rawIndex: 42, time: DateTime(2025, 10, 13, 11, 0), price: 54.2, type: 'B1', level: 'MIN30', confirmed: true);
  final snapshot = MultiLevelChanSnapshot(
    mainLevel: 'DAILY',
    levels: const ['DAILY', 'MIN30'],
    snapshots: {
      'DAILY': ChanSnapshot(rawBars: dailyBars, mergedBars: const [], fxs: const [], bis: const [], segs: const [], zss: const [], bsps: const [dailyBsp]),
      'MIN30': ChanSnapshot(rawBars: m30Bars, mergedBars: const [], fxs: const [], bis: const [], segs: const [], zss: const [], bsps: const [m30Bsp]),
    },
    relations: const [LevelRelation(parentLevel: 'DAILY', parentRawIndex: 5, childLevel: 'MIN30', childStartRawIndex: 40, childEndRawIndex: 47)],
    meta: const {'validation_fixture': true, 'fixture_remove_next_version': true, 'source': 'ui_validation_fixture'},
  );
  return PythonMultiLevelChanAnalysis(snapshot: snapshot, frames: [snapshot], meta: snapshot.meta);
}
