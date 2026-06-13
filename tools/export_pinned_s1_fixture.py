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

DEFAULT_OUTPUT = ROOT / 'test' / 'fixtures' / 'pinned' / 's1_600340_SH_DAILY_MIN30_MIN5_2025-09-01_2025-10-20_step_compact_v1.json'


def _levels(raw: str) -> list[str]:
    values = [x.strip().upper() for x in raw.replace('，', ',').split(',') if x.strip()]
    if len(values) < 2:
        raise ValueError('levels requires at least two values')
    return values


def _elapsed_ms(start: float) -> int:
    return int((perf_counter() - start) * 1000)


def export(args: argparse.Namespace) -> dict[str, Any]:
    lv_list = _levels(args.levels)
    config: dict[str, Any] = {
        'bi_algo': 'normal',
        'seg_algo': 'chan',
        'zs_algo': 'normal',
        'max_step_frames': args.max_step_frames,
        'include_bars_in_frames': False,
        'include_indicators_in_frames': False,
        'frame_policy': 'full',
        'frame_stride': 1,
    }
    payload: dict[str, Any] = {
        'mode': 'step',
        'symbol': args.symbol,
        'market': args.market,
        'lv_list': lv_list,
        'adjust': args.adjust,
        'main_level': lv_list[0],
        'clock_level': lv_list[0],
        'count': args.count,
        'start': args.start,
        'end': args.end,
        'config': config,
    }
    start = perf_counter()
    result = analyze_multi(
        symbol=args.symbol,
        market=args.market,
        levels=lv_list,
        adjust=args.adjust,
        mode='step',
        main_level=lv_list[0],
        clock_level=lv_list[0],
        start=args.start,
        end=args.end,
        count=args.count,
        config=config,
    )
    result = _compact_multilevel_step_result(result, payload, config)
    elapsed_ms = _elapsed_ms(start)
    meta = dict(result.get('meta')) if isinstance(result.get('meta'), dict) else {}
    meta.update({
        'fixture': True,
        'fixture_kind': 'pinned_s1_multilevel_step_compact_v1',
        'fixture_source': 'tools/export_pinned_s1_fixture.py',
        'fixture_request': payload,
        'fixture_elapsed_ms': elapsed_ms,
        'sample_data_supervisor_decision': 'accepted_for_this_S1_request',
        'chan_calculation_authority': 'backend analyze_multi with original python/chan.py',
        'dart_chan_calculation': False,
    })
    result['meta'] = meta
    output: Path = args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    return {
        'ok': True,
        'output': str(output),
        'frames_total': meta.get('frames_total'),
        'frames_returned': meta.get('frames_returned'),
        'compact_validation_status': meta.get('compact_validation_status'),
        'compact_validation_mismatch_count': meta.get('compact_validation_mismatch_count'),
        'native_cchan_lv_list': meta.get('native_cchan_lv_list'),
        'fallback_to_bridge': meta.get('fallback_to_bridge', False),
        'elapsed_ms': elapsed_ms,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--symbol', default='600340')
    parser.add_argument('--market', default='SH')
    parser.add_argument('--levels', default='DAILY,MIN30,MIN5')
    parser.add_argument('--adjust', default='QFQ')
    parser.add_argument('--count', type=int, default=220)
    parser.add_argument('--max-step-frames', type=int, default=60)
    parser.add_argument('--start', default='2025-09-01')
    parser.add_argument('--end', default='2025-10-20')
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    try:
        result = export(args)
    except Exception as exc:
        print(json.dumps({'ok': False, 'error': str(exc)}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
