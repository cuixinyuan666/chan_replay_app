from __future__ import annotations

from copy import deepcopy
from datetime import date, datetime, timedelta, time
import re
from typing import Any


class EasyTdxUnavailable(RuntimeError):
    pass


_EASY_TDX_BAR_CACHE: dict[tuple[Any, ...], list[dict[str, Any]]] = {}
_EASY_TDX_CACHE_STATS: dict[str, Any] = {'hits': 0, 'misses': 0, 'hit_levels': [], 'miss_levels': []}


def reset_easy_tdx_cache_stats() -> None:
    _EASY_TDX_CACHE_STATS.update({'hits': 0, 'misses': 0, 'hit_levels': [], 'miss_levels': []})


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


def normalize_symbol(symbol: str) -> str:
    return str(symbol or '').strip().upper().replace('.SZ', '').replace('.SH', '').replace('.BJ', '')


def infer_market(symbol: str) -> str:
    code = normalize_symbol(symbol)
    if code.startswith(('920', '8', '4')):
        return 'BJ'
    return 'SH' if code.startswith(('5', '6', '9')) else 'SZ'


def normalize_market(symbol: str, market: str | None = None) -> str:
    inferred = infer_market(symbol)
    requested = str(market or '').strip().upper().replace('.', '')
    if requested not in {'SH', 'SZ', 'BJ'}:
        return inferred
    return inferred if requested != inferred else requested


def _enum_value(enum_cls: Any, *names: str) -> Any:
    for name in names:
        if hasattr(enum_cls, name):
            return getattr(enum_cls, name)
    raise EasyTdxUnavailable(f'easy-tdx enum missing fields: {names}')


def _period_value(period: str, Period: Any) -> Any:
    mapping = {
        '1M': ('MIN_1', 'MIN1', 'M1'), 'MIN1': ('MIN_1', 'MIN1', 'M1'),
        '5M': ('MIN_5', 'MIN5', 'M5'), 'MIN5': ('MIN_5', 'MIN5', 'M5'),
        '15M': ('MIN_15', 'MIN15', 'M15'), 'MIN15': ('MIN_15', 'MIN15', 'M15'),
        '30M': ('MIN_30', 'MIN30', 'M30'), 'MIN30': ('MIN_30', 'MIN30', 'M30'),
        '60M': ('MIN_60', 'MIN60', 'M60'), 'MIN60': ('MIN_60', 'MIN60', 'M60'),
        'D': ('DAILY', 'DAY', 'D'), 'DAILY': ('DAILY', 'DAY', 'D'),
        'W': ('WEEKLY', 'WEEK', 'W'), 'WEEKLY': ('WEEKLY', 'WEEK', 'W'),
        'M': ('MONTHLY', 'MONTH', 'M'), 'MONTHLY': ('MONTHLY', 'MONTH', 'M'),
    }
    return _enum_value(Period, *mapping.get(str(period).upper(), ('DAILY', 'DAY', 'D')))


def _adjust_value(adjust: str, Adjust: Any) -> Any:
    mapping = {'QFQ': ('QFQ', 'FRONT', 'FORWARD'), 'HFQ': ('HFQ', 'BACK', 'BACKWARD'), 'NONE': ('NONE', 'NO', 'RAW')}
    return _enum_value(Adjust, *mapping.get(str(adjust).upper(), ('QFQ', 'FRONT', 'FORWARD')))


def _market_value(market: str, Market: Any) -> Any:
    text = str(market).upper()
    if text == 'BJ':
        return _enum_value(Market, 'BJ')
    return _enum_value(Market, 'SH') if text == 'SH' else _enum_value(Market, 'SZ')


def _parse_dt(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value
    if isinstance(value, date):
        return datetime(value.year, value.month, value.day)
    text = str(value).strip().replace('/', '-').replace('T', ' ')
    if not text:
        raise ValueError('empty datetime value')
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
    return df.to_dict('records') if hasattr(df, 'to_dict') else (df or [])


def _close_client(client: Any) -> None:
    for name in ('close', 'disconnect'):
        method = getattr(client, name, None)
        if callable(method):
            try:
                method()
            except Exception:
                pass
            return


def _client_call(method_name: str, MacClient: Any, *args: Any, **kwargs: Any) -> Any:
    client = MacClient.from_best_host()
    try:
        if hasattr(client, '__enter__') and hasattr(client, '__exit__'):
            with client as c:
                return getattr(c, method_name)(*args, **kwargs)
        return getattr(client, method_name)(*args, **kwargs)
    finally:
        _close_client(client)


def _get_stock_kline(MacClient: Any, *args: Any, **kwargs: Any) -> Any:
    return _client_call('get_stock_kline', MacClient, *args, **kwargs)


def _get_transactions(MacClient: Any, *args: Any, **kwargs: Any) -> Any:
    return _client_call('get_transactions', MacClient, *args, **kwargs)


def _is_tick_period(period_name: str) -> bool:
    return period_name.upper() in {'TICK', 'TRANSACTION', 'TRANSACTIONS'}


def _is_tick_agg_min1_period(period_name: str) -> bool:
    return period_name.upper().strip().replace('-', '_') in {'TICK_MIN1', 'TICK_1MIN', 'TICK_MIN_1', 'TXN_MIN1', 'TRANSACTION_MIN1', 'TRANSACTIONS_MIN1'}


def _date_arg(value: str | None) -> int | None:
    return None if not value else int(f'{_parse_dt(value).year:04d}{_parse_dt(value).month:02d}{_parse_dt(value).day:02d}')


def _window_bounds(start: str | None, end: str | None) -> tuple[datetime | None, datetime | None]:
    start_dt = _parse_dt(start) if start else None
    end_dt = _parse_dt(end) if end else None
    if end_dt is not None and end and len(str(end).strip().replace('/', '-')) <= 10 and ':' not in str(end):
        end_dt = datetime.combine(end_dt.date(), time.max)
    return start_dt, end_dt


def _transaction_date_hints(start: str | None, end: str | None) -> list[int | None]:
    start_dt, end_dt = _window_bounds(start, end)
    if start_dt is None and end_dt is None:
        return [None]
    anchor_start = (start_dt or end_dt)
    anchor_end = (end_dt or start_dt)
    if anchor_start is None or anchor_end is None:
        return [None]
    if anchor_start > anchor_end:
        anchor_start, anchor_end = anchor_end, anchor_start
    hints: list[int | None] = []
    cur = anchor_start.date()
    while cur <= anchor_end.date():
        if cur.weekday() < 5:
            hints.append(int(f'{cur.year:04d}{cur.month:02d}{cur.day:02d}'))
        cur += timedelta(days=1)
    return hints or [_date_arg(end) or _date_arg(start)]


def _filter_bars_by_datetime(bars: list[dict[str, Any]], *, start: str | None, end: str | None) -> list[dict[str, Any]]:
    start_dt, end_dt = _window_bounds(start, end)
    if start_dt is None and end_dt is None:
        return bars
    filtered: list[dict[str, Any]] = []
    for row in bars:
        dt = _parse_dt(row.get('dt') or row.get('time') or row.get('datetime') or row.get('date'))
        if start_dt is not None and dt < start_dt:
            continue
        if end_dt is not None and dt > end_dt:
            continue
        filtered.append(row)
    for raw_index, row in enumerate(filtered):
        row['id'] = raw_index
        row['raw_index'] = raw_index
    return filtered


def _parse_transaction_dt(row: Any, date_hint: int | None) -> datetime:
    value = _row_get(row, 'datetime', 'dt', 'date', 'time', default=None)
    if isinstance(value, datetime):
        return value
    text = str(value or '').strip().replace('/', '-').replace('T', ' ')
    if text:
        if re.match(r'^\d{1,2}:\d{2}(:\d{2})?$', text):
            day = datetime.strptime(str(date_hint), '%Y%m%d') if date_hint is not None else datetime.today()
            parts = [int(x) for x in text.split(':')]
            return datetime(day.year, day.month, day.day, parts[0], parts[1], parts[2] if len(parts) > 2 else 0)
        return _parse_dt(text)
    return datetime.strptime(str(date_hint), '%Y%m%d') if date_hint is not None else datetime.today()


def _transaction_side(row: Any) -> str:
    text = str(_row_get(row, 'bs', 'side', 'direction', 'flag', 'type', 'buy_sell', 'kind', default='')).strip().lower()
    if text in {'s', 'sell', 'sold', 'out', '2', '-1'}:
        return 'sell'
    if text in {'b', 'buy', 'bought', 'in', '1'}:
        return 'buy'
    return 'unknown'


def _transaction_price(row: Any) -> float | None:
    return _optional_float(_row_get(row, 'price', 'p', 'close', 'last', default=None))


def _transaction_volume(row: Any) -> float:
    return _optional_float(_row_get(row, 'vol', 'volume', 'v', 'qty', 'quantity', default=0)) or 0.0


def _transaction_amount(row: Any) -> float | None:
    return _optional_float(_row_get(row, 'amount', 'money', 'turnover', default=None))


def _normalize_transaction_bars(rows: Any, *, code: str, market_name: str, period_name: str, adjust_name: str, date_hint: int | None) -> list[dict[str, Any]]:
    bars: list[dict[str, Any]] = []
    for row in _iter_rows(rows):
        price = _transaction_price(row)
        if price is None or price <= 0:
            continue
        dt = _parse_transaction_dt(row, date_hint)
        volume = _transaction_volume(row)
        amount = _transaction_amount(row)
        side = _transaction_side(row)
        raw_index = len(bars)
        bars.append({
            'id': raw_index, 'raw_index': raw_index, 'dt': dt.isoformat(sep=' '), 'time': dt.isoformat(sep=' '),
            'open': price, 'high': price, 'low': price, 'close': price, 'vol': volume, 'volume': volume,
            'amount': amount, 'turnover': None, 'transaction_side': side, 'symbol': f'{code}.{market_name}',
            'market': market_name, 'code': code, 'period': period_name, 'adjust': adjust_name,
            'chip_tick_bins': {'p': [price], 's': [volume if side == 'sell' else 0.0], 'b': [volume if side != 'sell' else 0.0], 'w': [volume], 'source': 'backend_tick_transaction'},
        })
    # TICK transactions must be chronological before aggregation and export.
    bars.sort(key=lambda row: str(row.get('dt') or row.get('time') or ''))
    for raw_index, row in enumerate(bars):
        row['id'] = raw_index
        row['raw_index'] = raw_index
    return bars


def _aggregate_transaction_bars_to_min1(transaction_bars: list[dict[str, Any]], *, code: str, market_name: str, period_name: str, adjust_name: str) -> list[dict[str, Any]]:
    buckets: dict[datetime, list[dict[str, Any]]] = {}
    for row in transaction_bars:
        if isinstance(row, dict):
            minute = _parse_dt(row.get('dt') or row.get('time')).replace(second=0, microsecond=0)
            buckets.setdefault(minute, []).append(row)
    bars: list[dict[str, Any]] = []
    for minute in sorted(buckets):
        rows = buckets[minute]
        prices = [float(row.get('close') or row.get('price') or row.get('open') or 0) for row in rows]
        prices = [price for price in prices if price > 0]
        if not prices:
            continue
        amount_values = [float(row.get('amount')) for row in rows if row.get('amount') is not None]
        sell_by_price: dict[float, float] = {}
        buy_by_price: dict[float, float] = {}
        total_by_price: dict[float, float] = {}
        for row in rows:
            bins = row.get('chip_tick_bins') if isinstance(row.get('chip_tick_bins'), dict) else {}
            for i, raw_price in enumerate(bins.get('p') or bins.get('prices') or []):
                price = _optional_float(raw_price)
                if price is None or price <= 0:
                    continue
                sells, buys, totals = bins.get('s') or [], bins.get('b') or [], bins.get('w') or []
                sell = _optional_float(sells[i] if i < len(sells) else None) or 0.0
                buy = _optional_float(buys[i] if i < len(buys) else None) or 0.0
                total = _optional_float(totals[i] if i < len(totals) else None)
                if total is None:
                    total = sell + buy
                sell_by_price[price] = sell_by_price.get(price, 0.0) + sell
                buy_by_price[price] = buy_by_price.get(price, 0.0) + buy
                total_by_price[price] = total_by_price.get(price, 0.0) + total
        bin_prices = sorted(total_by_price)
        raw_index = len(bars)
        bars.append({
            'id': raw_index, 'raw_index': raw_index, 'dt': minute.isoformat(sep=' '), 'time': minute.isoformat(sep=' '),
            'open': prices[0], 'high': max(prices), 'low': min(prices), 'close': prices[-1],
            'vol': sum(float(row.get('volume') or row.get('vol') or 0) for row in rows),
            'volume': sum(float(row.get('volume') or row.get('vol') or 0) for row in rows),
            'amount': sum(amount_values) if amount_values else None, 'turnover': None,
            'symbol': f'{code}.{market_name}', 'market': market_name, 'code': code, 'period': period_name, 'adjust': adjust_name,
            'tick_agg_source': 'backend_tick_transaction', 'tick_agg_period': 'MIN1', 'tick_agg_transaction_count': len(rows),
            'chip_tick_bins': {'p': bin_prices, 's': [sell_by_price.get(p, 0.0) for p in bin_prices], 'b': [buy_by_price.get(p, 0.0) for p in bin_prices], 'w': [total_by_price.get(p, 0.0) for p in bin_prices], 'source': 'backend_tick_agg_min1', 'source_period': 'TICK', 'agg_period': 'MIN1', 'transaction_count': len(rows)},
        })
    return bars


def _cache_key(*, code: str, market_name: str, period_name: str, adjust_name: str, count: int, start: str | None, end: str | None) -> tuple[Any, ...]:
    return (code, market_name, period_name, adjust_name, int(count), str(start or ''), str(end or ''))


def _record_cache_hit(period_name: str) -> None:
    _EASY_TDX_CACHE_STATS['hits'] = int(_EASY_TDX_CACHE_STATS.get('hits') or 0) + 1
    _EASY_TDX_CACHE_STATS.setdefault('hit_levels', []).append(period_name)


def _record_cache_miss(period_name: str) -> None:
    _EASY_TDX_CACHE_STATS['misses'] = int(_EASY_TDX_CACHE_STATS.get('misses') or 0) + 1
    _EASY_TDX_CACHE_STATS.setdefault('miss_levels', []).append(period_name)


def _copy_bars(bars: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return deepcopy(bars)


def _fetch_transactions(MacClient: Any, market_enum: Any, code: str, safe_count: int, date_hint: int | None) -> Any:
    try:
        if date_hint is None:
            return _get_transactions(MacClient, market_enum, code, count=safe_count)
        return _get_transactions(MacClient, market_enum, code, count=safe_count, date=date_hint)
    except TypeError:
        if date_hint is None:
            return _get_transactions(MacClient, market_enum, code, safe_count)
        return _get_transactions(MacClient, market_enum, code, safe_count, date_hint)


def load_easy_tdx_bars(*, symbol: str, market: str | None = None, period: str = 'DAILY', adjust: str = 'QFQ', count: int = 800, start: str | None = None, end: str | None = None) -> list[dict[str, Any]]:
    code = normalize_symbol(symbol)
    market_name = normalize_market(code, market)
    period_name = period.upper()
    adjust_name = adjust.upper()
    safe_count = max(1, int(count))
    key = _cache_key(code=code, market_name=market_name, period_name=period_name, adjust_name=adjust_name, count=safe_count, start=start, end=end)
    cached = _EASY_TDX_BAR_CACHE.get(key)
    if cached is not None:
        _record_cache_hit(period_name)
        return _copy_bars(cached)
    _record_cache_miss(period_name)

    try:
        from easy_tdx import Adjust, MacClient, Market, Period
    except Exception as exc:
        raise EasyTdxUnavailable('easy_tdx unavailable in current Python environment') from exc

    market_enum = _market_value(market_name, Market)
    if _is_tick_agg_min1_period(period_name) or _is_tick_period(period_name):
        transaction_bars: list[dict[str, Any]] = []
        for date_hint in _transaction_date_hints(start, end):
            rows = _fetch_transactions(MacClient, market_enum, code, safe_count, date_hint)
            transaction_bars.extend(_normalize_transaction_bars(rows, code=code, market_name=market_name, period_name='TICK' if _is_tick_agg_min1_period(period_name) else period_name, adjust_name=adjust_name, date_hint=date_hint))
        transaction_bars = _filter_bars_by_datetime(transaction_bars, start=start, end=end)
        bars = _aggregate_transaction_bars_to_min1(transaction_bars, code=code, market_name=market_name, period_name=period_name, adjust_name=adjust_name) if _is_tick_agg_min1_period(period_name) else transaction_bars
        _EASY_TDX_BAR_CACHE[key] = _copy_bars(bars)
        return bars

    period_enum = _period_value(period_name, Period)
    adjust_enum = _adjust_value(adjust_name, Adjust)
    try:
        df = _get_stock_kline(MacClient, market_enum, code, period=period_enum, count=safe_count, adjust=adjust_enum)
    except TypeError:
        df = _get_stock_kline(MacClient, market_enum, code, period_enum, safe_count, adjust_enum)

    start_dt, end_dt = _window_bounds(start, end)
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
        raw_index = len(bars)
        bars.append({'id': raw_index, 'raw_index': raw_index, 'dt': dt.isoformat(sep=' '), 'time': dt.isoformat(sep=' '), 'open': open_, 'high': max(open_, high, low, close), 'low': min(open_, high, low, close), 'close': close, 'vol': volume, 'volume': volume, 'amount': _optional_float(_row_get(row, 'amount', 'money', default=None)), 'turnover': _optional_float(_row_get(row, 'turnover', 'turnover_rate', 'turnrate', default=None)), 'symbol': f'{code}.{market_name}', 'market': market_name, 'code': code, 'period': period_name, 'adjust': adjust_name})
    _EASY_TDX_BAR_CACHE[key] = _copy_bars(bars)
    return bars
