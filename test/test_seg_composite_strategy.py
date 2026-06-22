from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.app.a_seg_composite_strategy import (  # noqa: E402
    run_seg_composite_backtest,
    scan_seg_composite_events,
)


def _analysis() -> dict:
    bars = [
        {'index': i, 'dt': f'2025-01-0{i + 1}T09:35:00', 'open': 10 + i, 'close': 10.5 + i}
        for i in range(6)
    ]
    frames = []
    for visible in range(1, 7):
        grouped = {'2': [], '3': []}
        candidates = {'2': [], '3': []}
        if visible >= 2:
            grouped = {
                '2': [{'raw_index': 1, 'type': 'B1', 'is_buy': True, 'confirmed': True}],
                '3': [{'raw_index': 1, 'type': 'B3a', 'is_buy': True, 'confirmed': True}],
            }
        if visible >= 4:
            grouped = {
                '2': [*grouped['2'], {'raw_index': 3, 'type': 'S2', 'is_buy': False, 'confirmed': True}],
                '3': [*grouped['3'], {'raw_index': 3, 'type': 'S3b', 'is_buy': False, 'confirmed': True}],
            }
        candidates['2'].append({'raw_index': visible - 1, 'type': 'SEG2_B', 'is_buy': True, 'derived': True})
        frames.append({
            'levels': {
                'MIN5': {
                    'visible_count': visible,
                    'seg_bsp_layers': grouped,
                    'seg_endpoint_bsp_layers': candidates,
                },
            },
        })
    return {'main_level': 'MIN5', 'levels': {'MIN5': {'bars': bars}}, 'frames': frames}


class SegCompositeStrategyTest(unittest.TestCase):
    def test_scans_authoritative_multilayer_and_rule_as_of_each_frame(self):
        rule = {
            'conditions': [
                {'layer': 3, 'side': 'buy', 'types': ['3a']},
                {'layer': 2, 'side': 'buy', 'types': ['1']},
            ],
        }
        events = scan_seg_composite_events(_analysis(), level='MIN5', rule=rule)
        self.assertEqual([event['raw_index'] for event in events], [1])
        self.assertEqual(events[0]['signature'], ['3段3a', '2段1'])

    def test_backtest_uses_next_bar_and_composite_exit(self):
        result = run_seg_composite_backtest(
            _analysis(),
            level='MIN5',
            entry_rule={'conditions': [
                {'layer': 3, 'side': 'buy', 'types': ['3a']},
                {'layer': 2, 'side': 'buy', 'types': ['1']},
            ]},
            exit_rule={'conditions': [
                {'layer': 3, 'side': 'sell', 'types': ['3b']},
                {'layer': 2, 'side': 'sell', 'types': ['2']},
            ]},
            options={'fee_bps': 0, 'slippage_bps': 0},
        )
        self.assertEqual(result['summary']['trade_count'], 1)
        trade = result['trades'][0]
        self.assertEqual(trade['entry_index'], 2)
        self.assertEqual(trade['exit_index'], 4)
        self.assertEqual(trade['exit_reason'], 'seg_composite_exit')
        self.assertFalse(result['meta']['endpoint_candidates_used'])

    def test_newer_opposite_point_replaces_older_matching_state(self):
        events = scan_seg_composite_events(
            _analysis(),
            level='MIN5',
            rule={'dedupe': False, 'conditions': [
                {'layer': 2, 'side': 'buy', 'types': ['1']},
            ]},
        )
        self.assertEqual([event['raw_index'] for event in events], [1, 2])


if __name__ == '__main__':
    unittest.main()
