from __future__ import annotations

import math
from datetime import date, datetime, time, timedelta
from typing import Any, Callable

from .easy_tdx_provider import infer_market, load_easy_tdx_bars, normalize_market, normalize_symbol


def attach_chip_history(
    result: dict[str, Any],
    *,
    payload: dict[str, Any],
    config: dict[str, Any] | None = None,
    load_bars: Callable[..., list[dict[str, Any]]] = load_easy_tdx_bars,
) -> dict[str, Any]:
    cfg = config or {}
    if _off(cfg) or not isinstance(result, dict) or not isinstance(result.get('levels'), dict):
        return result
    symbol = normalize_symbol(str(payload.get('symbol') or ''))
    if not symbol:
        return result
    market = normalize_market(symbol, payload.get('market') or infer_market(symbol))
    adjust = str(payload.get('adjust') or 'QFQ').upper()
    replay_end = payload.get('end')
    start_hint = _first_present(payload, cfg, 'listing_date', 'listed_at', 'ipo_date', 'chip_listing_date')
    history_count = _int(cfg.get('chip_history_count', payload.get('history_count', 500000)), 500000, 1, 500000)
    bucket_count = _int(cfg.get('chip_history_seed_bucket_count', 160), 160, 24, 4096)
    history_cache: dict[tuple[str, str, str], list[dict[str, Any]]] = {}
    seed_cache: dict[tuple[str, str, str], tuple[dict[str, Any] | None, dict[str, Any]]] = {}
    level_meta: dict[str, dict[str, Any]] = {}

    patched = dict(result)
    patched['levels'] = _patch_levels(
        result['levels'], symbol, market, adjust, replay_end, start_hint,
        history_count, bucket_count, load_bars, history_cache, seed_cache, level_meta)
    frames = result.get('frames')
    if isinstance(frames, list):
        patched_frames: list[Any] = []
        for frame in frames:
            if isinstance(frame, dict) and isinstance(frame.get('levels'), dict):
                next_frame = dict(frame)
                next_frame['levels'] = _patch_levels(
                    frame['levels'], symbol, market, adjust, replay_end, start_hint,
                    history_count, bucket_count, load_bars, history_cache, seed_cache, level_meta)
                patched_frames.append(next_frame)
            else:
                patched_frames.append(frame)
        patched['frames'] = patched_frames
    meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
    meta.update({
        'chip_history_baseline_enabled': True,
        'chip_history_baseline_policy': 'UI bars stay c-d; first visible bar chip_tick_bins carries listing/earliest-to-first-visible seed',
        'chip_history_baseline_levels': level_meta,
    })
    patched['meta'] = meta
    return patched


def _patch_levels(
    levels: dict[Any, Any], symbol: str, market: str, adjust: str, replay_end: Any,
    start_hint: str | None, history_count: int, bucket_count: int,
    load_bars: Callable[..., list[dict[str, Any]]],
    history_cache: dict[tuple[str, str, str], list[dict[str, Any]]],
    seed_cache: dict[tuple[str, str, str], tuple[dict[str, Any] | None, dict[str, Any]]],
    level_meta: dict[str, dict[str, Any]],
) -> dict[Any, Any]:
    out: dict[Any, Any] = {}
    for key, payload in levels.items():
        level = str(key).upper()
        bars = payload.get('bars') if isinstance(payload, dict) else None
        if not isinstance(bars, list) or not bars or not isinstance(bars[0], dict) or bars[0].get('chip_history_seed') is True:
            out[key] = payload
            continue
        visible_start = _time_text(bars[0])
        visible_end = _time_text(bars[-1]) or str(replay_end or '')
        if not visible_start:
            out[key] = payload
            continue
        cache_key = (level, visible_start, visible_end)
        if cache_key not in seed_cache:
            seed_cache[cache_key] = _build_seed(
                level, dict(bars[0]), visible_start, visible_end, symbol, market,
                adjust, replay_end, start_hint, history_count, bucket_count,
                load_bars, history_cache)
        seed, meta = seed_cache[cache_key]
        level_meta[level] = meta
        if seed is None:
            out[key] = payload
            continue
        next_bars = [dict(row) if isinstance(row, dict) else row for row in bars]
        first = dict(next_bars[0])
        first['chip_tick_bins'] = seed
        first['chip_history_seed'] = True
        first['chip_history_seed_policy'] = 'listing_to_first_visible_inclusive'
        next_bars[0] = first
        next_payload = dict(payload)
        next_payload['bars'] = next_bars
        pmeta = dict(next_payload.get('meta')) if isinstance(next_payload.get('meta'), dict) else {}
        pmeta['chip_history_seed'] = meta
        next_payload['meta'] = pmeta
        out[key] = next_payload
    return out


def _build_seed(
    level: str, first_bar: dict[str, Any], visible_start: str, visible_end: str,
    symbol: str, market: str, adjust: str, replay_end: Any, start_hint: str | None,
    history_count: int, bucket_count: int,
    load_bars: Callable[..., list[dict[str, Any]]],
    history_cache: dict[tuple[str, str, str], list[dict[str, Any]]],
) -> tuple[dict[str, Any] | None, dict[str, Any]]:
    history_period = _baseline_history_period(level)
    history_end = _baseline_history_end(history_period, visible_start) or str(replay_end or visible_end or '') or None
    hkey = (history_period, str(start_hint or ''), str(history_end or ''))
    errors: list[str] = []
    if hkey not in history_cache:
        try:
            rows = load_bars(symbol=symbol, market=market, period=history_period, adjust=adjust,
                             count=history_count, start=start_hint, end=history_end)
            history_cache[hkey] = _sort_rows(rows if isinstance(rows, list) else [])
        except Exception as exc:  # pragma: no cover
            history_cache[hkey] = []
            errors.append(f'provider_error:{type(exc).__name__}')
    history = history_cache[hkey]
    before = _baseline_rows_before_visible(history, visible_start, history_period)
    listing_date = start_hint or (_time_text(history[0]) if history else None)
    if not before:
        return None, {
            'status': 'no_baseline_rows', 'level': level, 'baseline_source_level': history_period,
            'listing_date': listing_date, 'visible_start': visible_start, 'visible_end': visible_end,
            'baseline_history_end': history_end, 'baseline_bar_count': 0,
            'history_bar_count': len(history), 'seed_includes_first_visible_bar': False,
            'errors': errors,
        }
    seed_rows = [*before, first_bar]
    seed = _fold(seed_rows, bucket_count)
    return seed, {
        'status': 'ok', 'level': level, 'baseline_source_level': history_period,
        'listing_date': listing_date, 'chip_calc_start': _time_text(seed_rows[0]),
        'visible_start': visible_start, 'visible_end': visible_end,
        'baseline_history_end': history_end,
        'baseline_policy': 'listing_or_earliest_to_visible_start_exclusive_plus_first_visible_bar',
        'baseline_bar_count': len(before), 'seed_bar_count': len(seed_rows),
        'history_bar_count': len(history), 'seed_bucket_count': len(seed.get('p', [])),
        'seed_total_weight': sum(float(v) for v in seed.get('w', [])),
        'seed_includes_first_visible_bar': True, 'errors': errors,
    }


def _baseline_history_period(level: str) -> str:
    text = level.upper().strip().replace('-', '_')
    compact = text.replace('_', '')
    if text in {'TICK', 'TRANSACTION', 'TRANSACTIONS', 'TICK_MIN1', 'TICK_1MIN', 'TICK_MIN_1', 'TXN_MIN1', 'TRANSACTION_MIN1', 'TRANSACTIONS_MIN1'}:
        return 'DAILY'
    if compact in {'TICK', 'TRANSACTION', 'TRANSACTIONS', 'TICKMIN1', 'TICK1MIN', 'TXNMIN1', 'TRANSACTIONMIN1', 'TRANSACTIONSMIN1'}:
        return 'DAILY'
    return level


def _baseline_history_end(history_period: str, visible_start: str) -> str | None:
    visible_dt = _parse_dt(visible_start)
    if visible_dt is None:
        return visible_start or None
    if _is_daily_period(history_period):
        # A daily row dated the same day as an intraday visible_start would contain
        # future intraday volume. End at the previous calendar day and filter by
        # row date again below to keep the baseline future-free.
        return (visible_dt.date() - timedelta(days=1)).isoformat()
    return visible_start


def _baseline_rows_before_visible(rows: list[dict[str, Any]], visible_start: str, history_period: str) -> list[dict[str, Any]]:
    visible_dt = _parse_dt(visible_start)
    before: list[dict[str, Any]] = []
    for row in rows:
        row_dt = _parse_dt(_time_text(row))
        if row_dt is None:
            continue
        if _is_daily_period(history_period) and visible_dt is not None:
            if row_dt.date() < visible_dt.date():
                before.append(row)
            continue
        if visible_dt is not None:
            if row_dt < visible_dt:
                before.append(row)
        elif _cmp_time(_time_text(row), visible_start) < 0:
            before.append(row)
    return before


def _is_daily_period(period: str) -> bool:
    return period.upper().strip().replace('-', '_') in {'D', 'DAY', 'DAILY', 'K_DAY', 'KDAY'}


def _fold(rows: list[dict[str, Any]], bucket_count: int) -> dict[str, Any]:
    lo, hi = _range(rows)
    if lo <= 0 or hi <= 0:
        return {'p': [], 's': [], 'b': [], 'w': [], 'source': 'backend_chip_history_seed'}
    if abs(hi - lo) < 1e-12:
        lo, hi = lo * 0.999, hi * 1.001
    step = (hi - lo) / bucket_count
    sell = [0.0] * bucket_count
    buy = [0.0] * bucket_count
    for row in rows:
        bins = row.get('chip_tick_bins') or row.get('chipTickBins')
        if isinstance(bins, dict):
            _fold_exact(bins, sell, buy, lo, step)
        else:
            _fold_ohlcv(row, sell, buy, lo, step)
    prices: list[float] = []
    sells: list[float] = []
    buys: list[float] = []
    totals: list[float] = []
    for i, (s, b) in enumerate(zip(sell, buy)):
        total = s + b
        if total <= 0:
            continue
        prices.append(lo + (i + 0.5) * step)
        sells.append(s)
        buys.append(b)
        totals.append(total)
    return {'p': prices, 's': sells, 'b': buys, 'w': totals,
            'source': 'backend_chip_history_seed', 'seed_model': 'ohlcv_triangular_or_exact_tick_v1'}


def _fold_exact(bins: dict[str, Any], sell: list[float], buy: list[float], lo: float, step: float) -> None:
    prices = bins.get('p') or bins.get('prices') or []
    s_values = bins.get('s') or bins.get('sell') or []
    b_values = bins.get('b') or bins.get('buy') or []
    totals = bins.get('w') or bins.get('weight') or bins.get('weights') or []
    for i, raw_price in enumerate(prices):
        price = _float(raw_price)
        if price <= 0:
            continue
        s = _float(s_values[i]) if i < len(s_values) else 0.0
        b = _float(b_values[i]) if i < len(b_values) else 0.0
        total = _float(totals[i]) if i < len(totals) else s + b
        if total > 0 and s <= 0 and b <= 0:
            b = total
        idx = _bucket(price, lo, step, len(sell))
        sell[idx] += max(0.0, s)
        buy[idx] += max(0.0, b)


def _fold_ohlcv(row: dict[str, Any], sell: list[float], buy: list[float], lo: float, step: float) -> None:
    volume = _float(row.get('volume', row.get('vol', row.get('v'))))
    low = _float(row.get('low', row.get('l')))
    high = _float(row.get('high', row.get('h')))
    close = _float(row.get('close', row.get('c')))
    if volume <= 0 or high < low or high <= 0 or low <= 0:
        return
    if abs(high - low) < 1e-12:
        buy[_bucket(close, lo, step, len(buy))] += volume
        return
    typical = (high + low + close) / 3.0
    first = _bucket(low, lo, step, len(buy))
    last = _bucket(high, lo, step, len(buy))
    weights = [(i, max(0.001, 1.0 - abs((lo + (i + 0.5) * step) - typical) / max(high - low, step))) for i in range(first, last + 1)]
    total = sum(weight for _, weight in weights) or 1.0
    for idx, weight in weights:
        share = volume * weight / total
        if close >= (high + low) / 2.0:
            buy[idx] += share
        else:
            sell[idx] += share


def _range(rows: list[dict[str, Any]]) -> tuple[float, float]:
    prices: list[float] = []
    for row in rows:
        bins = row.get('chip_tick_bins') or row.get('chipTickBins')
        if isinstance(bins, dict):
            prices.extend(_float(p) for p in (bins.get('p') or bins.get('prices') or []) if _float(p) > 0)
        else:
            low = _float(row.get('low', row.get('l')))
            high = _float(row.get('high', row.get('h')))
            close = _float(row.get('close', row.get('c')))
            if low > 0 and high >= low:
                prices.extend((low, high))
            elif close > 0:
                prices.append(close)
    return (min(prices), max(prices)) if prices else (0.0, 0.0)


def _off(config: dict[str, Any]) -> bool:
    raw = config.get('chip_history_baseline_enabled', True)
    return (not raw) if isinstance(raw, bool) else str(raw).strip().lower() in {'0', 'false', 'no', 'off'}


def _first_present(payload: dict[str, Any], config: dict[str, Any], *keys: str) -> str | None:
    for source in (payload, config):
        for key in keys:
            value = source.get(key)
            if value:
                return str(value)
    return None


def _sort_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted([dict(row) for row in rows if isinstance(row, dict) and _parse_dt(_time_text(row)) is not None],
                  key=lambda row: (_parse_dt(_time_text(row)) or datetime.min, int(row.get('raw_index', row.get('id', 0)) or 0)))


def _time_text(row: dict[str, Any]) -> str:
    return str(row.get('time') or row.get('dt') or row.get('datetime') or row.get('date') or '')


def _parse_dt(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    if isinstance(value, date):
        return datetime.combine(value, time.min)
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


def _cmp_time(a: Any, b: Any) -> int:
    da, db = _parse_dt(a), _parse_dt(b)
    if da is not None and db is not None:
        return (da > db) - (da < db)
    return (str(a or '') > str(b or '')) - (str(a or '') < str(b or ''))


def _bucket(price: float, lo: float, step: float, count: int) -> int:
    return max(0, min(count - 1, int((price - lo) / max(step, 1e-12))))


def _int(value: Any, default: int, minimum: int, maximum: int) -> int:
    try:
        number = int(value)
    except (TypeError, ValueError):
        number = default
    return max(minimum, min(number, maximum))


def _float(value: Any) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return 0.0
    return number if math.isfinite(number) else 0.0
