import 'chan_config.dart';
import '../models/merged_bar.dart';
import '../models/fx.dart';

class FxEngine {
  List<FX> detect(List<MergedBar> bars, ChanConfig config) {
    if (bars.length < 3) return [];
    final fxs = <FX>[];

    for (var i = 1; i < bars.length - 1; i++) {
      final left = bars[i - 1];
      final center = bars[i];
      final right = bars[i + 1];

      final isTop = config.strictFx
          ? center.high > left.high &&
              center.high > right.high &&
              center.low > left.low &&
              center.low > right.low
          : center.high >= left.high &&
              center.high >= right.high &&
              center.low >= left.low &&
              center.low >= right.low;

      final isBottom = config.strictFx
          ? center.low < left.low &&
              center.low < right.low &&
              center.high < left.high &&
              center.high < right.high
          : center.low <= left.low &&
              center.low <= right.low &&
              center.high <= left.high &&
              center.high <= right.high;

      if (isTop) {
        fxs.add(FX(
          index: center.index,
          rawIndex: center.highRawIndex,
          time: center.highTime,
          type: FxType.top,
          price: center.high,
          left: left,
          center: center,
          right: right,
        ));
      } else if (isBottom) {
        fxs.add(FX(
          index: center.index,
          rawIndex: center.lowRawIndex,
          time: center.lowTime,
          type: FxType.bottom,
          price: center.low,
          left: left,
          center: center,
          right: right,
        ));
      }
    }

    return fxs;
  }
}
