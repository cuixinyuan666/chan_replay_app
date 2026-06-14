#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANUAL = ROOT / 'task checklist and contact.md'
ROOT_PAGE = ROOT / 'lib' / 'ui' / 'pages' / 'root_page.dart'
S12_PAGE = ROOT / 'lib' / 'ui' / 'pages' / 's12_single_stock_replay_page.dart'
MULTI_PAGE = ROOT / 'lib' / 'ui' / 'pages' / 'multi_level_replay_page.dart'
RUNTIME_PATH = ROOT / 'lib' / 'core' / 'runtime' / 'runtime_path.dart'
ANALYSIS_SOURCE = ROOT / 'lib' / 'data' / 'python_multi_level_chan_analysis_source.dart'
ORIGIN_CHART = ROOT / 'lib' / 'ui' / 'widgets' / 'origin_kline_chart.dart'
BACKEND_NATIVE = ROOT / 'backend' / 'app' / 'a_multilevel_native_engine.py'
VALIDATOR = 'tools/validate_s12_app_single_stock_replay_high_speed_path.py'

FORBIDDEN_DART_CALC_PATTERNS: dict[str, str] = {
    'dart_fx_calculation': r'\bcheckFx\b|\bFxCalculator\b|\bcalculateFx\b',
    'dart_bi_calculation': r'\bcheckBi\b|\bBiCalculator\b|\bcalculateBi\b',
    'dart_seg_calculation': r'\bSegCalculator\b|\bcalculateSeg\b',
    'dart_zs_calculation': r'\bZsCalculator\b|\bcalculateZs\b',
    'dart_bsp_calculation': r'\bBspCalculator\b|\bcalculateBsp\b',
    'dart_segseg_calculation': r'\bSegSegCalculator\b|\bcalculateSegSeg\b|\bcalculate2Seg\b',
}

DART_SCAN_FILES = [ROOT_PAGE, S12_PAGE, MULTI_PAGE, RUNTIME_PATH, ANALYSIS_SOURCE, ORIGIN_CHART]


def _read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(str(path))
    return path.read_text(encoding='utf-8-sig')


def _scan_dart_forbidden() -> list[str]:
    hits: list[str] = []
    for path in DART_SCAN_FILES:
        if not path.exists():
            continue
        text = _read(path)
        for name, pattern in FORBIDDEN_DART_CALC_PATTERNS.items():
            if re.search(pattern, text):
                hits.append(f'{path.relative_to(ROOT).as_posix()}:{name}')
    return hits


def _validate() -> dict[str, Any]:
    manual = _read(MANUAL)
    root_page = _read(ROOT_PAGE)
    s12_page = _read(S12_PAGE)
    multi_page = _read(MULTI_PAGE)
    runtime = _read(RUNTIME_PATH)
    source = _read(ANALYSIS_SOURCE)
    chart = _read(ORIGIN_CHART)
    backend = _read(BACKEND_NATIVE)
    dart_forbidden = _scan_dart_forbidden()

    baseline_checks: dict[str, bool] = {
        's12c_manual_selected': 'S12c selected: step-load temporal evidence state tracking for replay structures' in manual,
        'high_speed_runtime_path_default': 'ValueNotifier<RuntimePath>(RuntimePath.highSpeed)' in runtime and 'runtime_path_default' in runtime,
        'slow_path_debug_only_policy_present': 'slow_path' in runtime and 'slow_path_debug_only' in runtime,
        'single_stock_replay_route_exists': 'S12SingleStockReplayPage()' in root_page,
        'single_stock_replay_default_route': 'int _index = _multiLevelIndex' in root_page,
        'stock_code_input_exists': '_symbolController' in s12_page,
        'market_input_or_override_exists': '_marketController' in s12_page,
        'date_window_input_exists': '_startController' in s12_page and '_endController' in s12_page,
        'level_selection_ui_exists': '_levelChip' in s12_page and 'FilterChip' in s12_page,
        'analyze_multi_source_path_exists': '/api/chan/analyze_multi' in source and 'Future<PythonMultiLevelChanAnalysis> analyzeMulti' in source,
        'runtime_path_forwarded_to_backend': "'runtime_path': selectedRuntimePath.wireName" in source,
        'native_cchan_lv_list_backend_authority': "'lv_list': kl_types" in backend and 'DATA_SRC.CSV' in backend,
        'origin_chart_reused': 'OriginKlineChart(' in s12_page,
        'tradingview_toolbox_host_exists': 'TradingViewToolboxHost' in chart,
        'chan_structures_from_backend_models_only': 'MultiLevelChanSnapshot' in s12_page and 'ChanSnapshotJsonParser.parse' in source,
        'strict_step_frames_used': 'analysis.frames' in s12_page and 'final_snapshot_rendered_as_step: false' in multi_page,
        'no_dart_chan_calculation_authority': not dart_forbidden,
    }

    s12b_required_checks: dict[str, bool] = {
        'explicit_s12_evidence_button_exists': '复制复盘证据' in s12_page and 's12_phase: app_single_stock_replay_high_speed_path' in s12_page,
        'indicator_display_hidden_by_default': 'final Set<String> _enabledEasyTdxIndicators = <String>{}' in s12_page and 'showEasyTdxIndicators: _enabledEasyTdxIndicators.isNotEmpty' in s12_page,
        'invalid_level_combination_feedback_exists': '_validateSelectedLevels' in s12_page and '级别组合无效' in s12_page,
        'normalized_level_result_reported': '级别组合已归一化' in s12_page and 'level_validation:' in s12_page,
    }

    s12c_required_checks: dict[str, bool] = {
        'temporal_evidence_class_exists': 'class _TemporalEvidence' in s12_page and 'class _TemporalSummary' in s12_page,
        'temporal_rebuild_from_backend_frames_exists': '_rebuildTemporalEvidence' in s12_page and 'analysis.frames.isNotEmpty' in s12_page and 'backend_step_frames' in s12_page,
        'temporal_collects_backend_structures': all(token in s12_page for token in ('snapshot.bsps', 'snapshot.fxs', 'snapshot.bis', 'snapshot.segs', 'snapshot.zss')),
        'temporal_states_exist': all(token in s12_page for token in ('provisional', 'confirmed', 'historical_provisional')),
        'historical_provisional_not_confirmed': "lastSeenStep < finalStep" in s12_page and "state = 'historical_provisional'" in s12_page,
        'provisional_to_confirmed_updates_existing': 'confirmedStep ??= step' in s12_page and 'target.putIfAbsent' in s12_page,
        'temporal_evidence_preserved_not_recalculated': 'preserve backend-exported structures across frames; do not recalculate Chan structures in Dart' in s12_page,
        'temporal_evidence_copy_fields_present': all(token in s12_page for token in ('temporal_source:', 'temporal_state:', 'temporal_state_counts:', 'temporal_sample_id:', 'first_seen_step:', 'confirmed_step:', 'last_seen_step:')),
    }

    review_checks: dict[str, bool] = {
        'interval_link_marker_id_exists': 'interval_link_' in s12_page,
        'marker_overlap_policy_marker_exists': 'marker_overlap_policy' in s12_page or 'ChartLabelLayout' in s12_page,
    }

    missing_baseline = [key for key, ok in baseline_checks.items() if not ok]
    missing_s12b = [key for key, ok in s12b_required_checks.items() if not ok]
    missing_s12c = [key for key, ok in s12c_required_checks.items() if not ok]
    missing_review = [key for key, ok in review_checks.items() if not ok]

    return {
        'ok': not missing_baseline and not missing_s12b and not missing_s12c,
        'command': f'python {VALIDATOR}',
        'validator': VALIDATOR,
        'stage': 'S12c step-load temporal evidence state tracking',
        'full_s12_completion': False,
        'source_policy': 'python/chan.py via native CChan(lv_list); Flutter/Dart lifecycle-tracks backend-exported structures only',
        'baseline_checks': baseline_checks,
        's12b_required_checks': s12b_required_checks,
        's12c_required_checks': s12c_required_checks,
        'missing_baseline_required': missing_baseline,
        'missing_s12b_required': missing_s12b,
        'missing_s12c_required': missing_s12c,
        'full_s12_review_checks': review_checks,
        'full_s12_missing_review_only': missing_review,
        'forbidden_dart_calc_patterns': dart_forbidden,
        'next_required_work_if_ok': 'Continue with interval_link marker ids and shared marker-overlap policy.',
        'chan_recalculated': False,
        'dart_chan_calculation_authority': False,
        'candidate_policy': 'not a trading recommendation',
    }


def main() -> int:
    result = _validate()
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
