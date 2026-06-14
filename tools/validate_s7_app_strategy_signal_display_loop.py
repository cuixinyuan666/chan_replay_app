#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PANEL = ROOT / 'lib' / 'ui' / 'widgets' / 'multi_level_interval_signal_panel.dart'
PAGE = ROOT / 'lib' / 'ui' / 'pages' / 'multi_level_replay_page.dart'
CHART = ROOT / 'lib' / 'ui' / 'widgets' / 'origin_kline_chart.dart'
MANUAL = ROOT / 'task checklist and contact.md'
VALIDATOR = 'tools/validate_s7_app_strategy_signal_display_loop.py'
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


def _manual_has_s7_record(manual: str) -> bool:
    return (
        '## S7 selected: App strategy signal display loop' in manual
        or '## S7 accepted: App strategy signal display loop' in manual
    )


def _forbidden_hits(texts: dict[str, str]) -> list[str]:
    hits: list[str] = []
    for file_name, text in texts.items():
        for name, pattern in FORBIDDEN_DART_CALC_PATTERNS.items():
            if re.search(pattern, text):
                hits.append(f'{file_name}:{name}')
    return hits


def _validate() -> dict[str, Any]:
    panel = _read(PANEL)
    page = _read(PAGE)
    chart = _read(CHART)
    manual = _read(MANUAL)
    texts = {
        str(PANEL.relative_to(ROOT)): panel,
        str(PAGE.relative_to(ROOT)): page,
        str(CHART.relative_to(ROOT)): chart,
    }
    forbidden = _forbidden_hits(texts)

    checks: dict[str, bool] = {
        'signal_panel_present': 'class MultiLevelIntervalSignalPanel' in panel,
        'strategy_rule_matrix_present': _has(panel, 'DAILY_2B_MIN30_1B', 'DAILY_3B_MIN30_1B', 'DAILY_3B_MIN30_2B'),
        'panel_builds_signals_from_bsp_and_relations': _has(panel, '_buildSignals', 'relationsForParentRange', '_matchesHighFilter', '_matchesLowFilter'),
        'traceability_fields_present': _has(panel, 'source_bsp_identifiers', 'target_levels', 'parent_relation_range', 'child_relation_range', 'strict_step_verified', 'state: ${selected.state}', 'rule_mode_name'),
        'one_click_evidence_present': _has(panel, 'S1一键复制', 'strategy_traceability_required'),
        'multi_level_page_uses_signal_panel': 'MultiLevelIntervalSignalPanel(' in page,
        'multi_level_page_uses_origin_chart': 'OriginKlineChart(' in page,
        'page_has_relation_locator_baseline': _has(page, '_locateRelationTarget', '_barListIndexForRawIndex', '_viewEndIndex', '_crosshairIndex'),
        'panel_exposes_selected_signal_callback': _has(panel, 'onSelectedSignalChanged', 'MultiLevelStrategySignalSelection'),
        'panel_exposes_jump_callback': _has(panel, 'onJumpToSignal'),
        'page_receives_selected_signal': _has(page, '_selectedStrategySignal', 'onSelectedSignalChanged'),
        'page_jumps_to_signal_raw_index': _has(page, '_locateStrategySignal', 'lowRawIndex', 'highRawIndex'),
        'page_marks_strategy_signal_on_chart': _has(page, '_strategySignalDrawingObjects', 's7_strategy_signal_marker', 'drawingObjects:'),
        'chart_accepts_overlay_markers': 'final List<DrawingObject> drawingObjects' in chart and 'drawingObjects:' in chart,
        'manual_s7_recorded': _manual_has_s7_record(manual),
        'no_dart_chan_calculation_authority': not forbidden,
    }

    required = {
        'signal_panel_present',
        'strategy_rule_matrix_present',
        'panel_builds_signals_from_bsp_and_relations',
        'traceability_fields_present',
        'one_click_evidence_present',
        'multi_level_page_uses_signal_panel',
        'multi_level_page_uses_origin_chart',
        'page_has_relation_locator_baseline',
        'panel_exposes_selected_signal_callback',
        'panel_exposes_jump_callback',
        'page_receives_selected_signal',
        'page_jumps_to_signal_raw_index',
        'page_marks_strategy_signal_on_chart',
        'chart_accepts_overlay_markers',
        'manual_s7_recorded',
        'no_dart_chan_calculation_authority',
    }
    missing_required = [key for key, ok in checks.items() if key in required and not ok]
    return {
        'ok': not missing_required,
        'command': f'python {VALIDATOR}',
        'validator': VALIDATOR,
        'source_policy': SOURCE_POLICY,
        'stage': 'S7 App strategy signal display loop',
        'checks': checks,
        'missing_required': missing_required,
        'forbidden_dart_calc_patterns': forbidden,
        'diagnosis': (
            'S7 static requirements are satisfied; App evidence is still required for visual display and interaction.'
            if not missing_required
            else 'S7 is not yet accepted. Existing signal panel/display evidence is present, but selected-signal callback, jump-to-raw-index, chart marker wiring, or manual record is incomplete.'
        ),
        'app_evidence_required_after_static_ok': [
            'Open Multi-level replay',
            'Load or scan a window with strategy signals',
            'Open 区间信号 panel',
            'Select Next/Prev signal',
            'Confirm chart marker appears on the active level',
            'Click Jump/定位 and confirm chart moves to the low/high raw index/time',
            'Copy one-click evidence showing source BSP, relation range, strict-step visibility, rule name, and state',
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
