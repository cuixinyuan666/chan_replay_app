#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import validate_s4_cli_strategy_diagnostics as s4
import validate_s5_cli_strategy_rule_matrix as s5

VALIDATOR = 'tools/validate_s6_strategy_signal_sample_coverage.py'
PARENT_LEVEL = 'DAILY'
CHILD_LEVEL = 'MIN30'


def _frame_levels(frame: dict[str, Any]) -> dict[str, Any]:
    raw = frame.get('levels')
    return raw if isinstance(raw, dict) else {}


def _frame_relations(frame: dict[str, Any], root_relations: list[dict[str, Any]]) -> list[dict[str, Any]]:
    raw = frame.get('relations')
    if isinstance(raw, list):
        return [item for item in raw if isinstance(item, dict)]
    return root_relations


def _bsps_from_levels(levels: dict[str, Any], level: str) -> list[dict[str, Any]]:
    payload = levels.get(level)
    if not isinstance(payload, dict):
        return []
    return s4._bsps(payload)


def _root_no_output(path: Path) -> tuple[dict[str, Any], list[str]]:
    report = s5._validate(path)
    no_output_rules = []
    for item in report.get('matrix', []):
        if isinstance(item, dict) and int(item.get('matched_signal_count') or 0) == 0:
            no_output_rules.append(str(item.get('strategy_rule_name')))
    return report, no_output_rules


def _scan_scope(scope: str, frame_index: int | None, levels: dict[str, Any], relations: list[dict[str, Any]]) -> list[dict[str, Any]]:
    high_bsps = _bsps_from_levels(levels, PARENT_LEVEL)
    low_bsps = _bsps_from_levels(levels, CHILD_LEVEL)
    evidence: list[dict[str, Any]] = []
    for rule_name in s5.RULES:
        matches = s5._scan(rule_name, high_bsps, low_bsps, relations)
        for match in matches:
            evidence.append({
                'scope': scope,
                'frame_index': frame_index,
                'rule_mode_name': rule_name,
                'source_bsp_identifiers': match.get('source_bsp_identifiers'),
                'source_target_levels': match.get('target_levels'),
                'native_relation_range': match.get('native_relation_range'),
                'strict_step_visibility': match.get('strict_step_visibility'),
                'state': match.get('state'),
            })
    return evidence


def _matched_output_candidates(root: dict[str, Any]) -> list[dict[str, Any]]:
    root_relations = [r for r in s4._arr(root.get('relations'), 'relations') if isinstance(r, dict)]
    evidence: list[dict[str, Any]] = []
    levels = root.get('levels')
    if isinstance(levels, dict):
        evidence.extend(_scan_scope('root_snapshot', None, levels, root_relations))
    frames = s4._arr(root.get('frames'), 'frames')
    for idx, frame in enumerate(frames):
        if not isinstance(frame, dict):
            continue
        evidence.extend(_scan_scope('strict_step_frame', idx, _frame_levels(frame), _frame_relations(frame, root_relations)))
    return evidence


def _validate(path: Path) -> dict[str, Any]:
    root = s4._load_json(path)
    s5_report, no_output_rules = _root_no_output(path)
    matched = _matched_output_candidates(root)
    matched_sample = matched[0] if matched else None
    no_output_ok = bool(no_output_rules)
    matched_ok = matched_sample is not None
    ok = no_output_ok and matched_ok
    return {
        'ok': ok,
        'command': 'python tools/validate_s6_strategy_signal_sample_coverage.py',
        'fixture': str(path),
        'validator': VALIDATOR,
        'source_policy': 'original chan.py BSP + native LevelRelation only',
        'no_output_path': {
            'ok': no_output_ok,
            'rules': no_output_rules,
            'diagnosis': 'pinned fixture root snapshot has no matched strategy output for listed rules',
            'strict_step_frame_evidence': s5_report.get('strict_step_frame_evidence'),
        },
        'matched_output_path': {
            'ok': matched_ok,
            'matched_sample_count': len(matched),
            'sample': matched_sample,
            'traceability_fields_present': bool(matched_sample),
            'required_traceability_fields': [
                'source_bsp_identifiers',
                'source_target_levels',
                'native_relation_range',
                'strict_step_visibility',
                'state',
                'rule_mode_name',
            ],
        },
        'compact_validation_status': s5_report.get('compact_validation_status'),
        'compact_validation_mismatch_count': s5_report.get('compact_validation_mismatch_count'),
        'native_cchan_lv_list': s5_report.get('native_cchan_lv_list'),
        'fallback_to_bridge': s5_report.get('fallback_to_bridge'),
        'forbidden_dart_calc_patterns': s5_report.get('forbidden_dart_calc_patterns'),
        'chan_recalculated': False,
        'dart_chan_calculation_authority': False,
        'action_required_if_not_ok': '' if ok else 'No matched strategy output was found in the pinned fixture root snapshot or strict-step frames. Create the smallest traceable backend-derived metadata sample, or explicitly approve a UI-only synthetic diagnostic fixture before using synthetic matched-output evidence.',
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
    return 0 if result.get('ok') is True else 1


if __name__ == '__main__':
    raise SystemExit(main())
