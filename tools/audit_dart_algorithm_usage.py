#!/usr/bin/env python3
"""Audit Dart-side Chan algorithm usage for origin_vespa_tdx.

Goal:
  Flutter/Dart may keep draw models and UI state, but production UI/data flow must
  not compute FX/BI/SEG/ZS/BSP with the legacy Dart engines. Python chan.py is the
  only calculation source.

Run from repository root:
  python tools/audit_dart_algorithm_usage.py

Exit code:
  0 = no blocking production usage found
  1 = blocking production usage found
"""
from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parents[1]

# Files under these folders may retain comparison or legacy code, but they must not
# be part of the App production route.
ALLOWED_NON_PRODUCTION_PARTS = {
    "legacy",
    "tools",
    "compare",
    "test",
    "tests",
}

# Definition files are allowed to exist temporarily while the branch is being
# migrated. The blocking rule is about importing or instantiating them from the
# production route.
ENGINE_DEFINITION_PREFIXES = (
    "lib/core/engine/",
)

ENGINE_IMPORT_RE = re.compile(r"import\s+['\"][^'\"]*core/engine/[^'\"]+['\"]")
ENGINE_SYMBOL_RE = re.compile(
    r"\b(ChanReplayEngine|FxEngine|BiEngine|SegEngine|ZsEngine|IncludeProcessor)\b"
)
CHART_MODEL_RE = re.compile(r"\b(FxDrawModel|BiDrawModel|SegDrawModel|ZsDrawModel|BspPoint)\b")
PYTHON_SOURCE_RE = re.compile(r"PythonChan(Analysis|Engine)Source|python_chan|analyze_bars|/api/chan/analyze")


@dataclass(frozen=True)
class Finding:
    path: str
    kind: str
    line: int
    text: str
    blocking: bool
    reason: str


def iter_dart_files() -> Iterable[Path]:
    for path in (REPO_ROOT / "lib").rglob("*.dart"):
        if path.is_file():
            yield path


def is_non_production_path(path: Path) -> bool:
    rel = path.relative_to(REPO_ROOT).as_posix()
    if rel.startswith(ENGINE_DEFINITION_PREFIXES):
        return True
    parts = set(path.relative_to(REPO_ROOT).parts)
    return bool(parts & ALLOWED_NON_PRODUCTION_PARTS)


def audit_file(path: Path) -> list[Finding]:
    rel = path.relative_to(REPO_ROOT).as_posix()
    text = path.read_text(encoding="utf-8", errors="replace")
    non_production = is_non_production_path(path)
    has_python_source = bool(PYTHON_SOURCE_RE.search(text))
    findings: list[Finding] = []

    for no, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if ENGINE_IMPORT_RE.search(line):
            blocking = not non_production
            findings.append(
                Finding(
                    rel,
                    "engine_import",
                    no,
                    stripped,
                    blocking,
                    "production Dart imports legacy Chan engine" if blocking else "allowed non-production import/definition",
                )
            )
        if ENGINE_SYMBOL_RE.search(line):
            blocking = not non_production
            findings.append(
                Finding(
                    rel,
                    "engine_symbol",
                    no,
                    stripped,
                    blocking,
                    "production Dart references legacy Chan engine symbol" if blocking else "allowed non-production symbol/definition",
                )
            )
        # Draw models are allowed when the same file clearly consumes Python source;
        # this distinguishes display DTOs from local algorithm computation.
        if CHART_MODEL_RE.search(line) and not has_python_source:
            findings.append(
                Finding(
                    rel,
                    "draw_model_without_python_source",
                    no,
                    stripped,
                    False,
                    "review only: draw/model symbol appears outside an obvious Python consumer",
                )
            )
    return findings


def main() -> int:
    findings: list[Finding] = []
    for path in iter_dart_files():
        findings.extend(audit_file(path))

    blocking = [f for f in findings if f.blocking]
    payload = {
        "repo": REPO_ROOT.name,
        "rule": "Flutter/Dart must not compute FX/BI/SEG/ZS/BSP in production route",
        "blocking_count": len(blocking),
        "review_count": len(findings) - len(blocking),
        "findings": [asdict(f) for f in findings],
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    if blocking:
        print("\nFAIL: found production Dart-side Chan algorithm usage.", file=sys.stderr)
        return 1
    print("\nPASS: no blocking production Dart-side Chan algorithm usage found.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
