import 'package:companion_mobile/features/chat_history/data/app_database.dart';

/// Test-only trace observer for diagnosing memory pipeline decisions.
///
/// Wraps an [AppDatabase] and records redacted admission, retrieval, receipt,
/// and consolidation decisions. Never records transcript or memory content text.
///
/// Usage:
/// ```dart
/// final observer = MemoryLookupTraceObserver(database);
/// await database.upsertUserMessageAndExtractMemory(...);
/// await database.readMemoryContext(...);
/// print(jsonEncode(observer.snapshot()));
/// ```
class MemoryLookupTraceObserver {
  final List<_TraceEntry> _entries = [];

  MemoryLookupTraceObserver(AppDatabase _);

  void recordAdmission({
    required String turnId,
    String? result,
    String? label,
    String? reason,
    int timestampMs = 0,
  }) {
    _entries.add(
      _TraceEntry(
        stage: 'admission',
        turnId: turnId,
        result: result ?? 'unknown',
        label: label,
        reason: reason,
        timestampMs: timestampMs,
      ),
    );
  }

  void recordRetrieval({
    required String queryTextHash,
    List<String> memoryIds = const [],
    List<String> labels = const [],
    int packetCount = 0,
    int elapsedMs = 0,
    String? route,
    String? strategy,
  }) {
    _entries.add(
      _TraceEntry(
        stage: 'retrieval',
        queryTextHash: queryTextHash,
        memoryIds: memoryIds,
        labels: labels,
        packetCount: packetCount,
        elapsedMs: elapsedMs,
        route: route,
        strategy: strategy,
      ),
    );
  }

  void recordReceipt({
    required String memoryId,
    String? result,
    String? previousState,
    String? newState,
  }) {
    _entries.add(
      _TraceEntry(
        stage: 'receipt',
        memoryId: memoryId,
        result: result ?? 'unknown',
        previousState: previousState,
        newState: newState,
      ),
    );
  }

  void recordConsolidation({
    int staleCount = 0,
    int decayedCount = 0,
    int agedCount = 0,
    int currentCount = 0,
  }) {
    _entries.add(
      _TraceEntry(
        stage: 'consolidation',
        staleCount: staleCount,
        decayedCount: decayedCount,
        agedCount: agedCount,
        currentCount: currentCount,
      ),
    );
  }

  Map<String, dynamic> snapshot() {
    return {
      'total_entries': _entries.length,
      'by_stage': _stageCounts(),
      'entries': _entries.map((e) => e.toJson()).toList(),
    };
  }

  Map<String, int> _stageCounts() {
    final counts = <String, int>{};
    for (final entry in _entries) {
      counts[entry.stage] = (counts[entry.stage] ?? 0) + 1;
    }
    return counts;
  }

  void clear() {
    _entries.clear();
  }
}

class _TraceEntry {
  final String stage;
  final String? turnId;
  final String? result;
  final String? label;
  final String? reason;
  final int? timestampMs;
  final String? queryTextHash;
  final List<String> memoryIds;
  final List<String> labels;
  final int? packetCount;
  final int? elapsedMs;
  final String? route;
  final String? strategy;
  final String? memoryId;
  final String? previousState;
  final String? newState;
  final int? staleCount;
  final int? decayedCount;
  final int? agedCount;
  final int? currentCount;

  _TraceEntry({
    required this.stage,
    this.turnId,
    this.result,
    this.label,
    this.reason,
    this.timestampMs,
    this.queryTextHash,
    this.memoryIds = const [],
    this.labels = const [],
    this.packetCount,
    this.elapsedMs,
    this.route,
    this.strategy,
    this.memoryId,
    this.previousState,
    this.newState,
    this.staleCount,
    this.decayedCount,
    this.agedCount,
    this.currentCount,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'stage': stage};
    _putIf(json, 'turn_id', turnId);
    _putIf(json, 'result', result);
    _putIf(json, 'label', label);
    _putIf(json, 'reason', reason);
    _putIf(json, 'timestamp_ms', timestampMs);
    _putIf(json, 'query_text_hash', queryTextHash);
    if (memoryIds.isNotEmpty) json['memory_ids'] = memoryIds;
    if (labels.isNotEmpty) json['labels'] = labels;
    _putIf(json, 'packet_count', packetCount);
    _putIf(json, 'elapsed_ms', elapsedMs);
    _putIf(json, 'route', route);
    _putIf(json, 'strategy', strategy);
    _putIf(json, 'memory_id', memoryId);
    _putIf(json, 'previous_state', previousState);
    _putIf(json, 'new_state', newState);
    _putIf(json, 'stale_count', staleCount);
    _putIf(json, 'decayed_count', decayedCount);
    _putIf(json, 'aged_count', agedCount);
    _putIf(json, 'current_count', currentCount);
    return json;
  }

  static void _putIf(Map<String, dynamic> target, String key, Object? value) {
    if (value != null) target[key] = value;
  }
}
