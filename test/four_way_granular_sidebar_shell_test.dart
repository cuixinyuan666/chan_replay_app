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

  testWidgets('swiping a rail moves the connected frame and opens its panel',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(subject());

    final topRail = find.byKey(const ValueKey<String>('top-icon-rail'));
    final initialLeft = tester.getTopLeft(topRail).dx;
    await tester.flingFrom(
      const Offset(24, 100),
      const Offset(240, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('left-category-panel')),
        findsOneWidget);
    expect(tester.getTopLeft(topRail).dx, greaterThan(initialLeft));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a settings icon opens the classified settings panel',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('right-settings-panel')),
        findsOneWidget);
    expect(find.text('K图外观'), findsWidgets);
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
      tester.getSize(find.byKey(const ValueKey<String>('chart-content'))),
      const Size(800, 600),
    );
    expect(find.text('>'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registered panels are mutually exclusive and push content',
      (tester) async {
    final custom = MaterialApp(
      home: Scaffold(
        body: FourWayGranularSidebarShell(
          selectedRouteIndex: 5,
          onOpenRoute: (_) {},
          additionalRegistrations: <SidebarRegistration>[
            SidebarRegistration(
              id: 'custom-system',
              label: '系统设置',
              category: '系统',
              icon: Icons.settings,
              edge: SidebarEdge.left,
              panelBuilder: (_) => const Text('registered system panel'),
            ),
          ],
          child: const ColoredBox(
            key: ValueKey<String>('chart-content'),
            color: Colors.black,
          ),
        ),
      ),
    );
    await tester.pumpWidget(custom);
    await tester.tap(
      find.byKey(const ValueKey<String>('sidebar-entry-appearance')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('right-settings-panel')),
        findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('sidebar-entry-custom-system')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('sidebar-entry-custom-system')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('right-settings-panel')),
        findsNothing);
    expect(find.byKey(const ValueKey<String>('left-category-panel')),
        findsOneWidget);
    expect(find.text('registered system panel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
