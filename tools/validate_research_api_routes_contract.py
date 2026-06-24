#!/usr/bin/env python3
"""Validate research API route contracts against a fixture analysis JSON.

This script intentionally imports ``backend.app.main`` and calls the FastAPI route
functions directly.  It catches route-to-engine signature drift such as passing a
``model_name`` keyword to a scorer that only accepts ``model``, or passing legacy
backtest keywords to an engine that only accepts ``options``.

Usage:
  python tools/validate_research_api_routes_contract.py \
    test/fixtures/research_pipeline_contract_valid.json --require-features
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.app.main import (  # noqa: E402
    research_backtest,
    research_bsp_features,
    research_ml_score,
    research_pipeline,
)


class ContractError(RuntimeError):
    pass


def _assert(condition: bool, message: str) -> None:
    if not condition:
        raise ContractError(message)


def _load_payload(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise ContractError(f'analysis JSON not found: {path}')
    data = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(data, dict):
        raise ContractError('analysis JSON must be an object')
    analysis = data.get('analysis') if isinstance(data.get('analysis'), dict) else data
    if not isinstance(analysis.get('bars'), list):
        raise ContractError('analysis.bars must be a list')
    if not isinstance(analysis.get('bsp'), list):
        raise ContractError('analysis.bsp must be a list; use [] when no BSP exists')
    return {
        'analysis': analysis,
        'label_horizon': 5,
        'include_labels': True,
        'horizon': 5,
        'fee_rate': 0.0005,
        'slippage': 0.0,
        'initial_cash': 100000.0,
        'model': 'logistic_v1',
    }


def _rows(payload: dict[str, Any], key: str) -> list[dict[str, Any]]:
    value = payload.get(key)
    if isinstance(value, dict):
        value = value.get(key)
    if not isinstance(value, list):
        return []
    return [row for row in value if isinstance(row, dict)]


def _assert_clean_meta(payload: dict[str, Any], stage: str) -> None:
    meta = payload.get('meta')
    _assert(isinstance(meta, dict), f'{stage}.meta must be an object')
    _assert(meta.get('chan_py_polluted') is False, f'{stage}.meta.chan_py_polluted must be false')


def validate(path: Path, *, require_features: bool) -> dict[str, Any]:
    payload = _load_payload(path)

    features = research_bsp_features(payload)
    _assert(features.get('ok') is True, 'features route must return ok=true')
    _assert_clean_meta(features, 'features')
    feature_rows = _rows(features, 'features')
    if require_features:
        _assert(feature_rows, 'features route returned no feature rows')

    scores = research_ml_score(payload)
    _assert(scores.get('ok') is True, 'ml score route must return ok=true')
    _assert_clean_meta(scores, 'scores')
    score_rows = _rows(scores, 'scores')
    _assert(len(score_rows) == len(feature_rows), f'score count mismatch: {len(score_rows)} != {len(feature_rows)}')
    for index, row in enumerate(score_rows):
        score = row.get('ml_score')
        _assert(isinstance(score, (int, float)), f'scores[{index}].ml_score must be numeric')
        _assert(0.0 <= float(score) <= 1.0, f'scores[{index}].ml_score out of [0,1]')
        _assert(row.get('ml_signal') in {'accept', 'reject'}, f'scores[{index}].ml_signal invalid')

    backtest = research_backtest(payload)
    _assert(backtest.get('ok') is True, 'backtest route must return ok=true')
    _assert_clean_meta(backtest, 'backtest')
    _assert(backtest['meta'].get('same_bar_lookahead') is False, 'backtest must declare no same-bar lookahead')
    _assert(isinstance(backtest.get('trades'), list), 'backtest.trades must be a list')
    _assert(isinstance(backtest.get('summary'), dict), 'backtest.summary must be an object')

    pipeline = research_pipeline(payload)
    _assert(pipeline.get('ok') is True, 'pipeline route must return ok=true')
    _assert(isinstance(pipeline.get('features'), dict), 'pipeline.features must be a payload object')
    _assert(isinstance(pipeline.get('scores'), dict), 'pipeline.scores must be a payload object')
    _assert(isinstance(pipeline.get('backtest'), dict), 'pipeline.backtest must be a payload object')
    _assert_clean_meta(pipeline['features'], 'pipeline.features')
    _assert_clean_meta(pipeline['scores'], 'pipeline.scores')
    _assert_clean_meta(pipeline['backtest'], 'pipeline.backtest')
    _assert(
        pipeline['backtest']['meta'].get('signal_source') in {
            'analysis_scores_or_features',
            'auto_scored_features',
            'analysis_bsp_fallback',
        },
        'pipeline.backtest.meta.signal_source must be declared',
    )

    return {
        'ok': True,
        'analysis_path': str(path),
        'features': len(feature_rows),
        'scores': len(score_rows),
        'backtest_trades': len(backtest.get('trades', [])),
        'pipeline_trades': len(pipeline['backtest'].get('trades', [])),
        'pipeline_signal_source': pipeline['backtest']['meta'].get('signal_source'),
        'meta': {
            'validator': 'tools/validate_research_api_routes_contract.py',
            'chan_py_polluted': False,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('analysis_json', type=Path)
    parser.add_argument('--require-features', action='store_true')
    args = parser.parse_args()
    try:
        result = validate(args.analysis_json, require_features=args.require_features)
    except Exception as exc:
        print(json.dumps({'ok': False, 'error': str(exc)}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
