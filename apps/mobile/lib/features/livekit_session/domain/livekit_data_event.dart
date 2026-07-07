import 'dart:convert';

enum LiveKitEventReliability { reliable, lossy }

class LiveKitDataEvent {
  const LiveKitDataEvent({
    required this.type,
    required this.sequence,
    required this.sessionId,
    required this.timestampMs,
    this.turnId,
    this.schemaVersion = 1,
    this.payload = const <String, Object?>{},
  });

  final String type;
  final int sequence;
  final String sessionId;
  final String? turnId;
  final int timestampMs;
  final int schemaVersion;
  final Map<String, Object?> payload;

  List<int> encode() {
    return utf8.encode(
      jsonEncode({
        ...payload,
        'type': type,
        'sequence': sequence,
        'session_id': sessionId,
        if (turnId != null) 'turn_id': turnId,
        'schema_version': schemaVersion,
        'timestamp_ms': timestampMs,
      }),
    );
  }

  static LiveKitDataEvent decode(List<int> data) {
    final decoded = jsonDecode(utf8.decode(data));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('LiveKit data event must be a JSON object.');
    }
    return LiveKitDataEvent(
      type: decoded['type'] as String,
      sequence: decoded['sequence'] as int,
      sessionId: decoded['session_id'] as String,
      turnId: decoded['turn_id'] as String?,
      schemaVersion: (decoded['schema_version'] as int?) ?? 1,
      timestampMs: (decoded['timestamp_ms'] as int?) ?? 0,
      payload: Map<String, Object?>.from(decoded)
        ..remove('type')
        ..remove('sequence')
        ..remove('session_id')
        ..remove('turn_id')
        ..remove('schema_version')
        ..remove('timestamp_ms'),
    );
  }
}

class LiveKitEventDeduplicator {
  LiveKitEventDeduplicator({this.maxSeenEvents = 256});

  final int maxSeenEvents;
  final List<String> _order = <String>[];
  final Set<String> _seen = <String>{};

  bool shouldAccept(LiveKitDataEvent event) {
    final key = '${event.sessionId}:${event.turnId ?? "_"}:${event.sequence}';
    if (_seen.contains(key)) {
      return false;
    }
    _seen.add(key);
    _order.add(key);
    while (_order.length > maxSeenEvents) {
      _seen.remove(_order.removeAt(0));
    }
    return true;
  }
}

class LiveKitEventSequencer {
  int _nextSequence = 1;

  LiveKitDataEvent next({
    required String type,
    required String sessionId,
    String? turnId,
    Map<String, Object?> payload = const <String, Object?>{},
  }) {
    return LiveKitDataEvent(
      type: type,
      sequence: _nextSequence++,
      sessionId: sessionId,
      turnId: turnId,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      payload: payload,
    );
  }
}
