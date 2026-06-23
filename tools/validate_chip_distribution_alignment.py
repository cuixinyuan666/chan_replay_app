#!/usr/bin/env python3
"""Offline contract checks for same-level chip distribution alignment."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from backend.app.a_chip_distribution_service import calculate_chip_distribution  # noqa: E402

LEVELS = ['DAILY', 'MIN60', 'MIN30', 'MIN15', 'MIN5', 'MIN1']


def bar(t: str, vol: float, price: float, idx: int) -> dict[str, Any]:
    return {'time': t, 'dt': t, 'raw_index': idx, 'open': price, 'high': price, 'low': price, 'close': price, 'vol': vol, 'volume': vol}


def tick_bar(t: str, prices: list[float], sell: list[float], buy: list[float], total: list[float]) -> dict[str, Any]:
    return {
        'time': t,
        'dt': t,
        'raw_index': 0,
        'open': prices[0],
        'high': max(prices),
        'low': min(prices),
        'close': prices[-1],
        'vol': sum(total),
        'volume': sum(total),
        'chip_tick_bins': {'p': prices, 's': sell, 'b': buy, 'w': total},
    }


def total(result: dict[str, Any]) -> float:
    return float(result['chip_distribution_state']['total_weight'])


def meta(result: dict[str, Any]) -> dict[str, Any]:
    return result['chip_distribution_meta']


def close(left: float, right: float, message: str) -> None:
    if not math.isclose(left, right, rel_tol=1e-9, abs_tol=1e-9):
        raise AssertionError(f'{message}: {left!r} != {right!r}')


def assert_true(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def test_same_level_volume_and_listing_baseline() -> None:
    rows = [bar('2020-01-01', 100, 10, 0), bar('2024-01-01', 200, 10, 1), bar('2024-12-31', 10000, 20, 2)]
    for level in LEVELS:
        result = calculate_chip_distribution({
            'symbol': '000001', 'market': 'SZ', 'level': level, 'bars': rows,
            'replay_start': '2024-01-01', 'replay_end': '2024-12-31',
            'target_time': '2024-01-01', 'bucket_count': 16,
            'settings_version': f'validate-{level}',
        })
        m = meta(result)
        assert_true(result['ok'] is True, f'{level} should calculate')
        assert_true(m['volume_source_level'] == level, f'{level} must use its own vol')
        assert_true(m['volume_source_kind'] == 'same_level_bars', f'{level} should use same-level bars')
        assert_true(m['chip_calc_start'] == '2020-01-01', f'{level} must start from listing/earliest history')
        assert_true(m['baseline_bar_count'] == 1, f'{level} c-state must include b->c baseline')
        close(total(result), 300.0, f'{level} must not include future volume')


def test_once_step_consistency_and_guard() -> None:
    rows = [bar('2020-01-01', 100, 10, 0), bar('2024-01-01', 200, 10, 1), bar('2024-12-31', 10000, 30, 2)]
    common = {
        'symbol': '000001', 'market': 'SZ', 'level': 'MIN1', 'bars': rows,
        'replay_start': '2024-01-01', 'replay_end': '2024-12-31',
        'target_time': '2024-01-01', 'bucket_count': 16,
    }
    once = calculate_chip_distribution({**common, 'mode': 'once', 'settings_version': 'once-contract'})
    step = calculate_chip_distribution({**common, 'mode': 'step', 'settings_version': 'step-contract'})
    close(total(once), total(step), 'once and step must match at same t')
    close(total(step), 300.0, 'step at c must only include b->c volume')

    blocked = calculate_chip_distribution({
        **common, 'mode': 'step', 'target_time': '2024-12-31',
        'max_allowed_time': '2024-01-01', 'settings_version': 'blocked-contract',
    })
    assert_true(meta(blocked)['future_guard_passed'] is False, 'future target should be flagged')
    close(total(blocked), 300.0, 'blocked target must fold only max_allowed_time rows')


def test_tick_min1_uses_transactions_and_rejects_fallback() -> None:
    result = calculate_chip_distribution({
        'symbol': '000001', 'market': 'SZ', 'level': 'TICK_MIN1',
        'bars': [
            tick_bar('2024-01-01 09:30:00', [10.00, 10.01], [2.0, 0.0], [3.0, 5.0], [5.0, 5.0]),
            tick_bar('2024-01-01 09:31:00', [10.02], [1.0], [4.0], [5.0]),
        ],
        'replay_start': '2024-01-01', 'replay_end': '2024-01-01 09:31:00',
        'target_time': '2024-01-01 09:31:00', 'bucket_count': 16,
        'settings_version': 'tick-contract',
    })
    m = meta(result)
    assert_true(result['ok'] is True, 'TICK_MIN1 should calculate when tick bins exist')
    assert_true(m['volume_source_level'] == 'TICK_MIN1', 'TICK_MIN1 source level must be TICK_MIN1')
    assert_true(m['volume_source_kind'] == 'tick_transactions', 'TICK_MIN1 must use transactions')
    assert_true(m['distribution_model'] == 'tick_exact_price_v1', 'TICK_MIN1 must use exact tick price model')
    close(total(result), 15.0, 'TICK_MIN1 total must equal transaction volume')

    empty = calculate_chip_distribution({'symbol': '000001', 'market': 'SZ', 'level': 'TICK_MIN1', 'bars': [], 'settings_version': 'tick-empty'})
    assert_true(empty['ok'] is False and empty['status'] == 'unavailable', 'empty TICK_MIN1 should be unavailable')
    assert_true(empty['reason'] == 'no_tick_trade_data' and empty['fallback_used'] is False, 'TICK_MIN1 must not fallback to MIN1')

    min1_like = calculate_chip_distribution({'symbol': '000001', 'market': 'SZ', 'level': 'TICK_MIN1', 'bars': [bar('2024-01-01 09:30:00', 100, 10, 0)], 'settings_version': 'tick-min1-like'})
    assert_true(min1_like['ok'] is False, 'TICK_MIN1 should reject MIN1-like bars')
    assert_true(min1_like['reason'] == 'tick_bins_missing_no_min1_fallback', 'TICK_MIN1 missing bins should be explicit')


def test_bucket_stability() -> None:
    rows = [bar('2020-01-01', 100, 10, 0), bar('2024-01-01', 200, 12, 1), bar('2024-12-31', 300, 30, 2)]
    base = {'symbol': '000001', 'market': 'SZ', 'level': 'MIN5', 'bars': rows, 'replay_start': '2024-01-01', 'replay_end': '2024-12-31', 'bucket_count': 16}
    early = calculate_chip_distribution({**base, 'target_time': '2024-01-01', 'settings_version': 'bucket-early'})
    late = calculate_chip_distribution({**base, 'target_time': '2024-12-31', 'settings_version': 'bucket-late'})
    for key in ('bucket_policy', 'bucket_low', 'bucket_high', 'bucket_step', 'bucket_count'):
        assert_true(meta(early)[key] == meta(late)[key], f'{key} should stay stable')
    assert_true(meta(early)['bucket_rule_stable_in_session'] is True, 'bucket rule should be marked stable')


def main() -> int:
    for test in (test_same_level_volume_and_listing_baseline, test_once_step_consistency_and_guard, test_tick_min1_uses_transactions_and_rejects_fallback, test_bucket_stability):
        test()
        print(f'PASS: {test.__name__}')
    print('PASS: chip distribution alignment contract')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
