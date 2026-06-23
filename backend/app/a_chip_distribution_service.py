from __future__ import annotations

import hashlib
import json
import math
from collections import OrderedDict
from datetime import date, datetime
from typing import Any, Callable

_CACHE: "OrderedDict[str, dict[str, Any]]" = OrderedDict()
_CHECKPOINTS: dict[str, list[tuple[int, list[float], list[float]]]] = {}

_LEVEL_ALIASES = {
    '1M': 'MIN1', 'M1': 'MIN1', 'MIN_1': 'MIN1',
    '5M': 'MIN5', 'M5': 'MIN5', 'MIN_5': 'MIN5',
    '15M': 'MIN15', 'M15': 'MIN15', 'MIN_15': 'MIN15',
    '30M': 'MIN30', 'M30': 'MIN30', 'MIN_30': 'MIN30',
    '60M': 'MIN60', 'M60': 'MIN60', 'MIN_60': 'MIN60',
    'D': 'DAILY', 'DAY': 'DAILY',
    'TICK': 'TICK_MIN1', 'TRANSACTION': 'TICK_MIN1', 'TRANSACTIONS': 'TICK_MIN1',
    'TICK_1MIN': 'TICK_MIN1', 'TICK_MIN_1': 'TICK_MIN1', 'TXN_MIN1': 'TICK_MIN1',
    'TRANSACTION_MIN1': 'TICK_MIN1', 'TRANSACTIONS_MIN1': 'TICK_MIN1',
}
_SUPPORTED_LEVELS = {'TICK_MIN1', 'DAILY', 'MIN60', 'MIN30', 'MIN15', 'MIN5', 'MIN1'}


def _f(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _level(value: Any) -> str:
    text = str(value or 'DAILY').upper().strip().replace('-', '_')
    normalized = _LEVEL_ALIASES.get(text, text)
    return normalized if normalized in _SUPPORTED_LEVELS else 'DAILY'


def _is_tick(level: str) -> bool:
    return level == 'TICK_MIN1'


def _time(row: dict[str, Any]) -> str:
    return str(row.get('time') or row.get('dt') or row.get('datetime') or row.get('date') or '')


def _parse_time(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    if isinstance(value, date):
        return datetime(value.year, value.month, value.day)
    text = str(value).strip().replace('/', '-').replace('T', ' ')
    if not text:
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


def _cmp(a: Any, b: Any) -> int:
    da, db = _parse_time(a), _parse_time(b)
    if da is not None and db is not None:
        return (da > db) - (da < db)
    sa, sb = str(a or ''), str(b or '')
    return (sa > sb) - (sa < sb)


def _index(row: dict[str, Any], fallback: int) -> int:
    try:
        return int(row.get('raw_index', row.get('rawIndex', row.get('index', fallback))))
    except (TypeError, ValueError):
        return fallback


def _checkpoint_interval(level: str, requested: int | None) -> int:
    if requested and requested > 0:
        return requested
    if level == 'DAILY':
        return 1
    if level == 'MIN1':
        return 60
    if level == 'MIN5':
        return 48
    if level == 'TICK_MIN1':
        return 2000
    return 48


def _cache_key(payload: dict[str, Any], settings_version: str) -> str:
    fields = [
        payload.get('symbol'), payload.get('market'), _level(payload.get('level') or payload.get('period')),
        payload.get('adjust_type', payload.get('adjust', 'QFQ')), payload.get('mode', 'once'),
        payload.get('listing_date'), payload.get('replay_start') or payload.get('start'),
        payload.get('replay_end') or payload.get('end'), payload.get('target_time'),
        payload.get('bucket_count', 80), payload.get('bucket_size') or payload.get('price_bucket_size'),
        payload.get('distribution_model', 'ohlcv_triangular_v1'),
        payload.get('decay_model', 'none'), payload.get('baseline_policy', 'listing_to_replay_start'),
        payload.get('checkpoint_policy', 'same_level_periodic'), settings_version,
    ]
    return 'chip:' + hashlib.sha256('|'.join(str(v or '') for v in fields).encode('utf-8')).hexdigest()


def _sorted_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(rows, key=lambda row: (_parse_time(_time(row)) or datetime.min, _index(row, 0)))


def _target_rows(rows: list[dict[str, Any]], target_time: str | None) -> list[dict[str, Any]]:
    if not target_time:
        return rows
    return [row for row in rows if not _time(row) or _cmp(_time(row), target_time) <= 0]


def _price_range(rows: list[dict[str, Any]], tick_mode: bool) -> tuple[float, float]:
    prices: list[float] = []
    for row in rows:
        bins = row.get('chip_tick_bins') or row.get('chipTickBins')
        if tick_mode and isinstance(bins, dict):
            prices.extend(_f(v) for v in bins.get('p', []) if _f(v) > 0)
        else:
            low, high, close = _f(row.get('low', row.get('l'))), _f(row.get('high', row.get('h'))), _f(row.get('close', row.get('c')))
            if low > 0 and high >= low:
                prices.extend((low, high))
            elif close > 0:
                prices.append(close)
    if not prices:
        return 0.0, 0.0
    lo, hi = min(prices), max(prices)
    if abs(hi - lo) < 1e-9:
        lo, hi = lo * 0.999, hi * 1.001
    return lo, hi


def _bucket(price: float, lo: float, step: float, count: int) -> int:
    return max(0, min(count - 1, int((price - lo) / max(step, 1e-12))))


def _bucket_plan(payload: dict[str, Any], rows: list[dict[str, Any]], tick_mode: bool) -> tuple[int, float, float, float, str, bool]:
    requested_count = max(8, min(int(payload.get('bucket_count') or 80), 240))
    lo, hi = _price_range(rows, tick_mode)
    fixed_size = _f(payload.get('bucket_size') or payload.get('price_bucket_size') or payload.get('bucket_step'), 0.0)
    if fixed_size > 0:
        low = math.floor(lo / fixed_size) * fixed_size if lo > 0 else 0.0
        high = math.ceil(hi / fixed_size) * fixed_size if hi > low else low + fixed_size
        count = max(1, int(math.ceil((high - low) / fixed_size)))
        max_count = max(requested_count, min(int(payload.get('max_bucket_count') or 4096), 20000))
        if count > max_count:
            step = (high - low) / max_count if high > low else fixed_size
            return max_count, low, low + max_count * step, step, 'fixed_price_step_v1', True
        return count, low, low + count * fixed_size, fixed_size, 'fixed_price_step_v1', False
    step = (hi - lo) / requested_count if hi > lo else 1.0
    return requested_count, lo, hi, step, 'session_range_even_count_v1', False


def _fold_row(row: dict[str, Any], sell: list[float], buy: list[float], lo: float, step: float, tick_mode: bool, errors: list[str]) -> bool:
    count = len(sell)
    bins = row.get('chip_tick_bins') or row.get('chipTickBins')
    if tick_mode:
        if not isinstance(bins, dict):
            errors.append('tick_bins_missing')
            return False
        prices, s_values, b_values, totals = bins.get('p', []), bins.get('s', []), bins.get('b', []), bins.get('w', [])
        used = False
        for i, raw_price in enumerate(prices):
            price = _f(raw_price)
            if price <= 0:
                continue
            total = _f(totals[i]) if i < len(totals) else 0.0
            s = _f(s_values[i]) if i < len(s_values) else 0.0
            b = _f(b_values[i]) if i < len(b_values) else max(total - s, 0.0)
            if total > 0 and s <= 0 and b <= 0:
                b = total
            idx = _bucket(price, lo, step, count)
            sell[idx] += max(0.0, s)
            buy[idx] += max(0.0, b)
            used = used or total > 0 or s > 0 or b > 0
        return used
    volume = _f(row.get('volume', row.get('vol', row.get('v'))))
    if volume <= 0:
        return False
    low, high, close = _f(row.get('low', row.get('l'))), _f(row.get('high', row.get('h'))), _f(row.get('close', row.get('c')))
    if high < low:
        errors.append('high_below_low')
        return False
    if abs(high - low) < 1e-12:
        buy[_bucket(close, lo, step, count)] += volume
        return True
    typical = (high + low + close) / 3.0
    first, last = _bucket(low, lo, step, count), _bucket(high, lo, step, count)
    weights = [(idx, max(0.001, 1.0 - abs((lo + (idx + 0.5) * step) - typical) / max(high - low, step))) for idx in range(first, last + 1)]
    total = sum(weight for _, weight in weights) or 1.0
    for idx, weight in weights:
        share = volume * weight / total
        if close >= (high + low) / 2.0:
            buy[idx] += share
        else:
            sell[idx] += share
    return True


def _unavailable(symbol: str, market: str, level: str, mode: str, reason: str, replay_start: Any, replay_end: Any, target_time: Any, settings_version: str, errors: list[str] | None = None) -> dict[str, Any]:
    return {
        'ok': False,
        'status': 'unavailable',
        'reason': reason,
        'fallback_used': False,
        'chip_distribution_state': {'target_index': -1, 'current_price': 0.0, 'total_weight': 0.0, 'sell_weight': 0.0, 'buy_weight': 0.0, 'average_cost': 0.0, 'poc_price': 0.0, 'profit_ratio': 0.0, 'bins': []},
        'chip_distribution_meta': {
            'symbol': symbol, 'market': market, 'level': level, 'mode': mode, 'status': 'unavailable', 'reason': reason,
            'listing_date': None, 'replay_start': replay_start, 'replay_end': replay_end, 'target_time': target_time,
            'volume_source_level': 'TICK_MIN1' if _is_tick(level) else level,
            'volume_source_kind': 'tick_transactions' if _is_tick(level) else 'same_level_bars',
            'fallback_used': False, 'future_guard_passed': True, 'settings_version': settings_version,
            'error_count': len(errors or []), 'errors': list(errors or [])[:10],
        },
    }


def _load_rows(payload: dict[str, Any], level: str, symbol: str, market: str, adjust: str, replay_end: Any, target_time: Any, load_bars: Callable[..., list[dict[str, Any]]] | None) -> tuple[list[dict[str, Any]], str, bool, list[str]]:
    payload_bars = payload.get('bars')
    payload_rows = [dict(row) for row in payload_bars if isinstance(row, dict)] if isinstance(payload_bars, list) else []
    errors: list[str] = []
    if load_bars is not None and symbol:
        try:
            loaded = load_bars(
                symbol=symbol,
                market=market,
                period=level,
                adjust=adjust,
                count=int(payload.get('history_count') or 500000),
                start=str(payload.get('listing_date') or payload.get('listed_at') or payload.get('ipo_date') or '') or None,
                end=str(replay_end or target_time or '') or None,
            )
            if isinstance(loaded, list) and loaded:
                return [dict(row) for row in loaded if isinstance(row, dict)], 'provider_listing_to_replay_end', False, errors
            errors.append('provider_empty')
        except Exception as exc:  # pragma: no cover - live provider dependent
            errors.append(f'provider_error:{type(exc).__name__}')
        if _is_tick(level):
            return [], 'provider_tick_unavailable_no_fallback', False, errors
        if payload_rows:
            return payload_rows, 'payload_bars_fallback_after_provider_empty', True, errors
        return [], 'provider_empty', False, errors
    return payload_rows, 'payload_bars', False, errors


def calculate_chip_distribution(payload: dict[str, Any], *, load_bars: Callable[..., list[dict[str, Any]]] | None = None) -> dict[str, Any]:
    level = _level(payload.get('level') or payload.get('period') or 'DAILY')
    symbol, market = str(payload.get('symbol') or ''), str(payload.get('market') or '')
    adjust = str(payload.get('adjust_type') or payload.get('adjust') or 'QFQ').upper()
    mode = str(payload.get('mode') or 'once').lower()
    replay_start, replay_end = payload.get('replay_start') or payload.get('start'), payload.get('replay_end') or payload.get('end')
    requested_target_time = payload.get('target_time') or payload.get('step_time') or payload.get('step_frame_time')
    settings_version = str(payload.get('settings_version') or '1')
    cache_key = _cache_key({**payload, 'level': level}, settings_version)
    cached = _CACHE.get(cache_key)
    if cached is not None:
        _CACHE.move_to_end(cache_key)
        result = json.loads(json.dumps(cached))
        result['chip_distribution_meta']['cache_hit'] = True
        return result

    all_rows, history_source, fallback_used, errors = _load_rows(payload, level, symbol, market, adjust, replay_end, requested_target_time, load_bars)
    all_rows = _sorted_rows([dict(row) for row in all_rows if isinstance(row, dict)])
    tick_mode = _is_tick(level)
    if tick_mode:
        has_tick_bins = any(isinstance(row.get('chip_tick_bins') or row.get('chipTickBins'), dict) for row in all_rows)
        if not all_rows:
            return _unavailable(symbol, market, level, mode, 'no_tick_trade_data', replay_start, replay_end, requested_target_time, settings_version, errors)
        if not has_tick_bins:
            return _unavailable(symbol, market, level, mode, 'tick_bins_missing_no_min1_fallback', replay_start, replay_end, requested_target_time, settings_version, errors + ['tick_bins_missing'])

    max_allowed_time = payload.get('max_allowed_time')
    future_blocked = bool(mode == 'step' and max_allowed_time and requested_target_time and _cmp(requested_target_time, max_allowed_time) > 0)
    effective_target_time = str(max_allowed_time) if future_blocked else (str(requested_target_time) if requested_target_time else None)
    rows = _target_rows(all_rows, effective_target_time)
    bucket_count, lo, hi, step, bucket_policy, bucket_clamped = _bucket_plan(payload, all_rows or rows, tick_mode)
    sell, buy = [0.0] * bucket_count, [0.0] * bucket_count
    used = 0
    checkpoints: list[tuple[int, list[float], list[float]]] = []
    checkpoint_every = _checkpoint_interval(level, payload.get('checkpoint_interval'))
    for i, row in enumerate(rows):
        if _fold_row(row, sell, buy, lo, step, tick_mode, errors):
            used += 1
        if (i + 1) % checkpoint_every == 0:
            checkpoints.append((i, list(sell), list(buy)))
    _CHECKPOINTS[f'{symbol}|{market}|{level}|{adjust}|{bucket_count}|{settings_version}'] = checkpoints
    if tick_mode and used == 0:
        return _unavailable(symbol, market, level, mode, 'no_tick_trade_volume', replay_start, replay_end, requested_target_time, settings_version, errors)

    total = sum(sell) + sum(buy)
    current = _f(rows[-1].get('close', rows[-1].get('c'))) if rows else 0.0
    bins = []
    weighted = profit = 0.0
    max_weight, poc = -1.0, current
    for i in range(bucket_count):
        price_low = lo + i * step
        price_high = price_low + step
        price = price_low + 0.5 * step
        weight = sell[i] + buy[i]
        weighted += price * weight
        if price <= current:
            profit += weight
        if weight > max_weight:
            max_weight, poc = weight, price
        bins.append({'price': price, 'price_low': price_low, 'price_high': price_high, 'cost': price, 'sell_weight': sell[i], 'buy_weight': buy[i], 'weight': weight, 'volume': weight, 'ratio': weight / total if total else 0.0})

    baseline_rows = [row for row in rows if replay_start and _time(row) and _cmp(_time(row), replay_start) < 0]
    runtime_rows = [row for row in rows if not replay_start or not _time(row) or _cmp(_time(row), replay_start) >= 0]
    target_index = len(rows) - 1
    listing_date = str(payload.get('listing_date') or (_time(all_rows[0]) if all_rows else '')) or None
    meta = {
        'symbol': symbol, 'market': market, 'level': level, 'mode': mode, 'status': 'ok',
        'listing_date': listing_date, 'replay_start': replay_start, 'replay_end': replay_end,
        'user_start': replay_start, 'user_end': replay_end, 'chip_calc_start': _time(all_rows[0]) if all_rows else None,
        'chip_calc_end': _time(rows[-1]) if rows else effective_target_time, 'visible_start': replay_start, 'visible_end': replay_end,
        'target_source': payload.get('target_source', 'target_time' if requested_target_time else 'last_bar'),
        'target_index': target_index, 'target_raw_index': _index(rows[-1], target_index) if rows else None,
        'target_time': _time(rows[-1]) if rows else effective_target_time, 'requested_target_time': requested_target_time,
        'effective_target_time': effective_target_time, 'crosshair_active': bool(payload.get('crosshair_active')),
        'crosshair_index': payload.get('crosshair_index'), 'view_end_index': payload.get('view_end_index'),
        'adjust_type': adjust, 'volume_granularity': level, 'volume_source_level': 'TICK_MIN1' if tick_mode else level,
        'volume_source_kind': 'tick_transactions' if tick_mode else 'same_level_bars', 'bars_period_required': level,
        'tick_min1_uses_transaction_volume': tick_mode, 'fallback_used': fallback_used, 'history_source': history_source,
        'baseline_policy': 'listing_to_replay_start_exclusive', 'baseline_start': _time(all_rows[0]) if all_rows else None,
        'baseline_end': replay_start, 'baseline_level': level, 'baseline_bar_count': len(baseline_rows),
        'baseline_incomplete': not bool(all_rows) or (bool(replay_start) and history_source.startswith('payload')),
        'checkpoint_used': bool(checkpoints), 'checkpoint_time': _time(rows[checkpoints[-1][0]]) if checkpoints else None,
        'checkpoint_index': checkpoints[-1][0] if checkpoints else None, 'checkpoint_level': level,
        'checkpoint_source': 'backend_memory_same_level', 'increment_start': replay_start,
        'increment_end': effective_target_time or replay_end, 'increment_level': level, 'increment_bar_count': len(runtime_rows),
        'bucket_count': bucket_count, 'bucket_policy': bucket_policy, 'bucket_low': lo, 'bucket_high': hi,
        'bucket_step': step, 'bucket_clamped': bucket_clamped, 'bucket_range_source': 'listing_to_replay_end_full_history',
        'bucket_rule_stable_in_session': True, 'distribution_model': 'tick_exact_price_v1' if tick_mode else 'ohlcv_triangular_v1',
        'tick_mode': tick_mode, 'tick_bins_used': tick_mode and used > 0,
        'tick_incomplete': tick_mode and 'tick_bins_missing' in errors, 'settings_version': settings_version,
        'cache_key': cache_key, 'cache_hit': False, 'used_bar_count': used, 'all_history_bar_count': len(all_rows),
        'target_bar_count': len(rows), 'future_guard_passed': not future_blocked, 'future_guard_blocked': future_blocked,
        'error_count': len(errors), 'errors': errors[:10], 'step_frame_index': payload.get('step_frame_index'),
        'step_frame_time': payload.get('step_frame_time'), 'max_allowed_time': max_allowed_time,
    }
    result = {
        'ok': True,
        'chip_distribution_state': {
            'target_index': target_index, 'current_price': current, 'total_weight': total,
            'sell_weight': sum(sell), 'buy_weight': sum(buy), 'average_cost': weighted / total if total else 0.0,
            'poc_price': poc, 'profit_ratio': profit / total if total else 0.0, 'bins': bins,
        },
        'chip_distribution_meta': meta,
    }
    _CACHE[cache_key] = result
    max_cache = max(8, min(int(payload.get('cache_size') or 128), 2048))
    while len(_CACHE) > max_cache:
        _CACHE.popitem(last=False)
    return result
