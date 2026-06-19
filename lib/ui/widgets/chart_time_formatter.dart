class ChartTimeFormatter {
  const ChartTimeFormatter._();

  static Duration minimumGranularity(Iterable<DateTime> times) {
    final sorted = times.toList()..sort();
    Duration? minimum;
    for (var i = 1; i < sorted.length; i++) {
      final delta = sorted[i].difference(sorted[i - 1]).abs();
      if (delta == Duration.zero) continue;
      if (minimum == null || delta < minimum) minimum = delta;
    }
    return minimum ?? const Duration(days: 1);
  }

  static String format(DateTime value, Iterable<DateTime> series) {
    final granularity = minimumGranularity(series);
    final date = '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    if (granularity >= const Duration(days: 1)) return date;
    final minute = '${value.hour.toString().padLeft(2, '0')}'
        '${value.minute.toString().padLeft(2, '0')}';
    if (granularity >= const Duration(minutes: 1)) return '$date $minute';
    return '$date $minute${value.second.toString().padLeft(2, '0')}';
  }
}
