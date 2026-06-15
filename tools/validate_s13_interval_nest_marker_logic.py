#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
S13_PAGE = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'
MULTI_SOURCE = ROOT / 'lib' / 'data' / 'python_multi_level_chan_analysis_source.dart'
NATIVE_TIMED = ROOT / 'backend' / 'app' / 'a_multilevel_native_timed_engine.py'
MANUAL = ROOT / 'task checklist and contact.md'
VALIDATOR = 'tools/validate_s13_interval_nest_marker_logic.py'


def _read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(str(path))
    return path.read_text(encoding='utf-8-sig')


def _extract_block(text: str, name: str) -> str:
    pattern = re.compile(r'\b[\w<>?]+\s+' + re.escape(name) + r'\s*\([^)]*\)\s*\{')
    m = pattern.search(text)
    if not m:
        return ''
    start = m.start()
    brace = text.find('{', m.end() - 1)
    if brace < 0:
        return text[start:m.end()]
    depth = 0
    for i in range(brace, len(text)):
        ch = text[i]
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
    return text[start:]


def _contains_unconditional_first_child_range(relation_down: str) -> bool:
    if not relation_down:
        return True
    compact = re.sub(r'\s+', ' ', relation_down)
    unsafe_patterns = [
        r'return\s+matches\.isEmpty\s*\?\s*null\s*:\s*matches\.first\s*;',
        r'return\s+matches\.first\s*;',
    ]
    if any(re.search(pattern, compact) for pattern in unsafe_patterns):
        return True
    # Safe implementations should either reject ambiguity or select by a target child raw index/range.
    ambiguity_tokens = (
        'matches.length == 1',
        'matches.length <= 1',
        'ambiguous',
        'childRawIndex',
        'targetChildRawIndex',
        'containsChildRawIndex',
    )
    return not any(token in relation_down for token in ambiguity_tokens)


def _child_start_can_impersonate_bsp(s13: str) -> bool:
    # The known unsafe pattern stores childStartRawIndex in rawByLevel when no child BSP exists.
    # That is a valid interval-region anchor only if the row model explicitly carries anchor kind / interval-only state.
    unsafe_assignment = 'rawByLevel[child] = down.childStartRawIndex' in s13
    has_explicit_anchor_kind = any(
        token in s13
        for token in (
            'isIntervalAnchor',
            'anchorKind',
            'NestedAnchorKind',
            'intervalOnly',
            'isBspAnchor',
        )
    )
    return unsafe_assignment and not has_explicit_anchor_kind


def _lower_level_bsp_collapse_risk(s13: str) -> bool:
    # A Set<int> of active raw indexes collapses distinct lower-level BSP observations before marker construction.
    collapsed_anchor_set = re.search(r'final\s+activeAnchorRawIndexes\s*=\s*<int>\s*\{\s*\}\s*;', s13) is not None
    only_int_anchor_add = 'activeAnchorRawIndexes.add(activeRaw)' in s13
    has_trigger_identity = any(
        token in s13
        for token in (
            'class _NestedBspTrigger',
            'triggerLevel',
            'triggerBspKey',
            'triggerRawIndex',
            'sourceBsp',
            'sourceLevel',
        )
    )
    return collapsed_anchor_set and only_int_anchor_add and not has_trigger_identity


def _historical_candidate_ui_only_ok(s13: str) -> bool:
    creates_trail_copy = 'BspPoint _trailPoint' in s13 and "type: '$t候选轨迹'" in s13 and 'confirmed: p.confirmed' in s13
    display_snapshot_is_copy = 'ChanSnapshot(' in s13 and 'bsps: <BspPoint>[...trail, ...s.bsps]' in s13
    forbidden_mutations = [
        r'\.bsps\.add\(',
        r'\.bsps\.addAll\(',
        r'\.bsps\s*=',
        r'_analysis\s*=\s*.*trail',
        r'a\.frames\[[^\]]+\]\s*=',
        r'analysis\.snapshot\s*=',
    ]
    mutation_hits = [pattern for pattern in forbidden_mutations if re.search(pattern, s13)]
    return creates_trail_copy and display_snapshot_is_copy and not mutation_hits


def _step_uses_current_frame_ok(s13: str, native: str) -> bool:
    current_snapshot = _extract_block(s13, '_currentSnapshot')
    dart_uses_frame = 'return a.frames[_safeFrameIndex]' in current_snapshot
    dart_has_final_fallback_inside_step = bool(
        re.search(r'if\s*\(_isStepMode\).*?return\s+a\.snapshot', current_snapshot, re.S)
    )
    native_uses_step_load = "getattr(chan, 'step_load', None)" in native and 'iterator = iter(step_iter())' in native
    native_exports_frames = "'native_step_frames': True" in native and "'step_frame_format': 'compact_v1'" in native
    return dart_uses_frame and not dart_has_final_fallback_inside_step and native_uses_step_load and native_exports_frames


def _backend_relations_only_ok(s13: str) -> bool:
    relation_tokens = ['c.relations', 'parentLevel', 'childLevel', 'parentRawIndex', 'childStartRawIndex', 'childEndRawIndex']
    if not all(token in s13 for token in relation_tokens):
        return False
    forbidden_calculation_tokens = [
        'calculateParentChild',
        'deriveRelations',
        'buildRelationsFromTime',
        'inferParentChildByTime',
        'DateTimeRange',
    ]
    return not any(token in s13 for token in forbidden_calculation_tokens)


def _manual_records_task(manual: str) -> bool:
    required = [
        'S13 interval-nest hidden logic review is selected',
        'tools/validate_s13_interval_nest_marker_logic.py',
        'first child range',
        'childStart',
        'Historical candidate BSPs remain UI-only',
    ]
    return all(token in manual for token in required)


def _validate() -> dict[str, Any]:
    s13 = _read(S13_PAGE)
    source = _read(MULTI_SOURCE)
    native = _read(NATIVE_TIMED)
    manual = _read(MANUAL)
    relation_down = _extract_block(s13, '_relationDown')

    checks: dict[str, bool] = {
        'validator_file_exists': Path(__file__).name == 'validate_s13_interval_nest_marker_logic.py',
        's13_step_uses_current_frame_not_final_snapshot': _step_uses_current_frame_ok(s13, native),
        'frontend_sends_start_end_to_analyze_multi': "if (startDate != null) 'start': _fmtDate(startDate)" in source and "if (endDate != null) 'end': _fmtDate(endDate)" in source,
        'nested_markers_use_backend_relations_only': _backend_relations_only_ok(s13),
        'relation_down_rejects_ambiguous_first_child_range': not _contains_unconditional_first_child_range(relation_down),
        'child_start_is_interval_anchor_not_bsp_anchor': not _child_start_can_impersonate_bsp(s13),
        'multiple_lower_level_bsps_preserved_as_distinct_triggers': not _lower_level_bsp_collapse_risk(s13),
        'historical_candidate_bsp_is_ui_only': _historical_candidate_ui_only_ok(s13),
        'manual_records_s13_validation_task': _manual_records_task(manual),
    }

    required_order = list(checks.keys())
    missing = [key for key in required_order if not checks[key]]
    review_notes: list[str] = []
    if not checks['relation_down_rejects_ambiguous_first_child_range']:
        review_notes.append('_relationDown still appears to select matches.first without an ambiguity/target-child guard.')
    if not checks['child_start_is_interval_anchor_not_bsp_anchor']:
        review_notes.append('childStartRawIndex can still be stored as a row raw index without an explicit interval-anchor/BSP-anchor distinction.')
    if not checks['multiple_lower_level_bsps_preserved_as_distinct_triggers']:
        review_notes.append('activeAnchorRawIndexes is still a Set<int>, so multiple lower-level BSP observations can collapse onto one active rawIndex before marker construction.')

    return {
        'ok': not missing,
        'command': f'python {VALIDATOR}',
        'validator': VALIDATOR,
        'stage': 'S13 interval-nest marker hidden logic validation',
        'source_policy': 'backend MultiLevelChanSnapshot.relations + backend BSP rows only; no Dart Chan structure calculation authority',
        'checks': checks,
        'missing_required': missing,
        'review_notes': review_notes,
        'expected_current_status': 'This validator is expected to fail until S13 marker mapping is hardened if the known unsafe patterns remain present.',
        'chan_recalculated': False,
        'dart_chan_calculation_authority': False,
    }


def main() -> int:
    result = _validate()
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
