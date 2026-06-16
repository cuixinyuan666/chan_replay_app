from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


def contains(path: str, needles: list[str]) -> dict[str, bool]:
    text = read(path)
    return {needle: needle in text for needle in needles}


def functional_rhythm_sample() -> dict[str, bool | str | int | float]:
    module_path = ROOT / 'backend/app/a_rhythm_overlay.py'
    spec = importlib.util.spec_from_file_location('a_rhythm_overlay_validate', module_path)
    if spec is None or spec.loader is None:
        return {'ok': False, 'error': 'cannot load a_rhythm_overlay.py'}
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)

    bars = [
        {'dt': '2024-01-01', 'high': 0.5, 'low': 0.0},
        {'dt': '2024-01-02', 'high': 4.0, 'low': 3.6},
        {'dt': '2024-01-03', 'high': 2.4, 'low': 2.0},
        {'dt': '2024-01-04', 'high': 5.1, 'low': 4.8},
        {'dt': '2024-01-05', 'high': 3.4, 'low': 3.0},
        {'dt': '2024-01-06', 'high': 6.0, 'low': 5.7},
    ]
    payload = {
        'bars': bars,
        'fx': [
            {'index': 0, 'raw_index': 0, 'type': 'BOTTOM', 'price': 0.0},
            {'index': 1, 'raw_index': 1, 'type': 'TOP', 'price': 4.0},
            {'index': 2, 'raw_index': 2, 'type': 'BOTTOM', 'price': 2.0},
            {'index': 3, 'raw_index': 3, 'type': 'TOP', 'price': 5.0},
            {'index': 4, 'raw_index': 4, 'type': 'BOTTOM', 'price': 3.0},
            {'index': 5, 'raw_index': 5, 'type': 'TOP', 'price': 6.0},
            {'index': 6, 'raw_index': 6, 'type': 'BOTTOM', 'price': 2.0},
            {'index': 7, 'raw_index': 7, 'type': 'TOP', 'price': 7.0},
        ],
        'bi': [
            {
                'index': 0,
                'start_raw_index': 0,
                'end_raw_index': 7,
                'start_price': 0.0,
                'end_price': 7.0,
                'direction': 'UP',
            },
        ],
        'seg': [],
        'seg_layers': {'2': []},
        'meta': {},
    }
    result = module.with_level_rhythm_overlay('DAILY', payload, {
        'enable_rhythm_1382': True,
        'rhythm_calc_mode': 'normal',
        'rhythm_max_lines': 20,
        'rhythm_max_hits_per_line': 3,
    })
    lines = result.get('rhythm_lines') or []
    hits = result.get('rhythm_hits') or []
    rhythm_lines = [line for line in lines if line.get('source_kind') != 'rhythm_left_connector']
    connectors = [line for line in lines if line.get('source_kind') == 'rhythm_left_connector']
    if not rhythm_lines:
        return {'ok': False, 'error': 'functional sample produced no rhythm lines'}
    first_line = rhythm_lines[0]
    expected_price = 2.5
    expected_threshold = 2.0 + (4.0 - 2.0) * 1.382
    return {
        'ok': (
            first_line.get('level') == 'fract'
            and first_line.get('parent_level') == 'bi'
            and abs(float(first_line.get('y1')) - expected_price) < 1e-9
            and abs(float(first_line.get('threshold')) - expected_threshold) < 1e-9
            and bool(hits)
            and int(hits[0].get('raw_index')) == 3
            and bool(connectors)
        ),
        'line_count': len(lines),
        'rhythm_line_count_without_connectors': len(rhythm_lines),
        'left_edge_connector_count': len(connectors),
        'hit_count': len(hits),
        'first_line_y': float(first_line.get('y1')),
        'first_line_threshold': float(first_line.get('threshold')),
        'first_hit_raw_index': int(hits[0].get('raw_index')) if hits else -1,
    }


def main() -> int:
    checks = {
        'backend_overlay_module': contains('backend/app/a_rhythm_overlay.py', [
            'RHYTHM_RATIO = 1.382',
            'with_multilevel_rhythm_overlay',
            'rhythm_lines',
            'rhythm_hits',
        ]),
        'backend_replay_trainer_semantics': contains('backend/app/a_rhythm_overlay.py', [
            '_child_lines_for_parent_rhythm',
            '_build_alternating_child_sequence',
            '_rhythm_1382_threshold',
            '_rhythm_retrace_allowed',
            '_build_parent_rhythm_entries',
            'parent_child_fract_bi_seg_segseg',
            "['fract->bi', 'bi->seg', 'seg->segseg']",
            'gate_threshold',
            'rhythm_price',
            'seg_layers',
        ]),
        'backend_left_edge_connectors': contains('backend/app/a_rhythm_overlay.py', [
            '_left_edge_connectors',
            'rhythm_left_connector',
            'same x1 rhythm lines are connected',
            'rhythm_left_edge_connector_policy',
        ]),
        'backend_route': contains('backend/app/main.py', [
            'from .a_rhythm_overlay import with_multilevel_rhythm_overlay',
            'with_multilevel_rhythm_overlay',
            'backend_route_rhythm_1382_overlay_ms',
            'rhythm_lines',
            'rhythm_hits',
            '_compact_multilevel_step_result',
        ]),
        'dart_model': contains('lib/core/models/rhythm.dart', [
            'class RhythmLine',
            'class RhythmHit',
            'parseRhythmLines',
            'parseRhythmHits',
        ]),
        'snapshot_model': contains('lib/core/models/chan_snapshot.dart', [
            'final List<RhythmLine> rhythmLines',
            'final List<RhythmHit> rhythmHits',
            '_rhythmLineCache',
            '_rhythmHitCache',
            'ChanSnapshot.empty()',
        ]),
        'snapshot_cache_contract_test': contains('test/validate_chan_snapshot_rhythm_cache.dart', [
            'final rawBars = []',
            'final rewrapped = ChanSnapshot',
            'assert(rewrapped.rhythmLines.length == 1)',
            'assert(rewrapped.rhythmHits.length == 1)',
        ]),
        'step_display_fix_doc': contains('docs/hichanjzx_rhythm_step_display_fix.md', [
            'step replay',
            'rewraps the same `rawBars`',
            'rhythm_left_connector',
        ]),
        'json_parser': contains('lib/data/chan_snapshot_json_parser.dart', [
            'rhythm_lines',
            'rhythmHits: rhythmHits',
            'parseRhythmLines',
            'parseRhythmHits',
        ]),
        'single_stock_replay_page': contains('lib/ui/pages/s13_single_stock_replay_page.dart', [
            'enable_rhythm_1382',
            'rhythm_calc_mode',
            'drawingObjects: _rhythmDrawingObjects(s)',
            'TradingViewDrawingTool.trendLine',
            'TradingViewDrawingTool.priceLabel',
            'rhythm_1382_line_count',
            'rhythm_1382_hit_count',
            'dart_chan_calculation_authority: false',
        ]),
    }
    functional = functional_rhythm_sample()
    missing = {name: [key for key, ok in values.items() if not ok] for name, values in checks.items() if not all(values.values())}
    result = {
        'ok': not missing and bool(functional.get('ok')),
        'missing': missing,
        'checks': checks,
        'functional_rhythm_sample': functional,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
