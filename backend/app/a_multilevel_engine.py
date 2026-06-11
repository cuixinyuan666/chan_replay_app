from __future__ import annotations

from datetime import date, datetime, time
from typing import Any

from .a_indicator_export import build_display_indicators, indicator_source_meta
from .a_multilevel_native_engine import analyze_multi_native
from .chanpy_engine import analyze_once
from .easy_tdx_provider import infer_market, normalize_symbol

_INTRADAY_PREFIXES = ('MIN', 'K_')
_DAILY_LEVELS = {'DAY', 'DAILY', 'K_DAY'}


def _normalize_levels(value: Any) -> list[str]:
    if isinstance(value, str):
        raw = [part.strip() for part in value.replace('，', ',').split(',')]
    elif isinstance(value, list):
        raw = [str(part).strip() for part in value]
    else:
        raw = []
    result: list[str] = []
    for item in raw:
        level = item.upper()
        if level and level not in result:
            result.append(level)
    return result or ['DAILY', 'MIN30', 'MIN5']


def _level_is_daily(level: str) -> bool:
    return level.upper() in _DAILY_LEVELS


def _level_is_intraday(level: str) -> bool:
    text = level.upper()
    return text.startswith(_INTRADAY_PREFIXES) or text.endswith('M')


def _parse_dt(value: Any) -> datetime | None:
    if value is None:
        return None
    text = str(value).strip().replace('/', '-').replace(' ', 'T')
    if not text or text.lower() == 'null':
        return None
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        try:
            return datetime.combine(date.fromisoformat(text[:10]), time.min)
        except ValueError:
            return None


def _bar_time(row: dict[str, Any]) -> datetime | None:
    return _parse_dt(row.get('dt') or row.get('datetime') or row.get('date') or row.get('time'))


def _row_int(row: dict[str, Any], *keys: str) -> int | None:
    for key in keys:
        value = row.get(key)
        if value is None:
            continue
        try:
            return int(value)
        except (TypeError, ValueError):
            continue
    return None


def _copy_meta_with_indicators(result: dict[str, Any], config: dict[str, Any] | None) -> dict[str, Any]:
    patched = dict(result)
    bars = patched.get('bars')
    if isinstance(bars, list):
        patched['indicators'] = build_display_indicators(bars, config)
    meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
    sources = dict(meta.get('indicator_sources')) if isinstance(meta.get('indicator_sources'), dict) else {}
    sources.update(indicator_source_meta())
    meta['indicator_sources'] = sources
    patched['meta'] = meta
    return patched


def _level_result_without_outer_meta(result: dict[str, Any], config: dict[str, Any] | None) -> dict[str, Any]:
    patched = _copy_meta_with_indicators(result, config)
    return {
        'bars': patched.get('bars', []),
        'merged_bars': patched.get('merged_bars', []),
        'fx': patched.get('fx', []),
        'bi': patched.get('bi', []),
        'seg': patched.get('seg', []),
        'zs': patched.get('zs', []),
        'bsp': patched.get('bsp', []),
        'indicators': patched.get('indicators', {}),
        'meta': patched.get('meta', {}),
    }


def _visible_bar_count(level_result: dict[str, Any], cutoff: datetime, *, include_same_day: bool) -> int:
    bars = level_result.get('bars')
    if not isinstance(bars, list):
        return 0
    count = 0
    for row in bars:
        if not isinstance(row, dict):
            continue
        row_time = _bar_time(row)
        if row_time is None:
            continue
        visible = row_time <= cutoff or (include_same_day and row_time.date() <= cutoff.date())
        if visible:
            count += 1
        else:
            break
    return count


def _slice_level_result(
    level_result: dict[str, Any],
    cutoff: datetime,
    *,
    include_same_day: bool,
    config: dict[str, Any] | None,
) -> dict[str, Any]:
    bars = level_result.get('bars') if isinstance(level_result.get('bars'), list) else []
    visible_count = _visible_bar_count(level_result, cutoff, include_same_day=include_same_day)
    visible_bars = list(bars[:visible_count])

    merged_bars = [
        row for row in level_result.get('merged_bars', [])
        if isinstance(row, dict) and (_row_int(row, 'end_raw_index', 'endRawIndex') or -1) < visible_count
    ]
    fxs = [
        row for row in level_result.get('fx', [])
        if isinstance(row, dict) and (_row_int(row, 'raw_index', 'rawIndex') or -1) < visible_count
    ]
    bis = [
        row for row in level_result.get('bi', [])
        if isinstance(row, dict) and (_row_int(row, 'end_raw_index', 'endRawIndex') or -1) < visible_count
    ]
    visible_bi_count = len(bis)
    segs = [
        row for row in level_result.get('seg', [])
        if isinstance(row, dict) and (_row_int(row, 'end_bi_index', 'endBiIndex') or -1) < visible_bi_count
    ]
    zss = [
        row for row in level_result.get('zs', [])
        if isinstance(row, dict)
        and (
            (_row_int(row, 'end_raw_index', 'endRawIndex') is not None and (_row_int(row, 'end_raw_index', 'endRawIndex') or -1) < visible_count)
            or (_row_int(row, 'end_bi_index', 'endBiIndex') is not None and (_row_int(row, 'end_bi_index', 'endBiIndex') or -1) < visible_bi_count)
        )
    ]
    bsps = [
        row for row in level_result.get('bsp', [])
        if isinstance(row, dict) and (_row_int(row, 'raw_index', 'rawIndex') or -1) < visible_count
    ]
    return {
        'bars': visible_bars,
        'merged_bars': merged_bars,
        'fx': fxs,
        'bi': bis,
        'seg': segs,
        'zs': zss,
        'bsp': bsps,
        'indicators': build_display_indicators(visible_bars, config),
        'meta': level_result.get('meta', {}),
    }


def _build_relations(
    *,
    parent_level: str,
    child_level: str,
    parent_result: dict[str, Any],
    child_result: dict[str, Any],
) -> list[dict[str, Any]]:
    parent_bars = parent_result.get('bars') if isinstance(parent_result.get('bars'), list) else []
    child_bars = child_result.get('bars') if isinstance(child_result.get('bars'), list) else []
    child_times = [(_bar_time(row), i) for i, row in enumerate(child_bars) if isinstance(row, dict)]
    relations: list[dict[str, Any]] = []
    prev_parent_time: datetime | None = None
    for parent_index, parent_row in enumerate(parent_bars):
        if not isinstance(parent_row, dict):
            continue
        parent_time = _bar_time(parent_row)
        if parent_time is None:
            continue
        matched: list[int] = []
        for child_time, child_index in child_times:
            if child_time is None:
                continue
            if _level_is_daily(parent_level) and _level_is_intraday(child_level):
                in_parent = child_time.date() == parent_time.date()
            else:
                after_previous = prev_parent_time is None or child_time > prev_parent_time
                in_parent = after_previous and child_time <= parent_time
            if in_parent:
                matched.append(child_index)
        if matched:
            relations.append({
                'parent_level': parent_level,
                'parent_raw_index': parent_index,
                'child_level': child_level,
                'child_start_raw_index': min(matched),
                'child_end_raw_index': max(matched),
            })
        prev_parent_time = parent_time
    return relations


def _build_all_relations(level_order: list[str], levels: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    relations: list[dict[str, Any]] = []
    for i in range(len(level_order) - 1):
        parent_level = level_order[i]
        child_level = level_order[i + 1]
        parent_result = levels.get(parent_level)
        child_result = levels.get(child_level)
        if not isinstance(parent_result, dict) or not isinstance(child_result, dict):
            continue
        relations.extend(_build_relations(
            parent_level=parent_level,
            child_level=child_level,
            parent_result=parent_result,
            child_result=child_result,
        ))
    return relations


def _build_step_frames(
    *,
    level_order: list[str],
    levels: dict[str, dict[str, Any]],
    clock_level: str,
    config: dict[str, Any] | None,
) -> list[dict[str, Any]]:
    clock_result = levels.get(clock_level)
    if not isinstance(clock_result, dict):
        return []
    clock_bars = clock_result.get('bars') if isinstance(clock_result.get('bars'), list) else []
    frames: list[dict[str, Any]] = []
    for cursor, clock_row in enumerate(clock_bars):
        if not isinstance(clock_row, dict):
            continue
        cutoff = _bar_time(clock_row)
        if cutoff is None:
            continue
        frame_levels: dict[str, dict[str, Any]] = {}
        for level in level_order:
            level_result = levels.get(level)
            if not isinstance(level_result, dict):
                continue
            include_same_day = _level_is_daily(clock_level) and _level_is_intraday(level)
            frame_levels[level] = _slice_level_result(
                level_result,
                cutoff,
                include_same_day=include_same_day,
                config=config,
            )
        frames.append({
            'main_level': level_order[0],
            'clock_level': clock_level,
            'cursor': cursor,
            'current_time': str(clock_row.get('dt') or clock_row.get('time') or clock_row.get('date')),
            'levels': frame_levels,
            'relations': _build_all_relations(level_order, frame_levels),
            'meta': {
                'mode': 'step',
                'clock_level': clock_level,
                'levels': level_order,
                'cursor': cursor,
                'native_cchan_lv_list': False,
                'level_relation_mode': 'time_date_bridge',
            },
        })
    return frames


def _analyze_multi_bridge(
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

    level_results: dict[str, dict[str, Any]] = {}
    warnings: list[str] = []
    for level in level_order:
        result = analyze_once(
            symbol=code,
            market=market_name,
            freq=level,
            adjust=adjust,
            start=start,
            end=end,
            count=count,
            config=config,
        )
        if result.get('ok') is False:
            warnings.append(f'{level}: {result.get("error") or "analysis failed"}')
        level_results[level] = _level_result_without_outer_meta(result, config)

    return {
        'ok': not warnings,
        'main_level': main,
        'levels': level_results,
        'relations': _build_all_relations(level_order, level_results),
        'frames': _build_step_frames(
            level_order=level_order,
            levels=level_results,
            clock_level=clock,
            config=config,
        ) if mode_name == 'step' else [],
        'meta': {
            'engine': 'chan.py',
            'source': 'origin_vespa_tdx.backend.a_multilevel_engine.bridge',
            'mode': mode_name,
            'symbol': f'{code}.{market_name}',
            'name': code,
            'levels': level_order,
            'main_level': main,
            'clock_level': clock,
            'adjust': adjust.upper(),
            'native_cchan_lv_list': False,
            'level_relation_mode': 'time_date_bridge',
            'chan_py_polluted': False,
            'bridge_prototype': True,
            'warnings': warnings,
        },
    }


def analyze_multi(
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
    try:
        return analyze_multi_native(
            symbol=symbol,
            market=market,
            levels=levels,
            adjust=adjust,
            mode=mode,
            main_level=main_level,
            clock_level=clock_level,
            start=start,
            end=end,
            count=count,
            config=config,
        )
    except Exception as exc:
        bridge = _analyze_multi_bridge(
            symbol=symbol,
            market=market,
            levels=levels,
            adjust=adjust,
            mode=mode,
            main_level=main_level,
            clock_level=clock_level,
            start=start,
            end=end,
            count=count,
            config=config,
        )
        meta = dict(bridge.get('meta')) if isinstance(bridge.get('meta'), dict) else {}
        warnings = list(meta.get('warnings')) if isinstance(meta.get('warnings'), list) else []
        warnings.insert(0, f'native CChan(lv_list) failed, fallback to bridge: {exc}')
        meta.update({
            'fallback_to_bridge': True,
            'native_failure': str(exc),
            'warnings': warnings,
        })
        bridge['meta'] = meta
        return bridge
