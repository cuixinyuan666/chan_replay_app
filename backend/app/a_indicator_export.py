from __future__ import annotations

import math
import re
from typing import Any


def _to_float(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    if math.isnan(number) or math.isinf(number):
        return None
    return number


def _to_int(value: Any) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _bar_get(bar: dict[str, Any], *keys: str) -> Any:
    for key in keys:
        if key in bar:
            return bar[key]
    return None


def _bar_time(bar: dict[str, Any]) -> Any:
    return _bar_get(bar, 'time', 'dt', 'datetime', 'date')


def _bar_value(bar: dict[str, Any], *keys: str) -> float | None:
    return _to_float(_bar_get(bar, *keys))


def _point(bar: dict[str, Any], raw_index: int, value: float | None) -> dict[str, Any]:
    return {
        'time': _bar_time(bar),
        'raw_index': raw_index,
        'value': value,
    }


def _raw_index(bar: dict[str, Any], fallback: int) -> int:
    return _to_int(_bar_get(bar, 'raw_index', 'rawIndex', 'id', 'index')) or fallback


def _point_series(bars: list[dict[str, Any]], *keys: str) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for i, bar in enumerate(bars):
        result.append(_point(bar, _raw_index(bar, i), _bar_value(bar, *keys)))
    return result


def _close_values(bars: list[dict[str, Any]]) -> list[float | None]:
    return [_bar_value(bar, 'close', 'c') for bar in bars]


def _parse_periods(value: Any, *, defaults: list[int]) -> list[int]:
    raw: list[Any]
    if isinstance(value, (list, tuple, set)):
        raw = list(value)
    elif value is None:
        raw = []
    else:
        raw = [part for part in re.split(r'[,，\s]+', str(value).strip()) if part]
    result: list[int] = []
    for item in raw:
        period = _to_int(item)
        if period is None or period <= 0 or period > 500:
            continue
        if period not in result:
            result.append(period)
    return result or defaults


def _moving_average(bars: list[dict[str, Any]], period: int) -> list[dict[str, Any]]:
    closes = _close_values(bars)
    result: list[dict[str, Any]] = []
    window_sum = 0.0
    valid_count = 0
    window: list[float | None] = []
    for i, (bar, close) in enumerate(zip(bars, closes)):
        window.append(close)
        if close is not None:
            window_sum += close
            valid_count += 1
        if len(window) > period:
            old = window.pop(0)
            if old is not None:
                window_sum -= old
                valid_count -= 1
        value = window_sum / period if len(window) == period and valid_count == period else None
        result.append(_point(bar, _raw_index(bar, i), value))
    return result


def _ema(prev: float | None, value: float, period: int) -> float:
    alpha = 2.0 / (period + 1.0)
    return value if prev is None else alpha * value + (1.0 - alpha) * prev


def _macd_series(bars: list[dict[str, Any]], *, fast: int, slow: int, signal: int) -> list[dict[str, Any]]:
    fast = max(1, fast)
    slow = max(fast + 1, slow)
    signal = max(1, signal)
    ema_fast: float | None = None
    ema_slow: float | None = None
    dea: float | None = None
    result: list[dict[str, Any]] = []
    for i, bar in enumerate(bars):
        close = _bar_value(bar, 'close', 'c')
        if close is None:
            result.append({'time': _bar_time(bar), 'raw_index': _raw_index(bar, i), 'dif': None, 'dea': None, 'hist': None})
            continue
        ema_fast = _ema(ema_fast, close, fast)
        ema_slow = _ema(ema_slow, close, slow)
        dif = ema_fast - ema_slow
        dea = _ema(dea, dif, signal)
        result.append({
            'time': _bar_time(bar),
            'raw_index': _raw_index(bar, i),
            'dif': dif,
            'dea': dea,
            'hist': (dif - dea) * 2.0,
        })
    return result


def _boll_series(bars: list[dict[str, Any]], *, period: int) -> list[dict[str, Any]]:
    period = max(2, min(period, 500))
    closes = _close_values(bars)
    result: list[dict[str, Any]] = []
    window: list[float | None] = []
    for i, (bar, close) in enumerate(zip(bars, closes)):
        window.append(close)
        if len(window) > period:
            window.pop(0)
        values = [v for v in window if v is not None]
        if len(window) == period and len(values) == period:
            mid = sum(values) / period
            variance = sum((v - mid) ** 2 for v in values) / period
            std = math.sqrt(variance)
            upper = mid + 2.0 * std
            lower = mid - 2.0 * std
        else:
            upper = mid = lower = None
        result.append({
            'time': _bar_time(bar),
            'raw_index': _raw_index(bar, i),
            'upper': upper,
            'mid': mid,
            'lower': lower,
        })
    return result


def _cfg_int(config: dict[str, Any], key: str, default: int) -> int:
    value = _to_int(config.get(key))
    return default if value is None else value


def build_display_indicators(bars: list[dict[str, Any]], config: dict[str, Any] | None = None) -> dict[str, Any]:
    """Build display-only market/indicator series for Flutter.

    This adapter intentionally does not feed any value back into chan.py. The
    returned data is aligned by raw_index and exists only for VOL/amount/MACD/MA/
    BOLL sub-chart rendering and tooltip display.
    """
    cfg = config or {}
    ma_periods = _parse_periods(cfg.get('mean_metrics'), defaults=[5, 10, 20])
    macd_cfg = cfg.get('macd') if isinstance(cfg.get('macd'), dict) else {}
    fast = _cfg_int(macd_cfg, 'fast', _cfg_int(cfg, 'macd_fast', 12))
    slow = _cfg_int(macd_cfg, 'slow', _cfg_int(cfg, 'macd_slow', 26))
    signal = _cfg_int(macd_cfg, 'signal', _cfg_int(cfg, 'macd_signal', 9))
    boll_n = _cfg_int(cfg, 'boll_n', 20)

    return {
        'vol': _point_series(bars, 'vol', 'volume', 'v'),
        'amount': _point_series(bars, 'amount', 'money'),
        'turnover': _point_series(bars, 'turnover', 'turnover_rate', 'turnrate'),
        'ma': {str(period): _moving_average(bars, period) for period in ma_periods},
        'boll': _boll_series(bars, period=boll_n),
        'macd': _macd_series(bars, fast=fast, slow=slow, signal=signal),
    }


def indicator_source_meta() -> dict[str, str]:
    return {
        'vol': 'bars.volume/easy_tdx',
        'amount': 'bars.amount/easy_tdx_when_available',
        'turnover': 'bars.turnover/easy_tdx_when_available_null_not_estimated',
        'ma': 'backend_display_only_from_close',
        'boll': 'backend_display_only_from_close',
        'macd': 'backend_display_only_from_close',
    }
