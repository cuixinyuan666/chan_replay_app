import 'dart:math' as math;

import '../../core/models/rhythm.dart';

class S13RhythmViewportSelection {
  final List<RhythmLine> lines;
  final List<RhythmHit> hits;
  final int hiddenLineCount;
  final int hiddenHitCount;

  const S13RhythmViewportSelection({
    required this.lines,
    required this.hits,
    required this.hiddenLineCount,
    required this.hiddenHitCount,
  });
}

class S13RhythmViewportSelector {
  static const int defaultMaxLines = 120;
  static const int defaultMaxHits = 80;

  static S13RhythmViewportSelection select({
    required List<RhythmLine> lines,
    required List<RhythmHit> hits,
    required int totalBars,
    required int? viewEndIndex,
    required int windowSize,
    int maxLines = defaultMaxLines,
    int maxHits = defaultMaxHits,
  }) {
    if (totalBars <= 0) {
      return S13RhythmViewportSelection(
        lines: const <RhythmLine>[],
        hits: const <RhythmHit>[],
        hiddenLineCount: lines.length,
        hiddenHitCount: hits.length,
      );
    }
    final end = (viewEndIndex ?? totalBars - 1).clamp(0, totalBars - 1).toInt();
    final safeWindow = math.max(1, windowSize);
    final start = math.max(0, end - safeWindow + 1);
    final margin = math.max(8, (safeWindow * 0.35).round());
    final minRaw = math.max(0, start - margin);
    final maxRaw = math.min(totalBars - 1, end + margin);

    final visibleLines = lines
        .where((line) => _lineTouchesRange(line, minRaw, maxRaw))
        .toList(growable: false)
      ..sort((a, b) => _linePriority(a, b, start, end));
    final visibleHits = hits
        .where((hit) => hit.rawIndex >= minRaw && hit.rawIndex <= maxRaw)
        .toList(growable: false)
      ..sort((a, b) => _hitPriority(a, b, end));

    final selectedLines = visibleLines.take(math.max(0, maxLines)).toList(growable: false);
    final selectedHits = visibleHits.take(math.max(0, maxHits)).toList(growable: false);
    return S13RhythmViewportSelection(
      lines: selectedLines,
      hits: selectedHits,
      hiddenLineCount: math.max(0, visibleLines.length - selectedLines.length),
      hiddenHitCount: math.max(0, visibleHits.length - selectedHits.length),
    );
  }

  static bool _lineTouchesRange(RhythmLine line, int minRaw, int maxRaw) {
    final left = math.min(line.x1, line.x2);
    final right = math.max(line.x1, line.x2);
    return right >= minRaw && left <= maxRaw;
  }

  static int _linePriority(RhythmLine a, RhythmLine b, int start, int end) {
    final aInWindow = _lineTouchesRange(a, start, end) ? 0 : 1;
    final bInWindow = _lineTouchesRange(b, start, end) ? 0 : 1;
    if (aInWindow != bInWindow) return aInWindow.compareTo(bInWindow);
    final layer = a.layer.compareTo(b.layer);
    if (layer != 0) return layer;
    final ad = _lineDistanceToEnd(a, end);
    final bd = _lineDistanceToEnd(b, end);
    if (ad != bd) return ad.compareTo(bd);
    return a.x1.compareTo(b.x1);
  }

  static int _lineDistanceToEnd(RhythmLine line, int end) {
    final left = math.min(line.x1, line.x2);
    final right = math.max(line.x1, line.x2);
    if (end >= left && end <= right) return 0;
    return math.min((left - end).abs(), (right - end).abs());
  }

  static int _hitPriority(RhythmHit a, RhythmHit b, int end) {
    final ad = (a.rawIndex - end).abs();
    final bd = (b.rawIndex - end).abs();
    if (ad != bd) return ad.compareTo(bd);
    return b.rawIndex.compareTo(a.rawIndex);
  }
}
