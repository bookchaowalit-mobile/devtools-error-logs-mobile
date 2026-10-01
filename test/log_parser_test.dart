import 'package:error_logs/logic/log_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses common line formats', () {
    final a = parseLine('2026-09-30T10:00:01.123Z [ERROR] boom', 1);
    expect(a.level, LogLevel.error);
    expect(a.message, 'boom');
    expect(a.timestamp, '2026-09-30T10:00:01.123Z');

    final b = parseLine('WARNING: disk almost full', 2);
    expect(b.level, LogLevel.warn);
    expect(b.message, 'disk almost full');
    expect(b.timestamp, isNull);

    final c = parseLine('10:00:01 info started', 3);
    expect(c.level, LogLevel.info);
    expect(c.message, 'started');

    final d = parseLine('Something happened', 4);
    expect(d.level, LogLevel.unknown);
    expect(d.message, 'Something happened');

    final e = parseLine('2026-09-30 10:00:00 Hello there', 5);
    expect(e.level, LogLevel.unknown);
    expect(e.message, 'Hello there');
  });

  test('parseLog skips blanks and attaches stack frames', () {
    final entries = parseLog(
      'ERROR first\r\n    at a.dart:1\n\n  #0 main (b.dart:2)\nINFO second\n',
    );
    expect(entries, hasLength(2));
    expect(entries[0].message, 'first\nat a.dart:1\n#0 main (b.dart:2)');
    expect(entries[1].lineNumber, 5);
  });

  test('filterEntries by level and query', () {
    final entries = parseLog('ERROR a timeout\nINFO ok\nWARN slow timeout');
    expect(
      filterEntries(entries, levels: {LogLevel.error, LogLevel.warn})
          .map((e) => e.message),
      ['a timeout', 'slow timeout'],
    );
    expect(filterEntries(entries, query: 'TIMEOUT'), hasLength(2));
    expect(filterEntries(entries, levels: {LogLevel.info}, query: 'time'),
        isEmpty);
  });

  test('signature normalises volatile values', () {
    expect(signatureOf('Timeout id=42 after 1200ms'),
        'Timeout id=<n> after <n>ms');
    expect(signatureOf("User 'bob' not found"), 'User <str> not found');
    expect(signatureOf('ptr 0xDEADBEEF'), 'ptr <hex>');
    expect(
      signatureOf('req 123e4567-e89b-12d3-a456-426614174000 failed'),
      'req <uuid> failed',
    );
  });

  test('groupRepeats counts warn+ messages, most frequent first', () {
    final entries = parseLog('''
ERROR Timeout id=1
INFO Timeout id=9
WARN slow
ERROR Timeout id=2
ERROR Timeout id=3
WARN slow''');
    final groups = groupRepeats(entries);
    expect(groups.map((g) => [g.signature, g.count, g.firstLine]).toList(), [
      ['Timeout id=<n>', 3, 1],
      ['slow', 2, 3],
    ]);
    expect(countByLevel(entries)[LogLevel.error], 3);
  });

  group('edge cases (pass 3)', () {
    test('lone CR and Unicode line separators no longer crash', () {
      final entries = parseLog('INFO a\rWARN b\rERROR c\u2028d');
      expect(entries.map((e) => e.level), [
        LogLevel.info,
        LogLevel.warn,
        LogLevel.error,
      ]);
      expect(entries.last.message, 'c\u2028d');
      expect(parseLine('\u2028', 1).level, LogLevel.unknown);
    });

    test('bracketed timestamps', () {
      final a = parseLine('[2026-01-01 10:00:00] ERROR boom', 1);
      expect(a.level, LogLevel.error);
      expect(a.timestamp, '2026-01-01 10:00:00');
      expect(a.message, 'boom');
      final b = parseLine('[10:00:01,250] [warn] slow', 2);
      expect(b.level, LogLevel.warn);
      expect(b.timestamp, '10:00:01,250');
      final c = parseLine('[10:00:01] just text', 3);
      expect(c.level, LogLevel.unknown);
      expect(c.message, 'just text');
    });

    test('empty, level-only and whitespace lines', () {
      expect(parseLog(''), isEmpty);
      expect(parseLog(' \n\t\n'), isEmpty);
      final e = parseLine('ERROR', 1);
      expect(e.level, LogLevel.error);
      expect(e.message, '');
      expect(parseLine('Errors happen', 1).level, LogLevel.unknown);
    });

    test('Java and Python traces are attached to their entry', () {
      final entries = parseLog(
        'ERROR java.lang.IllegalStateException: x\n'
        '\tat A.b(A.java:1)\n'
        'Caused by: java.io.IOException: y\n'
        '\t... 12 more\n'
        'ERROR Traceback (most recent call last):\n'
        '  File "app.py", line 3, in <module>\n'
        '    main()\n'
        'INFO done',
      );
      expect(entries.map((e) => e.lineNumber), [1, 5, 8]);
      expect(entries[0].message, contains('Caused by: java.io.IOException: y'));
      expect(entries[0].message, endsWith('... 12 more'));
      expect(entries[1].message, endsWith('main()'));
    });

    test('indented lines are only attached after a Python frame', () {
      final entries = parseLog('INFO a\n    indented note');
      expect(entries, hasLength(2));
    });

    test('apostrophes do not swallow the message in signatures', () {
      expect(
        signatureOf("can't find user 'bob' (attempt 3)"),
        "can't find user <str> (attempt <n>)",
      );
      expect(signatureOf('path "C:\\tmp" missing'), 'path <str> missing');
    });

    test('Thai and emoji messages group and filter', () {
      final entries =
          parseLog('ERROR ชำระเงินล้มเหลว 42\nERROR ชำระเงินล้มเหลว 43 😀');
      expect(groupRepeats(entries), hasLength(2));
      expect(signatureOf(entries.first.message), 'ชำระเงินล้มเหลว <n>');
      expect(filterEntries(entries, query: 'ล้มเหลว'), hasLength(2));
    });
  });
}
