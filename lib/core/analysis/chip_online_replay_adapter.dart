import '../models/chan_snapshot.dart';
import '../models/raw_bar.dart';
import 'chip_distribution.dart';

/// 在线 analyze_multi -> 筹码分布输入的轻量适配层。
///
/// 当前阶段只接入在线 K 线，不读取离线分笔文件；如果后端后续把
/// chip_tick_bins 放入 kline_all JSON，可继续通过 ChipDistributionBar.fromJson
/// 进入同一计算引擎。
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
        ),
    ];
  }

  /// 统一筹码分布目标 K 选择。
  ///
  /// once 模式：crosshairIndex > viewEndIndex > lastBarIndex。
  /// step 模式：优先十字线，但不能超过当前 stepIndex；超过则 clamp 到 stepIndex。
  static int resolveTargetIndex({
    required int total,
    required bool isStepMode,
    required int stepIndex,
    required int? crosshairIndex,
    required int? viewEndIndex,
  }) {
    if (total <= 0) return 0;
    final last = total - 1;
    if (isStepMode) {
      final maxAllowed = stepIndex.clamp(0, last).toInt();
      final requested = crosshairIndex ?? maxAllowed;
      return requested.clamp(0, maxAllowed).toInt();
    }
    final requested = crosshairIndex ?? viewEndIndex ?? last;
    return requested.clamp(0, last).toInt();
  }
}
