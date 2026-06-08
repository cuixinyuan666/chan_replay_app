import 'chan_config.dart';
import '../models/bi.dart';
import '../models/fx.dart';
import '../models/merged_bar.dart';

class BiEngine {
  List<BI> build(List<FX> fxs, ChanConfig config, {List<MergedBar> mergedBars = const []}) {
    if (fxs.length < 2) return [];

    final inputFxs = _seedInitialFx(fxs, config, mergedBars);
    final points = <FX>[];
    for (final fx in inputFxs) {
      if (points.isEmpty) {
        points.add(fx);
        continue;
      }

      final last = points.last;
      if (last.type == fx.type) {
        final replace = fx.isTop ? fx.price >= last.price : fx.price <= last.price;
        if (replace) points[points.length - 1] = fx;
        continue;
      }

      if (!_canMakeBi(last, fx, config, mergedBars)) continue;
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

    _addTailBi(bis, points.last, config, mergedBars);
    return bis;
  }

  List<FX> _seedInitialFx(List<FX> fxs, ChanConfig config, List<MergedBar> mergedBars) {
    if (fxs.isEmpty || mergedBars.length < 3) return fxs;
    final first = fxs.first;

    if (first.isTop) {
      for (var i = 1; i < mergedBars.length - 1; i++) {
        final center = mergedBars[i];
        if (center.index >= first.index) break;
        if (!_isBottomShape(mergedBars, i, config.strictFx)) continue;
        final seed = _fxFromLowAt(mergedBars, i, confirmed: true);
        if (seed.rawIndex == first.rawIndex) continue;
        if (_canMakeBi(seed, first, config, mergedBars) || _canMakeInitialSeedBi(seed, first, config, mergedBars)) {
          return [seed, ...fxs];
        }
      }
    } else {
      for (var i = 1; i < mergedBars.length - 1; i++) {
        final center = mergedBars[i];
        if (center.index >= first.index) break;
        if (!_isTopShape(mergedBars, i, config.strictFx)) continue;
        final seed = _fxFromHighAt(mergedBars, i, confirmed: true);
        if (seed.rawIndex == first.rawIndex) continue;
        if (_canMakeBi(seed, first, config, mergedBars) || _canMakeInitialSeedBi(seed, first, config, mergedBars)) {
          return [seed, ...fxs];
        }
      }
    }

    return fxs;
  }

  bool _canMakeInitialSeedBi(FX start, FX end, ChanConfig config, List<MergedBar> mergedBars) {
    final biConf = config.bi;
    if (biConf.biAlgo != BiAlgo.fx) {
      final span = (end.index - start.index).abs();
      if (span < biConf.effectiveMinKlcSpan) return false;
    }
    if (start.isBottom && end.isTop) {
      if (start.price >= end.price) return false;
      if (start.center.low >= end.center.low) return false;
    } else if (start.isTop && end.isBottom) {
      if (start.price <= end.price) return false;
      if (start.center.high <= end.center.high) return false;
    } else {
      return false;
    }
    if (biConf.endIsPeak && !_endIsPeak(start, end, mergedBars)) return false;
    return true;
  }

  bool _isBottomShape(List<MergedBar> bars, int index, bool strict) {
    final left = bars[index - 1];
    final center = bars[index];
    final right = bars[index + 1];
    if (strict) {
      return center.low < left.low && center.low < right.low && center.high < left.high && center.high < right.high;
    }
    return center.low <= left.low && center.low <= right.low && center.high <= left.high && center.high <= right.high;
  }

  bool _isTopShape(List<MergedBar> bars, int index, bool strict) {
    final left = bars[index - 1];
    final center = bars[index];
    final right = bars[index + 1];
    if (strict) {
      return center.high > left.high && center.high > right.high && center.low > left.low && center.low > right.low;
    }
    return center.high >= left.high && center.high >= right.high && center.low >= left.low && center.low >= right.low;
  }

  void _addTailBi(List<BI> bis, FX lastPoint, ChanConfig config, List<MergedBar> mergedBars) {
    if (bis.isEmpty || mergedBars.isEmpty) return;
    if (lastPoint.isTop) {
      final end = _lowestAfter(lastPoint, mergedBars);
      if (end == null || !_canMakeBi(lastPoint, end, config, mergedBars, forVirtual: true)) return;
      bis.add(BI(index: bis.length, start: lastPoint, end: end, direction: BiDirection.down, prevIndex: bis.last.index, isSure: false));
    } else {
      final end = _highestAfter(lastPoint, mergedBars);
      if (end == null || !_canMakeBi(lastPoint, end, config, mergedBars, forVirtual: true)) return;
      bis.add(BI(index: bis.length, start: lastPoint, end: end, direction: BiDirection.up, prevIndex: bis.last.index, isSure: false));
    }
  }

  FX? _lowestAfter(FX start, List<MergedBar> bars) {
    MergedBar? best;
    for (final bar in bars) {
      if (bar.index <= start.index) continue;
      if (best == null || bar.low < best.low || (bar.low == best.low && bar.lowRawIndex > best.lowRawIndex)) best = bar;
    }
    if (best == null) return null;
    return _fxFromLow(best, confirmed: false);
  }

  FX? _highestAfter(FX start, List<MergedBar> bars) {
    MergedBar? best;
    for (final bar in bars) {
      if (bar.index <= start.index) continue;
      if (best == null || bar.high > best.high || (bar.high == best.high && bar.highRawIndex > best.highRawIndex)) best = bar;
    }
    if (best == null) return null;
    return _fxFromHigh(best, confirmed: false);
  }

  FX _fxFromLowAt(List<MergedBar> bars, int index, {required bool confirmed}) {
    final bar = bars[index];
    return FX(index: bar.index, rawIndex: bar.lowRawIndex, time: bar.lowTime, type: FxType.bottom, price: bar.low, left: bars[index - 1], center: bar, right: bars[index + 1], confirmed: confirmed);
  }

  FX _fxFromHighAt(List<MergedBar> bars, int index, {required bool confirmed}) {
    final bar = bars[index];
    return FX(index: bar.index, rawIndex: bar.highRawIndex, time: bar.highTime, type: FxType.top, price: bar.high, left: bars[index - 1], center: bar, right: bars[index + 1], confirmed: confirmed);
  }

  FX _fxFromLow(MergedBar bar, {required bool confirmed}) {
    return FX(index: bar.index, rawIndex: bar.lowRawIndex, time: bar.lowTime, type: FxType.bottom, price: bar.low, left: bar, center: bar, right: bar, confirmed: confirmed);
  }

  FX _fxFromHigh(MergedBar bar, {required bool confirmed}) {
    return FX(index: bar.index, rawIndex: bar.highRawIndex, time: bar.highTime, type: FxType.top, price: bar.high, left: bar, center: bar, right: bar, confirmed: confirmed);
  }

  bool _canMakeBi(FX start, FX end, ChanConfig config, List<MergedBar> mergedBars, {bool forVirtual = false}) {
    final biConf = config.bi;
    if (biConf.biAlgo != BiAlgo.fx) {
      final span = (end.index - start.index).abs();
      if (span < biConf.effectiveMinKlcSpan) return false;
    }
    if (!_checkFxValid(start, end, biConf.fxCheck, forVirtual: forVirtual)) return false;
    if (biConf.endIsPeak && !_endIsPeak(start, end, mergedBars)) return false;
    return true;
  }

  bool _checkFxValid(FX start, FX end, BiFxCheck method, {bool forVirtual = false}) {
    if (start.isTop && end.isBottom) {
      if (forVirtual) return start.center.high > end.center.low;
      final item2High = _endHighForCheck(end, method);
      final selfLow = _startLowForCheck(start, method);
      if (method == BiFxCheck.totally) return start.center.low > item2High;
      return start.center.high > item2High && end.center.low < selfLow;
    }
    if (start.isBottom && end.isTop) {
      if (forVirtual) return start.center.low < end.center.high;
      final item2Low = _endLowForCheck(end, method);
      final selfHigh = _startHighForCheck(start, method);
      if (method == BiFxCheck.totally) return start.center.high < item2Low;
      return start.center.low < item2Low && end.center.high > selfHigh;
    }
    return false;
  }

  double _endHighForCheck(FX end, BiFxCheck method) {
    switch (method) {
      case BiFxCheck.loss:
        return end.center.high;
      case BiFxCheck.half:
        return _max(end.left.high, end.center.high);
      case BiFxCheck.strict:
      case BiFxCheck.totally:
        return _max(_max(end.left.high, end.center.high), end.right.high);
    }
  }

  double _endLowForCheck(FX end, BiFxCheck method) {
    switch (method) {
      case BiFxCheck.loss:
        return end.center.low;
      case BiFxCheck.half:
        return _min(end.left.low, end.center.low);
      case BiFxCheck.strict:
      case BiFxCheck.totally:
        return _min(_min(end.left.low, end.center.low), end.right.low);
    }
  }

  double _startLowForCheck(FX start, BiFxCheck method) {
    switch (method) {
      case BiFxCheck.loss:
        return start.center.low;
      case BiFxCheck.half:
        return _min(start.center.low, start.right.low);
      case BiFxCheck.strict:
      case BiFxCheck.totally:
        return _min(_min(start.left.low, start.center.low), start.right.low);
    }
  }

  double _startHighForCheck(FX start, BiFxCheck method) {
    switch (method) {
      case BiFxCheck.loss:
        return start.center.high;
      case BiFxCheck.half:
        return _max(start.center.high, start.right.high);
      case BiFxCheck.strict:
      case BiFxCheck.totally:
        return _max(_max(start.left.high, start.center.high), start.right.high);
    }
  }

  bool _endIsPeak(FX start, FX end, List<MergedBar> mergedBars) {
    if (mergedBars.isEmpty) return true;
    final from = start.index + 1;
    final to = end.index - 1;
    if (from > to) return true;
    if (start.isBottom && end.isTop) {
      for (final bar in mergedBars) {
        if (bar.index < from || bar.index > to) continue;
        if (bar.high > end.center.high) return false;
      }
      return true;
    }
    if (start.isTop && end.isBottom) {
      for (final bar in mergedBars) {
        if (bar.index < from || bar.index > to) continue;
        if (bar.low < end.center.low) return false;
      }
      return true;
    }
    return false;
  }

  double _max(double a, double b) => a >= b ? a : b;
  double _min(double a, double b) => a <= b ? a : b;
}
