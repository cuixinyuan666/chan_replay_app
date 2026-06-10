#!/usr/bin/env python3
"""Audit whether OriginReplayPageV2 has wired indicator panes through the host."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / 'lib/ui/pages/origin_replay_page_v2.dart'

REQUIRED_SNIPPETS = {
    'imports_host': "import '../widgets/origin_indicator_pane_host.dart';",
    'has_vol_state': 'bool _showVolPane = true;',
    'has_macd_state': 'bool _showMacdPane = false;',
    'has_vol_status': "_LayerStatusRow('VOL', _fullSnapshot.indicators.vol.length, _showVolPane)",
    'has_macd_status': "_LayerStatusRow('MACD', _fullSnapshot.indicators.macd.length, _showMacdPane)",
    'has_vol_toolbar': "'VOL副图'",
    'has_macd_toolbar': "'MACD副图'",
    'uses_host': 'OriginIndicatorPaneHost(',
    'passes_snapshot': 'snapshot: _snapshot,',
    'passes_window': 'windowSize: _windowSize,',
    'passes_crosshair': 'crosshairIndex: _crosshairIndex,',
    'wraps_origin_chart': 'chart: OriginKlineChart(',
}

FORBIDDEN_SNIPPETS = {
    'direct_indicator_pane_in_page': 'OriginIndicatorPane(',
    'direct_backend_reference': 'backend/app',
    'dart_engine_reference': 'core/engine/',
}


def line_of(text: str, snippet: str) -> int | None:
    index = text.find(snippet)
    if index < 0:
        return None
    return text[:index].count('\n') + 1


def main() -> int:
    if not TARGET.exists():
        print({'target': TARGET.as_posix(), 'exists': False})
        return 1
    text = TARGET.read_text(encoding='utf-8', errors='replace')

    missing = [name for name, snippet in REQUIRED_SNIPPETS.items() if snippet not in text]
    forbidden = [
        {'name': name, 'line': line_of(text, snippet), 'snippet': snippet}
        for name, snippet in FORBIDDEN_SNIPPETS.items()
        if snippet in text
    ]
    locations = {
        name: line_of(text, snippet)
        for name, snippet in REQUIRED_SNIPPETS.items()
        if snippet in text
    }
    payload = {
        'target': TARGET.relative_to(ROOT).as_posix(),
        'wired': not missing and not forbidden,
        'missing': missing,
        'forbidden': forbidden,
        'locations': locations,
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))

    if missing or forbidden:
        print('FAIL: replay indicator pane wiring is incomplete.', file=sys.stderr)
        return 1
    print('PASS: replay indicator pane wiring is complete.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
