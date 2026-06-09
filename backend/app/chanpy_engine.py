from __future__ import annotations

import csv
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Any, Iterable

from .easy_tdx_provider import infer_market, load_easy_tdx_bars, normalize_symbol


def _project_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _load_exporter() -> Any:
    root = _project_root()
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
    from tools.chanpy_compare import chanpy_export

    return chanpy_export


def _chanpy_path() -> str:
    env = os.environ.get('CHANPY_PATH') or os.environ.get('CHAN_PY_PATH')
    if env:
        return env
    bundled = _project_root() / 'python' / 'chan.py'
    if bundled.exists():
        return str(bundled)
    local = _project_root() / 'chan.py'
    if local.exists():
        return str(local)
    return str(_project_root().parent / 'chan.py')


def _safe_code(value: str) -> str:
    text = re.sub(r'[^0-9A-Za-z_]+', '_', value.strip())
    return text.strip('_') or 'local_csv'


def _bars_to_csv(bars: list[dict[str, Any]], symbol: str) -> Path:
    root = Path(tempfile.gettempdir()) / 'chan_replay_app_origin'
    root.mkdir(parents=True, exist_ok=True)
    path = root / f'{_safe_code(symbol)}_input.csv'
    with path.open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['time', 'open', 'high', 'low', 'close', 'volume'])
        writer.writeheader()
        for bar in bars:
            open_ = float(bar['open'])
            high = float(bar['high'])
            low = float(bar['low'])
            close = float(bar['close'])
            writer.writerow({
                'time': bar.get('dt') or bar.get('time') or bar.get('date'),
                'open': open_,
                'high': max(open_, high, low, close),
                'low': min(open_, high, low, close),
                'close': close,
                'volume': bar.get('vol') or bar.get('volume') or 0,
            })
    return path


def _bool(value: Any, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in ('1', 'true', 'yes', 'y', 'on')


def _config_dict(*, trigger_step: bool, config: dict[str, Any] | None = None) -> dict[str, Any]:
    cfg = config or {}
    return {
        'trigger_step': trigger_step,
        'skip_step': int(cfg.get('skip_step') or 0),
        'seg_algo': str(cfg.get('seg_algo') or 'chan'),
        'bi_algo': str(cfg.get('bi_algo') or 'normal'),
        'bi_strict': _bool(cfg.get('bi_strict'), True),
        'zs_algo': str(cfg.get('zs_algo') or 'normal'),
        'zs_combine': _bool(cfg.get('zs_combine'), True),
        'zs_combine_mode': str(cfg.get('zs_combine_mode') or 'zs'),
        'one_bi_zs': _bool(cfg.get('one_bi_zs'), False),
        'bs_type': str(cfg.get('bs_type') or '1,1p,2,2s,3a,3b'),
        'divergence_rate': float(cfg.get('divergence_rate') or float('inf')),
        'min_zs_cnt': int(cfg.get('min_zs_cnt') or 1),
        'max_bs2_rate': float(cfg.get('max_bs2_rate') or 0.9999),
        'bs1_peak': _bool(cfg.get('bs1_peak'), True),
        'bsp2_follow_1': _bool(cfg.get('bsp2_follow_1'), True),
        'bsp3_follow_1': _bool(cfg.get('bsp3_follow_1'), True),
        'bsp3_peak': _bool(cfg.get('bsp3_peak'), False),
        'bsp2s_follow_2': _bool(cfg.get('bsp2s_follow_2'), False),
        'strict_bsp3': _bool(cfg.get('strict_bsp3'), False),
        'bsp3a_max_zs_cnt': int(cfg.get('bsp3a_max_zs_cnt') or 1),
        'macd_algo': str(cfg.get('macd_algo') or 'peak'),
    }


def _attr(obj: Any, names: Iterable[str], default: Any = None) -> Any:
    for name in names:
        if hasattr(obj, name):
            return getattr(obj, name)
    return default


def _call_any(obj: Any, names: Iterable[str], default: Any = None) -> Any:
    for name in names:
        value = getattr(obj, name, None)
        if callable(value):
            try:
                return value()
            except TypeError:
                continue
        if value is not None:
            return value
    return default


def _as_list(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    if isinstance(value, tuple):
        return list(value)
    try:
        return list(value)
    except TypeError:
        return []


def _to_float(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _idx(obj: Any) -> int | None:
    value = _attr(obj, ('idx', 'klu_idx', 'index', 'id'), None)
    return value if isinstance(value, int) else None


def _time(obj: Any) -> str | None:
    value = _attr(obj, ('time', 'time_begin', 'date', 'dt'), None)
    return None if value is None else str(value)


def _iter_list(obj: Any, *names: str) -> list[Any]:
    for name in names:
        value = getattr(obj, name, None)
        if callable(value):
            try:
                value = value()
            except TypeError:
                continue
        rows = _as_list(value)
        if rows:
            return rows
    return []


def _export_merged_bars(level: Any) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    klcs = _iter_list(level, 'lst', 'klc_list', 'klu_list', 'kline_list')
    for i, klc in enumerate(klcs):
        units = _iter_list(klc, 'lst', 'klu_list', 'kl_list', 'units') or [klc]
        raw_indices = [x for x in (_idx(u) for u in units) if x is not None]
        if not raw_indices:
            continue
        high_unit = max(units, key=lambda u: _to_float(_attr(u, ('high',), 0)) or 0)
        low_unit = min(units, key=lambda u: _to_float(_attr(u, ('low',), 0)) or 0)
        first, last = units[0], units[-1]
        high = _to_float(_attr(high_unit, ('high',), None))
        low = _to_float(_attr(low_unit, ('low',), None))
        if high is None or low is None:
            continue
        result.append({
            'index': _idx(klc) if _idx(klc) is not None else i,
            'start_raw_index': min(raw_indices),
            'end_raw_index': max(raw_indices),
            'high_raw_index': _idx(high_unit) if _idx(high_unit) is not None else min(raw_indices),
            'low_raw_index': _idx(low_unit) if _idx(low_unit) is not None else min(raw_indices),
            'time': _time(first) or _time(klc),
            'high_time': _time(high_unit),
            'low_time': _time(low_unit),
            'open': _to_float(_attr(first, ('open',), None)),
            'high': high,
            'low': low,
            'close': _to_float(_attr(last, ('close',), None)),
            'volume': sum((_to_float(_attr(u, ('volume', 'vol'), 0)) or 0) for u in units),
        })
    return result


def _bsp_container_items(container: Any) -> list[Any]:
    if container is None:
        return []
    for method_name in ('getSortedBspList', 'get_latest_bsp', 'bsp_iter', 'bsp_iter_v2'):
        method = getattr(container, method_name, None)
        if not callable(method):
            continue
        try:
            rows = method(0) if method_name == 'get_latest_bsp' else method()
        except TypeError:
            continue
        rows = _as_list(rows)
        if rows:
            return rows
    rows = _as_list(container)
    return rows


def _bsp_type_text(item: Any, is_buy: bool) -> str:
    type2str = getattr(item, 'type2str', None)
    if callable(type2str):
        try:
            text = str(type2str())
        except TypeError:
            text = ''
    else:
        raw = _attr(item, ('type', 'bsp_type', 'bs_type', 'name'), '')
        if isinstance(raw, list):
            text = ','.join(str(getattr(x, 'value', x)) for x in raw)
        else:
            text = str(getattr(raw, 'value', raw))
    prefix = 'B' if is_buy else 'S'
    return f'{prefix}{text or "SP"}'


def _bsp_price(item: Any, klu: Any, line: Any, is_buy: bool) -> float | None:
    # Vespa PlotMeta anchors BSP at bsp.klu.low for buy and bsp.klu.high for sell.
    # Do the same first; direct value / line end value are only compatibility fallbacks.
    if klu is not None:
        if is_buy:
            klu_price = _to_float(_attr(klu, ('low', 'close'), None))
        else:
            klu_price = _to_float(_attr(klu, ('high', 'close'), None))
        if klu_price is not None:
            return klu_price
    direct = _to_float(_attr(item, ('price', 'val', 'value'), None))
    if direct is not None:
        return direct
    return _to_float(_call_any(line, ('get_end_val',), None)) if line is not None else None


def _export_bsp(level: Any) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    containers = [
        ('bi', _attr(level, ('bs_point_lst', 'bs_point_list'), None)),
        ('seg', _attr(level, ('seg_bs_point_lst', 'seg_bs_point_list'), None)),
    ]
    seen: set[tuple[int, str, str]] = set()
    for level_name, container in containers:
        for item in _bsp_container_items(container):
            line = _attr(item, ('bi', 'seg', 'relate_bi', 'related_bi'), None)
            klu = _attr(item, ('klu', 'kl', 'point', 'kline'), None) or _call_any(item, ('get_klu',), None)
            if klu is None and line is not None:
                klu = _call_any(line, ('get_end_klu',), None)
            is_buy = bool(_attr(item, ('is_buy',), False))
            raw_index = _idx(klu)
            price = _bsp_price(item, klu, line, is_buy)
            if raw_index is None or price is None:
                continue
            type_text = _bsp_type_text(item, is_buy)
            key = (raw_index, type_text, level_name)
            if key in seen:
                continue
            seen.add(key)
            line_index = _idx(line)
            result.append({
                'index': len(result),
                'raw_index': raw_index,
                'time': _time(klu),
                'price': price,
                'type': type_text,
                'level': level_name,
                'bi_index': line_index if level_name == 'bi' else None,
                'seg_index': line_index if level_name == 'seg' else None,
                'zs_index': None,
                'confirmed': bool(_attr(item, ('is_sure', 'confirmed'), True)),
            })
    return sorted(result, key=lambda row: (row['raw_index'], row['type']))


def _export_level(exporter: Any, level: Any) -> dict[str, Any]:
    return {
        'merged_bars': _export_merged_bars(level),
        'fx': exporter.export_fx(level),
        'bi': exporter.export_bi(level),
        'seg': exporter.export_seg(level),
        'zs': exporter.export_zs(level),
        'bsp': _export_bsp(level),
    }


def _prepare_chan(*, bars: list[dict[str, Any]], code: str, freq: str, adjust: str, trigger_step: bool, config: dict[str, Any] | None) -> tuple[Any, Any, Any]:
    exporter = _load_exporter()
    chanpy_root = exporter.add_chanpy_path(_chanpy_path())
    CChan, CChanConfig, AUTYPE, DATA_SRC, KL_TYPE = exporter.import_chanpy()
    kl_type = exporter.pick_kl_type(KL_TYPE, freq)
    autype = exporter.pick_autype(AUTYPE, adjust)
    csv_path = _bars_to_csv(bars, code)
    prepared_code = exporter.prepare_chanpy_csv(str(csv_path), chanpy_root, kl_type, f'origin_{_safe_code(code)}')
    chan_config = CChanConfig(_config_dict(trigger_step=trigger_step, config=config))
    chan = exporter.make_cchan(CChan, {
        'code': prepared_code,
        'begin_time': None,
        'end_time': None,
        'data_src': DATA_SRC.CSV,
        'lv_list': [kl_type],
        'config': chan_config,
        'autype': autype,
        'extra_kl': None,
    })
    return exporter, chan, kl_type


def _run_chanpy_export(*, bars: list[dict[str, Any]], code: str, freq: str, adjust: str, config: dict[str, Any] | None) -> dict[str, Any]:
    exporter, chan, kl_type = _prepare_chan(bars=bars, code=code, freq=freq, adjust=adjust, trigger_step=False, config=config)
    level = exporter.get_level(chan, kl_type)
    return _export_level(exporter, level)


def _run_chanpy_step_export(*, bars: list[dict[str, Any]], code: str, freq: str, adjust: str, config: dict[str, Any] | None) -> dict[str, Any]:
    exporter, chan, kl_type = _prepare_chan(bars=bars, code=code, freq=freq, adjust=adjust, trigger_step=True, config=config)
    frames: list[dict[str, Any]] = []
    last_structures: dict[str, Any] = {'merged_bars': [], 'fx': [], 'bi': [], 'seg': [], 'zs': [], 'bsp': []}
    step_iter = getattr(chan, 'step_load', None)
    if not callable(step_iter):
        return {**_run_chanpy_export(bars=bars, code=code, freq=freq, adjust=adjust, config=config), 'frames': []}
    for i, cur_chan in enumerate(step_iter()):
        level = exporter.get_level(cur_chan, kl_type)
        structures = _export_level(exporter, level)
        frame_bars = bars[: min(i + 1, len(bars))]
        frames.append({'bars': frame_bars, **structures})
        last_structures = structures
    return {**last_structures, 'frames': frames}


def _fallback_result(*, bars: list[dict[str, Any]], symbol: str, market: str, freq: str, adjust: str, mode: str, error: Exception) -> dict[str, Any]:
    return {
        'ok': True,
        'bars': bars,
        'merged_bars': [],
        'fx': [],
        'bi': [],
        'seg': [],
        'zs': [],
        'bsp': [],
        'frames': [],
        'meta': {
            'engine': 'chan.py',
            'version': 'external',
            'symbol': f'{symbol}.{market}',
            'name': symbol,
            'freq': freq.upper(),
            'adjust': adjust.upper(),
            'mode': mode,
            'warning': f'chan.py unavailable or failed: {error}',
        },
    }


def _result(*, bars: list[dict[str, Any]], structures: dict[str, Any], code: str, market: str, freq: str, adjust: str, mode: str, config: dict[str, Any] | None) -> dict[str, Any]:
    return {
        'ok': True,
        'bars': bars,
        'merged_bars': structures.get('merged_bars', []),
        'fx': structures.get('fx', []),
        'bi': structures.get('bi', []),
        'seg': structures.get('seg', []),
        'zs': structures.get('zs', []),
        'bsp': structures.get('bsp', []),
        'frames': structures.get('frames', []),
        'meta': {
            'engine': 'chan.py',
            'version': 'external',
            'symbol': f'{code}.{market}',
            'name': code,
            'freq': freq.upper(),
            'adjust': adjust.upper(),
            'mode': mode,
            'config': _config_dict(trigger_step=mode == 'step', config=config),
        },
    }


def analyze_bars(*, bars: list[dict[str, Any]], symbol: str = 'local_csv', market: str = 'LOCAL', freq: str = 'DAILY', adjust: str = 'QFQ', mode: str = 'once', config: dict[str, Any] | None = None) -> dict[str, Any]:
    code = _safe_code(symbol or 'local_csv')
    market_name = (market or 'LOCAL').upper()
    mode_name = (mode or 'once').lower()
    try:
        structures = _run_chanpy_step_export(bars=bars, code=code, freq=freq, adjust=adjust, config=config) if mode_name == 'step' else _run_chanpy_export(bars=bars, code=code, freq=freq, adjust=adjust, config=config)
    except Exception as exc:
        return _fallback_result(bars=bars, symbol=code, market=market_name, freq=freq, adjust=adjust, mode=mode_name, error=exc)
    return _result(bars=bars, structures=structures, code=code, market=market_name, freq=freq, adjust=adjust, mode=mode_name, config=config)


def analyze_once(*, symbol: str, market: str | None, freq: str, adjust: str, start: str | None, end: str | None, count: int = 5000, config: dict[str, Any] | None = None) -> dict[str, Any]:
    code = normalize_symbol(symbol)
    market_name = (market or infer_market(code)).upper()
    bars = load_easy_tdx_bars(symbol=code, market=market_name, period=freq, adjust=adjust, count=count, start=start, end=end)
    return analyze_bars(bars=bars, symbol=code, market=market_name, freq=freq, adjust=adjust, mode='once', config=config)


def analyze_step(*, symbol: str, market: str | None, freq: str, adjust: str, start: str | None, end: str | None, count: int = 5000, config: dict[str, Any] | None = None) -> dict[str, Any]:
    code = normalize_symbol(symbol)
    market_name = (market or infer_market(code)).upper()
    bars = load_easy_tdx_bars(symbol=code, market=market_name, period=freq, adjust=adjust, count=count, start=start, end=end)
    return analyze_bars(bars=bars, symbol=code, market=market_name, freq=freq, adjust=adjust, mode='step', config=config)
