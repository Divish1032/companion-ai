import 'dart:convert';

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
  final AppDatabase _database;
  final List<_TraceEntry> _entries = [];

  MemoryLookupTraceObserver(this._database);

  /// Records that a user message was processed for memory extraction.
  void recordAdmission({
    required String turnId,
    String? result,
    String? label,
    String? reason,
    int timestampMs = 0,
  }) {
    _entries.add(_TraceEntry(
      stage: 'admission',
      turnId: turnId,
      result: result ?? 'unknown',
      label: label,
      reason: reason,
      timestampMs: timestampMs,
    ));
  }

  /// Records a retrieval call and its results.
  void recordRetrieval({
    required String queryTextHash,
    List<String> memoryIds = const [],
    List<String> labels = const [],
    int packetCount = 0,
    int elapsedMs = 0,
    String? route,
    String? strategy,
  }) {
    _entries.add(_TraceEntry(
      stage: 'retrieval',
      queryTextHash: queryTextHash,
      memoryIds: memoryIds,
      labels: labels,
      packetCount: packetCount,
      elapsedMs: elapsedMs,
      route: route,
      strategy: strategy,
    ));
  }

  /// Records a receipt state change.
  void recordReceipt({
    required String memoryId,
    String? result,
    String? previousState,
    String? newState,
  }) {
    _entries.add(_TraceEntry(
      stage: 'receipt',
      memoryId: memoryId,
      result: result ?? 'unknown',
      previousState: previousState,
      newState: newState,
    ));
  }

  /// Records consolidation results.
  void recordConsolidation({
    int staleCount = 0,
    int decayedCount = 0,
    int agedCount = 0,
    int currentCount = 0,
  }) {
    _entries.add(_TraceEntry(
      stage: 'consolidation',
      staleCount: staleCount,
      decayedCount: decayedCount,
      agedCount: agedCount,
      currentCount: currentCount,
    ));
  }

  /// Returns a redacted snapshot of all trace entries.
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

  /// Clears all recorded trace entries.
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

  // Retrieval fields
  final String? queryTextHash;
  final List<String> memoryIds;
  final List<String> labels;
  final int? packetCount;
  final int? elapsedMs;
  final String? route;
  final String? strategy;

  // Receipt fields
  final String? memoryId;
  final String? previousState;
  final String? newState;

  // Consolidation fields
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
    if (turnId != null) json['turn_id'] = turnId;
    if (result != null) json['result'] = result;
    if (label != null) json['label'] = label;
    if (reason != null) json['reason'] = reason;
    if (timestampMs != null) json['timestamp_ms'] = timestampMs;
    if (queryTextHash != null) json['query_text_hash'] = queryTextHash;
    if (memoryIds.isNotEmpty) json['memory_ids'] = memoryIds;
    if (labels.isNotEmpty) json['labels'] = labels;
    if (packetCount != null) json['packet_count'] = packetCount;
    if (elapsedMs != null) json['elapsed_ms'] = elapsedMs;
    if (route != null) json['route'] = route;
    if (strategy != null) json['strategy'] = strategy;
    if (memoryId != null) json['memory_id'] = memoryId;
    if (previousState != null) json['previous_state'] = previousState;
    if (newState != null) json['new_state'] = newState;
    if (staleCount != null) json['stale_count'] = staleCount;
    if (decayedCount != null) json['decayed_count'] = decayedCount;
    if (agedCount != null) json['aged_count'] = agedCount;
    if (currentCount != null) json['current_count'] = currentCount;
    return json;
  }
}
