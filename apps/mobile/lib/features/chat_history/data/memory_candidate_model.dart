/// Typed `memory_judge_v1` wire models.
///
/// Every judge decision is untrusted input: parsing is strict and throws
/// [FormatException] so a malformed response becomes an `invalid` outcome
/// instead of a partial mutation.
library;

const memoryJudgeActions = {'accept', 'update', 'supersede', 'reject'};

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
    if (json['kind'] is! String ||
        json['subject'] is! String ||
        json['predicate'] is! String ||
        json['object_text'] is! String ||
        json['temporal_status'] is! String ||
        json['explicitness'] is! String ||
        json['confidence'] is! num ||
        json['future_utility'] is! num ||
        json['sensitivity'] is! String ||
        json['evidence_role'] is! String ||
        json['suggested_action'] is! String ||
        sources is! List ||
        sources.any((item) => item is! String)) {
      throw const FormatException('Invalid memory judge proposal.');
    }
    return ExtractedMemoryCandidate(
      kind: json['kind']! as String,
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
      sourceTurnIds: sources.cast<String>().toList(growable: false),
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

class MemoryJudgeDecision {
  const MemoryJudgeDecision({
    required this.decisionId,
    required this.action,
    required this.proposal,
  });

  factory MemoryJudgeDecision.fromJson(Map<String, Object?> json) {
    final decisionId = json['decision_id'];
    final action = json['action'];
    final proposal = json['proposal'];
    if (decisionId is! String ||
        decisionId.length < 16 ||
        decisionId.length > 160 ||
        action is! String ||
        !memoryJudgeActions.contains(action) ||
        proposal is! Map<String, Object?>) {
      throw const FormatException('Invalid memory judge decision.');
    }
    return MemoryJudgeDecision(
      decisionId: decisionId,
      action: action,
      proposal: ExtractedMemoryCandidate.fromJson(proposal),
    );
  }

  final String decisionId;
  final String action;
  final ExtractedMemoryCandidate proposal;
}

class MemoryJudgeCost {
  const MemoryJudgeCost({
    required this.source,
    required this.inputTokens,
    required this.outputTokens,
    required this.estimatedMicroInr,
  });

  factory MemoryJudgeCost.fromJson(Map<String, Object?> json) {
    final source = json['source'];
    final inputTokens = json['input_tokens'];
    final outputTokens = json['output_tokens'];
    final estimatedMicroInr = json['estimated_micro_inr'];
    if (source is! String ||
        !{'provider_reported', 'estimated', 'unknown'}.contains(source) ||
        inputTokens is! int ||
        inputTokens < 0 ||
        outputTokens is! int ||
        outputTokens < 0 ||
        estimatedMicroInr is! int ||
        estimatedMicroInr < 0) {
      throw const FormatException('Invalid memory judge cost.');
    }
    return MemoryJudgeCost(
      source: source,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      estimatedMicroInr: estimatedMicroInr,
    );
  }

  static const unknown = MemoryJudgeCost(
    source: 'unknown',
    inputTokens: 0,
    outputTokens: 0,
    estimatedMicroInr: 0,
  );

  final String source;
  final int inputTokens;
  final int outputTokens;
  final int estimatedMicroInr;
}

class MemoryJudgeEnvelope {
  const MemoryJudgeEnvelope({
    required this.jobId,
    required this.cost,
    required this.decisions,
  });

  final String jobId;
  final MemoryJudgeCost cost;
  final List<MemoryJudgeDecision> decisions;
}
