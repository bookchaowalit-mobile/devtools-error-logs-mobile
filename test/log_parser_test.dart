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
}
