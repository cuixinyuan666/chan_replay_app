from __future__ import annotations

from dataclasses import dataclass
from statistics import mean
from typing import Any, Callable


FeatureRow = dict[str, Any]
FeatureExtractor = Callable[['BspFeatureContext', dict[str, Any], int], FeatureRow]
_FEATURE_REGISTRY: list[tuple[str, FeatureExtractor]] = []


def register_bsp_feature_extractor(name: str) -> Callable[[FeatureExtractor], FeatureExtractor]:
    """Register a non-invasive BSP feature extractor.

    The registry keeps the BSP feature engine extensible: future feature groups can
    be added without rewriting ``extract_bsp_features``.  Extractors must be pure
    readers of the exported analysis JSON and must never mutate chan.py objects.
    """

    def decorator(func: FeatureExtractor) -> FeatureExtractor:
        _FEATURE_REGISTRY.append((name, func))
        return func

    return decorator


def registered_bsp_feature_extractors() -> list[str]:
    return [name for name, _ in _FEATURE_REGISTRY]


@dataclass(frozen=True)
class BspFeatureContext:
    analysis: dict[str, Any]
    bars: list[dict[str, Any]]
    bsp_rows: list[dict[str, Any]]
    bi_rows: list[Any]
    seg_rows: list[Any]
    zs_rows: list[Any]
    indicators: dict[str, Any]
    closes: list[float | None]
    volumes: list[float | None]
    label_horizon: int
    include_labels: bool


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


def _bool_value(value: Any) -> bool | None:
    if isinstance(value, bool):
        return value
    if value is None:
        return None
    text = str(value).strip().lower()
    if text in {'1', 'true', 'yes', 'y', 'up'}:
        return True
    if text in {'0', 'false', 'no', 'n', 'down'}:
        return False
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


def _safe_div(numerator: float | None, denominator: float | None) -> float | None:
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


def _row_start(row: dict[str, Any]) -> int | None:
    return _int(_get(row, 'start_raw_index', 'startRawIndex', 'begin_raw_index', 'beginRawIndex'))


def _row_end(row: dict[str, Any]) -> int | None:
    return _int(_get(row, 'end_raw_index', 'endRawIndex', 'finish_raw_index', 'finishRawIndex'))


def _row_index(row: dict[str, Any]) -> int | None:
    return _int(_get(row, 'index', 'idx'))


def _line_extreme_from_bars(
    bars: list[dict[str, Any]],
    start: int | None,
    end: int | None,
) -> tuple[float | None, float | None]:
    if start is None or end is None or not bars:
        return None, None
    left = max(0, min(start, end))
    right = min(len(bars) - 1, max(start, end))
    if left > right:
        return None, None
    highs = [_high(bar) for bar in bars[left:right + 1]]
    lows = [_low(bar) for bar in bars[left:right + 1]]
    valid_highs = [value for value in highs if value is not None]
    valid_lows = [value for value in lows if value is not None]
    return (max(valid_highs) if valid_highs else None, min(valid_lows) if valid_lows else None)


def _line_direction(row: dict[str, Any], start_price: float | None, end_price: float | None) -> bool | None:
    explicit = _bool_value(_get(row, 'is_up', 'isUp', 'direction_up', 'up'))
    if explicit is not None:
        return explicit
    direction = str(_get(row, 'direction', 'dir', default='')).strip().lower()
    if direction in {'up', 'rise', 'bull', 'bullish', '向上', '上'}:
        return True
    if direction in {'down', 'fall', 'bear', 'bearish', '向下', '下'}:
        return False
    if start_price is not None and end_price is not None:
        return end_price >= start_price
    return None


def _line_missing_context(prefix: str) -> dict[str, Any]:
    keys = [
        'index', 'is_up', 'direction', 'is_sure', 'start_raw_index', 'end_raw_index',
        'start_time', 'end_time', 'start_price', 'end_price', 'high', 'low',
        'mid_price', 'length_bars', 'price_change', 'price_change_pct',
        'amplitude_abs', 'amplitude_pct', 'slope_pct_per_bar', 'progress_bars',
        'progress_ratio', 'age_bars', 'bars_since_end', 'is_active',
        'close_position_in_range', 'price_to_start_pct', 'price_to_end_pct',
        'price_to_high_pct', 'price_to_low_pct', 'same_direction_as_bsp',
        'raw_power', 'raw_slope', 'macd_area', 'volume_sum', 'prev_index',
        'prev_is_up', 'prev_length_bars', 'prev_amplitude_pct',
        'length_vs_prev_ratio', 'amplitude_vs_prev_ratio',
    ]
    return {f'{prefix}_{key}': None for key in keys}


def _line_context(
    rows: list[Any],
    raw_index: int,
    prefix: str,
    *,
    bars: list[dict[str, Any]],
    price: float | None,
    signal_is_buy: bool,
) -> dict[str, Any]:
    candidates: list[dict[str, Any]] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        start = _row_start(row)
        end = _row_end(row)
        if start is None or end is None or start > raw_index:
            continue
        if start <= raw_index <= end or end <= raw_index:
            candidates.append(row)
    if not candidates:
        return _line_missing_context(prefix)

    selected = max(
        candidates,
        key=lambda row: (
            _row_end(row) if _row_end(row) is not None else -1,
            _row_index(row) if _row_index(row) is not None else -1,
        ),
    )
    selected_start = _row_start(selected)
    selected_end = _row_end(selected)
    selected_index = _row_index(selected)
    start_price = _num(_get(selected, 'start_price', 'startPrice', 'begin_price', 'beginPrice'))
    end_price = _num(_get(selected, 'end_price', 'endPrice', 'finish_price', 'finishPrice'))
    high = _num(_get(selected, 'high', 'hi', 'max_price', 'maxPrice', 'peak_price', 'peakPrice'))
    low = _num(_get(selected, 'low', 'lo', 'min_price', 'minPrice', 'valley_price', 'valleyPrice'))
    if high is None or low is None:
        bar_high, bar_low = _line_extreme_from_bars(bars, selected_start, selected_end)
        high = high if high is not None else bar_high
        low = low if low is not None else bar_low
    mid_price = (high + low) / 2.0 if high is not None and low is not None else None
    is_up = _line_direction(selected, start_price, end_price)
    is_sure = _bool_value(_get(selected, 'is_sure', 'isSure', 'confirmed'))
    if is_sure is None:
        is_sure = True
    length_bars = None if selected_start is None or selected_end is None else max(0, selected_end - selected_start + 1)
    price_change = None if start_price is None or end_price is None else end_price - start_price
    price_change_pct = _safe_pct(price_change, start_price)
    amplitude_abs = None if high is None or low is None else high - low
    amplitude_pct = _safe_pct(amplitude_abs, mid_price or start_price or end_price)
    slope_pct_per_bar = _safe_div(price_change_pct, float(length_bars or 0))
    is_active = bool(selected_start is not None and selected_end is not None and selected_start <= raw_index <= selected_end)
    progress_bars = None if selected_start is None else max(0, raw_index - selected_start)
    progress_ratio = _safe_div(
        None if progress_bars is None else float(progress_bars),
        None if length_bars is None or length_bars <= 1 else float(length_bars - 1),
    )
    if progress_ratio is not None:
        progress_ratio = max(0.0, min(1.0, progress_ratio))
    bars_since_end = None if selected_end is None else max(0, raw_index - selected_end)
    age_bars = 0 if is_active else bars_since_end

    previous: dict[str, Any] | None = None
    for row in rows:
        if not isinstance(row, dict) or row is selected:
            continue
        row_end = _row_end(row)
        row_idx = _row_index(row)
        if row_end is None or selected_start is None or row_end > selected_start:
            continue
        if selected_index is not None and row_idx is not None and row_idx >= selected_index:
            continue
        if previous is None or (row_end, row_idx or -1) > (_row_end(previous) or -1, _row_index(previous) or -1):
            previous = row
    prev_start = _row_start(previous) if previous is not None else None
    prev_end = _row_end(previous) if previous is not None else None
    prev_start_price = _num(_get(previous or {}, 'start_price', 'startPrice', 'begin_price', 'beginPrice'))
    prev_end_price = _num(_get(previous or {}, 'end_price', 'endPrice', 'finish_price', 'finishPrice'))
    prev_high = _num(_get(previous or {}, 'high', 'hi', 'max_price', 'maxPrice', 'peak_price', 'peakPrice'))
    prev_low = _num(_get(previous or {}, 'low', 'lo', 'min_price', 'minPrice', 'valley_price', 'valleyPrice'))
    if previous is not None and (prev_high is None or prev_low is None):
        bar_high, bar_low = _line_extreme_from_bars(bars, prev_start, prev_end)
        prev_high = prev_high if prev_high is not None else bar_high
        prev_low = prev_low if prev_low is not None else bar_low
    prev_length = None if prev_start is None or prev_end is None else max(0, prev_end - prev_start + 1)
    prev_mid = (prev_high + prev_low) / 2.0 if prev_high is not None and prev_low is not None else None
    prev_amplitude = None if prev_high is None or prev_low is None else prev_high - prev_low
    prev_amplitude_pct = _safe_pct(prev_amplitude, prev_mid or prev_start_price or prev_end_price)
    prev_is_up = _line_direction(previous or {}, prev_start_price, prev_end_price) if previous is not None else None

    row = {
        f'{prefix}_index': selected_index,
        f'{prefix}_is_up': is_up,
        f'{prefix}_direction': 'up' if is_up is True else ('down' if is_up is False else None),
        f'{prefix}_is_sure': is_sure,
        f'{prefix}_start_raw_index': selected_start,
        f'{prefix}_end_raw_index': selected_end,
        f'{prefix}_start_time': _get(selected, 'start_time', 'startTime', 'begin_time', 'beginTime'),
        f'{prefix}_end_time': _get(selected, 'end_time', 'endTime', 'finish_time', 'finishTime'),
        f'{prefix}_start_price': start_price,
        f'{prefix}_end_price': end_price,
        f'{prefix}_high': high,
        f'{prefix}_low': low,
        f'{prefix}_mid_price': mid_price,
        f'{prefix}_length_bars': length_bars,
        f'{prefix}_price_change': price_change,
        f'{prefix}_price_change_pct': price_change_pct,
        f'{prefix}_amplitude_abs': amplitude_abs,
        f'{prefix}_amplitude_pct': amplitude_pct,
        f'{prefix}_slope_pct_per_bar': slope_pct_per_bar,
        f'{prefix}_progress_bars': progress_bars,
        f'{prefix}_progress_ratio': progress_ratio,
        f'{prefix}_age_bars': age_bars,
        f'{prefix}_bars_since_end': bars_since_end,
        f'{prefix}_is_active': is_active,
        f'{prefix}_close_position_in_range': _safe_div(None if price is None or low is None else price - low, amplitude_abs),
        f'{prefix}_price_to_start_pct': _safe_pct(None if price is None or start_price is None else price - start_price, start_price),
        f'{prefix}_price_to_end_pct': _safe_pct(None if price is None or end_price is None else price - end_price, end_price),
        f'{prefix}_price_to_high_pct': _safe_pct(None if price is None or high is None else price - high, high),
        f'{prefix}_price_to_low_pct': _safe_pct(None if price is None or low is None else price - low, low),
        f'{prefix}_same_direction_as_bsp': None if is_up is None else is_up == signal_is_buy,
        f'{prefix}_raw_power': _num(_get(selected, 'power', 'strength', 'force')),
        f'{prefix}_raw_slope': _num(_get(selected, 'slope', 'slope_pct', 'slopePct')),
        f'{prefix}_macd_area': _num(_get(selected, 'macd_area', 'macdArea', 'macd_power', 'macdPower')),
        f'{prefix}_volume_sum': _num(_get(selected, 'volume_sum', 'volumeSum', 'vol_sum', 'volSum', 'volume', 'vol')),
        f'{prefix}_prev_index': _row_index(previous) if previous is not None else None,
        f'{prefix}_prev_is_up': prev_is_up,
        f'{prefix}_prev_length_bars': prev_length,
        f'{prefix}_prev_amplitude_pct': prev_amplitude_pct,
        f'{prefix}_length_vs_prev_ratio': _safe_div(None if length_bars is None else float(length_bars), None if prev_length is None else float(prev_length)),
        f'{prefix}_amplitude_vs_prev_ratio': _safe_div(amplitude_pct, prev_amplitude_pct),
    }
    return row


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
                'price_to_zs_center_pct': _safe_pct(
                    None if price is None or center is None else price - center,
                    center,
                ),
            }
    return best or {
        'zs_index': None,
        'zs_distance_bars': None,
        'zs_width_pct': None,
        'price_to_zs_center_pct': None,
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


def _canonical_type(value: Any) -> str:
    text = str(value or '').strip().lower()
    for prefix in ('buy', 'sell'):
        if text.startswith(prefix):
            text = text[len(prefix):]
            break
    if text[:1] in {'b', 's'}:
        text = text[1:]
    return text.strip()


def _is_buy_signal(row: dict[str, Any]) -> bool:
    if 'is_buy' in row:
        return bool(row['is_buy'])
    return str(row.get('type') or '').strip().lower().startswith(('b', 'buy'))


def _signal_raw_index(row: dict[str, Any]) -> int | None:
    return _int(_get(row, 'raw_index', 'rawIndex', 'klu_idx', 'kluIdx'))


def _signal_price(row: dict[str, Any]) -> float | None:
    return _num(_get(row, 'price', 'value'))


def _signal_is_sure(row: dict[str, Any]) -> bool:
    return bool(_get(row, 'is_sure', 'isSure', 'confirmed', default=True))


def _grouped_layer_maps(analysis: dict[str, Any], level: str | None) -> list[dict[Any, Any]]:
    """Return authoritative segN layer maps from exported analysis snapshots.

    Priority mirrors seg-composite backtest: use ``seg_bsp_history_layers`` when
    present, otherwise ``seg_bsp_layers``.  Top-level, per-level, and final-frame
    payloads are all accepted because different callers export slightly different
    analysis shapes.
    """
    candidates: list[dict[str, Any]] = []
    if isinstance(analysis, dict):
        candidates.append(analysis)
    levels = analysis.get('levels') if isinstance(analysis.get('levels'), dict) else {}
    if level and isinstance(levels, dict):
        level_payload = levels.get(level) or levels.get(str(level).upper()) or levels.get(str(level).lower())
        if isinstance(level_payload, dict):
            candidates.append(level_payload)
    frames = analysis.get('frames') if isinstance(analysis.get('frames'), list) else []
    if frames:
        final_frame = frames[-1]
        if isinstance(final_frame, dict):
            candidates.append(final_frame)
            frame_levels = final_frame.get('levels') if isinstance(final_frame.get('levels'), dict) else {}
            if level and isinstance(frame_levels, dict):
                frame_level = frame_levels.get(level) or frame_levels.get(str(level).upper()) or frame_levels.get(str(level).lower())
                if isinstance(frame_level, dict):
                    candidates.append(frame_level)
    grouped: list[dict[Any, Any]] = []
    seen: set[int] = set()
    for payload in candidates:
        for key in ('seg_bsp_history_layers', 'seg_bsp_layers'):
            value = payload.get(key)
            if isinstance(value, dict) and id(value) not in seen:
                grouped.append(value)
                seen.add(id(value))
    return grouped


def _available_layers(grouped_maps: list[dict[Any, Any]]) -> list[int]:
    layers: set[int] = set()
    for grouped in grouped_maps:
        for key in grouped.keys():
            layer = _int(key)
            if layer is not None and layer >= 2:
                layers.add(layer)
    return sorted(layers)


def _layer_rows(grouped_maps: list[dict[Any, Any]], layer: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for grouped in grouped_maps:
        source = grouped.get(str(layer), grouped.get(layer, []))
        if isinstance(source, list):
            rows.extend(row for row in source if isinstance(row, dict))
    return rows


def _latest_layer_signal(rows: list[dict[str, Any]], raw_index: int) -> dict[str, Any] | None:
    available = []
    for row in rows:
        raw = _signal_raw_index(row)
        if raw is None or raw > raw_index:
            continue
        available.append(row)
    if not available:
        return None
    return max(available, key=lambda row: _signal_raw_index(row) or -1)


@register_bsp_feature_extractor('bsp_identity')
def _feature_bsp_identity(ctx: BspFeatureContext, bsp: dict[str, Any], raw_index: int) -> FeatureRow:
    bar = ctx.bars[raw_index]
    close = _close(bar)
    price = _num(_get(bsp, 'price', 'value')) or close
    return {
        'bsp_index': _int(_get(bsp, 'index')),
        'raw_index': raw_index,
        'time': _time(bar),
        'level': str(_get(bsp, 'level', default='bi')),
        'type': _get(bsp, 'type', 'types', default=''),
        'is_buy': bool(_get(bsp, 'is_buy', 'isBuy', default=str(_get(bsp, 'type', '')).upper().startswith('B'))),
        'is_sure': bool(_get(bsp, 'is_sure', 'isSure', 'confirmed', default=True)),
        'price': price,
    }


@register_bsp_feature_extractor('bar_price_volume')
def _feature_bar_price_volume(ctx: BspFeatureContext, bsp: dict[str, Any], raw_index: int) -> FeatureRow:
    bar = ctx.bars[raw_index]
    close = _close(bar)
    open_ = _open(bar)
    high = _high(bar)
    low = _low(bar)
    volume_window = _rolling(ctx.volumes, raw_index, 20)
    return {
        'close': close,
        'bar_body_pct': _safe_pct(None if open_ is None or close is None else close - open_, open_),
        'bar_range_pct': _safe_pct(None if high is None or low is None else high - low, close),
        'volume_ratio_20': None if not volume_window or ctx.volumes[raw_index] is None else _safe_pct(ctx.volumes[raw_index], mean(volume_window)),
    }


@register_bsp_feature_extractor('returns_and_volatility')
def _feature_returns_and_volatility(ctx: BspFeatureContext, bsp: dict[str, Any], raw_index: int) -> FeatureRow:
    close = _close(ctx.bars[raw_index])
    close_window_5 = _rolling(ctx.closes, raw_index, 5)
    row: FeatureRow = {
        'ret_1': _safe_pct(None if raw_index < 1 or close is None or ctx.closes[raw_index - 1] is None else close - ctx.closes[raw_index - 1], ctx.closes[raw_index - 1] if raw_index >= 1 else None),
        'ret_5': _safe_pct(None if raw_index < 5 or close is None or ctx.closes[raw_index - 5] is None else close - ctx.closes[raw_index - 5], ctx.closes[raw_index - 5] if raw_index >= 5 else None),
        'ret_20': _safe_pct(None if raw_index < 20 or close is None or ctx.closes[raw_index - 20] is None else close - ctx.closes[raw_index - 20], ctx.closes[raw_index - 20] if raw_index >= 20 else None),
        'close_std_5_pct': None,
    }
    if len(close_window_5) >= 2 and close is not None:
        avg = mean(close_window_5)
        variance = mean([(x - avg) ** 2 for x in close_window_5])
        row['close_std_5_pct'] = _safe_pct(variance ** 0.5, close)
    return row


@register_bsp_feature_extractor('technical_indicators')
def _feature_technical_indicators(ctx: BspFeatureContext, bsp: dict[str, Any], raw_index: int) -> FeatureRow:
    close = _close(ctx.bars[raw_index])
    close_window_20 = _rolling(ctx.closes, raw_index, 20)
    ma_values = _ma_by_index(ctx.indicators, raw_index)
    ma_20 = ma_values.get('ma_20') or (mean(close_window_20) if len(close_window_20) == 20 else None)
    return {
        'close_to_ma20_pct': _safe_pct(None if close is None or ma_20 is None else close - ma_20, ma_20),
        'macd_dif': _indicator_by_index(ctx.indicators.get('macd'), raw_index, 'dif'),
        'macd_dea': _indicator_by_index(ctx.indicators.get('macd'), raw_index, 'dea'),
        'macd_hist': _indicator_by_index(ctx.indicators.get('macd'), raw_index, 'hist'),
        **ma_values,
    }


@register_bsp_feature_extractor('chan_native_bi_seg_zs')
def _feature_chan_native_context(ctx: BspFeatureContext, bsp: dict[str, Any], raw_index: int) -> FeatureRow:
    price = _num(_get(bsp, 'price', 'value')) or _close(ctx.bars[raw_index])
    is_buy = bool(_get(bsp, 'is_buy', 'isBuy', default=str(_get(bsp, 'type', '')).upper().startswith('B')))
    return {
        **_line_context(ctx.bi_rows, raw_index, 'bi', bars=ctx.bars, price=price, signal_is_buy=is_buy),
        **_line_context(ctx.seg_rows, raw_index, 'seg', bars=ctx.bars, price=price, signal_is_buy=is_buy),
        **_last_zs_distance(ctx.zs_rows, raw_index, price),
    }


@register_bsp_feature_extractor('chan_recursive_segn')
def _feature_chan_recursive_segn(ctx: BspFeatureContext, bsp: dict[str, Any], raw_index: int) -> FeatureRow:
    level = str(_get(bsp, 'level', default='') or '')
    grouped_maps = _grouped_layer_maps(ctx.analysis, level)
    layers = _available_layers(grouped_maps)
    row: FeatureRow = {
        'segn_context_available': bool(layers),
        'segn_context_layer_count': len(layers),
        'segn_same_side_signal_count': 0,
        'segn_opposite_side_signal_count': 0,
        'segn_confirmed_signal_count': 0,
        'segn_nearest_layer': None,
        'segn_nearest_raw_index': None,
        'segn_nearest_age_bars': None,
        'segn_nearest_is_buy': None,
        'segn_nearest_type': None,
        'segn_layers_present': layers,
    }
    bsp_is_buy = bool(_get(bsp, 'is_buy', 'isBuy', default=str(_get(bsp, 'type', '')).upper().startswith('B')))
    nearest: tuple[int, int, dict[str, Any]] | None = None
    for layer in layers:
        signal = _latest_layer_signal(_layer_rows(grouped_maps, layer), raw_index)
        prefix = f'segn_l{layer}'
        if signal is None:
            row.update({
                f'{prefix}_has_signal': False,
                f'{prefix}_raw_index': None,
                f'{prefix}_age_bars': None,
                f'{prefix}_type': None,
                f'{prefix}_canonical_type': None,
                f'{prefix}_is_buy': None,
                f'{prefix}_side': None,
                f'{prefix}_is_sure': None,
                f'{prefix}_price': None,
            })
            continue
        raw = _signal_raw_index(signal)
        age = None if raw is None else raw_index - raw
        is_buy = _is_buy_signal(signal)
        is_sure = _signal_is_sure(signal)
        row.update({
            f'{prefix}_has_signal': True,
            f'{prefix}_raw_index': raw,
            f'{prefix}_age_bars': age,
            f'{prefix}_type': signal.get('type'),
            f'{prefix}_canonical_type': _canonical_type(signal.get('type')),
            f'{prefix}_is_buy': is_buy,
            f'{prefix}_side': 'buy' if is_buy else 'sell',
            f'{prefix}_is_sure': is_sure,
            f'{prefix}_price': _signal_price(signal),
        })
        if is_buy == bsp_is_buy:
            row['segn_same_side_signal_count'] += 1
        else:
            row['segn_opposite_side_signal_count'] += 1
        if is_sure:
            row['segn_confirmed_signal_count'] += 1
        if raw is not None and (nearest is None or raw > nearest[1]):
            nearest = (layer, raw, signal)
    if nearest is not None:
        layer, raw, signal = nearest
        row.update({
            'segn_nearest_layer': layer,
            'segn_nearest_raw_index': raw,
            'segn_nearest_age_bars': raw_index - raw,
            'segn_nearest_is_buy': _is_buy_signal(signal),
            'segn_nearest_type': signal.get('type'),
        })
    return row


@register_bsp_feature_extractor('offline_labels')
def _feature_offline_labels(ctx: BspFeatureContext, bsp: dict[str, Any], raw_index: int) -> FeatureRow:
    if not ctx.include_labels:
        return {}
    is_buy = bool(_get(bsp, 'is_buy', 'isBuy', default=str(_get(bsp, 'type', '')).upper().startswith('B')))
    return _future_label(ctx.bars, raw_index, max(1, ctx.label_horizon), is_buy)


def extract_bsp_features(analysis: dict[str, Any], *, label_horizon: int = 5, include_labels: bool = True) -> dict[str, Any]:
    """Extract non-invasive BSP feature rows from an analysis JSON.

    Feature values are derived from registered pure-read extractors over the
    exported analysis JSON.  chan.py native feature groups keep the original
    BI/SEG/ZS semantics, while recursive segN context reads only authoritative
    ``seg_bsp_history_layers`` / ``seg_bsp_layers`` snapshots and filters rows by
    ``raw_index <= current`` to preserve no-future behavior.
    """
    bars = [row for row in analysis.get('bars', []) if isinstance(row, dict)]
    bsp_rows = [row for row in analysis.get('bsp', []) if isinstance(row, dict)]
    bi_rows = analysis.get('bi', []) if isinstance(analysis.get('bi'), list) else []
    seg_rows = analysis.get('seg', []) if isinstance(analysis.get('seg'), list) else []
    zs_rows = analysis.get('zs', []) if isinstance(analysis.get('zs'), list) else []
    indicators = analysis.get('indicators') if isinstance(analysis.get('indicators'), dict) else {}
    ctx = BspFeatureContext(
        analysis=analysis,
        bars=bars,
        bsp_rows=bsp_rows,
        bi_rows=bi_rows,
        seg_rows=seg_rows,
        zs_rows=zs_rows,
        indicators=indicators,
        closes=[_close(row) for row in bars],
        volumes=[_vol(row) for row in bars],
        label_horizon=label_horizon,
        include_labels=include_labels,
    )

    rows: list[dict[str, Any]] = []
    for bsp in bsp_rows:
        raw_index = _int(_get(bsp, 'raw_index', 'rawIndex', 'klu_idx', 'kluIdx'))
        if raw_index is None or raw_index < 0 or raw_index >= len(bars):
            continue
        row: FeatureRow = {}
        for _, extractor in _FEATURE_REGISTRY:
            row.update(extractor(ctx, bsp, raw_index))
        rows.append(row)

    return {
        'ok': True,
        'features': rows,
        'meta': {
            'source': 'origin_vespa_tdx.backend.a_bsp_feature_engine',
            'bsp_count': len(bsp_rows),
            'feature_count': len(rows),
            'feature_registry': registered_bsp_feature_extractors(),
            'feature_registry_version': 2,
            'native_chan_feature_profile': 'bi_seg_zs_expanded_v2',
            'segn_feature_source': 'seg_bsp_history_layers|seg_bsp_layers',
            'label_horizon': label_horizon if include_labels else None,
            'labels_use_future_data': include_labels,
            'chan_py_polluted': False,
        },
    }
