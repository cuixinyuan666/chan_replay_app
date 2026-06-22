import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chan_replay_app/app.dart';

void main() {
  testWidgets('migrated display and indicator controls remain functional',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ChanReplayApp());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('side-toolbar-toggle')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('sidebar-entry-s13-display-indicators'),
      ),
    );
    await tester.pumpAndSettle();

    final ma = find.widgetWithText(FilterChip, 'MA');
    expect(ma, findsOneWidget);
    expect(tester.widget<FilterChip>(ma).selected, isFalse);

    await tester.tap(ma);
    await tester.pumpAndSettle();

    expect(tester.widget<FilterChip>(ma).selected, isTrue);
    expect(find.text('节奏线设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('every legacy toolbar section is registered on the frame',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ChanReplayApp());
    await tester.pumpAndSettle();

    final cases = <String, String>{
      's13-stock': '状态 / 一键复制',
      's13-levels': 'DAILY',
      's13-replay-marker': '载入复盘',
      's13-display-indicators': '节奏线设置',
    };
    for (final entry in cases.entries) {
      final button = find.byKey(
        ValueKey<String>('sidebar-entry-${entry.key}'),
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsWidgets,
          reason: '${entry.key} should expose its original controls');
    }

    final drawingButton = find.byKey(
      const ValueKey<String>('sidebar-entry-s13-drawing'),
    );
    await tester.ensureVisible(drawingButton);
    await tester.tap(drawingButton);
    await tester.pumpAndSettle();
    expect(find.text('已打开画线工具：趋势线，请在K线图上点击锚点。'), findsOneWidget);
    expect(find.text('打开画线工具'), findsNothing);

    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
