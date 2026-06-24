#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from typing import Any

REQUIRED = {
    'bi_start_raw_index', 'bi_end_raw_index', 'bi_high', 'bi_low',
    'bi_length_bars', 'bi_amplitude_pct', 'bi_progress_ratio',
    'bi_slope_pct_per_bar', 'bi_same_direction_as_bsp',
    'seg_start_raw_index', 'seg_end_raw_index', 'seg_high', 'seg_low',
    'seg_length_bars', 'seg_amplitude_pct', 'seg_progress_ratio',
    'seg_slope_pct_per_bar', 'seg_same_direction_as_bsp',
}


def post(base: str, endpoint: str, payload: dict[str, Any], timeout: int) -> dict[str, Any]:
    req = urllib.request.Request(
        base.rstrip('/') + endpoint,
        data=json.dumps(payload, ensure_ascii=False).encode('utf-8'),
        headers={'content-type': 'application/json'},
        method='POST',
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as res:
            data = json.loads(res.read().decode('utf-8'))
            if not isinstance(data, dict):
                raise RuntimeError(f'{endpoint} did not return a JSON object')
            return data
    except urllib.error.HTTPError as exc:
        body = exc.read().decode('utf-8', errors='replace')
        raise RuntimeError(f'{endpoint} HTTP {exc.code}: {body}') from exc


def level_payload(levels: Any, level: str) -> dict[str, Any]:
    if not isinstance(levels, dict):
        raise RuntimeError('analyze_multi response missing levels')
    for key in (level, level.upper(), level.lower()):
        value = levels.get(key)
        if isinstance(value, dict):
            return dict(value)
    for key, value in levels.items():
        if str(key).strip().upper() == level.upper() and isinstance(value, dict):
            return dict(value)
    raise RuntimeError(f'analyze_multi response missing {level}')


def normalize_analysis(raw: dict[str, Any], args: argparse.Namespace) -> dict[str, Any]:
    analysis = dict(raw)
    meta = dict(analysis.get('meta')) if isinstance(analysis.get('meta'), dict) else {}
    level = args.level.upper()
    meta.update({
        'symbol': args.symbol,
        'market': args.market.upper(),
        'freq': level,
        'period': level,
        'adjust': args.adjust,
        'main_level': level,
        'levels': [level],
        'source': 'tools.validate_research_native_feature_columns',
        'chan_py_polluted': False,
    })
    analysis['meta'] = meta
    analysis['symbol'] = args.symbol
    analysis['market'] = args.market.upper()
    analysis['freq'] = level
    analysis['period'] = level
    analysis['adjust'] = args.adjust
    if not isinstance(analysis.get('bsp'), list) and isinstance(analysis.get('bsps'), list):
        analysis['bsp'] = analysis['bsps']
    if analysis.get('seg_bsp_history_layers') is None and analysis.get('seg_bsp_layers') is not None:
        analysis['seg_bsp_history_layers'] = analysis['seg_bsp_layers']
    return analysis


def rows(payload: dict[str, Any], key: str) -> list[dict[str, Any]]:
    value = payload.get(key)
    if isinstance(value, dict):
        value = value.get(key)
    return [row for row in value if isinstance(row, dict)] if isinstance(value, list) else []


def columns(row_list: list[dict[str, Any]]) -> set[str]:
    result: set[str] = set()
    for row in row_list:
        result.update(str(key) for key in row.keys())
    return result


def validate(args: argparse.Namespace) -> dict[str, Any]:
    base_payload = {
        'symbol': args.symbol,
        'market': args.market.upper(),
        'levels': [args.level.upper()],
        'level': args.level.upper(),
        'main_level': args.level.upper(),
        'clock_level': args.level.upper(),
        'adjust': args.adjust,
        'start': args.start,
        'end': args.end,
        'count': args.count,
        'mode': 'once',
        'config': {
            'bi_algo': 'fx',
            'seg_algo': 'chan',
            'zs_algo': 'normal',
            'recursive_seg_max_level': 4,
        },
    }
    analyze = post(args.base_url, '/api/chan/analyze_multi', base_payload, args.timeout)
    if analyze.get('ok') is False:
        raise RuntimeError(f'analyze_multi failed: {analyze.get("error")}')
    analysis = normalize_analysis(level_payload(analyze.get('levels'), args.level), args)
    features = post(args.base_url, '/api/research/bsp/features', {'analysis': analysis}, args.timeout)
    if features.get('ok') is False:
        raise RuntimeError(f'features failed: {features.get("error")}')
    feature_rows = rows(features, 'features')
    if not feature_rows:
        raise RuntimeError('features returned no rows')
    meta = features.get('meta') if isinstance(features.get('meta'), dict) else {}
    if meta.get('feature_registry_version') != 2:
        raise RuntimeError(f'feature_registry_version must be 2: {meta}')
    if meta.get('native_chan_feature_profile') != 'bi_seg_zs_expanded_v2':
        raise RuntimeError(f'native_chan_feature_profile invalid: {meta}')
    missing = sorted(REQUIRED - columns(feature_rows))
    if missing:
        raise RuntimeError(f'missing native columns: {missing}')
    scores = post(args.base_url, '/api/research/ml/score', {'analysis': analysis}, args.timeout)
    score_meta = scores.get('meta') if isinstance(scores.get('meta'), dict) else {}
    if score_meta.get('native_chan_features_supported') is not True:
        raise RuntimeError(f'native_chan_features_supported invalid: {score_meta}')
    return {
        'ok': True,
        'feature_rows': len(feature_rows),
        'required_native_columns': sorted(REQUIRED),
        'feature_registry_version': meta.get('feature_registry_version'),
        'native_chan_feature_profile': meta.get('native_chan_feature_profile'),
        'native_chan_features_supported': score_meta.get('native_chan_features_supported'),
        'sample': {key: feature_rows[0].get(key) for key in sorted(REQUIRED)},
        'meta': {'validator': 'tools/validate_research_native_feature_columns.py', 'chan_py_polluted': False},
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--base-url', default='http://127.0.0.1:8000')
    parser.add_argument('--symbol', default='600340')
    parser.add_argument('--market', default='SH')
    parser.add_argument('--level', default='MIN5')
    parser.add_argument('--start', default='2025-09-01')
    parser.add_argument('--end', default='2026-06-18')
    parser.add_argument('--count', type=int, default=50000)
    parser.add_argument('--adjust', default='QFQ')
    parser.add_argument('--timeout', type=int, default=300)
    args = parser.parse_args(argv)
    try:
        print(json.dumps(validate(args), ensure_ascii=False, indent=2))
        return 0
    except Exception as exc:
        print(json.dumps({'ok': False, 'error': str(exc)}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
