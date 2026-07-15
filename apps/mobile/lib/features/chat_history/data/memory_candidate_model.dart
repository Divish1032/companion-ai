class ExtractedMemoryCandidate {
  const ExtractedMemoryCandidate({
    required this.kind,
    required this.subject,
    required this.predicate,
    required this.objectText,
    required this.temporalStatus,
    required this.explicitness,
    required this.confidence,
    required this.futureUtility,
    required this.sensitivity,
    required this.sourceTurnIds,
    required this.evidenceRole,
    required this.suggestedAction,
    required this.followUpAllowed,
    required this.proactiveAllowed,
    this.eventStartAt,
    this.eventEndAt,
  });

  factory ExtractedMemoryCandidate.fromJson(Map<String, Object?> json) {
    final sources = json['source_turn_ids'];
    return ExtractedMemoryCandidate(
      kind: json['candidate_kind']! as String,
      subject: json['subject']! as String,
      predicate: json['predicate']! as String,
      objectText: json['object_text']! as String,
      eventStartAt: (json['event_start_at_ms'] as num?)?.toInt(),
      eventEndAt: (json['event_end_at_ms'] as num?)?.toInt(),
      temporalStatus: json['temporal_status']! as String,
      explicitness: json['explicitness']! as String,
      confidence: (json['confidence']! as num).toDouble(),
      futureUtility: (json['future_utility']! as num).toDouble(),
      sensitivity: json['sensitivity']! as String,
      sourceTurnIds: sources is List
          ? sources.whereType<String>().toList(growable: false)
          : const [],
      evidenceRole: json['evidence_role']! as String,
      suggestedAction: json['suggested_action']! as String,
      followUpAllowed: json['follow_up_allowed'] == true,
      proactiveAllowed: json['proactive_allowed'] == true,
    );
  }

  final String kind;
  final String subject;
  final String predicate;
  final String objectText;
  final int? eventStartAt;
  final int? eventEndAt;
  final String temporalStatus;
  final String explicitness;
  final double confidence;
  final double futureUtility;
  final String sensitivity;
  final List<String> sourceTurnIds;
  final String evidenceRole;
  final String suggestedAction;
  final bool followUpAllowed;
  final bool proactiveAllowed;
}
