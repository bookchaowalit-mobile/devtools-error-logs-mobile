/// Parses pasted log output into entries, filters them and groups repeats.
library;

enum LogLevel { trace, debug, info, warn, error, fatal, unknown }

class LogEntry {
  const LogEntry({
    required this.lineNumber,
    required this.level,
    required this.message,
    this.timestamp,
  });

  final int lineNumber;
  final LogLevel level;
  final String message;
  final String? timestamp;
}

const _levelAliases = {
  'TRACE': LogLevel.trace,
  'DEBUG': LogLevel.debug,
  'DBG': LogLevel.debug,
  'INFO': LogLevel.info,
  'INF': LogLevel.info,
  'NOTICE': LogLevel.info,
  'WARN': LogLevel.warn,
  'WARNING': LogLevel.warn,
  'WRN': LogLevel.warn,
  'ERROR': LogLevel.error,
  'ERR': LogLevel.error,
  'SEVERE': LogLevel.error,
  'FATAL': LogLevel.fatal,
  'CRITICAL': LogLevel.fatal,
  'CRIT': LogLevel.fatal,
  'PANIC': LogLevel.fatal,
};

// Optional ISO-ish or HH:MM:SS timestamp, then an optional [LEVEL] / LEVEL: /
// LEVEL token, then the message.
final _linePattern = RegExp(
  r'^\s*'
  r'(?<ts>\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2})?|\d{2}:\d{2}:\d{2}(?:[.,]\d+)?)?'
  r'\s*'
  r'(?:\[(?<lvl1>[A-Za-z]+)\]|(?<lvl2>[A-Za-z]+)(?=[:\s]|$))?'
  r'\s*:?\s*'
  r'(?<msg>.*)$',
);

LogEntry parseLine(String line, int lineNumber) {
  final m = _linePattern.firstMatch(line)!;
  final ts = m.namedGroup('ts');
  final token = (m.namedGroup('lvl1') ?? m.namedGroup('lvl2'))?.toUpperCase();
  final level = token == null ? null : _levelAliases[token];
  if (level == null) {
    // The first word was not a level; keep it as part of the message.
    final rest =
        ts == null ? line.trim() : line.trim().substring(ts.length).trim();
    return LogEntry(
      lineNumber: lineNumber,
      level: LogLevel.unknown,
      message: rest,
      timestamp: ts,
    );
  }
  return LogEntry(
    lineNumber: lineNumber,
    level: level,
    message: m.namedGroup('msg')!.trim(),
    timestamp: ts,
  );
}

/// Parses every non-blank line. Indented continuation lines (stack traces)
/// are attached to the previous entry's message.
List<LogEntry> parseLog(String text) {
  final entries = <LogEntry>[];
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;
    final isContinuation = entries.isNotEmpty &&
        (line.startsWith(RegExp(r'\s+at ')) ||
            line.startsWith(RegExp(r'\s+#\d')));
    if (isContinuation) {
      final prev = entries.removeLast();
      entries.add(
        LogEntry(
          lineNumber: prev.lineNumber,
          level: prev.level,
          message: '${prev.message}\n${line.trim()}',
          timestamp: prev.timestamp,
        ),
      );
      continue;
    }
    entries.add(parseLine(line, i + 1));
  }
  return entries;
}

List<LogEntry> filterEntries(
  List<LogEntry> entries, {
  Set<LogLevel>? levels,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  return entries
      .where((e) => levels == null || levels.contains(e.level))
      .where((e) => q.isEmpty || e.message.toLowerCase().contains(q))
      .toList();
}

class MessageGroup {
  const MessageGroup(this.signature, this.level, this.count, this.firstLine);

  final String signature;
  final LogLevel level;
  final int count;
  final int firstLine;
}

/// Normalises volatile parts (numbers, hex ids, quoted values) so repeated
/// errors with different ids group together.
String signatureOf(String message) {
  final firstLine = message.split('\n').first;
  return firstLine
      .replaceAll(RegExp(r'0x[0-9a-fA-F]+'), '<hex>')
      .replaceAll(
        RegExp(
            r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b'),
        '<uuid>',
      )
      .replaceAll(RegExp(r'''(["'])[^"']*\1'''), '<str>')
      .replaceAll(RegExp(r'\d+'), '<n>')
      .trim();
}

/// Groups entries at or above [minLevel] by signature, most frequent first.
List<MessageGroup> groupRepeats(
  List<LogEntry> entries, {
  LogLevel minLevel = LogLevel.warn,
}) {
  final counts = <String, MessageGroup>{};
  for (final e in entries) {
    if (e.level == LogLevel.unknown || e.level.index < minLevel.index) continue;
    final sig = signatureOf(e.message);
    final key = '${e.level.name}|$sig';
    final prev = counts[key];
    counts[key] = MessageGroup(
      sig,
      e.level,
      (prev?.count ?? 0) + 1,
      prev?.firstLine ?? e.lineNumber,
    );
  }
  final list = counts.values.toList()
    ..sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.firstLine.compareTo(b.firstLine);
    });
  return list;
}

Map<LogLevel, int> countByLevel(List<LogEntry> entries) {
  final out = <LogLevel, int>{};
  for (final e in entries) {
    out[e.level] = (out[e.level] ?? 0) + 1;
  }
  return out;
}
