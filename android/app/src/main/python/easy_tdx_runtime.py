from __future__ import annotations

import json
from datetime import date, datetime
from typing import Any


class EasyTdxRuntimeError(RuntimeError):
    pass


def normalize_symbol(symbol: str) -> str:
    return symbol.strip().upper().replace('.SZ', '').replace('.SH', '')


def infer_market(symbol: str) -> str:
    code = normalize_symbol(symbol)
    if code.startswith(('5', '6', '9')):
        return 'SH'
    return 'SZ'


def _enum_value(enum_cls: Any, *names: str) -> Any:
    for name in names:
        if hasattr(enum_cls, name):
            return getattr(enum_cls, name)
    raise EasyTdxRuntimeError(f'easy-tdx 枚举缺少字段: {names}')


def _period_value(period: str, Period: Any) -> Any:
    p = period.upper()
    mapping = {
        '1M': ('MIN_1', 'MIN1', 'M1'),
        'MIN1': ('MIN_1', 'MIN1', 'M1'),
        '5M': ('MIN_5', 'MIN5', 'M5'),
        'MIN5': ('MIN_5', 'MIN5', 'M5'),
        '15M': ('MIN_15', 'MIN15', 'M15'),
        'MIN15': ('MIN_15', 'MIN15', 'M15'),
        '30M': ('MIN_30', 'MIN30', 'M30'),
        'MIN30': ('MIN_30', 'MIN30', 'M30'),
        '60M': ('MIN_60', 'MIN60', 'M60'),
        'MIN60': ('MIN_60', 'MIN60', 'M60'),
        'D': ('DAILY', 'DAY', 'D'),
        'DAILY': ('DAILY', 'DAY', 'D'),
        'W': ('WEEKLY', 'WEEK', 'W'),
        'WEEKLY': ('WEEKLY', 'WEEK', 'W'),
        'M': ('MONTHLY', 'MONTH', 'M'),
        'MONTHLY': ('MONTHLY', 'MONTH', 'M'),
    }
    return _enum_value(Period, *mapping.get(p, ('DAILY', 'DAY', 'D')))


def _adjust_value(adjust: str, Adjust: Any) -> Any:
    a = adjust.upper()
    mapping = {
        'QFQ': ('QFQ', 'FRONT', 'FORWARD'),
        'HFQ': ('HFQ', 'BACK', 'BACKWARD'),
        'NONE': ('NONE', 'NO', 'RAW'),
    }
    return _enum_value(Adjust, *mapping.get(a, ('QFQ', 'FRONT', 'FORWARD')))


def _market_value(market: str, Market: Any) -> Any:
    return _enum_value(Market, 'SH') if market.upper() == 'SH' else _enum_value(Market, 'SZ')


def _parse_dt(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value
    if isinstance(value, date):
        return datetime(value.year, value.month, value.day)
    text = str(value).strip()
    if not text:
        raise ValueError('empty datetime value')
    text = text.replace('/', '-').replace('T', ' ')
    for fmt in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%d %H:%M', '%Y-%m-%d'):
        try:
            return datetime.strptime(text[:19], fmt)
        except ValueError:
            pass
    return datetime.fromisoformat(text)


def _row_get(row: Any, *keys: str, default: Any = None) -> Any:
    for key in keys:
        if isinstance(row, dict) and key in row:
            return row[key]
        if hasattr(row, key):
            return getattr(row, key)
        try:
            return row[key]
        except Exception:
            pass
    return default


def _iter_rows(df: Any):
    if hasattr(df, 'to_dict'):
        return df.to_dict('records')
    return df or []


def _close_client(client: Any) -> None:
    for name in ('close', 'disconnect'):
        method = getattr(client, name, None)
        if callable(method):
            try:
                method()
            except Exception:
                pass
            return


def _get_stock_kline(MacClient: Any, *args: Any, **kwargs: Any) -> Any:
    client = MacClient.from_best_host()
    try:
        if hasattr(client, '__enter__') and hasattr(client, '__exit__'):
            with client as c:
                return c.get_stock_kline(*args, **kwargs)
        return client.get_stock_kline(*args, **kwargs)
    finally:
        _close_client(client)


def load_kline_json(payload_json: str) -> str:
    payload = json.loads(payload_json or '{}')
    try:
        from easy_tdx import Adjust, MacClient, Market, Period
    except Exception as exc:
        return json.dumps({
            'ok': False,
            'error': f'未安装或无法导入 easy-tdx: {exc}',
            'bars': [],
        }, ensure_ascii=False)

    code = normalize_symbol(str(payload.get('symbol') or payload.get('code') or '000001'))
    market_name = str(payload.get('market') or infer_market(code)).upper()
    period_name = str(payload.get('period') or payload.get('freq') or 'DAILY').upper()
    adjust_name = str(payload.get('adjust') or 'QFQ').upper()
    count = max(1, min(int(payload.get('count') or 800), 5000))
    start = payload.get('start') or None
    end = payload.get('end') or None

    market_enum = _market_value(market_name, Market)
    period_enum = _period_value(period_name, Period)
    adjust_enum = _adjust_value(adjust_name, Adjust)

    try:
        try:
            df = _get_stock_kline(
                MacClient,
                market_enum,
                code,
                period=period_enum,
                count=count,
                adjust=adjust_enum,
            )
        except TypeError:
            df = _get_stock_kline(
                MacClient,
                market_enum,
                code,
                period_enum,
                count,
                adjust_enum,
            )
    except Exception as exc:
        return json.dumps({
            'ok': False,
            'error': f'easy-tdx 获取K线失败: {exc}',
            'bars': [],
        }, ensure_ascii=False)

    start_dt = _parse_dt(start) if start else None
    end_dt = _parse_dt(end) if end else None
    bars = []
    for row in _iter_rows(df):
        try:
            dt = _parse_dt(_row_get(row, 'datetime', 'dt', 'date', 'time'))
            if start_dt and dt < start_dt:
                continue
            if end_dt and dt > end_dt:
                continue
            bars.append({
                'id': len(bars),
                'dt': dt.isoformat(sep=' '),
                'open': float(_row_get(row, 'open', 'o')),
                'high': float(_row_get(row, 'high', 'h')),
                'low': float(_row_get(row, 'low', 'l')),
                'close': float(_row_get(row, 'close', 'c')),
                'vol': float(_row_get(row, 'vol', 'volume', default=0) or 0),
                'amount': float(_row_get(row, 'amount', 'money', default=0) or 0),
                'symbol': f'{code}.{market_name}',
            })
        except Exception:
            continue

    return json.dumps({
        'ok': True,
        'source': {
            'name': 'embedded-easy-tdx',
            'symbol': f'{code}.{market_name}',
            'freq': period_name,
            'adjust': adjust_name,
            'count': len(bars),
            'start': start,
            'end': end,
        },
        'bars': bars,
    }, ensure_ascii=False)
