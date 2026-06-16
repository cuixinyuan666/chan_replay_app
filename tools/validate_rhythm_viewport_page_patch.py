from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'

REQUIRED = [
    "import 's13_rhythm_viewport_selector.dart';",
    'final selection = S13RhythmViewportSelector.select(',
    'for (final line in selection.lines)',
    'for (final hit in selection.hits)',
]
FORBIDDEN = [
    'snapshot.rhythmLines.take(120)',
    'snapshot.rhythmHits.take(80)',
]


def main() -> None:
    text = PAGE.read_text(encoding='utf-8')
    missing = [item for item in REQUIRED if item not in text]
    stale = [item for item in FORBIDDEN if item in text]
    if missing or stale:
        raise SystemExit(f'rhythm viewport page patch invalid: missing={missing}, stale={stale}')
    print('validate_rhythm_viewport_page_patch: OK')


if __name__ == '__main__':
    main()
