from __future__ import annotations

import math
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.app.a_rhythm_overlay import RHYTHM_RATIO, with_level_rhythm_overlay


def _assert_close(actual: float, expected: float, *, label: str, eps: float = 1e-9) -> None:
    if abs(float(actual) - float(expected)) > eps:
        raise AssertionError(f'{label}: expected {expected}, got {actual}')


def _sample_payload(*, d_price: float = 24.0) -> dict[str, Any]:
    """Minimal parent bi + child fx structure for trainer-rhythm parity checks.

    Parent: UP bi from raw 0 to raw 3.
    Children: bottom->top->bottom->top->bottom, so the last down child crosses
    the parent right edge and must still be included, matching a_replay_trainer.py.
    """
    threshold = 14.0 + (20.0 - 14.0) * RHYTHM_RATIO
    return {
        'bars': [
            {'dt': '2024-01-01', 'high': 10.5, 'low': 9.8},
            {'dt': '2024-01-02', 'high': 20.5, 'low': 18.0},
            {'dt': '2024-01-03', 'high': 15.0, 'low': 13.8},
            {'dt': '2024-01-04', 'high': max(d_price + 0.2, threshold + 0.1), 'low': d_price - 2.0},
            {'dt': '2024-01-05', 'high': 16.5, 'low': 15.8},
        ],
        'fx': [
            {'index': 0, 'raw_index': 0, 'type': 'bottom', 'price': 10.0},
            {'index': 1, 'raw_index': 1, 'type': 'top', 'price': 20.0},
            {'index': 2, 'raw_index': 2, 'type': 'bottom', 'price': 14.0},
            {'index': 3, 'raw_index': 3, 'type': 'top', 'price': d_price},
            {'index': 4, 'raw_index': 4, 'type': 'bottom', 'price': 16.0},
        ],
        'bi': [
            {
                'index': 0,
                'start_raw_index': 0,
                'end_raw_index': 3,
                'start_price': 10.0,
                'end_price': d_price,
                'direction': 'UP',
            }
        ],
        'seg': [],
        'seg_layers': {'2': []},
        'meta': {},
    }


def _overlay(mode: str, *, d_price: float = 24.0) -> dict[str, Any]:
    return with_level_rhythm_overlay(
        'DAILY',
        _sample_payload(d_price=d_price),
        {'enable_rhythm_1382': True, 'rhythm_calc_mode': mode},
    )


def validate_rhythm_price_not_threshold() -> None:
    result = _overlay('transition', d_price=24.0)
    lines = result.get('rhythm_lines') or []
    hits = result.get('rhythm_hits') or []
    if len(lines) != 1:
        raise AssertionError(f'expected 1 rhythm line, got {len(lines)}')
    if not hits:
        raise AssertionError('expected at least one 1.382 hit')

    line = lines[0]
    threshold = 14.0 + (20.0 - 14.0) * RHYTHM_RATIO
    rhythm_price = 24.0 - (24.0 - 10.0) * ((20.0 - 14.0) / (20.0 - 10.0))
    _assert_close(line['threshold'], threshold, label='threshold')
    _assert_close(line['price'], rhythm_price, label='rhythm_price')
    _assert_close(line['y1'], rhythm_price, label='y1')
    _assert_close(line['y2'], rhythm_price, label='y2')
    if math.isclose(float(line['price']), float(line['threshold'])):
        raise AssertionError('rhythm line price must not be the 1.382 threshold')
    if line.get('level') != 'DAILY':
        raise AssertionError(f'line.level must remain chart timeframe, got {line.get("level")}')
    if line.get('source_kind') != 'fx' or line.get('parent_level') != 'bi':
        raise AssertionError(f'unexpected mapping: {line.get("source_kind")}->{line.get("parent_level")}')
    if hits[0].get('level') != 'DAILY':
        raise AssertionError(f'hit.level must remain chart timeframe, got {hits[0].get("level")}')
    if hits[0].get('raw_index') != 3:
        raise AssertionError(f'first hit must start after C and land on raw 3, got {hits[0].get("raw_index")}')


def validate_calc_mode_semantics() -> None:
    # d=21 is stronger than b=20, but weaker than 1.382 threshold ~=22.292.
    # Therefore transition should pass, strict1382 should fail.
    transition = _overlay('transition', d_price=21.0)
    strict = _overlay('strict1382', d_price=21.0)
    normal_weak = _overlay('normal', d_price=19.0)
    transition_weak = _overlay('transition', d_price=19.0)
    if not transition.get('rhythm_lines'):
        raise AssertionError('transition must allow d >= b even when d < 1.382 threshold')
    if strict.get('rhythm_lines'):
        raise AssertionError('strict1382 must reject d below 1.382 threshold')
    if not normal_weak.get('rhythm_lines'):
        raise AssertionError('normal must allow weak retrace')
    if transition_weak.get('rhythm_lines'):
        raise AssertionError('transition must reject d below b')


def main() -> None:
    validate_rhythm_price_not_threshold()
    validate_calc_mode_semantics()
    print('validate_rhythm_trainer_parity: OK')


if __name__ == '__main__':
    main()
