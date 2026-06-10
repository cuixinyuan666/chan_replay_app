#!/usr/bin/env python3
"""Audit global eager-loading risks in Flutter entry and shell files.

The goal is not to force every widget to use Dart deferred imports.  The goal is
that app-wide entry/shell files do not import legacy algorithm engines or heavy
research/scanner pages in a way that reintroduces production coupling.  Actual
research pages may remain normal imports inside their own feature boundary.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GLOBAL_FILES = [
    Path('lib/main.dart'),
    Path('lib/app.dart'),
    Path('lib/ui/pages/root_page.dart'),
    Path('lib/ui/pages/replay_page.dart'),
]
LEGACY_ENGINE_PATTERNS = (
    'core/engine/',
    'ChanReplayEngine',
    'FxEngine',
    'BiEngine',
    'SegEngine',
    'ZsEngine',
    'IncludeProcessor',
)
HEAVY_PAGE_PATTERNS = (
    'scanner_page.dart',
    'backtest_page.dart',
    'machine_learning_page.dart',
    'research_page.dart',
)
ALLOWED_GLOBAL_IMPORTS = {
    'lib/ui/pages/root_page.dart': {
        'ashare_bsp_scanner_page.dart',
        'origin_replay_page_v2.dart',
    },
    'lib/ui/pages/replay_page.dart': {
        'origin_replay_page_v2.dart',
    },
}


@dataclass(frozen=True)
class Finding:
    path: Path
    line: int
    kind: str
    text: str
    blocking: bool
    reason: str


def _iter_dart_files() -> list[Path]:
    return sorted((ROOT / 'lib').rglob('*.dart'))


def _scan_file(path: Path, *, strict: bool) -> list[Finding]:
    full = ROOT / path
    if not full.exists():
        return []
    findings: list[Finding] = []
    allowed = ALLOWED_GLOBAL_IMPORTS.get(path.as_posix(), set())
    for lineno, line in enumerate(full.read_text(encoding='utf-8').splitlines(), start=1):
        stripped = line.strip()
        for pattern in LEGACY_ENGINE_PATTERNS:
            if pattern in stripped:
                findings.append(Finding(
                    path=path,
                    line=lineno,
                    kind='legacy_engine_global_reference',
                    text=stripped,
                    blocking=True,
                    reason='global entry/shell must not eagerly import or reference Dart Chan algorithm engines',
                ))
        if stripped.startswith('import '):
            for pattern in HEAVY_PAGE_PATTERNS:
                if pattern in stripped and pattern not in allowed:
                    findings.append(Finding(
                        path=path,
                        line=lineno,
                        kind='heavy_page_global_import',
                        text=stripped,
                        blocking=strict,
                        reason='heavy feature page should be loaded behind feature boundary or explicitly whitelisted',
                    ))
    return findings


def _scan_all_dart_for_legacy_imports() -> list[Finding]:
    findings: list[Finding] = []
    production_allow = re.compile(r'/(core/engine|tools?|test|debug|compare)/')
    for full in _iter_dart_files():
        rel = full.relative_to(ROOT)
        if 'core/engine' in rel.as_posix():
            continue
        for lineno, line in enumerate(full.read_text(encoding='utf-8').splitlines(), start=1):
            stripped = line.strip()
            if 'core/engine/' in stripped and not production_allow.search('/' + rel.as_posix()):
                findings.append(Finding(
                    path=rel,
                    line=lineno,
                    kind='legacy_engine_import',
                    text=stripped,
                    blocking=True,
                    reason='production Dart file imports legacy Chan algorithm engine',
                ))
    return findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--strict', action='store_true', help='treat non-whitelisted heavy page imports as blocking')
    args = parser.parse_args()

    findings: list[Finding] = []
    for path in GLOBAL_FILES:
        findings.extend(_scan_file(path, strict=args.strict))
    findings.extend(_scan_all_dart_for_legacy_imports())

    blocking = [f for f in findings if f.blocking]
    print({
        'repo': ROOT.name,
        'rule': 'global shell must avoid eager legacy algorithm coupling and audited heavy imports',
        'blocking_count': len(blocking),
        'review_count': len(findings) - len(blocking),
        'findings': [f.__dict__ | {'path': f.path.as_posix()} for f in findings],
    })
    if blocking:
        print('FAIL: global lazy-loading / legacy coupling audit failed', file=sys.stderr)
        return 1
    print('PASS: global lazy-loading audit passed')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
