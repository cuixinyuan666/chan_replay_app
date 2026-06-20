from __future__ import annotations

from collections import deque
from time import perf_counter
from typing import Any

from .a_multilevel_native_engine import (
    _load_aligned_bars_by_level,
    _max_step_frames,
    _native_once_response,
    _native_relations,
    _normalize_levels,
    _prepare_native_chan,
    _raw_klu_iter,
    _snapshot_from_chan,
)
from .chanpy_engine import _export_bsp, _export_merged_bars, _idx
from .easy_tdx_provider import (
    get_easy_tdx_cache_stats,
    infer_market,
    normalize_symbol,
    reset_easy_tdx_cache_stats,
)


def _elapsed_ms(start: float) -> int:
    return int((perf_counter() - start) * 1000)


def _add_elapsed_ms(timing: dict[str, Any], key: str, start: float) -> None:
    timing[key] = int(timing.get(key) or 0) + _elapsed_ms(start)


def _merge_timing(result: dict[str, Any], timing: dict[str, Any]) -> dict[str, Any]:
    patched = dict(result)
    meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
    meta.update(timing)
    patched['meta'] = meta
    return patched


def _timed_native_failure_response(
    *,
    symbol: str,
    market: str | None,
    levels: list[str] | str | None,
    adjust: str,
    mode: str,
    main_level: str | None,
    clock_level: str | None,
    exc: Exception,
) -> dict[str, Any]:
    code = normalize_symbol(symbol)
    market_name = (market or infer_market(code)).upper()
    level_order = _normalize_levels(levels)
    main = (main_level or level_order[0]).upper()
    if main not in level_order:
        main = level_order[0]
    clock = (clock_level or main).upper()
    if clock not in level_order:
        clock = main
    error = str(exc)
    return {
        'ok': False,
        'error': error,
        'main_level': main,
        'levels': {},
        'relations': [],
        'frames': [],
        'meta': {
            'engine': 'chan.py',
            'source': 'origin_vespa_tdx.backend.a_multilevel_native_timed_engine',
            'mode': (mode or 'once').lower(),
            'symbol': f'{code}.{market_name}',
            'name': code,
            'levels': level_order,
            'main_level': main,
            'clock_level': clock,
            'adjust': adjust.upper(),
            'native_cchan_lv_list': False,
            'level_relation_mode': 'native_unavailable',
            'fallback_to_bridge': False,
            'native_failure': error,
            'chan_py_polluted': False,
            'warnings': [
                'native CChan(lv_list) failed; bridge fallback is intentionally blocked',
            ],
        },
    }


def _cache_timing_meta() -> dict[str, Any]:
    stats = get_easy_tdx_cache_stats()
    return {
        'backend_data_cache_enabled': stats.get('enabled'),
        'backend_data_cache_hits': stats.get('hits'),
        'backend_data_cache_misses': stats.get('misses'),
        'backend_data_cache_hit_levels': stats.get('hit_levels'),
        'backend_data_cache_miss_levels': stats.get('miss_levels'),
        'backend_data_cache_key_count': stats.get('key_count'),
        'backend_data_cache_policy': stats.get('policy'),
    }


def _timed_export_level(exporter: Any, level_obj: Any, timing: dict[str, Any]) -> dict[str, Any]:
    total_start = perf_counter()

    merged_start = perf_counter()
    merged_bars = _export_merged_bars(level_obj)
    _add_elapsed_ms(timing, 'backend_structure_export_merged_ms', merged_start)

    fx_start = perf_counter()
    fx = exporter.export_fx(level_obj)
    _add_elapsed_ms(timing, 'backend_structure_export_fx_ms', fx_start)

    bi_start = perf_counter()
    bi = exporter.export_bi(level_obj)
    _add_elapsed_ms(timing, 'backend_structure_export_bi_ms', bi_start)

    seg_start = perf_counter()
    seg = exporter.export_seg(level_obj)
    _add_elapsed_ms(timing, 'backend_structure_export_seg_ms', seg_start)

    zs_start = perf_counter()
    zs = exporter.export_zs(level_obj)
    _add_elapsed_ms(timing, 'backend_structure_export_zs_ms', zs_start)

    bsp_start = perf_counter()
    bsp = _export_bsp(level_obj)
    _add_elapsed_ms(timing, 'backend_structure_export_bsp_ms', bsp_start)

    _add_elapsed_ms(timing, 'backend_step_export_structure_ms', total_start)
    return {
        'merged_bars': merged_bars,
        'fx': fx,
        'bi': bi,
        'seg': seg,
        'zs': zs,
        'bsp': bsp,
    }
