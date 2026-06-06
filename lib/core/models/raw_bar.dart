class RawBar {
  final int index;
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const RawBar({
    required this.index,
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  RawBar copyWith({
    int? index,
    DateTime? time,
    double? open,
    double? high,
    double? low,
    double? close,
    double? volume,
  }) {
    return RawBar(
      index: index ?? this.index,
      time: time ?? this.time,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
    );
  }
}
