import 'package:flutter_test/flutter_test.dart';

import 'package:chan_replay_app/ui/registries/research_backtest_registry.dart';

void main() {
  test('research/backtest BSP options and actions are registry driven', () {
    final registry = ResearchBacktestRegistry.instance;

    expect(registry.bspTypes.map((item) => item.value),
        containsAll(<String>['1', '1p', '2', '2s', '3a', '3b', 'endpoint']));
    expect(registry.bspTypeOf('endpoint').labelForSide('buy'), '下跌终点候选');
    expect(registry.bspTypeOf('endpoint').labelForSide('sell'), '上涨终点候选');
    expect(registry.actions.map((item) => item.id),
        containsAll(<String>['bsp-features', 'ml-score', 'backtest', 'pipeline', 'seg-composite']));
  });

  test('registry maps structure and BSP type to backend rule payload', () {
    final registry = ResearchBacktestRegistry.instance;

    expect(
      registry.buildConditionPayload(
        structure: 'bi',
        layer: 9,
        side: 'buy',
        type: 'endpoint',
      ),
      <String, dynamic>{
        'source': 'bi_endpoint_candidate',
        'structure': 'bi',
        'layer': 2,
        'side': 'buy',
        'types': <String>[],
      },
    );

    expect(
      registry.buildConditionPayload(
        structure: 'nseg',
        layer: 4,
        side: 'sell',
        type: '3b',
      ),
      <String, dynamic>{
        'source': 'recursive_seg_bsp',
        'structure': 'nseg',
        'layer': 4,
        'side': 'sell',
        'types': <String>['3b'],
      },
    );
  });
}
