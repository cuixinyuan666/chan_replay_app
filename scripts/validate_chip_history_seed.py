#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backend'))

from app.a_chip_history_seed import attach_chip_history  # noqa: E402


def bar(dt: str, close: float, volume: float) -> dict[str, Any]:
    return {
        'dt': dt,
        'time': dt,
        'open': close,
        'high': close + 0.5,
        'low': close - 0.5,
        'close': close,
        'vol': volume,
        'volume': volume,
    }


def main() -> int:
    visible = [
        bar('2026-01-01 00:00:00', 12.0, 300.0),
        bar('2026-01-02 00:00:00', 13.0, 400.0),
    ]
    history = [
        bar('2025-12-29 00:00:00', 10.0, 100.0),
        bar('2025-12-30 00:00:00', 11.0, 200.0),
        visible[0],
        visible[1],
    ]

    def fake_load_bars(**_: Any) -> list[dict[str, Any]]:
        return [dict(row) for row in history]

    result = {
        'ok': True,
        'main_level': 'DAILY',
        'levels': {'DAILY': {'bars': [dict(row) for row in visible], 'meta': {}}},
        'relations': [],
        'frames': [],
        'meta': {},
    }
    patched = attach_chip_history(
        result,
        payload={
            'symbol': '600340',
            'market': 'SH',
            'lv_list': ['DAILY'],
            'adjust': 'QFQ',
            'start': '2026-01-01',
            'end': '2026-01-02',
            'count': 50000,
        },
        config={'chip_history_seed_bucket_count': 32},
        load_bars=fake_load_bars,
    )
    bars = patched['levels']['DAILY']['bars']
    assert len(bars) == len(visible), 'visible c-d bar count changed'
    assert bars[0].get('chip_history_seed') is True, 'first visible bar lacks seed'
    assert 'chip_tick_bins' in bars[0], 'seed must use chip_tick_bins'
    assert 'chip_tick_bins' not in bars[1], 'later bars should stay normal OHLCV'
    total = sum(float(v) for v in bars[0]['chip_tick_bins']['w'])
    assert abs(total - 600.0) < 1e-6, f'expected baseline+first volume=600, got {total}'
    meta = patched['meta']['chip_history_baseline_levels']['DAILY']
    assert meta['baseline_bar_count'] == 2, meta
    assert meta['seed_includes_first_visible_bar'] is True, meta
    print('OK chip history seed keeps c-d visible and calculates b-c state')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
