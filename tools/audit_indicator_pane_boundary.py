#!/usr/bin/env python3
"""Audit OriginIndicatorPane display-only boundary.

The indicator pane is a Flutter display widget.  It may consume immutable model
objects produced from chan.py analysis JSON, but it must not import old Dart Chan
engines, backend launchers, HTTP clients, MethodChannels, or Python runtime glue.

Run from repository root:
  python tools/audit_indicator_pane_boundary.py
"""
from __future__ import annotations

import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / 'lib/ui/widgets/origin_indicator_pane.dart'

REQUIRED_SNIPPETS = (
    "../../core/models/chan_snapshot.dart",
    "../../core/models/easy_tdx_indicator.dart",
    "../../core/models/raw_bar.dart",
    "class OriginIndicatorPane extends StatelessWidget",
)

FORBIDDEN_PATTERNS = {
    'legacy_dart_chan_engine': re.compile(
        r"core/engine/|ChanReplayEngine|FxEngine|BiEngine|SegEngine|ZsEngine|IncludeProcessor"
    ),
    'backend_or_python_runtime': re.compile(
        r"PythonChan|python_chan|MethodChannel|http\.|dart:io|backend|app_engine|analyze_bars|/api/chan/analyze"
    ),
    'research_or_training_layer': re.compile(
        r"a_bsp_feature_engine|a_ml_bridge|a_backtest_engine|ml_score|future_return|label_"
    ),
}


@dataclass(frozen=True)
class Finding:
    line: int
    kind: str
    text: str


def main() -> int:
    if not TARGET.exists():
        print(f'FAIL: missing {TARGET.relative_to(ROOT).as_posix()}', file=sys.stderr)
        return 1

    text = TARGET.read_text(encoding='utf-8', errors='replace')
    missing = [snippet for snippet in REQUIRED_SNIPPETS if snippet not in text]
    findings: list[Finding] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        for kind, pattern in FORBIDDEN_PATTERNS.items():
            if pattern.search(stripped):
                findings.append(Finding(line_no, kind, stripped))

    payload = {
        'target': TARGET.relative_to(ROOT).as_posix(),
        'rule': 'indicator pane must stay display-only and consume chan.py JSON models only',
        'missing_required_snippets': missing,
        'forbidden_count': len(findings),
        'findings': [asdict(item) for item in findings],
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))

    if missing or findings:
        print('FAIL: OriginIndicatorPane boundary audit failed.', file=sys.stderr)
        return 1
    print('PASS: OriginIndicatorPane remains a display-only widget.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
