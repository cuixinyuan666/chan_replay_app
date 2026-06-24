from __future__ import annotations

import math
from typing import Any


def _num(value: Any) -> float | None:
    if isinstance(value, bool) or value is None:
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    if math.isnan(number) or math.isinf(number):
        return None
    return number


def _sigmoid(value: float) -> float:
    if value >= 40:
        return 1.0
    if value <= -40:
        return 0.0
    return 1.0 / (1.0 + math.exp(-value))


def _normalize_feature_rows(features: Any) -> tuple[list[dict[str, Any]], str]:
    """Accept both a raw feature list and the /features API payload shape."""
    source_shape = type(features).__name__
    if isinstance(features, dict):
        source_shape = 'features_payload'
        features = features.get('features', [])
    if not isinstance(features, list):
        return [], source_shape
    return [row for row in features if isinstance(row, dict)], source_shape


def _normalize_model(model: Any, model_name: str | None = None) -> dict[str, Any]:
    if isinstance(model, dict):
        normalized = dict(model)
    else:
        normalized = {'type': 'heuristic_baseline'}
    if model_name and 'name' not in normalized:
        normalized['name'] = model_name
    if not normalized.get('type'):
        normalized['type'] = 'heuristic_baseline'
    return normalized


def _bounded(value: float, lower: float, upper: float) -> float:
    return max(lower, min(upper, value))


def _heuristic_score(row: dict[str, Any]) -> tuple[float, dict[str, float]]:
    contributions: dict[str, float] = {}
    score = 0.0

    if bool(row.get('is_sure')):
        contributions['is_sure'] = 0.12
        score += contributions['is_sure']
    if str(row.get('level', '')).lower().find('seg') >= 0:
        contributions['seg_level'] = 0.10
        score += contributions['seg_level']

    ret_5 = _num(row.get('ret_5'))
    if ret_5 is not None:
        value = _bounded(-ret_5 if row.get('is_buy') else ret_5, -0.15, 0.15)
        contributions['ret_5_reversal'] = value * 1.8
        score += contributions['ret_5_reversal']

    hist = _num(row.get('macd_hist'))
    if hist is not None:
        value = _bounded(hist, -0.2, 0.2)
        contributions['macd_hist'] = value * (1.0 if row.get('is_buy') else -1.0)
        score += contributions['macd_hist']

    close_to_ma20 = _num(row.get('close_to_ma20_pct'))
    if close_to_ma20 is not None:
        value = _bounded(close_to_ma20, -0.2, 0.2)
        contributions['ma20_position'] = (-value if row.get('is_buy') else value) * 0.8
        score += contributions['ma20_position']

    zs_distance = _num(row.get('zs_distance_bars'))
    if zs_distance is not None:
        value = max(0.0, 0.12 - min(zs_distance, 24.0) / 240.0)
        contributions['near_zs'] = value
        score += value

    seg_layer_count = _num(row.get('segn_context_layer_count'))
    if seg_layer_count is not None and seg_layer_count > 0:
        value = min(seg_layer_count, 5.0) * 0.015
        contributions['segn_layer_coverage'] = value
        score += value

    same_side = _num(row.get('segn_same_side_signal_count'))
    opposite_side = _num(row.get('segn_opposite_side_signal_count'))
    if same_side is not None or opposite_side is not None:
        same = same_side or 0.0
        opposite = opposite_side or 0.0
        value = _bounded((same - opposite) * 0.035, -0.14, 0.14)
        contributions['segn_side_alignment'] = value
        score += value

    confirmed = _num(row.get('segn_confirmed_signal_count'))
    if confirmed is not None and confirmed > 0:
        value = min(confirmed, 4.0) * 0.012
        contributions['segn_confirmed_layers'] = value
        score += value

    nearest_age = _num(row.get('segn_nearest_age_bars'))
    nearest_same_side = row.get('segn_nearest_is_buy') == row.get('is_buy')
    if nearest_age is not None:
        freshness = max(0.0, 0.10 - min(nearest_age, 20.0) / 250.0)
        value = freshness if nearest_same_side else -freshness * 0.6
        contributions['segn_nearest_freshness'] = value
        score += value

    probability = _sigmoid(score)
    return probability, contributions


def _linear_score(row: dict[str, Any], model: dict[str, Any]) -> tuple[float, dict[str, float]]:
    intercept = _num(model.get('intercept')) or 0.0
    weights = model.get('weights') if isinstance(model.get('weights'), dict) else {}
    raw_score = intercept
    contributions: dict[str, float] = {'intercept': intercept}
    for key, weight in weights.items():
        value = _num(row.get(str(key)))
        w = _num(weight)
        if value is None or w is None:
            continue
        part = value * w
        raw_score += part
        contributions[str(key)] = part
    return _sigmoid(raw_score), contributions


def _feature_columns(rows: list[dict[str, Any]]) -> list[str]:
    keys: set[str] = set()
    for row in rows:
        keys.update(str(key) for key in row.keys())
    return sorted(keys)


def score_bsp_features(
    features: Any,
    model: dict[str, Any] | None = None,
    *,
    model_name: str | None = None,
) -> dict[str, Any]:
    """Score BSP feature rows with a small pluggable model contract.

    The default mode is a transparent heuristic baseline.  A caller can pass a
    linear model: {"type":"linear", "intercept":0, "weights":{"ret_5":-1}}
    to keep the interface compatible with later external model files without
    importing sklearn/xgboost/lightgbm into the app backend by default.

    Registered feature groups such as chan.py native BI/SEG/ZS context and
    recursive segN context are ordinary feature columns.  The heuristic baseline
    consumes a conservative subset of ``segn_*`` fields, while a linear model can
    use any numeric registered feature via ``weights``.
    """
    rows_in, source_shape = _normalize_feature_rows(features)
    normalized_model = _normalize_model(model, model_name=model_name)
    model_type = str(normalized_model.get('type') or 'heuristic_baseline')
    rows: list[dict[str, Any]] = []
    threshold = float(normalized_model.get('threshold', 0.55))
    for row in rows_in:
        if model_type == 'linear':
            probability, contributions = _linear_score(row, normalized_model)
        else:
            probability, contributions = _heuristic_score(row)
        scored = dict(row)
        scored['ml_score'] = probability
        scored['ml_signal'] = 'accept' if probability >= threshold else 'reject'
        scored['ml_contributions'] = contributions
        rows.append(scored)
    return {
        'ok': True,
        'scores': rows,
        'meta': {
            'source': 'origin_vespa_tdx.backend.a_ml_bridge',
            'model_type': model_type,
            'model_name': normalized_model.get('name'),
            'feature_source_shape': source_shape,
            'count': len(rows),
            'feature_columns': _feature_columns(rows_in),
            'segn_features_supported': True,
            'default_model_is_research_baseline': model_type != 'linear',
            'chan_py_polluted': False,
        },
    }
