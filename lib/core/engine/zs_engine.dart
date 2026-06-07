import 'chan_config.dart';
import '../models/bi.dart';
import '../models/seg.dart';
import '../models/zs.dart';

class ZsEngine {
  List<ZS> build(List<BI> bis, ChanConfig config, {List<SEG> segs = const []}) {
    if (bis.isEmpty) return [];

    switch (config.zs.zsAlgo) {
      case ZsAlgo.normal:
        // normal 模式必须服从线段边界；没有确认线段时不生成中枢，避免退回全局笔列表造成跨段显示。
        return _buildInsideConfirmedSegs(segs, config);
      case ZsAlgo.overSeg:
        // overSeg 才允许全局笔列表扫描，也就是允许跨段中枢。
        return _buildOnBis(bis, config, startSegIndex: null, endSegIndex: null);
      case ZsAlgo.auto:
        // auto 优先确认线段内中枢，无结果时再退回全局笔列表。
        final inSeg = _buildInsideConfirmedSegs(segs, config);
        if (inSeg.isNotEmpty) return inSeg;
        return _buildOnBis(bis, config, startSegIndex: null, endSegIndex: null);
    }
  }

  List<ZS> _buildInsideConfirmedSegs(List<SEG> segs, ChanConfig config) {
    if (segs.isEmpty) return [];

    final minCount = config.zs.oneBiZs ? 1 : 3;
    final eligible = segs.where((seg) {
      if (seg.biList.length < minCount) return false;
      // 默认只使用确认线段。关闭 onlyConfirmed 后才允许尾部 S? 参与临时中枢。
      if (config.zs.onlyConfirmed && !seg.isSure) return false;
      return true;
    }).toList();

    final all = <ZS>[];
    for (final seg in eligible) {
      final zss = _buildOnBis(
        seg.biList,
        config,
        startSegIndex: seg.index,
        endSegIndex: seg.index,
        combineWithinWindow: config.zs.needCombine,
      ).where((zs) => _zsInsideSeg(zs, seg)).toList();
      all.addAll(zss);
    }
    return _renumber(all);
  }

  bool _zsInsideSeg(ZS zs, SEG seg) {
    return zs.startBiIndex >= seg.startBiIndex &&
        zs.endBiIndex <= seg.endBiIndex &&
        zs.startRawIndex >= seg.startRawIndex &&
        zs.endRawIndex <= seg.endRawIndex &&
        !zs.isCrossSeg;
  }

  List<ZS> _buildOnBis(
    List<BI> bis,
    ChanConfig config, {
    required int? startSegIndex,
    required int? endSegIndex,
    bool? combineWithinWindow,
  }) {
    final minCount = config.zs.oneBiZs ? 1 : 3;
    if (bis.length < minCount) return [];

    final zss = <ZS>[];
    var i = 0;
    while (i <= bis.length - minCount) {
      final seed = bis.sublist(i, i + minCount);
      final base = _calcOverlap(seed, strict: true);
      if (base == null) {
        i += 1;
        continue;
      }

      var end = i + minCount - 1;
      var zg = base.zg;
      var zd = base.zd;
      var gg = base.gg;
      var dd = base.dd;

      // 对齐 chan.py CZSList normal 思路：中枢形成后，后续笔若仍在区间内则尝试延伸。
      for (var j = end + 1; j < bis.length; j++) {
        final b = bis[j];
        final overlap = _hasOverlap(zg, zd, b.high, b.low, strict: true);
        if (!overlap) break;

        zg = _min(zg, b.high);
        zd = _max(zd, b.low);
        gg = _max(gg, b.high);
        dd = _min(dd, b.low);
        end = j;
      }

      zss.add(ZS(
        index: zss.length,
        startBiIndex: bis[i].index,
        endBiIndex: bis[end].index,
        startRawIndex: bis[i].startRawIndex,
        endRawIndex: bis[end].endRawIndex,
        zg: zg,
        zd: zd,
        gg: gg,
        dd: dd,
        confirmed: true,
        startSegIndex: startSegIndex,
        endSegIndex: endSegIndex,
      ));

      i = end + 1;
    }

    final shouldCombine = combineWithinWindow ?? config.zs.needCombine;
    if (!shouldCombine) return zss;
    return _combineZs(zss, config.zs.combineMode);
  }

  _Overlap? _calcOverlap(List<BI> items, {required bool strict}) {
    final zg = items.map((e) => e.high).reduce(_min);
    final zd = items.map((e) => e.low).reduce(_max);
    if (!_hasOverlap(zg, zd, zg, zd, strict: strict)) return null;
    final gg = items.map((e) => e.high).reduce(_max);
    final dd = items.map((e) => e.low).reduce(_min);
    return _Overlap(zg: zg, zd: zd, gg: gg, dd: dd);
  }

  bool _hasOverlap(double zg, double zd, double high, double low, {required bool strict}) {
    final minHigh = _min(zg, high);
    final maxLow = _max(zd, low);
    return strict ? minHigh > maxLow : minHigh >= maxLow;
  }

  List<ZS> _combineZs(List<ZS> source, ZsCombineMode mode) {
    if (source.length < 2) return source;
    final result = <ZS>[];

    for (final zs in source) {
      if (result.isEmpty) {
        result.add(zs);
        continue;
      }

      final last = result.last;
      // 不允许不同线段的中枢在 normal/线段内模式下被合并。
      final sameSeg = last.startSegIndex == zs.startSegIndex &&
          last.endSegIndex == zs.endSegIndex;
      if (!sameSeg) {
        result.add(zs);
        continue;
      }

      final shouldCombine = mode == ZsCombineMode.zs
          ? _hasOverlap(last.zg, last.zd, zs.zg, zs.zd, strict: false)
          : _hasOverlap(last.gg, last.dd, zs.gg, zs.dd, strict: false);

      if (!shouldCombine) {
        result.add(zs);
        continue;
      }

      final merged = ZS(
        index: result.length - 1,
        startBiIndex: last.startBiIndex,
        endBiIndex: zs.endBiIndex,
        startRawIndex: last.startRawIndex,
        endRawIndex: zs.endRawIndex,
        zg: _min(last.zg, zs.zg),
        zd: _max(last.zd, zs.zd),
        gg: _max(last.gg, zs.gg),
        dd: _min(last.dd, zs.dd),
        confirmed: last.confirmed && zs.confirmed,
        startSegIndex: last.startSegIndex,
        endSegIndex: zs.endSegIndex,
      );
      result[result.length - 1] = merged;
    }

    return _renumber(result);
  }

  List<ZS> _renumber(List<ZS> source) {
    return [
      for (var i = 0; i < source.length; i++)
        ZS(
          index: i,
          startBiIndex: source[i].startBiIndex,
          endBiIndex: source[i].endBiIndex,
          startRawIndex: source[i].startRawIndex,
          endRawIndex: source[i].endRawIndex,
          zg: source[i].zg,
          zd: source[i].zd,
          gg: source[i].gg,
          dd: source[i].dd,
          confirmed: source[i].confirmed,
          startSegIndex: source[i].startSegIndex,
          endSegIndex: source[i].endSegIndex,
        ),
    ];
  }

  double _max(double a, double b) => a >= b ? a : b;
  double _min(double a, double b) => a <= b ? a : b;
}

class _Overlap {
  final double zg;
  final double zd;
  final double gg;
  final double dd;

  const _Overlap({required this.zg, required this.zd, required this.gg, required this.dd});
}
