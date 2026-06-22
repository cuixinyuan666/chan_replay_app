from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S13 = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'


def _replace_exact(text: str, old: str, new: str, label: str, expected: int = 1) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'[abort] {label}: expected {expected} match(es), got {count}')
    return text.replace(old, new)


def main() -> None:
    text = S13.read_text(encoding='utf-8')
    original = text

    text = _replace_exact(
        text,
        """import '../../core/models/bsp.dart';\n""",
        """import '../../core/models/bsp.dart';\nimport '../../core/models/bsp_step_review.dart';\n""",
        'add bsp_step_review import',
    )
    text = _replace_exact(
        text,
        """import '../widgets/auto_collapsible_side_toolbar.dart';\n""",
        """import '../widgets/auto_collapsible_side_toolbar.dart';\nimport '../widgets/bsp_bottom_label_overlay.dart';\n""",
        'add bottom label overlay import',
    )

    text = _replace_exact(
        text,
        """  final Map<String, Offset> _replayControlOffsets = <String, Offset>{};\n""",
        """  final Map<String, Offset> _replayControlOffsets = <String, Offset>{};\n  final Map<String, BspStepReviewItem> _bspStepReviewItems =\n      <String, BspStepReviewItem>{};\n  final Set<String> _bspStepReviewCorrectKeys = <String>{};\n  final Set<String> _bspStepReviewWrongKeys = <String>{};\n""",
        'add step review state',
    )

    text = _replace_exact(
        text,
        """  int get _bspCandidateTrailCount {\n    final s = _activeSnapshot;\n    return s == null ? 0 : _bspCandidateTrail(s).length;\n  }\n\n""",
        """  int get _bspCandidateTrailCount {\n    final s = _activeSnapshot;\n    return s == null ? 0 : _bspCandidateTrail(s).length;\n  }\n\n  String _bspReviewSide(BspPoint p) =>\n      p.isSell ? 'sell' : (p.isBuy ? 'buy' : 'bsp');\n\n  String _bspReviewSideText(BspPoint p) =>\n      p.isSell ? '卖' : (p.isBuy ? '买' : '点');\n\n  String _bspReviewJudgeKey(String level, BspPoint p) =>\n      '${level.trim().toUpperCase()}|${p.rawIndex}|${_bspReviewSide(p)}';\n\n  BspReviewStatus _bspReviewStatusFor(String judgeKey) {\n    if (_bspStepReviewCorrectKeys.contains(judgeKey)) {\n      return BspReviewStatus.correct;\n    }\n    if (_bspStepReviewWrongKeys.contains(judgeKey)) {\n      return BspReviewStatus.wrong;\n    }\n    return BspReviewStatus.pending;\n  }\n\n  List<BspStepReviewItem> get _currentBspStepReviewItems {\n    if (!_hasStepFrames) return const <BspStepReviewItem>[];\n    final rows = <BspStepReviewItem>[];\n    for (final observation in _snapshotBspObservationsWithTrail(_activeLevel)) {\n      final bsp = observation.bsp;\n      final judgeKey = _bspReviewJudgeKey(_activeLevel, bsp);\n      final baseType = _baseBspType(bsp);\n      final item = _bspStepReviewItems.putIfAbsent(\n        judgeKey,\n        () => BspStepReviewItem(\n          key: '${observation.bspKey}|${observation.bspSourceFrame}',\n          judgeKey: judgeKey,\n          level: _activeLevel,\n          anchorRawIndex: bsp.rawIndex,\n          displayRawIndex: bsp.rawIndex,\n          isBuy: !bsp.isSell,\n          label: baseType,\n          displayLabel: '${_bspReviewSideText(bsp)}$baseType',\n          firstFrameIndex: observation.bspSourceFrame < 0\n              ? _safeFrameIndex\n              : observation.bspSourceFrame,\n        ),\n      );\n      rows.add(item.copyWith(status: _bspReviewStatusFor(judgeKey)));\n    }\n    rows.sort((a, b) {\n      if (a.displayRawIndex != b.displayRawIndex) {\n        return a.displayRawIndex.compareTo(b.displayRawIndex);\n      }\n      return a.judgeKey.compareTo(b.judgeKey);\n    });\n    return rows;\n  }\n\n  List<BspBottomLabel> get _bspBottomLabels => <BspBottomLabel>[\n        for (final item in _currentBspStepReviewItems)\n          BspBottomLabel(\n            rawIndex: item.displayRawIndex,\n            anchorRawIndex: item.anchorRawIndex,\n            text: '${_bspReviewStatusPrefix(item.status)}${item.displayLabel}',\n            isBuy: item.isBuy,\n            status: item.status,\n            level: item.level,\n          ),\n      ];\n\n  String _bspReviewStatusPrefix(BspReviewStatus status) => switch (status) {\n        BspReviewStatus.correct => '✓',\n        BspReviewStatus.wrong => '×',\n        BspReviewStatus.pending => '?',\n      };\n\n  BspReviewStats get _bspReviewStats {\n    final items = _currentBspStepReviewItems;\n    final judged = items\n        .where((item) => item.status != BspReviewStatus.pending)\n        .length;\n    final correct =\n        items.where((item) => item.status == BspReviewStatus.correct).length;\n    final wrong = items.where((item) => item.status == BspReviewStatus.wrong).length;\n    return BspReviewStats(\n      appeared: items.length,\n      judged: judged,\n      correct: correct,\n      wrong: wrong,\n      rate: judged == 0 ? null : correct / judged,\n      fromFrame: items.isEmpty\n          ? _safeFrameIndex\n          : items.map((item) => item.firstFrameIndex).reduce(math.min),\n      toFrame: _safeFrameIndex,\n      fromTime: _activeSnapshot?.rawBars.isEmpty == false\n          ? _activeSnapshot!.rawBars.first.time\n          : null,\n      toTime: _activeSnapshot?.rawBars.isEmpty == false\n          ? _activeSnapshot!.rawBars.last.time\n          : null,\n      reason: _hasStepFrames ? 'manual_current_frame' : 'not_step_mode',\n    );\n  }\n\n  String _bspReviewStatsText() {\n    final stats = _bspReviewStats;\n    final rate = stats.rate == null\n        ? 'N/A'\n        : '${(stats.rate! * 100).toStringAsFixed(1)}%';\n    return 'appeared=${stats.appeared} judged=${stats.judged} correct=${stats.correct} wrong=${stats.wrong} rate=$rate frame=${stats.fromFrame + 1}~${stats.toFrame + 1} reason=${stats.reason}';\n  }\n\n  void _judgeCurrentBspStepReviews() {\n    if (!_hasStepFrames) {\n      _showInfo('请先以 step 模式载入复盘数据。');\n      return;\n    }\n    final finalSnapshot = _analysis?.snapshot.of(_activeLevel);\n    if (finalSnapshot == null || finalSnapshot.bsps.isEmpty) {\n      _showInfo('最终快照没有可用于对照的 BSP。');\n      return;\n    }\n    final items = _currentBspStepReviewItems;\n    if (items.isEmpty) {\n      _showInfo('当前帧没有可检查的 BSP。');\n      return;\n    }\n    final finalJudgeKeys = <String>{\n      for (final p in finalSnapshot.bsps) _bspReviewJudgeKey(_activeLevel, p),\n    };\n    setState(() {\n      for (final item in items) {\n        if (finalJudgeKeys.contains(item.judgeKey)) {\n          _bspStepReviewCorrectKeys.add(item.judgeKey);\n          _bspStepReviewWrongKeys.remove(item.judgeKey);\n        } else {\n          _bspStepReviewWrongKeys.add(item.judgeKey);\n          _bspStepReviewCorrectKeys.remove(item.judgeKey);\n        }\n      }\n    });\n    _showInfo('当前买卖点检查完成\\n${_bspReviewStatsText()}');\n  }\n\n""",
        'insert bsp step review helpers',
    )

    load_button_tail = """                label: const Text('载入复盘'),\n              ),\n"""
    text = _replace_exact(
        text,
        load_button_tail,
        """                label: const Text('载入复盘'),\n              ),\n              OutlinedButton.icon(\n                onPressed: _hasStepFrames ? _judgeCurrentBspStepReviews : null,\n                icon: const Icon(Icons.fact_check, size: 16),\n                label: const Text('检查当前买卖点'),\n              ),\n              _infoButton('BSP统计', _bspReviewStatsText()),\n""",
        'add manual bsp review buttons',
        expected=2,
    )

    text = _replace_exact(
        text,
        """      S13ChipDistributionPanel(\n        snapshot: _activeSnapshot,\n        enabled: _showChipDistribution,\n        isStepMode: _isStepMode,\n        stepIndex:\n            (s.rawBars.length - 1).clamp(0, s.rawBars.length - 1).toInt(),\n        crosshairIndex: _crosshairIndex,\n        visibleRightIndex: (_viewEndIndex ?? s.rawBars.length - 1)\n            .clamp(0, s.rawBars.length - 1)\n            .toInt(),\n        windowSize: _windowSize,\n        priceScale: _priceScale,\n        priceOffset: _priceOffset,\n        easySubPanelCount: _enabledEasyTdxIndicators.isEmpty ? 0 : 2,\n      ),\n""",
        """      S13ChipDistributionPanel(\n        snapshot: _activeSnapshot,\n        enabled: _showChipDistribution,\n        isStepMode: _isStepMode,\n        stepIndex:\n            (s.rawBars.length - 1).clamp(0, s.rawBars.length - 1).toInt(),\n        crosshairIndex: _crosshairIndex,\n        visibleRightIndex: (_viewEndIndex ?? s.rawBars.length - 1)\n            .clamp(0, s.rawBars.length - 1)\n            .toInt(),\n        windowSize: _windowSize,\n        priceScale: _priceScale,\n        priceOffset: _priceOffset,\n        easySubPanelCount: _enabledEasyTdxIndicators.isEmpty ? 0 : 2,\n      ),\n      BspBottomLabelOverlay(\n        enabled: _hasStepFrames,\n        labels: _bspBottomLabels,\n        totalBars: s.rawBars.length,\n        windowSize: _windowSize,\n        viewEndIndex: _viewEndIndex,\n        easySubPanelCount: _enabledEasyTdxIndicators.isEmpty ? 0 : 2,\n      ),\n""",
        'add bottom label overlay to chart stack',
    )

    text = _replace_exact(
        text,
        """      _bspStepReviewWrongKeys.remove(item.judgeKey);\n        } else {\n""",
        """          _bspStepReviewWrongKeys.remove(item.judgeKey);\n        } else {\n""",
        'fix correct-branch indentation',
    )

    if text == original:
        raise SystemExit('[abort] no changes produced')
    S13.write_text(text, encoding='utf-8')
    print('BSP step review overlay patch applied.')
    print('Next: flutter analyze')


if __name__ == '__main__':
    main()
