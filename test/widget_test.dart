import 'package:flutter_test/flutter_test.dart';

import 'package:chan_replay_app/app.dart';

void main() {
  testWidgets('app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const ChanReplayApp());

    expect(find.byType(ChanReplayApp), findsOneWidget);
  });
}
