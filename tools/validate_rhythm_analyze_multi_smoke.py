from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.app.a_multilevel_engine_timed import analyze_multi


_ALLOWED_MAPPING = {
    'fx': 'bi',
    'bi': 'seg',
    'seg': 'segseg',
}


def _finite(value: Any) -> bool:
    try:
        return math.isfinite(float(value))
    except (TypeError, ValueError):
        return False


def _as_levels(value: str) -> list[str]:
    return [part.strip().upper() for part in value.replace('，', ',').split(',') if part.strip()]


def _validate_level(level_name: str, payload: dict[str, Any]) -> dict[str, Any]:
    lines = payload.get('rhythm_lines') if isinstance(payload.get('rhythm_lines'), list) else []
    hits = payload.get('rhythm_hits') if isinstance(payload.get('rhythm_hits'), list) else []
    meta = payload.get('meta') if isinstance(payload.get('meta'), dict) else {}
    line_ids = {str(row.get('id')) for row in lines if isinstance(row, dict)}
    equal_price_threshold = 0
    errors: list[str] = []
    mapping_counts: dict[str, int] = {}

    if int(meta.get('rhythm_line_count') or 0) != len(lines):
        errors.append(f'{level_name}: meta.rhythm_line_count != actual lines')
    if int(meta.get('rhythm_hit_count') or 0) != len(hits):
        errors.append(f'{level_name}: meta.rhythm_hit_count != actual hits')

    for i, line in enumerate(lines):
        if not isinstance(line, dict):
            errors.append(f'{level_name}: rhythm_lines[{i}] is not object')
            continue
        if str(line.get('level') or '').upper() != level_name.upper():
            errors.append(f'{level_name}: line.level must be chart timeframe, got {line.get("level")}')
        source_kind = str(line.get('source_kind') or '')
        parent_level = str(line.get('parent_level') or '')
        expected_parent = _ALLOWED_MAPPING.get(source_kind)
        if expected_parent is None:
            errors.append(f'{level_name}: unexpected source_kind={source_kind!r}')
        elif parent_level != expected_parent:
            errors.append(f'{level_name}: mapping {source_kind}->{parent_level}, expected {source_kind}->{expected_parent}')
        mapping_counts[f'{source_kind}->{parent_level}'] = mapping_counts.get(f'{source_kind}->{parent_level}', 0) + 1
        for key in ('x1', 'x2'):
            if not isinstance(line.get(key), int):
                errors.append(f'{level_name}: line[{i}].{key} must be int')
        for key in ('y1', 'y2', 'price', 'threshold', 'ratio'):
            if not _finite(line.get(key)):
                errors.append(f'{level_name}: line[{i}].{key} must be finite')
        if _finite(line.get('price')) and _finite(line.get('threshold')):
            if math.isclose(float(line['price']), float(line['threshold']), rel_tol=1e-12, abs_tol=1e-12):
                equal_price_threshold += 1

    for i, hit in enumerate(hits):
        if not isinstance(hit, dict):
            errors.append(f'{level_name}: rhythm_hits[{i}] is not object')
            continue
        if str(hit.get('level') or '').upper() != level_name.upper():
            errors.append(f'{level_name}: hit.level must be chart timeframe, got {hit.get("level")}')
        if str(hit.get('line_id')) not in line_ids:
            errors.append(f'{level_name}: hit[{i}].line_id has no matching rhythm line')
        if not isinstance(hit.get('raw_index'), int):
            errors.append(f'{level_name}: hit[{i}].raw_index must be int')
        for key in ('price', 'threshold'):
            if not _finite(hit.get(key)):
                errors.append(f'{level_name}: hit[{i}].{key} must be finite')

    return {
        'level': level_name,
        'bars': len(payload.get('bars') or []),
        'lines': len(lines),
        'hits': len(hits),
        'mapping_counts': mapping_counts,
        'equal_price_threshold': equal_price_threshold,
        'meta_policy': meta.get('rhythm_policy'),
        'errors': errors,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description='Run real analyze_multi rhythm overlay smoke validation.')
    parser.add_argument('--symbol', default='000001')
    parser.add_argument('--market', default='SZ')
    parser.add_argument('--levels', default='DAILY,MIN30,MIN5')
    parser.add_argument('--start', default='2024-01-01')
    parser.add_argument('--end', default='2024-12-31')
    parser.add_argument('--count', type=int, default=900)
    parser.add_argument('--mode', default='once', choices=['once', 'step'])
    parser.add_argument('--main-level', default='DAILY')
    parser.add_argument('--clock-level', default='MIN30')
    parser.add_argument('--calc-mode', default='transition', choices=['normal', 'transition', 'strict1382'])
    parser.add_argument('--require-lines', action='store_true')
    args = parser.parse_args()

    levels = _as_levels(args.levels)
    result = analyze_multi(
        symbol=args.symbol,
        market=args.market,
        levels=levels,
        adjust='QFQ',
        mode=args.mode,
        main_level=args.main_level,
        clock_level=args.clock_level,
        start=args.start,
        end=args.end,
        count=args.count,
        config={
            'enable_rhythm_1382': True,
            'rhythm_calc_mode': args.calc_mode,
            'recursive_seg_max_level': 4,
            # These are intentionally ignored by trainer-parity backend export,
            # but kept here because the Flutter request still sends them.
            'rhythm_max_lines': 160,
            'rhythm_max_hits_per_line': 3,
        },
    )
    if result.get('ok') is False:
        raise RuntimeError(result.get('error') or result)
    levels_payload = result.get('levels')
    if not isinstance(levels_payload, dict):
        raise AssertionError('analyze_multi result has no levels dict')

    summaries = []
    errors: list[str] = []
    for level_name in levels:
        payload = levels_payload.get(level_name)
        if not isinstance(payload, dict):
            errors.append(f'missing level payload: {level_name}')
            continue
        summary = _validate_level(level_name, payload)
        summaries.append(summary)
        errors.extend(summary['errors'])

    total_lines = sum(int(item['lines']) for item in summaries)
    total_hits = sum(int(item['hits']) for item in summaries)
    if args.require_lines and total_lines <= 0:
        errors.append('require-lines was set but no rhythm lines were produced')

    print(json.dumps({
        'symbol': args.symbol,
        'market': args.market,
        'levels': levels,
        'mode': args.mode,
        'calc_mode': args.calc_mode,
        'total_lines': total_lines,
        'total_hits': total_hits,
        'summaries': summaries,
        'top_meta': {
            key: result.get('meta', {}).get(key)
            for key in (
                'rhythm_1382_enabled',
                'rhythm_1382_total_lines',
                'rhythm_1382_total_hits',
                'rhythm_1382_overlay_source',
                'backend_route_rhythm_1382_overlay_ms',
            )
        },
        'errors': errors,
    }, ensure_ascii=False, indent=2))

    if errors:
        raise SystemExit(1)
    print('validate_rhythm_analyze_multi_smoke: OK')


if __name__ == '__main__':
    main()
