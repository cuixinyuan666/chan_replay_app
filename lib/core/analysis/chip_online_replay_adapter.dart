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
        if (bar.chipTickBins == null)
          ChipDistributionBar(
            index: bar.index,
            time: bar.time,
            open: bar.open,
            high: bar.high,
            low: bar.low,
            close: bar.close,
            volume: bar.volume,
          )
        else
          ChipDistributionBar.fromJson(
            <String, dynamic>{
              'x': bar.index,
              'dt': bar.time.toIso8601String(),
              'open': bar.open,
              'high': bar.high,
              'low': bar.low,
              'close': bar.close,
              'volume': bar.volume,
              'chip_tick_bins': bar.chipTickBins,
            },
            bar.index,
          ),
    ];
  }

  /// 统一筹码分布目标 K 选择。
  ///
  /// once 模式：crosshairIndex > viewEndIndex > lastBarIndex。
  /// step 模式：crosshairIndex > stepIndex。只要用户移动十字线，右侧筹码
  /// 就展示十字线对应 K 的筹码状态；没有十字线时才回到当前 stepIndex。
  /// 筹码引擎仍只计算 targetIndex 及其之前的 bars，不使用目标 K 之后数据。
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
      final requested = crosshairIndex ?? stepIndex;
      return requested.clamp(0, last).toInt();
    }
    final requested = crosshairIndex ?? viewEndIndex ?? last;
    return requested.clamp(0, last).toInt();
  }
}
