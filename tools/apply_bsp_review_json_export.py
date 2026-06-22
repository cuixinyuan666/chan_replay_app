from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S13 = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'


def _replace_exact(text: str, old: str, new: str, label: str, expected: int = 1) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'[abort] {label}: expected {expected} match(es), got {count}')
    return text.replace(old, new, expected)


def _insert_before(text: str, marker: str, insertion: str, label: str) -> str:
    index = text.find(marker)
    if index < 0:
        raise SystemExit(f'[abort] {label}: marker not found')
    return text[:index] + insertion + text[index:]


REPORT_HELPERS = '''  List<BspStepReviewItem> get _allBspStepReviewItems {
    final rows = _bspStepReviewItems.values
        .map((item) => item.copyWith(status: _bspReviewStatusFor(item.judgeKey)))
        .toList(growable: false);
    rows.sort((a, b) {
      if (a.level != b.level) return a.level.compareTo(b.level);
      if (a.displayRawIndex != b.displayRawIndex) {
        return a.displayRawIndex.compareTo(b.displayRawIndex);
      }
      return a.judgeKey.compareTo(b.judgeKey);
    });
    return rows;
  }

  Map<String, dynamic> _bspReviewReportJson() {
    final stats = _bspReviewStats;
    return <String, dynamic>{
      'schema': 'chan_replay_app.bsp_review_report.v1',
      'generated_at': DateTime.now().toIso8601String(),
      'symbol': _symbolController.text.trim(),
      'market': _marketController.text.trim().toUpperCase(),
      'mode': _mode,
      'active_level': _activeLevel,
      'selected_levels': _normalizedLevels,
      'loaded_levels': _loadedLevels,
      'runtime_path': RuntimePathController.current.wireName,
      'window': _effectiveWindowText,
      'frame_index': _safeFrameIndex,
      'frame_count': _frameCount,
      'auto_judge': _autoJudgeBspStepReview,
      'judge_key': 'level|rawIndex|side',
      'stats': <String, dynamic>{
        'appeared': stats.appeared,
        'judged': stats.judged,
        'correct': stats.correct,
        'wrong': stats.wrong,
        'rate': stats.rate,
        'reason': stats.reason,
      },
      'buckets': <Map<String, dynamic>>[
        for (final row in _bspReviewBucketStats)
          <String, dynamic>{
            'key': row.key,
            'level': row.level,
            'side': row.side,
            'label': row.label,
            'appeared': row.appeared,
            'judged': row.judged,
            'correct': row.correct,
            'wrong': row.wrong,
            'rate': row.rate,
          },
      ],
      'items': <Map<String, dynamic>>[
        for (final item in _allBspStepReviewItems)
          <String, dynamic>{
            'key': item.key,
            'judge_key': item.judgeKey,
            'level': item.level,
            'display_raw_index': item.displayRawIndex,
            'anchor_raw_index': item.anchorRawIndex,
            'side': item.isBuy ? 'buy' : 'sell',
            'label': item.label,
            'display_label': item.displayLabel,
            'first_frame_index': item.firstFrameIndex,
            'status': item.status.name,
          },
      ],
    };
  }

  String _bspReviewReportText() {
    final stats = _bspReviewStats;
    final rate = stats.rate == null
        ? 'N/A'
        : '${(stats.rate! * 100).toStringAsFixed(1)}%';
    final buffer = StringBuffer()
      ..writeln('BSP_STEP_REVIEW_REPORT')
      ..writeln('generated_at=${DateTime.now().toIso8601String()}')
      ..writeln('symbol=${_symbolController.text.trim()}')
      ..writeln('market=${_marketController.text.trim().toUpperCase()}')
      ..writeln('mode=$_mode')
      ..writeln('active_level=$_activeLevel')
      ..writeln('frame=${_safeFrameIndex + 1}/$_frameCount')
      ..writeln('auto_judge=$_autoJudgeBspStepReview')
      ..writeln('judge_key=level|rawIndex|side')
      ..writeln('stats appeared=${stats.appeared} judged=${stats.judged} correct=${stats.correct} wrong=${stats.wrong} rate=$rate')
      ..writeln('buckets=${_bspReviewBucketStatsText()}')
      ..writeln('items:');
    for (final item in _allBspStepReviewItems) {
      buffer.writeln('${item.status.name} ${item.level} raw=${item.displayRawIndex} ${item.isBuy ? 'buy' : 'sell'} ${item.label} ${item.judgeKey}');
    }
    return buffer.toString();
  }

  Future<void> _copyBspReviewReport() async {
    final report = _bspReviewReportText();
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    _showInfo('BSP 检查报告已复制\\n${report.split('\\n').take(10).join('\\n')}');
  }

  Future<void> _exportBspReviewReportJson() async {
    final reportText = _bspReviewReportText();
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: reportText));
      if (!mounted) return;
      _showInfo('Web 环境暂不写本地文件，已复制 BSP 检查报告。');
      return;
    }
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/chan_replay_bsp_reports');
      if (!await dir.exists()) await dir.create(recursive: true);
      final symbol = _symbolController.text.trim().isEmpty
          ? 'UNKNOWN'
          : _symbolController.text.trim();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('.', '');
      final file = File('${dir.path}/bsp_review_${symbol}_${_activeLevel}_$stamp.json');
      final jsonText = const JsonEncoder.withIndent('  ').convert(_bspReviewReportJson());
      await file.writeAsString(jsonText);
      if (!mounted) return;
      _showInfo('BSP 检查 JSON 已导出\\n${file.path}');
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: reportText));
      if (!mounted) return;
      _showInfo('BSP 报告导出失败，已复制文本报告。错误：$e');
    }
  }

'''


def main() -> None:
    text = S13.read_text(encoding='utf-8')
    original = text

    text = _replace_exact(
        text,
        """import 'dart:async';
import 'dart:math' as math;
""",
        """import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
""",
        'add report export dart imports',
    )

    text = _replace_exact(
        text,
        """import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
""",
        """import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
""",
        'add path_provider import',
    )

    text = _insert_before(
        text,
        """  List<BspPoint> _bspCandidateTrail(ChanSnapshot current) {""",
        REPORT_HELPERS,
        'insert bsp report helpers',
    )

    text = _replace_exact(
        text,
        """              _infoButton('BSP统计', _bspReviewStatsText()),
              _infoButton('BSP分组', _bspReviewBucketStatsText()),
""",
        """              _infoButton('BSP统计', _bspReviewStatsText()),
              _infoButton('BSP分组', _bspReviewBucketStatsText()),
              OutlinedButton.icon(
                onPressed: _bspStepReviewItems.isEmpty
                    ? null
                    : _copyBspReviewReport,
                icon: const Icon(Icons.copy_all, size: 16),
                label: const Text('复制BSP报告'),
              ),
              OutlinedButton.icon(
                onPressed: _bspStepReviewItems.isEmpty
                    ? null
                    : _exportBspReviewReportJson,
                icon: const Icon(Icons.save_alt, size: 16),
                label: const Text('导出BSP JSON'),
              ),
""",
        'add report buttons to replay controls',
        expected=2,
    )

    if text == original:
        raise SystemExit('[abort] no changes produced')
    S13.write_text(text, encoding='utf-8')
    print('BSP review JSON export patch applied.')
    print('Next: flutter analyze')


if __name__ == '__main__':
    main()
