import '../models/raw_bar.dart';
import '../models/merged_bar.dart';

class IncludeProcessor {
  List<MergedBar> process(List<RawBar> bars, {required bool enabled}) {
    if (bars.isEmpty) return [];
    if (!enabled) {
      return [
        for (var i = 0; i < bars.length; i++) _fromRawBar(bars[i], i),
      ];
    }

    final merged = <MergedBar>[];
    for (final bar in bars) {
      final next = _fromRawBar(bar, merged.length);

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

      // 对齐 Vespa/chan.py 包含处理语义：
      // 上升包含：高点取高，低点取高；下降包含：高点取低，低点取低。
      // 同价时保留较早的 peak K 线，配合后续 FX 使用 get_peak_klu 类似语义。
      final highChoice = up
          ? _chooseHigher(last.high, last.highRawIndex, last.highTime, next.high, next.highRawIndex, next.highTime)
          : _chooseLower(last.high, last.highRawIndex, last.highTime, next.high, next.highRawIndex, next.highTime);
      final lowChoice = up
          ? _chooseHigher(last.low, last.lowRawIndex, last.lowTime, next.low, next.lowRawIndex, next.lowTime)
          : _chooseLower(last.low, last.lowRawIndex, last.lowTime, next.low, next.lowRawIndex, next.lowTime);

      merged[merged.length - 1] = last.copyWith(
        endRawIndex: next.endRawIndex,
        time: next.time,
        high: highChoice.price,
        highRawIndex: highChoice.rawIndex,
        highTime: highChoice.time,
        low: lowChoice.price,
        lowRawIndex: lowChoice.rawIndex,
        lowTime: lowChoice.time,
        close: next.close,
        volume: last.volume + next.volume,
      );
    }

    return [
      for (var i = 0; i < merged.length; i++) merged[i].copyWith(index: i),
    ];
  }

  MergedBar _fromRawBar(RawBar bar, int index) {
    return MergedBar(
      index: index,
      startRawIndex: bar.index,
      endRawIndex: bar.index,
      highRawIndex: bar.index,
      lowRawIndex: bar.index,
      time: bar.time,
      highTime: bar.time,
      lowTime: bar.time,
      open: bar.open,
      high: bar.high,
      low: bar.low,
      close: bar.close,
      volume: bar.volume,
    );
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

  _PeakChoice _chooseHigher(
    double a,
    int aRawIndex,
    DateTime aTime,
    double b,
    int bRawIndex,
    DateTime bTime,
  ) {
    if (b > a) return _PeakChoice(price: b, rawIndex: bRawIndex, time: bTime);
    return _PeakChoice(price: a, rawIndex: aRawIndex, time: aTime);
  }

  _PeakChoice _chooseLower(
    double a,
    int aRawIndex,
    DateTime aTime,
    double b,
    int bRawIndex,
    DateTime bTime,
  ) {
    if (b < a) return _PeakChoice(price: b, rawIndex: bRawIndex, time: bTime);
    return _PeakChoice(price: a, rawIndex: aRawIndex, time: aTime);
  }
}

class _PeakChoice {
  final double price;
  final int rawIndex;
  final DateTime time;

  const _PeakChoice({required this.price, required this.rawIndex, required this.time});
}
