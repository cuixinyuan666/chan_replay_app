from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.app.a_multilevel_engine_timed import analyze_multi
from backend.app.a_rhythm_overlay import with_multilevel_rhythm_overlay


def main() -> None:
    p = argparse.ArgumentParser(description='Validate that rhythm overlay is applied to a real analyze_multi result.')
    p.add_argument('--symbol', default='000001')
    p.add_argument('--market', default='SZ')
    p.add_argument('--level', default='DAILY')
    p.add_argument('--start', default='2024-01-01')
    p.add_argument('--end', default='2024-12-31')
    p.add_argument('--count', type=int, default=900)
    p.add_argument('--calc-mode', default='transition', choices=['normal', 'transition', 'strict1382'])
    args = p.parse_args()

    level = args.level.strip().upper()
    cfg = {
        'enable_rhythm_1382': True,
        'rhythm_calc_mode': args.calc_mode,
        'recursive_seg_max_level': 4,
    }
    raw = analyze_multi(
        symbol=args.symbol,
        market=args.market,
        levels=[level],
        adjust='QFQ',
        mode='once',
        main_level=level,
        clock_level=level,
        start=args.start,
        end=args.end,
        count=args.count,
        config=cfg,
    )
    if raw.get('ok') is False:
        raise SystemExit(f'analyze_multi failed: {raw.get("error") or raw.get("meta")}')
    patched = with_multilevel_rhythm_overlay(raw, cfg)
    payload = patched.get('levels', {}).get(level, {})
    meta = payload.get('meta', {}) if isinstance(payload, dict) else {}
    lines = payload.get('rhythm_lines') if isinstance(payload.get('rhythm_lines'), list) else []
    hits = payload.get('rhythm_hits') if isinstance(payload.get('rhythm_hits'), list) else []
    if meta.get('rhythm_1382_enabled') is not True:
        raise SystemExit('rhythm_1382_enabled is not True')
    if not meta.get('rhythm_policy'):
        raise SystemExit('rhythm_policy is missing')
    if int(meta.get('rhythm_line_count') or 0) != len(lines):
        raise SystemExit('rhythm_line_count does not match rhythm_lines length')
    if int(meta.get('rhythm_hit_count') or 0) != len(hits):
        raise SystemExit('rhythm_hit_count does not match rhythm_hits length')
    print(f'validate_rhythm_overlay_applied: OK level={level} lines={len(lines)} hits={len(hits)}')


if __name__ == '__main__':
    main()
