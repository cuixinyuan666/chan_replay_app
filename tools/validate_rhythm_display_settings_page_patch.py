from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'

REQUIRED = [
    "import 's13_rhythm_display_settings.dart';",
    'S13RhythmDisplaySettings _rhythmSettings',
    '_openRhythmDisplaySettings()',
    "label: const Text('节奏线设置')",
    'selection.lines.where(_rhythmSettings.lineVisible)',
    'style: _rhythmSettings.lineStyle(line)',
    'selection.hits.where(_rhythmSettings.hitVisible)',
    'style: _rhythmSettings.hitStyle(hit)',
    'text: _rhythmSettings.hitText(hit)',
]
FORBIDDEN = [
    "colorValue: line.dir == 'UP' ? 0xFF66BB6A : 0xFFEF5350",
    "text: '1.382 ${hit.displayLabel}'",
]


def main() -> None:
    text = PAGE.read_text(encoding='utf-8')
    missing = [item for item in REQUIRED if item not in text]
    stale = [item for item in FORBIDDEN if item in text]
    if missing or stale:
        raise SystemExit(f'rhythm display settings page patch invalid: missing={missing}, stale={stale}')
    print('validate_rhythm_display_settings_page_patch: OK')


if __name__ == '__main__':
    main()
