from __future__ import annotations

from statistics import mean
from typing import Any


def _num(value: Any) -> float | None:
    if isinstance(value, bool) or value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _int(value: Any) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _get(row: dict[str, Any], *keys: str, default: Any = None) -> Any:
    for key in keys:
        if key in row:
            return row[key]
    return default


def _close(bar: dict[str, Any]) -> float | None:
    return _num(_get(bar, 'close', 'c'))


def _open(bar: dict[str, Any]) -> float | None:
    return _num(_get(bar, 'open', 'o'))


def _high(bar: dict[str, Any]) -> float | None:
    return _num(_get(bar, 'high', 'h'))


def _low(bar: dict[str, Any]) -> float | None:
    return _num(_get(bar, 'low', 'l'))


def _vol(bar: dict[str, Any]) -> float | None:
    return _num(_get(bar, 'vol', 'volume', 'v'))


def _time(bar: dict[str, Any]) -> Any:
    return _get(bar, 'time', 'dt', 'datetime', 'date')


def _safe_pct(numerator: float | None, denominator: float | None) -> float | None:
    if numerator is None or denominator is None or abs(denominator) < 1e-12:
        return None
    return numerator / denominator


def _rolling(values: list[float | None], end: int, window: int) -> list[float]:
    start = max(0, end - window + 1)
    return [v for v in values[start:end + 1] if v is not None]


def _indicator_by_index(rows: Any, raw_index: int, *keys: str) -> float | None:
    if not isinstance(rows, list):
        return None
    for row in rows:
        if not isinstance(row, dict):
            continue
        idx = _int(_get(row, 'raw_index', 'rawIndex'))
        if idx != raw_index:
            continue
        for key in keys:
            value = _num(row.get(key))
            if value is not None:
                return value
    return None


def _ma_by_index(indicators: dict[str, Any], raw_index: int) -> dict[str, float | None]:
    result: dict[str, float | None] = {}
    ma = indicators.get('ma')
    if not isinstance(ma, dict):
        return result
    for period, rows in ma.items():
        result[f'ma_{period}'] = _indicator_by_index(rows, raw_index, 'value')
    return result


def _last_zs_distance(zss: list[Any], raw_index: int, price: float | None) -> dict[str, Any]:
    best: dict[str, Any] | None = None
    for zs in zss:
        if not isinstance(zs, dict):
            continue
        start = _int(_get(zs, 'start_raw_index', 'startRawIndex'))
        end = _int(_get(zs, 'end_raw_index', 'endRawIndex'))
        if start is None or end is None or start > raw_index:
            continue
        if end > raw_index:
            distance_bars = 0
        else:
            distance_bars = raw_index - end
        if best is None or distance_bars < best['zs_distance_bars']:
            zd = _num(_get(zs, 'zd', 'low'))
            zg = _num(_get(zs, 'zg', 'high'))
            center = (zd + zg) / 2.0 if zd is not None and zg is not None else None
            width = zg - zd if zd is not None and zg is not None else None
            best = {
                'zs_index': _int(zs.get('index')),
                'zs_distance_bars': distance_bars,
                'zs_width_pct': _safe_pct(width, center),
                'price_to_zs_center_pct': _safe_pct(None if price is None or center is None else price - center, center),
            }
    return best or {
        'zs_index': None,
        'zs_distance_bars': None,
        'zs_width_pct': None,
        'price_to_zs_center_pct': None,
    }


def _line_context(rows: list[Any], raw_index: int, prefix: str) -> dict[str, Any]:
    selected: dict[str, Any] | None = None
    for row in rows:
        if not isinstance(row, dict):
            continue
        start = _int(_get(row, 'start_raw_index', 'startRawIndex'))
        end = _int(_get(row, 'end_raw_index', 'endRawIndex'))
        if start is None or end is None:
            continue
        if start <= raw_index <= end or end <= raw_index:
            if selected is None or (_int(_get(row, 'index')) or -1) > (_int(_get(selected, 'index')) or -1):
                selected = row
    if selected is None:
        return {
            f'{prefix}_index': None,
            f'{prefix}_is_up': None,
            f'{prefix}_is_sure': None,
            f'{prefix}_length_bars': None,
            f'{prefix}_amplitude_pct': None,
        }
    start = _int(_get(selected, 'start_raw_index', 'startRawIndex'))
    end = _int(_get(selected, 'end_raw_index', 'endRawIndex'))
    start_price = _num(_get(selected, 'start_price', 'startPrice'))
    end_price = _num(_get(selected, 'end_price', 'endPrice'))
    return {
        f'{prefix}_index': _int(_get(selected, 'index')),
        f'{prefix}_is_up': bool(_get(selected, 'is_up', 'isUp', default=False)),
        f'{prefix}_is_sure': bool(_get(selected, 'is_sure', 'isSure', 'confirmed', default=True)),
        f'{prefix}_length_bars': None if start is None or end is None else max(0, end - start + 1),
        f'{prefix}_amplitude_pct': _safe_pct(None if start_price is None or end_price is None else end_price - start_price, start_price),
    }


def _future_label(bars: list[dict[str, Any]], raw_index: int, horizon: int, is_buy: bool) -> dict[str, Any]:
    entry_idx = raw_index + 1
    exit_idx = min(len(bars) - 1, raw_index + horizon)
    if entry_idx >= len(bars) or exit_idx <= raw_index:
        return {'label_horizon': horizon, 'future_return': None, 'label_win': None}
    entry = _open(bars[entry_idx]) or _close(bars[entry_idx])
    exit_price = _close(bars[exit_idx])
    if entry is None or exit_price is None or abs(entry) < 1e-12:
        return {'label_horizon': horizon, 'future_return': None, 'label_win': None}
    ret = (exit_price - entry) / entry
    if not is_buy:
        ret = -ret
    return {'label_horizon': horizon, 'future_return': ret, 'label_win': ret > 0}


def extract_bsp_features(analysis: dict[str, Any], *, label_horizon: int = 5, include_labels: bool = True) -> dict[str, Any]:
    """Extract non-invasive BSP feature rows from an analysis JSON.

    Feature values are derived from the current/past bar window, exported chan.py
    structures, and display indicators. Future returns are isolated under label_*
    fields and should be used only for offline training/evaluation.
    """
    bars = [row for row in analysis.get('bars', []) if isinstance(row, dict)]
    bsp_rows = [row for row in analysis.get('bsp', []) if isinstance(row, dict)]
    bi_rows = analysis.get('bi', []) if isinstance(analysis.get('bi'), list) else []
    seg_rows = analysis.get('seg', []) if isinstance(analysis.get('seg'), list) else []
    zs_rows = analysis.get('zs', []) if isinstance(analysis.get('zs'), list) else []
    indicators = analysis.get('indicators') if isinstance(analysis.get('indicators'), dict) else {}
    closes = [_close(row) for row in bars]
    volumes = [_vol(row) for row in bars]

    rows: list[dict[str, Any]] = []
    for bsp in bsp_rows:
        raw_index = _int(_get(bsp, 'raw_index', 'rawIndex', 'klu_idx', 'kluIdx'))
        if raw_index is None or raw_index < 0 or raw_index >= len(bars):
            continue
        bar = bars[raw_index]
        close = _close(bar)
        open_ = _open(bar)
        high = _high(bar)
        low = _low(bar)
        price = _num(_get(bsp, 'price', 'value')) or close
        is_buy = bool(_get(bsp, 'is_buy', 'isBuy', default=str(_get(bsp, 'type', '')).upper().startswith('B')))
        volume_window = _rolling(volumes, raw_index, 20)
        close_window_5 = _rolling(closes, raw_index, 5)
        close_window_20 = _rolling(closes, raw_index, 20)
        ma_values = _ma_by_index(indicators, raw_index)
        ma_20 = ma_values.get('ma_20') or (mean(close_window_20) if len(close_window_20) == 20 else None)
        row = {
            'bsp_index': _int(_get(bsp, 'index')),
            'raw_index': raw_index,
            'time': _time(bar),
            'level': str(_get(bsp, 'level', default='bi')),
            'type': _get(bsp, 'type', 'types', default=''),
            'is_buy': is_buy,
            'is_sure': bool(_get(bsp, 'is_sure', 'isSure', 'confirmed', default=True)),
            'price': price,
            'close': close,
            'bar_body_pct': _safe_pct(None if open_ is None or close is None else close - open_, open_),
            'bar_range_pct': _safe_pct(None if high is None or low is None else high - low, close),
            'ret_1': _safe_pct(None if raw_index < 1 or close is None or closes[raw_index - 1] is None else close - closes[raw_index - 1], closes[raw_index - 1] if raw_index >= 1 else None),
            'ret_5': _safe_pct(None if raw_index < 5 or close is None or closes[raw_index - 5] is None else close - closes[raw_index - 5], closes[raw_index - 5] if raw_index >= 5 else None),
            'ret_20': _safe_pct(None if raw_index < 20 or close is None or closes[raw_index - 20] is None else close - closes[raw_index - 20], closes[raw_index - 20] if raw_index >= 20 else None),
            'close_to_ma20_pct': _safe_pct(None if close is None or ma_20 is None else close - ma_20, ma_20),
            'close_std_5_pct': None,
            'volume_ratio_20': None if not volume_window or volumes[raw_index] is None else _safe_pct(volumes[raw_index], mean(volume_window)),
            'macd_dif': _indicator_by_index(indicators.get('macd'), raw_index, 'dif'),
            'macd_dea': _indicator_by_index(indicators.get('macd'), raw_index, 'dea'),
            'macd_hist': _indicator_by_index(indicators.get('macd'), raw_index, 'hist'),
            **ma_values,
            **_line_context(bi_rows, raw_index, 'bi'),
            **_line_context(seg_rows, raw_index, 'seg'),
            **_last_zs_distance(zs_rows, raw_index, price),
        }
        if len(close_window_5) >= 2 and close is not None:
            avg = mean(close_window_5)
            variance = mean([(x - avg) ** 2 for x in close_window_5])
            row['close_std_5_pct'] = _safe_pct(variance ** 0.5, close)
        if include_labels:
            row.update(_future_label(bars, raw_index, max(1, label_horizon), is_buy))
        rows.append(row)

    return {
        'ok': True,
        'features': rows,
        'meta': {
            'source': 'origin_vespa_tdx.backend.a_bsp_feature_engine',
            'bsp_count': len(bsp_rows),
            'feature_count': len(rows),
            'label_horizon': label_horizon if include_labels else None,
            'labels_use_future_data': include_labels,
            'chan_py_polluted': False,
        },
    }
