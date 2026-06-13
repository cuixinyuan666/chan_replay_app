#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from time import perf_counter
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.app.a_multilevel_engine_timed import analyze_multi  # noqa: E402
from backend.app.main import _compact_multilevel_step_result  # noqa: E402
import validate_s4_cli_strategy_diagnostics as s4  # noqa: E402
import validate_s5_cli_strategy_rule_matrix as s5  # noqa: E402
import validate_s6_strategy_signal_sample_coverage as s6  # noqa: E402

DEFAULT_OUTPUT = ROOT / 'test' / 'fixtures' / 'derived' / 's6_strategy_matched_sample_v1.json'
DEFAULT_SYMBOLS = ','.join([
    '600340.SH', '000001.SZ', '000002.SZ', '600519.SH', '300750.SZ', '601318.SH',
    '600036.SH', '000858.SZ', '002594.SZ', '600000.SH', '600030.SH', '600276.SH',
    '600309.SH', '600438.SH', '600887.SH', '601012.SH', '601166.SH', '601398.SH',
    '601888.SH', '000063.SZ', '000333.SZ', '000568.SZ', '000651.SZ', '000725.SZ',
    '002415.SZ', '002475.SZ', '002714.SZ', '300014.SZ', '300059.SZ', '300760.SZ',
])


def _elapsed_ms(start: float) -> int:
    return int((perf_counter() - start) * 1000)


def _parse_symbols(raw: str) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    for item in raw.replace('，', ',').split(','):
        text = item.strip().upper()
        if not text:
            continue
        if '.' in text:
            symbol, market = text.split('.', 1)
        else:
            symbol = text
            market = 'SH' if symbol.startswith('6') else 'SZ'
        pairs.append((symbol.strip(), market.strip()))
    return pairs


def _levels(raw: str) -> list[str]:
    values = [x.strip().upper() for x in raw.replace('，', ',').split(',') if x.strip()]
    if len(values) < 2:
        raise ValueError('levels requires at least two values')
    return values


def _build_payload(args: argparse.Namespace, symbol: str, market: str, levels: list[str], mode: str) -> tuple[dict[str, Any], dict[str, Any]]:
    config: dict[str, Any] = {
        'bi_algo': 'normal',
        'seg_algo': 'chan',
        'zs_algo': 'normal',
        'max_step_frames': args.max_step_frames,
        'include_bars_in_frames': False,
        'include_indicators_in_frames': False,
        'frame_policy': 'full',
        'frame_stride': 1,
        'max_return_frames': args.max_return_frames,
    }
    payload: dict[str, Any] = {
        'mode': mode,
        'symbol': symbol,
        'market': market,
        'lv_list': levels,
        'adjust': args.adjust,
        'main_level': levels[0],
        'clock_level': levels[0],
        'count': args.count,
        'start': args.start,
        'end': args.end,
        'config': config,
    }
    return payload, config


def _run_candidate(args: argparse.Namespace, symbol: str, market: str, levels: list[str], mode: str) -> dict[str, Any]:
    payload, config = _build_payload(args, symbol, market, levels, mode)
    result = analyze_multi(
        symbol=symbol,
        market=market,
        levels=levels,
        adjust=args.adjust,
        mode=mode,
        main_level=levels[0],
        clock_level=levels[0],
        start=args.start,
        end=args.end,
        count=args.count,
        config=config,
    )
    return _compact_multilevel_step_result(result, payload, config) if mode == 'step' else result


def _level_bsps(result: dict[str, Any], level: str) -> list[dict[str, Any]]:
    levels = result.get('levels')
    if not isinstance(levels, dict):
        return []
    payload = levels.get(level)
    if not isinstance(payload, dict):
        return []
    return s4._bsps(payload)


def _relation_count(result: dict[str, Any]) -> int:
    relations = result.get('relations')
    if not isinstance(relations, list):
        return 0
    return sum(1 for r in relations if isinstance(r, dict) and s4._relation_pair(r) == s5.SELECTED_PAIR)


def _diagnostics(result: dict[str, Any]) -> dict[str, Any]:
    high = _level_bsps(result, s5.PARENT_LEVEL)
    low = _level_bsps(result, s5.CHILD_LEVEL)
    return {
        'root_high_bsp_count': len(high),
        'root_low_bsp_count': len(low),
        'root_high_type_counts': s5._type_counts(high),
        'root_low_type_counts': s5._type_counts(low),
        'root_relation_count_for_pair': _relation_count(result),
        'root_matched_sample_count': len(s6._matched_output_candidates(result)),
    }


def _write_sample(args: argparse.Namespace, symbol: str, market: str, levels: list[str], result: dict[str, Any], matched: list[dict[str, Any]], attempts: list[dict[str, Any]], started: float) -> dict[str, Any]:
    meta = dict(result.get('meta')) if isinstance(result.get('meta'), dict) else {}
    sample = {
        'sample_kind': 's6_strategy_matched_output_metadata_v1',
        'fixture_source': 'tools/export_s6_strategy_matched_sample.py',
        'source_policy': 'original chan.py BSP + native LevelRelation only',
        'backend_entrypoint': 'backend.app.a_multilevel_engine_timed.analyze_multi',
        'chan_calculation_authority': 'backend analyze_multi with original python/chan.py',
        'dart_chan_calculation': False,
        'chan_recalculated': False,
        'request': {
            'symbol': symbol,
            'market': market,
            'levels': levels,
            'adjust': args.adjust,
            'mode': 'step',
            'start': args.start,
            'end': args.end,
            'count': args.count,
            'max_step_frames': args.max_step_frames,
            'max_return_frames': args.max_return_frames,
        },
        'backend_meta': {
            'compact_validation_status': meta.get('compact_validation_status'),
            'compact_validation_mismatch_count': meta.get('compact_validation_mismatch_count'),
            'native_cchan_lv_list': meta.get('native_cchan_lv_list'),
            'fallback_to_bridge': bool(meta.get('fallback_to_bridge') or False),
            'frames_total': meta.get('frames_total'),
            'frames_returned': meta.get('frames_returned'),
        },
        'matched_output_path': {
            'ok': True,
            'matched_sample_count': len(matched),
            'sample': matched[0],
        },
        'attempts': attempts,
        'elapsed_ms': _elapsed_ms(started),
    }
    output: Path = args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(sample, ensure_ascii=False, indent=2), encoding='utf-8')
    return {'ok': True, 'output': str(output), 'matched_sample': matched[0], 'attempts': attempts}


def export(args: argparse.Namespace) -> dict[str, Any]:
    started = perf_counter()
    levels = _levels(args.levels)
    attempts: list[dict[str, Any]] = []
    for symbol, market in _parse_symbols(args.symbols):
        once_started = perf_counter()
        try:
            once = _run_candidate(args, symbol, market, levels, 'once')
            once_diag = _diagnostics(once)
            once_meta = dict(once.get('meta')) if isinstance(once.get('meta'), dict) else {}
            attempts.append({
                'symbol': f'{symbol}.{market}',
                'phase': 'once_prefilter',
                'ok': bool(once.get('ok', True)),
                'native_cchan_lv_list': once_meta.get('native_cchan_lv_list'),
                'fallback_to_bridge': bool(once_meta.get('fallback_to_bridge') or False),
                **once_diag,
                'elapsed_ms': _elapsed_ms(once_started),
            })
            if not args.step_all and once_diag.get('root_matched_sample_count') == 0:
                continue
        except Exception as exc:
            attempts.append({'symbol': f'{symbol}.{market}', 'phase': 'once_prefilter', 'ok': False, 'error': str(exc), 'elapsed_ms': _elapsed_ms(once_started)})
            if not args.step_all:
                continue

        step_started = perf_counter()
        try:
            step = _run_candidate(args, symbol, market, levels, 'step')
            matched = s6._matched_output_candidates(step)
            step_meta = dict(step.get('meta')) if isinstance(step.get('meta'), dict) else {}
            attempts.append({
                'symbol': f'{symbol}.{market}',
                'phase': 'step_confirm',
                'ok': bool(step.get('ok', True)),
                'matched_sample_count': len(matched),
                'frames_total': step_meta.get('frames_total'),
                'frames_returned': step_meta.get('frames_returned'),
                'compact_validation_status': step_meta.get('compact_validation_status'),
                'native_cchan_lv_list': step_meta.get('native_cchan_lv_list'),
                'fallback_to_bridge': bool(step_meta.get('fallback_to_bridge') or False),
                'elapsed_ms': _elapsed_ms(step_started),
            })
            if matched:
                return _write_sample(args, symbol, market, levels, step, matched, attempts, started)
        except Exception as exc:
            attempts.append({'symbol': f'{symbol}.{market}', 'phase': 'step_confirm', 'ok': False, 'error': str(exc), 'elapsed_ms': _elapsed_ms(step_started)})
    return {'ok': False, 'output': str(args.output), 'attempts': attempts, 'error': 'no matched strategy sample found'}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--symbols', default=DEFAULT_SYMBOLS)
    parser.add_argument('--levels', default='DAILY,MIN30,MIN5')
    parser.add_argument('--adjust', default='QFQ')
    parser.add_argument('--count', type=int, default=900)
    parser.add_argument('--max-step-frames', type=int, default=1000)
    parser.add_argument('--max-return-frames', type=int, default=1000)
    parser.add_argument('--start', default='2022-01-01')
    parser.add_argument('--end', default='2025-12-31')
    parser.add_argument('--step-all', action='store_true', help='Run expensive step scan even if once prefilter has no root match')
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    result = export(args)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result.get('ok') is True else 1


if __name__ == '__main__':
    raise SystemExit(main())
