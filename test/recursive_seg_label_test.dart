import 'package:chan_replay_app/ui/widgets/recursive_seg_origin_kline_chart.dart';
import 'package:chan_replay_app/ui/widgets/bsp_chart_label_adapter.dart';
import 'package:chan_replay_app/core/models/bsp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats recursive segment BSP labels with layer and type', () {
    expect(recursiveSegBspLabel(2, 'B3a'), '2段B3a');
    expect(recursiveSegBspLabel(3, 'S3B'), '3段S3B');
    expect(recursiveSegBspLabel(4, 'buy1p'), '4段B1p');
  });

  test('near-candle and bottom BSP labels share type body formatter', () {
    const buy = BspPoint(
      index: 0,
      rawIndex: 10,
      price: 1,
      type: 'buy3a',
      buy: true,
    );
    const sell = BspPoint(
      index: 1,
      rawIndex: 11,
      price: 1,
      type: '卖2',
      buy: false,
    );
    expect(BspChartLabelAdapter.displayTypeFor(buy), 'B3a');
    expect(BspChartLabelAdapter.labelTextFor(levelPrefix: '笔', bsp: buy), '笔B3a');
    expect(BspChartLabelAdapter.labelTextFor(levelPrefix: '2段', bsp: buy), '2段B3a');
    expect(BspChartLabelAdapter.displayTypeFor(sell), 'S2');
    expect(BspChartLabelAdapter.labelTextFor(levelPrefix: '段', bsp: sell), '段S2');
  });

  test('real recursive BSP supersedes endpoint candidate on same bar', () {
    const real = BspPoint(
      index: 0,
      rawIndex: 9071,
      price: 1.28,
      type: 'B2',
      level: 'segseg',
    );
    expect(
        recursiveSegCandidateIsSuperseded(const {
          2: [real]
        }, 2, 9071),
        isTrue);
    expect(
        recursiveSegCandidateIsSuperseded(const {
          2: [real]
        }, 2, 9000),
        isFalse);
  });
}
