import 'package:error_logs/main.dart';
import 'package:error_logs/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell shows logs and about tab', (tester) async {
    await tester.pumpWidget(const ErrorLogsApp());
    expect(find.text('Error Logs'), findsWidgets);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('Features'), findsOneWidget);
  });

  testWidgets('sample log is grouped and filterable', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    String count() =>
        tester.widget<Text>(find.byKey(const Key('entry-count'))).data!;
    expect(count(), 'Entries (6 of 6)');
    expect(find.text('Timeout calling payments id=<n>'), findsOneWidget);

    await tester.tap(find.text('debug (1)'));
    await tester.pump();
    expect(count(), 'Entries (5 of 6)');

    await tester.enterText(find.byKey(const Key('query-input')), 'memory');
    await tester.pump();
    expect(count(), 'Entries (1 of 6)');
  });
}
