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


def validate_daily_seed() -> None:
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
    assert len(bars) == len(visible), 'DAILY visible c-d bar count changed'
    assert bars[0].get('chip_history_seed') is True, 'DAILY first visible bar lacks seed'
    assert 'chip_tick_bins' in bars[0], 'DAILY seed must use chip_tick_bins'
    assert 'chip_tick_bins' not in bars[1], 'DAILY later bars should stay normal OHLCV'
    total = sum(float(v) for v in bars[0]['chip_tick_bins']['w'])
    assert abs(total - 600.0) < 1e-6, f'DAILY expected baseline+first volume=600, got {total}'
    meta = patched['meta']['chip_history_baseline_levels']['DAILY']
    assert meta['baseline_bar_count'] == 2, meta
    assert meta['baseline_source_level'] == 'DAILY', meta
    assert meta['seed_includes_first_visible_bar'] is True, meta


def validate_tick_min1_uses_prior_daily_baseline() -> None:
    visible = [
        {
            **bar('2026-06-22 09:25:00', 16.49, 645.0),
            'chip_tick_bins': {'p': [16.49], 's': [0.0], 'b': [645.0], 'w': [645.0]},
        },
        {
            **bar('2026-06-22 09:26:00', 16.50, 300.0),
            'chip_tick_bins': {'p': [16.50], 's': [100.0], 'b': [200.0], 'w': [300.0]},
        },
    ]
    daily_history = [
        bar('2026-06-18 00:00:00', 15.0, 1000.0),
        bar('2026-06-19 00:00:00', 15.5, 2000.0),
        bar('2026-06-22 00:00:00', 16.0, 999999.0),
    ]
    calls: list[dict[str, Any]] = []

    def fake_load_bars(**kwargs: Any) -> list[dict[str, Any]]:
        calls.append(kwargs)
        return [dict(row) for row in daily_history]

    result = {
        'ok': True,
        'main_level': 'TICK_MIN1',
        'levels': {'TICK_MIN1': {'bars': [dict(row) for row in visible], 'meta': {}}},
        'relations': [],
        'frames': [],
        'meta': {},
    }
    patched = attach_chip_history(
        result,
        payload={
            'symbol': '920126',
            'market': 'SH',
            'lv_list': ['TICK_MIN1'],
            'adjust': 'QFQ',
            'start': '2026-06-22',
            'end': '2026-06-24',
            'count': 50000,
        },
        config={'chip_history_seed_bucket_count': 32},
        load_bars=fake_load_bars,
    )
    assert calls, 'TICK_MIN1 baseline should call provider'
    assert calls[0]['period'] == 'DAILY', calls[0]
    assert calls[0]['end'] == '2026-06-21', calls[0]
    bars = patched['levels']['TICK_MIN1']['bars']
    assert len(bars) == len(visible), 'TICK_MIN1 visible c-d bar count changed'
    assert bars[0].get('chip_history_seed') is True, 'TICK_MIN1 first visible bar lacks seed'
    assert bars[0]['chip_tick_bins']['source'] == 'backend_chip_history_seed'
    assert bars[1]['chip_tick_bins']['source'] != 'backend_chip_history_seed', 'later exact tick bins should stay untouched'
    total = sum(float(v) for v in bars[0]['chip_tick_bins']['w'])
    assert abs(total - 3645.0) < 1e-6, f'TICK_MIN1 expected prior daily baseline+first tick volume=3645, got {total}'
    meta = patched['meta']['chip_history_baseline_levels']['TICK_MIN1']
    assert meta['baseline_source_level'] == 'DAILY', meta
    assert meta['baseline_bar_count'] == 2, meta
    assert meta['seed_includes_first_visible_bar'] is True, meta


def main() -> int:
    validate_daily_seed()
    validate_tick_min1_uses_prior_daily_baseline()
    print('OK chip history seed keeps c-d visible and calculates b-c state')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
