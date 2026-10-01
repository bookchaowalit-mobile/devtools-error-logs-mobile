import 'package:flutter/material.dart';

import '../logic/log_parser.dart';

const _sample = '''2026-09-30 10:00:01 INFO Server started on port 8080
2026-09-30 10:00:05 [WARN] Slow query took 1200ms
2026-09-30 10:00:07 ERROR Timeout calling payments id=42
    at PaymentsClient.charge (payments.dart:88)
2026-09-30 10:00:09 ERROR Timeout calling payments id=43
2026-09-30 10:00:10 DEBUG cache hit user=7
2026-09-30 10:00:12 FATAL Out of memory''';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _input = TextEditingController(text: _sample);
  final _query = TextEditingController();
  final Set<LogLevel> _levels = {...LogLevel.values};

  @override
  void dispose() {
    _input.dispose();
    _query.dispose();
    super.dispose();
  }

  Color? _colorFor(LogLevel level, ColorScheme c) => switch (level) {
        LogLevel.error || LogLevel.fatal => c.error,
        LogLevel.warn => c.tertiary,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entries = parseLog(_input.text);
    final counts = countByLevel(entries);
    final visible = filterEntries(entries, levels: _levels, query: _query.text);
    final groups = groupRepeats(entries);
    return Scaffold(
      appBar: AppBar(title: const Text('Error Logs')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('log-input'),
            controller: _input,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Paste log output',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final l in LogLevel.values)
                if ((counts[l] ?? 0) > 0)
                  FilterChip(
                    label: Text('${l.name} (${counts[l]})'),
                    selected: _levels.contains(l),
                    onSelected: (on) => setState(
                      () => on ? _levels.add(l) : _levels.remove(l),
                    ),
                  ),
            ],
          ),
          TextField(
            key: const Key('query-input'),
            controller: _query,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search messages',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text('Top repeated warnings and errors',
              style: textTheme.titleMedium),
          if (groups.isEmpty) const Text('None found.'),
          for (final g in groups.take(5))
            ListTile(
              dense: true,
              leading: CircleAvatar(
                child: Text(
                  '${g.count}',
                  semanticsLabel:
                      '${g.count} ${g.count == 1 ? 'time' : 'times'}',
                ),
              ),
              title: Text(g.signature),
              subtitle: Text('${g.level.name} · first on line ${g.firstLine}'),
            ),
          const SizedBox(height: 16),
          Text(
            'Entries (${visible.length} of ${entries.length})',
            key: const Key('entry-count'),
            style: textTheme.titleMedium,
          ),
          for (final e in visible)
            ListTile(
              dense: true,
              leading: Text(
                e.level.name.toUpperCase(),
                style: TextStyle(
                  color: _colorFor(e.level, colors),
                  fontWeight: FontWeight.bold,
                ),
              ),
              title: Text(
                e.message.isEmpty ? '(no message)' : e.message,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              subtitle: Text('line ${e.lineNumber}'
                  '${e.timestamp == null ? '' : ' · ${e.timestamp}'}'),
            ),
        ],
      ),
    );
  }
}
