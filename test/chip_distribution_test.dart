import 'package:chan_replay_app/core/analysis/chip_distribution.dart';
import 'package:chan_replay_app/core/analysis/chip_online_replay_adapter.dart';
import 'package:chan_replay_app/core/models/chan_snapshot.dart';
import 'package:chan_replay_app/core/models/raw_bar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chip distribution does not consume bars after target index', () {
    final engine = const ChipDistributionEngine();
    final baseBars = <ChipDistributionBar>[
      const ChipDistributionBar(
        index: 0,
        open: 10,
        high: 11,
        low: 9,
        close: 10.5,
        volume: 100,
      ),
      const ChipDistributionBar(
        index: 1,
        open: 10.5,
        high: 12,
        low: 10,
        close: 11.5,
        volume: 120,
      ),
    ];
    final withFuture = <ChipDistributionBar>[
      ...baseBars,
      const ChipDistributionBar(
        index: 2,
        open: 80,
        high: 120,
        low: 70,
        close: 110,
        volume: 999999,
      ),
    ];

    final a = engine.calculate(
      baseBars,
      targetIndex: 1,
      options: const ChipDistributionOptions(binCount: 32, lookback: 20),
    );
    final b = engine.calculate(
      withFuture,
      targetIndex: 1,
      options: const ChipDistributionOptions(binCount: 32, lookback: 20),
    );

    expect(b.currentPrice, a.currentPrice);
    expect(b.totalWeight, a.totalWeight);
    expect(b.averageCost, closeTo(a.averageCost, 1e-9));
    expect(b.pocPrice, closeTo(a.pocPrice, 1e-9));
    expect(b.profitRatio, closeTo(a.profitRatio, 1e-9));
  });

  test('exact price-volume bins are preferred over OHLCV fallback', () {
    final result = const ChipDistributionEngine().calculate(
      <ChipDistributionBar>[
        ChipDistributionBar(
          index: 0,
          open: 9,
          high: 12,
          low: 8,
          close: 11,
          volume: 1,
          priceVolume: <double, double>{10: 100, 11: 300},
        ),
      ],
      targetIndex: 0,
      options: const ChipDistributionOptions(binCount: 20),
    );

    expect(result.totalWeight, 400);
    expect(result.buyWeight, 400);
    expect(result.sellWeight, 0);
    expect(result.averageCost, closeTo(10.75, 0.08));
    expect(result.pocPrice, closeTo(11, 0.12));
    expect(result.profitRatio, closeTo(1, 1e-9));
  });

  test('a_replay_trainer chip_tick_bins p/s/b/w are parsed and preserved', () {
    final bar = ChipDistributionBar.fromJson(
      <String, dynamic>{
        'x': 3,
        't': '2026-01-05',
        'o': 10,
        'h': 11,
        'l': 9,
        'c': 10.5,
        'v': 999,
        'chip_tick_bins': <String, dynamic>{
          'p': <double>[10, 10.5, 11],
          's': <double>[20, 30, 40],
          'b': <double>[80, 70, 60],
          'w': <double>[100, 100, 100],
        },
      },
      0,
    );

    final result = const ChipDistributionEngine().calculate(
      <ChipDistributionBar>[bar],
      targetIndex: 0,
      options: const ChipDistributionOptions(binCount: 40),
    );

    expect(result.totalWeight, 300);
    expect(result.sellWeight, 90);
    expect(result.buyWeight, 210);
    expect(result.averageCost, closeTo(10.5, 0.08));
    expect(result.pocPrice, closeTo(10, 0.08));
  });

  test('chip_tick_bins legacy w-only mode is treated as buy side', () {
    final bar = ChipDistributionBar.fromJson(
      <String, dynamic>{
        't': '2026-01-05',
        'o': 10,
        'h': 11,
        'l': 9,
        'c': 10.5,
        'v': 1,
        'chip_tick_bins': <String, dynamic>{
          'p': <double>[10, 11],
          'w': <double>[40, 60],
        },
      },
      0,
    );

    final result = const ChipDistributionEngine().calculate(
      <ChipDistributionBar>[bar],
      targetIndex: 0,
      options: const ChipDistributionOptions(binCount: 20),
    );

    expect(result.totalWeight, 100);
    expect(result.sellWeight, 0);
    expect(result.buyWeight, 100);
  });

  test('chip target priority is step, crosshair, visible right, last bar', () {
    const resolver = ChipTargetResolver();

    expect(
      resolver.resolve(
        total: 100,
        isStepping: true,
        stepIndex: 12,
        crosshairIndex: 50,
        visibleRightIndex: 80,
      ),
      12,
    );
    expect(
      resolver.resolve(
        total: 100,
        isStepping: false,
        stepIndex: 12,
        crosshairIndex: 50,
        visibleRightIndex: 80,
      ),
      50,
    );
    expect(
      resolver.resolve(
        total: 100,
        isStepping: false,
        visibleRightIndex: 80,
      ),
      80,
    );
    expect(
      resolver.resolve(total: 100, isStepping: false),
      99,
    );
  });

  test('online replay adapter maps snapshot bars and follows crosshair targets',
      () {
    final snapshot = ChanSnapshot(
      rawBars: <RawBar>[
        RawBar(
          index: 0,
          time: DateTime(2026, 1, 1),
          open: 10,
          high: 11,
          low: 9,
          close: 10.5,
          volume: 100,
        ),
        RawBar(
          index: 1,
          time: DateTime(2026, 1, 2),
          open: 10.5,
          high: 12,
          low: 10,
          close: 11.5,
          volume: 120,
        ),
      ],
      mergedBars: const [],
      fxs: const [],
      bis: const [],
      segs: const [],
      zss: const [],
    );

    final bars = ChipOnlineReplayAdapter.fromSnapshot(snapshot);
    expect(bars.length, 2);
    expect(bars.last.close, 11.5);
    expect(
      ChipOnlineReplayAdapter.resolveTargetIndex(
        total: bars.length,
        isStepMode: true,
        stepIndex: 1,
        crosshairIndex: 0,
        viewEndIndex: 0,
      ),
      0,
    );
    expect(
      ChipOnlineReplayAdapter.resolveTargetIndex(
        total: bars.length,
        isStepMode: false,
        stepIndex: 1,
        crosshairIndex: null,
        viewEndIndex: 0,
      ),
      0,
    );
  });
}
