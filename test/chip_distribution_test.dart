import 'package:chan_replay_app/core/analysis/chip_distribution.dart';
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
        const ChipDistributionBar(
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
    expect(result.averageCost, closeTo(10.75, 0.08));
    expect(result.pocPrice, closeTo(11, 0.12));
    expect(result.profitRatio, closeTo(1, 1e-9));
  });
}
