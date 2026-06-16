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

  /// 兼容旧字段：逐价总成交量。没有 s/b 时按 a_replay_trainer.py 的旧字段兼容规则
  /// 归入 buy/right 侧。
  final Map<double, double> priceVolume;

  /// a_replay_trainer.py 风格 chip_tick_bins.s：逐价卖侧成交量。
  final Map<double, double> priceSellVolume;

  /// a_replay_trainer.py 风格 chip_tick_bins.b：逐价买侧成交量。
  final Map<double, double> priceBuyVolume;

  const ChipDistributionBar({
    required this.index,
    this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.priceVolume = const <double, double>{},
    this.priceSellVolume = const <double, double>{},
    this.priceBuyVolume = const <double, double>{},
  });

  bool get hasExactChipBins =>
      priceSellVolume.isNotEmpty ||
      priceBuyVolume.isNotEmpty ||
      priceVolume.isNotEmpty;

  /// 从后端 K 线 JSON 解析筹码输入。
  ///
  /// 支持 a_replay_trainer.py 下发的：
  /// `chip_tick_bins: {p: [...], s: [...], b: [...], w: [...]}`。
  /// 当 s/b 不存在但 w 存在时，按参考实现的兼容逻辑把 w 当作 buy/right 侧。
  factory ChipDistributionBar.fromJson(
      Map<String, dynamic> row, int fallbackIndex) {
    final tickBins =
        ChipTickBins.fromJson(row['chip_tick_bins'] ?? row['chipTickBins']);
    return ChipDistributionBar(
      index: _int(row['x'] ?? row['index'] ?? row['idx']) ?? fallbackIndex,
      time: _parseTime(row['dt'] ??
          row['datetime'] ??
          row['date'] ??
          row['time'] ??
          row['t']),
      open: _num(row['open'] ?? row['o']) ?? 0,
      high: _num(row['high'] ?? row['h']) ?? 0,
      low: _num(row['low'] ?? row['l']) ?? 0,
      close: _num(row['close'] ?? row['c']) ?? 0,
      volume: _num(row['vol'] ?? row['volume'] ?? row['v']) ?? 0,
      priceVolume: tickBins.totalByPrice,
      priceSellVolume: tickBins.sellByPrice,
      priceBuyVolume: tickBins.buyByPrice,
    );
  }
}

/// a_replay_trainer.py 风格逐价筹码桶。
class ChipTickBins {
  final Map<double, double> sellByPrice;
  final Map<double, double> buyByPrice;
  final Map<double, double> totalByPrice;

  const ChipTickBins({
    this.sellByPrice = const <double, double>{},
    this.buyByPrice = const <double, double>{},
    this.totalByPrice = const <double, double>{},
  });

  bool get isEmpty =>
      sellByPrice.isEmpty && buyByPrice.isEmpty && totalByPrice.isEmpty;
  bool get isNotEmpty => !isEmpty;

  factory ChipTickBins.fromJson(Object? raw) {
    if (raw is! Map) return const ChipTickBins();
    final prices = _numList(raw['p'] ?? raw['prices']);
    if (prices.isEmpty) return const ChipTickBins();
    final sell = _numList(raw['s'] ?? raw['sell'] ?? raw['sell_weights']);
    final buy = _numList(raw['b'] ?? raw['buy'] ?? raw['buy_weights']);
    final total = _numList(raw['w'] ?? raw['weight'] ?? raw['weights']);

    final sellByPrice = <double, double>{};
    final buyByPrice = <double, double>{};
    final totalByPrice = <double, double>{};
    final hasSide = sell.length == prices.length || buy.length == prices.length;
    final hasTotal = total.length == prices.length;

    for (var i = 0; i < prices.length; i++) {
      final p = _normalizePrice(prices[i]);
      if (p <= 0) continue;
      final s = sell.length == prices.length ? _safeWeight(sell[i]) : 0.0;
      final b = buy.length == prices.length ? _safeWeight(buy[i]) : 0.0;
      final w = hasTotal ? _safeWeight(total[i]) : s + b;
      if (s > 0) sellByPrice[p] = (sellByPrice[p] ?? 0) + s;
      if (b > 0) buyByPrice[p] = (buyByPrice[p] ?? 0) + b;
      if (w > 0) totalByPrice[p] = (totalByPrice[p] ?? 0) + w;
      if (!hasSide && hasTotal && w > 0) {
        // 参考 _aggregate_kline_dicts_by_quantity 的旧字段兼容：无 s/b 时把 w 当作 B。
        buyByPrice[p] = (buyByPrice[p] ?? 0) + w;
      }
    }
    return ChipTickBins(
      sellByPrice: Map<double, double>.unmodifiable(sellByPrice),
      buyByPrice: Map<double, double>.unmodifiable(buyByPrice),
      totalByPrice: Map<double, double>.unmodifiable(totalByPrice),
    );
  }
}

class ChipDistributionOptions {
  /// 价格桶数量。实际有效值会 clamp 到 8..240。
  final int binCount;

  /// 只使用目标K线及其以前最多 lookback 根K线，保证不偷看未来。
  ///
  /// 如需模拟参考实现“上市首根 -> 当前K”，传入足够大的 lookback。
  final int lookback;

  /// 旧筹码衰减率。0 表示不衰减；0.02 表示越旧权重越低。
  final double ageDecay;

  const ChipDistributionOptions({
    this.binCount = 80,
    this.lookback = 100000,
    this.ageDecay = 0.0,
  });

  int get safeBinCount => binCount.clamp(8, 240).toInt();
  int get safeLookback => lookback.clamp(1, 1000000).toInt();
  double get safeAgeDecay => ageDecay.clamp(0.0, 0.95).toDouble();
}

class ChipDistributionBin {
  final double price;
  final double sellWeight;
  final double buyWeight;
  final double weight;
  final double ratio;

  const ChipDistributionBin({
    required this.price,
    required this.sellWeight,
    required this.buyWeight,
    required this.weight,
    required this.ratio,
  });
}

class ChipDistributionResult {
  final int targetIndex;
  final double currentPrice;
  final double totalWeight;
  final double sellWeight;
  final double buyWeight;
  final double averageCost;
  final double pocPrice;
  final double profitRatio;
  final List<ChipDistributionBin> bins;

  const ChipDistributionResult({
    required this.targetIndex,
    required this.currentPrice,
    required this.totalWeight,
    required this.sellWeight,
    required this.buyWeight,
    required this.averageCost,
    required this.pocPrice,
    required this.profitRatio,
    required this.bins,
  });

  bool get isEmpty => bins.isEmpty || totalWeight <= 0;
}

/// 筹码目标K选择器。
///
/// 对齐 a_replay_trainer.py 任务记录中的优先级：
/// 1. step 模式/正在步进：最新步进K线；
/// 2. 未步进且十字线激活：十字线所在K线；
/// 3. 未步进且无十字线：视觉最右侧K线；
/// 4. 兜底：最后一根K线。
class ChipTargetResolver {
  const ChipTargetResolver();

  int resolve({
    required int total,
    required bool isStepping,
    int? stepIndex,
    int? crosshairIndex,
    int? visibleRightIndex,
  }) {
    if (total <= 0) return 0;
    int? candidate;
    if (isStepping && stepIndex != null) {
      candidate = stepIndex;
    } else if (crosshairIndex != null) {
      candidate = crosshairIndex;
    } else if (visibleRightIndex != null) {
      candidate = visibleRightIndex;
    } else {
      candidate = total - 1;
    }
    return candidate.clamp(0, total - 1).toInt();
  }
}

/// 筹码分布计算器。
///
/// 设计原则：
/// - 当下性：只消费 [0, targetIndex] 范围内的数据。
/// - 分笔/逐价优先：有 chip_tick_bins 时精确累加 s/b/w。
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
        sellWeight: 0,
        buyWeight: 0,
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
      if (bar.hasExactChipBins) {
        for (final p0 in <double>{
          ...bar.priceSellVolume.keys,
          ...bar.priceBuyVolume.keys,
          ...bar.priceVolume.keys,
        }) {
          final p = _safePrice(p0);
          final w = _safeWeight((bar.priceSellVolume[p0] ?? 0) +
              (bar.priceBuyVolume[p0] ?? 0) +
              (bar.priceVolume[p0] ?? 0));
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

    if (!minPrice.isFinite ||
        !maxPrice.isFinite ||
        minPrice <= 0 ||
        maxPrice <= 0) {
      return ChipDistributionResult(
        targetIndex: safeTarget,
        currentPrice: currentPrice,
        totalWeight: 0,
        sellWeight: 0,
        buyWeight: 0,
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
    final sellWeights = List<double>.filled(binCount, 0);
    final buyWeights = List<double>.filled(binCount, 0);

    for (var wi = 0; wi < window.length; wi++) {
      final bar = window[wi];
      final age = window.length - wi - 1;
      final ageWeight = math.pow(1.0 - options.safeAgeDecay, age).toDouble();
      if (bar.hasExactChipBins) {
        _foldExactPriceVolume(
          sellWeights: sellWeights,
          buyWeights: buyWeights,
          bar: bar,
          minPrice: minPrice,
          step: step,
          ageWeight: ageWeight,
        );
      } else {
        _foldOhlcvTriangular(
          sellWeights: sellWeights,
          buyWeights: buyWeights,
          bar: bar,
          minPrice: minPrice,
          step: step,
          ageWeight: ageWeight,
        );
      }
    }

    final totalSell = sellWeights.fold<double>(0, (sum, w) => sum + w);
    final totalBuy = buyWeights.fold<double>(0, (sum, w) => sum + w);
    final totalWeight = totalSell + totalBuy;
    if (totalWeight <= 0) {
      return ChipDistributionResult(
        targetIndex: safeTarget,
        currentPrice: currentPrice,
        totalWeight: 0,
        sellWeight: 0,
        buyWeight: 0,
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

    for (var i = 0; i < binCount; i++) {
      final price = minPrice + step * (i + 0.5);
      final sell = sellWeights[i];
      final buy = buyWeights[i];
      final weight = sell + buy;
      weightedCost += price * weight;
      if (price <= currentPrice) profitWeight += weight;
      if (weight > maxWeight) {
        maxWeight = weight;
        pocPrice = price;
      }
      bins.add(ChipDistributionBin(
        price: price,
        sellWeight: sell,
        buyWeight: buy,
        weight: weight,
        ratio: weight / totalWeight,
      ));
    }

    return ChipDistributionResult(
      targetIndex: safeTarget,
      currentPrice: currentPrice,
      totalWeight: totalWeight,
      sellWeight: totalSell,
      buyWeight: totalBuy,
      averageCost: weightedCost / totalWeight,
      pocPrice: pocPrice,
      profitRatio: profitWeight / totalWeight,
      bins: bins,
    );
  }

  void _foldExactPriceVolume({
    required List<double> sellWeights,
    required List<double> buyWeights,
    required ChipDistributionBar bar,
    required double minPrice,
    required double step,
    required double ageWeight,
  }) {
    for (final entry in bar.priceSellVolume.entries) {
      final price = _safePrice(entry.key);
      final volume = _safeWeight(entry.value) * ageWeight;
      if (price <= 0 || volume <= 0) continue;
      final idx = ((price - minPrice) / step)
          .floor()
          .clamp(0, sellWeights.length - 1)
          .toInt();
      sellWeights[idx] += volume;
    }
    for (final entry in bar.priceBuyVolume.entries) {
      final price = _safePrice(entry.key);
      final volume = _safeWeight(entry.value) * ageWeight;
      if (price <= 0 || volume <= 0) continue;
      final idx = ((price - minPrice) / step)
          .floor()
          .clamp(0, buyWeights.length - 1)
          .toInt();
      buyWeights[idx] += volume;
    }
    if (bar.priceSellVolume.isEmpty && bar.priceBuyVolume.isEmpty) {
      for (final entry in bar.priceVolume.entries) {
        final price = _safePrice(entry.key);
        final volume = _safeWeight(entry.value) * ageWeight;
        if (price <= 0 || volume <= 0) continue;
        final idx = ((price - minPrice) / step)
            .floor()
            .clamp(0, buyWeights.length - 1)
            .toInt();
        buyWeights[idx] += volume;
      }
    }
  }

  void _foldOhlcvTriangular({
    required List<double> sellWeights,
    required List<double> buyWeights,
    required ChipDistributionBar bar,
    required double minPrice,
    required double step,
    required double ageWeight,
  }) {
    final volume = _safeWeight(bar.volume) * ageWeight;
    if (volume <= 0) return;

    final low = _safePrice(math.min(bar.low, bar.high));
    final high = _safePrice(math.max(bar.low, bar.high));
    final close = _safePrice(bar.close);
    if (low <= 0 || high <= 0 || high < low) return;

    if ((high - low).abs() < 1e-9) {
      final idx = ((close > 0 ? close : low) - minPrice) ~/ step;
      buyWeights[idx.clamp(0, buyWeights.length - 1).toInt()] += volume;
      return;
    }

    final typical = _safePrice((bar.high + bar.low + bar.close) / 3.0);
    final center =
        typical > 0 ? typical.clamp(low, high).toDouble() : (low + high) / 2.0;
    final radius = math.max((high - low) / 2.0, step / 2.0);
    final from = ((low - minPrice) / step)
        .floor()
        .clamp(0, buyWeights.length - 1)
        .toInt();
    final to = ((high - minPrice) / step)
        .floor()
        .clamp(0, buyWeights.length - 1)
        .toInt();

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
      final idx = ((center - minPrice) / step)
          .floor()
          .clamp(0, buyWeights.length - 1)
          .toInt();
      buyWeights[idx] += volume;
      return;
    }

    for (final entry in kernel.entries) {
      buyWeights[entry.key] += volume * entry.value / kernelSum;
    }
  }

  static double _safePrice(num raw) {
    final v = raw.toDouble();
    return v.isFinite ? v : 0.0;
  }
}

List<double> _numList(Object? raw) {
  if (raw is! List) return const <double>[];
  final out = <double>[];
  for (final item in raw) {
    final n = _num(item);
    if (n != null && n.isFinite) out.add(n);
  }
  return out;
}

double _normalizePrice(num raw) {
  final v = raw.toDouble();
  if (!v.isFinite) return 0.0;
  return double.parse(v.toStringAsFixed(4));
}

double _safeWeight(num raw) {
  final v = raw.toDouble();
  return v.isFinite && v > 0 ? v : 0.0;
}

double? _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

DateTime? _parseTime(Object? value) {
  final s = '$value'.trim();
  if (s.isEmpty || s == 'null') return null;
  return DateTime.tryParse(s.replaceFirst(' ', 'T').replaceAll('/', '-'));
}
