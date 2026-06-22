from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S13 = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'


def _replace_exact(text: str, old: str, new: str, label: str, expected: int = 1) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'[abort] {label}: expected {expected} match(es), got {count}')
    return text.replace(old, new, expected)


def main() -> None:
    text = S13.read_text(encoding='utf-8')
    original = text

    text = _replace_exact(
        text,
        """import '../widgets/auto_collapsible_side_toolbar.dart';
import '../widgets/bsp_bottom_label_overlay.dart';
""",
        """import '../widgets/auto_collapsible_side_toolbar.dart';
import '../widgets/bsp_bottom_label_overlay.dart';
import '../widgets/bsp_chart_label_adapter.dart';
""",
        'add BSP chart label adapter import',
    )

    text = _replace_exact(
        text,
        """  List<BspBottomLabel> get _bspBottomLabels => <BspBottomLabel>[
        for (final item in _currentBspStepReviewItems)
          BspBottomLabel(
            rawIndex: item.displayRawIndex,
            anchorRawIndex: item.anchorRawIndex,
            text: '${_bspReviewStatusPrefix(item.status)}${item.displayLabel}',
            isBuy: item.isBuy,
            status: item.status,
            level: item.level,
          ),
      ];

  String _bspReviewStatusPrefix(BspReviewStatus status) => switch (status) {
        BspReviewStatus.correct => '✓',
        BspReviewStatus.wrong => '×',
        BspReviewStatus.pending => '?',
      };
""",
        """  List<BspBottomLabel> get _bspBottomLabels {
    final rows = <BspBottomLabel>[];
    for (final observation in _snapshotBspObservationsWithTrail(_activeLevel)) {
      final bsp = observation.bsp;
      final visualLevel = _bspVisualLevel(bsp);
      final judgeKey = _bspReviewJudgeKey(_activeLevel, bsp);
      rows.add(BspBottomLabel(
        rawIndex: bsp.rawIndex,
        anchorRawIndex: bsp.rawIndex,
        text: BspChartLabelAdapter.labelTextFor(
          levelPrefix: visualLevel,
          bsp: bsp,
        ),
        isBuy: bsp.isBuy,
        status: _bspReviewStatusFor(judgeKey),
        level: visualLevel,
      ));
    }
    final snap = _activeSnapshot;
    if (snap != null) {
      for (final entry in snap.recursiveSegBsps.entries) {
        final layer = entry.key;
        if (layer < 2) continue;
        final visualLevel = '${layer}段';
        for (final bsp in entry.value) {
          rows.add(BspBottomLabel(
            rawIndex: bsp.rawIndex,
            anchorRawIndex: bsp.rawIndex,
            text: BspChartLabelAdapter.labelTextFor(
              levelPrefix: visualLevel,
              bsp: bsp,
            ),
            isBuy: bsp.isBuy,
            status: BspReviewStatus.pending,
            level: visualLevel,
          ));
        }
      }
    }
    rows.sort((a, b) {
      if (a.rawIndex != b.rawIndex) return a.rawIndex.compareTo(b.rawIndex);
      return _bspVisualRank(a.level).compareTo(_bspVisualRank(b.level));
    });
    return rows;
  }

  String _bspVisualLevel(BspPoint p) => _isVisualSegBsp(p) ? '段' : '笔';

  bool _isVisualSegBsp(BspPoint p) {
    final level = p.level.trim().toLowerCase();
    return level == 'seg' || level == 'segment' || level.contains('seg');
  }

  int _bspVisualRank(String level) {
    final text = level.trim();
    if (text == '笔') return 0;
    if (text == '段') return 1;
    final match = RegExp(r'^(\\d+)段$').firstMatch(text);
    if (match != null) return int.tryParse(match.group(1) ?? '') ?? 2;
    return text.contains('段') ? 1 : 0;
  }
""",
        'replace bottom BSP label source',
    )

    if text == original:
        raise SystemExit('[abort] no changes produced')
    S13.write_text(text, encoding='utf-8')
    print('BSP bottom label layer patch applied.')
    print('Next: flutter analyze')


if __name__ == '__main__':
    main()
