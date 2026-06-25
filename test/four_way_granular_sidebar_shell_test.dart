import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chan_replay_app/ui/widgets/four_way_granular_sidebar_shell.dart';

void main() {
  Widget subject() => MaterialApp(
        home: Scaffold(
          body: FourWayGranularSidebarShell(
            selectedRouteIndex: 1,
            onOpenRoute: (_) {},
            child: const ColoredBox(
              key: ValueKey<String>('chart-content'),
              color: Colors.black,
            ),
          ),
        ),
      );

  for (final size in <Size>[
    const Size(480, 320),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('lays out without exceptions at ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(find.byKey(const ValueKey<String>('left-icon-rail')))
            .width,
        48,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey<String>('right-icon-rail')))
            .width,
        48,
      );
    });
  }

  testWidgets('rails do not render redundant edge arrow buttons',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(subject());

    expect(
        find.byKey(const ValueKey<String>('sidebar-edge-left')), findsNothing);
    expect(
        find.byKey(const ValueKey<String>('sidebar-edge-right')), findsNothing);
    expect(
        find.byKey(const ValueKey<String>('sidebar-edge-top')), findsNothing);
    expect(find.byKey(const ValueKey<String>('sidebar-edge-bottom')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a settings icon opens the classified settings panel',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('sidebar-open-panel')),
        findsOneWidget);
    expect(find.text('K图外观'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('price bucket count opens as a sidebar panel', (tester) async {
    await tester.pumpWidget(subject());
    await tester.tap(find.byKey(const ValueKey<String>('sidebar-entry-chips')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('sidebar-open-panel')),
        findsOneWidget);
    expect(find.text('价格桶数'), findsWidgets);
    expect(find.textContaining('chip_bin_count_source'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mouse wheel rotates rails without pointer exceptions',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(subject());

    final topRail = find.byKey(const ValueKey<String>('top-icon-rail'));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(topRail),
        scrollDelta: const Offset(0, 240),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(topRail, findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('right-icon-rail')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'global angle toggle hides all rails and lets content fill screen',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(subject());

    await tester.tap(
      find.byKey(const ValueKey<String>('sidebar-visibility-toggle')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('left-icon-rail')), findsNothing);
    expect(find.byKey(const ValueKey<String>('right-icon-rail')), findsNothing);
    expect(find.byKey(const ValueKey<String>('top-icon-rail')), findsNothing);
    expect(
        find.byKey(const ValueKey<String>('bottom-icon-rail')), findsNothing);
    expect(
        find.byKey(const ValueKey<String>('app-close-corner')), findsNothing);
    expect(find.byKey(const ValueKey<String>('sidebar-corner-kline')),
        findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('chart-content'))),
      const Size(800, 600),
    );
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registered panels are mutually exclusive and push content',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.tap(
      find.byKey(const ValueKey<String>('sidebar-entry-appearance')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('sidebar-open-panel')),
        findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('sidebar-entry-chips')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('sidebar-open-panel')),
        findsOneWidget);
    expect(find.text('价格桶数'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
