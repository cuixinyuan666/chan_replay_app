import 'package:chan_replay_app/ui/widgets/chart_time_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('15 minute data displays date and minute precision', () {
    final times = <DateTime>[
      DateTime(2026, 2, 9, 10),
      DateTime(2026, 2, 9, 10, 15),
    ];
    expect(ChartTimeFormatter.format(times.last, times), '2026-02-09 1015');
  });

  test('daily data keeps date precision', () {
    final times = <DateTime>[DateTime(2026, 2, 9), DateTime(2026, 2, 10)];
    expect(ChartTimeFormatter.format(times.last, times), '2026-02-10');
  });
}
