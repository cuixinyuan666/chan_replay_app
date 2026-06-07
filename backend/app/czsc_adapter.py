from __future__ import annotations

from datetime import datetime
from typing import Any


def _parse_dt(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    text = str(value).strip()
    if not text:
        return None
    text = text.replace('T', ' ')
    for fmt in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%d %H:%M', '%Y-%m-%d'):
        try:
            return datetime.strptime(text[:19], fmt)
        except ValueError:
            pass
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def _get(obj: Any, *names: str, default: Any = None) -> Any:
    for name in names:
        if isinstance(obj, dict) and name in obj:
            return obj[name]
        if hasattr(obj, name):
            return getattr(obj, name)
    return default


def _text(value: Any) -> str:
    if value is None:
        return ''
    if hasattr(value, 'value'):
        return str(value.value)
    if hasattr(value, 'name'):
        return str(value.name)
    return str(value)


def _is_top(mark: Any) -> bool:
    text = _text(mark).lower()
    return text in {'g', 'top', '顶', 'mark.g', 'fx.top'} or 'top' in text or '顶' in text


def _direction(value: Any) -> str:
    text = _text(value).lower()
    if text in {'up', '向上', 'direction.up'} or 'up' in text or '向上' in text:
        return 'up'
    return 'down'


def _dt_index_map(bars: list[dict[str, Any]]) -> dict[str, int]:
    result: dict[str, int] = {}
    for i, bar in enumerate(bars):
        dt = _parse_dt(bar.get('dt'))
        if dt is None:
            continue
        result[dt.isoformat(sep=' ')] = i
        result[dt.date().isoformat()] = i
    return result


def _find_bar_id(bars: list[dict[str, Any]], dt: Any, fallback: int = 0) -> int:
    parsed = _parse_dt(dt)
    if parsed is None:
        return max(0, min(fallback, len(bars) - 1)) if bars else 0
    keys = _dt_index_map(bars)
    return keys.get(parsed.isoformat(sep=' '), keys.get(parsed.date().isoformat(), fallback))


def _freq_obj(freq: str) -> Any:
    try:
        from czsc import Freq
    except Exception:
        try:
            from czsc.enum import Freq
        except Exception:
            return freq
    f = freq.upper()
    candidates = {
        '1M': ('F1', 'MIN1', 'M1'),
        'MIN1': ('F1', 'MIN1', 'M1'),
        '5M': ('F5', 'MIN5', 'M5'),
        'MIN5': ('F5', 'MIN5', 'M5'),
        '15M': ('F15', 'MIN15', 'M15'),
        'MIN15': ('F15', 'MIN15', 'M15'),
        '30M': ('F30', 'MIN30', 'M30'),
        'MIN30': ('F30', 'MIN30', 'M30'),
        '60M': ('F60', 'MIN60', 'M60'),
        'MIN60': ('F60', 'MIN60', 'M60'),
        'D': ('D', 'DAY', 'DAILY'),
        'DAILY': ('D', 'DAY', 'DAILY'),
        'W': ('W', 'WEEK', 'WEEKLY'),
        'WEEKLY': ('W', 'WEEK', 'WEEKLY'),
        'M': ('M', 'MONTH', 'MONTHLY'),
        'MONTHLY': ('M', 'MONTH', 'MONTHLY'),
    }.get(f, ('D', 'DAY', 'DAILY'))
    for name in candidates:
        if hasattr(Freq, name):
            return getattr(Freq, name)
    return freq


def _raw_bar_obj(bar: dict[str, Any], freq_obj: Any, symbol: str) -> Any:
    try:
        from czsc import RawBar
    except Exception:
        from czsc.objects import RawBar

    kwargs = {
        'symbol': symbol,
        'id': int(bar.get('id', 0)),
        'freq': freq_obj,
        'dt': _parse_dt(bar.get('dt')),
        'open': float(bar['open']),
        'close': float(bar['close']),
        'high': float(bar['high']),
        'low': float(bar['low']),
        'vol': float(bar.get('vol', bar.get('volume', 0)) or 0),
        'amount': float(bar.get('amount', 0) or 0),
    }
    try:
        return RawBar(**kwargs)
    except TypeError:
        kwargs.pop('amount', None)
        return RawBar(**kwargs)


def analyze_with_czsc(
    *,
    bars: list[dict[str, Any]],
    symbol: str,
    freq: str,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        'symbol': symbol,
        'freq': freq,
        'bars': bars,
        'new_bars': [],
        'fx': [],
        'bi': [],
        'seg': [],
        'zs': [],
        'signals': {},
        'engine': 'czsc',
        'engine_warning': None,
    }
    if len(bars) < 3:
        payload['engine_warning'] = 'K线数量不足，CZSC 元素为空'
        return payload

    try:
        from czsc import CZSC
    except Exception:
        try:
            from czsc.analyze import CZSC
        except Exception as exc:
            payload['engine_warning'] = f'未能导入 CZSC: {exc}'
            return payload

    try:
        freq_obj = _freq_obj(freq)
        raw_bars = [_raw_bar_obj(bar, freq_obj, symbol) for bar in bars]
        c = CZSC(raw_bars)
    except Exception as exc:
        payload['engine_warning'] = f'CZSC 初始化失败: {exc}'
        return payload

    # 去包含后的 K 线。字段名随 czsc 版本可能变化，所以这里做宽松提取。
    for i, nb in enumerate(_get(c, 'bars_ubi', 'bars_nubi', 'new_bars', default=[]) or []):
        dt = _get(nb, 'dt')
        payload['new_bars'].append(
            {
                'id': i,
                'dt': dt.isoformat(sep=' ') if hasattr(dt, 'isoformat') else str(dt),
                'open': float(_get(nb, 'open', default=0) or 0),
                'high': float(_get(nb, 'high', default=0) or 0),
                'low': float(_get(nb, 'low', default=0) or 0),
                'close': float(_get(nb, 'close', default=0) or 0),
                'vol': float(_get(nb, 'vol', 'volume', default=0) or 0),
                'start_bar_id': _find_bar_id(bars, _get(nb, 'sdt', 'dt'), i),
                'end_bar_id': _find_bar_id(bars, _get(nb, 'edt', 'dt'), i),
            }
        )

    fx_list = _get(c, 'fx_list', 'fxs', default=[]) or []
    for i, fx in enumerate(fx_list):
        mark = _get(fx, 'mark', 'type')
        is_top = _is_top(mark)
        dt = _get(fx, 'dt')
        bar_id = _find_bar_id(bars, dt, i)
        price = _get(fx, 'fx', 'price', default=None)
        if price is None:
            price = _get(fx, 'high' if is_top else 'low', default=bars[bar_id]['high' if is_top else 'low'])
        payload['fx'].append(
            {
                'index': i,
                'type': 'top' if is_top else 'bottom',
                'bar_id': bar_id,
                'dt': bars[bar_id]['dt'] if bars else str(dt),
                'price': float(price),
                'confirmed': bool(_get(fx, 'confirmed', 'is_sure', default=True)),
            }
        )

    bi_list = _get(c, 'bi_list', 'bis', default=[]) or []
    for i, bi in enumerate(bi_list):
        fx_a = _get(bi, 'fx_a', 'start', 'start_fx')
        fx_b = _get(bi, 'fx_b', 'end', 'end_fx')
        start_dt = _get(bi, 'sdt', default=_get(fx_a, 'dt'))
        end_dt = _get(bi, 'edt', default=_get(fx_b, 'dt'))
        start_bar_id = _find_bar_id(bars, start_dt, 0)
        end_bar_id = _find_bar_id(bars, end_dt, start_bar_id)
        direction = _direction(_get(bi, 'direction', 'dir'))
        start_price = _get(fx_a, 'fx', 'price', default=None)
        end_price = _get(fx_b, 'fx', 'price', default=None)
        if start_price is None:
            start_price = bars[start_bar_id]['low' if direction == 'up' else 'high']
        if end_price is None:
            end_price = bars[end_bar_id]['high' if direction == 'up' else 'low']
        payload['bi'].append(
            {
                'index': i,
                'start_bar_id': start_bar_id,
                'end_bar_id': end_bar_id,
                'start_price': float(start_price),
                'end_price': float(end_price),
                'direction': direction,
                'is_sure': bool(_get(bi, 'is_sure', 'confirmed', default=True)),
            }
        )

    seg_list = _get(c, 'seg_list', 'segs', default=[]) or []
    for i, seg in enumerate(seg_list):
        start_bi_index = int(_get(seg, 'start_bi_index', 'sbi', default=0) or 0)
        end_bi_index = int(_get(seg, 'end_bi_index', 'ebi', default=start_bi_index) or start_bi_index)
        if payload['bi'] and start_bi_index < len(payload['bi']) and end_bi_index < len(payload['bi']):
            start_bar_id = payload['bi'][start_bi_index]['start_bar_id']
            end_bar_id = payload['bi'][end_bi_index]['end_bar_id']
            start_price = payload['bi'][start_bi_index]['start_price']
            end_price = payload['bi'][end_bi_index]['end_price']
        else:
            start_bar_id = _find_bar_id(bars, _get(seg, 'sdt'), 0)
            end_bar_id = _find_bar_id(bars, _get(seg, 'edt'), start_bar_id)
            start_price = bars[start_bar_id]['close']
            end_price = bars[end_bar_id]['close']
        payload['seg'].append(
            {
                'index': i,
                'start_bi_index': start_bi_index,
                'end_bi_index': end_bi_index,
                'start_bar_id': start_bar_id,
                'end_bar_id': end_bar_id,
                'start_price': float(start_price),
                'end_price': float(end_price),
                'direction': _direction(_get(seg, 'direction', 'dir')),
                'is_sure': bool(_get(seg, 'is_sure', 'confirmed', default=True)),
            }
        )

    zs_list = _get(c, 'zs_list', 'zss', default=[]) or []
    for i, zs in enumerate(zs_list):
        sdt = _get(zs, 'sdt', 'start_dt')
        edt = _get(zs, 'edt', 'end_dt')
        start_bar_id = _find_bar_id(bars, sdt, 0)
        end_bar_id = _find_bar_id(bars, edt, start_bar_id)
        payload['zs'].append(
            {
                'index': i,
                'start_bar_id': start_bar_id,
                'end_bar_id': end_bar_id,
                'start_bi_index': int(_get(zs, 'start_bi_index', default=0) or 0),
                'end_bi_index': int(_get(zs, 'end_bi_index', default=0) or 0),
                'zg': float(_get(zs, 'zg', 'high', default=0) or 0),
                'zd': float(_get(zs, 'zd', 'low', default=0) or 0),
                'gg': float(_get(zs, 'gg', 'peak_high', default=_get(zs, 'zg', 'high', default=0)) or 0),
                'dd': float(_get(zs, 'dd', 'peak_low', default=_get(zs, 'zd', 'low', default=0)) or 0),
                'confirmed': bool(_get(zs, 'is_sure', 'confirmed', default=True)),
            }
        )

    signals = _get(c, 'signals', 's', default={}) or {}
    if isinstance(signals, dict):
        payload['signals'] = {str(k): str(v) for k, v in signals.items()}
    return payload
