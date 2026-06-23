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
from .chanpy_engine import _export_bsp, _export_merged_bars, _export_seg_zs, _idx
from .easy_tdx_provider import (
    get_easy_tdx_cache_stats,
    infer_market,
    normalize_market,
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
    market_name = normalize_market(code, market or infer_market(code))
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

    seg_zs_start = perf_counter()
    seg_zs = _export_seg_zs(level_obj)
    _add_elapsed_ms(timing, 'backend_structure_export_seg_zs_ms', seg_zs_start)

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
        'seg_zs': seg_zs,
        'bsp': bsp,
    }


def _visible_count_for_level(level_obj: Any, bars: list[dict[str, Any]]) -> int:
    indices = [idx for idx in (_idx(klu) for klu in _raw_klu_iter(level_obj)) if idx is not None]
    if not indices:
        return 0
    return min(max(indices) + 1, len(bars))


def _compact_level_payload(*, visible_count: int, structures: dict[str, Any]) -> dict[str, Any]:
    return {
        'visible_count': visible_count,
        'merged_bars': structures.get('merged_bars', []),
        'fx': structures.get('fx', []),
        'bi': structures.get('bi', []),
        'seg': structures.get('seg', []),
        'zs': structures.get('zs', []),
        'seg_zs': structures.get('seg_zs', []),
        'bsp': structures.get('bsp', []),
        'meta': {
            'compact_frame_level': True,
            'frame_bars_omitted': True,
            'frame_indicators_omitted': True,
        },
    }


def _compact_frame_current_time(
    frame: dict[str, Any],
    main: str,
    bars_by_level: dict[str, list[dict[str, Any]]],
) -> str | None:
    level = frame.get('levels', {}).get(main) if isinstance(frame.get('levels'), dict) else None
    if not isinstance(level, dict):
        return None
    try:
        visible_count = int(level.get('visible_count') or 0)
    except (TypeError, ValueError):
        visible_count = 0
    bars = bars_by_level.get(main) or []
    if visible_count <= 0 or visible_count > len(bars):
        return None
    last = bars[visible_count - 1]
    if not isinstance(last, dict):
        return None
    value = last.get('dt') or last.get('time') or last.get('date')
    return None if value is None else str(value)


def _timed_compact_snapshot_from_chan(
    *,
    exporter: Any,
    chan: Any,
    kl_types: list[Any],
    level_order: list[str],
    bars_by_level: dict[str, list[dict[str, Any]]],
    main: str,
    clock: str,
    mode_name: str,
    timing: dict[str, Any],
    cursor: int | None = None,
) -> dict[str, Any]:
    level_results: dict[str, dict[str, Any]] = {}
    total_bsp_count = 0
    for level, kl_type in zip(level_order, kl_types):
        level_start = perf_counter()
        level_obj = exporter.get_level(chan, kl_type)

        structures = _timed_export_level(exporter, level_obj, timing)
        total_bsp_count += len(structures.get('bsp', []) if isinstance(structures, dict) else [])

        visible_start = perf_counter()
        visible_count = _visible_count_for_level(level_obj, bars_by_level[level])
        _add_elapsed_ms(timing, 'backend_step_export_visible_bars_ms', visible_start)

        payload_start = perf_counter()
        level_results[level] = _compact_level_payload(
            visible_count=visible_count,
            structures=structures,
        )
        _add_elapsed_ms(timing, 'backend_step_export_level_payload_ms', payload_start)
        _add_elapsed_ms(timing, 'backend_step_export_level_snapshot_ms', level_start)

    relation_start = perf_counter()
    relations = _native_relations(
        level_order=level_order,
        kl_types=kl_types,
        chan=chan,
        exporter=exporter,
    )
    _add_elapsed_ms(timing, 'backend_step_export_relation_ms', relation_start)
    timing['backend_step_export_bsp_count'] = (
        int(timing.get('backend_step_export_bsp_count') or 0) + total_bsp_count
    )

    meta = {
        'engine': 'chan.py',
        'source': 'origin_vespa_tdx.backend.a_multilevel_native_timed_engine',
        'mode': mode_name,
        'levels': level_order,
        'main_level': main,
        'clock_level': clock,
        'native_cchan_lv_list': True,
        'level_relation_mode': 'chan_parent_child',
        'chan_py_polluted': False,
        'step_frame_format': 'compact_v1',
        'compact_first_step_frame_export': True,
    }
    if cursor is not None:
        meta['cursor'] = cursor
    return {
        'main_level': main,
        'levels': level_results,
        'relations': relations,
        'meta': meta,
    }
