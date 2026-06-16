from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


def contains(path: str, needles: list[str]) -> dict[str, bool]:
    text = read(path)
    return {needle: needle in text for needle in needles}


def main() -> int:
    checks = {
        'backend_overlay_module': contains('backend/app/a_rhythm_overlay.py', ['RHYTHM_RATIO = 1.382', 'with_multilevel_rhythm_overlay', 'rhythm_lines', 'rhythm_hits']),
        'backend_route': contains('backend/app/main.py', ['with_multilevel_rhythm_overlay', 'backend_route_rhythm_1382_overlay_ms', 'rhythm_lines', 'rhythm_hits', '_compact_multilevel_step_result']),
        'dart_model': contains('lib/core/models/rhythm.dart', ['class RhythmLine', 'class RhythmHit', 'parseRhythmLines', 'parseRhythmHits']),
        'snapshot_model': contains('lib/core/models/chan_snapshot.dart', ['final List<RhythmLine> rhythmLines', 'final List<RhythmHit> rhythmHits', 'rhythmLines = const []', 'rhythmHits = const []']),
        'json_parser': contains('lib/data/chan_snapshot_json_parser.dart', ['rhythm_lines', 'rhythmHits: rhythmHits', 'parseRhythmLines', 'parseRhythmHits']),
        'single_stock_replay_page': contains('lib/ui/pages/s13_single_stock_replay_page.dart', ['enable_rhythm_1382', 'rhythm_calc_mode', 'drawingObjects: _rhythmDrawingObjects(s)', 'TradingViewDrawingTool.trendLine', 'TradingViewDrawingTool.priceLabel', 'rhythm_1382_line_count', 'rhythm_1382_hit_count', 'dart_chan_calculation_authority: false']),
    }
    missing = {name: [key for key, ok in values.items() if not ok] for name, values in checks.items() if not all(values.values())}
    result = {'ok': not missing, 'missing': missing, 'checks': checks}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
