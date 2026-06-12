from __future__ import annotations

from time import perf_counter
from typing import Any

from .a_multilevel_native_engine import (
    _load_aligned_bars_by_level,
    _native_once_response,
    _native_step_response,
    _normalize_levels,
    _prepare_native_chan,
)
from .easy_tdx_provider import infer_market, normalize_symbol


def _elapsed_ms(start: float) -> int:
    return int((perf_counter() - start) * 1000)


def _merge_timing(result: dict[str, Any], timing: dict[str, int]) -> dict[str, Any]:
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
    timing: dict[str, int] = {}
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
            result = _native_step_response(
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
