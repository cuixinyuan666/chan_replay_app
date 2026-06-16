import 'package:flutter_test/flutter_test.dart';
import 'package:chan_replay_app/core/models/rhythm.dart';
import 'package:chan_replay_app/ui/pages/s13_rhythm_viewport_selector.dart';

RhythmLine makeLine(String id, int x1, int x2, {int layer = 1}) => RhythmLine(
      id: id,
      level: 'DAILY',
      sourceKind: 'fx',
      sourceLabel: 'FX',
      calcMode: 'transition',
      dir: 'UP',
      displayLabel: 'FX1382',
      labelLeft: 'A',
      labelRight: 'B',
      x1: x1,
      y1: 10,
      x2: x2,
      y2: 11,
      threshold: 12,
      ratio: 0.6,
      thresholdRatio: 1.382,
      roundCurrent: 1,
      roundRef: 1,
      layer: layer,
    );

RhythmHit makeHit(String id, String lineId, int rawIndex) => RhythmHit(
      id: id,
      lineId: lineId,
      level: 'DAILY',
      sourceKind: 'fx',
      rawIndex: rawIndex,
      time: null,
      price: 12,
      threshold: 12,
      dir: 'UP',
      displayLabel: 'FX1382',
      detail: '',
    );

void main() {
  test('selects overlays near viewport instead of oldest first', () {
    final selection = S13RhythmViewportSelector.select(
      lines: <RhythmLine>[
        makeLine('old', 1, 5),
        makeLine('near', 84, 96),
        makeLine('cross', 20, 95, layer: 2),
      ],
      hits: <RhythmHit>[
        makeHit('old-hit', 'old', 3),
        makeHit('near-hit', 'near', 90),
        makeHit('right-hit', 'near', 105),
      ],
      totalBars: 120,
      viewEndIndex: 99,
      windowSize: 20,
      maxLines: 10,
      maxHits: 10,
    );

    expect(selection.lines.map((e) => e.id), containsAll(<String>['near', 'cross']));
    expect(selection.lines.map((e) => e.id), isNot(contains('old')));
    expect(selection.hits.map((e) => e.id), containsAll(<String>['near-hit', 'right-hit']));
    expect(selection.hits.map((e) => e.id), isNot(contains('old-hit')));
  });

  test('caps selected overlays and exposes hidden counts', () {
    final selection = S13RhythmViewportSelector.select(
      lines: <RhythmLine>[
        makeLine('l1', 80, 90),
        makeLine('l2', 81, 91),
        makeLine('l3', 82, 92),
      ],
      hits: <RhythmHit>[
        makeHit('h1', 'l1', 88),
        makeHit('h2', 'l2', 89),
        makeHit('h3', 'l3', 90),
      ],
      totalBars: 100,
      viewEndIndex: 90,
      windowSize: 20,
      maxLines: 2,
      maxHits: 1,
    );

    expect(selection.lines.length, 2);
    expect(selection.hits.length, 1);
    expect(selection.hiddenLineCount, 1);
    expect(selection.hiddenHitCount, 2);
  });
}
