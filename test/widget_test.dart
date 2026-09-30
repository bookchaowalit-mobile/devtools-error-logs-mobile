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

  Widget home({double textScale = 1}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const HomeScreen(),
        ),
      );

  testWidgets('pasting a log with lone CR line endings does not crash', (
    tester,
  ) async {
    await tester.pumpWidget(home());
    await tester.enterText(
      find.byKey(const Key('log-input')),
      'ERROR a\rERROR a\rWARN b',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Text>(find.byKey(const Key('entry-count'))).data,
      'Entries (3 of 3)',
    );
  });

  testWidgets('empty input shows empty states', (tester) async {
    await tester.pumpWidget(home());
    await tester.enterText(find.byKey(const Key('log-input')), '');
    await tester.pump();
    expect(find.text('None found.'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('entry-count'))).data,
      'Entries (0 of 0)',
    );
  });

  testWidgets('repeat counts are announced as times', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(home());
    await tester.enterText(
      find.byKey(const Key('log-input')),
      'ERROR x 1\nERROR x 2',
    );
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('2 times')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('meets tap-target, label and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(home());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('lays out at 200% text scale without overflow', (tester) async {
    await tester.pumpWidget(home(textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
