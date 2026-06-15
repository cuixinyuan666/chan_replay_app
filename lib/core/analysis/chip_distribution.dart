import 'dart:math' as math;

/// 单根K线参与筹码分布计算的最小数据。
///
/// 该对象只承载行情输入，不承载任何缠论 FX/BI/SEG/ZS/BSP 结构，避免 Flutter
/// 侧获得或暗含新的缠论计算权威。
class ChipDistributionBar {
  final int index;
  final DateTime? time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  /// 可选的精确逐价成交量。
  ///
  /// 当后端或离线分笔已经提供逐价成交量时优先使用该字段；为空时才使用
  /// OHLCV 的三角分摊兜底。
  final Map<double, double> priceVolume;

  const ChipDistributionBar({
    required this.index,
    this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.priceVolume = const <double, double>{},
  });
}

class ChipDistributionOptions {
  /// 价格桶数量。实际有效值会 clamp 到 8..240。
  final int binCount;

  /// 只使用目标K线及其以前最多 lookback 根K线，保证不偷看未来。
  final int lookback;

  /// 旧筹码衰减率。0 表示不衰减；0.02 表示越旧权重越低。
  final double ageDecay;

  const ChipDistributionOptions({
    this.binCount = 80,
    this.lookback = 240,
    this.ageDecay = 0.0,
  });

  int get safeBinCount => binCount.clamp(8, 240).toInt();
  int get safeLookback => lookback.clamp(1, 100000).toInt();
  double get safeAgeDecay => ageDecay.clamp(0.0, 0.95).toDouble();
}

class ChipDistributionBin {
  final double price;
  final double weight;
  final double ratio;

  const ChipDistributionBin({
    required this.price,
    required this.weight,
    required this.ratio,
  });
}

class ChipDistributionResult {
  final int targetIndex;
  final double currentPrice;
  final double totalWeight;
  final double averageCost;
  final double pocPrice;
  final double profitRatio;
  final List<ChipDistributionBin> bins;

  const ChipDistributionResult({
    required this.targetIndex,
    required this.currentPrice,
    required this.totalWeight,
    required this.averageCost,
    required this.pocPrice,
    required this.profitRatio,
    required this.bins,
  });

  bool get isEmpty => bins.isEmpty || totalWeight <= 0;
}

/// 筹码分布计算器。
///
/// 设计原则：
/// - 当下性：只消费 [0, targetIndex] 范围内的数据。
/// - 分笔/逐价优先：有 [ChipDistributionBar.priceVolume] 时精确累加。
/// - OHLCV 兜底：无逐价数据时按 high-low 区间做三角分摊，中心为 typical price。
/// - UI 解耦：不依赖任何 Widget，也不依赖 chan.py 结构对象。
class ChipDistributionEngine {
  const ChipDistributionEngine();

  ChipDistributionResult calculate(
    List<ChipDistributionBar> bars, {
    required int targetIndex,
    ChipDistributionOptions options = const ChipDistributionOptions(),
  }) {
    if (bars.isEmpty) {
      return ChipDistributionResult(
        targetIndex: targetIndex,
        currentPrice: 0,
        totalWeight: 0,
        averageCost: 0,
        pocPrice: 0,
        profitRatio: 0,
        bins: const <ChipDistributionBin>[],
      );
    }

    final safeTarget = targetIndex.clamp(0, bars.length - 1).toInt();
    final start = math.max(0, safeTarget - options.safeLookback + 1);
    final window = bars.sublist(start, safeTarget + 1);
    final currentPrice = _safePrice(window.last.close);

    var minPrice = double.infinity;
    var maxPrice = -double.infinity;
    for (final bar in window) {
      if (bar.priceVolume.isNotEmpty) {
        for (final entry in bar.priceVolume.entries) {
          final p = _safePrice(entry.key);
          final w = _safeWeight(entry.value);
          if (p <= 0 || w <= 0) continue;
          minPrice = math.min(minPrice, p);
          maxPrice = math.max(maxPrice, p);
        }
      } else {
        final lo = _safePrice(bar.low);
        final hi = _safePrice(bar.high);
        final close = _safePrice(bar.close);
        if (lo > 0 && hi > 0 && hi >= lo) {
          minPrice = math.min(minPrice, lo);
          maxPrice = math.max(maxPrice, hi);
        } else if (close > 0) {
          minPrice = math.min(minPrice, close);
          maxPrice = math.max(maxPrice, close);
        }
      }
    }

    if (!minPrice.isFinite || !maxPrice.isFinite || minPrice <= 0 || maxPrice <= 0) {
      return ChipDistributionResult(
        targetIndex: safeTarget,
        currentPrice: currentPrice,
        totalWeight: 0,
        averageCost: 0,
        pocPrice: 0,
        profitRatio: 0,
        bins: const <ChipDistributionBin>[],
      );
    }

    if ((maxPrice - minPrice).abs() < 1e-9) {
      minPrice *= 0.999;
      maxPrice *= 1.001;
    }

    final binCount = options.safeBinCount;
    final step = (maxPrice - minPrice) / binCount;
    final weights = List<double>.filled(binCount, 0);

    for (var wi = 0; wi < window.length; wi++) {
      final bar = window[wi];
      final age = window.length - wi - 1;
      final ageWeight = math.pow(1.0 - options.safeAgeDecay, age).toDouble();
      if (bar.priceVolume.isNotEmpty) {
        _foldExactPriceVolume(weights, bar.priceVolume, minPrice, step, ageWeight);
      } else {
        _foldOhlcvTriangular(weights, bar, minPrice, step, ageWeight);
      }
    }

    final totalWeight = weights.fold<double>(0, (sum, w) => sum + w);
    if (totalWeight <= 0) {
      return ChipDistributionResult(
        targetIndex: safeTarget,
        currentPrice: currentPrice,
        totalWeight: 0,
        averageCost: 0,
        pocPrice: 0,
        profitRatio: 0,
        bins: const <ChipDistributionBin>[],
      );
    }

    var weightedCost = 0.0;
    var profitWeight = 0.0;
    var maxWeight = -1.0;
    var pocPrice = currentPrice;
    final bins = <ChipDistributionBin>[];

    for (var i = 0; i < weights.length; i++) {
      final price = minPrice + step * (i + 0.5);
      final weight = weights[i];
      weightedCost += price * weight;
      if (price <= currentPrice) profitWeight += weight;
      if (weight > maxWeight) {
        maxWeight = weight;
        pocPrice = price;
      }
      bins.add(ChipDistributionBin(
        price: price,
        weight: weight,
        ratio: weight / totalWeight,
      ));
    }

    return ChipDistributionResult(
      targetIndex: safeTarget,
      currentPrice: currentPrice,
      totalWeight: totalWeight,
      averageCost: weightedCost / totalWeight,
      pocPrice: pocPrice,
      profitRatio: profitWeight / totalWeight,
      bins: bins,
    );
  }

  void _foldExactPriceVolume(
    List<double> weights,
    Map<double, double> priceVolume,
    double minPrice,
    double step,
    double ageWeight,
  ) {
    for (final entry in priceVolume.entries) {
      final price = _safePrice(entry.key);
      final volume = _safeWeight(entry.value) * ageWeight;
      if (price <= 0 || volume <= 0) continue;
      final idx = ((price - minPrice) / step).floor().clamp(0, weights.length - 1).toInt();
      weights[idx] += volume;
    }
  }

  void _foldOhlcvTriangular(
    List<double> weights,
    ChipDistributionBar bar,
    double minPrice,
    double step,
    double ageWeight,
  ) {
    final volume = _safeWeight(bar.volume) * ageWeight;
    if (volume <= 0) return;

    final low = _safePrice(math.min(bar.low, bar.high));
    final high = _safePrice(math.max(bar.low, bar.high));
    final close = _safePrice(bar.close);
    if (low <= 0 || high <= 0 || high < low) return;

    if ((high - low).abs() < 1e-9) {
      final idx = ((close > 0 ? close : low) - minPrice) ~/ step;
      weights[idx.clamp(0, weights.length - 1).toInt()] += volume;
      return;
    }

    final typical = _safePrice((bar.high + bar.low + bar.close) / 3.0);
    final center = typical > 0 ? typical.clamp(low, high).toDouble() : (low + high) / 2.0;
    final radius = math.max((high - low) / 2.0, step / 2.0);
    final from = ((low - minPrice) / step).floor().clamp(0, weights.length - 1).toInt();
    final to = ((high - minPrice) / step).floor().clamp(0, weights.length - 1).toInt();

    var kernelSum = 0.0;
    final kernel = <int, double>{};
    for (var i = from; i <= to; i++) {
      final price = minPrice + step * (i + 0.5);
      final distance = (price - center).abs();
      final k = math.max(0.0, 1.0 - distance / radius);
      if (k <= 0) continue;
      kernel[i] = k;
      kernelSum += k;
    }

    if (kernelSum <= 0) {
      final idx = ((center - minPrice) / step).floor().clamp(0, weights.length - 1).toInt();
      weights[idx] += volume;
      return;
    }

    for (final entry in kernel.entries) {
      weights[entry.key] += volume * entry.value / kernelSum;
    }
  }

  static double _safePrice(num raw) {
    final v = raw.toDouble();
    return v.isFinite ? v : 0.0;
  }

  static double _safeWeight(num raw) {
    final v = raw.toDouble();
    return v.isFinite && v > 0 ? v : 0.0;
  }
}
