import 'dart:convert';

/// Redacted session export. Callers receive data only; sharing/saving remains a
/// debug-build UI concern so no transcript database rows are ever selected.
class TelemetryExport {
  static String json(List<Map<String, Object?>> envelopes) =>
      const JsonEncoder.withIndent('  ').convert(envelopes);

  static String csv(List<Map<String, Object?>> envelopes) {
    const headings = [
      'session_id',
      'turn_id',
      'terminal_outcome',
      'total_cost_micro_inr',
      'cost_complete',
      'endpoint_commit_ms',
      'tts_first_published_ms',
      'client_first_playback_timestamp_ms',
    ];
    String value(Object? item) => '"${'$item'.replaceAll('"', '""')}"';
    final rows = <String>[headings.join(',')];
    for (final envelope in envelopes) {
      final timestamps = Map<String, Object?>.from(
        envelope['timestamps_ms'] as Map? ?? const <String, Object?>{},
      );
      rows.add(
        [
          envelope['session_id'],
          envelope['turn_id'],
          envelope['terminal_outcome'],
          envelope['total_cost_micro_inr'],
          envelope['cost_complete'],
          timestamps['server_endpoint_commit'],
          timestamps['tts_first_published'],
          timestamps['client_first_playback_timestamp_ms'],
        ].map(value).join(','),
      );
    }
    return rows.join('\n');
  }
}
