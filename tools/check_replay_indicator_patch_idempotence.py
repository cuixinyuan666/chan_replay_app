#!/usr/bin/env python3
"""Check that replay indicator patching is idempotent."""
from __future__ import annotations

import json
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

    original = TARGET.read_text(encoding='utf-8')
    try:
        first, first_statuses = patch_text(original)
        second, second_statuses = patch_text(first)
    except RuntimeError as exc:
        print({'target': TARGET.as_posix(), 'ok': False, 'error': str(exc)})
        return 1

    changed_on_second_pass = second != first
    non_idempotent_statuses = [
        item for item in second_statuses if item[1] != 'already_applied'
    ]
    payload = {
        'target': TARGET.relative_to(ROOT).as_posix(),
        'ok': not changed_on_second_pass and not non_idempotent_statuses,
        'first_would_change': first != original,
        'changed_on_second_pass': changed_on_second_pass,
        'first_statuses': first_statuses,
        'second_statuses': second_statuses,
        'non_idempotent_statuses': non_idempotent_statuses,
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))

    if changed_on_second_pass or non_idempotent_statuses:
        print('FAIL: replay indicator patch is not idempotent.', file=sys.stderr)
        return 1
    print('PASS: replay indicator patch is idempotent.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
