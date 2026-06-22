import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chan_replay_app/ui/widgets/auto_collapsible_side_toolbar.dart';

void main() {
  Widget subject({bool initiallyExpanded = false}) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: <Widget>[
            const Positioned.fill(child: Text('chart')),
            AutoCollapsibleSideToolbar(
              initiallyExpanded: initiallyExpanded,
              sections: const <SideToolbarSection>[
                SideToolbarSection(
                  title: 'tools',
                  children: <Widget>[Text('tool content')],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('collapsed toggle opens the toolbar', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text('tool content'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('side-toolbar-toggle')),
    );
    await tester.pumpAndSettle();

    expect(find.text('tool content'), findsOneWidget);
    expect(find.text('<'), findsOneWidget);
  });

  testWidgets('initially expanded toolbar is visible', (tester) async {
    await tester.pumpWidget(subject(initiallyExpanded: true));

    expect(find.text('tool content'), findsOneWidget);
  });
}
