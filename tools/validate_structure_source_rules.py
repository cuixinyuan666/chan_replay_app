#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / 'tools'
for path in (ROOT, TOOLS):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from validate_research_other_target_flow import (  # noqa: E402
    DEFAULT_BASE_URL,
    DEFAULT_END,
    DEFAULT_LEVEL,
    DEFAULT_MARKET,
    DEFAULT_START,
    DEFAULT_SYMBOL,
    _assert_ok,
    _base_payload,
    _json_post,
)

_PRESETS: dict[str, dict[str, Any]] = {
    'origin_bsp_any_buy': {
        'label': '原级别真实BSP：任意买点',
        'signal_source': 'real_bsp',
        'entry_rule': {
            'conditions': [
                {
                    'source': 'origin_bsp',
                    'layer': 2,
                    'side': 'buy',
                    'types': ['1', '1p', '2', '2s', '3a', '3b'],
                },
            ],
            'dedupe': True,
        },
        'exit_rule': {
            'conditions': [
                {'source': 'origin_bsp', 'layer': 2, 'side': 'sell', 'types': []},
            ],
            'dedupe': True,
        },
    },
    'bi_endpoint_buy': {
        'label': '非真实BSP：笔下跌终点候选',
        'signal_source': 'endpoint_candidate',
        'entry_rule': {
            'conditions': [
                {'source': 'bi_endpoint_candidate', 'layer': 2, 'side': 'buy', 'types': []},
            ],
            'dedupe': True,
        },
        'exit_rule': {
            'conditions': [
                {'source': 'bi_endpoint_candidate', 'layer': 2, 'side': 'sell', 'types': []},
            ],
            'dedupe': True,
        },
    },
    'seg_endpoint_buy': {
        'label': '非真实BSP：线段下跌终点候选',
        'signal_source': 'endpoint_candidate',
        'entry_rule': {
            'conditions': [
                {'source': 'seg_endpoint_candidate', 'layer': 2, 'side': 'buy', 'types': []},
            ],
            'dedupe': True,
        },
        'exit_rule': {
            'conditions': [
                {'source': 'seg_endpoint_candidate', 'layer': 2, 'side': 'sell', 'types': []},
            ],
            'dedupe': True,
        },
    },
    'recursive_seg2_endpoint_buy': {
        'label': '非真实BSP：2层递归段下跌终点候选',
        'signal_source': 'endpoint_candidate',
        'entry_rule': {
            'conditions': [
                {'source': 'recursive_seg_endpoint_candidate', 'layer': 2, 'side': 'buy', 'types': []},
            ],
            'dedupe': True,
        },
        'exit_rule': {
            'conditions': [
                {'source': 'recursive_seg_endpoint_candidate', 'layer': 2, 'side': 'sell', 'types': []},
            ],
            'dedupe': True,
        },
    },
}

_REQUIRED_SOURCE_COUNT_KEYS = (
    'origin_bsp',
    'bi_endpoint_candidate',
    'seg_endpoint_candidate',
    'recursive_seg_2',
)


def _length(value: Any) -> int:
    return len(value) if isinstance(value, list) else 0


def _seg_payload(args: argparse.Namespace, preset_key: str) -> dict[str, Any]:
    preset = _PRESETS[preset_key]
    payload = _base_payload(args)
    payload.update({
        'entry_rule': preset['entry_rule'],
        'exit_rule': preset['exit_rule'],
        'options': {
            'max_hold_days': args.horizon,
            'fee_bps': 3,
            'slippage_bps': 2,
            'signal_source': preset['signal_source'],
            'collect_structure_source_counts': True,
        },
        'preset': preset_key,
        'preset_label': preset['label'],
    })
    return payload


def _row_from_result(key: str, result: dict[str, Any]) -> dict[str, Any]:
    preset = _PRESETS[key]
    meta = result.get('meta') if isinstance(result.get('meta'), dict) else {}
    summary = result.get('summary') if isinstance(result.get('summary'), dict) else {}
    source_counts = meta.get('structure_source_counts') if isinstance(meta.get('structure_source_counts'), dict) else {}
    return {
        'preset': key,
        'label': preset['label'],
        'signal_source': preset['signal_source'],
        'entry_events': _length(result.get('entry_events')),
        'exit_events': _length(result.get('exit_events')),
        'trades': _length(result.get('trades')),
        'evaluated_step_frames': meta.get('evaluated_step_frames'),
        'effective_signal_source': meta.get('seg_composite_signal_source'),
        'structure_source_counts': source_counts,
        'trade_count': summary.get('trade_count'),
        'win_rate': summary.get('win_rate'),
        'total_return': summary.get('total_return'),
        'profit_factor': summary.get('profit_factor'),
    }


def _validate_source_counts(row: dict[str, Any]) -> None:
    counts = row.get('structure_source_counts')
    if not isinstance(counts, dict):
        raise RuntimeError(f'missing structure_source_counts in smoke result: {row}')
    missing = [key for key in _REQUIRED_SOURCE_COUNT_KEYS if int(counts.get(key) or 0) <= 0]
    if missing:
        raise RuntimeError(f'structure_source_counts missing positive sources {missing}: {counts}')


def validate(args: argparse.Namespace) -> dict[str, Any]:
    if args.exhaustive:
        preset_keys = list(_PRESETS)
    else:
        # One full-window request is enough for CI: the backend reports all
        # source counts only because this validator explicitly requests them.
        preset_keys = ['recursive_seg2_endpoint_buy']

    rows: list[dict[str, Any]] = []
    for key in preset_keys:
        result = _json_post(
            args.base_url,
            '/api/research/seg-composite/backtest',
            _seg_payload(args, key),
            timeout=args.timeout,
        ).payload
        _assert_ok(f'structure-source preset {key}', result)
        row = _row_from_result(key, result)
        rows.append(row)
        if int(row['entry_events'] or 0) <= 0:
            raise RuntimeError(f'structure source smoke preset generated no entry_events: {row}')
        _validate_source_counts(row)

    return {
        'ok': True,
        'base_url': args.base_url,
        'symbol': args.symbol,
        'market': args.market.upper(),
        'level': args.level.upper(),
        'mode': 'exhaustive' if args.exhaustive else 'smoke',
        'results': rows,
        'meta': {
            'validator': 'tools/validate_structure_source_rules.py',
            'preset_count': len(rows),
            'validated_source_count_keys': list(_REQUIRED_SOURCE_COUNT_KEYS),
            'rule_policy': 'condition.source selects origin BSP, bi endpoint, seg endpoint, or recursive seg endpoint sources',
            'chan_py_polluted': False,
        },
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--base-url', default=DEFAULT_BASE_URL)
    parser.add_argument('--symbol', default=DEFAULT_SYMBOL)
    parser.add_argument('--market', default=DEFAULT_MARKET)
    parser.add_argument('--level', default=DEFAULT_LEVEL)
    parser.add_argument('--start', default=DEFAULT_START)
    parser.add_argument('--end', default=DEFAULT_END)
    parser.add_argument('--count', type=int, default=50000)
    parser.add_argument('--adjust', default='QFQ')
    parser.add_argument('--horizon', type=int, default=10)
    parser.add_argument('--timeout', type=int, default=300)
    parser.add_argument('--bi-algo', default='fx')
    parser.add_argument('--seg-algo', default='chan')
    parser.add_argument('--zs-algo', default='normal')
    parser.add_argument('--recursive-seg-max-level', type=int, default=4)
    parser.add_argument('--exhaustive', action='store_true')
    args = parser.parse_args(argv)
    try:
        print(json.dumps(validate(args), ensure_ascii=False, indent=2))
        return 0
    except Exception as exc:
        print(json.dumps({'ok': False, 'error': str(exc)}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
