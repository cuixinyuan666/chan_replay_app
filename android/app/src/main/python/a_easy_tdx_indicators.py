from __future__ import annotations

from collections.abc import Iterable
from typing import Any


def _to_float(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip().replace(',', '')
    if not text or text in {'-', '--'} or text.lower() in {'none', 'null', 'nan'}:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def _time(row: dict[str, Any]) -> str | None:
    value = row.get('time') or row.get('dt') or row.get('datetime') or row.get('date')
    return None if value is None else str(value)


def _raw_index(row: dict[str, Any], fallback: int) -> int:
    value = row.get('raw_index', row.get('rawIndex', row.get('id', fallback)))
    try:
        return int(value)
    except (TypeError, ValueError):
        return fallback


def _point(row: dict[str, Any], fallback: int, value: Any) -> dict[str, Any]:
    return {'time': _time(row), 'raw_index': _raw_index(row, fallback), 'value': _to_float(value)}


def _ema(prev: float | None, value: float, period: int) -> float:
    alpha = 2.0 / (period + 1.0)
    return value if prev is None else alpha * value + (1.0 - alpha) * prev


def _moving_average(values: list[float | None], window: int) -> list[float | None]:
    result: list[float | None] = []
    running: list[float] = []
    for value in values:
        if value is None:
            running.clear()
            result.append(None)
            continue
        running.append(value)
        if len(running) > window:
            running.pop(0)
        result.append(sum(running) / window if len(running) >= window else None)
    return result


def _std(values: Iterable[float]) -> float:
    rows = list(values)
    if not rows:
        return 0.0
    mean = sum(rows) / len(rows)
    return (sum((item - mean) ** 2 for item in rows) / len(rows)) ** 0.5


def _boll(values: list[float | None], window: int) -> list[tuple[float | None, float | None, float | None]]:
    result: list[tuple[float | None, float | None, float | None]] = []
    running: list[float] = []
    for value in values:
        if value is None:
            running.clear()
            result.append((None, None, None))
            continue
        running.append(value)
        if len(running) > window:
            running.pop(0)
        if len(running) < window:
            result.append((None, None, None))
            continue
        mid = sum(running) / window
        delta = 2.0 * _std(running)
        result.append((mid + delta, mid, mid - delta))
    return result


def _macd(values: list[float | None], *, fast: int, slow: int, signal: int) -> list[tuple[float | None, float | None, float | None]]:
    result: list[tuple[float | None, float | None, float | None]] = []
    ema_fast: float | None = None
    ema_slow: float | None = None
    dea: float | None = None
    for value in values:
        if value is None:
            ema_fast = ema_slow = dea = None
            result.append((None, None, None))
            continue
        ema_fast = _ema(ema_fast, value, fast)
        ema_slow = _ema(ema_slow, value, slow)
        dif = ema_fast - ema_slow
        dea = _ema(dea, dif, signal)
        result.append((dif, dea, dif - dea))
    return result


def build_easy_tdx_indicators(
    bars: list[dict[str, Any]],
    *,
    ma_windows: tuple[int, ...] = (5, 10, 20, 60),
    boll_window: int = 20,
    macd_fast: int = 12,
    macd_slow: int = 26,
    macd_signal: int = 9,
) -> dict[str, Any]:
    closes = [_to_float(row.get('close') or row.get('c')) for row in bars]
    result: dict[str, Any] = {
        'vol': [_point(row, i, row.get('volume', row.get('vol', row.get('v')))) for i, row in enumerate(bars)],
        'amount': [_point(row, i, row.get('amount', row.get('money'))) for i, row in enumerate(bars)],
        'turnover': [_point(row, i, row.get('turnover', row.get('turnover_rate'))) for i, row in enumerate(bars)],
        'ma': {},
    }
    ma: dict[str, list[dict[str, Any]]] = {}
    for window in ma_windows:
        values = _moving_average(closes, window)
        ma[str(window)] = [{'time': _time(row), 'raw_index': _raw_index(row, i), 'value': values[i]} for i, row in enumerate(bars)]
    result['ma'] = ma
    boll_rows = _boll(closes, boll_window)
    result['boll'] = [
        {'time': _time(row), 'raw_index': _raw_index(row, i), 'upper': upper, 'mid': mid, 'lower': lower}
        for i, (row, (upper, mid, lower)) in enumerate(zip(bars, boll_rows))
    ]
    macd_rows = _macd(closes, fast=macd_fast, slow=macd_slow, signal=macd_signal)
    result['macd'] = [
        {'time': _time(row), 'raw_index': _raw_index(row, i), 'dif': dif, 'dea': dea, 'hist': hist}
        for i, (row, (dif, dea, hist)) in enumerate(zip(bars, macd_rows))
    ]
    return result


def easy_tdx_indicator_meta() -> dict[str, Any]:
    return {
        'indicator_sources': {
            'vol': 'easy_tdx_bar.volume',
            'amount': 'easy_tdx_bar.amount_or_null',
            'turnover': 'easy_tdx_bar.turnover_or_null',
            'ma': 'android_display_only_from_close',
            'boll': 'android_display_only_from_close',
            'macd': 'android_display_only_from_close',
        },
        'indicator_warning': '指标仅用于展示和 tooltip，不参与 chan.py 缠论结构计算。',
    }
