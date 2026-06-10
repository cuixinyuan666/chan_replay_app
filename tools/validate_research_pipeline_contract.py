#!/usr/bin/env python3
"""Validate the non-invasive research pipeline contract.

This script runs the local BSP feature extractor, ML scoring bridge, and BSP
backtest engine against an exported chan.py analysis JSON.  It does not import or
modify chan.py; it only consumes the JSON contract that Flutter and the backend
already exchange.

Usage:
  python tools/validate_research_pipeline_contract.py test/fixtures/research_pipeline_contract_valid.json --require-features
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

from backend.app.a_backtest_engine import run_bsp_backtest  # noqa: E402
from backend.app.a_bsp_feature_engine import extract_bsp_features  # noqa: E402
from backend.app.a_ml_bridge import score_bsp_features  # noqa: E402


class ContractError(RuntimeError):
    pass


def _load_analysis(path: Path) -> dict[str, Any]:
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
    return analysis


def _assert(condition: bool, message: str) -> None:
    if not condition:
        raise ContractError(message)


def _assert_meta_clean(payload: dict[str, Any], stage: str) -> None:
    meta = payload.get('meta')
    _assert(isinstance(meta, dict), f'{stage}.meta must be an object')
    _assert(meta.get('chan_py_polluted') is False, f'{stage}.meta.chan_py_polluted must be false')


def _validate_features(payload: dict[str, Any], *, require_features: bool) -> list[dict[str, Any]]:
    _assert(payload.get('ok') is True, 'features.ok must be true')
    _assert_meta_clean(payload, 'features')
    rows = payload.get('features')
    _assert(isinstance(rows, list), 'features.features must be a list')
    if require_features:
        _assert(len(rows) > 0, 'features must not be empty when --require-features is set')
    required = {'raw_index', 'time', 'level', 'type', 'is_buy', 'is_sure', 'price', 'close'}
    for i, row in enumerate(rows):
        _assert(isinstance(row, dict), f'features[{i}] must be an object')
        missing = sorted(required - set(row))
        _assert(not missing, f'features[{i}] missing keys: {missing}')
        if row.get('future_return') is not None:
            _assert('label_horizon' in row and 'label_win' in row, f'features[{i}] label fields incomplete')
    return rows


def _validate_scores(payload: dict[str, Any], expected_count: int) -> list[dict[str, Any]]:
    _assert(payload.get('ok') is True, 'scores.ok must be true')
    _assert_meta_clean(payload, 'scores')
    rows = payload.get('scores')
    _assert(isinstance(rows, list), 'scores.scores must be a list')
    _assert(len(rows) == expected_count, f'scores count mismatch: {len(rows)} != {expected_count}')
    for i, row in enumerate(rows):
        score = row.get('ml_score')
        _assert(isinstance(score, (int, float)), f'scores[{i}].ml_score must be numeric')
        _assert(0.0 <= float(score) <= 1.0, f'scores[{i}].ml_score out of [0,1]')
        _assert(row.get('ml_signal') in {'accept', 'reject'}, f'scores[{i}].ml_signal invalid')
        _assert(isinstance(row.get('ml_contributions'), dict), f'scores[{i}].ml_contributions must be object')
    return rows


def _validate_backtest(payload: dict[str, Any]) -> None:
    _assert(payload.get('ok') is True, 'backtest.ok must be true')
    _assert_meta_clean(payload, 'backtest')
    _assert(payload['meta'].get('same_bar_lookahead') is False, 'backtest must declare no same-bar lookahead')
    _assert(isinstance(payload.get('trades'), list), 'backtest.trades must be a list')
    summary = payload.get('summary')
    _assert(isinstance(summary, dict), 'backtest.summary must be an object')
    for key in ('trade_count', 'win_count', 'loss_count', 'total_return', 'final_equity'):
        _assert(key in summary, f'backtest.summary missing {key}')


def validate(path: Path, *, label_horizon: int, require_features: bool, write_output: Path | None) -> dict[str, Any]:
    analysis = _load_analysis(path)
    features_payload = extract_bsp_features(analysis, label_horizon=label_horizon, include_labels=True)
    features = _validate_features(features_payload, require_features=require_features)

    scores_payload = score_bsp_features(features)
    scores = _validate_scores(scores_payload, len(features))

    backtest_input = dict(analysis)
    backtest_input['features'] = features
    backtest_input['scores'] = scores
    backtest_payload = run_bsp_backtest(backtest_input)
    _validate_backtest(backtest_payload)

    result = {
        'ok': True,
        'analysis_path': str(path),
        'bars': len(analysis.get('bars', [])),
        'bsp': len(analysis.get('bsp', [])),
        'features': len(features),
        'scores': len(scores),
        'trades': len(backtest_payload.get('trades', [])),
        'summary': backtest_payload.get('summary', {}),
        'meta': {
            'validator': 'tools/validate_research_pipeline_contract.py',
            'chan_py_polluted': False,
            'labels_are_offline_only': True,
        },
    }
    if write_output is not None:
        write_output.parent.mkdir(parents=True, exist_ok=True)
        write_output.write_text(json.dumps({
            'features': features_payload,
            'scores': scores_payload,
            'backtest': backtest_payload,
            'validator': result,
        }, ensure_ascii=False, indent=2), encoding='utf-8')
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('analysis_json', type=Path)
    parser.add_argument('--label-horizon', type=int, default=5)
    parser.add_argument('--require-features', action='store_true')
    parser.add_argument('--write-output', type=Path)
    args = parser.parse_args()

    try:
        result = validate(
            args.analysis_json,
            label_horizon=max(1, args.label_horizon),
            require_features=args.require_features,
            write_output=args.write_output,
        )
    except Exception as exc:
        print(json.dumps({'ok': False, 'error': str(exc)}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
