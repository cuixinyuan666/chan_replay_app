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
    """Resolve project period names to CZSC official Freq enum names."""
    from czsc import Freq

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
    return Freq.D


def _bars_to_standard_df(bars: list[dict[str, Any]], symbol: str):
    """Build the standard kline DataFrame required by czsc.format_standard_kline.

    CZSC official examples use:
        bars = format_standard_kline(df, freq=Freq.F30)
        c = CZSC(bars)

    Therefore this adapter keeps the same path and only normalizes easy-tdx rows
    into the required standard columns.
    """
    import pandas as pd

    rows: list[dict[str, Any]] = []
    for i, bar in enumerate(bars):
        rows.append(
            {
                'symbol': bar.get('symbol') or symbol,
                'dt': _parse_dt(bar.get('dt')),
                'id': int(bar.get('id', i)),
                'open': float(bar['open']),
                'close': float(bar['close']),
                'high': float(bar['high']),
                'low': float(bar['low']),
                'vol': float(bar.get('vol', bar.get('volume', 0)) or 0),
                'amount': float(bar.get('amount', 0) or 0),
            }
        )
    df = pd.DataFrame(rows)
    if not df.empty:
        df = df.sort_values('dt').reset_index(drop=True)
        df['id'] = range(len(df))
    return df


def _serialize_new_bars(c: Any, bars: list[dict[str, Any]]) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for i, nb in enumerate(_get(c, 'bars_ubi', 'bars_nubi', 'new_bars', default=[]) or []):
        dt = _get(nb, 'dt')
        items.append(
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
    return items


def _serialize_fx(c: Any, bars: list[dict[str, Any]]) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    fx_list = _get(c, 'fx_list', default=[]) or []
    for i, fx in enumerate(fx_list):
        mark = _get(fx, 'mark')
        is_top = _is_top(mark)
        dt = _get(fx, 'dt')
        bar_id = _find_bar_id(bars, dt, i)
        price = _get(fx, 'fx', default=None)
        if price is None:
            price = _get(fx, 'high' if is_top else 'low', default=bars[bar_id]['high' if is_top else 'low'])
        items.append(
            {
                'index': i,
                'type': 'top' if is_top else 'bottom',
                'bar_id': bar_id,
                'dt': bars[bar_id]['dt'] if bars else str(dt),
                'price': float(price),
                'confirmed': True,
            }
        )
    return items


def _serialize_bi(c: Any, bars: list[dict[str, Any]]) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    bi_list = _get(c, 'bi_list', default=[]) or []
    for i, bi in enumerate(bi_list):
        fx_a = _get(bi, 'fx_a')
        fx_b = _get(bi, 'fx_b')
        start_dt = _get(bi, 'sdt', default=_get(fx_a, 'dt'))
        end_dt = _get(bi, 'edt', default=_get(fx_b, 'dt'))
        start_bar_id = _find_bar_id(bars, start_dt, 0)
        end_bar_id = _find_bar_id(bars, end_dt, start_bar_id)
        direction = _direction(_get(bi, 'direction'))
        start_price = _get(fx_a, 'fx', default=None)
        end_price = _get(fx_b, 'fx', default=None)
        if start_price is None:
            start_price = bars[start_bar_id]['low' if direction == 'up' else 'high']
        if end_price is None:
            end_price = bars[end_bar_id]['high' if direction == 'up' else 'low']
        items.append(
            {
                'index': i,
                'start_bar_id': start_bar_id,
                'end_bar_id': end_bar_id,
                'start_price': float(start_price),
                'end_price': float(end_price),
                'direction': direction,
                'is_sure': True,
            }
        )
    return items


def _serialize_recent_official_zs(c: Any, bars: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], str | None]:
    """Serialize the recent ZS exactly following CZSC official example usage.

    CZSC docs/examples/02_chan_structures.py demonstrates:
        recent = c.bi_list[-7:]
        zs = ZS(recent)
        if zs.is_valid(): ...

    This adapter only uses that official path. It does not scan or invent a full
    historical ZS list.
    """
    bi_list = _get(c, 'bi_list', default=[]) or []
    if len(bi_list) < 3:
        return [], 'CZSC 官方 ZS(bi_list) 调用需要至少 3 笔；当前笔数不足，中枢为空'

    try:
        from czsc import ZS
    except Exception as exc:
        return [], f'未能导入 CZSC 官方 ZS 对象: {exc}'

    recent_start = max(0, len(bi_list) - 7)
    recent = bi_list[recent_start:]
    try:
        zs = ZS(recent)
        is_valid = zs.is_valid() if callable(getattr(zs, 'is_valid', None)) else bool(_get(zs, 'is_valid', default=False))
    except Exception as exc:
        return [], f'CZSC 官方 ZS(c.bi_list[-7:]) 构造失败: {exc}'

    if not is_valid:
        return [], 'CZSC 官方 ZS(c.bi_list[-7:]) 返回无效中枢；中枢为空'

    sdt = _get(zs, 'sdt')
    edt = _get(zs, 'edt')
    start_bar_id = _find_bar_id(bars, sdt, _get(_get(recent[0], 'fx_a'), 'dt', default=0))
    end_bar_id = _find_bar_id(bars, edt, start_bar_id)
    return [
        {
            'index': 0,
            'start_bar_id': start_bar_id,
            'end_bar_id': end_bar_id,
            'start_bi_index': recent_start,
            'end_bi_index': len(bi_list) - 1,
            'zg': float(_get(zs, 'zg', default=0) or 0),
            'zd': float(_get(zs, 'zd', default=0) or 0),
            'zz': float(_get(zs, 'zz', default=0) or 0),
            'gg': float(_get(zs, 'gg', default=0) or 0),
            'dd': float(_get(zs, 'dd', default=0) or 0),
            'sdt': str(sdt),
            'edt': str(edt),
            'source': 'official: ZS(c.bi_list[-7:])',
            'confirmed': True,
        }
    ], None


def analyze_with_czsc(
    *,
    bars: list[dict[str, Any]],
    symbol: str,
    freq: str,
) -> dict[str, Any]:
    warnings: list[str] = []
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
        'meta': {
            'official_path': 'format_standard_kline(df, freq) -> CZSC(bars) -> fx_list/bi_list -> ZS(c.bi_list[-7:])',
            'seg_policy': 'CZSC 当前官方核心示例未暴露 seg_list；不自研线段，seg 保持为空',
            'zs_policy': '按 CZSC 官方示例仅构造最近 7 笔中枢，不自研完整历史中枢列表',
        },
    }
    if len(bars) < 3:
        payload['engine_warning'] = 'K线数量不足，CZSC 元素为空'
        return payload

    try:
        from czsc import CZSC, format_standard_kline
    except Exception as exc:
        payload['engine_warning'] = f'未能导入 CZSC / format_standard_kline: {exc}'
        return payload

    try:
        freq_obj = _freq_obj(freq)
        df = _bars_to_standard_df(bars, symbol)
        raw_bars = format_standard_kline(df, freq=freq_obj)
        c = CZSC(raw_bars)
    except Exception as exc:
        payload['engine_warning'] = f'CZSC 官方路径初始化失败: {exc}'
        return payload

    payload['new_bars'] = _serialize_new_bars(c, bars)
    payload['fx'] = _serialize_fx(c, bars)
    payload['bi'] = _serialize_bi(c, bars)

    # CZSC 官方核心结构目前稳定暴露 fx_list / bi_list；未在官方示例中暴露 seg_list。
    warnings.append('线段 SEG 未按自研逻辑生成：当前仅使用 CZSC 官方暴露结构，seg 保持为空')

    payload['zs'], zs_warning = _serialize_recent_official_zs(c, bars)
    if zs_warning:
        warnings.append(zs_warning)

    signals = _get(c, 'signals', default={}) or {}
    if isinstance(signals, dict):
        payload['signals'] = {str(k): str(v) for k, v in signals.items()}

    payload['meta'].update(
        {
            'counts': {
                'bars': len(bars),
                'new_bars': len(payload['new_bars']),
                'fx': len(payload['fx']),
                'bi': len(payload['bi']),
                'seg': len(payload['seg']),
                'zs': len(payload['zs']),
            },
            'czsc_available_attrs': [
                name for name in ('bars_raw', 'bars_ubi', 'fx_list', 'bi_list', 'signals', 'ubi', 'ubi_fxs', 'zs_list', 'seg_list') if hasattr(c, name)
            ],
        }
    )
    payload['engine_warning'] = '；'.join(warnings) if warnings else None
    return payload
