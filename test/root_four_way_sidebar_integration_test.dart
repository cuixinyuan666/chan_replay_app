import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chan_replay_app/app.dart';
import 'package:chan_replay_app/ui/pages/chan_settings_page.dart';
import 'package:chan_replay_app/ui/pages/research_backtest_page.dart';

void main() {
  testWidgets('system settings pushes research content without route overlap',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ChanReplayApp());

    await tester.tap(
      find.byKey(const ValueKey<String>('sidebar-entry-research')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ResearchBacktestPage), findsOneWidget);

    final systemEntry =
        find.byKey(const ValueKey<String>('sidebar-entry-system-settings'));
    await tester.ensureVisible(systemEntry);
    await tester.tap(systemEntry);
    await tester.pumpAndSettle();

    expect(find.byType(ResearchBacktestPage), findsOneWidget);
    expect(find.byType(ChanSettingsPage), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('left-category-panel')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
