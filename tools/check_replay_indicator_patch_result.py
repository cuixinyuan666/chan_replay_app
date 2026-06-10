#!/usr/bin/env python3
"""Check the patched replay page text without writing the page file."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT / 'tools') not in sys.path:
    sys.path.insert(0, str(ROOT / 'tools'))

from patch_origin_replay_indicator_panes import TARGET, patch_text  # noqa: E402

REQUIRED_AFTER_PATCH = [
    "import '../widgets/origin_indicator_pane_host.dart';",
    'bool _showVolPane = true;',
    'bool _showMacdPane = false;',
    "'VOL副图'",
    "'MACD副图'",
    'OriginIndicatorPaneHost(',
    'chart: OriginKlineChart(',
    'indicators: source.indicators,',
]


def main() -> int:
    if not TARGET.exists():
        print({'target': TARGET.as_posix(), 'exists': False})
        return 1
    text = TARGET.read_text(encoding='utf-8')
    try:
        patched, statuses = patch_text(text)
    except RuntimeError as exc:
        print({'target': TARGET.as_posix(), 'ok': False, 'error': str(exc)})
        return 1
    missing = [snippet for snippet in REQUIRED_AFTER_PATCH if snippet not in patched]
    payload = {
        'target': TARGET.relative_to(ROOT).as_posix(),
        'ok': not missing,
        'would_change': patched != text,
        'missing_after_patch': missing,
        'statuses': statuses,
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    if missing:
        print('FAIL: patched replay indicator result is incomplete.', file=sys.stderr)
        return 1
    print('PASS: patched replay indicator result is complete.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
