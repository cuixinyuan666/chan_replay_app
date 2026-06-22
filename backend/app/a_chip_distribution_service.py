from __future__ import annotations

import hashlib
import json
from collections import OrderedDict
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Callable


_CACHE: "OrderedDict[str, dict[str, Any]]" = OrderedDict()
_CHECKPOINTS: dict[str, list[tuple[int, list[float], list[float]]]] = {}


def _f(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _time(row: dict[str, Any]) -> str:
    return str(row.get('time') or row.get('dt') or row.get('datetime') or row.get('date') or '')


def _index(row: dict[str, Any], fallback: int) -> int:
    try:
        return int(row.get('raw_index', row.get('rawIndex', row.get('index', fallback))))
    except (TypeError, ValueError):
        return fallback


def _checkpoint_interval(level: str, requested: int | None) -> int:
    if requested and requested > 0:
        return requested
    key = level.upper()
    if key == 'DAILY':
        return 1
    if key == 'MIN1':
        return 60
    if key == 'MIN5':
        return 48
    if key == 'TICK':
        return 2000
    return 48


def _cache_key(payload: dict[str, Any], settings_version: str) -> str:
    fields = [
        payload.get('symbol'), payload.get('market'), payload.get('level'),
        payload.get('adjust_type', 'QFQ'), payload.get('mode', 'once'),
        payload.get('replay_start'), payload.get('replay_end'), payload.get('target_time'),
        payload.get('bucket_count', 80), payload.get('distribution_model', 'ohlcv_triangular_v1'),
        payload.get('decay_model', 'none'), payload.get('baseline_policy', 'listing_to_replay_start'),
        payload.get('checkpoint_policy', 'same_level_periodic'), settings_version,
    ]
    raw = '|'.join(str(value or '') for value in fields)
    return 'chip:' + hashlib.sha256(raw.encode('utf-8')).hexdigest()


def _target_rows(rows: list[dict[str, Any]], target_time: str | None) -> list[dict[str, Any]]:
    if not target_time:
        return rows
    return [row for row in rows if not _time(row) or _time(row) <= target_time]


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


def _fold_row(row: dict[str, Any], sell: list[float], buy: list[float], lo: float, step: float, tick_mode: bool, errors: list[str]) -> bool:
    count = len(sell)
    bins = row.get('chip_tick_bins') or row.get('chipTickBins')
    if tick_mode:
        if not isinstance(bins, dict):
            errors.append('tick_bins_missing')
            return False
        prices, s_values, b_values, totals = bins.get('p', []), bins.get('s', []), bins.get('b', []), bins.get('w', [])
        for i, raw_price in enumerate(prices):
            price = _f(raw_price)
            if price <= 0:
                continue
            s = _f(s_values[i]) if i < len(s_values) else 0.0
            b = _f(b_values[i]) if i < len(b_values) else (_f(totals[i]) if i < len(totals) else 0.0)
            idx = _bucket(price, lo, step, count)
            sell[idx] += max(0.0, s)
            buy[idx] += max(0.0, b)
        return True
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
    weights: list[tuple[int, float]] = []
    span = max(high - low, step)
    for idx in range(first, last + 1):
        price = lo + (idx + 0.5) * step
        weight = max(0.001, 1.0 - abs(price - typical) / span)
        weights.append((idx, weight))
    total = sum(weight for _, weight in weights) or 1.0
    for idx, weight in weights:
        share = volume * weight / total
        if close >= (high + low) / 2.0:
            buy[idx] += share
        else:
            sell[idx] += share
    return True


def calculate_chip_distribution(
    payload: dict[str, Any],
    *,
    load_bars: Callable[..., list[dict[str, Any]]] | None = None,
) -> dict[str, Any]:
    level = str(payload.get('level') or 'DAILY').upper()
    symbol, market = str(payload.get('symbol') or ''), str(payload.get('market') or '')
    adjust = str(payload.get('adjust_type') or 'QFQ').upper()
    mode = str(payload.get('mode') or 'once').lower()
    replay_start, replay_end = payload.get('replay_start'), payload.get('replay_end')
    target_time = payload.get('target_time')
    settings_version = str(payload.get('settings_version') or '1')
    cache_key = _cache_key(payload, settings_version)
    cached = _CACHE.get(cache_key)
    if cached is not None:
        _CACHE.move_to_end(cache_key)
        result = json.loads(json.dumps(cached))
        result['chip_distribution_meta']['cache_hit'] = True
        return result

    bars = payload.get('bars')
    if not isinstance(bars, list):
        if load_bars is None:
            bars = []
        else:
            bars = load_bars(symbol=symbol, market=market, period=level, adjust=adjust,
                             count=int(payload.get('history_count') or 500000), start=None, end=target_time or replay_end)
    rows = _target_rows([dict(row) for row in bars if isinstance(row, dict)], str(target_time) if target_time else None)
    tick_mode = level == 'TICK'
    bucket_count = max(8, min(int(payload.get('bucket_count') or 80), 240))
    lo, hi = _price_range(rows, tick_mode)
    step = (hi - lo) / bucket_count if hi > lo else 1.0
    sell, buy = [0.0] * bucket_count, [0.0] * bucket_count
    errors: list[str] = []
    used = 0
    checkpoint_every = _checkpoint_interval(level, payload.get('checkpoint_interval'))
    checkpoint_key = f'{symbol}|{market}|{level}|{adjust}|{bucket_count}|{settings_version}'
    checkpoints: list[tuple[int, list[float], list[float]]] = []
    for i, row in enumerate(rows):
        if _fold_row(row, sell, buy, lo, step, tick_mode, errors):
            used += 1
        if (i + 1) % checkpoint_every == 0:
            checkpoints.append((i, list(sell), list(buy)))
    _CHECKPOINTS[checkpoint_key] = checkpoints
    total = sum(sell) + sum(buy)
    current = _f(rows[-1].get('close', rows[-1].get('c'))) if rows else 0.0
    bins = []
    weighted, profit, max_weight, poc = 0.0, 0.0, -1.0, current
    for i in range(bucket_count):
        price, weight = lo + (i + 0.5) * step, sell[i] + buy[i]
        weighted += price * weight
        if price <= current:
            profit += weight
        if weight > max_weight:
            max_weight, poc = weight, price
        bins.append({'price': price, 'sell_weight': sell[i], 'buy_weight': buy[i], 'weight': weight, 'ratio': weight / total if total else 0.0})
    baseline_rows = [row for row in rows if replay_start and _time(row) < str(replay_start)]
    runtime_rows = [row for row in rows if not replay_start or _time(row) >= str(replay_start)]
    target_index = len(rows) - 1
    future_blocked = bool(mode == 'step' and payload.get('max_allowed_time') and target_time and str(target_time) > str(payload['max_allowed_time']))
    meta = {
        'symbol': symbol, 'market': market, 'level': level, 'mode': mode,
        'listing_date': _time(rows[0]) if rows else None, 'replay_start': replay_start, 'replay_end': replay_end,
        'target_source': payload.get('target_source', 'last_bar'), 'target_index': target_index,
        'target_raw_index': _index(rows[-1], target_index) if rows else None, 'target_time': _time(rows[-1]) if rows else target_time,
        'crosshair_active': bool(payload.get('crosshair_active')), 'crosshair_index': payload.get('crosshair_index'), 'view_end_index': payload.get('view_end_index'),
        'adjust_type': adjust, 'volume_granularity': level, 'baseline_policy': 'listing_to_replay_start_exclusive',
        'baseline_start': _time(rows[0]) if rows else None, 'baseline_end': replay_start, 'baseline_level': level,
        'baseline_bar_count': len(baseline_rows), 'baseline_incomplete': not bool(rows),
        'checkpoint_used': bool(checkpoints), 'checkpoint_time': _time(rows[checkpoints[-1][0]]) if checkpoints else None,
        'checkpoint_index': checkpoints[-1][0] if checkpoints else None, 'checkpoint_level': level, 'checkpoint_source': 'backend_memory_same_level',
        'increment_start': replay_start, 'increment_end': target_time, 'increment_level': level, 'increment_bar_count': len(runtime_rows),
        'bucket_count': bucket_count, 'distribution_model': 'tick_exact_price_v1' if tick_mode else 'ohlcv_triangular_v1',
        'tick_mode': tick_mode, 'tick_bins_used': tick_mode and used > 0, 'tick_incomplete': tick_mode and bool(errors),
        'settings_version': settings_version, 'cache_key': cache_key, 'cache_hit': False, 'used_bar_count': used,
        'future_guard_passed': not future_blocked, 'future_guard_blocked': future_blocked, 'error_count': len(errors),
        'step_frame_index': payload.get('step_frame_index'), 'step_frame_time': payload.get('step_frame_time'),
        'max_allowed_time': payload.get('max_allowed_time'),
    }
    result = {
        'ok': True,
        'chip_distribution_state': {
            'target_index': target_index, 'current_price': current, 'total_weight': total,
            'sell_weight': sum(sell), 'buy_weight': sum(buy),
            'average_cost': weighted / total if total else 0.0, 'poc_price': poc,
            'profit_ratio': profit / total if total else 0.0, 'bins': bins,
        },
        'chip_distribution_meta': meta,
    }
    _CACHE[cache_key] = result
    max_cache = max(8, min(int(payload.get('cache_size') or 128), 2048))
    while len(_CACHE) > max_cache:
        _CACHE.popitem(last=False)
    return result
