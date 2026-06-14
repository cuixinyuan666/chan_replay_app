#!/usr/bin/env python3
from __future__ import annotations

import importlib
import inspect
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / 'backend' / 'app' / 'a_multilevel_native_engine.py'
MANUAL = ROOT / 'task checklist and contact.md'
VALIDATOR = 'tools/validate_s10_long_history_count_expansion.py'
WINDOW_START = '2022-01-01'
WINDOW_END = '2025-12-31'
REQUESTED_COUNT = 900

FORBIDDEN_BACKEND_PATTERNS: dict[str, str] = {
    'wall_clock_now_estimation': r'\bdatetime\.now\s*\(',
    'bridge_fallback': r'bridge\s*fallback|fallback\s*bridge',
    'chan_result_cache': r'Chan result cache|chan_result_cache|result cache',
}

FORBIDDEN_DART_CALC_PATTERNS: dict[str, str] = {
    'dart_fx_calculation': r'\bcheckFx\b|\bFxCalculator\b|\bcalculateFx\b',
    'dart_bi_calculation': r'\bcheckBi\b|\bBiCalculator\b|\bcalculateBi\b',
    'dart_seg_calculation': r'\bSegCalculator\b|\bcalculateSeg\b',
    'dart_zs_calculation': r'\bZsCalculator\b|\bcalculateZs\b',
    'dart_bsp_calculation': r'\bBspCalculator\b|\bcalculateBsp\b',
}

DART_FILES = [
    ROOT / 'lib' / 'ui' / 'pages' / 'multi_level_replay_page.dart',
    ROOT / 'lib' / 'ui' / 'pages' / 's8_strategy_batch_page.dart',
    ROOT / 'lib' / 'ui' / 'widgets' / 'multi_level_interval_signal_panel.dart',
]


def _read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(str(path))
    return path.read_text(encoding='utf-8')


def _hits(text: str, patterns: dict[str, str]) -> list[str]:
    return [name for name, pattern in patterns.items() if re.search(pattern, text, flags=re.IGNORECASE)]


def _dart_hits() -> list[str]:
    hits: list[str] = []
    for path in DART_FILES:
        if not path.exists():
            continue
        text = _read(path)
        for name, pattern in FORBIDDEN_DART_CALC_PATTERNS.items():
            if re.search(pattern, text):
                hits.append(f'{path.relative_to(ROOT)}:{name}')
    return hits


def _import_backend() -> Any:
    sys.path.insert(0, str(ROOT))
    return importlib.import_module('backend.app.a_multilevel_native_engine')


def _validate() -> dict[str, Any]:
    backend_text = _read(BACKEND)
    manual_text = _read(MANUAL)
    backend_forbidden = _hits(backend_text, FORBIDDEN_BACKEND_PATTERNS)
    dart_forbidden = _dart_hits()

    native = _import_backend()
    start_dt = native._parse_request_window_bound(WINDOW_START, is_end=False)
    end_dt = native._parse_request_window_bound(WINDOW_END, is_end=True)
    if start_dt is None or end_dt is None:
        raise RuntimeError('S10 request-window parser returned None')

    samples = {
        level: native._expanded_count_for_level(level, REQUESTED_COUNT, start_dt, end_dt)
        for level in ('DAILY', 'MIN30', 'MIN5')
    }
    basis = {
        level: native._count_expansion_basis(level, REQUESTED_COUNT, start_dt, end_dt)
        for level in ('DAILY', 'MIN30', 'MIN5')
    }

    load_src = inspect.getsource(native._load_aligned_bars_by_level)
    expanded_sig = inspect.signature(native._expanded_count_for_level)

    checks: dict[str, bool] = {
        's10_manual_selected': 'S10 selected: formalize analyze_multi long-history window count expansion' in manual_text,
        'request_window_parser_present': '_parse_request_window_bound' in backend_text,
        'request_start_end_used': 'requested_start_dt = _parse_request_window_bound(start' in load_src and 'requested_end_dt = _parse_request_window_bound(end' in load_src,
        'expanded_signature_uses_window_bounds': {'window_start', 'window_end'}.issubset(set(expanded_sig.parameters)),
        'top_level_prefetch_expanded': 'top_count = int(prefetch_count_basis[top_level]' in load_src and 'count=top_count' in load_src,
        'lower_levels_use_window_count': '_count_expansion_basis(level, int(count), data_start_dt, data_end_dt)' in load_src,
        'metadata_records_requested_window': "'requested_window'" in load_src,
        'metadata_records_count_expansion_basis': "'count_expansion_basis'" in load_src and "'count_expansion_policy'" in load_src,
        'daily_count_expands_for_s8_window': samples['DAILY'] > REQUESTED_COUNT,
        'min30_count_expands_above_daily': samples['MIN30'] > samples['DAILY'],
        'min5_count_expands_above_min30': samples['MIN5'] > samples['MIN30'],
        's8_window_preserved_in_basis': all(
            str(item.get('window_start', '')).startswith('2022-01-01') and str(item.get('window_end', '')).startswith('2025-12-31')
            for item in basis.values()
        ),
        'native_cchan_lv_list_authority_present': "'lv_list': kl_types" in backend_text and 'DATA_SRC.CSV' in backend_text,
        'no_bridge_fallback_or_wall_clock_count': not backend_forbidden,
        'no_dart_chan_calculation_authority': not dart_forbidden,
    }
    missing_required = [key for key, ok in checks.items() if not ok]
    return {
        'ok': not missing_required,
        'command': f'python {VALIDATOR}',
        'validator': VALIDATOR,
        'stage': 'S10 analyze_multi long-history count expansion',
        'request_window': {'start': WINDOW_START, 'end': WINDOW_END, 'requested_count': REQUESTED_COUNT},
        'sample_expanded_counts': samples,
        'sample_count_basis': basis,
        'checks': checks,
        'missing_required': missing_required,
        'forbidden_backend_patterns': backend_forbidden,
        'forbidden_dart_calc_patterns': dart_forbidden,
        'source_policy': 'python/chan.py via native CChan(lv_list); no Dart Chan calculation',
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
