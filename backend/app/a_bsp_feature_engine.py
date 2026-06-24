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
    return {
        **_line_context(ctx.bi_rows, raw_index, 'bi'),
        **_line_context(ctx.seg_rows, raw_index, 'seg'),
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
            'feature_registry_version': 1,
            'segn_feature_source': 'seg_bsp_history_layers|seg_bsp_layers',
            'label_horizon': label_horizon if include_labels else None,
            'labels_use_future_data': include_labels,
            'chan_py_polluted': False,
        },
    }
