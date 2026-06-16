import 'package:chan_replay_app/core/models/chan_snapshot.dart';
import 'package:chan_replay_app/core/models/easy_tdx_indicator.dart';
import 'package:chan_replay_app/core/models/raw_bar.dart';
import 'package:chan_replay_app/core/models/rhythm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rewrapped snapshot keeps rhythm overlays for the same rawBars object', () {
    final rawBars = <RawBar>[];
    final original = ChanSnapshot(
      rawBars: rawBars,
      mergedBars: const [],
      fxs: const [],
      bis: const [],
      segs: const [],
      zss: const [],
      indicators: const EasyTdxIndicators(),
      rhythmLines: const [
        RhythmLine(
          id: 'r1',
          level: 'fract',
          sourceKind: 'fract',
          sourceLabel: '分型',
          calcMode: 'normal',
          dir: 'UP',
          displayLabel: '节奏线1-0',
          labelLeft: '1-0',
          labelRight: '0.5',
          x1: 1,
          y1: 2,
          x2: 3,
          y2: 2,
          threshold: 4.764,
          ratio: 0.5,
          thresholdRatio: 1.382,
          roundCurrent: 1,
          roundRef: 1,
          layer: 0,
        ),
      ],
      rhythmHits: const [
        RhythmHit(
          id: 'h1',
          lineId: 'r1',
          level: 'fract',
          sourceKind: 'fract',
          rawIndex: 3,
          time: null,
          price: 5,
          threshold: 4.764,
          dir: 'UP',
          displayLabel: '分型1382',
          detail: 'hit',
        ),
      ],
    );
    final rewrapped = ChanSnapshot(
      rawBars: rawBars,
      mergedBars: original.mergedBars,
      fxs: original.fxs,
      bis: original.bis,
      segs: original.segs,
      zss: original.zss,
      bsps: original.bsps,
      indicators: original.indicators,
    );
    expect(rewrapped.rhythmLines, hasLength(1));
    expect(rewrapped.rhythmHits, hasLength(1));
  });
}
