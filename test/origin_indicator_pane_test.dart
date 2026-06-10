import 'package:chan_replay_app/core/models/chan_snapshot.dart';
import 'package:chan_replay_app/core/models/easy_tdx_indicator.dart';
import 'package:chan_replay_app/core/models/raw_bar.dart';
import 'package:chan_replay_app/ui/widgets/origin_indicator_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('OriginIndicatorPane renders VOL and MACD panes from snapshot indicators',
      (tester) async {
    final snapshot = _snapshotWithIndicators();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: 220,
            child: OriginIndicatorPane(
              snapshot: snapshot,
              showVol: true,
              showMacd: true,
              windowSize: 60,
              viewEndIndex: snapshot.rawBars.length - 1,
              crosshairIndex: 10,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(OriginIndicatorPane), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OriginIndicatorPane collapses when no pane is enabled',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OriginIndicatorPane(
            snapshot: _snapshotWithIndicators(),
            showVol: false,
            showMacd: false,
            windowSize: 30,
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

ChanSnapshot _snapshotWithIndicators() {
  final base = DateTime(2024, 1, 1);
  final bars = <RawBar>[
    for (var i = 0; i < 40; i++)
      RawBar(
        index: i,
        time: base.add(Duration(days: i)),
        open: 10 + i * 0.08,
        high: 10.4 + i * 0.08,
        low: 9.8 + i * 0.08,
        close: i.isEven ? 10.2 + i * 0.08 : 9.95 + i * 0.08,
        volume: 1000 + i * 25,
      ),
  ];
  return ChanSnapshot(
    rawBars: bars,
    mergedBars: const [],
    fxs: const [],
    bis: const [],
    segs: const [],
    zss: const [],
    indicators: EasyTdxIndicators(
      vol: [
        for (final bar in bars)
          EasyIndicatorPoint(
            time: bar.time,
            rawIndex: bar.index,
            value: bar.volume,
          ),
      ],
      macd: [
        for (final bar in bars)
          EasyMacdPoint(
            time: bar.time,
            rawIndex: bar.index,
            dif: (bar.index - 18) / 100,
            dea: (bar.index - 16) / 120,
            hist: ((bar.index % 9) - 4) / 80,
          ),
      ],
    ),
  );
}
