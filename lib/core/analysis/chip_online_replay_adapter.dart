import '../models/chan_snapshot.dart';
import '../models/raw_bar.dart';
import 'chip_distribution.dart';

/// 在线 analyze_multi -> 筹码分布输入的轻量适配层。
///
/// 该层只搬运后端已经返回到 ChanSnapshot.rawBars 的行情字段：
/// - 有 chip_tick_bins / chipTickBins 时，保留 a_replay_trainer.py 风格 p/s/b/w；
/// - 没有逐价桶时，交给 ChipDistributionEngine 使用 OHLCV 兜底。
class ChipOnlineReplayAdapter {
  const ChipOnlineReplayAdapter._();

  static List<ChipDistributionBar> fromSnapshot(ChanSnapshot? snapshot) {
    final bars = snapshot?.rawBars ?? const <RawBar>[];
    return <ChipDistributionBar>[
      for (final bar in bars)
        ChipDistributionBar(
          index: bar.index,
          time: bar.time,
          open: bar.open,
          high: bar.high,
          low: bar.low,
          close: bar.close,
          volume: bar.volume,
          priceVolume: bar.chipTickBins.totalByPrice,
          priceSellVolume: bar.chipTickBins.sellByPrice,
          priceBuyVolume: bar.chipTickBins.buyByPrice,
        ),
    ];
  }

  static int resolveTargetIndex({
    required int total,
    required bool isStepMode,
    required int stepIndex,
    required int? crosshairIndex,
    required int? viewEndIndex,
  }) {
    return const ChipTargetResolver().resolve(
      total: total,
      isStepping: isStepMode,
      stepIndex: isStepMode ? stepIndex : null,
      crosshairIndex: isStepMode ? null : crosshairIndex,
      visibleRightIndex: isStepMode ? null : viewEndIndex,
    );
  }
}
