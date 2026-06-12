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
    return {
        'ok': False,
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
            'native_failure': str(exc),
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
        'bsp': structures.get('bsp', []),
        'meta': {
            'compact_frame_level': True,
            'frame_bars_omitted': True,
            'frame_indicators_omitted': True,
        },
    }


def _compact_frame_current_time(frame: dict[str, Any], main: str, bars_by_level: dict[str, list[dict[str, Any]]]) -> str | None:
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
    timing['backend_step_export_bsp_count'] = int(timing.get('backend_step_export_bsp_count') or 0) + total_bsp_count

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


def _timed_native_step_response(
    *,
    exporter: Any,
    chan: Any,
    kl_types: list[Any],
    level_order: list[str],
    bars_by_level: dict[str, list[dict[str, Any]]],
    data_meta: dict[str, Any],
    prepared_code: str,
    code: str,
    market_name: str,
    adjust: str,
    main: str,
    clock: str,
    config: dict[str, Any] | None,
    timing: dict[str, Any],
) -> dict[str, Any]:
    step_iter = getattr(chan, 'step_load', None)
    if not callable(step_iter):
        raise RuntimeError('native CChan(lv_list) does not expose step_load')
    max_frames = _max_step_frames(config)
    frame_buffer: deque[dict[str, Any]] = deque(maxlen=max_frames)
    total_frames = 0
    last_chan: Any | None = None
    iterator = iter(step_iter())
    cursor = 0
    while True:
        iter_start = perf_counter()
        try:
            cur_chan = next(iterator)
        except StopIteration:
            _add_elapsed_ms(timing, 'backend_step_export_iter_ms', iter_start)
            break
        _add_elapsed_ms(timing, 'backend_step_export_iter_ms', iter_start)
        last_chan = cur_chan

        frame_start = perf_counter()
        frame = _timed_compact_snapshot_from_chan(
            exporter=exporter,
            chan=cur_chan,
            kl_types=kl_types,
            level_order=level_order,
            bars_by_level=bars_by_level,
            main=main,
            clock=clock,
            mode_name='step',
            timing=timing,
            cursor=cursor,
        )
        current_time_start = perf_counter()
        frame['meta']['current_time'] = _compact_frame_current_time(frame, main, bars_by_level)
        _add_elapsed_ms(timing, 'backend_step_export_current_time_ms', current_time_start)
        frame['meta']['frame_index'] = cursor
        frame_buffer.append(frame)
        total_frames += 1
        cursor += 1
        _add_elapsed_ms(timing, 'backend_step_export_frame_build_ms', frame_start)

    frames = list(frame_buffer)
    if not frames or last_chan is None:
        raise RuntimeError('native CChan(lv_list) step_load returned no frames')

    final_start = perf_counter()
    final = _snapshot_from_chan(
        exporter=exporter,
        chan=last_chan,
        kl_types=kl_types,
        level_order=level_order,
        bars_by_level=bars_by_level,
        config=config,
        main=main,
        clock=clock,
        mode_name='step',
        cursor=total_frames - 1,
    )
    _add_elapsed_ms(timing, 'backend_step_export_final_snapshot_ms', final_start)

    meta = dict(final['meta'])
    meta.update({
        'symbol': f'{code}.{market_name}',
        'name': code,
        'adjust': adjust.upper(),
        'prepared_code': prepared_code,
        'native_step_frames': True,
        'native_step_frames_total': total_frames,
        'native_step_frames_returned': len(frames),
        'native_step_frames_limit': max_frames,
        'native_step_frames_truncated': total_frames > len(frames),
        'native_data_window': data_meta,
        'native_csv_time_policy': 'effective-time sort/dedupe; non-intraday parent levels are written to CSV at 23:59 while UI bars keep original times',
        'warnings': ['native CChan(lv_list).step_load() path is active'],
        'backend_step_export_total_frames': total_frames,
        'backend_step_export_returned_frames': len(frames),
        'step_frame_format': 'compact_v1',
        'compact_first_step_frame_export': True,
    })
    return {
        'ok': True,
        'main_level': main,
        'levels': final['levels'],
        'relations': final['relations'],
        'frames': frames,
        'meta': meta,
    }


def analyze_multi_native_timed(
    *,
    symbol: str,
    market: str | None,
    levels: list[str] | str | None,
    adjust: str = 'QFQ',
    mode: str = 'once',
    main_level: str | None = None,
    clock_level: str | None = None,
    start: str | None = None,
    end: str | None = None,
    count: int = 50000,
    config: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Timed App-adapter wrapper for native CChan(lv_list) analysis.

    This function intentionally reuses the existing native engine helpers and only
    adds metadata timings. It must not change chan.py calculation semantics.
    """
    total_start = perf_counter()
    timing: dict[str, Any] = {}
    reset_easy_tdx_cache_stats()
    try:
        code = normalize_symbol(symbol)
        market_name = (market or infer_market(code)).upper()
        level_order = _normalize_levels(levels)
        main = (main_level or level_order[0]).upper()
        if main not in level_order:
            main = level_order[0]
        clock = (clock_level or main).upper()
        if clock not in level_order:
            clock = main
        mode_name = (mode or 'once').lower()

        data_start = perf_counter()
        bars_by_level, data_meta = _load_aligned_bars_by_level(
            code=code,
            market_name=market_name,
            level_order=level_order,
            adjust=adjust,
            count=count,
            start=start,
            end=end,
        )
        timing['backend_native_data_load_ms'] = _elapsed_ms(data_start)
        timing.update(_cache_timing_meta())

        prepare_start = perf_counter()
        exporter, chan, kl_types, prepared_code = _prepare_native_chan(
            code=code,
            level_order=level_order,
            bars_by_level=bars_by_level,
            adjust=adjust,
            config=config,
            trigger_step=mode_name == 'step',
        )
        timing['backend_native_prepare_chan_ms'] = _elapsed_ms(prepare_start)

        if mode_name == 'step':
            step_start = perf_counter()
            result = _timed_native_step_response(
                exporter=exporter,
                chan=chan,
                kl_types=kl_types,
                level_order=level_order,
                bars_by_level=bars_by_level,
                data_meta=data_meta,
                prepared_code=prepared_code,
                code=code,
                market_name=market_name,
                adjust=adjust,
                main=main,
                clock=clock,
                config=config,
                timing=timing,
            )
            timing['backend_native_step_export_ms'] = _elapsed_ms(step_start)
        else:
            once_start = perf_counter()
            result = _native_once_response(
                exporter=exporter,
                chan=chan,
                kl_types=kl_types,
                level_order=level_order,
                bars_by_level=bars_by_level,
                data_meta=data_meta,
                prepared_code=prepared_code,
                code=code,
                market_name=market_name,
                adjust=adjust,
                main=main,
                clock=clock,
                config=config,
            )
            timing['backend_native_once_export_ms'] = _elapsed_ms(once_start)

        timing['backend_native_total_ms'] = _elapsed_ms(total_start)
        return _merge_timing(result, timing)
    except Exception as exc:
        timing.update(_cache_timing_meta())
        timing['backend_native_total_ms'] = _elapsed_ms(total_start)
        failure = _timed_native_failure_response(
            symbol=symbol,
            market=market,
            levels=levels,
            adjust=adjust,
            mode=mode,
            main_level=main_level,
            clock_level=clock_level,
            exc=exc,
        )
        return _merge_timing(failure, timing)
