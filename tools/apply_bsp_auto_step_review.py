from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S13 = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'


def _replace_exact(text: str, old: str, new: str, label: str, expected: int = 1) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'[abort] {label}: expected {expected} match(es), got {count}')
    return text.replace(old, new, expected)


def _replace_between(text: str, start: str, end: str, new: str, label: str) -> str:
    start_index = text.find(start)
    if start_index < 0:
        raise SystemExit(f'[abort] {label}: start marker not found')
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise SystemExit(f'[abort] {label}: end marker not found')
    return text[:start_index] + new + text[end_index:]


AUTO_REVIEW_FUNCTIONS = """  int _updateCurrentBspStepReviews({required bool notify}) {
    if (!_hasStepFrames) {
      if (notify) _showInfo('请先以 step 模式载入复盘数据。');
      return 0;
    }
    final finalSnapshot = _analysis?.snapshot.of(_activeLevel);
    if (finalSnapshot == null || finalSnapshot.bsps.isEmpty) {
      if (notify) _showInfo('最终快照没有可用于对照的 BSP。');
      return 0;
    }
    final items = _currentBspStepReviewItems;
    if (items.isEmpty) {
      if (notify) _showInfo('当前帧没有可检查的 BSP。');
      return 0;
    }
    final finalJudgeKeys = <String>{
      for (final p in finalSnapshot.bsps) _bspReviewJudgeKey(_activeLevel, p),
    };
    var changed = 0;
    setState(() {
      for (final item in items) {
        final wasCorrect = _bspStepReviewCorrectKeys.contains(item.judgeKey);
        final wasWrong = _bspStepReviewWrongKeys.contains(item.judgeKey);
        final isCorrect = finalJudgeKeys.contains(item.judgeKey);
        if (isCorrect) {
          _bspStepReviewCorrectKeys.add(item.judgeKey);
          _bspStepReviewWrongKeys.remove(item.judgeKey);
        } else {
          _bspStepReviewWrongKeys.add(item.judgeKey);
          _bspStepReviewCorrectKeys.remove(item.judgeKey);
        }
        final nowCorrect = _bspStepReviewCorrectKeys.contains(item.judgeKey);
        final nowWrong = _bspStepReviewWrongKeys.contains(item.judgeKey);
        if (wasCorrect != nowCorrect || wasWrong != nowWrong) changed++;
      }
    });
    if (notify) {
      _showInfo(
          '当前买卖点检查完成\\n${_bspReviewStatsText()}\\n${_bspReviewBucketStatsText()}');
    }
    return changed;
  }

  void _judgeCurrentBspStepReviews() =>
      _updateCurrentBspStepReviews(notify: true);

"""


def main() -> None:
    text = S13.read_text(encoding='utf-8')
    original = text

    text = _replace_exact(
        text,
        """      _panelOpen = false,
      _playing = false;
""",
        """      _panelOpen = false,
      _autoJudgeBspStepReview = true,
      _playing = false;
""",
        'add auto judge state flag',
    )

    text = _replace_exact(
        text,
        """      reason: _hasStepFrames ? 'manual_current_frame' : 'not_step_mode',
    );
  }

  String _bspReviewStatsText() {
""",
        """      reason: _hasStepFrames
          ? (_autoJudgeBspStepReview ? 'auto_step' : 'manual_current_frame')
          : 'not_step_mode',
    );
  }

  List<BspReviewBucketStats> get _bspReviewBucketStats {
    final buckets = <String, BspReviewBucketStats>{};
    for (final item in _bspStepReviewItems.values) {
      final status = _bspReviewStatusFor(item.judgeKey);
      final side = item.isBuy ? 'buy' : 'sell';
      final key = '${item.level}|$side|${item.label}';
      final current = buckets[key] ??
          BspReviewBucketStats(
            key: key,
            level: item.level,
            side: side,
            label: item.label,
          );
      buckets[key] = current.copyWith(
        appeared: current.appeared + 1,
        judged: current.judged +
            (status == BspReviewStatus.pending ? 0 : 1),
        correct: current.correct +
            (status == BspReviewStatus.correct ? 1 : 0),
        wrong: current.wrong + (status == BspReviewStatus.wrong ? 1 : 0),
      );
    }
    final rows = buckets.values.toList(growable: false);
    rows.sort((a, b) {
      if (a.level != b.level) return a.level.compareTo(b.level);
      if (a.side != b.side) return a.side.compareTo(b.side);
      return a.label.compareTo(b.label);
    });
    return rows;
  }

  String _bspReviewBucketStatsText() {
    final rows = _bspReviewBucketStats;
    if (rows.isEmpty) return 'bucket=none';
    return rows.map((row) {
      final rate = row.rate == null
          ? 'N/A'
          : '${(row.rate! * 100).toStringAsFixed(1)}%';
      return '${row.level}/${row.side}/${row.label}:${row.correct}/${row.judged}/$rate';
    }).join(' | ');
  }

  String _bspReviewStatsText() {
""",
        'insert bucket stats helpers',
    )

    text = _replace_between(
        text,
        """  void _judgeCurrentBspStepReviews() {""",
        """  List<BspPoint> _bspCandidateTrail(ChanSnapshot current) {""",
        AUTO_REVIEW_FUNCTIONS,
        'replace manual review function by markers',
    )

    text = _replace_exact(
        text,
        """        _priceOffset = 0.0;
        _chartGeneration++;
        _status = _buildStatus(a, startDate, endDate);
""",
        """        _priceOffset = 0.0;
        _bspStepReviewItems.clear();
        _bspStepReviewCorrectKeys.clear();
        _bspStepReviewWrongKeys.clear();
        _chartGeneration++;
        _status = _buildStatus(a, startDate, endDate);
""",
        'clear review state on load',
    )

    text = _replace_exact(
        text,
        """      _showMessage('S13 replay loaded');
""",
        """      if (_autoJudgeBspStepReview) {
        _updateCurrentBspStepReviews(notify: false);
      }
      _showMessage('S13 replay loaded');
""",
        'auto judge first frame after load',
    )

    text = _replace_exact(
        text,
        """      _priceOffset = 0.0;
      final c = _currentSnapshot;
""",
        """      _priceOffset = 0.0;
      _bspStepReviewItems.clear();
      _bspStepReviewCorrectKeys.clear();
      _bspStepReviewWrongKeys.clear();
      final c = _currentSnapshot;
""",
        'clear review state on mode change',
    )

    text = _replace_exact(
        text,
        """    setState(() {
      _frameIndex = next;
      _activeLevel = level;
      _viewEndIndex = null;
      _crosshairIndex = null;
      _priceScale = 1.0;
      _priceOffset = 0.0;
      final activeBiCount = f.of(level)?.bis.length ?? 0;
      _status =
          'S13 step frame ${next + 1}/${a.frames.length} active:$level active_bi:$activeBiCount loaded_config:{${_loadedChanConfigSummary(a)}} final_bi_counts:{${_biCountSummary(a.snapshot)}} current_bi_counts:{${_biCountSummary(f)}} relations:${f.relations.length} nested_markers:${_nestedBspMarkers.length} candidate_trail:$_bspCandidateTrailCount missing_edges:${_missingAdjacentRelationEdges().join(',')}';
    });
  }

""",
        """    setState(() {
      _frameIndex = next;
      _activeLevel = level;
      _viewEndIndex = null;
      _crosshairIndex = null;
      _priceScale = 1.0;
      _priceOffset = 0.0;
      final activeBiCount = f.of(level)?.bis.length ?? 0;
      _status =
          'S13 step frame ${next + 1}/${a.frames.length} active:$level active_bi:$activeBiCount loaded_config:{${_loadedChanConfigSummary(a)}} final_bi_counts:{${_biCountSummary(a.snapshot)}} current_bi_counts:{${_biCountSummary(f)}} relations:${f.relations.length} nested_markers:${_nestedBspMarkers.length} candidate_trail:$_bspCandidateTrailCount missing_edges:${_missingAdjacentRelationEdges().join(',')} bsp_review:{${_bspReviewStatsText()}}';
    });
    if (_autoJudgeBspStepReview) {
      _updateCurrentBspStepReviews(notify: false);
    }
  }

""",
        'auto judge on frame index update',
    )

    text = _replace_exact(
        text,
        """              _infoButton('BSP统计', _bspReviewStatsText()),
""",
        """              _infoButton('BSP统计', _bspReviewStatsText()),
              _infoButton('BSP分组', _bspReviewBucketStatsText()),
""",
        'add bucket stat info buttons',
        expected=2,
    )

    text = _replace_exact(
        text,
        """            SwitchListTile(
              value: _showBspCandidateTrail,
""",
        """            SwitchListTile(
              value: _autoJudgeBspStepReview,
              onChanged: _loading
                  ? null
                  : (v) {
                      setState(() => _autoJudgeBspStepReview = v);
                      if (v) _updateCurrentBspStepReviews(notify: false);
                    },
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '自动检查 BSP',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SwitchListTile(
              value: _showBspCandidateTrail,
""",
        'add auto judge switch in toolbar sections',
    )

    text = _replace_exact(
        text,
        """            SwitchListTile(
                value: _showBspCandidateTrail,
""",
        """            SwitchListTile(
                value: _autoJudgeBspStepReview,
                onChanged: _loading
                    ? null
                    : (v) {
                        setState(() => _autoJudgeBspStepReview = v);
                        if (v) _updateCurrentBspStepReviews(notify: false);
                      },
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('自动检查 BSP',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700))),
            SwitchListTile(
                value: _showBspCandidateTrail,
""",
        'add auto judge switch in unified tool panel',
    )

    if text == original:
        raise SystemExit('[abort] no changes produced')
    S13.write_text(text, encoding='utf-8')
    print('BSP auto step review patch applied.')
    print('Next: flutter analyze')


if __name__ == '__main__':
    main()
