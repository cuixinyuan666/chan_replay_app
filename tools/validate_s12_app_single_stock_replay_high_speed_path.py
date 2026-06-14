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

PROFIT_OR_TRADING_PATTERNS: dict[str, str] = {
    'profit_prediction_wording': r'利润预测|收益预测|profit\s+prediction|predict\s+profit',
    'trading_recommendation_wording': r'交易推荐|买入推荐|卖出推荐|recommend\s+buy|recommend\s+sell',
    'automatic_trading_wording': r'自动交易|auto\s*trading|automatic\s*trading',
}

DART_SCAN_FILES = [
    ROOT_PAGE,
    S12_PAGE,
    MULTI_PAGE,
    RUNTIME_PATH,
    ANALYSIS_SOURCE,
    ORIGIN_CHART,
]


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


def _scan_forbidden_wording() -> list[str]:
    hits: list[str] = []
    for path in DART_SCAN_FILES:
        if not path.exists():
            continue
        text = _read(path).replace('not a trading recommendation', '')
        for name, pattern in PROFIT_OR_TRADING_PATTERNS.items():
            if re.search(pattern, text, flags=re.IGNORECASE):
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
    wording_forbidden = _scan_forbidden_wording()

    baseline_checks: dict[str, bool] = {
        's12b_manual_selected': 'S12b selected: replay evidence button, indicator default-hidden state, and explicit level-validation feedback' in manual,
        'high_speed_runtime_path_exists': 'RuntimePath.highSpeed' in runtime and "return 'high_speed'" in runtime,
        'high_speed_runtime_path_default': 'ValueNotifier<RuntimePath>(RuntimePath.highSpeed)' in runtime and 'runtime_path_default' in runtime,
        'slow_path_debug_only_policy_present': 'slow_path' in runtime and 'slow_path_debug_only' in runtime,
        'single_stock_replay_route_exists': 'S12SingleStockReplayPage()' in root_page and 's12_single_stock_replay_page.dart' in root_page,
        'single_stock_replay_default_route': 'int _index = _multiLevelIndex' in root_page,
        'stock_code_input_exists': '_symbolController' in s12_page and "TextEditingController(text: '600340')" in s12_page,
        'market_input_or_override_exists': '_marketController' in s12_page and "TextEditingController(text: 'SH')" in s12_page,
        'date_window_input_exists': '_startController' in s12_page and '_endController' in s12_page,
        'level_options_exist': '_levelOptions' in s12_page and all(level in s12_page for level in ('DAILY', 'MIN30', 'MIN5')),
        'level_selection_ui_exists': '_levelChip' in s12_page and 'FilterChip' in s12_page,
        'normalized_level_submission_exists': '_normalizedLevels' in s12_page and 'levels: levelValidation.normalizedLevels' in s12_page,
        'analyze_multi_source_path_exists': '/api/chan/analyze_multi' in source and 'Future<PythonMultiLevelChanAnalysis> analyzeMulti' in source,
        'runtime_path_forwarded_to_backend': "'runtime_path': selectedRuntimePath.wireName" in source and 'RuntimePathController.current' in source,
        'page_uses_runtime_path_current': 'runtimePath: RuntimePathController.current' in s12_page,
        'native_cchan_lv_list_backend_authority': "'lv_list': kl_types" in backend and 'DATA_SRC.CSV' in backend,
        'origin_chart_reused': 'OriginKlineChart(' in s12_page,
        'tradingview_toolbox_host_exists': 'TradingViewToolboxHost' in chart,
        'easy_tdx_toolbox_entrance_exists': 'enabledEasyTdxIndicators' in chart and 'onEasyTdxIndicatorToggled' in chart,
        'chan_structures_from_backend_models_only': 'MultiLevelChanSnapshot' in s12_page and 'ChanSnapshotJsonParser.parse' in source,
        'strict_step_frames_used': 'analysis.frames' in s12_page and 'final_snapshot_rendered_as_step: false' in multi_page,
        'relation_panel_link_navigation_exists': 'MultiLevelRelationPanel' in multi_page and '_locateRelationTarget' in multi_page,
        'strategy_interval_marker_exists': 's7_strategy_signal_marker' in multi_page and '_locateStrategySignal' in multi_page,
        'no_dart_chan_calculation_authority': not dart_forbidden,
        'no_profit_or_auto_trading_wording': not wording_forbidden,
    }

    s12b_required_checks: dict[str, bool] = {
        'explicit_s12_evidence_button_exists': '复制复盘证据' in s12_page and 's12_phase: app_single_stock_replay_high_speed_path' in s12_page,
        'replay_evidence_required_fields_present': all(
            token in s12_page
            for token in (
                'selected_levels:',
                'normalized_levels:',
                'runtime_path:',
                'enabled_easy_tdx_indicators:',
                'backend_authority:',
                'dart_chan_calculation_authority: false',
                'candidate_policy: not a trading recommendation',
            )
        ),
        'indicator_display_hidden_by_default': 'final Set<String> _enabledEasyTdxIndicators = <String>{}' in s12_page and 'showEasyTdxIndicators: _enabledEasyTdxIndicators.isNotEmpty' in s12_page,
        'indicator_toggles_use_tradingview_entrance': 'onEasyTdxIndicatorToggled: _toggleEasyTdxIndicator' in s12_page and '_toggleEasyTdxIndicator' in s12_page,
        'invalid_level_combination_feedback_exists': '_validateSelectedLevels' in s12_page and '级别组合无效' in s12_page,
        'normalized_level_result_reported': '级别组合已归一化' in s12_page and 'level_validation:' in s12_page,
    }

    # Remaining full-S12 work is deliberately not blocking S12b.
    full_s12_review_checks: dict[str, bool] = {
        'temporal_state_provisional_confirmed_historical_exists': all(token in s12_page for token in ('provisional', 'confirmed', 'historical_provisional')),
        'interval_link_marker_id_exists': 'interval_link_' in s12_page,
        'marker_overlap_policy_marker_exists': 'marker_overlap_policy' in s12_page or 'ChartLabelLayout' in s12_page,
    }

    missing_baseline = [key for key, ok in baseline_checks.items() if not ok]
    missing_s12b_required = [key for key, ok in s12b_required_checks.items() if not ok]
    full_s12_missing = [key for key, ok in full_s12_review_checks.items() if not ok]

    return {
        'ok': not missing_baseline and not missing_s12b_required,
        'command': f'python {VALIDATOR}',
        'validator': VALIDATOR,
        'stage': 'S12b replay evidence, indicator default-hidden, level-validation feedback',
        'full_s12_completion': False,
        'source_policy': 'python/chan.py via native CChan(lv_list); Flutter/Dart display, route, mark, and copy evidence only',
        'baseline_checks': baseline_checks,
        's12b_required_checks': s12b_required_checks,
        'missing_baseline_required': missing_baseline,
        'missing_s12b_required': missing_s12b_required,
        'full_s12_review_checks': full_s12_review_checks,
        'full_s12_missing_review_only': full_s12_missing,
        'forbidden_dart_calc_patterns': dart_forbidden,
        'forbidden_profit_or_trading_wording': wording_forbidden,
        'next_required_work_if_ok': 'Continue with temporal evidence states, interval_link marker ids, and shared marker-overlap policy.',
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
