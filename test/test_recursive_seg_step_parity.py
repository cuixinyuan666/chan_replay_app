from __future__ import annotations

import unittest
from datetime import datetime, timedelta
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.app.a_multilevel_native_engine import (
    _native_once_response,
    _prepare_native_chan,
)
from backend.app.a_multilevel_native_timed_recursive_engine import (
    _attach_recursive_seg_layers,
    _recursive_timed_native_step_response,
)
from backend.app.a_recursive_seg_manager import (
    RecursiveSegManager,
    RecursiveSegRuntimeState,
)


def _synthetic_bars(count: int = 180) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for index in range(count):
        day = index // 48
        slot = index % 48
        timestamp = datetime(2025, 1, 1, 9, 35) + timedelta(
            days=day,
            minutes=slot * 5,
        )
        phase = index % 12
        center = 10 + (phase if phase <= 6 else 12 - phase) * 0.35
        close = center + (0.12 if index % 2 else -0.12)
        rows.append({
            'dt': timestamp.isoformat(),
            'open': center,
            'high': max(center, close) + 0.18,
            'low': min(center, close) - 0.18,
            'close': close,
            'vol': 1000 + index,
        })
    return rows


def _without_debug_repr(value):
    if isinstance(value, dict):
        return {
            key: _without_debug_repr(item)
            for key, item in value.items()
            if key != 'repr'
        }
    if isinstance(value, list):
        return [_without_debug_repr(item) for item in value]
    return value


class RecursiveSegStepParityTest(unittest.TestCase):
    config = {
        'bi_algo': 'fx',
        'bi_fx_check': 'loss',
        'seg_algo': 'chan',
        'zs_algo': 'normal',
        'level_promoter_max_level': 3,
        'max_step_frames': 256,
    }

    def setUp(self) -> None:
        self.bars_by_level = {'MIN5': _synthetic_bars()}

    def tearDown(self) -> None:
        root = Path(__file__).resolve().parents[1] / 'python' / 'chan.py'
        for name in ('PARITY_ONCE', 'PARITY_STEP'):
            (root / f'origin_multi_{name}_5m.csv').unlink(missing_ok=True)

    def _prepare(self, code: str, *, trigger_step: bool):
        return _prepare_native_chan(
            code=code,
            level_order=['MIN5'],
            bars_by_level=self.bars_by_level,
            adjust='QFQ',
            config=self.config,
            trigger_step=trigger_step,
        )

    def test_step_frames_include_recursive_layers_and_final_matches_once(self):
        exporter, chan, kl_types, prepared = self._prepare(
            'PARITY_ONCE', trigger_step=False)
        once = _native_once_response(
            exporter=exporter,
            chan=chan,
            kl_types=kl_types,
            level_order=['MIN5'],
            bars_by_level=self.bars_by_level,
            data_meta={},
            prepared_code=prepared,
            code='PARITY',
            market_name='SH',
            adjust='QFQ',
            main='MIN5',
            clock='MIN5',
            config=self.config,
        )
        once = _attach_recursive_seg_layers(
            result=once,
            exporter=exporter,
            chan=chan,
            kl_types=kl_types,
            level_order=['MIN5'],
            config=self.config,
            timing={},
        )

        step_exporter, step_chan, step_types, step_prepared = self._prepare(
            'PARITY_STEP', trigger_step=True)
        step = _recursive_timed_native_step_response(
            exporter=step_exporter,
            chan=step_chan,
            kl_types=step_types,
            level_order=['MIN5'],
            bars_by_level=self.bars_by_level,
            data_meta={},
            prepared_code=step_prepared,
            code='PARITY',
            market_name='SH',
            adjust='QFQ',
            main='MIN5',
            clock='MIN5',
            config=self.config,
            timing={},
        )

        self.assertTrue(step['frames'])
        self.assertTrue(step['frames'][0]['levels']['MIN5']['bsp_history_seed'])
        if len(step['frames']) > 1:
            self.assertFalse(step['frames'][1]['levels']['MIN5']['bsp_history_seed'])
            self.assertEqual(
                step['frames'][1]['levels']['MIN5']['bsp'],
                step['frames'][1]['levels']['MIN5']['bsp_delta'],
            )
        for frame in (step['frames'][0], step['frames'][-1]):
            level = frame['levels']['MIN5']
            self.assertIn('seg_layers', level)
            self.assertIn('seg_zs_layers', level)
            self.assertIn('seg_bsp_layers', level)
            self.assertTrue(level['recursive_seg_meta']['stateful_incremental'])

        once_level = once['levels']['MIN5']
        step_level = step['levels']['MIN5']
        for key in ('seg_layers', 'seg_zs_layers', 'seg_bsp_layers'):
            self.assertEqual(
                _without_debug_repr(once_level[key]),
                _without_debug_repr(step_level[key]),
                key,
            )

    def test_missing_config_is_reported_in_meta_errors(self):
        payload = RecursiveSegManager(max_level=3).export(object())
        self.assertIn('config', payload['recursive_seg_meta']['errors'])
        self.assertFalse(payload['recursive_seg_meta']['classic_recursive_enabled'])

    def test_step_bsp_history_freezes_first_label_at_recognition_bar(self):
        state = RecursiveSegRuntimeState(max_level=3)
        history, delta = state.capture_bsp_history(
            layer=2,
            rows=[{'raw_index': 10, 'type': 'B1', 'is_buy': True, 'price': 9.8}],
            recognized_raw_index=12,
            recognized_time='2025-01-01T10:35:00',
        )
        self.assertEqual(len(delta), 1)
        self.assertEqual(history[0]['anchor_raw_index'], 10)
        self.assertEqual(history[0]['raw_index'], 12)
        self.assertEqual(history[0]['type'], 'B1')

        history, delta = state.capture_bsp_history(
            layer=2,
            rows=[{'raw_index': 10, 'type': 'B1p', 'is_buy': True, 'price': 9.8}],
            recognized_raw_index=13,
            recognized_time='2025-01-01T10:40:00',
        )
        self.assertEqual(delta, [])
        self.assertEqual(history[0]['type'], 'B1')
        self.assertEqual(history[0]['recognized_raw_index'], 12)


if __name__ == '__main__':
    unittest.main()
