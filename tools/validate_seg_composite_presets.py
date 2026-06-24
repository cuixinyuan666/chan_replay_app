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
    'strict_nest': {
        'label': '真实BSP：严格区间套：2段B1 AND 3段B3a',
        'signal_source': 'real_bsp',
        'entry_rule': {
            'conditions': [
                {'layer': 2, 'side': 'buy', 'types': ['1']},
                {'layer': 3, 'side': 'buy', 'types': ['3a']},
            ],
            'dedupe': True,
        },
    },
    'layer2_b1': {
        'label': '真实BSP：只测2段B1',
        'signal_source': 'real_bsp',
        'entry_rule': {
            'conditions': [
                {'layer': 2, 'side': 'buy', 'types': ['1']},
            ],
            'dedupe': True,
        },
    },
    'layer2_any_buy': {
        'label': '真实BSP：只测2段任意买点',
        'signal_source': 'real_bsp',
        'entry_rule': {
            'conditions': [
                {'layer': 2, 'side': 'buy', 'types': ['1', '2', '3a', '3b']},
            ],
            'dedupe': True,
        },
    },
    'layer3_any_buy': {
        'label': '真实BSP：只测3段任意买点',
        'signal_source': 'real_bsp',
        'entry_rule': {
            'conditions': [
                {'layer': 3, 'side': 'buy', 'types': ['1', '2', '3a', '3b']},
            ],
            'dedupe': True,
        },
    },
    'endpoint_layer2_buy': {
        'label': '候选：2段向下段结束买点',
        'signal_source': 'endpoint_candidate',
        'entry_rule': {
            'conditions': [
                {'layer': 2, 'side': 'buy', 'types': []},
            ],
            'dedupe': True,
        },
    },
    'endpoint_layer3_buy': {
        'label': '候选：3段向下段结束买点',
        'signal_source': 'endpoint_candidate',
        'entry_rule': {
            'conditions': [
                {'layer': 3, 'side': 'buy', 'types': []},
            ],
            'dedupe': True,
        },
    },
}


def _seg_payload(args: argparse.Namespace, preset_key: str) -> dict[str, Any]:
    preset = _PRESETS[preset_key]
    signal_source = str(preset.get('signal_source') or 'real_bsp')
    payload = _base_payload(args)
    payload.update({
        'entry_rule': preset['entry_rule'],
        'exit_rule': {
            'conditions': [
                {'layer': 2, 'side': 'sell', 'types': [] if signal_source == 'endpoint_candidate' else ['1']},
            ],
            'dedupe': True,
        },
        'options': {
            'max_hold_days': args.horizon,
            'fee_bps': 3,
            'slippage_bps': 2,
            'signal_source': signal_source,
        },
        'preset': preset_key,
        'preset_label': preset['label'],
    })
    return payload


def _length(value: Any) -> int:
    return len(value) if isinstance(value, list) else 0


def validate(args: argparse.Namespace) -> dict[str, Any]:
    preset_keys = list(_PRESETS) if args.preset == 'all' else [args.preset]
    rows: list[dict[str, Any]] = []
    for key in preset_keys:
        if key not in _PRESETS:
            raise RuntimeError(f'unknown preset: {key}; available={list(_PRESETS)}')
        result = _json_post(
            args.base_url,
            '/api/research/seg-composite/backtest',
            _seg_payload(args, key),
            timeout=args.timeout,
        ).payload
        _assert_ok(f'seg-composite preset {key}', result)
        meta = result.get('meta') if isinstance(result.get('meta'), dict) else {}
        summary = result.get('summary') if isinstance(result.get('summary'), dict) else {}
        rows.append({
            'preset': key,
            'label': _PRESETS[key]['label'],
            'signal_source': _PRESETS[key].get('signal_source'),
            'entry_events': _length(result.get('entry_events')),
            'exit_events': _length(result.get('exit_events')),
            'trades': _length(result.get('trades')),
            'evaluated_step_frames': meta.get('evaluated_step_frames'),
            'effective_signal_source': meta.get('seg_composite_signal_source'),
            'trade_count': summary.get('trade_count'),
            'win_rate': summary.get('win_rate'),
            'total_return': summary.get('total_return'),
            'profit_factor': summary.get('profit_factor'),
        })
    real_bsp_signal_found = any(
        row['signal_source'] == 'real_bsp' and int(row['entry_events'] or 0) > 0
        for row in rows
    )
    endpoint_candidate_signal_found = any(
        row['signal_source'] == 'endpoint_candidate' and int(row['entry_events'] or 0) > 0
        for row in rows
    )
    if args.require_loose_signal and not (real_bsp_signal_found or endpoint_candidate_signal_found):
        raise RuntimeError(f'no real-BSP or endpoint-candidate preset generated entry_events: {rows}')
    return {
        'ok': True,
        'base_url': args.base_url,
        'symbol': args.symbol,
        'market': args.market.upper(),
        'level': args.level.upper(),
        'preset': args.preset,
        'results': rows,
        'real_bsp_signal_found': real_bsp_signal_found,
        'endpoint_candidate_signal_found': endpoint_candidate_signal_found,
        'loose_signal_found': real_bsp_signal_found or endpoint_candidate_signal_found,
        'meta': {
            'validator': 'tools/validate_seg_composite_presets.py',
            'preset_count': len(rows),
            'candidate_policy': 'endpoint_candidate presets are segment-end candidates, not real chan.py CBSPointList BSP',
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
    parser.add_argument('--preset', default='all', choices=['all', *_PRESETS.keys()])
    parser.add_argument('--require-loose-signal', action='store_true')
    args = parser.parse_args(argv)
    try:
        print(json.dumps(validate(args), ensure_ascii=False, indent=2))
        return 0
    except Exception as exc:
        print(json.dumps({'ok': False, 'error': str(exc)}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
