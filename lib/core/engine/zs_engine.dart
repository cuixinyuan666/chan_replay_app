import '../models/bi.dart';
import '../models/zs.dart';

class ZsEngine {
  List<ZS> build(List<BI> bis) {
    if (bis.length < 3) return [];

    final zss = <ZS>[];
    var i = 0;
    while (i <= bis.length - 3) {
      final first3 = bis.sublist(i, i + 3);
      final base = _calcOverlap(first3);
      if (base == null) {
        i += 1;
        continue;
      }

      var end = i + 2;
      var zg = base.zg;
      var zd = base.zd;
      var gg = base.gg;
      var dd = base.dd;

      // 向右扩展中枢，后续笔若仍与当前中枢区间有重叠，则并入。
      for (var j = i + 3; j < bis.length; j++) {
        final b = bis[j];
        final newZg = _min(zg, b.high);
        final newZd = _max(zd, b.low);
        if (newZg >= newZd) {
          zg = newZg;
          zd = newZd;
          gg = _max(gg, b.high);
          dd = _min(dd, b.low);
          end = j;
        } else {
          break;
        }
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

      // 避免同一组笔重复生成多个高度重叠中枢。
      i = end + 1;
    }

    return zss;
  }

  _Overlap? _calcOverlap(List<BI> seg) {
    final zg = seg.map((e) => e.high).reduce(_min);
    final zd = seg.map((e) => e.low).reduce(_max);
    if (zg < zd) return null;
    final gg = seg.map((e) => e.high).reduce(_max);
    final dd = seg.map((e) => e.low).reduce(_min);
    return _Overlap(zg: zg, zd: zd, gg: gg, dd: dd);
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
