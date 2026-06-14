#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from time import perf_counter
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
TOOLS = ROOT / 'tools'
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import export_s6_strategy_matched_sample as s6_export  # noqa: E402
import validate_s5_cli_strategy_rule_matrix as s5  # noqa: E402
import validate_s6_strategy_signal_sample_coverage as s6  # noqa: E402

DEFAULT_OUTPUT = ROOT / 'test' / 'fixtures' / 'derived' / 's8_strategy_batch_candidates_v1.json'
SOURCE_POLICY = 'original chan.py BSP + native LevelRelation only'
BACKEND_ENTRYPOINT = 'backend.app.a_multilevel_engine_timed.analyze_multi'
SAMPLE_KIND = 's8_strategy_batch_candidates_v1'
_RAW_RE = re.compile(r'(?P<level>[A-Z0-9]+)#(?P<index>[^:;]+):raw=(?P<raw>-?\d+):type=(?P<type>[^;]+)')


def _elapsed_ms(start: float) -> int:
    return int((perf_counter() - start) * 1000)


def _safe_int(value: Any) -> int | None:
    try:
        return int(value)
    except Exception:
        return None


def _parse_bsp_identifiers(text: str) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for match in _RAW_RE.finditer(text or ''):
        result.append({
            'level': match.group('level'),
            'index': match.group('index'),
            'raw_index': _safe_int(match.group('raw')),
            'type': match.group('type'),
        })
    return result


def _jump_target(candidate: dict[str, Any]) -> dict[str, Any]:
    ids = _parse_bsp_identifiers(str(candidate.get('source_bsp_identifiers') or ''))
    low = ids[-1] if ids else {}
    pair = str(candidate.get('source_target_levels') or candidate.get('target_levels') or s5.SELECTED_PAIR)
    low_level = pair.split('->')[-1] if '->' in pair else s5.CHILD_LEVEL
    return {
        'target_level': str(low.get('level') or low_level),
        'raw_index': low.get('raw_index'),
        'source': 'low-level trigger BSP raw index',
    }


def _candidate_record(symbol: str, market: str, phase: str, candidate: dict[str, Any]) -> dict[str, Any]:
    ids = _parse_bsp_identifiers(str(candidate.get('source_bsp_identifiers') or ''))
    return {
        'symbol': symbol,
        'market': market,
        'code': f'{symbol}.{market}',
        'phase': phase,
        'scope': candidate.get('scope'),
        'frame_index': candidate.get('frame_index'),
        'rule_mode_name': candidate.get('rule_mode_name'),
        'source_bsp_identifiers': candidate.get('source_bsp_identifiers'),
        'source_bsp_parsed': ids,
        'source_target_levels': candidate.get('source_target_levels'),
        'native_relation_range': candidate.get('native_relation_range'),
        'strict_step_visibility': candidate.get('strict_step_visibility'),
        'state': candidate.get('state'),
        'jump_target': _jump_target(candidate),
        'candidate_policy': 'candidate signal only; not a trading recommendation',
    }


def _phase_attempt(symbol: str, market: str, phase: str, result: dict[str, Any], elapsed_ms: int) -> dict[str, Any]:
    meta = dict(result.get('meta')) if isinstance(result.get('meta'), dict) else {}
    matched = s6._matched_output_candidates(result)
    return {
        'code': f'{symbol}.{market}',
        'phase': phase,
        'ok': bool(result.get('ok', True)),
        'matched_candidate_count': len(matched),
        'compact_validation_status': meta.get('compact_validation_status'),
        'compact_validation_mismatch_count': meta.get('compact_validation_mismatch_count'),
        'native_cchan_lv_list': meta.get('native_cchan_lv_list'),
        'fallback_to_bridge': bool(meta.get('fallback_to_bridge') or False),
        'frames_total': meta.get('frames_total'),
        'frames_returned': meta.get('frames_returned'),
        'elapsed_ms': elapsed_ms,
    }


def _collect(args: argparse.Namespace) -> dict[str, Any]:
    started = perf_counter()
    levels = s6_export._levels(args.levels)
    symbols = s6_export._parse_symbols(args.symbols)
    attempts: list[dict[str, Any]] = []
    candidates: list[dict[str, Any]] = []

    for symbol, market in symbols:
        if len(candidates) >= args.max_candidates:
            break
        phase_started = perf_counter()
        try:
            once = s6_export._run_candidate(args, symbol, market, levels, 'once')
            attempts.append(_phase_attempt(symbol, market, 'once_prefilter', once, _elapsed_ms(phase_started)))
            once_candidates = s6._matched_output_candidates(once)
            for item in once_candidates:
                candidates.append(_candidate_record(symbol, market, 'once_prefilter', item))
                if len(candidates) >= args.max_candidates:
                    break
            if len(candidates) >= args.max_candidates:
                break
            if not args.step_all and not once_candidates:
                continue
        except Exception as exc:
            attempts.append({
                'code': f'{symbol}.{market}',
                'phase': 'once_prefilter',
                'ok': False,
                'error': str(exc),
                'elapsed_ms': _elapsed_ms(phase_started),
            })
            if not args.step_all:
                continue

        phase_started = perf_counter()
        try:
            step = s6_export._run_candidate(args, symbol, market, levels, 'step')
            attempts.append(_phase_attempt(symbol, market, 'step_confirm', step, _elapsed_ms(phase_started)))
            step_candidates = s6._matched_output_candidates(step)
            for item in step_candidates:
                candidates.append(_candidate_record(symbol, market, 'step_confirm', item))
                if len(candidates) >= args.max_candidates:
                    break
        except Exception as exc:
            attempts.append({
                'code': f'{symbol}.{market}',
                'phase': 'step_confirm',
                'ok': False,
                'error': str(exc),
                'elapsed_ms': _elapsed_ms(phase_started),
            })

    meta = {
        'sample_kind': SAMPLE_KIND,
        'fixture_source': 'tools/export_s8_strategy_batch_candidates.py',
        'source_policy': SOURCE_POLICY,
        'backend_entrypoint': BACKEND_ENTRYPOINT,
        'chan_calculation_authority': 'backend analyze_multi with original python/chan.py',
        'dart_chan_calculation': False,
        'chan_recalculated': False,
        'request': {
            'symbols': [f'{symbol}.{market}' for symbol, market in symbols],
            'levels': levels,
            'adjust': args.adjust,
            'start': args.start,
            'end': args.end,
            'count': args.count,
            'max_step_frames': args.max_step_frames,
            'max_return_frames': args.max_return_frames,
            'max_candidates': args.max_candidates,
            'step_all': args.step_all,
        },
        'summary': {
            'symbol_count': len(symbols),
            'candidate_count': len(candidates),
            'attempt_count': len(attempts),
            'rules_supported': list(s5.RULES),
            'selected_relation_pair': s5.SELECTED_PAIR,
        },
        'attempts': attempts,
        'candidates': candidates,
        'elapsed_ms': _elapsed_ms(started),
    }
    return meta


def export(args: argparse.Namespace) -> dict[str, Any]:
    output: Path = args.output
    data = _collect(args)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    return {
        'ok': bool(data['candidates']),
        'output': str(output),
        'candidate_count': len(data['candidates']),
        'attempt_count': len(data['attempts']),
        'sample': data['candidates'][0] if data['candidates'] else None,
        'action_required_if_not_ok': '' if data['candidates'] else 'Increase --symbols, --count, or use --step-all to find backend-confirmed candidates.',
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--symbols', default=s6_export.DEFAULT_SYMBOLS)
    parser.add_argument('--levels', default='DAILY,MIN30,MIN5')
    parser.add_argument('--adjust', default='QFQ')
    parser.add_argument('--count', type=int, default=900)
    parser.add_argument('--max-step-frames', type=int, default=1000)
    parser.add_argument('--max-return-frames', type=int, default=1000)
    parser.add_argument('--start', default='2022-01-01')
    parser.add_argument('--end', default='2025-12-31')
    parser.add_argument('--max-candidates', type=int, default=20)
    parser.add_argument('--step-all', action='store_true')
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    result = export(args)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result.get('ok') is True else 1


if __name__ == '__main__':
    raise SystemExit(main())
