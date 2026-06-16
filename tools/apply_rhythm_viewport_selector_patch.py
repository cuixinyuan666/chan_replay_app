from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'

IMPORT_ANCHOR = "import 's13_nested_marker_numbering_policy.dart';\n"
IMPORT_LINE = "import 's13_rhythm_viewport_selector.dart';\n"

OLD_FUNC = """  List<DrawingObject> _rhythmDrawingObjects(ChanSnapshot snapshot) {
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    final objects = <DrawingObject>[];
    if (_showRhythmLines) {
      for (final line in snapshot.rhythmLines.take(120)) {
        objects.add(DrawingObject(
          id: 'auto_${line.id}',
          tool: TradingViewDrawingTool.trendLine,
          anchors: <DrawingAnchor>[
            DrawingAnchor.chart(rawIndex: line.x1, price: line.y1),
            DrawingAnchor.chart(rawIndex: line.x2, price: line.y2),
          ],
          style: DrawingStyle(
            colorValue: line.dir == 'UP' ? 0xFF66BB6A : 0xFFEF5350,
            strokeWidth: 1.2 + line.layer.clamp(0, 3) * 0.35,
            opacity: 0.88,
            dashed: true,
            fontSize: 11,
          ),
          text: line.displayLabel,
          locked: true,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
    if (_show1382Hits) {
      for (final hit in snapshot.rhythmHits.take(80)) {
        objects.add(DrawingObject(
          id: 'auto_${hit.id}',
          tool: TradingViewDrawingTool.priceLabel,
          anchors: <DrawingAnchor>[
            DrawingAnchor.chart(
              rawIndex: hit.rawIndex,
              price: hit.price == 0 ? hit.threshold : hit.price,
            ),
          ],
          style: const DrawingStyle(
            colorValue: 0xFF8AB4FF,
            strokeWidth: 1.0,
            opacity: 0.95,
            fontSize: 10,
          ),
          text: '1.382 ${hit.displayLabel}',
          locked: true,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
    return objects;
  }
"""

NEW_FUNC = """  List<DrawingObject> _rhythmDrawingObjects(ChanSnapshot snapshot) {
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    final objects = <DrawingObject>[];
    final selection = S13RhythmViewportSelector.select(
      lines: snapshot.rhythmLines,
      hits: snapshot.rhythmHits,
      totalBars: snapshot.rawBars.length,
      viewEndIndex: _viewEndIndex,
      windowSize: _windowSize,
    );
    if (_showRhythmLines) {
      for (final line in selection.lines) {
        objects.add(DrawingObject(
          id: 'auto_${line.id}',
          tool: TradingViewDrawingTool.trendLine,
          anchors: <DrawingAnchor>[
            DrawingAnchor.chart(rawIndex: line.x1, price: line.y1),
            DrawingAnchor.chart(rawIndex: line.x2, price: line.y2),
          ],
          style: DrawingStyle(
            colorValue: line.dir == 'UP' ? 0xFF66BB6A : 0xFFEF5350,
            strokeWidth: 1.2 + line.layer.clamp(0, 3) * 0.35,
            opacity: 0.88,
            dashed: true,
            fontSize: 11,
          ),
          text: line.displayLabel,
          locked: true,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
    if (_show1382Hits) {
      for (final hit in selection.hits) {
        objects.add(DrawingObject(
          id: 'auto_${hit.id}',
          tool: TradingViewDrawingTool.priceLabel,
          anchors: <DrawingAnchor>[
            DrawingAnchor.chart(
              rawIndex: hit.rawIndex,
              price: hit.price == 0 ? hit.threshold : hit.price,
            ),
          ],
          style: const DrawingStyle(
            colorValue: 0xFF8AB4FF,
            strokeWidth: 1.0,
            opacity: 0.95,
            fontSize: 10,
          ),
          text: '1.382 ${hit.displayLabel}',
          locked: true,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
    return objects;
  }
"""


def main() -> None:
    text = PAGE.read_text(encoding='utf-8')
    changed = False
    if IMPORT_LINE not in text:
        if IMPORT_ANCHOR not in text:
            raise SystemExit(f'import anchor not found: {IMPORT_ANCHOR.strip()}')
        text = text.replace(IMPORT_ANCHOR, IMPORT_ANCHOR + IMPORT_LINE, 1)
        changed = True
    if OLD_FUNC not in text:
        if NEW_FUNC in text:
            print('rhythm viewport selector patch already applied')
            return
        raise SystemExit('target _rhythmDrawingObjects function shape not found')
    text = text.replace(OLD_FUNC, NEW_FUNC, 1)
    changed = True
    if changed:
        PAGE.write_text(text, encoding='utf-8')
        print(f'patched {PAGE.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
