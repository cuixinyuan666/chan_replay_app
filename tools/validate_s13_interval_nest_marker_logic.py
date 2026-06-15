#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
S13_PAGE = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'
NUMBERING_POLICY = S13_PAGE.with_name('s13_nested_marker_numbering_policy.dart')
MULTI_SOURCE = ROOT / 'lib' / 'data' / 'python_multi_level_chan_analysis_source.dart'
NATIVE_TIMED = ROOT / 'backend' / 'app' / 'a_multilevel_native_timed_engine.py'
MANUAL = ROOT / 'task checklist and contact.md'
VALIDATOR = 'tools/validate_s13_interval_nest_marker_logic.py'


def _read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(str(path))
    return path.read_text(encoding='utf-8-sig')


def _extract_block(text: str, name: str) -> str:
    patterns = [
        re.compile(r'(?:[\w<>?,]+\s+)*(?:get\s+)?' + re.escape(name) + r'\s*(?:\([^)]*\))?\s*\{'),
        re.compile(r'\b' + re.escape(name) + r'\s*(?:\([^)]*\))?\s*\{'),
    ]
    match = None
    for pattern in patterns:
        match = pattern.search(text)
        if match:
            break
    if not match:
        return ''
    start = match.start()
    brace = text.find('{', match.end() - 1)
    if brace < 0:
        return text[start:match.end()]
    depth = 0
    in_single = False
    in_double = False
    escape = False
    for i in range(brace, len(text)):
        ch = text[i]
        if escape:
            escape = False
            continue
        if ch == '\\':
            escape = True
            continue
        if ch == "'" and not in_double:
            in_single = not in_single
            continue
        if ch == '"' and not in_single:
            in_double = not in_double
            continue
        if in_single or in_double:
            continue
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
    ambiguity_tokens = (
        'matches.length == 1',
        'targetChildRawIndex',
        'containsChildRawIndex',
    )
    return not any(token in relation_down for token in ambiguity_tokens)


def _step_uses_current_frame_ok(s13: str, native: str) -> bool:
    current_snapshot = _extract_block(s13, '_currentSnapshot')
    dart_uses_frame = 'return a.frames[_safeFrameIndex]' in current_snapshot
    unsafe_fallback = re.search(
        r'if\s*\(_isStepMode\)[^{;]*(?:\{|;)\s*return\s+a\.snapshot\s*;',
        current_snapshot,
        re.S,
    ) is not None
    native_gets_step_load = "getattr(chan, 'step_load', None)" in native
    native_iterates_step_load = any(
        token in native
        for token in (
            'iterator = iter(step_iter())',
            'enumerate(step_iter())',
            'for cursor, cur_chan in enumerate(step_iter())',
            'for cur_chan in step_iter()',
        )
    )
    native_exports_frames = "'native_step_frames': True" in native and "'step_frame_format': 'compact_v1'" in native
    return dart_uses_frame and not unsafe_fallback and native_gets_step_load and native_iterates_step_load and native_exports_frames


def _backend_relations_only_ok(s13: str) -> bool:
    relation_tokens = [
        'c.relations',
        'parentLevel',
        'childLevel',
        'parentRawIndex',
        'childStartRawIndex',
        'childEndRawIndex',
    ]
    forbidden_calculation_tokens = [
        'calculateParentChild',
        'deriveRelations',
        'buildRelationsFromTime',
        'inferParentChildByTime',
        'DateTimeRange',
    ]
    return all(token in s13 for token in relation_tokens) and not any(
        token in s13 for token in forbidden_calculation_tokens
    )


def _historical_candidate_ui_only_ok(s13: str) -> bool:
    creates_trail_copy = all(
        token in s13
        for token in (
            'BspPoint _trailPoint',
            "type: '$type候选轨迹'",
            'confirmed: p.confirmed',
        )
    )
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


def _numbering_policy_ok(s13: str, numbering_policy: str) -> bool:
    required_s13 = [
        "import 's13_nested_marker_numbering_policy.dart';",
        '_nestedNumberingPolicy.sequenceLabel',
        'sequenceNumber: sequence',
        'sequenceTotal: total',
        'sequenceLabel:',
        'if (label != null)',
        'visibleByRawIndex',
    ]
    required_policy = [
        'class S13NestedMarkerNumberingPolicy',
        'sequenceTotal <= 1) return null',
        "return '$sequenceNumber'",
    ]
    return all(token in s13 for token in required_s13) and all(
        token in numbering_policy for token in required_policy
    )


def _candidate_current_identity_ok(s13: str, numbering_policy: str) -> bool:
    required = [
        'class _BspObservation',
        'class _NestedBspTrigger',
        'S13NestedMarkerTriggerState.current',
        'S13NestedMarkerTriggerState.candidateTrail',
        'trigger_state=${_triggerStateText(marker.triggerState)}',
        'sourceLevel',
        'sourceRawIndex',
        'activeRawIndex',
        'bspKey',
        'relationSourceFrame',
        'bspSourceFrame',
        'anchorKind',
    ]
    policy_equal = re.search(
        r'int\s+compareTriggerState\s*\([^)]*\)\s*\{\s*return\s+0\s*;\s*\}',
        numbering_policy,
        re.S,
    ) is not None
    return all(token in s13 for token in required) and policy_equal


def _evidence_payload_ok(s13: str) -> bool:
    required = [
        'S13_INTERVAL_NEST_MARKER_EVIDENCE',
        '_copyS13IntervalNestMarkerEvidence',
        '_buildS13IntervalNestMarkerEvidence',
        'Clipboard.setData',
        '复制 marker 证据',
        'request_params:',
        'runtime_path=',
        'current_frame=',
        'frame_total=',
        'active_level=',
        'loaded_levels=',
        'relation_count=',
        'nested_marker_count=',
        'candidate_trail_count=',
        'missing_relation_edges=',
        'marker_trigger_sample',
        'activeRawIndex=',
        'sourceLevel=',
        'sourceRawIndex=',
        'trigger_state=',
        'sequenceNumber=',
        'sequenceTotal=',
        'bsp_key=',
        'relation_source_frame=',
        'bsp_source_frame=',
        'anchor_kind=',
    ]
    return all(token in s13 for token in required)


def _missing_edge_diagnostic_ok(s13: str) -> bool:
    required = [
        '_missingAdjacentRelationEdges',
        '_hasAdjacentRelationEdge',
        'missing_relation_edges',
        'missing relation edge diagnostic',
        'if (!_hasAdjacentRelationEdge(parent, childLevel)) return null;',
        'if (!_hasAdjacentRelationEdge(parentLevel, child)) return null;',
    ]
    return all(token in s13 for token in required)


def _interval_anchor_not_bsp_ok(s13: str) -> bool:
    required = [
        'intervalAnchorByLevel',
        'isIntervalAnchor',
        'anchorKind: isIntervalAnchor ? \'interval\' : \'bsp\'',
        'bsp: observation?.bsp',
        "row.isIntervalAnchor ? '-' : ''",
        "? 'interval'",
        ": (row.bsp == null ? 'missing' : 'bsp')",
    ]
    return all(token in s13 for token in required)


def _trigger_list_not_collapsed_ok(s13: str) -> bool:
    collapsed_anchor_set = re.search(r'final\s+activeAnchorRawIndexes\s*=\s*<int>\s*\{\s*\}\s*;', s13) is not None
    only_int_anchor_add = 'activeAnchorRawIndexes.add(activeRaw)' in s13
    required = [
        'final triggers = <_NestedBspTrigger>[];',
        'totalByActiveRaw',
        'sequenceByActiveRaw',
        'trigger.observation.bspKey',
        'sourceRawIndex: observation.bsp.rawIndex',
        'state: _nestedTriggerState(observation)',
    ]
    return not collapsed_anchor_set and not only_int_anchor_add and all(token in s13 for token in required)


def _manual_records_task(manual: str) -> bool:
    required = [
        'hichan',
        'hichanqujiantao',
        'S13_INTERVAL_NEST_MARKER_EVIDENCE',
        'completed_tasks',
        'evidence_button',
        'validation_result',
        'remaining_risk',
        'next_task',
    ]
    return all(token in manual for token in required)


def _validate() -> dict[str, Any]:
    s13 = _read(S13_PAGE)
    source = _read(MULTI_SOURCE)
    native = _read(NATIVE_TIMED)
    manual = _read(MANUAL)
    numbering_policy = _read(NUMBERING_POLICY)
    relation_down = _extract_block(s13, '_relationDown')

    checks: dict[str, bool] = {
        'validator_file_exists': Path(__file__).name == 'validate_s13_interval_nest_marker_logic.py',
        's13_step_uses_current_frame_not_final_snapshot': _step_uses_current_frame_ok(s13, native),
        'frontend_sends_start_end_to_analyze_multi': "if (startDate != null) 'start': _fmtDate(startDate)" in source and "if (endDate != null) 'end': _fmtDate(endDate)" in source,
        'nested_markers_use_backend_relations_only': _backend_relations_only_ok(s13),
        'relation_down_rejects_ambiguous_first_child_range': not _contains_unconditional_first_child_range(relation_down),
        'historical_candidate_bsp_is_ui_only': _historical_candidate_ui_only_ok(s13),
        'numbering_policy_hides_single_sequence_label': _numbering_policy_ok(s13, numbering_policy),
        'candidate_current_identity_fields_preserved': _candidate_current_identity_ok(s13, numbering_policy),
        'evidence_button_and_payload_fields_exist': _evidence_payload_ok(s13),
        'missing_adjacent_relation_edge_diagnostic_exists': _missing_edge_diagnostic_ok(s13),
        'interval_anchor_not_impersonating_bsp': _interval_anchor_not_bsp_ok(s13),
        'multiple_lower_level_bsps_preserved_as_distinct_triggers': _trigger_list_not_collapsed_ok(s13),
        'manual_records_s13_validation_task': _manual_records_task(manual),
    }

    missing = [key for key, ok in checks.items() if not ok]
    review_notes: list[str] = []
    if not checks['evidence_button_and_payload_fields_exist']:
        review_notes.append('S13 evidence copy must expose header, request/runtime/frame/level/count fields, missing edges, and marker trigger samples.')
    if not checks['candidate_current_identity_fields_preserved']:
        review_notes.append('Candidate/current trigger identity and frame provenance fields are incomplete.')
    if not checks['missing_adjacent_relation_edge_diagnostic_exists']:
        review_notes.append('Adjacent loaded-level relation gaps must stop marker mapping and be reportable in copied evidence.')
    if not checks['interval_anchor_not_impersonating_bsp']:
        review_notes.append('Interval anchors must remain explicit interval rows and cannot be rendered/evidenced as BSP anchors.')

    return {
        'ok': not missing,
        'command': f'python {VALIDATOR}',
        'validator': VALIDATOR,
        'stage': 'S13 interval-nest marker evidence hardening validation',
        'source_policy': 'backend MultiLevelChanSnapshot.relations + backend BSP rows only; Dart parses/displays/numbers/copies evidence only',
        'checks': checks,
        'missing_required': missing,
        'review_notes': review_notes,
        'chan_recalculated': False,
        'dart_chan_calculation_authority': False,
    }


def main() -> int:
    result = _validate()
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
