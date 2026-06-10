#!/usr/bin/env python3
"""Audit indicator-pane display boundary."""
from __future__ import annotations

import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGETS = {
    ROOT / 'lib/ui/widgets/origin_indicator_pane.dart': (
        "../../core/models/chan_snapshot.dart",
        "../../core/models/easy_tdx_indicator.dart",
        "../../core/models/raw_bar.dart",
        "class OriginIndicatorPane extends StatelessWidget",
    ),
    ROOT / 'lib/ui/widgets/origin_indicator_pane_host.dart': (
        "../../core/models/chan_snapshot.dart",
        "origin_indicator_pane.dart",
        "class OriginIndicatorPaneHost extends StatelessWidget",
    ),
}

FORBIDDEN_PATTERNS = {
    'legacy_dart_chan_engine': re.compile(
        r"core/engine/|ChanReplayEngine|FxEngine|BiEngine|SegEngine|ZsEngine|IncludeProcessor"
    ),
    'backend_or_runtime_link': re.compile(
        r"PythonChan|python_chan|MethodChannel|http\.|dart:io|backend|app_engine|analyze_bars|/api/chan/analyze"
    ),
    'research_or_training_layer': re.compile(
        r"a_bsp_feature_engine|a_ml_bridge|a_backtest_engine|ml_score|future_return|label_"
    ),
}


@dataclass(frozen=True)
class Finding:
    path: str
    line: int
    kind: str
    text: str


def audit_target(path: Path, required: tuple[str, ...]) -> tuple[list[str], list[Finding]]:
    if not path.exists():
        return [f'missing file: {path.relative_to(ROOT).as_posix()}'], []
    text = path.read_text(encoding='utf-8', errors='replace')
    missing = [snippet for snippet in required if snippet not in text]
    findings: list[Finding] = []
    rel = path.relative_to(ROOT).as_posix()
    for line_no, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        for kind, pattern in FORBIDDEN_PATTERNS.items():
            if pattern.search(stripped):
                findings.append(Finding(rel, line_no, kind, stripped))
    return missing, findings


def main() -> int:
    all_missing: dict[str, list[str]] = {}
    all_findings: list[Finding] = []
    for path, required in TARGETS.items():
        missing, findings = audit_target(path, required)
        if missing:
            all_missing[path.relative_to(ROOT).as_posix()] = missing
        all_findings.extend(findings)

    payload = {
        'rule': 'indicator widgets must stay display-only and consume chart models only',
        'missing_required_snippets': all_missing,
        'forbidden_count': len(all_findings),
        'findings': [asdict(item) for item in all_findings],
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))

    if all_missing or all_findings:
        print('FAIL: indicator pane boundary audit failed.', file=sys.stderr)
        return 1
    print('PASS: indicator pane widgets remain display-only.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
