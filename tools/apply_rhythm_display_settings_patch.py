from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'

IMPORT_ANCHOR = "import 's13_nested_marker_numbering_policy.dart';\n"
IMPORT_SETTINGS = "import 's13_rhythm_display_settings.dart';\n"
FIELD_ANCHOR = "  final Map<String, Offset> _replayControlOffsets = <String, Offset>{};\n"
FIELD_INSERT = FIELD_ANCHOR + "  S13RhythmDisplaySettings _rhythmSettings = const S13RhythmDisplaySettings();\n"

METHOD_ANCHOR = "  Widget _settingsPanel() => _panelBox('工具栏', _unifiedToolPanel());\n"
METHOD_INSERT = """  Future<void> _openRhythmDisplaySettings() async {
    final next = await showS13RhythmDisplaySettingsDialog(
      context: context,
      initial: _rhythmSettings,
    );
    if (next == null || !mounted) return;
    setState(() {
      _rhythmSettings = next;
      _showRhythmLines = next.enabled;
      _show1382Hits = next.hit.enabled;
    });
  }

""" + METHOD_ANCHOR

BUTTON_ANCHOR = """               FilterChip(
                   label: const Text('1.382命中'),
                   selected: _show1382Hits,
                   onSelected: _loading
                       ? null
                       : (v) => setState(() => _show1382Hits = v)),
"""
BUTTON_INSERT = BUTTON_ANCHOR + """              FilledButton.tonalIcon(
                onPressed: _loading ? null : _openRhythmDisplaySettings,
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('节奏线设置'),
              ),
"""

REPLACES = [
    ("for (final line in selection.lines) {", "for (final line in selection.lines.where(_rhythmSettings.lineVisible)) {"),
    ("""          style: DrawingStyle(
            colorValue: line.dir == 'UP' ? 0xFF66BB6A : 0xFFEF5350,
            strokeWidth: 1.2 + line.layer.clamp(0, 3) * 0.35,
            opacity: 0.88,
            dashed: true,
            fontSize: 11,
          ),
""", """          style: _rhythmSettings.lineStyle(line),
"""),
    ("for (final hit in selection.hits) {", "for (final hit in selection.hits.where(_rhythmSettings.hitVisible)) {"),
    ("""          style: const DrawingStyle(
            colorValue: 0xFF8AB4FF,
            strokeWidth: 1.0,
            opacity: 0.95,
            fontSize: 10,
          ),
          text: '1.382 ${hit.displayLabel}',
""", """          style: _rhythmSettings.hitStyle(hit),
          text: _rhythmSettings.hitText(hit),
"""),
]


def apply_once(text: str, old: str, new: str, label: str) -> tuple[str, bool]:
    if new in text:
        return text, False
    if old not in text:
        raise SystemExit(f'target not found: {label}')
    return text.replace(old, new, 1), True


def main() -> None:
    text = PAGE.read_text(encoding='utf-8')
    changed = False
    if IMPORT_SETTINGS not in text:
        if IMPORT_ANCHOR not in text:
            raise SystemExit('import anchor not found')
        text = text.replace(IMPORT_ANCHOR, IMPORT_ANCHOR + IMPORT_SETTINGS, 1)
        changed = True
    if 'S13RhythmDisplaySettings _rhythmSettings' not in text:
        if FIELD_ANCHOR not in text:
            raise SystemExit('field anchor not found')
        text = text.replace(FIELD_ANCHOR, FIELD_INSERT, 1)
        changed = True
    if '_openRhythmDisplaySettings()' not in text:
        if METHOD_ANCHOR not in text:
            raise SystemExit('settings panel anchor not found')
        text = text.replace(METHOD_ANCHOR, METHOD_INSERT, 1)
        changed = True
    if "label: const Text('节奏线设置')" not in text:
        if BUTTON_ANCHOR not in text:
            raise SystemExit('rhythm hit chip anchor not found')
        text = text.replace(BUTTON_ANCHOR, BUTTON_INSERT, 1)
        changed = True
    for old, new in REPLACES:
        text, did = apply_once(text, old, new, old.split('\n', 1)[0])
        changed = changed or did
    if changed:
        PAGE.write_text(text, encoding='utf-8')
        print(f'patched {PAGE.relative_to(ROOT)}')
    else:
        print('rhythm display settings patch already applied')


if __name__ == '__main__':
    main()
