#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FIXTURE = ROOT / 'test' / 'fixtures' / 'pinned' / 's1_600340_SH_DAILY_MIN30_MIN5_2025-09-01_2025-10-20_step_compact_v1.json'
PANEL = ROOT / 'lib' / 'ui' / 'widgets' / 'multi_level_interval_signal_panel.dart'
STRATEGY_RULE = 'DAILY_2B_MIN30_1B'
PARENT_LEVEL = 'DAILY'
CHILD_LEVEL = 'MIN30'
HIGH_TYPES = {'B2', 'B2s'}
LOW_TYPES = {'B1'}

FORBIDDEN_DART_CALC_PATTERNS = {
    'dart_check_fx': r'\bcheckFx\b|\bcheck_fx\b',
    'dart_check_bi': r'\bcheckBi\b|\bcheck_bi\b',
    'dart_build_seg': r'\bbuildSeg\b|\bbuild_seg\b',
    'dart_build_zs': r'\bbuildZs\b|\bbuild_zs\b',
    'dart_dummy_merged_bar': r'_dummyMergedBar',
}


def _fail(message: str) -> None:
    raise RuntimeError(message)


def _expect(condition: bool, message: str) -> None:
    if not condition:
        _fail(message)


def _load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        _fail(f'fixture not found: {path}')
    data = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(data, dict):
        _fail('fixture root must be an object')
    return data


def _obj(value: Any, name: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(f'{name} must be an object')
    return value


def _arr(value: Any, name: str) -> list[Any]:
    if not isinstance(value, list):
        _fail(f'{name} must be a list')
    return value


def _level(root: dict[str, Any], name: str) -> dict[str, Any]:
    levels = _obj(root.get('levels'), 'levels')
    value = levels.get(name)
    if not isinstance(value, dict):
        _fail(f'missing level {name}')
    return value


def _bsps(level_payload: dict[str, Any]) -> list[dict[str, Any]]:
    raw = level_payload.get('bsp') or level_payload.get('bsps') or []
    if not isinstance(raw, list):
        _fail('level bsp payload must be a list')
    return [item for item in raw if isinstance(item, dict)]


def _bsp_type(bsp: dict[str, Any]) -> str:
    return str(bsp.get('type') or bsp.get('bsp_type') or '').strip()


def _raw_index(bsp: dict[str, Any]) -> int | None:
    value = bsp.get('raw_index', bsp.get('rawIndex'))
    try:
        return int(value)
    except Exception:
        return None


def _relation_pair(relation: dict[str, Any]) -> str:
    parent = relation.get('parent_level') or relation.get('parentLevel') or ''
    child = relation.get('child_level') or relation.get('childLevel') or ''
    return f'{parent}->{child}'


def _relation_child_range(relation: dict[str, Any]) -> tuple[int | None, int | None]:
    start = relation.get('child_start_raw_index', relation.get('childStartRawIndex'))
    end = relation.get('child_end_raw_index', relation.get('childEndRawIndex'))
    try:
        return int(start), int(end)
    except Exception:
        return None, None


def _frame_levels_ok(frames: list[Any]) -> bool:
    if not frames:
        return False
    first = frames[0]
    if not isinstance(first, dict):
        return False
    levels = first.get('levels')
    return isinstance(levels, dict) and PARENT_LEVEL in levels and CHILD_LEVEL in levels


def _scan_for_strategy_candidates(
    high_bsps: list[dict[str, Any]],
    low_bsps: list[dict[str, Any]],
    relations: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []
    pair_relations = [r for r in relations if _relation_pair(r) == f'{PARENT_LEVEL}->{CHILD_LEVEL}']
    for high in high_bsps:
        if _bsp_type(high) not in HIGH_TYPES:
            continue
        high_raw = _raw_index(high)
        for relation in pair_relations:
            # The pinned S1 relation schema maps parent raw index to one child raw range.
            parent_raw = relation.get('parent_raw_index', relation.get('parentRawIndex'))
            try:
                parent_raw_i = int(parent_raw)
            except Exception:
                parent_raw_i = None
            if high_raw is not None and parent_raw_i is not None and high_raw != parent_raw_i:
                continue
            child_start, child_end = _relation_child_range(relation)
            if child_start is None or child_end is None:
                continue
            for low in low_bsps:
                low_raw = _raw_index(low)
                if _bsp_type(low) in LOW_TYPES and low_raw is not None and child_start <= low_raw <= child_end:
                    candidates.append({
                        'high_type': _bsp_type(high),
                        'high_raw_index': high_raw,
                        'low_type': _bsp_type(low),
                        'low_raw_index': low_raw,
                        'relation_pair': _relation_pair(relation),
                        'child_range': f'{child_start}-{child_end}',
                    })
    return candidates


def _validate(path: Path) -> dict[str, Any]:
    root = _load_json(path)
    meta = _obj(root.get('meta'), 'meta')
    frames = _arr(root.get('frames'), 'frames')
    relations_raw = _arr(root.get('relations'), 'relations')
    relations = [r for r in relations_raw if isinstance(r, dict)]
    parent_level = _level(root, PARENT_LEVEL)
    child_level = _level(root, CHILD_LEVEL)
    high_bsps = _bsps(parent_level)
    low_bsps = _bsps(child_level)

    relation_pairs = sorted({_relation_pair(r) for r in relations})
    expected_pair = f'{PARENT_LEVEL}->{CHILD_LEVEL}'
    _expect(expected_pair in relation_pairs, f'missing relation pair {expected_pair}')
    _expect('MIN30->MIN5' in relation_pairs, 'missing relation pair MIN30->MIN5')
    _expect(meta.get('compact_validation_status') == 'match', 'compact_validation_status must be match')
    _expect(int(meta.get('compact_validation_mismatch_count') or 0) == 0, 'compact_validation_mismatch_count must be 0')
    _expect(meta.get('native_cchan_lv_list') is True, 'native_cchan_lv_list must be true')
    _expect(meta.get('fallback_to_bridge') in (False, None), 'fallback_to_bridge must be false or absent')
    _expect(meta.get('step_frame_format') == 'compact_v1', 'step_frame_format must be compact_v1')
    _expect(int(meta.get('frames_total') or 0) == len(frames), 'frames_total must match frames length')
    _expect(int(meta.get('frames_returned') or 0) == len(frames), 'frames_returned must match frames length')
    _expect(_frame_levels_ok(frames), 'first strict-step frame must contain DAILY and MIN30')

    candidates = _scan_for_strategy_candidates(high_bsps, low_bsps, relations)
    no_output = len(candidates) == 0
    diagnosis = 'no candidate matched current strategy rule in pinned strict-step fixture' if no_output else 'strategy candidates found'

    forbidden_calc: list[str] = []
    if PANEL.exists():
        panel_text = PANEL.read_text(encoding='utf-8')
        forbidden_calc = [name for name, pattern in FORBIDDEN_DART_CALC_PATTERNS.items() if re.search(pattern, panel_text)]
    _expect(not forbidden_calc, 'forbidden Dart-side Chan calculation markers found')

    return {
        'ok': True,
        'command': 'python tools/validate_s4_cli_strategy_diagnostics.py',
        'fixture': str(path),
        'strategy_rule_name': STRATEGY_RULE,
        'source_policy': 'original chan.py BSP + native LevelRelation only',
        'target_levels': expected_pair,
        'relation_pairs': relation_pairs,
        'native_relation_count_for_pair': sum(1 for r in relations if _relation_pair(r) == expected_pair),
        'high_level': PARENT_LEVEL,
        'low_level': CHILD_LEVEL,
        'high_strategy_types': sorted(HIGH_TYPES),
        'low_trigger_types': sorted(LOW_TYPES),
        'high_bsp_count': len(high_bsps),
        'low_bsp_count': len(low_bsps),
        'available_signals': len(candidates),
        'source_bsp_identifiers': 'none' if no_output else candidates[:3],
        'no_output_diagnosis': diagnosis,
        'strict_step_frame_evidence': {
            'frame_source': 'native_step_frame',
            'frames_total': meta.get('frames_total'),
            'frames_returned': meta.get('frames_returned'),
            'first_frame_has_levels': [PARENT_LEVEL, CHILD_LEVEL],
            'final_snapshot_rendered_as_step': False,
        },
        'compact_validation_status': meta.get('compact_validation_status'),
        'compact_validation_mismatch_count': meta.get('compact_validation_mismatch_count'),
        'native_cchan_lv_list': meta.get('native_cchan_lv_list'),
        'fallback_to_bridge': bool(meta.get('fallback_to_bridge') or False),
        'forbidden_dart_calc_patterns': forbidden_calc,
        'chan_recalculated': False,
        'dart_chan_calculation_authority': False,
        'validator': 'tools/validate_s4_cli_strategy_diagnostics.py',
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('fixture', nargs='?', type=Path, default=DEFAULT_FIXTURE)
    args = parser.parse_args()
    try:
        result = _validate(args.fixture)
    except Exception as exc:
        print(json.dumps({'ok': False, 'error': str(exc), 'validator': 'tools/validate_s4_cli_strategy_diagnostics.py'}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
