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
            'DATA_SRC': importlib.import_module('Common.CEnum').DATA_SRC,
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
        'DAY': ('K_DAY', 'DAY'),
        'DAILY': ('K_DAY', 'DAY'),
        'D': ('K_DAY', 'DAY'),
        'WEEK': ('K_WEEK', 'WEEK'),
        'WEEKLY': ('K_WEEK', 'WEEK'),
        'W': ('K_WEEK', 'WEEK'),
        'MONTH': ('K_MON', 'K_MONTH', 'MONTH'),
        'MONTHLY': ('K_MON', 'K_MONTH', 'MONTH'),
        'M': ('K_MON', 'K_MONTH', 'MONTH'),
        'MIN1': ('K_1M', 'K_1MIN', 'MIN1'),
        'MIN5': ('K_5M', 'K_5MIN', 'MIN5'),
        'MIN15': ('K_15M', 'K_15MIN', 'MIN15'),
        'MIN30': ('K_30M', 'K_30MIN', 'MIN30'),
        'MIN60': ('K_60M', 'K_60MIN', 'MIN60'),
    }
    return _enum_value(KL_TYPE, *mapping.get(f, ('K_DAY', 'DAY')))


def _autype(adjust: str, AUTYPE: Any) -> Any:
    a = adjust.upper()
    if a == 'QFQ':
        return _enum_value(AUTYPE, 'QFQ', 'AUTYPE_QFQ')
    if a == 'HFQ':
        return _enum_value(AUTYPE, 'HFQ', 'AUTYPE_HFQ')
    return _enum_value(AUTYPE, 'NONE', 'AUTYPE_NONE')


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


def _config(CChanConfig: Any, *, trigger_step: bool) -> Any:
    data = {
        'trigger_step': trigger_step,
        'skip_step': 0,
        'seg_algo': 'chan',
        'bi_algo': 'normal',
        'bi_strict': True,
        'zs_algo': 'normal',
        'zs_combine': True,
        'zs_combine_mode': 'zs',
        'one_bi_zs': False,
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


def _call(obj: Any, name: str, *args: Any) -> Any:
    method = getattr(obj, name, None)
    if callable(method):
        try:
            return method(*args)
        except TypeError:
            return method()
    return None


def _attr(obj: Any, names: Iterable[str], default: Any = None) -> Any:
    for name in names:
        if hasattr(obj, name):
            value = getattr(obj, name)
            if callable(value) and name.startswith('get_'):
                try:
                    return value()
                except TypeError:
                    continue
            return value
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
    if isinstance(value, int):
        return value
    return None


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
    text = str(_attr(fx, ('fx', 'fx_type', 'type'), '') or '')
    return _is_top_text(text)


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
    if is_top:
        return _call_any(klc, ('get_high_peak_klu',), None)
    return _call_any(klc, ('get_low_peak_klu',), None)


def _price(obj: Any, is_top: bool) -> float | None:
    for name in (('high', 'peak_high') if is_top else ('low', 'peak_low')):
        value = getattr(obj, name, None)
        if isinstance(value, (int, float)):
            return float(value)
    return None


def _export_fx(level: Any) -> list[dict[str, Any]]:
    result = []
    source = _iter_list(level, 'fx_list', 'fx_lst')
    if not source:
        source = [item for item in _as_list(getattr(level, 'lst', None)) if _is_valid_fx(item)]
    for i, fx in enumerate(source):
        is_top = _is_top_fx(fx)
        peak = _peak_klu(fx, is_top) or fx
        result.append({
            'index': _idx(fx) if _idx(fx) is not None else i,
            'raw_index': _idx(peak),
            'time': _time(peak),
            'type': 'top' if is_top else 'bottom',
            'price': _price(peak, is_top),
            'confirmed': True,
        })
    return result


def _export_bi(level: Any) -> list[dict[str, Any]]:
    result = []
    for i, bi in enumerate(_iter_list(level, 'bi_list', 'bi_list_lst', 'bi_lst')):
        begin = _call_any(bi, ('get_begin_klu',), None) or _peak_klu(_attr(bi, ('begin_klc', 'start_klc', 'begin', 'start'), None), False) or _attr(bi, ('begin_klu',), None)
        end = _call_any(bi, ('get_end_klu',), None) or _peak_klu(_attr(bi, ('end_klc', 'end'), None), True) or _attr(bi, ('end_klu',), None)
        begin_val = _call_any(bi, ('get_begin_val',), None)
        end_val = _call_any(bi, ('get_end_val',), None)
        direction = _dir_text(_attr(bi, ('dir', 'direction', 'bi_dir'), ''))
        result.append({
            'index': _idx(bi) if _idx(bi) is not None else i,
            'start_raw_index': _idx(begin),
            'end_raw_index': _idx(end),
            'start_time': _time(begin),
            'end_time': _time(end),
            'start_price': _to_float(begin_val),
            'end_price': _to_float(end_val),
            'direction': 'down' if 'down' in direction else 'up',
            'is_sure': bool(getattr(bi, 'is_sure', True)),
        })
    return result


def _export_seg(level: Any) -> list[dict[str, Any]]:
    result = []
    for i, seg in enumerate(_iter_list(level, 'seg_list', 'seg_lst')):
        start_bi = _attr(seg, ('start_bi', 'begin_bi', 'begin'), None)
        end_bi = _attr(seg, ('end_bi', 'end'), None)
        begin_klu = _call_any(seg, ('get_begin_klu',), None)
        end_klu = _call_any(seg, ('get_end_klu',), None)
        direction = _dir_text(_attr(seg, ('dir', 'direction', 'bi_dir'), ''))
        result.append({
            'index': _idx(seg) if _idx(seg) is not None else i,
            'start_bi_index': getattr(start_bi, 'idx', None),
            'end_bi_index': getattr(end_bi, 'idx', None),
            'start_raw_index': _idx(begin_klu),
            'end_raw_index': _idx(end_klu),
            'start_price': _to_float(_call_any(seg, ('get_begin_val',), None)),
            'end_price': _to_float(_call_any(seg, ('get_end_val',), None)),
            'direction': 'down' if 'down' in direction else 'up',
            'is_sure': bool(getattr(seg, 'is_sure', True)),
        })
    return result


def _export_zs(level: Any) -> list[dict[str, Any]]:
    result = []
    for i, zs in enumerate(_iter_list(level, 'zs_list', 'zs_lst')):
        begin_bi = _attr(zs, ('begin_bi', 'start_bi', 'bi_in'), None)
        end_bi = _attr(zs, ('end_bi', 'bi_out'), None)
        result.append({
            'index': _idx(zs) if _idx(zs) is not None else i,
            'start_bi_index': getattr(begin_bi, 'idx', None),
            'end_bi_index': getattr(end_bi, 'idx', None),
            'start_raw_index': _idx(_attr(zs, ('begin',), None)),
            'end_raw_index': _idx(_attr(zs, ('end',), None)),
            'zg': _to_float(_attr(zs, ('high', 'zg'), None)),
            'zd': _to_float(_attr(zs, ('low', 'zd'), None)),
            'gg': _to_float(_attr(zs, ('peak_high', 'gg'), None)),
            'dd': _to_float(_attr(zs, ('peak_low', 'dd'), None)),
            'confirmed': bool(getattr(zs, 'is_sure', False)),
        })
    return result


def _snapshot(chan: Any, kl_type: Any) -> dict[str, Any]:
    level = _get_level(chan, kl_type)
    return {
        'fx': _export_fx(level),
        'bi': _export_bi(level),
        'seg': _export_seg(level),
        'zs': _export_zs(level),
    }


def _run_chanpy(bars: list[dict[str, Any]], code: str, freq: str, adjust: str, mode: str) -> dict[str, Any]:
    global _ANDROID_BARS
    _ANDROID_BARS = list(bars)
    lib = _import_chanpy()
    kl_type = _kl_type(freq, lib['KL_TYPE'])
    autype = _autype(adjust, lib['AUTYPE'])
    data_src = _install_memory_data_api(lib)
    trigger_step = mode == 'step'
    chan = _make_cchan(lib['CChan'], {
        'code': code,
        'begin_time': None,
        'end_time': None,
        'data_src': data_src,
        'lv_list': [kl_type],
        'config': _config(lib['CChanConfig'], trigger_step=trigger_step),
        'autype': autype,
        'extra_kl': None,
    })

    if trigger_step and callable(getattr(chan, 'step_load', None)):
        frames = []
        latest = {'fx': [], 'bi': [], 'seg': [], 'zs': []}
        for i, cur_chan in enumerate(chan.step_load()):
            latest = _snapshot(cur_chan, kl_type)
            frames.append({'bars': bars[: min(i + 1, len(bars))], **latest})
        return {**latest, 'frames': frames}

    return {**_snapshot(chan, kl_type), 'frames': []}


def _result(ok: bool, *, bars: list[dict[str, Any]], code: str, market: str, freq: str, adjust: str, mode: str, warning: str | None = None, error: str | None = None, structures: dict[str, Any] | None = None) -> str:
    structures = structures or {}
    data = {
        'ok': ok,
        'bars': bars,
        'fx': structures.get('fx', []),
        'bi': structures.get('bi', []),
        'seg': structures.get('seg', []),
        'zs': structures.get('zs', []),
        'bsp': structures.get('bsp', []),
        'frames': structures.get('frames', []),
        'meta': {
            'engine': 'chan.py',
            'platform': 'android-chaquopy',
            'symbol': f'{code}.{market}',
            'name': code,
            'freq': freq,
            'adjust': adjust,
            'mode': mode,
        },
    }
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

    kline_payload = dict(payload)
    kline_payload['symbol'] = code
    kline_payload['market'] = market
    kline_payload['freq'] = freq
    kline_payload['adjust'] = adjust
    bars_result = json.loads(load_kline_json(json.dumps(kline_payload, ensure_ascii=False)))
    bars = bars_result.get('bars') or []
    if not bars_result.get('ok', False):
        return _result(False, bars=[], code=code, market=market, freq=freq, adjust=adjust, mode=mode, error=bars_result.get('error') or 'Android easy-tdx 获取K线失败')

    try:
        structures = _run_chanpy(bars, code, freq, adjust, mode)
        return _result(True, bars=bars, code=code, market=market, freq=freq, adjust=adjust, mode=mode, structures=structures)
    except Exception as exc:
        return _result(True, bars=bars, code=code, market=market, freq=freq, adjust=adjust, mode=mode, warning=f'Android chan.py 导出失败，已降级仅显示K线: {type(exc).__name__}: {exc}')
