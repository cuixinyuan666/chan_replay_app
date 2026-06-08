from __future__ import annotations

import importlib
import inspect
import json
import sys
import types
from typing import Any, Iterable

from easy_tdx_runtime import infer_market, load_kline_json, normalize_symbol

_ANDROID_BARS: list[dict[str, Any]] = []


class ChanPyRuntimeError(RuntimeError):
    pass


def _enum_value(enum_cls: Any, *names: str) -> Any:
    for name in names:
        if hasattr(enum_cls, name):
            return getattr(enum_cls, name)
    raise ChanPyRuntimeError(f'chan.py 枚举缺少字段: {names}')


def _import_chanpy() -> dict[str, Any]:
    try:
        return {
            'CChan': importlib.import_module('Chan').CChan,
            'CChanConfig': importlib.import_module('ChanConfig').CChanConfig,
            'AUTYPE': importlib.import_module('Common.CEnum').AUTYPE,
            'KL_TYPE': importlib.import_module('Common.CEnum').KL_TYPE,
            'DATA_FIELD': importlib.import_module('Common.CEnum').DATA_FIELD,
            'CKLine_Unit': importlib.import_module('KLine.KLine_Unit').CKLine_Unit,
            'CTime': importlib.import_module('Common.CTime').CTime,
            'CCommonStockApi': importlib.import_module('DataAPI.CommonStockAPI').CCommonStockApi,
        }
    except Exception as exc:
        raise ChanPyRuntimeError('APK 内无法导入 chan.py；请确认 python/chan.py 已被 Chaquopy 打包') from exc


def _kl_type(freq: str, KL_TYPE: Any) -> Any:
    f = freq.upper()
    mapping = {
        'DAY': ('K_DAY', 'DAY'), 'DAILY': ('K_DAY', 'DAY'), 'D': ('K_DAY', 'DAY'),
        'WEEK': ('K_WEEK', 'WEEK'), 'WEEKLY': ('K_WEEK', 'WEEK'), 'W': ('K_WEEK', 'WEEK'),
        'MONTH': ('K_MON', 'K_MONTH', 'MONTH'), 'MONTHLY': ('K_MON', 'K_MONTH', 'MONTH'), 'M': ('K_MON', 'K_MONTH', 'MONTH'),
        'MIN1': ('K_1M', 'K_1MIN', 'MIN1'), 'MIN5': ('K_5M', 'K_5MIN', 'MIN5'),
        'MIN15': ('K_15M', 'K_15MIN', 'MIN15'), 'MIN30': ('K_30M', 'K_30MIN', 'MIN30'), 'MIN60': ('K_60M', 'K_60MIN', 'MIN60'),
    }
    return _enum_value(KL_TYPE, *mapping.get(f, ('K_DAY', 'DAY')))


def _autype(adjust: str, AUTYPE: Any) -> Any:
    a = adjust.upper()
    if a == 'QFQ':
        return _enum_value(AUTYPE, 'QFQ', 'AUTYPE_QFQ')
    if a == 'HFQ':
        return _enum_value(AUTYPE, 'HFQ', 'AUTYPE_HFQ')
    return _enum_value(AUTYPE, 'NONE', 'AUTYPE_NONE')


def _bool(value: Any, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in ('1', 'true', 'yes', 'y', 'on')


def _parse_time(value: Any, CTime: Any) -> Any:
    text = str(value or '').replace('/', '-').strip()
    if ' ' in text:
        date_part, time_part = text.split(' ', 1)
    elif 'T' in text:
        date_part, time_part = text.split('T', 1)
    else:
        date_part, time_part = text, '00:00'
    year, month, day = [int(x) for x in date_part[:10].split('-')]
    hour = minute = 0
    if time_part:
        parts = time_part.split(':')
        if len(parts) >= 2:
            hour = int(parts[0])
            minute = int(parts[1])
    return CTime(year, month, day, hour, minute)


def _install_memory_data_api(lib: dict[str, Any]) -> str:
    module_name = 'DataAPI.AndroidRuntimeAPI'
    CCommonStockApi = lib['CCommonStockApi']
    CKLine_Unit = lib['CKLine_Unit']
    CTime = lib['CTime']
    DATA_FIELD = lib['DATA_FIELD']

    class AndroidRuntimeAPI(CCommonStockApi):  # type: ignore[misc]
        def get_kl_data(self):
            for bar in _ANDROID_BARS:
                open_ = float(bar['open'])
                high = float(bar['high'])
                low = float(bar['low'])
                close = float(bar['close'])
                item = {
                    DATA_FIELD.FIELD_TIME: _parse_time(bar.get('dt') or bar.get('time') or bar.get('date'), CTime),
                    DATA_FIELD.FIELD_OPEN: open_,
                    DATA_FIELD.FIELD_HIGH: max(open_, high, low, close),
                    DATA_FIELD.FIELD_LOW: min(open_, high, low, close),
                    DATA_FIELD.FIELD_CLOSE: close,
                }
                yield CKLine_Unit(item)

        def SetBasciInfo(self):
            self.name = self.code
            self.is_stock = True

        @classmethod
        def do_init(cls):
            pass

        @classmethod
        def do_close(cls):
            pass

    module = types.ModuleType(module_name)
    module.AndroidRuntimeAPI = AndroidRuntimeAPI
    sys.modules[module_name] = module
    return 'custom:AndroidRuntimeAPI.AndroidRuntimeAPI'


def _config(CChanConfig: Any, *, trigger_step: bool, config: dict[str, Any] | None) -> Any:
    cfg = config or {}
    data = {
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
    try:
        return CChanConfig(data)
    except TypeError:
        sig = inspect.signature(CChanConfig)
        return CChanConfig(**{k: v for k, v in data.items() if k in sig.parameters})


def _make_cchan(CChan: Any, params: dict[str, Any]) -> Any:
    sig = inspect.signature(CChan)
    return CChan(**{k: v for k, v in params.items() if k in sig.parameters})


def _get_level(chan: Any, kl_type: Any) -> Any:
    kl_datas = getattr(chan, 'kl_datas', None)
    if isinstance(kl_datas, dict):
        return kl_datas.get(kl_type) or next(iter(kl_datas.values()))
    if isinstance(kl_datas, list) and kl_datas:
        return kl_datas[0]
    for name in ('kl_list', 'levels'):
        value = getattr(chan, name, None)
        if isinstance(value, list) and value:
            return value[0]
    raise ChanPyRuntimeError('无法读取 chan.py level 数据')


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


def _to_float(value: Any) -> Any:
    try:
        return float(value)
    except (TypeError, ValueError):
        return value


def _idx(obj: Any) -> int | None:
    value = _attr(obj, ('idx', 'klu_idx', 'index', 'id'), None)
    return value if isinstance(value, int) else None


def _time(obj: Any) -> str | None:
    value = _attr(obj, ('time', 'time_begin', 'date', 'dt'), None)
    return None if value is None else str(value)


def _dir_text(value: Any) -> str:
    return str(value or '').lower()


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


def _is_top_text(text: str) -> bool:
    lower = text.lower()
    return 'top' in lower or 'ding' in lower or 'peak' in lower or 'fx_type.top' in lower


def _is_bottom_text(text: str) -> bool:
    lower = text.lower()
    return 'bottom' in lower or 'di' in lower or 'fx_type.bottom' in lower


def _is_top_fx(fx: Any) -> bool:
    return _is_top_text(str(_attr(fx, ('fx', 'fx_type', 'type'), '') or ''))


def _is_valid_fx(fx: Any) -> bool:
    text = str(_attr(fx, ('fx', 'fx_type', 'type'), '') or '')
    lower = text.lower()
    return (_is_top_text(text) or _is_bottom_text(text)) and 'unknown' not in lower and 'none' not in lower


def _peak_klu(klc: Any, is_top: bool) -> Any:
    if klc is None:
        return None
    method = getattr(klc, 'get_peak_klu', None)
    if callable(method):
        try:
            return method(is_high=is_top)
        except TypeError:
            try:
                return method(is_top)
            except TypeError:
                pass
    return _call_any(klc, ('get_high_peak_klu',), None) if is_top else _call_any(klc, ('get_low_peak_klu',), None)


def _price(obj: Any, is_top: bool) -> float | None:
    for name in (('high', 'peak_high') if is_top else ('low', 'peak_low')):
        value = getattr(obj, name, None)
        if isinstance(value, (int, float)):
            return float(value)
    return None


def _export_merged_bars(level: Any) -> list[dict[str, Any]]:
    result = []
    for i, klc in enumerate(_iter_list(level, 'lst', 'klc_list', 'klu_list', 'kline_list')):
        units = _iter_list(klc, 'lst', 'klu_list', 'kl_list', 'units') or [klc]
        raw_indices = [x for x in (_idx(u) for u in units) if x is not None]
        if not raw_indices:
            continue
        high_unit = max(units, key=lambda u: _to_float(_attr(u, ('high',), 0)) or 0)
        low_unit = min(units, key=lambda u: _to_float(_attr(u, ('low',), 0)) or 0)
        first, last = units[0], units[-1]
        result.append({
            'index': _idx(klc) if _idx(klc) is not None else i,
            'start_raw_index': min(raw_indices),
            'end_raw_index': max(raw_indices),
            'high_raw_index': _idx(high_unit) or min(raw_indices),
            'low_raw_index': _idx(low_unit) or min(raw_indices),
            'time': _time(first) or _time(klc),
            'high_time': _time(high_unit),
            'low_time': _time(low_unit),
            'open': _to_float(_attr(first, ('open',), None)),
            'high': _to_float(_attr(high_unit, ('high',), None)),
            'low': _to_float(_attr(low_unit, ('low',), None)),
            'close': _to_float(_attr(last, ('close',), None)),
            'volume': sum((_to_float(_attr(u, ('volume', 'vol'), 0)) or 0) for u in units),
        })
    return result


def _export_fx(level: Any) -> list[dict[str, Any]]:
    result = []
    source = _iter_list(level, 'fx_list', 'fx_lst') or [item for item in _as_list(getattr(level, 'lst', None)) if _is_valid_fx(item)]
    for i, fx in enumerate(source):
        is_top = _is_top_fx(fx)
        peak = _peak_klu(fx, is_top) or fx
        result.append({'index': _idx(fx) if _idx(fx) is not None else i, 'raw_index': _idx(peak), 'time': _time(peak), 'type': 'top' if is_top else 'bottom', 'price': _price(peak, is_top), 'confirmed': True})
    return result


def _export_bi(level: Any) -> list[dict[str, Any]]:
    result = []
    for i, bi in enumerate(_iter_list(level, 'bi_list', 'bi_list_lst', 'bi_lst')):
        direction = _dir_text(_attr(bi, ('dir', 'direction', 'bi_dir'), ''))
        is_down = 'down' in direction
        begin = _call_any(bi, ('get_begin_klu',), None) or _peak_klu(_attr(bi, ('begin_klc', 'start_klc', 'begin', 'start'), None), is_down) or _attr(bi, ('begin_klu',), None)
        end = _call_any(bi, ('get_end_klu',), None) or _peak_klu(_attr(bi, ('end_klc', 'end'), None), not is_down) or _attr(bi, ('end_klu',), None)
        result.append({'index': _idx(bi) if _idx(bi) is not None else i, 'start_raw_index': _idx(begin), 'end_raw_index': _idx(end), 'start_time': _time(begin), 'end_time': _time(end), 'start_price': _to_float(_call_any(bi, ('get_begin_val',), None)), 'end_price': _to_float(_call_any(bi, ('get_end_val',), None)), 'direction': 'down' if is_down else 'up', 'is_sure': bool(getattr(bi, 'is_sure', True))})
    return result


def _export_seg(level: Any) -> list[dict[str, Any]]:
    result = []
    for i, seg in enumerate(_iter_list(level, 'seg_list', 'seg_lst')):
        start_bi = _attr(seg, ('start_bi', 'begin_bi', 'begin'), None)
        end_bi = _attr(seg, ('end_bi', 'end'), None)
        direction = _dir_text(_attr(seg, ('dir', 'direction', 'bi_dir'), ''))
        result.append({'index': _idx(seg) if _idx(seg) is not None else i, 'start_bi_index': getattr(start_bi, 'idx', None), 'end_bi_index': getattr(end_bi, 'idx', None), 'start_raw_index': _idx(_call_any(seg, ('get_begin_klu',), None)), 'end_raw_index': _idx(_call_any(seg, ('get_end_klu',), None)), 'start_price': _to_float(_call_any(seg, ('get_begin_val',), None)), 'end_price': _to_float(_call_any(seg, ('get_end_val',), None)), 'direction': 'down' if 'down' in direction else 'up', 'is_sure': bool(getattr(seg, 'is_sure', True))})
    return result


def _export_zs(level: Any) -> list[dict[str, Any]]:
    result = []
    for i, zs in enumerate(_iter_list(level, 'zs_list', 'zs_lst')):
        begin_bi = _attr(zs, ('begin_bi', 'start_bi', 'bi_in'), None)
        end_bi = _attr(zs, ('end_bi', 'bi_out'), None)
        result.append({'index': _idx(zs) if _idx(zs) is not None else i, 'start_bi_index': getattr(begin_bi, 'idx', None), 'end_bi_index': getattr(end_bi, 'idx', None), 'start_raw_index': _idx(_attr(zs, ('begin',), None)), 'end_raw_index': _idx(_attr(zs, ('end',), None)), 'zg': _to_float(_attr(zs, ('high', 'zg'), None)), 'zd': _to_float(_attr(zs, ('low', 'zd'), None)), 'gg': _to_float(_attr(zs, ('peak_high', 'gg'), None)), 'dd': _to_float(_attr(zs, ('peak_low', 'dd'), None)), 'confirmed': bool(getattr(zs, 'is_sure', False))})
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
    return _as_list(container)


def _bsp_type_text(item: Any, is_buy: bool) -> str:
    type2str = getattr(item, 'type2str', None)
    if callable(type2str):
        try:
            text = str(type2str())
        except TypeError:
            text = ''
    else:
        raw = _attr(item, ('type', 'bsp_type', 'bs_type', 'name'), '')
        text = ','.join(str(getattr(x, 'value', x)) for x in raw) if isinstance(raw, list) else str(getattr(raw, 'value', raw))
    return f'{"B" if is_buy else "S"}{text or "SP"}'


def _bsp_price(item: Any, klu: Any, bi: Any, is_buy: bool) -> Any:
    direct = _to_float(_attr(item, ('price', 'val', 'value'), None))
    if direct is not None:
        return direct
    bi_val = _to_float(_call_any(bi, ('get_end_val',), None)) if bi is not None else None
    if bi_val is not None:
        return bi_val
    return _to_float(_attr(klu, ('low', 'close'), None)) if is_buy else _to_float(_attr(klu, ('high', 'close'), None))


def _export_bsp(level: Any) -> list[dict[str, Any]]:
    result = []
    seen = set()
    containers = [('bi', _attr(level, ('bs_point_lst', 'bs_point_list'), None)), ('seg', _attr(level, ('seg_bs_point_lst', 'seg_bs_point_list'), None))]
    for level_name, container in containers:
        for item in _bsp_container_items(container):
            bi = _attr(item, ('bi', 'relate_bi', 'related_bi'), None)
            klu = _attr(item, ('klu', 'kl', 'point', 'kline'), None) or _call_any(item, ('get_klu',), None)
            if klu is None and bi is not None:
                klu = _call_any(bi, ('get_end_klu',), None)
            is_buy = bool(_attr(item, ('is_buy',), False))
            raw_index = _idx(klu)
            price = _bsp_price(item, klu, bi, is_buy)
            if raw_index is None or price is None:
                continue
            type_text = _bsp_type_text(item, is_buy)
            key = (raw_index, type_text, level_name)
            if key in seen:
                continue
            seen.add(key)
            result.append({'index': len(result), 'raw_index': raw_index, 'time': _time(klu), 'price': price, 'type': type_text, 'level': level_name, 'bi_index': _idx(bi), 'seg_index': _idx(bi) if level_name == 'seg' else None, 'zs_index': None, 'confirmed': bool(_attr(item, ('is_sure', 'confirmed'), True))})
    return sorted(result, key=lambda row: (row['raw_index'], row['type']))


def _snapshot(chan: Any, kl_type: Any) -> dict[str, Any]:
    level = _get_level(chan, kl_type)
    return {'merged_bars': _export_merged_bars(level), 'fx': _export_fx(level), 'bi': _export_bi(level), 'seg': _export_seg(level), 'zs': _export_zs(level), 'bsp': _export_bsp(level)}


def _run_chanpy(bars: list[dict[str, Any]], code: str, freq: str, adjust: str, mode: str, config: dict[str, Any] | None) -> dict[str, Any]:
    global _ANDROID_BARS
    _ANDROID_BARS = list(bars)
    lib = _import_chanpy()
    kl_type = _kl_type(freq, lib['KL_TYPE'])
    autype = _autype(adjust, lib['AUTYPE'])
    data_src = _install_memory_data_api(lib)
    trigger_step = mode == 'step'
    chan = _make_cchan(lib['CChan'], {'code': code, 'begin_time': None, 'end_time': None, 'data_src': data_src, 'lv_list': [kl_type], 'config': _config(lib['CChanConfig'], trigger_step=trigger_step, config=config), 'autype': autype, 'extra_kl': None})
    if trigger_step and callable(getattr(chan, 'step_load', None)):
        frames = []
        latest = {'merged_bars': [], 'fx': [], 'bi': [], 'seg': [], 'zs': [], 'bsp': []}
        for i, cur_chan in enumerate(chan.step_load()):
            latest = _snapshot(cur_chan, kl_type)
            frames.append({'bars': bars[: min(i + 1, len(bars))], **latest})
        return {**latest, 'frames': frames}
    return {**_snapshot(chan, kl_type), 'frames': []}


def _result(ok: bool, *, bars: list[dict[str, Any]], code: str, market: str, freq: str, adjust: str, mode: str, warning: str | None = None, error: str | None = None, structures: dict[str, Any] | None = None, config: dict[str, Any] | None = None) -> str:
    structures = structures or {}
    data = {'ok': ok, 'bars': bars, 'merged_bars': structures.get('merged_bars', []), 'fx': structures.get('fx', []), 'bi': structures.get('bi', []), 'seg': structures.get('seg', []), 'zs': structures.get('zs', []), 'bsp': structures.get('bsp', []), 'frames': structures.get('frames', []), 'meta': {'engine': 'chan.py', 'platform': 'android-chaquopy', 'symbol': f'{code}.{market}', 'name': code, 'freq': freq, 'adjust': adjust, 'mode': mode, 'config': config or {}}}
    if warning:
        data['meta']['warning'] = warning
    if error:
        data['error'] = error
    return json.dumps(data, ensure_ascii=False)


def analyze_json(payload_json: str) -> str:
    payload = json.loads(payload_json or '{}')
    code = normalize_symbol(str(payload.get('symbol') or payload.get('code') or '000001'))
    market = str(payload.get('market') or infer_market(code)).upper()
    freq = str(payload.get('freq') or payload.get('period') or 'DAILY').upper()
    adjust = str(payload.get('adjust') or 'QFQ').upper()
    mode = str(payload.get('mode') or 'once').lower()
    config = payload.get('config') if isinstance(payload.get('config'), dict) else {}
    bars = payload.get('bars') if isinstance(payload.get('bars'), list) else None
    if bars is None:
        kline_payload = dict(payload)
        kline_payload['symbol'] = code
        kline_payload['market'] = market
        kline_payload['freq'] = freq
        kline_payload['adjust'] = adjust
        bars_result = json.loads(load_kline_json(json.dumps(kline_payload, ensure_ascii=False)))
        bars = bars_result.get('bars') or []
        if not bars_result.get('ok', False):
            return _result(False, bars=[], code=code, market=market, freq=freq, adjust=adjust, mode=mode, error=bars_result.get('error') or 'Android easy-tdx 获取K线失败', config=config)
    try:
        structures = _run_chanpy(bars, code, freq, adjust, mode, config)
        return _result(True, bars=bars, code=code, market=market, freq=freq, adjust=adjust, mode=mode, structures=structures, config=config)
    except Exception as exc:
        return _result(True, bars=bars, code=code, market=market, freq=freq, adjust=adjust, mode=mode, warning=f'Android chan.py 导出失败，已降级仅显示K线: {type(exc).__name__}: {exc}', config=config)
