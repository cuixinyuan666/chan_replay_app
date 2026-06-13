#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FIXTURE = ROOT / 'test' / 'fixtures' / 'pinned' / 's1_600340_SH_DAILY_MIN30_MIN5_2025-09-01_2025-10-20_step_compact_v1.json'
REQUIRED_LEVELS = ['DAILY', 'MIN30', 'MIN5']


class FixtureError(RuntimeError):
    pass


def _fail(message: str) -> None:
    raise FixtureError(message)


def _assert(condition: bool, message: str) -> None:
    if not condition:
        _fail(message)


def _load(path: Path) -> dict[str, Any]:
    if not path.exists():
        _fail(f'fixture not found: {path}')
    data = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(data, dict):
        _fail('fixture root must be an object')
    return data


def _as_dict(value: Any, name: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(f'{name} must be an object')
    return value


def _as_list(value: Any, name: str) -> list[Any]:
    if not isinstance(value, list):
        _fail(f'{name} must be a list')
    return value


def _level_payload(root: dict[str, Any], level: str) -> dict[str, Any]:
    levels = _as_dict(root.get('levels'), 'levels')
    payload = levels.get(level)
    if not isinstance(payload, dict):
        _fail(f'levels.{level} must exist')
    return payload


def _count_level(root: dict[str, Any], level: str) -> dict[str, int]:
    payload = _level_payload(root, level)
    return {
        'raw': len(payload.get('bars') or payload.get('raw_bars') or []),
        'merged': len(payload.get('merged_bars') or []),
        'fx': len(payload.get('fx') or []),
        'bi': len(payload.get('bi') or []),
        'seg': len(payload.get('seg') or []),
        'zs': len(payload.get('zs') or []),
        'bsp': len(payload.get('bsp') or []),
    }


def _validate(path: Path) -> dict[str, Any]:
    root = _load(path)
    meta = _as_dict(root.get('meta'), 'meta')
    levels_obj = _as_dict(root.get('levels'), 'levels')
    frames = _as_list(root.get('frames'), 'frames')
    relations = _as_list(root.get('relations'), 'relations')

    for level in REQUIRED_LEVELS:
        _assert(level in levels_obj, f'missing level: {level}')

    _assert(meta.get('fixture') is True, 'meta.fixture must be true')
    _assert(meta.get('fixture_kind') == 'pinned_s1_multilevel_step_compact_v1', 'unexpected fixture_kind')
    _assert(meta.get('compact_validation_status') == 'match', 'compact_validation_status must be match')
    _assert(int(meta.get('compact_validation_mismatch_count') or 0) == 0, 'compact_validation_mismatch_count must be 0')
    _assert(meta.get('native_cchan_lv_list') is True, 'native_cchan_lv_list must be true')
    _assert(meta.get('fallback_to_bridge') in (False, None), 'fallback_to_bridge must be false or absent')
    _assert(meta.get('step_frame_format') == 'compact_v1', 'step_frame_format must be compact_v1')
    _assert(meta.get('frames_total') == 29, 'frames_total must be 29 for pinned S1 fixture')
    _assert(meta.get('frames_returned') == 29, 'frames_returned must be 29 for pinned S1 fixture')
    _assert(len(frames) == 29, 'frames length must be 29')
    _assert(len(relations) >= 2, 'relations must contain native parent-child ranges')

    relation_pairs = {f"{r.get('parent_level') or r.get('parentLevel')}->{r.get('child_level') or r.get('childLevel')}" for r in relations if isinstance(r, dict)}
    _assert('DAILY->MIN30' in relation_pairs, 'missing DAILY->MIN30 relation pair')
    _assert('MIN30->MIN5' in relation_pairs, 'missing MIN30->MIN5 relation pair')

    first_frame = _as_dict(frames[0], 'frames[0]')
    frame_levels = _as_dict(first_frame.get('levels'), 'frames[0].levels')
    for level in REQUIRED_LEVELS:
        _assert(level in frame_levels, f'frames[0] missing level {level}')

    level_counts = {level: _count_level(root, level) for level in REQUIRED_LEVELS}
    return {
        'ok': True,
        'fixture': str(path),
        'fixture_size_bytes': path.stat().st_size,
        'levels': REQUIRED_LEVELS,
        'frames_total': meta.get('frames_total'),
        'frames_returned': meta.get('frames_returned'),
        'compact_validation_status': meta.get('compact_validation_status'),
        'compact_validation_mismatch_count': meta.get('compact_validation_mismatch_count'),
        'native_cchan_lv_list': meta.get('native_cchan_lv_list'),
        'fallback_to_bridge': bool(meta.get('fallback_to_bridge') or False),
        'relation_pairs': sorted(relation_pairs),
        'level_counts': level_counts,
        'validator': 'tools/validate_pinned_s1_fixture.py',
        'chan_recalculated': False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('fixture', nargs='?', type=Path, default=DEFAULT_FIXTURE)
    args = parser.parse_args()
    try:
        result = _validate(args.fixture)
    except Exception as exc:
        print(json.dumps({'ok': False, 'error': str(exc)}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
