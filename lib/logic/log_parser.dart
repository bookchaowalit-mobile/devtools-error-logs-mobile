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

const _ts = r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?'
    r'(?:Z|[+-]\d{2}:?\d{2})?|\d{2}:\d{2}:\d{2}(?:[.,]\d+)?';

// Optional ISO-ish or HH:MM:SS timestamp, bare or in [brackets].
final _prefixPattern = RegExp('^\\s*(?:\\[(?<ts1>$_ts)\\]|(?<ts2>$_ts))?\\s*');

// Optional [LEVEL] / LEVEL: / LEVEL token, then the message. dotAll so that
// stray line separators (U+2028, lone CR) never make the match fail.
final _levelPattern = RegExp(
  r'^(?:\[(?<lvl1>[A-Za-z]+)\]|(?<lvl2>[A-Za-z]+)(?=[:\s]|$))\s*:?\s*(?<msg>.*)$',
  dotAll: true,
);

LogEntry parseLine(String line, int lineNumber) {
  // The prefix pattern can match the empty string, so it always matches.
  final prefix = _prefixPattern.firstMatch(line)!;
  final ts = prefix.namedGroup('ts1') ?? prefix.namedGroup('ts2');
  final rest = line.substring(prefix.end);
  final m = _levelPattern.firstMatch(rest);
  final token = (m?.namedGroup('lvl1') ?? m?.namedGroup('lvl2'))?.toUpperCase();
  final level = token == null ? null : _levelAliases[token];
  if (level == null) {
    // The first word was not a level; keep it as part of the message.
    return LogEntry(
      lineNumber: lineNumber,
      level: LogLevel.unknown,
      message: rest.trim(),
      timestamp: ts,
    );
  }
  return LogEntry(
    lineNumber: lineNumber,
    level: level,
    message: m!.namedGroup('msg')!.trim(),
    timestamp: ts,
  );
}

// Stack-trace continuation lines: Dart/JS/Java frames (`  at ...`, `  #0`),
// Python frames (`  File "..."`), Java `Caused by:` and `... 12 more`.
final _continuation = RegExp(
  r'^(?:\s+at |\s+#\d|\s+File "|\s+\.\.\. \d+ more|Caused by: )',
);

/// Parses every non-blank line. Indented continuation lines (stack traces)
/// are attached to the previous entry's message.
List<LogEntry> parseLog(String text) {
  final entries = <LogEntry>[];
  // CRLF and lone CR both end a line (a lone CR used to crash parseLine).
  final lines =
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  var afterPythonFrame = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;
    final isFrame = _continuation.hasMatch(line);
    // Python echoes the source line, indented, under each `File "..."` frame.
    final isSourceEcho = afterPythonFrame && line.startsWith(RegExp(r'\s'));
    afterPythonFrame = line.trimLeft().startsWith('File "');
    final isContinuation = entries.isNotEmpty && (isFrame || isSourceEcho);
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
      // A quote right after a letter is an apostrophe (can't), not a quote.
      .replaceAll(RegExp(r'''(?<![A-Za-z])(["'])[^"'\n]*\1'''), '<str>')
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
