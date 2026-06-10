#!/usr/bin/env python3
"""Patch OriginReplayPageV2 to mount display-only indicator panes."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / 'lib/ui/pages/origin_replay_page_v2.dart'

IMPORT_OLD = """import '../widgets/origin_kline_chart.dart';
import '../widgets/replay_controller_bar.dart';"""
IMPORT_NEW = """import '../widgets/origin_kline_chart.dart';
import '../widgets/origin_indicator_pane_host.dart';
import '../widgets/replay_controller_bar.dart';"""

STATE_OLD = """  bool _showMergedBars = false;
  bool _showLayerStatusPanel = true;"""
STATE_NEW = """  bool _showMergedBars = false;
  bool _showVolPane = true;
  bool _showMacdPane = false;
  bool _showLayerStatusPanel = true;"""

STATUS_OLD = """      _LayerStatusRow('合并K线', _fullSnapshot.mergedBars.length, _showMergedBars),
    ];"""
STATUS_NEW = """      _LayerStatusRow('合并K线', _fullSnapshot.mergedBars.length, _showMergedBars),
      _LayerStatusRow('VOL', _fullSnapshot.indicators.vol.length, _showVolPane),
      _LayerStatusRow('MACD', _fullSnapshot.indicators.macd.length, _showMacdPane),
    ];"""

TOOLBAR_OLD = """                        _toolIcon('本地CSV上传', Icons.upload_file,
                            _loading ? null : _pickCsv),"""
TOOLBAR_NEW = """                        _toolIcon(
                            'VOL副图',
                            Icons.bar_chart,
                            _hasBars && _snapshot.indicators.vol.isNotEmpty
                                ? () => setState(() => _showVolPane = !_showVolPane)
                                : null,
                            selected: _showVolPane && _snapshot.indicators.vol.isNotEmpty),
                        _toolIcon(
                            'MACD副图',
                            Icons.show_chart,
                            _hasBars && _snapshot.indicators.macd.isNotEmpty
                                ? () => setState(() => _showMacdPane = !_showMacdPane)
                                : null,
                            selected: _showMacdPane && _snapshot.indicators.macd.isNotEmpty),
                        _toolIcon('本地CSV上传', Icons.upload_file,
                            _loading ? null : _pickCsv),"""

CHART_START_OLD = """              Positioned.fill(
                child: OriginKlineChart("""
CHART_START_NEW = """              Positioned.fill(
                child: OriginIndicatorPaneHost(
                  snapshot: _snapshot,
                  showVol: _showVolPane,
                  showMacd: _showMacdPane,
                  windowSize: _windowSize,
                  viewEndIndex: _viewEndIndex,
                  crosshairIndex: _crosshairIndex,
                  chart: OriginKlineChart("""

CHART_END_OLD = """                  onPriceScaleChanged: (v) => setState(() => _priceScale = v),
                ),
              ),
              if (_showLayerStatusPanel) _buildLayerStatusPanel(),"""
CHART_END_NEW = """                  onPriceScaleChanged: (v) => setState(() => _priceScale = v),
                  ),
                ),
              ),
              if (_showLayerStatusPanel) _buildLayerStatusPanel(),"""

SLICE_INDICATORS_OLD = """      bsps: source.bsps.where((e) => inCursor(e.rawIndex)).toList(),
    );"""
SLICE_INDICATORS_NEW = """      bsps: source.bsps.where((e) => inCursor(e.rawIndex)).toList(),
      indicators: source.indicators,
    );"""

PATCHES = [
    ('import OriginIndicatorPaneHost', IMPORT_OLD, IMPORT_NEW),
    ('indicator pane state flags', STATE_OLD, STATE_NEW),
    ('layer status rows', STATUS_OLD, STATUS_NEW),
    ('toolbar indicator toggles', TOOLBAR_OLD, TOOLBAR_NEW),
    ('chart panel host start', CHART_START_OLD, CHART_START_NEW),
    ('chart panel host end', CHART_END_OLD, CHART_END_NEW),
    ('slice snapshot indicators', SLICE_INDICATORS_OLD, SLICE_INDICATORS_NEW),
]


def replace_once(text: str, name: str, old: str, new: str) -> tuple[str, str]:
    if new in text:
        return text, 'already_applied'
    if old not in text:
        raise RuntimeError(f'missing patch anchor: {name}')
    return text.replace(old, new, 1), 'applied'


def patch_text(text: str) -> tuple[str, list[tuple[str, str]]]:
    statuses: list[tuple[str, str]] = []
    next_text = text
    for name, old, new in PATCHES:
        next_text, status = replace_once(next_text, name, old, new)
        statuses.append((name, status))
    return next_text, statuses


def check_applied(text: str) -> list[str]:
    return [name for name, _old, new in PATCHES if new not in text]


def check_anchors(text: str) -> list[str]:
    return [name for name, old, new in PATCHES if old not in text and new not in text]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true', help='verify that all patches are already applied')
    parser.add_argument('--check-anchors', action='store_true', help='verify that anchors or patched blocks exist')
    args = parser.parse_args()

    if not TARGET.exists():
        print(f'FAIL: target not found: {TARGET}', file=sys.stderr)
        return 1
    text = TARGET.read_text(encoding='utf-8')

    if args.check:
        missing = check_applied(text)
        if missing:
            print({'target': TARGET.as_posix(), 'applied': False, 'missing': missing})
            return 1
        print({'target': TARGET.as_posix(), 'applied': True})
        return 0

    if args.check_anchors:
        missing = check_anchors(text)
        if missing:
            print({'target': TARGET.as_posix(), 'anchors_ok': False, 'missing': missing})
            return 1
        print({'target': TARGET.as_posix(), 'anchors_ok': True})
        return 0

    try:
        patched, statuses = patch_text(text)
    except RuntimeError as exc:
        print(f'FAIL: {exc}', file=sys.stderr)
        return 1

    if patched != text:
        TARGET.write_text(patched, encoding='utf-8')
    print({'target': TARGET.as_posix(), 'statuses': statuses})
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
