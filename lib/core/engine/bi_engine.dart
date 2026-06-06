import 'chan_config.dart';
import '../models/fx.dart';
import '../models/bi.dart';

class BiEngine {
  List<BI> build(List<FX> fxs, ChanConfig config) {
    if (fxs.length < 2) return [];

    final points = <FX>[];
    for (final fx in fxs) {
      if (points.isEmpty) {
        points.add(fx);
        continue;
      }

      final last = points.last;
      if (last.type == fx.type) {
        // 连续同类分型，保留更极端的那个。
        final replace = fx.isTop ? fx.price >= last.price : fx.price <= last.price;
        if (replace) points[points.length - 1] = fx;
        continue;
      }

      final enoughDistance = (fx.index - last.index).abs() >= config.minKCountForBi;
      if (!enoughDistance) {
        // 距离不足，不成笔；继续等待后续更合适的反向分型。
        continue;
      }

      points.add(fx);
    }

    if (points.length < 2) return [];

    final bis = <BI>[];
    for (var i = 1; i < points.length; i++) {
      final start = points[i - 1];
      final end = points[i];
      if (start.type == end.type) continue;
      final direction = start.isBottom && end.isTop ? BiDirection.up : BiDirection.down;
      bis.add(BI(index: bis.length, start: start, end: end, direction: direction));
    }
    return bis;
  }
}
