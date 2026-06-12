from __future__ import annotations

from copy import deepcopy
from datetime import date, datetime
from typing import Any


class EasyTdxUnavailable(RuntimeError):
    pass


_EASY_TDX_BAR_CACHE: dict[tuple[Any, ...], list[dict[str, Any]]] = {}
_EASY_TDX_CACHE_STATS: dict[str, Any] = {
    'hits': 0,
    'misses': 0,
    'hit_levels': [],
    'miss_levels': [],
}


def reset_easy_tdx_cache_stats() -> None:
    _EASY_TDX_CACHE_STATS['hits'] = 0
    _EASY_TDX_CACHE_STATS['misses'] = 0
    _EASY_TDX_CACHE_STATS['hit_levels'] = []
    _EASY_TDX_CACHE_STATS['miss_levels'] = []


def get_easy_tdx_cache_stats() -> dict[str, Any]:
    return {
        'enabled': True,
        'hits': int(_EASY_TDX_CACHE_STATS.get('hits') or 0),
        'misses': int(_EASY_TDX_CACHE_STATS.get('misses') or 0),
        'hit_levels': list(_EASY_TDX_CACHE_STATS.get('hit_levels') or []),
        'miss_levels': list(_EASY_TDX_CACHE_STATS.get('miss_levels') or []),
        'key_count': len(_EASY_TDX_BAR_CACHE),
        'policy': 'process-local raw K-line cache; key=symbol,market,period,adjust,count,start,end; no Chan result cache',
    }


def clear_easy_tdx_bar_cache() -> None:
    _EASY_TDX_BAR_CACHE.clear()
    reset_easy_tdx_cache_stats()


def infer_market(symbol: str) -> str:
    code = symbol.strip().upper().replace('.SZ', '').replace('.SH', '')
    if code.startswith(('5', '6', '9')):
        return 'SH'
    return 'SZ'


def normalize_symbol(symbol: str) -> str:
    return symbol.strip().upper().replace('.SZ', '').replace('.SH', '')


def _enum_value(enum_cls: Any, *names: str) -> Any:
    for name in names:
        if hasattr(enum_cls, name):
            return getattr(enum_cls, name)
    raise EasyTdxUnavailable(f'easy-tdx 枚举缺少字段: {names}')


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
    m = market.upper()
    return _enum_value(Market, 'SH') if m == 'SH' else _enum_value(Market, 'SZ')


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


def _optional_float(value: Any) -> float | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text or text.lower() in {'none', 'null', 'nan', '--', '-'}:
        return None
    try:
        return float(text)
    except (TypeError, ValueError):
        return None


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


def _cache_key(
    *,
    code: str,
    market_name: str,
    period_name: str,
    adjust_name: str,
    count: int,
    start: str | None,
    end: str | None,
) -> tuple[Any, ...]:
    return (
        code,
        market_name,
        period_name,
        adjust_name,
        int(count),
        str(start or ''),
        str(end or ''),
    )


def _record_cache_hit(period_name: str) -> None:
    _EASY_TDX_CACHE_STATS['hits'] = int(_EASY_TDX_CACHE_STATS.get('hits') or 0) + 1
    _EASY_TDX_CACHE_STATS.setdefault('hit_levels', []).append(period_name)


def _record_cache_miss(period_name: str) -> None:
    _EASY_TDX_CACHE_STATS['misses'] = int(_EASY_TDX_CACHE_STATS.get('misses') or 0) + 1
    _EASY_TDX_CACHE_STATS.setdefault('miss_levels', []).append(period_name)


def _copy_bars(bars: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return deepcopy(bars)


def load_easy_tdx_bars(
    *,
    symbol: str,
    market: str | None = None,
    period: str = 'DAILY',
    adjust: str = 'QFQ',
    count: int = 800,
    start: str | None = None,
    end: str | None = None,
) -> list[dict[str, Any]]:
    code = normalize_symbol(symbol)
    market_name = (market or infer_market(code)).upper()
    period_name = period.upper()
    adjust_name = adjust.upper()
    safe_count = max(1, int(count))
    key = _cache_key(
        code=code,
        market_name=market_name,
        period_name=period_name,
        adjust_name=adjust_name,
        count=safe_count,
        start=start,
        end=end,
    )
    cached = _EASY_TDX_BAR_CACHE.get(key)
    if cached is not None:
        _record_cache_hit(period_name)
        return _copy_bars(cached)
    _record_cache_miss(period_name)

    try:
        from easy_tdx import Adjust, MacClient, Market, Period
    except Exception as exc:  # pragma: no cover - environment dependent
        raise EasyTdxUnavailable(
            '未安装 easy-tdx，或当前 Python 环境无法导入 easy_tdx / easy-tdx'
        ) from exc

    market_enum = _market_value(market_name, Market)
    period_enum = _period_value(period_name, Period)
    adjust_enum = _adjust_value(adjust_name, Adjust)

    try:
        df = _get_stock_kline(
            MacClient,
            market_enum,
            code,
            period=period_enum,
            count=safe_count,
            adjust=adjust_enum,
        )
    except TypeError:
        df = _get_stock_kline(
            MacClient,
            market_enum,
            code,
            period_enum,
            safe_count,
            adjust_enum,
        )

    start_dt = _parse_dt(start) if start else None
    end_dt = _parse_dt(end) if end else None
    bars: list[dict[str, Any]] = []
    for row in _iter_rows(df):
        dt = _parse_dt(_row_get(row, 'datetime', 'dt', 'date', 'time'))
        if start_dt and dt < start_dt:
            continue
        if end_dt and dt > end_dt:
            continue
        open_ = float(_row_get(row, 'open', 'o'))
        high = float(_row_get(row, 'high', 'h'))
        low = float(_row_get(row, 'low', 'l'))
        close = float(_row_get(row, 'close', 'c'))
        volume = _optional_float(_row_get(row, 'vol', 'volume', default=0)) or 0.0
        amount = _optional_float(_row_get(row, 'amount', 'money', default=None))
        turnover = _optional_float(_row_get(row, 'turnover', 'turnover_rate', 'turnrate', default=None))
        raw_index = len(bars)
        bars.append(
            {
                'id': raw_index,
                'raw_index': raw_index,
                'dt': dt.isoformat(sep=' '),
                'time': dt.isoformat(sep=' '),
                'open': open_,
                'high': max(open_, high, low, close),
                'low': min(open_, high, low, close),
                'close': close,
                'vol': volume,
                'volume': volume,
                'amount': amount,
                'turnover': turnover,
                'symbol': f'{code}.{market_name}',
                'market': market_name,
                'code': code,
                'period': period_name,
                'adjust': adjust_name,
            }
        )
    _EASY_TDX_BAR_CACHE[key] = _copy_bars(bars)
    return bars
