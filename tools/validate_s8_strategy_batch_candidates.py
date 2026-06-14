#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / 'tools'
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import validate_s4_cli_strategy_diagnostics as s4  # noqa: E402
import validate_s5_cli_strategy_rule_matrix as s5  # noqa: E402

VALIDATOR = 'tools/validate_s8_strategy_batch_candidates.py'
DEFAULT_OUTPUT = ROOT / 'test' / 'fixtures' / 'derived' / 's8_strategy_batch_candidates_v1.json'
EXPORTER = ROOT / 'tools' / 'export_s8_strategy_batch_candidates.py'
SOURCE_POLICY = 'original chan.py BSP + native LevelRelation only'
REQUIRED_CANDIDATE_FIELDS = [
    'code',
    'symbol',
    'market',
    'phase',
    'rule_mode_name',
    'source_bsp_identifiers',
    'source_target_levels',
    'native_relation_range',
    'strict_step_visibility',
    'state',
    'jump_target',
]
REQUIRED_JUMP_FIELDS = ['target_level', 'raw_index', 'source']


def _load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(str(path))
    raw = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(raw, dict):
        raise RuntimeError(f'{path} must contain a JSON object')
    return raw


def _exporter_static_checks() -> dict[str, Any]:
    if not EXPORTER.exists():
        return {'ok': False, 'missing': [str(EXPORTER)]}
    text = EXPORTER.read_text(encoding='utf-8')
    required = [
        'SAMPLE_KIND =',
        's8_strategy_batch_candidates_v1',
        'source_policy',
        'backend_entrypoint',
        'dart_chan_calculation',
        'chan_recalculated',
        'jump_target',
        'source_bsp_identifiers',
        'native_relation_range',
        'strict_step_visibility',
        'candidate_policy',
        '_run_candidate',
        '_matched_output_candidates',
    ]
    missing = [item for item in required if item not in text]
    forbidden = [name for name, pattern in s4.FORBIDDEN_DART_CALC_PATTERNS.items() if re.search(pattern, text)]
    return {'ok': not missing and not forbidden, 'missing': missing, 'forbidden_dart_calc_patterns': forbidden}


def _candidate_ok(candidate: dict[str, Any]) -> tuple[bool, list[str]]:
    missing = [field for field in REQUIRED_CANDIDATE_FIELDS if field not in candidate or candidate.get(field) in ('', None)]
    jump = candidate.get('jump_target')
    if not isinstance(jump, dict):
        missing.append('jump_target.object')
    else:
        for field in REQUIRED_JUMP_FIELDS:
            if field not in jump or jump.get(field) in ('', None):
                missing.append(f'jump_target.{field}')
    if candidate.get('rule_mode_name') not in s5.RULES:
        missing.append('rule_mode_name.supported')
    if candidate.get('source_target_levels') != s5.SELECTED_PAIR:
        missing.append('source_target_levels.selected_pair')
    if 'raw=' not in str(candidate.get('source_bsp_identifiers') or ''):
        missing.append('source_bsp_identifiers.raw')
    if 'parent=' not in str(candidate.get('native_relation_range') or ''):
        missing.append('native_relation_range.parent')
    if 'final snapshot' not in str(candidate.get('strict_step_visibility') or ''):
        missing.append('strict_step_visibility.policy')
    return not missing, missing


def _validate_output(path: Path) -> dict[str, Any]:
    data = _load_json(path)
    candidates = data.get('candidates')
    attempts = data.get('attempts')
    summary = data.get('summary')
    request = data.get('request')
    if not isinstance(candidates, list):
        raise RuntimeError('candidates must be a list')
    if not isinstance(attempts, list):
        raise RuntimeError('attempts must be a list')
    if not isinstance(summary, dict):
        raise RuntimeError('summary must be an object')
    if not isinstance(request, dict):
        raise RuntimeError('request must be an object')

    candidate_errors = []
    for index, candidate in enumerate(candidates):
        if not isinstance(candidate, dict):
            candidate_errors.append({'index': index, 'missing': ['candidate.object']})
            continue
        ok, missing = _candidate_ok(candidate)
        if not ok:
            candidate_errors.append({'index': index, 'code': candidate.get('code'), 'missing': missing})

    attempt_native_violations = []
    for item in attempts:
        if not isinstance(item, dict) or item.get('ok') is not True:
            continue
        native = item.get('native_cchan_lv_list')
        fallback = bool(item.get('fallback_to_bridge') or False)
        if native is not True or fallback:
            attempt_native_violations.append({
                'code': item.get('code'),
                'phase': item.get('phase'),
                'native_cchan_lv_list': native,
                'fallback_to_bridge': fallback,
            })

    ok = (
        data.get('sample_kind') == 's8_strategy_batch_candidates_v1'
        and data.get('fixture_source') == 'tools/export_s8_strategy_batch_candidates.py'
        and data.get('source_policy') == SOURCE_POLICY
        and data.get('backend_entrypoint') == 'backend.app.a_multilevel_engine_timed.analyze_multi'
        and data.get('dart_chan_calculation') is False
        and data.get('chan_recalculated') is False
        and bool(candidates)
        and not candidate_errors
        and not attempt_native_violations
        and summary.get('candidate_count') == len(candidates)
        and s5.SELECTED_PAIR == summary.get('selected_relation_pair')
    )
    return {
        'ok': ok,
        'output': str(path),
        'sample_kind': data.get('sample_kind'),
        'source_policy': data.get('source_policy'),
        'candidate_count': len(candidates),
        'attempt_count': len(attempts),
        'rules_supported': summary.get('rules_supported'),
        'selected_relation_pair': summary.get('selected_relation_pair'),
        'candidate_errors': candidate_errors,
        'attempt_native_violations': attempt_native_violations,
        'sample': candidates[0] if candidates else None,
        'chan_recalculated': False,
        'dart_chan_calculation_authority': False,
    }


def _validate(path: Path) -> dict[str, Any]:
    static = _exporter_static_checks()
    output_result: dict[str, Any] | None = None
    output_error = ''
    if path.exists():
        try:
            output_result = _validate_output(path)
        except Exception as exc:
            output_error = str(exc)
    ok = bool(static.get('ok')) and bool(output_result and output_result.get('ok'))
    return {
        'ok': ok,
        'command': f'python {VALIDATOR}',
        'validator': VALIDATOR,
        'export_command': 'python tools/export_s8_strategy_batch_candidates.py',
        'source_policy': SOURCE_POLICY,
        'stage': 'S8 scanner / batch strategy output',
        'exporter_static': static,
        'output_validation': output_result,
        'output_error': output_error,
        'required_candidate_fields': REQUIRED_CANDIDATE_FIELDS,
        'required_jump_fields': REQUIRED_JUMP_FIELDS,
        'action_required_if_not_ok': '' if ok else 'Run python tools/export_s8_strategy_batch_candidates.py, then rerun this validator.',
        'chan_recalculated': False,
        'dart_chan_calculation_authority': False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    result = _validate(args.output)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result.get('ok') is True else 1


if __name__ == '__main__':
    raise SystemExit(main())
