#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
S8_PAGE = ROOT / 'lib' / 'ui' / 'pages' / 's8_strategy_batch_page.dart'
ROOT_PAGE = ROOT / 'lib' / 'ui' / 'pages' / 'root_page.dart'
VALIDATOR = 'tools/validate_s8_app_batch_navigation.py'
SOURCE_POLICY = 'original chan.py BSP + native LevelRelation only'

FORBIDDEN_DART_CALC_PATTERNS: dict[str, str] = {
    'dart_fx_calculation': r'\bcheckFx\b|\bFxCalculator\b|\bcalculateFx\b',
    'dart_bi_calculation': r'\bcheckBi\b|\bBiCalculator\b|\bcalculateBi\b',
    'dart_seg_calculation': r'\bSegCalculator\b|\bcalculateSeg\b',
    'dart_zs_calculation': r'\bZsCalculator\b|\bcalculateZs\b',
    'dart_bsp_calculation': r'\bBspCalculator\b|\bcalculateBsp\b',
}


def _read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(str(path))
    return path.read_text(encoding='utf-8')


def _has(text: str, *needles: str) -> bool:
    return all(needle in text for needle in needles)


def _forbidden_hits(texts: dict[str, str]) -> list[str]:
    hits: list[str] = []
    for file_name, text in texts.items():
        for name, pattern in FORBIDDEN_DART_CALC_PATTERNS.items():
            if re.search(pattern, text):
                hits.append(f'{file_name}:{name}')
    return hits


def _validate() -> dict[str, Any]:
    page = _read(S8_PAGE)
    root = _read(ROOT_PAGE)
    forbidden = _forbidden_hits({
        str(S8_PAGE.relative_to(ROOT)): page,
        str(ROOT_PAGE.relative_to(ROOT)): root,
    })
    checks: dict[str, bool] = {
        's8_page_present': 'class S8StrategyBatchPage' in page,
        'root_route_present': _has(root, 'S8StrategyBatchPage()', 'S8批量候选', '_s8BatchIndex'),
        'local_exporter_json_loaded': _has(page, 's8_strategy_batch_candidates_v1.json', 'sample_kind', '_loadCandidates'),
        'candidate_list_present': _has(page, 'DataTable', '_candidatesPanel', '_S8BatchCandidate'),
        'candidate_click_navigation_present': _has(page, '_openCandidate', 'onSelectChanged', 'analyzeMulti'),
        'jump_target_navigation_present': _has(page, 'jump_target', 'jumpTargetLevel', 'jumpRawIndex', '_locateCandidate'),
        'chart_marker_present': _has(page, 's8_batch_candidate_marker', '_s8CandidateDrawingObjects', 'drawingObjects:'),
        'traceability_fields_present': _has(page, 'source_bsp_identifiers', 'source_target_levels', 'native_relation_range', 'strict_step_visibility', 'rule_mode_name', 'state'),
        'copy_evidence_present': _has(page, '复制S8证据', 's8_phase: app_batch_candidate_navigation', 'candidate_policy'),
        'uses_existing_backend_authority': _has(page, 'PythonMultiLevelChanAnalysisSource', 'RuntimePathController.current', 'original chan.py BSP + native LevelRelation only'),
        'no_dart_chan_calculation_authority': not forbidden,
    }
    required = set(checks)
    missing_required = [key for key, ok in checks.items() if key in required and not ok]
    return {
        'ok': not missing_required,
        'command': f'python {VALIDATOR}',
        'validator': VALIDATOR,
        'source_policy': SOURCE_POLICY,
        'stage': 'S8b App scanner / batch candidate navigation',
        'checks': checks,
        'missing_required': missing_required,
        'forbidden_dart_calc_patterns': forbidden,
        'app_evidence_required_after_static_ok': [
            'Run python tools/export_s8_strategy_batch_candidates.py first so the local JSON exists',
            'Open S8批量候选 from the left route toolbar',
            'Click 读取候选',
            'Click one candidate row',
            'Confirm the multi-level chart loads and jumps to candidate jump_target raw index',
            'Confirm S8 marker is visible on the target level',
            'Click 复制S8证据 and paste the output for acceptance',
        ],
        'chan_recalculated': False,
        'dart_chan_calculation_authority': False,
    }


def main() -> int:
    try:
        result = _validate()
    except Exception as exc:
        print(json.dumps({'ok': False, 'error': str(exc), 'validator': VALIDATOR}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result.get('ok') is True else 1


if __name__ == '__main__':
    raise SystemExit(main())
