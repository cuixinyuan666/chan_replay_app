from __future__ import annotations

from collections import deque
from datetime import datetime, time, timedelta
from typing import Any

from .a_indicator_export import build_display_indicators, indicator_source_meta
from .chanpy_engine import (
    _bars_to_csv,
    _chanpy_path,
    _config_dict,
    _export_level,
    _idx,
    _load_exporter,
    _safe_code,
)
from .easy_tdx_provider import infer_market, load_easy_tdx_bars, normalize_symbol


_MAX_EXPANDED_LEVEL_COUNT = 200000
_COUNT_EXPANSION_BUFFER_RATIO = 1.35
_COUNT_EXPANSION_BUFFER_BARS = 500


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


def _parse_bar_dt(row: dict[str, Any]) -> datetime | None:
    value = row.get('dt') or row.get('time') or row.get('datetime') or row.get('date')
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    text = str(value).strip().replace('/', '-').replace('T', ' ')
    if not text or text.lower() == 'null':
        return None
    for fmt in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%d %H:%M', '%Y-%m-%d'):
        try:
            return datetime.strptime(text[:19], fmt)
        except ValueError:
            pass
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def _parse_request_window_bound(value: str | None, *, is_end: bool) -> datetime | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    parsed = _parse_bar_dt({'dt': text})
    if parsed is None:
        return None
    date_only = len(text.replace('/', '-')) <= 10 and ':' not in text
    if date_only:
        return datetime.combine(parsed.date(), time.max if is_end else time.min)
    return parsed


def _level_intraday_bars_per_day(level: str) -> int:
    text = level.upper().strip().replace('K_', '').replace('-', '').replace('_', '')
    aliases = {
        'MIN1': 240,
        '1MIN': 240,
        'M1': 240,
        '1M': 240,
        'MIN5': 48,
        '5MIN': 48,
        'M5': 48,
        '5M': 48,
        'MIN15': 16,
        '15MIN': 16,
        'M15': 16,
        '15M': 16,
        'MIN30': 8,
        '30MIN': 8,
        'M30': 8,
        '30M': 8,
        'MIN60': 4,
        '60MIN': 4,
        'M60': 4,
        '60M': 4,
        'DAILY': 1,
        'DAY': 1,
        'KDAY': 1,
        'WEEKLY': 1,
        'WEEK': 1,
        'MONTHLY': 1,
        'MONTH': 1,
    }
    if text in aliases:
        return aliases[text]
    if text.startswith('MIN') and text[3:].isdigit():
        minutes = max(1, int(text[3:]))
        return max(1, 240 // minutes)
    if text.endswith('MIN') and text[:-3].isdigit():
        minutes = max(1, int(text[:-3]))
        return max(1, 240 // minutes)
    if text.startswith('M') and text[1:].isdigit():
        minutes = max(1, int(text[1:]))
        return max(1, 240 // minutes)
    if text.endswith('M') and text[:-1].isdigit():
        minutes = max(1, int(text[:-1]))
        return max(1, 240 // minutes)
    return 1


def _is_intraday_level(level: str) -> bool:
    return _level_intraday_bars_per_day(level) > 1


def _effective_csv_dt(level: str, row: dict[str, Any]) -> datetime | None:
    row_dt = _parse_bar_dt(row)
    if row_dt is None:
        return None
    if _is_intraday_level(level):
        return row_dt
    return datetime.combine(row_dt.date(), time(23, 59))


def _trading_days_inclusive(start_dt: datetime, end_dt: datetime) -> int:
    start_date = min(start_dt.date(), end_dt.date())
    end_date = max(start_dt.date(), end_dt.date())
    days = 0
    cur = start_date
    while cur <= end_date:
        if cur.weekday() < 5:
            days += 1
        cur += timedelta(days=1)
    return max(1, days)


def _count_expansion_basis(
    level: str,
    requested_count: int,
    window_start: datetime,
    window_end: datetime,
) -> dict[str, int | float | str]:
    bars_per_day = _level_intraday_bars_per_day(level)
    trading_days = _trading_days_inclusive(window_start, window_end)
    window_estimated = int(trading_days * bars_per_day * _COUNT_EXPANSION_BUFFER_RATIO) + _COUNT_EXPANSION_BUFFER_BARS
    expanded_count = min(_MAX_EXPANDED_LEVEL_COUNT, max(int(requested_count), window_estimated))
    return {
        'level': level,
        'requested_count': int(requested_count),
        'bars_per_day': bars_per_day,
        'window_trading_days': trading_days,
        'buffer_ratio': _COUNT_EXPANSION_BUFFER_RATIO,
        'buffer_bars': _COUNT_EXPANSION_BUFFER_BARS,
        'window_estimated_count': window_estimated,
        'expanded_count': expanded_count,
        'window_start': window_start.isoformat(sep=' '),
        'window_end': window_end.isoformat(sep=' '),
    }


def _expanded_count_for_level(
    level: str,
    requested_count: int,
    window_start: datetime,
    window_end: datetime,
) -> int:
    return int(_count_expansion_basis(level, requested_count, window_start, window_end)['expanded_count'])


def _max_step_frames(config: dict[str, Any] | None) -> int:
    raw = (config or {}).get('max_step_frames')
    try:
        value = int(raw)
    except (TypeError, ValueError):
        value = 120
    return max(1, min(1000, value))


def _date_range_for_bars(bars: list[dict[str, Any]]) -> tuple[datetime | None, datetime | None]:
    times = [dt for row in bars if isinstance(row, dict) for dt in [_parse_bar_dt(row)] if dt is not None]
    if not times:
        return None, None
    return min(times), max(times)


def _filter_by_date_window(
    bars: list[dict[str, Any]],
    start_dt: datetime,
    end_dt: datetime,
) -> list[dict[str, Any]]:
    start_date = start_dt.date()
    end_date = end_dt.date()
    result: list[dict[str, Any]] = []
    for row in bars:
        if not isinstance(row, dict):
            continue
        row_dt = _parse_bar_dt(row)
        if row_dt is None:
            continue
        if start_date <= row_dt.date() <= end_date:
            result.append(row)
    return result


def _sort_dedupe_level_bars(level: str, bars: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], int]:
    keyed: dict[datetime, dict[str, Any]] = {}
    for row in bars:
        if not isinstance(row, dict):
            continue
        key = _effective_csv_dt(level, row)
        if key is None:
            continue
        keyed[key] = row
    result = [keyed[key] for key in sorted(keyed)]
    return result, max(0, len(bars) - len(result))


def _common_date_window(
    bars_by_level: dict[str, list[dict[str, Any]]]
) -> tuple[datetime, datetime]:
    starts: list[datetime] = []
    ends: list[datetime] = []
    for bars in bars_by_level.values():
        start_dt, end_dt = _date_range_for_bars(bars)
        if start_dt is None or end_dt is None:
            continue
        starts.append(start_dt)
        ends.append(end_dt)
    if not starts or not ends:
        raise RuntimeError('native CChan(lv_list) 没有可用K线数据')
    start = max(starts)
    end = min(ends)
    start = datetime.combine(start.date(), time.min)
    end = datetime.combine(end.date(), time.max)
    if start.date() > end.date():
        raise RuntimeError(f'native CChan(lv_list) 多级别数据日期没有交集: start={start}, end={end}')
    return start, end


def _load_aligned_bars_by_level(
    *,
    code: str,
    market_name: str,
    level_order: list[str],
    adjust: str,
    count: int,
    start: str | None,
    end: str | None,
) -> tuple[dict[str, list[dict[str, Any]]], dict[str, Any]]:
    top_level = level_order[0]
    requested_start_dt = _parse_request_window_bound(start, is_end=False)
    requested_end_dt = _parse_request_window_bound(end, is_end=True)
    if requested_start_dt is not None and requested_end_dt is not None and requested_start_dt > requested_end_dt:
        raise RuntimeError(f'analyze_multi request window is invalid: start={start}, end={end}')

    top_count = int(count)
    prefetch_count_basis: dict[str, dict[str, int | float | str]] = {}
    if requested_start_dt is not None and requested_end_dt is not None:
        prefetch_count_basis[top_level] = _count_expansion_basis(top_level, int(count), requested_start_dt, requested_end_dt)
        top_count = int(prefetch_count_basis[top_level]['expanded_count'])

    top_bars = load_easy_tdx_bars(
        symbol=code,
        market=market_name,
        period=top_level,
        adjust=adjust,
        count=top_count,
        start=start,
        end=end,
    )
    if not top_bars:
        raise RuntimeError(f'{top_level} 没有获取到K线数据')

    top_start, top_end = _date_range_for_bars(top_bars)
    if top_start is None or top_end is None:
        raise RuntimeError(f'{top_level} K线缺少可解析时间字段')

    data_start_dt = requested_start_dt or datetime.combine(top_start.date(), time.min)
    data_end_dt = requested_end_dt or datetime.combine(top_end.date(), time.max)
    if data_start_dt > data_end_dt:
        raise RuntimeError(f'analyze_multi data window is invalid: start={data_start_dt}, end={data_end_dt}')
    data_start = data_start_dt.isoformat(sep=' ')
    data_end = data_end_dt.isoformat(sep=' ')

    bars_by_level: dict[str, list[dict[str, Any]]] = {top_level: top_bars}
    requested_counts: dict[str, int] = {top_level: top_count}
    count_expansion_basis: dict[str, dict[str, int | float | str]] = {
        top_level: prefetch_count_basis.get(
            top_level,
            {
                **_count_expansion_basis(top_level, int(count), data_start_dt, data_end_dt),
                'expanded_count': top_count,
            },
        )
    }

    for level in level_order[1:]:
        basis = _count_expansion_basis(level, int(count), data_start_dt, data_end_dt)
        level_count = int(basis['expanded_count'])
        count_expansion_basis[level] = basis
        requested_counts[level] = level_count
        bars = load_easy_tdx_bars(
            symbol=code,
            market=market_name,
            period=level,
            adjust=adjust,
            count=level_count,
            start=data_start,
            end=data_end,
        )
        if not bars:
            raise RuntimeError(f'{level} 没有获取到K线数据')
        bars_by_level[level] = bars

    common_start, common_end = _common_date_window(bars_by_level)
    aligned: dict[str, list[dict[str, Any]]] = {}
    duplicates_removed: dict[str, int] = {}
    for level, bars in bars_by_level.items():
        windowed = _filter_by_date_window(bars, common_start, common_end)
        deduped, removed = _sort_dedupe_level_bars(level, windowed)
        aligned[level] = deduped
        duplicates_removed[level] = removed
    empty_levels = [level for level, bars in aligned.items() if not bars]
    if empty_levels:
        raise RuntimeError(f'native CChan(lv_list) 对齐后以下级别无K线: {empty_levels}')

    meta = {
        'top_level': top_level,
        'requested_window': {
            'start': data_start,
            'end': data_end,
            'request_start_provided': start is not None,
            'request_end_provided': end is not None,
        },
        'raw_window': {
            'start': str(top_start),
            'end': str(top_end),
        },
        'common_window': {
            'start': str(common_start),
            'end': str(common_end),
        },
        'requested_counts': requested_counts,
        'raw_counts': {level: len(bars) for level, bars in bars_by_level.items()},
        'aligned_counts': {level: len(bars) for level, bars in aligned.items()},
        'duplicates_removed': duplicates_removed,
        'bars_per_day': {level: _level_intraday_bars_per_day(level) for level in level_order},
        'count_expansion_basis': count_expansion_basis,
        'count_expansion_policy': 'deterministic request-window trading-day estimate + level bars_per_day + 35% buffer + 500, capped at 200000',
        'alignment_policy': 'expanded top/lower-level count + common date trim + effective-time sort/dedupe',
    }
    return aligned, meta


def _bars_for_native_csv(level: str, bars: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for row in bars:
        if not isinstance(row, dict):
            continue
        csv_dt = _effective_csv_dt(level, row)
        if csv_dt is None:
            result.append(row)
            continue
        patched = dict(row)
        patched['dt'] = csv_dt.isoformat(sep=' ')
        patched['time'] = csv_dt.isoformat(sep=' ')
        result.append(patched)
    return result


def _csv_bars_by_level(level_order: list[str], bars_by_level: dict[str, list[dict[str, Any]]]) -> dict[str, list[dict[str, Any]]]:
    return {
        level: _bars_for_native_csv(level, bars_by_level[level])
        for level in level_order
    }


def _patch_indicators(level_result: dict[str, Any], config: dict[str, Any] | None) -> dict[str, Any]:
    bars = level_result.get('bars') if isinstance(level_result.get('bars'), list) else []
    patched = dict(level_result)
    patched['indicators'] = build_display_indicators(bars, config)
    meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
    sources = dict(meta.get('indicator_sources')) if isinstance(meta.get('indicator_sources'), dict) else {}
    sources.update(indicator_source_meta())
    meta['indicator_sources'] = sources
    patched['meta'] = meta
    return patched


def _level_payload(
    *,
    bars: list[dict[str, Any]],
    structures: dict[str, Any],
    config: dict[str, Any] | None,
) -> dict[str, Any]:
    return _patch_indicators({
        'bars': bars,
        'merged_bars': structures.get('merged_bars', []),
        'fx': structures.get('fx', []),
        'bi': structures.get('bi', []),
        'seg': structures.get('seg', []),
        'zs': structures.get('zs', []),
        'bsp': structures.get('bsp', []),
        'meta': {},
    }, config)


def _raw_klu_iter(level: Any) -> list[Any]:
    result: list[Any] = []
    klcs = getattr(level, 'lst', None) or getattr(level, 'klc_list', None) or []
    for klc in list(klcs):
        units = getattr(klc, 'lst', None) or getattr(klc, 'klu_list', None) or [klc]
        for unit in list(units):
            if _idx(unit) is not None:
                result.append(unit)
    return result


def _visible_bars_for_level(level_obj: Any, bars: list[dict[str, Any]]) -> list[dict[str, Any]]:
    indices = [idx for idx in (_idx(klu) for klu in _raw_klu_iter(level_obj)) if idx is not None]
    if not indices:
        return []
    visible_count = min(max(indices) + 1, len(bars))
    return list(bars[:visible_count])


def _native_relations_for_pair(
    *,
    parent_level: str,
    child_level: str,
    parent_obj: Any,
    child_obj: Any,
) -> list[dict[str, Any]]:
    child_indices = {_idx(klu) for klu in _raw_klu_iter(child_obj)}
    child_indices.discard(None)
    relations: list[dict[str, Any]] = []
    for parent_klu in _raw_klu_iter(parent_obj):
        parent_idx = _idx(parent_klu)
        if parent_idx is None:
            continue
        raw_children = getattr(parent_klu, 'sub_kl_list', None) or getattr(parent_klu, 'children', None) or []
        children = []
        for child_klu in list(raw_children):
            child_idx = _idx(child_klu)
            if child_idx is not None and child_idx in child_indices:
                children.append(child_idx)
        if not children:
            continue
        relations.append({
            'parent_level': parent_level,
            'parent_raw_index': parent_idx,
            'child_level': child_level,
            'child_start_raw_index': min(children),
            'child_end_raw_index': max(children),
        })
    return relations


def _native_relations(
    *,
    level_order: list[str],
    kl_types: list[Any],
    chan: Any,
    exporter: Any,
) -> list[dict[str, Any]]:
    relations: list[dict[str, Any]] = []
    for i in range(len(kl_types) - 1):
        parent_obj = exporter.get_level(chan, kl_types[i])
        child_obj = exporter.get_level(chan, kl_types[i + 1])
        relations.extend(_native_relations_for_pair(
            parent_level=level_order[i],
            child_level=level_order[i + 1],
            parent_obj=parent_obj,
            child_obj=child_obj,
        ))
    return relations


def _prepare_native_chan(
    *,
    code: str,
    level_order: list[str],
    bars_by_level: dict[str, list[dict[str, Any]]],
    adjust: str,
    config: dict[str, Any] | None,
    trigger_step: bool,
) -> tuple[Any, Any, list[Any], str]:
    exporter = _load_exporter()
    chanpy_root = exporter.add_chanpy_path(_chanpy_path())
    CChan, CChanConfig, AUTYPE, DATA_SRC, KL_TYPE = exporter.import_chanpy()
    kl_types = [exporter.pick_kl_type(KL_TYPE, level) for level in level_order]
    autype = exporter.pick_autype(AUTYPE, adjust)
    prepared_code_base = f'origin_multi_{_safe_code(code)}'
    prepared_code: str | None = None
    csv_levels = _csv_bars_by_level(level_order, bars_by_level)
    for level, kl_type in zip(level_order, kl_types):
        csv_path = _bars_to_csv(csv_levels[level], f'{prepared_code_base}_{level.lower()}')
        next_code = exporter.prepare_chanpy_csv(str(csv_path), chanpy_root, kl_type, prepared_code_base)
        prepared_code = prepared_code or str(next_code)
    chan_config = CChanConfig(_config_dict(trigger_step=trigger_step, config=config))
    chan = exporter.make_cchan(CChan, {
        'code': prepared_code or prepared_code_base,
        'begin_time': None,
        'end_time': None,
        'data_src': DATA_SRC.CSV,
        'lv_list': kl_types,
        'config': chan_config,
        'autype': autype,
        'extra_kl': None,
    })
    return exporter, chan, kl_types, prepared_code or prepared_code_base


def _snapshot_from_chan(
    *,
    exporter: Any,
    chan: Any,
    kl_types: list[Any],
    level_order: list[str],
    bars_by_level: dict[str, list[dict[str, Any]]],
    config: dict[str, Any] | None,
    main: str,
    clock: str,
    mode_name: str,
    cursor: int | None = None,
    current_time: str | None = None,
    meta_extra: dict[str, Any] | None = None,
) -> dict[str, Any]:
    level_results: dict[str, dict[str, Any]] = {}
    for level, kl_type in zip(level_order, kl_types):
        level_obj = exporter.get_level(chan, kl_type)
        structures = _export_level(exporter, level_obj)
        visible_bars = _visible_bars_for_level(level_obj, bars_by_level[level])
        level_results[level] = _level_payload(
            bars=visible_bars,
            structures=structures,
            config=config,
        )
    relations = _native_relations(
        level_order=level_order,
        kl_types=kl_types,
        chan=chan,
        exporter=exporter,
    )
    meta = {
        'engine': 'chan.py',
        'source': 'origin_vespa_tdx.backend.a_multilevel_native_engine',
        'mode': mode_name,
        'levels': level_order,
        'main_level': main,
        'clock_level': clock,
        'native_cchan_lv_list': True,
        'level_relation_mode': 'chan_parent_child',
        'chan_py_polluted': False,
    }
    if cursor is not None:
        meta['cursor'] = cursor
    if current_time is not None:
        meta['current_time'] = current_time
    if meta_extra:
        meta.update(meta_extra)
    return {
        'main_level': main,
        'levels': level_results,
        'relations': relations,
        'meta': meta,
    }


def _frame_current_time(frame: dict[str, Any], main: str) -> str | None:
    level = frame.get('levels', {}).get(main) if isinstance(frame.get('levels'), dict) else None
    if not isinstance(level, dict):
        return None
    bars = level.get('bars')
    if not isinstance(bars, list) or not bars:
        return None
    last = bars[-1]
    if not isinstance(last, dict):
        return None
    value = last.get('dt') or last.get('time') or last.get('date')
    return None if value is None else str(value)


def _native_once_response(
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
) -> dict[str, Any]:
    snapshot = _snapshot_from_chan(
        exporter=exporter,
        chan=chan,
        kl_types=kl_types,
        level_order=level_order,
        bars_by_level=bars_by_level,
        config=config,
        main=main,
        clock=clock,
        mode_name='once',
        meta_extra={
            'symbol': f'{code}.{market_name}',
            'name': code,
            'adjust': adjust.upper(),
            'prepared_code': prepared_code,
            'native_step_frames': False,
            'native_data_window': data_meta,
            'native_csv_time_policy': 'effective-time sort/dedupe; non-intraday parent levels are written to CSV at 23:59 while UI bars keep original times',
            'warnings': ['native CChan(lv_list) path is active'],
        },
    )
    return {
        'ok': True,
        'main_level': main,
        'levels': snapshot['levels'],
        'relations': snapshot['relations'],
        'frames': [],
        'meta': snapshot['meta'],
    }


def _native_step_response(
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
) -> dict[str, Any]:
    step_iter = getattr(chan, 'step_load', None)
    if not callable(step_iter):
        raise RuntimeError('native CChan(lv_list) does not expose step_load')
    max_frames = _max_step_frames(config)
    frame_buffer: deque[dict[str, Any]] = deque(maxlen=max_frames)
    total_frames = 0
    for cursor, cur_chan in enumerate(step_iter()):
        frame = _snapshot_from_chan(
            exporter=exporter,
            chan=cur_chan,
            kl_types=kl_types,
            level_order=level_order,
            bars_by_level=bars_by_level,
            config=config,
            main=main,
            clock=clock,
            mode_name='step',
            cursor=cursor,
        )
        frame['meta']['current_time'] = _frame_current_time(frame, main)
        frame['meta']['frame_index'] = cursor
        frame_buffer.append(frame)
        total_frames += 1
    frames = list(frame_buffer)
    if not frames:
        raise RuntimeError('native CChan(lv_list) step_load returned no frames')
    final = frames[-1]
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
    })
    return {
        'ok': True,
        'main_level': main,
        'levels': final['levels'],
        'relations': final['relations'],
        'frames': frames,
        'meta': meta,
    }


def analyze_multi_native(
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

    bars_by_level, data_meta = _load_aligned_bars_by_level(
        code=code,
        market_name=market_name,
        level_order=level_order,
        adjust=adjust,
        count=count,
        start=start,
        end=end,
    )

    exporter, chan, kl_types, prepared_code = _prepare_native_chan(
        code=code,
        level_order=level_order,
        bars_by_level=bars_by_level,
        adjust=adjust,
        config=config,
        trigger_step=mode_name == 'step',
    )

    if mode_name == 'step':
        return _native_step_response(
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

    return _native_once_response(
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
