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
        value = max(-0.15, min(0.15, -ret_5 if row.get('is_buy') else ret_5))
        contributions['ret_5_reversal'] = value * 1.8
        score += contributions['ret_5_reversal']

    hist = _num(row.get('macd_hist'))
    if hist is not None:
        value = max(-0.2, min(0.2, hist))
        contributions['macd_hist'] = value * (1.0 if row.get('is_buy') else -1.0)
        score += contributions['macd_hist']

    close_to_ma20 = _num(row.get('close_to_ma20_pct'))
    if close_to_ma20 is not None:
        value = max(-0.2, min(0.2, close_to_ma20))
        contributions['ma20_position'] = (-value if row.get('is_buy') else value) * 0.8
        score += contributions['ma20_position']

    zs_distance = _num(row.get('zs_distance_bars'))
    if zs_distance is not None:
        value = max(0.0, 0.12 - min(zs_distance, 24.0) / 240.0)
        contributions['near_zs'] = value
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


def score_bsp_features(features: list[dict[str, Any]], model: dict[str, Any] | None = None) -> dict[str, Any]:
    """Score BSP feature rows with a small pluggable model contract.

    The default mode is a transparent heuristic baseline.  A caller can pass a
    linear model: {"type":"linear", "intercept":0, "weights":{"ret_5":-1}}
    to keep the interface compatible with later external model files without
    importing sklearn/xgboost/lightgbm into the app backend by default.
    """
    model = model or {'type': 'heuristic_baseline'}
    model_type = str(model.get('type') or 'heuristic_baseline')
    rows: list[dict[str, Any]] = []
    for row in features:
        if not isinstance(row, dict):
            continue
        if model_type == 'linear':
            probability, contributions = _linear_score(row, model)
        else:
            probability, contributions = _heuristic_score(row)
        scored = dict(row)
        scored['ml_score'] = probability
        scored['ml_signal'] = 'accept' if probability >= float(model.get('threshold', 0.55)) else 'reject'
        scored['ml_contributions'] = contributions
        rows.append(scored)
    return {
        'ok': True,
        'scores': rows,
        'meta': {
            'source': 'origin_vespa_tdx.backend.a_ml_bridge',
            'model_type': model_type,
            'count': len(rows),
            'default_model_is_research_baseline': model_type != 'linear',
            'chan_py_polluted': False,
        },
    }
