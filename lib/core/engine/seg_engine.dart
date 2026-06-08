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

  List<SEG> _buildChanLike(List<BI> bis, ChanConfig config) {
    final result = <SEG>[];

    void calSegSure(int beginIdx) {
      if (beginIdx < 0) beginIdx = 0;
      if (beginIdx >= bis.length) return;

      final upEigen = _EigenFx(SegDirection.up);
      final downEigen = _EigenFx(SegDirection.down);
      SegDirection? lastSegDir = result.isEmpty ? null : result.last.direction;

      for (var i = beginIdx; i < bis.length; i++) {
        final bi = bis[i];
        _EigenFx? fxEigen;

        if (bi.isDown && lastSegDir != SegDirection.up) {
          if (upEigen.add(bi, bis)) fxEigen = upEigen;
        } else if (bi.isUp && lastSegDir != SegDirection.down) {
          if (downEigen.add(bi, bis)) fxEigen = downEigen;
        }

        if (result.isEmpty) {
          if (upEigen.hasSecondElement && bi.isDown) {
            lastSegDir = SegDirection.down;
            downEigen.clear();
          } else if (downEigen.hasSecondElement && bi.isUp) {
            lastSegDir = SegDirection.up;
            upEigen.clear();
          }

          if (!upEigen.hasSecondElement && lastSegDir == SegDirection.down && bi.isDown) {
            lastSegDir = null;
          } else if (!downEigen.hasSecondElement && lastSegDir == SegDirection.up && bi.isUp) {
            lastSegDir = null;
          }
        }

        if (fxEigen != null) {
          _treatFxEigen(result, bis, fxEigen, beginIdx, calSegSure);
          return;
        }
      }
    }

    calSegSure(0);
    return _collectLeftSegs(result, bis, config.seg.leftMethod);
  }

  void _treatFxEigen(
    List<SEG> result,
    List<BI> bis,
    _EigenFx fxEigen,
    int beginIdx,
    void Function(int beginIdx) calSegSure,
  ) {
    final test = fxEigen.canBeEnd(bis);
    final endBiIdx = fxEigen.peakBiIndex().clamp(0, bis.length - 1).toInt();

    if (test == true || test == null) {
      final isTrue = test != null;
      final ok = _addNewSeg(
        result,
        bis,
        endBiIdx,
        isSure: isTrue,
        reason: isTrue ? 'chan_eigenfx' : 'chan_eigenfx_tail',
      );
      if (!ok) {
        calSegSure((endBiIdx + 1).clamp(beginIdx + 1, bis.length).toInt());
        return;
      }
      if (isTrue) {
        calSegSure((endBiIdx + 1).clamp(beginIdx + 1, bis.length).toInt());
      }
      return;
    }

    final retry = fxEigen.secondElementStartIndex;
    calSegSure(retry > beginIdx ? retry : beginIdx + 1);
  }

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
    return _collectLeftSegs(result, bis, config.seg.leftMethod);
  }

  SegDirection _segmentDirection(List<BI> bis, int start, int end) {
    final begin = bis[start].startPrice;
    final finish = bis[end].endPrice;
    if (finish >= begin) return SegDirection.up;
    return SegDirection.down;
  }

  SegDirection _directionFromBi(BI bi) => bi.isUp ? SegDirection.up : SegDirection.down;

  bool _addNewSeg(
    List<SEG> result,
    List<BI> bis,
    int endBiIdx, {
    required bool isSure,
    SegDirection? segDir,
    required String reason,
  }) {
    if (endBiIdx < 0 || endBiIdx >= bis.length) return false;
    final startBiIdx = result.isEmpty ? 0 : result.last.endBiIndex + 1;
    if (startBiIdx >= bis.length) return false;
    if (isSure ? endBiIdx <= startBiIdx : endBiIdx < startBiIdx) return false;

    final direction = segDir ?? _directionFromBi(bis[endBiIdx]);
    if (isSure && !_endValueIsValid(bis, startBiIdx, endBiIdx, direction)) {
      return false;
    }

    final seg = _makeSeg(
      result.length,
      bis,
      startBiIdx,
      endBiIdx,
      direction,
      isSure: isSure,
      reason: reason,
    );
    if (seg == null) return false;
    result.add(seg);
    return true;
  }

  bool _endValueIsValid(List<BI> bis, int start, int end, SegDirection direction) {
    final begin = bis[start].startPrice;
    final finish = bis[end].endPrice;
    return direction == SegDirection.up ? begin <= finish : begin >= finish;
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
      if (i >= 2) {
        final prePre = bis[i - 2].endPrice;
        if ((isHigh && prePre > v) || (!isHigh && prePre < v)) continue;
      }
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
    LeftSegMethod method,
  ) {
    final result = [...confirmed];
    if (bis.length < 3) return result;

    if (result.isEmpty) {
      _collectFirstSeg(result, bis, method);
      return result;
    }

    _collectRemainingSegs(result, bis, method);
    return result;
  }

  void _collectFirstSeg(List<SEG> result, List<BI> bis, LeftSegMethod method) {
    if (method == LeftSegMethod.all) {
      _addNewSeg(
        result,
        bis,
        bis.length - 1,
        isSure: false,
        segDir: _segmentDirection(bis, 0, bis.length - 1),
        reason: '0seg_collect_all',
      );
      return;
    }

    final first = bis.first.startPrice;
    final high = bis.map((e) => e.high).reduce((a, b) => a >= b ? a : b);
    final low = bis.map((e) => e.low).reduce((a, b) => a <= b ? a : b);
    final findHigh = (high - first).abs() >= (low - first).abs();
    final peak = _findPeakEnd(bis, 0, bis.length - 1, isHigh: findHigh);
    final end = peak ?? bis.length - 1;
    _addNewSeg(
      result,
      bis,
      end,
      isSure: false,
      segDir: findHigh ? SegDirection.up : SegDirection.down,
      reason: findHigh ? '0seg_find_high' : '0seg_find_low',
    );
    _collectLeftAsSeg(result, bis);
  }

  void _collectRemainingSegs(List<SEG> result, List<BI> bis, LeftSegMethod method) {
    if (result.isEmpty) return;
    final lastBi = bis.last;
    final lastSegEndBi = result.last.endBi;
    if (lastBi.index - lastSegEndBi.index < 3) return;

    if (lastSegEndBi.isDown && lastBi.endPrice <= lastSegEndBi.endPrice) {
      final peak = _findPeakEnd(
        bis,
        lastSegEndBi.index + 3,
        bis.length - 1,
        isHigh: true,
      );
      if (peak != null) {
        _addNewSeg(
          result,
          bis,
          peak,
          isSure: false,
          segDir: SegDirection.up,
          reason: 'collectleft_find_high_force',
        );
        _collectRemainingSegs(result, bis, method);
      }
      return;
    }

    if (lastSegEndBi.isUp && lastBi.endPrice >= lastSegEndBi.endPrice) {
      final peak = _findPeakEnd(
        bis,
        lastSegEndBi.index + 3,
        bis.length - 1,
        isHigh: false,
      );
      if (peak != null) {
        _addNewSeg(
          result,
          bis,
          peak,
          isSure: false,
          segDir: SegDirection.down,
          reason: 'collectleft_find_low_force',
        );
        _collectRemainingSegs(result, bis, method);
      }
      return;
    }

    if (method == LeftSegMethod.all) {
      _collectLeftAsSeg(result, bis);
    } else {
      _collectLeftSegPeakMethod(result, bis);
    }
  }

  void _collectLeftSegPeakMethod(List<SEG> result, List<BI> bis) {
    if (result.isEmpty) return;
    var lastSegEndBi = result.last.endBi;
    var findNewSeg = false;

    if (lastSegEndBi.isDown) {
      final peak = _findPeakEnd(
        bis,
        lastSegEndBi.index + 3,
        bis.length - 1,
        isHigh: true,
      );
      if (peak != null && peak - lastSegEndBi.index >= 3) {
        _addNewSeg(
          result,
          bis,
          peak,
          isSure: false,
          segDir: SegDirection.up,
          reason: 'collectleft_find_high',
        );
        findNewSeg = true;
      }
    } else {
      final peak = _findPeakEnd(
        bis,
        lastSegEndBi.index + 3,
        bis.length - 1,
        isHigh: false,
      );
      if (peak != null && peak - lastSegEndBi.index >= 3) {
        _addNewSeg(
          result,
          bis,
          peak,
          isSure: false,
          segDir: SegDirection.down,
          reason: 'collectleft_find_low',
        );
        findNewSeg = true;
      }
    }

    if (findNewSeg) {
      lastSegEndBi = result.last.endBi;
      if (bis.last.index - lastSegEndBi.index >= 3) {
        _collectLeftSegPeakMethod(result, bis);
      }
    } else {
      _collectLeftAsSeg(result, bis);
    }
  }

  void _collectLeftAsSeg(List<SEG> result, List<BI> bis) {
    if (result.isEmpty) return;
    final lastBi = bis.last;
    final lastSegEndBi = result.last.endBi;
    if (lastSegEndBi.index + 1 >= bis.length) return;

    final endIdx = lastSegEndBi.direction == lastBi.direction
        ? lastBi.index - 1
        : lastBi.index;
    _addNewSeg(
      result,
      bis,
      endIdx,
      isSure: false,
      reason: lastSegEndBi.direction == lastBi.direction
          ? 'collect_left_1'
          : 'collect_left_0',
    );
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
    if (start < 0 || end >= bis.length) return null;
    if (isSure ? end <= start : end < start) return null;
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

enum _KlineDir { up, down, combine, included }

enum _EigenFxType { unknown, top, bottom }

class _EigenElement {
  final List<BI> items = [];
  _KlineDir dir;
  double high;
  double low;
  _EigenFxType fx = _EigenFxType.unknown;
  bool gap = false;

  _EigenElement(BI bi, this.dir)
      : high = bi.high,
        low = bi.low {
    items.add(bi);
  }

  BI get first => items.first;
  BI get last => items.last;

  _KlineDir tryAdd(BI bi, {bool excludeIncluded = false, int? allowTopEqual}) {
    final relation = _testCombine(bi, excludeIncluded: excludeIncluded, allowTopEqual: allowTopEqual);
    if (relation == _KlineDir.combine) {
      items.add(bi);
      if (dir == _KlineDir.up) {
        high = _max(high, bi.high);
        low = _max(low, bi.low);
      } else if (dir == _KlineDir.down) {
        high = _min(high, bi.high);
        low = _min(low, bi.low);
      }
    }
    return relation;
  }

  _KlineDir _testCombine(
    BI bi, {
    required bool excludeIncluded,
    int? allowTopEqual,
  }) {
    if (high >= bi.high && low <= bi.low) return _KlineDir.combine;
    if (high <= bi.high && low >= bi.low) {
      if (allowTopEqual == 1 && high == bi.high && low > bi.low) {
        return _KlineDir.down;
      }
      if (allowTopEqual == -1 && low == bi.low && high < bi.high) {
        return _KlineDir.up;
      }
      return excludeIncluded ? _KlineDir.included : _KlineDir.combine;
    }
    if (high > bi.high && low > bi.low) return _KlineDir.down;
    if (high < bi.high && low < bi.low) return _KlineDir.up;

    return dir == _KlineDir.up ? _KlineDir.up : _KlineDir.down;
  }

  void updateFx(_EigenElement pre, _EigenElement next, {required bool excludeIncluded, int? allowTopEqual}) {
    fx = _EigenFxType.unknown;
    if (excludeIncluded) {
      if (pre.high < high && next.high <= high && next.low < low) {
        if (allowTopEqual == 1 || next.high < high) fx = _EigenFxType.top;
      } else if (next.high > high && pre.low > low && next.low >= low) {
        if (allowTopEqual == -1 || next.low > low) fx = _EigenFxType.bottom;
      }
    } else if (pre.high < high && next.high < high && pre.low < low && next.low < low) {
      fx = _EigenFxType.top;
    } else if (pre.high > high && next.high > high && pre.low > low && next.low > low) {
      fx = _EigenFxType.bottom;
    }

    if ((fx == _EigenFxType.top && pre.high < low) ||
        (fx == _EigenFxType.bottom && pre.low > high)) {
      gap = true;
    }
  }

  int peakBiIndex() {
    if (items.isEmpty) return 0;
    if (first.isUp) {
      var best = first;
      for (final bi in items) {
        if (bi.low <= best.low) best = bi;
      }
      return best.index - 1;
    }

    var best = first;
    for (final bi in items) {
      if (bi.high >= best.high) best = bi;
    }
    return best.index - 1;
  }

  double _max(double a, double b) => a >= b ? a : b;
  double _min(double a, double b) => a <= b ? a : b;
}

class _EigenFx {
  final SegDirection direction;
  final bool excludeIncluded;
  late final _KlineDir klDir;
  final List<_EigenElement?> ele = [null, null, null];
  final List<BI> lst = [];
  bool actualBreakFlag = true;

  _EigenFx(this.direction, {this.excludeIncluded = true}) {
    klDir = direction == SegDirection.up ? _KlineDir.up : _KlineDir.down;
  }

  bool get hasSecondElement => ele[1] != null;
  bool get isUp => direction == SegDirection.up;
  bool get isDown => direction == SegDirection.down;

  int get secondElementStartIndex => ele[1]?.first.index ?? (lst.isNotEmpty ? lst.first.index : 0);

  void clear() {
    ele[0] = null;
    ele[1] = null;
    ele[2] = null;
    lst.clear();
    actualBreakFlag = true;
  }

  bool add(BI bi, List<BI> allBis) {
    lst.add(bi);
    if (ele[0] == null) return _treatFirstEle(bi);
    if (ele[1] == null) return _treatSecondEle(bi, allBis);
    if (ele[2] == null) return _treatThirdEle(bi, allBis);
    return false;
  }

  bool _treatFirstEle(BI bi) {
    ele[0] = _EigenElement(bi, klDir);
    return false;
  }

  bool _treatSecondEle(BI bi, List<BI> allBis) {
    final first = ele[0]!;
    final combineDir = first.tryAdd(bi, excludeIncluded: excludeIncluded);
    if (combineDir != _KlineDir.combine) {
      ele[1] = _EigenElement(bi, klDir);
      final second = ele[1]!;
      if ((isUp && second.high < first.high) ||
          (isDown && second.low > first.low)) {
        return reset(allBis);
      }
    }
    return false;
  }

  bool _treatThirdEle(BI bi, List<BI> allBis) {
    final first = ele[0]!;
    final second = ele[1]!;
    final allowTopEqual = excludeIncluded ? (bi.isDown ? 1 : -1) : null;
    final combineDir = second.tryAdd(bi, allowTopEqual: allowTopEqual);
    if (combineDir == _KlineDir.combine) return false;

    final nextDir = combineDir == _KlineDir.included ? klDir : combineDir;
    ele[2] = _EigenElement(bi, nextDir);
    if (!_actualBreak(allBis)) return reset(allBis);

    second.updateFx(
      first,
      ele[2]!,
      excludeIncluded: excludeIncluded,
      allowTopEqual: allowTopEqual,
    );
    final fx = second.fx;
    final isFx = (isUp && fx == _EigenFxType.top) ||
        (isDown && fx == _EigenFxType.bottom);
    return isFx ? true : reset(allBis);
  }

  bool reset(List<BI> allBis) {
    final tmp = List<BI>.from(lst.skip(1));
    clear();
    for (final bi in tmp) {
      if (add(bi, allBis)) return true;
    }
    return false;
  }

  bool? canBeEnd(List<BI> allBis) {
    final mid = ele[1];
    if (mid == null) return false;
    if (mid.gap) {
      final endBiIdx = peakBiIndex().clamp(0, allBis.length - 1).toInt();
      final beginIdx = endBiIdx + 2;
      if (beginIdx >= allBis.length) return null;
      return _findRevertFx(allBis, beginIdx);
    }
    if (!actualBreakFlag) return null;
    return true;
  }

  bool? _findRevertFx(List<BI> allBis, int beginIdx) {
    if (beginIdx >= allBis.length) return null;
    final firstBi = allBis[beginIdx];
    final revertDirection = firstBi.isDown ? SegDirection.up : SegDirection.down;
    final eigenFx = _EigenFx(revertDirection, excludeIncluded: true);

    for (var i = beginIdx; i < allBis.length; i += 2) {
      if (eigenFx.add(allBis[i], allBis)) {
        while (true) {
          var test = eigenFx.canBeEnd(allBis);
          if (!eigenFx.actualBreakFlag) test = null;
          if (test == true || test == null) return test;
          if (!eigenFx.reset(allBis)) break;
        }
      }
    }
    return null;
  }

  int peakBiIndex() {
    final mid = ele[1];
    if (mid == null) return 0;
    return mid.peakBiIndex();
  }

  bool _actualBreak(List<BI> allBis) {
    if (!excludeIncluded) return true;
    final second = ele[1]!;
    final third = ele[2]!;

    if ((isUp && third.low < second.last.low) ||
        (isDown && third.high > second.last.high)) {
      return true;
    }

    final ele2Bi = third.first;
    final next2Index = ele2Bi.index + 2;
    if (next2Index < allBis.length) {
      final next2 = allBis[next2Index];
      if (ele2Bi.isDown) {
        if (next2.low < ele2Bi.low) return true;
        actualBreakFlag = false;
        return true;
      }
      if (ele2Bi.isUp) {
        if (next2.high > ele2Bi.high) return true;
        actualBreakFlag = false;
        return true;
      }
    } else {
      actualBreakFlag = false;
      return true;
    }
    return false;
  }
}
