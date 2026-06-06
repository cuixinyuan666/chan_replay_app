class MergedBar {
  final int index;
  final int startRawIndex;
  final int endRawIndex;
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const MergedBar({
    required this.index,
    required this.startRawIndex,
    required this.endRawIndex,
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  MergedBar copyWith({
    int? index,
    int? startRawIndex,
    int? endRawIndex,
    DateTime? time,
    double? open,
    double? high,
    double? low,
    double? close,
    double? volume,
  }) {
    return MergedBar(
      index: index ?? this.index,
      startRawIndex: startRawIndex ?? this.startRawIndex,
      endRawIndex: endRawIndex ?? this.endRawIndex,
      time: time ?? this.time,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
    );
  }
}
