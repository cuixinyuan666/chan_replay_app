import 'package:chan_replay_app/ui/widgets/recursive_seg_origin_kline_chart.dart';
import 'package:chan_replay_app/core/models/bsp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats recursive segment BSP labels with layer and type', () {
    expect(recursiveSegBspLabel(2, 'B3a'), '2段3a');
    expect(recursiveSegBspLabel(3, 'S3B'), '3段3b');
    expect(recursiveSegBspLabel(4, 'buy1p'), '4段1p');
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
