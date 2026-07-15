import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../chat_history/data/app_database.dart';
import '../data/telemetry_export.dart';

class TelemetryDiagnosticsScreen extends StatefulWidget {
  const TelemetryDiagnosticsScreen({
    required this.database,
    required this.sessionId,
    super.key,
  });

  final AppDatabase database;
  final String sessionId;

  @override
  State<TelemetryDiagnosticsScreen> createState() =>
      _TelemetryDiagnosticsScreenState();
}

class _TelemetryDiagnosticsScreenState
    extends State<TelemetryDiagnosticsScreen> {
  late Future<List<Map<String, Object?>>> _events = widget.database
      .readTelemetryForSession(widget.sessionId);

  void _reload() => setState(
    () => _events = widget.database.readTelemetryForSession(widget.sessionId),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Diagnostics'),
      actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _events,
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <Map<String, Object?>>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: events.isEmpty
                      ? null
                      : () => _copy(TelemetryExport.json(events)),
                  child: const Text('Copy JSON'),
                ),
                OutlinedButton(
                  onPressed: events.isEmpty
                      ? null
                      : () => _copy(TelemetryExport.csv(events)),
                  child: const Text('Copy CSV'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (events.isEmpty)
              const Text('No redacted terminal turn telemetry yet.')
            else
              for (final event in events) _TelemetryCard(event: event),
          ],
        );
      },
    ),
  );

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Redacted export copied.')));
    }
  }
}

class _TelemetryCard extends StatelessWidget {
  const _TelemetryCard({required this.event});
  final Map<String, Object?> event;

  @override
  Widget build(BuildContext context) {
    final timestamps = event['timestamps_ms'] as Map? ?? const {};
    final costs = event['costs_micro_inr'] as Map? ?? const {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${event['turn_id']} · ${event['terminal_outcome']}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              'Cost: ${(event['total_cost_micro_inr'] as num? ?? 0) / 1000000} INR · complete: ${event['cost_complete']}',
            ),
            Text(
              'Waterfall: endpoint ${timestamps['server_endpoint_commit'] ?? '-'} · TTS publish ${timestamps['tts_first_published'] ?? '-'} · playback report ${timestamps['client_first_playback_timestamp_ms'] ?? '-'}',
            ),
            Text('Line items (micro-INR): $costs'),
          ],
        ),
      ),
    );
  }
}
