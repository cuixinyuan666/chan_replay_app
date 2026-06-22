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
        """      _panelOpen = false,\n      _playing = false;\n""",
        """      _panelOpen = false,\n      _autoJudgeBspStepReview = true,\n      _playing = false;\n""",
        'add auto judge state flag',
    )

    text = _replace_exact(
        text,
        """      reason: _hasStepFrames ? 'manual_current_frame' : 'not_step_mode',\n    );\n  }\n\n  String _bspReviewStatsText() {\n""",
        """      reason: _hasStepFrames\n          ? (_autoJudgeBspStepReview ? 'auto_step' : 'manual_current_frame')\n          : 'not_step_mode',\n    );\n  }\n\n  List<BspReviewBucketStats> get _bspReviewBucketStats {\n    final buckets = <String, BspReviewBucketStats>{};\n    for (final item in _bspStepReviewItems.values) {\n      final status = _bspReviewStatusFor(item.judgeKey);\n      final side = item.isBuy ? 'buy' : 'sell';\n      final key = '${item.level}|$side|${item.label}';\n      final current = buckets[key] ??\n          BspReviewBucketStats(\n            key: key,\n            level: item.level,\n            side: side,\n            label: item.label,\n          );\n      buckets[key] = current.copyWith(\n        appeared: current.appeared + 1,\n        judged: current.judged +\n            (status == BspReviewStatus.pending ? 0 : 1),\n        correct: current.correct +\n            (status == BspReviewStatus.correct ? 1 : 0),\n        wrong: current.wrong + (status == BspReviewStatus.wrong ? 1 : 0),\n      );\n    }\n    final rows = buckets.values.toList(growable: false);\n    rows.sort((a, b) {\n      if (a.level != b.level) return a.level.compareTo(b.level);\n      if (a.side != b.side) return a.side.compareTo(b.side);\n      return a.label.compareTo(b.label);\n    });\n    return rows;\n  }\n\n  String _bspReviewBucketStatsText() {\n    final rows = _bspReviewBucketStats;\n    if (rows.isEmpty) return 'bucket=none';\n    return rows.map((row) {\n      final rate = row.rate == null\n          ? 'N/A'\n          : '${(row.rate! * 100).toStringAsFixed(1)}%';\n      return '${row.level}/${row.side}/${row.label}:${row.correct}/${row.judged}/$rate';\n    }).join(' | ');\n  }\n\n  String _bspReviewStatsText() {\n""",
        'insert bucket stats helpers',
    )

    text = _replace_exact(
        text,
        """  void _judgeCurrentBspStepReviews() {\n    if (!_hasStepFrames) {\n      _showInfo('请先以 step 模式载入复盘数据。');\n      return;\n    }\n    final finalSnapshot = _analysis?.snapshot.of(_activeLevel);\n    if (finalSnapshot == null || finalSnapshot.bsps.isEmpty) {\n      _showInfo('最终快照没有可用于对照的 BSP。');\n      return;\n    }\n    final items = _currentBspStepReviewItems;\n    if (items.isEmpty) {\n      _showInfo('当前帧没有可检查的 BSP。');\n      return;\n    }\n    final finalJudgeKeys = <String>{\n      for (final p in finalSnapshot.bsps) _bspReviewJudgeKey(_activeLevel, p),\n    };\n    setState(() {\n      for (final item in items) {\n        if (finalJudgeKeys.contains(item.judgeKey)) {\n          _bspStepReviewCorrectKeys.add(item.judgeKey);\n          _bspStepReviewWrongKeys.remove(item.judgeKey);\n        } else {\n          _bspStepReviewWrongKeys.add(item.judgeKey);\n          _bspStepReviewCorrectKeys.remove(item.judgeKey);\n        }\n      }\n    });\n    _showInfo('当前买卖点检查完成\\n${_bspReviewStatsText()}');\n  }\n\n""",
        """  int _updateCurrentBspStepReviews({required bool notify}) {\n    if (!_hasStepFrames) {\n      if (notify) _showInfo('请先以 step 模式载入复盘数据。');\n      return 0;\n    }\n    final finalSnapshot = _analysis?.snapshot.of(_activeLevel);\n    if (finalSnapshot == null || finalSnapshot.bsps.isEmpty) {\n      if (notify) _showInfo('最终快照没有可用于对照的 BSP。');\n      return 0;\n    }\n    final items = _currentBspStepReviewItems;\n    if (items.isEmpty) {\n      if (notify) _showInfo('当前帧没有可检查的 BSP。');\n      return 0;\n    }\n    final finalJudgeKeys = <String>{\n      for (final p in finalSnapshot.bsps) _bspReviewJudgeKey(_activeLevel, p),\n    };\n    var changed = 0;\n    setState(() {\n      for (final item in items) {\n        final wasCorrect = _bspStepReviewCorrectKeys.contains(item.judgeKey);\n        final wasWrong = _bspStepReviewWrongKeys.contains(item.judgeKey);\n        final isCorrect = finalJudgeKeys.contains(item.judgeKey);\n        if (isCorrect) {\n          _bspStepReviewCorrectKeys.add(item.judgeKey);\n          _bspStepReviewWrongKeys.remove(item.judgeKey);\n        } else {\n          _bspStepReviewWrongKeys.add(item.judgeKey);\n          _bspStepReviewCorrectKeys.remove(item.judgeKey);\n        }\n        final nowCorrect = _bspStepReviewCorrectKeys.contains(item.judgeKey);\n        final nowWrong = _bspStepReviewWrongKeys.contains(item.judgeKey);\n        if (wasCorrect != nowCorrect || wasWrong != nowWrong) changed++;\n      }\n    });\n    if (notify) {\n      _showInfo(\n          '当前买卖点检查完成\\n${_bspReviewStatsText()}\\n${_bspReviewBucketStatsText()}');\n    }\n    return changed;\n  }\n\n  void _judgeCurrentBspStepReviews() =>\n      _updateCurrentBspStepReviews(notify: true);\n\n""",
        'refactor manual judge into reusable updater',
    )

    text = _replace_exact(
        text,
        """        _priceOffset = 0.0;\n        _chartGeneration++;\n        _status = _buildStatus(a, startDate, endDate);\n""",
        """        _priceOffset = 0.0;\n        _bspStepReviewItems.clear();\n        _bspStepReviewCorrectKeys.clear();\n        _bspStepReviewWrongKeys.clear();\n        _chartGeneration++;\n        _status = _buildStatus(a, startDate, endDate);\n""",
        'clear review state on load',
    )

    text = _replace_exact(
        text,
        """      _showMessage('S13 replay loaded');\n""",
        """      if (_autoJudgeBspStepReview) {\n        _updateCurrentBspStepReviews(notify: false);\n      }\n      _showMessage('S13 replay loaded');\n""",
        'auto judge first frame after load',
    )

    text = _replace_exact(
        text,
        """      _priceOffset = 0.0;\n      final c = _currentSnapshot;\n""",
        """      _priceOffset = 0.0;\n      _bspStepReviewItems.clear();\n      _bspStepReviewCorrectKeys.clear();\n      _bspStepReviewWrongKeys.clear();\n      final c = _currentSnapshot;\n""",
        'clear review state on mode change',
    )

    text = _replace_exact(
        text,
        """    setState(() {\n      _frameIndex = next;\n      _activeLevel = level;\n      _viewEndIndex = null;\n      _crosshairIndex = null;\n      _priceScale = 1.0;\n      _priceOffset = 0.0;\n      final activeBiCount = f.of(level)?.bis.length ?? 0;\n      _status =\n          'S13 step frame ${next + 1}/${a.frames.length} active:$level active_bi:$activeBiCount loaded_config:{${_loadedChanConfigSummary(a)}} final_bi_counts:{${_biCountSummary(a.snapshot)}} current_bi_counts:{${_biCountSummary(f)}} relations:${f.relations.length} nested_markers:${_nestedBspMarkers.length} candidate_trail:$_bspCandidateTrailCount missing_edges:${_missingAdjacentRelationEdges().join(',')}';\n    });\n  }\n\n""",
        """    setState(() {\n      _frameIndex = next;\n      _activeLevel = level;\n      _viewEndIndex = null;\n      _crosshairIndex = null;\n      _priceScale = 1.0;\n      _priceOffset = 0.0;\n      final activeBiCount = f.of(level)?.bis.length ?? 0;\n      _status =\n          'S13 step frame ${next + 1}/${a.frames.length} active:$level active_bi:$activeBiCount loaded_config:{${_loadedChanConfigSummary(a)}} final_bi_counts:{${_biCountSummary(a.snapshot)}} current_bi_counts:{${_biCountSummary(f)}} relations:${f.relations.length} nested_markers:${_nestedBspMarkers.length} candidate_trail:$_bspCandidateTrailCount missing_edges:${_missingAdjacentRelationEdges().join(',')} bsp_review:{${_bspReviewStatsText()}}';\n    });\n    if (_autoJudgeBspStepReview) {\n      _updateCurrentBspStepReviews(notify: false);\n    }\n  }\n\n""",
        'auto judge on frame index update',
    )

    text = _replace_exact(
        text,
        """              _infoButton('BSP统计', _bspReviewStatsText()),\n""",
        """              _infoButton('BSP统计', _bspReviewStatsText()),\n              _infoButton('BSP分组', _bspReviewBucketStatsText()),\n""",
        'add bucket stat info buttons',
        expected=2,
    )

    text = _replace_exact(
        text,
        """             SwitchListTile(\n               value: _showBspCandidateTrail,\n""",
        """             SwitchListTile(\n               value: _autoJudgeBspStepReview,\n               onChanged: _loading\n                   ? null\n                   : (v) {\n                       setState(() => _autoJudgeBspStepReview = v);\n                       if (v) _updateCurrentBspStepReviews(notify: false);\n                     },\n               dense: true,\n               contentPadding: EdgeInsets.zero,\n               title: const Text(\n                 '自动检查 BSP',\n                 style: TextStyle(\n                   color: Colors.white70,\n                   fontSize: 12,\n                   fontWeight: FontWeight.w700,\n                 ),\n               ),\n             ),\n             SwitchListTile(\n               value: _showBspCandidateTrail,\n""",
        'add auto judge switch in toolbar sections',
    )

    text = _replace_exact(
        text,
        """             SwitchListTile(\n                 value: _showBspCandidateTrail,\n""",
        """             SwitchListTile(\n                 value: _autoJudgeBspStepReview,\n                 onChanged: _loading\n                     ? null\n                     : (v) {\n                         setState(() => _autoJudgeBspStepReview = v);\n                         if (v) _updateCurrentBspStepReviews(notify: false);\n                       },\n                 dense: true,\n                 contentPadding: EdgeInsets.zero,\n                 title: const Text('自动检查 BSP',\n                     style: TextStyle(\n                         color: Colors.white70,\n                         fontSize: 12,\n                         fontWeight: FontWeight.w700))),\n             SwitchListTile(\n                 value: _showBspCandidateTrail,\n""",
        'add auto judge switch in unified tool panel',
    )

    if text == original:
        raise SystemExit('[abort] no changes produced')
    S13.write_text(text, encoding='utf-8')
    print('BSP auto step review patch applied.')
    print('Next: flutter analyze')


if __name__ == '__main__':
    main()
