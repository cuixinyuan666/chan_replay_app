from __future__ import annotations

from datetime import datetime, time
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


def _level_intraday_bars_per_day(level: str) -> int:
    text = level.upper().replace('K_', '').replace('M', 'MIN')
    mapping = {
        'MIN1': 240,
        '1MIN': 240,
        'MIN5': 48,
        '5MIN': 48,
        'MIN15': 16,
        '15MIN': 16,
        'MIN30': 8,
        '30MIN': 8,
        'MIN60': 4,
        '60MIN': 4,
        'DAILY': 1,
        'DAY': 1,
        'K_DAY': 1,
        'WEEKLY': 1,
        'MONTHLY': 1,
    }
    return mapping.get(text, 1)


def _is_intraday_level(level: str) -> bool:
    return _level_intraday_bars_per_day(level) > 1


def _effective_csv_dt(level: str, row: dict[str, Any]) -> datetime | None:
    row_dt = _parse_bar_dt(row)
    if row_dt is None:
        return None
    if _is_intraday_level(level):
        return row_dt
    return datetime.combine(row_dt.date(), time(23, 59))


def _expanded_count_for_level(level: str, top_bar_count: int, requested_count: int) -> int:
    bars_per_day = _level_intraday_bars_per_day(level)
    estimated = int(top_bar_count * bars_per_day * 1.35) + 500
    return min(200000, max(int(requested_count), estimated))


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
    top_bars = load_easy_tdx_bars(
        symbol=code,
        market=market_name,
        period=top_level,
        adjust=adjust,
        count=count,
        start=start,
        end=end,
    )
    if not top_bars:
        raise RuntimeError(f'{top_level} 没有获取到K线数据')

    top_start, top_end = _date_range_for_bars(top_bars)
    if top_start is None or top_end is None:
        raise RuntimeError(f'{top_level} K线缺少可解析时间字段')

    data_start = start or datetime.combine(top_start.date(), time.min).isoformat(sep=' ')
    data_end = end or datetime.combine(top_end.date(), time.max).isoformat(sep=' ')
    bars_by_level: dict[str, list[dict[str, Any]]] = {top_level: top_bars}
    requested_counts: dict[str, int] = {top_level: int(count)}

    for level in level_order[1:]:
        level_count = _expanded_count_for_level(level, len(top_bars), int(count))
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
        'alignment_policy': 'expanded sub-level count + common date trim + effective-time sort/dedupe',
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
    chan_config = CChanConfig(_config_dict(trigger_step=False, config=config))
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
    )

    level_results: dict[str, dict[str, Any]] = {}
    for level, kl_type in zip(level_order, kl_types):
        level_obj = exporter.get_level(chan, kl_type)
        structures = _export_level(exporter, level_obj)
        level_results[level] = _level_payload(
            bars=bars_by_level[level],
            structures=structures,
            config=config,
        )

    relations = _native_relations(
        level_order=level_order,
        kl_types=kl_types,
        chan=chan,
        exporter=exporter,
    )
    warnings = ['native CChan(lv_list) path is active']
    if mode_name == 'step':
        warnings.append('native step frames are not exported yet; final multi-level structures are returned')

    return {
        'ok': True,
        'main_level': main,
        'levels': level_results,
        'relations': relations,
        'frames': [],
        'meta': {
            'engine': 'chan.py',
            'source': 'origin_vespa_tdx.backend.a_multilevel_native_engine',
            'mode': mode_name,
            'symbol': f'{code}.{market_name}',
            'name': code,
            'levels': level_order,
            'main_level': main,
            'clock_level': clock,
            'adjust': adjust.upper(),
            'prepared_code': prepared_code,
            'native_cchan_lv_list': True,
            'level_relation_mode': 'chan_parent_child',
            'chan_py_polluted': False,
            'native_step_frames': False,
            'native_data_window': data_meta,
            'native_csv_time_policy': 'effective-time sort/dedupe; non-intraday parent levels are written to CSV at 23:59 while UI bars keep original times',
            'warnings': warnings,
        },
    }
