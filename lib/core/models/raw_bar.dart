import '../analysis/chip_distribution.dart';

class RawBar {
  final int index;
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  /// Optional backend-provided a_replay_trainer.py style chip bins.
  ///
  /// Kept on the raw bar so the online analyze_multi -> ChanSnapshot ->
  /// chip distribution path can preserve exact p/s/b/w buckets when the backend
  /// provides them. When absent, the chip engine still falls back to OHLCV.
  final ChipTickBins chipTickBins;

  const RawBar({
    required this.index,
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.chipTickBins = const ChipTickBins(),
  });

  RawBar copyWith({
    int? index,
    DateTime? time,
    double? open,
    double? high,
    double? low,
    double? close,
    double? volume,
    ChipTickBins? chipTickBins,
  }) {
    return RawBar(
      index: index ?? this.index,
      time: time ?? this.time,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
      chipTickBins: chipTickBins ?? this.chipTickBins,
    );
  }
}
