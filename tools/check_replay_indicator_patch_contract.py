#!/usr/bin/env python3
"""Check replay indicator pane patch contract."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    'patcher': ROOT / 'tools/patch_origin_replay_indicator_panes.py',
    'dry_runner': ROOT / 'tools/dry_run_origin_replay_indicator_panes.py',
    'wiring_audit': ROOT / 'tools/audit_origin_replay_indicator_pane_wiring.py',
    'host': ROOT / 'lib/ui/widgets/origin_indicator_pane_host.dart',
}

CHECKS = {
    'patcher': [
        'OriginIndicatorPaneHost',
        "origin_indicator_pane_host.dart",
        'chart: OriginKlineChart(',
        'showVol: _showVolPane,',
        'showMacd: _showMacdPane,',
        'windowSize: _windowSize,',
        'crosshairIndex: _crosshairIndex,',
        'Icons.show_chart',
        'selected: _showVolPane && _snapshot.indicators.vol.isNotEmpty',
        'selected: _showMacdPane && _snapshot.indicators.macd.isNotEmpty',
        'indicators: source.indicators,',
        'slice snapshot indicators',
    ],
    'dry_runner': [
        'patch_text',
        'would_change',
        'statuses',
    ],
    'wiring_audit': [
        'OriginIndicatorPaneHost(',
        'chart: OriginKlineChart(',
        'wraps_origin_chart',
    ],
    'host': [
        'class OriginIndicatorPaneHost extends StatelessWidget',
        'final Widget chart;',
        'OriginIndicatorPane(',
        'bool get _hasBars => snapshot.rawBars.isNotEmpty;',
    ],
}


def main() -> int:
    missing: dict[str, list[str]] = {}
    for key, path in FILES.items():
        if not path.exists():
            missing[key] = ['file missing']
            continue
        text = path.read_text(encoding='utf-8', errors='replace')
        absent = [item for item in CHECKS[key] if item not in text]
        if absent:
            missing[key] = absent
    payload = {'ok': not missing, 'missing': missing}
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    if missing:
        print('FAIL: replay indicator patch contract check failed.', file=sys.stderr)
        return 1
    print('PASS: replay indicator patch contract check passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
