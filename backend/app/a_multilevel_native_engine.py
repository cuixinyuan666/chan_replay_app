from __future__ import annotations

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
    for level, kl_type in zip(level_order, kl_types):
        csv_path = _bars_to_csv(bars_by_level[level], f'{prepared_code_base}_{level.lower()}')
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

    bars_by_level = {
        level: load_easy_tdx_bars(
            symbol=code,
            market=market_name,
            period=level,
            adjust=adjust,
            count=count,
            start=start,
            end=end,
        )
        for level in level_order
    }

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
            'warnings': warnings,
        },
    }
