#!/usr/bin/env python3
"""Dry-run the replay indicator pane patch without writing page files."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT / 'tools') not in sys.path:
    sys.path.insert(0, str(ROOT / 'tools'))

from patch_origin_replay_indicator_panes import TARGET, patch_text  # noqa: E402


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
    print({
        'target': TARGET.as_posix(),
        'ok': True,
        'would_change': patched != text,
        'statuses': statuses,
    })
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
