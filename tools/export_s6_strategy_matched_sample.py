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
import validate_s6_strategy_signal_sample_coverage as s6  # noqa: E402

DEFAULT_OUTPUT = ROOT / 'test' / 'fixtures' / 'derived' / 's6_strategy_matched_sample_v1.json'
DEFAULT_SYMBOLS = '600340.SH,000001.SZ,000002.SZ,600519.SH,300750.SZ,601318.SH,600036.SH,000858.SZ,002594.SZ'


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


def _build_payload(args: argparse.Namespace, symbol: str, market: str, levels: list[str]) -> tuple[dict[str, Any], dict[str, Any]]:
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
        'mode': 'step',
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


def _run_candidate(args: argparse.Namespace, symbol: str, market: str, levels: list[str]) -> dict[str, Any]:
    payload, config = _build_payload(args, symbol, market, levels)
    result = analyze_multi(
        symbol=symbol,
        market=market,
        levels=levels,
        adjust=args.adjust,
        mode='step',
        main_level=levels[0],
        clock_level=levels[0],
        start=args.start,
        end=args.end,
        count=args.count,
        config=config,
    )
    return _compact_multilevel_step_result(result, payload, config)


def export(args: argparse.Namespace) -> dict[str, Any]:
    started = perf_counter()
    levels = _levels(args.levels)
    attempts: list[dict[str, Any]] = []
    for symbol, market in _parse_symbols(args.symbols):
        attempt_started = perf_counter()
        try:
            result = _run_candidate(args, symbol, market, levels)
            matched = s6._matched_output_candidates(result)
            meta = dict(result.get('meta')) if isinstance(result.get('meta'), dict) else {}
            attempts.append({
                'symbol': f'{symbol}.{market}',
                'ok': bool(result.get('ok', True)),
                'matched_sample_count': len(matched),
                'frames_total': meta.get('frames_total'),
                'frames_returned': meta.get('frames_returned'),
                'compact_validation_status': meta.get('compact_validation_status'),
                'native_cchan_lv_list': meta.get('native_cchan_lv_list'),
                'fallback_to_bridge': meta.get('fallback_to_bridge', False),
                'elapsed_ms': _elapsed_ms(attempt_started),
            })
            if matched:
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
        except Exception as exc:
            attempts.append({'symbol': f'{symbol}.{market}', 'ok': False, 'error': str(exc), 'elapsed_ms': _elapsed_ms(attempt_started)})
    return {'ok': False, 'output': str(args.output), 'attempts': attempts, 'error': 'no matched strategy sample found'}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--symbols', default=DEFAULT_SYMBOLS)
    parser.add_argument('--levels', default='DAILY,MIN30,MIN5')
    parser.add_argument('--adjust', default='QFQ')
    parser.add_argument('--count', type=int, default=260)
    parser.add_argument('--max-step-frames', type=int, default=500)
    parser.add_argument('--max-return-frames', type=int, default=500)
    parser.add_argument('--start', default='2025-01-01')
    parser.add_argument('--end', default='2025-12-31')
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    result = export(args)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result.get('ok') is True else 1


if __name__ == '__main__':
    raise SystemExit(main())
