import 'chan_config.dart';
import '../models/bi.dart';
import '../models/seg.dart';

class SegEngine {
  List<SEG> build(List<BI> bis, ChanConfig config) {
    if (bis.length < 3) return [];

    switch (config.seg.segAlgo) {
      case SegAlgo.chan:
        return _buildChanLike(bis, config);
      case SegAlgo.onePlusOne:
        return _buildPivotBreak(bis, config, reasonPrefix: '1+1');
      case SegAlgo.breakAlgo:
        return _buildPivotBreak(bis, config, reasonPrefix: 'break');
    }
  }

  /// chan.py 的 CSegListChan 使用特征序列分型确认线段。
  /// 当前 Dart 版先实现同方向峰值突破版骨架：
  /// - 线段至少包含 3 笔；
  /// - 上升线段要求结束笔相对起点向上突破；下降反之；
  /// - 尾部用 left_seg_method 收集未确认线段。
  List<SEG> _buildChanLike(List<BI> bis, ChanConfig config) {
    final result = <SEG>[];
    var start = 0;
    while (start + 2 < bis.length) {
      final next = _findNextConfirmedEnd(bis, start);
      if (next == null) break;
      final seg = _makeSeg(
        result.length,
        bis,
        start,
        next.endIndex,
        next.direction,
        isSure: true,
        reason: 'chan_fx_like',
      );
      if (seg != null) result.add(seg);
      start = next.endIndex + 1;
    }

    return _collectLeftSegs(result, bis, start, config.seg.leftMethod);
  }

  /// 轻量版 1+1 / break：使用每 3 笔的突破方向形成段。
  List<SEG> _buildPivotBreak(
    List<BI> bis,
    ChanConfig config, {
    required String reasonPrefix,
  }) {
    final result = <SEG>[];
    var start = 0;
    while (start + 2 < bis.length) {
      final end = start + 2;
      final direction = _segmentDirection(bis, start, end);
      final seg = _makeSeg(
        result.length,
        bis,
        start,
        end,
        direction,
        isSure: true,
        reason: reasonPrefix,
      );
      if (seg != null) result.add(seg);
      start = end + 1;
    }
    return _collectLeftSegs(result, bis, start, config.seg.leftMethod);
  }

  _SegEnd? _findNextConfirmedEnd(List<BI> bis, int start) {
    if (start + 2 >= bis.length) return null;

    final startPrice = bis[start].startPrice;
    for (var end = start + 2; end < bis.length; end++) {
      final direction = _segmentDirection(bis, start, end);
      if (direction == SegDirection.up && bis[end].endPrice > startPrice) {
        final peak = _findPeakEnd(bis, start + 2, end, isHigh: true) ?? end;
        return _SegEnd(endIndex: peak, direction: SegDirection.up);
      }
      if (direction == SegDirection.down && bis[end].endPrice < startPrice) {
        final peak = _findPeakEnd(bis, start + 2, end, isHigh: false) ?? end;
        return _SegEnd(endIndex: peak, direction: SegDirection.down);
      }
    }
    return null;
  }

  SegDirection _segmentDirection(List<BI> bis, int start, int end) {
    final begin = bis[start].startPrice;
    final finish = bis[end].endPrice;
    if (finish >= begin) return SegDirection.up;
    return SegDirection.down;
  }

  int? _findPeakEnd(List<BI> bis, int from, int to, {required bool isHigh}) {
    if (from > to) return null;
    int? best;
    double? bestVal;
    for (var i = from; i <= to; i++) {
      final b = bis[i];
      if (isHigh && !b.isUp) continue;
      if (!isHigh && !b.isDown) continue;
      final v = b.endPrice;
      if (best == null || (isHigh ? v >= bestVal! : v <= bestVal!)) {
        best = i;
        bestVal = v;
      }
    }
    return best;
  }

  List<SEG> _collectLeftSegs(
    List<SEG> confirmed,
    List<BI> bis,
    int leftStart,
    LeftSegMethod method,
  ) {
    final result = [...confirmed];
    final start = result.isEmpty ? 0 : result.last.endBiIndex + 1;
    if (start >= bis.length) return result;

    final leftCount = bis.length - start;
    if (leftCount < 2) return result;

    if (method == LeftSegMethod.all || result.isEmpty) {
      final direction = _segmentDirection(bis, start, bis.length - 1);
      final seg = _makeSeg(
        result.length,
        bis,
        start,
        bis.length - 1,
        direction,
        isSure: false,
        reason: 'left_all',
      );
      if (seg != null) result.add(seg);
      return result;
    }

    final last = result.last;
    final needHigh = last.isDown;
    final peak = _findPeakEnd(bis, start, bis.length - 1, isHigh: needHigh);
    if (peak != null && peak - start >= 1) {
      final seg = _makeSeg(
        result.length,
        bis,
        start,
        peak,
        needHigh ? SegDirection.up : SegDirection.down,
        isSure: false,
        reason: needHigh ? 'left_peak_high' : 'left_peak_low',
      );
      if (seg != null) result.add(seg);
    } else {
      final direction = _segmentDirection(bis, start, bis.length - 1);
      final seg = _makeSeg(
        result.length,
        bis,
        start,
        bis.length - 1,
        direction,
        isSure: false,
        reason: 'left_fallback',
      );
      if (seg != null) result.add(seg);
    }
    return result;
  }

  SEG? _makeSeg(
    int index,
    List<BI> bis,
    int start,
    int end,
    SegDirection direction, {
    required bool isSure,
    required String reason,
  }) {
    if (start < 0 || end >= bis.length || end <= start) return null;
    final list = List<BI>.unmodifiable(bis.sublist(start, end + 1));
    return SEG(
      index: index,
      startBi: bis[start],
      endBi: bis[end],
      direction: direction,
      isSure: isSure && end - start >= 2,
      reason: reason,
      biList: list,
    );
  }
}

class _SegEnd {
  final int endIndex;
  final SegDirection direction;

  const _SegEnd({required this.endIndex, required this.direction});
}
