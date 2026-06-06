import 'chan_config.dart';
import '../models/bi.dart';
import '../models/zs.dart';

class ZsEngine {
  List<ZS> build(List<BI> bis, ChanConfig config) {
    if (bis.isEmpty) return [];

    final zss = <ZS>[];
    final minCount = config.zs.oneBiZs ? 1 : 3;
    if (bis.length < minCount) return [];

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

      // 对齐 chan.py CZSList 的 normal 思路：中枢形成后，后续笔若仍在区间内则尝试延伸。
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
        startBiIndex: i,
        endBiIndex: end,
        startRawIndex: bis[i].startRawIndex,
        endRawIndex: bis[end].endRawIndex,
        zg: zg,
        zd: zd,
        gg: gg,
        dd: dd,
        confirmed: true,
      ));

      i = end + 1;
    }

    if (!config.zs.needCombine) return zss;
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
      );
      result[result.length - 1] = merged;
    }

    return [
      for (var i = 0; i < result.length; i++)
        ZS(
          index: i,
          startBiIndex: result[i].startBiIndex,
          endBiIndex: result[i].endBiIndex,
          startRawIndex: result[i].startRawIndex,
          endRawIndex: result[i].endRawIndex,
          zg: result[i].zg,
          zd: result[i].zd,
          gg: result[i].gg,
          dd: result[i].dd,
          confirmed: result[i].confirmed,
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
