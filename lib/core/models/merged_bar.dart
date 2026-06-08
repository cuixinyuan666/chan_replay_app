class MergedBar {
  final int index;
  final int startRawIndex;
  final int endRawIndex;
  final int highRawIndex;
  final int lowRawIndex;
  final DateTime time;
  final DateTime highTime;
  final DateTime lowTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const MergedBar({
    required this.index,
    required this.startRawIndex,
    required this.endRawIndex,
    required this.highRawIndex,
    required this.lowRawIndex,
    required this.time,
    required this.highTime,
    required this.lowTime,
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
    int? highRawIndex,
    int? lowRawIndex,
    DateTime? time,
    DateTime? highTime,
    DateTime? lowTime,
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
      highRawIndex: highRawIndex ?? this.highRawIndex,
      lowRawIndex: lowRawIndex ?? this.lowRawIndex,
      time: time ?? this.time,
      highTime: highTime ?? this.highTime,
      lowTime: lowTime ?? this.lowTime,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
    );
  }
}
