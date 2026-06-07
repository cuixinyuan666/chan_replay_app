import 'chan_config.dart';
import '../models/bi.dart';
import '../models/seg.dart';
import '../models/zs.dart';

class ZsEngine {
  List<ZS> build(List<BI> bis, ChanConfig config, {List<SEG> segs = const []}) {
    if (bis.isEmpty) return [];

    final ctx = _ZsBuildContext(config);
    switch (config.zs.zsAlgo) {
      case ZsAlgo.normal:
        ctx.calNormal(bis, segs);
        break;
      case ZsAlgo.overSeg:
        ctx.calOverSeg(bis);
        break;
      case ZsAlgo.auto:
        ctx.calAuto(bis, segs);
        break;
    }
    return ctx.output();
  }
}

class _ZsBuildContext {
  final ChanConfig config;
  final List<_WorkZs> _zss = [];
  final List<BI> _freeItems = [];

  _ZsBuildContext(this.config);

  void calNormal(List<BI> bis, List<SEG> segs) {
    if (segs.isEmpty) return;

    for (final seg in segs) {
      _clearFreeList();
      final segBis = bis
          .where((bi) => bi.index >= seg.startBiIndex && bi.index <= seg.endBiIndex)
          .toList();
      _addZsFromBiRange(segBis, seg, seg.isSure);
    }

    // Vespa：处理未生成新线段的部分。这里以最后一段结束笔之后的剩余 BI 作为未确认尾部。
    final lastSeg = segs.last;
    final tail = bis.where((bi) => bi.index > lastSeg.endBiIndex).toList();
    if (tail.isNotEmpty) {
      _clearFreeList();
      final virtualDir = _revertSegDir(lastSeg.direction);
      _addZsFromBiRange(tail, null, false, virtualSegDir: virtualDir);
    }
  }

  void calOverSeg(List<BI> bis) {
    assert(!config.zs.oneBiZs);
    _clearFreeList();
    for (var i = 0; i < bis.length; i++) {
      final prev = i > 0 ? bis[i - 1] : null;
      final next = i + 1 < bis.length ? bis[i + 1] : null;
      _updateOverSegZs(bis[i], prev: prev, next: next, isSure: true);
    }
  }

  void calAuto(List<BI> bis, List<SEG> segs) {
    if (segs.isEmpty) {
      calOverSeg(bis);
      return;
    }

    var sureSegAppear = false;
    final existSureSeg = segs.any((seg) => seg.isSure);
    for (var segIdx = 0; segIdx < segs.length; segIdx++) {
      final seg = segs[segIdx];
      if (seg.isSure) sureSegAppear = true;
      if (seg.isSure || (!sureSegAppear && existSureSeg)) {
        _clearFreeList();
        final segBis = bis
            .where((bi) => bi.index >= seg.startBiIndex && bi.index <= seg.endBiIndex)
            .toList();
        _addZsFromBiRange(segBis, seg, seg.isSure);
      } else {
        _clearFreeList();
        final start = seg.startBiIndex;
        final tail = bis.where((bi) => bi.index >= start).toList();
        for (var i = 0; i < tail.length; i++) {
          final globalIdx = bis.indexWhere((b) => b.index == tail[i].index);
          final prev = globalIdx > 0 ? bis[globalIdx - 1] : null;
          final next = globalIdx + 1 < bis.length ? bis[globalIdx + 1] : null;
          _updateOverSegZs(tail[i], prev: prev, next: next, isSure: tail[i].index <= seg.endBiIndex && seg.isSure);
        }
        break;
      }
    }
  }

  void _addZsFromBiRange(
    List<BI> segBis,
    SEG? seg,
    bool segIsSure, {
    SegDirection? virtualSegDir,
  }) {
    var dealBiCnt = 0;
    final segDir = virtualSegDir ?? seg!.direction;
    for (final bi in segBis) {
      if (_sameDir(bi, segDir)) continue;
      if (dealBiCnt < 1) {
        // Vespa: 防止 try_add_to_end 执行到上一个线段的中枢里面去。
        _addToFreeList(bi, segIsSure, ZsAlgo.normal, segIndex: seg?.index);
        dealBiCnt += 1;
      } else {
        _updateNormal(bi, segIsSure, segIndex: seg?.index);
      }
    }
  }

  void _updateNormal(BI bi, bool isSure, {int? segIndex}) {
    if (_freeItems.isEmpty && _tryAddToLastEnd(bi)) {
      _tryCombine();
      return;
    }
    _addToFreeList(bi, isSure, ZsAlgo.normal, segIndex: segIndex);
  }

  void _updateOverSegZs(
    BI bi, {
    required BI? prev,
    required BI? next,
    required bool isSure,
  }) {
    if (_zss.isNotEmpty && _freeItems.isEmpty) {
      final last = _zss.last;
      if (next == null) return;
      if (bi.index - last.endBi.index <= 1 && last.inRange(next) && last.tryAddToEnd(bi)) {
        _tryCombine();
        return;
      }
    }

    if (_zss.isNotEmpty && _freeItems.isEmpty) {
      final last = _zss.last;
      if (last.inRange(bi) && bi.index - last.endBi.index <= 1) {
        return;
      }
    }
    _addToFreeList(bi, isSure, ZsAlgo.overSeg, segIndex: null);
  }

  void _addToFreeList(BI item, bool isSure, ZsAlgo zsAlgo, {int? segIndex}) {
    if (_freeItems.isNotEmpty && item.index == _freeItems.last.index) {
      _freeItems.removeLast();
    }
    _freeItems.add(item);
    final zs = _tryConstructZs(_freeItems, isSure, zsAlgo, segIndex: segIndex);
    if (zs != null && zs.beginBi.index > 0) {
      _zss.add(zs);
      _clearFreeList();
      _tryCombine();
    }
  }

  _WorkZs? _tryConstructZs(
    List<BI> source,
    bool isSure,
    ZsAlgo zsAlgo, {
    required int? segIndex,
  }) {
    var lst = List<BI>.from(source);
    if (zsAlgo == ZsAlgo.normal) {
      if (!config.zs.oneBiZs) {
        if (lst.length == 1) return null;
        lst = lst.sublist(lst.length - 2);
      } else {
        lst = [lst.last];
      }
    } else if (zsAlgo == ZsAlgo.overSeg) {
      if (lst.length < 3) return null;
      lst = lst.sublist(lst.length - 3);
      // Vespa 中这里还检查 parent_seg.dir；当前 Dart BI 不持有 parent_seg，因此交由 normal 模式严格按 SEG 处理。
    }

    final upper = lst.map((e) => e.high).reduce(_min);
    final lower = lst.map((e) => e.low).reduce(_max);
    if (upper <= lower) return null;
    return _WorkZs(lst, isSure: isSure, segIndex: segIndex);
  }

  bool _tryAddToLastEnd(BI bi) {
    if (_zss.isEmpty) return false;
    return _zss.last.tryAddToEnd(bi);
  }

  void _tryCombine() {
    if (!config.zs.needCombine) return;
    while (_zss.length >= 2 && _zss[_zss.length - 2].combine(_zss.last, config.zs.combineMode)) {
      _zss.removeLast();
    }
  }

  void _clearFreeList() => _freeItems.clear();

  List<ZS> output() {
    final res = <ZS>[];
    for (final zs in _zss) {
      if (config.zs.onlyConfirmed && !zs.isSure) continue;
      res.add(zs.toModel(res.length));
    }
    return res;
  }

  bool _sameDir(BI bi, SegDirection segDir) {
    return (segDir == SegDirection.up && bi.isUp) ||
        (segDir == SegDirection.down && bi.isDown);
  }

  SegDirection _revertSegDir(SegDirection dir) =>
      dir == SegDirection.up ? SegDirection.down : SegDirection.up;

  double _max(double a, double b) => a >= b ? a : b;
  double _min(double a, double b) => a <= b ? a : b;
}

class _WorkZs {
  BI beginBi;
  BI endBi;
  double low;
  double high;
  double peakLow = double.infinity;
  double peakHigh = double.negativeInfinity;
  bool isSure;
  BI? biIn;
  BI? biOut;
  int? segIndex;
  final List<_WorkZs> subZsList = [];
  final List<BI> biList = [];

  _WorkZs(List<BI>? lst, {required this.isSure, required this.segIndex})
      : beginBi = lst!.first,
        endBi = lst.first,
        low = 0,
        high = 0 {
    updateZsRange(lst);
    for (final item in lst) {
      updateZsEnd(item);
    }
    biList.addAll(lst);
  }

  bool get isOneBiZs => beginBi.index == endBi.index;

  void updateZsRange(List<BI> lst) {
    low = lst.map((e) => e.low).reduce(_max);
    high = lst.map((e) => e.high).reduce(_min);
  }

  void updateZsEnd(BI item) {
    endBi = item;
    if (item.low < peakLow) peakLow = item.low;
    if (item.high > peakHigh) peakHigh = item.high;
    if (!biList.any((bi) => bi.index == item.index)) biList.add(item);
  }

  bool tryAddToEnd(BI item) {
    if (!inRange(item)) return false;
    if (isOneBiZs) {
      updateZsRange([beginBi, item]);
    }
    updateZsEnd(item);
    return true;
  }

  bool inRange(BI item) => _hasOverlap(low, high, item.low, item.high, equal: false);

  bool combine(_WorkZs zs2, ZsCombineMode combineMode) {
    if (zs2.isOneBiZs) return false;
    if (segIndex != zs2.segIndex) return false;

    if (combineMode == ZsCombineMode.zs) {
      if (!_hasOverlap(low, high, zs2.low, zs2.high, equal: true)) return false;
      doCombine(zs2);
      return true;
    }

    if (!_hasOverlap(peakLow, peakHigh, zs2.peakLow, zs2.peakHigh, equal: false)) {
      return false;
    }
    doCombine(zs2);
    return true;
  }

  void doCombine(_WorkZs zs2) {
    if (subZsList.isEmpty) {
      subZsList.add(makeCopy());
    }
    subZsList.add(zs2);

    // Vespa CZS.do_combine：low 取更低，high 取更高，peak 同样扩展。
    low = _min(low, zs2.low);
    high = _max(high, zs2.high);
    peakLow = _min(peakLow, zs2.peakLow);
    peakHigh = _max(peakHigh, zs2.peakHigh);
    endBi = zs2.endBi;
    biOut = zs2.biOut;
    isSure = isSure && zs2.isSure;
    biList.addAll(zs2.biList.where((bi) => !biList.any((x) => x.index == bi.index)));
  }

  _WorkZs makeCopy() {
    final copy = _WorkZs([beginBi], isSure: isSure, segIndex: segIndex);
    copy.beginBi = beginBi;
    copy.endBi = endBi;
    copy.low = low;
    copy.high = high;
    copy.peakLow = peakLow;
    copy.peakHigh = peakHigh;
    copy.biIn = biIn;
    copy.biOut = biOut;
    copy.biList
      ..clear()
      ..addAll(biList);
    return copy;
  }

  ZS toModel(int index) {
    return ZS(
      index: index,
      startBiIndex: beginBi.index,
      endBiIndex: endBi.index,
      startRawIndex: beginBi.startRawIndex,
      endRawIndex: endBi.endRawIndex,
      zg: high,
      zd: low,
      gg: peakHigh,
      dd: peakLow,
      confirmed: isSure,
      biInIndex: biIn?.index,
      biOutIndex: biOut?.index,
      startSegIndex: segIndex,
      endSegIndex: segIndex,
    );
  }

  double _max(double a, double b) => a >= b ? a : b;
  double _min(double a, double b) => a <= b ? a : b;

  bool _hasOverlap(double low1, double high1, double low2, double high2, {required bool equal}) {
    final l = _max(low1, low2);
    final h = _min(high1, high2);
    return equal ? h >= l : h > l;
  }
}
