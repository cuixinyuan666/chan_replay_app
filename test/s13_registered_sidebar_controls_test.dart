import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chan_replay_app/app.dart';
import 'package:chan_replay_app/ui/widgets/four_way_granular_sidebar_shell.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ChanReplayApp());
    await tester.pumpAndSettle();
    if (fourWaySidebarRegistry.entries.value.isEmpty) {
      final klineRoute =
          find.byKey(const ValueKey<String>('sidebar-corner-kline'));
      await tester.ensureVisible(klineRoute);
      await tester.tap(klineRoute);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('S13 granular controls are registered directly on the frame',
      (tester) async {
    await pumpApp(tester);

    expect(
      find.byKey(const ValueKey<String>('side-toolbar-toggle')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('sidebar-entry-s13-levels')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('sidebar-entry-s13-replay-marker')),
      findsNothing,
    );
    expect(
      find.byKey(
          const ValueKey<String>('sidebar-entry-s13-display-indicators')),
      findsNothing,
    );

    final registeredIds = {
      for (final entry in fourWaySidebarRegistry.entries.value) entry.id,
    };
    for (final id in <String>[
      's13-symbol-input',
      's13-level-TICK',
      's13-level-TICK_MIN1',
      's13-level-DAILY',
      's13-level-MIN60',
      's13-level-MIN30',
      's13-level-MIN15',
      's13-level-MIN5',
      's13-level-MIN1',
      's13-mode-once',
      's13-mode-step',
      's13-indicator-MA',
      's13-show-interval-nest',
      's13-show-chip-distribution',
      's13-drawing',
    ]) {
      expect(registeredIds, contains(id),
          reason: '$id should be registered as a sidebar entry');
    }
    expect(
      find.byKey(const ValueKey<String>('sidebar-corner-load-replay')),
      findsOneWidget,
    );

    expect(find.text('校验'), findsNothing);
    expect(find.text('当前'), findsNothing);
    expect(find.text('导出BSP JSON'), findsNothing);
    expect(find.text('检查当前买卖点'), findsNothing);
    expect(find.text('BSP统计'), findsNothing);
    expect(find.text('BSP分组'), findsNothing);
    expect(find.text('复制BSP报告'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct sidebar controls can be activated without panels',
      (tester) async {
    await pumpApp(tester);

    fourWaySidebarRegistry.entries.value
        .firstWhere((entry) => entry.id == 's13-indicator-MA')
        .onActivate
        ?.call();
    await tester.pumpAndSettle();

    fourWaySidebarRegistry.entries.value
        .firstWhere((entry) => entry.id == 's13-mode-step')
        .onActivate
        ?.call();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('right-settings-panel')),
        findsNothing);
    expect(find.byKey(const ValueKey<String>('left-category-panel')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });
}
