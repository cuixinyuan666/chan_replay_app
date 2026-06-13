#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

import validate_s4_cli_strategy_diagnostics as s4

VALIDATOR = 'tools/validate_s5_cli_strategy_rule_matrix.py'
PARENT_LEVEL = 'DAILY'
CHILD_LEVEL = 'MIN30'
SELECTED_PAIR = f'{PARENT_LEVEL}->{CHILD_LEVEL}'
SOURCE_POLICY = 'original chan.py BSP + native LevelRelation only'

RULES: dict[str, dict[str, Any]] = {
    'DAILY_2B_MIN30_1B': {
        'high_types': {'B2', 'B2s'},
        'low_types': {'B1'},
        'high_label': '2-buy',
        'low_label': '1-buy',
    },
    'DAILY_3B_MIN30_1B': {
        'high_types': {'B3', 'B3s'},
        'low_types': {'B1'},
        'high_label': '3-buy',
        'low_label': '1-buy',
    },
    'DAILY_3B_MIN30_2B': {
        'high_types': {'B3', 'B3s'},
        'low_types': {'B2', 'B2s'},
        'high_label': '3-buy',
        'low_label': '2-buy',
    },
}


def _bsp_id(level: str, bsp: dict[str, Any]) -> str:
    index = bsp.get('index', bsp.get('idx', ''))
    return f'{level}#{index}:raw={s4._raw_index(bsp)}:type={s4._bsp_type(bsp)}'


def _type_counts(bsps: list[dict[str, Any]]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for bsp in bsps:
        name = s4._bsp_type(bsp) or '<empty>'
        counts[name] = counts.get(name, 0) + 1
    return dict(sorted(counts.items()))


def _parent_raw(relation: dict[str, Any]) -> int | None:
    value = relation.get('parent_raw_index', relation.get('parentRawIndex'))
    try:
        return int(value)
    except Exception:
        return None


def _scan(rule_name: str, high_bsps: list[dict[str, Any]], low_bsps: list[dict[str, Any]], relations: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rule = RULES[rule_name]
    pair_relations = [r for r in relations if s4._relation_pair(r) == SELECTED_PAIR]
    matches: list[dict[str, Any]] = []
    for high in high_bsps:
        if s4._bsp_type(high) not in rule['high_types']:
            continue
        high_raw = s4._raw_index(high)
        for relation in pair_relations:
            parent_raw = _parent_raw(relation)
            if high_raw is not None and parent_raw is not None and high_raw != parent_raw:
                continue
            child_start, child_end = s4._relation_child_range(relation)
            if child_start is None or child_end is None:
                continue
            for low in low_bsps:
                low_raw = s4._raw_index(low)
                if low_raw is None or s4._bsp_type(low) not in rule['low_types']:
                    continue
                if child_start <= low_raw <= child_end:
                    matches.append({
                        'source_bsp_identifiers': f'{_bsp_id(PARENT_LEVEL, high)};{_bsp_id(CHILD_LEVEL, low)}',
                        'source_levels': f'{PARENT_LEVEL},{CHILD_LEVEL}',
                        'target_levels': SELECTED_PAIR,
                        'native_relation_range': f'parent={parent_raw}:child={child_start}-{child_end}',
                        'strict_step_visibility': 'current strict step frame only; no final snapshot signal confirmation',
                        'state': 'candidate',
                        'rule_mode_name': rule_name,
                    })
    return matches


def _forbidden_and_panel_rules() -> tuple[list[str], list[str]]:
    if not s4.PANEL.exists():
        return [], ['panel_missing']
    text = s4.PANEL.read_text(encoding='utf-8')
    forbidden = [name for name, pattern in s4.FORBIDDEN_DART_CALC_PATTERNS.items() if re.search(pattern, text)]
    missing_rules = [name for name in RULES if name not in text]
    return forbidden, missing_rules


def _validate(path: Path) -> dict[str, Any]:
    root = s4._load_json(path)
    meta = s4._obj(root.get('meta'), 'meta')
    frames = s4._arr(root.get('frames'), 'frames')
    relations = [r for r in s4._arr(root.get('relations'), 'relations') if isinstance(r, dict)]
    high_bsps = s4._bsps(s4._level(root, PARENT_LEVEL))
    low_bsps = s4._bsps(s4._level(root, CHILD_LEVEL))

    relation_pairs = sorted({s4._relation_pair(r) for r in relations})
    s4._expect(SELECTED_PAIR in relation_pairs, f'missing relation pair {SELECTED_PAIR}')
    s4._expect('MIN30->MIN5' in relation_pairs, 'missing relation pair MIN30->MIN5')
    s4._expect(meta.get('compact_validation_status') == 'match', 'compact_validation_status must be match')
    s4._expect(int(meta.get('compact_validation_mismatch_count') or 0) == 0, 'compact_validation_mismatch_count must be 0')
    s4._expect(meta.get('native_cchan_lv_list') is True, 'native_cchan_lv_list must be true')
    s4._expect(meta.get('fallback_to_bridge') in (False, None), 'fallback_to_bridge must be false or absent')
    s4._expect(meta.get('step_frame_format') == 'compact_v1', 'step_frame_format must be compact_v1')
    s4._expect(int(meta.get('frames_total') or 0) == len(frames), 'frames_total must match frames length')
    s4._expect(int(meta.get('frames_returned') or 0) == len(frames), 'frames_returned must match frames length')
    s4._expect(s4._frame_levels_ok(frames), 'first strict-step frame must contain DAILY and MIN30')

    forbidden, missing_panel_rules = _forbidden_and_panel_rules()
    s4._expect(not forbidden, 'forbidden Dart-side Chan calculation markers found')
    s4._expect(not missing_panel_rules, f'missing strategy rules in panel: {missing_panel_rules}')

    step = {
        'frame_source': 'native_step_frame',
        'frames_total': meta.get('frames_total'),
        'frames_returned': meta.get('frames_returned'),
        'first_frame_has_levels': [PARENT_LEVEL, CHILD_LEVEL],
        'final_snapshot_rendered_as_step': False,
    }
    common = {
        'strict_step_frame_evidence': step,
        'compact_validation_status': meta.get('compact_validation_status'),
        'compact_validation_mismatch_count': meta.get('compact_validation_mismatch_count'),
        'native_cchan_lv_list': meta.get('native_cchan_lv_list'),
        'fallback_to_bridge': bool(meta.get('fallback_to_bridge') or False),
        'forbidden_dart_calc_patterns': forbidden,
        'chan_recalculated': False,
        'dart_chan_calculation_authority': False,
    }
    matrix = []
    for name, rule in RULES.items():
        matches = _scan(name, high_bsps, low_bsps, relations)
        matrix.append({
            'strategy_rule_name': name,
            'source_policy': SOURCE_POLICY,
            'selected_relation_pair': SELECTED_PAIR,
            'high_level': PARENT_LEVEL,
            'low_level': CHILD_LEVEL,
            'high_strategy_type': rule['high_label'],
            'low_trigger_type': rule['low_label'],
            'high_strategy_types': sorted(rule['high_types']),
            'low_trigger_types': sorted(rule['low_types']),
            'high_bsp_count': len(high_bsps),
            'low_bsp_count': len(low_bsps),
            'high_type_counts': _type_counts(high_bsps),
            'low_type_counts': _type_counts(low_bsps),
            'native_relation_count_for_pair': sum(1 for r in relations if s4._relation_pair(r) == SELECTED_PAIR),
            'matched_signal_count': len(matches),
            'available_signals': len(matches),
            'source_bsp_identifiers': 'none' if not matches else [m['source_bsp_identifiers'] for m in matches[:5]],
            'no_output_diagnosis': 'no candidate matched this strategy rule in pinned strict-step fixture' if not matches else '',
            'sample_matches': matches[:5],
            **common,
        })

    return {
        'ok': True,
        'command': 'python tools/validate_s5_cli_strategy_rule_matrix.py',
        'fixture': str(path),
        'validator': VALIDATOR,
        'rules_checked': list(RULES),
        'source_policy': SOURCE_POLICY,
        'selected_relation_pair': SELECTED_PAIR,
        'relation_pairs': relation_pairs,
        'panel_strategy_rules_present': True,
        **common,
        'matrix': matrix,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('fixture', nargs='?', type=Path, default=s4.DEFAULT_FIXTURE)
    args = parser.parse_args()
    try:
        result = _validate(args.fixture)
    except Exception as exc:
        print(json.dumps({'ok': False, 'error': str(exc), 'validator': VALIDATOR}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
