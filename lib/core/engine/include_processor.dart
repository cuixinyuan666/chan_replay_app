import '../models/raw_bar.dart';
import '../models/merged_bar.dart';

class IncludeProcessor {
  List<MergedBar> process(List<RawBar> bars, {required bool enabled}) {
    if (bars.isEmpty) return [];
    if (!enabled) {
      return [
        for (var i = 0; i < bars.length; i++)
          MergedBar(
            index: i,
            startRawIndex: bars[i].index,
            endRawIndex: bars[i].index,
            time: bars[i].time,
            open: bars[i].open,
            high: bars[i].high,
            low: bars[i].low,
            close: bars[i].close,
            volume: bars[i].volume,
          ),
      ];
    }

    final merged = <MergedBar>[];
    for (final bar in bars) {
      final next = MergedBar(
        index: merged.length,
        startRawIndex: bar.index,
        endRawIndex: bar.index,
        time: bar.time,
        open: bar.open,
        high: bar.high,
        low: bar.low,
        close: bar.close,
        volume: bar.volume,
      );

      if (merged.isEmpty) {
        merged.add(next);
        continue;
      }

      final last = merged.last;
      final hasInclude = _hasInclude(last, next);
      if (!hasInclude) {
        merged.add(next.copyWith(index: merged.length));
        continue;
      }

      final direction = _detectDirection(merged);
      final up = direction >= 0;

      // 上升包含：高点取高，低点取高；下降包含：高点取低，低点取低。
      final newHigh = up ? _max(last.high, next.high) : _min(last.high, next.high);
      final newLow = up ? _max(last.low, next.low) : _min(last.low, next.low);

      merged[merged.length - 1] = last.copyWith(
        endRawIndex: next.endRawIndex,
        time: next.time,
        high: newHigh,
        low: newLow,
        close: next.close,
        volume: last.volume + next.volume,
      );
    }

    return [
      for (var i = 0; i < merged.length; i++) merged[i].copyWith(index: i),
    ];
  }

  bool _hasInclude(MergedBar a, MergedBar b) {
    final bInsideA = b.high <= a.high && b.low >= a.low;
    final aInsideB = b.high >= a.high && b.low <= a.low;
    return bInsideA || aInsideB;
  }

  int _detectDirection(List<MergedBar> bars) {
    if (bars.length < 2) {
      return bars.last.close >= bars.last.open ? 1 : -1;
    }
    final a = bars[bars.length - 2];
    final b = bars.last;
    if (b.high > a.high && b.low >= a.low) return 1;
    if (b.high <= a.high && b.low < a.low) return -1;
    return b.close >= a.close ? 1 : -1;
  }

  double _max(double a, double b) => a >= b ? a : b;
  double _min(double a, double b) => a <= b ? a : b;
}
