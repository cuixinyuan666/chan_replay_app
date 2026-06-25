import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chan_replay_app/core/analysis/chip_distribution.dart';
import 'package:chan_replay_app/core/analysis/chip_online_replay_adapter.dart';

String _read(String path) => File(path).readAsStringSync();

ChipDistributionBar _bar(
  int index, {
  required double close,
  double volume = 10,
}) =>
    ChipDistributionBar(
      index: index,
      time: DateTime(2026, 1, 1, 9, 30 + index),
      open: close,
      high: close + 0.05,
      low: close - 0.05,
      close: close,
      volume: volume,
    );

void main() {
  test('chip target resolver lets crosshair drive step mode', () {
    expect(
      ChipOnlineReplayAdapter.resolveTargetIndex(
        total: 100,
        isStepMode: true,
        stepIndex: 20,
        crosshairIndex: 80,
        viewEndIndex: 90,
      ),
      80,
    );

    expect(
      ChipOnlineReplayAdapter.resolveTargetIndex(
        total: 100,
        isStepMode: true,
        stepIndex: 20,
        crosshairIndex: 8,
        viewEndIndex: 90,
      ),
      8,
    );

    expect(
      ChipOnlineReplayAdapter.resolveTargetIndex(
        total: 100,
        isStepMode: true,
        stepIndex: 20,
        crosshairIndex: null,
        viewEndIndex: 90,
      ),
      20,
    );
  });

  test(
      'chip target resolver follows once priority crosshair then viewEnd then last',
      () {
    expect(
      ChipOnlineReplayAdapter.resolveTargetIndex(
        total: 100,
        isStepMode: false,
        stepIndex: 0,
        crosshairIndex: 7,
        viewEndIndex: 30,
      ),
      7,
    );

    expect(
      ChipOnlineReplayAdapter.resolveTargetIndex(
        total: 100,
        isStepMode: false,
        stepIndex: 0,
        crosshairIndex: null,
        viewEndIndex: 30,
      ),
      30,
    );

    expect(
      ChipOnlineReplayAdapter.resolveTargetIndex(
        total: 100,
        isStepMode: false,
        stepIndex: 0,
        crosshairIndex: null,
        viewEndIndex: null,
      ),
      99,
    );
  });

  test('chip engine never uses bars after targetIndex', () {
    final bars = <ChipDistributionBar>[
      _bar(0, close: 1.0, volume: 10),
      _bar(1, close: 2.0, volume: 10),
      _bar(2, close: 20.0, volume: 100000000),
    ];

    final result = const ChipDistributionEngine().calculate(
      bars,
      targetIndex: 1,
      options: const ChipDistributionOptions(binCount: 40, lookback: 1000000),
    );

    expect(result.targetIndex, 1);
    expect(result.currentPrice, 2.0);
    expect(result.totalWeight, lessThan(1000));
    expect(
      result.bins.where((bin) => bin.weight > 0).every((bin) => bin.price < 5),
      isTrue,
    );
  });

  test('S13 settings evidence exposes chip distribution fields', () {
    final source = _read('lib/ui/pages/s13_single_stock_replay_page.dart');

    expect(source, contains('[筹码分布]'));
    expect(source, contains('chip_target_source='));
    expect(source, contains('chip_input_mode='));
    expect(source, contains('chip_step_no_future='));
    expect(source, contains('Map<String, String> _chipDistributionEvidence'));
  });
}
