import 'dart:math' as math;

import 'memory_v3_models.dart';

const memoryV3AutoAdmissionSttThreshold = 0.78;

class MemoryV3AdmissionSource {
  const MemoryV3AdmissionSource({
    required this.id,
    required this.turnId,
    required this.role,
    required this.text,
    required this.status,
    required this.createdAtMs,
    this.sttConfidence,
  });

  factory MemoryV3AdmissionSource.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final turnId = json['turn_id'];
    final role = json['role'];
    final text = json['text'];
    final status = json['status'];
    final createdAtMs = json['created_at_ms'];
    final sttConfidence = json['stt_confidence'];
    if (id is! String ||
        turnId is! String ||
        role is! String ||
        text is! String ||
        status is! String ||
        createdAtMs is! int ||
        (sttConfidence != null && sttConfidence is! num)) {
      throw const FormatException('Invalid Memory V3 admission source.');
    }
    return MemoryV3AdmissionSource(
      id: id,
      turnId: turnId,
      role: role == 'ai' ? 'assistant' : role,
      text: text,
      status: status,
      createdAtMs: createdAtMs,
      sttConfidence: (sttConfidence as num?)?.toDouble(),
    );
  }

  final String id;
  final String turnId;
  final String role;
  final String text;
  final String status;
  final int createdAtMs;
  final double? sttConfidence;
}

class GroundedMemoryV3Evidence {
  const GroundedMemoryV3Evidence({
    required this.source,
    required this.fragment,
    required this.startChar,
    required this.endChar,
  });

  final MemoryV3AdmissionSource source;
  final String fragment;
  final int startChar;
  final int endChar;
}

class MemoryV3CandidateAdmission {
  const MemoryV3CandidateAdmission({
    required this.disposition,
    required this.reason,
    required this.evidence,
    required this.temporalStatus,
    required this.epistemicConfidence,
    required this.observedAtMs,
  });

  final String disposition;
  final String reason;
  final List<GroundedMemoryV3Evidence> evidence;
  final String temporalStatus;
  final double epistemicConfidence;
  final int observedAtMs;

  bool get mayStore =>
      {'admitted', 'deferred', 'confirmation_required'}.contains(disposition);

  Map<String, Object?> toJson() => {
    'disposition': disposition,
    'reason': reason,
    'temporal_status': temporalStatus,
    'epistemic_confidence': epistemicConfidence,
    'observed_at_ms': observedAtMs,
    'evidence': [
      for (final item in evidence)
        {
          'source_id': item.source.id,
          'turn_id': item.source.turnId,
          'role': item.source.role,
          'fragment': item.fragment,
          'start_char': item.startChar,
          'end_char': item.endChar,
        },
    ],
  };
}

const memoryV3PredicatesByKind = <String, Set<String>>{
  'profile': {'preferred_name', 'works_at', 'profile_association'},
  'relationship': {'has_relationship', 'relationship_association'},
  'preference': {
    'response_language',
    'response_length',
    'support_style',
    'likes',
    'dislikes',
  },
  'routine': {'follows_routine'},
  'goal': {'pursues_goal'},
  'value': {'holds_value'},
  'boundary': {'avoids_topic'},
  'episode': {
    'experienced_event',
    'event_outcome',
    'causes_stress',
    'episode_association',
  },
  'open_thread': {'open_thread'},
  'assistant_commitment': {'assistant_commitment'},
};

MemoryV3CandidateAdmission validateMemoryV3Candidate(
  MemoryV3Observation candidate,
  List<MemoryV3AdmissionSource> sources,
) {
  MemoryV3CandidateAdmission reject(String reason) =>
      MemoryV3CandidateAdmission(
        disposition: 'rejected',
        reason: reason,
        evidence: const [],
        temporalStatus: candidate.temporal.status,
        epistemicConfidence: candidate.epistemic.confidence,
        observedAtMs: sources.isEmpty
            ? 0
            : sources.map((item) => item.createdAtMs).reduce(math.max),
      );

  if (!(memoryV3PredicatesByKind[candidate.kind] ?? const <String>{}).contains(
    candidate.predicate,
  )) {
    return reject('kind_predicate_mismatch');
  }

  final grounded = <GroundedMemoryV3Evidence>[];
  final uniqueSources = <String>{};
  for (final evidence in candidate.evidence) {
    final matches = sources
        .where(
          (source) =>
              source.turnId == evidence.turnId && source.role == evidence.role,
        )
        .toList(growable: false);
    if (matches.length != 1) return reject('unknown_or_ambiguous_source');
    final source = matches.single;
    if (!{
      'final',
      'final_corrected',
      'safety_override',
    }.contains(source.status)) {
      return reject('non_final_source');
    }
    if (source.status == 'safety_override') {
      return reject('safety_ephemeral_source');
    }
    final start = evidence.startChar ?? source.text.indexOf(evidence.fragment);
    final end = evidence.endChar ?? start + evidence.fragment.length;
    if (start < 0 ||
        end > source.text.length ||
        source.text.substring(start, end) != evidence.fragment) {
      return reject('evidence_fragment_mismatch');
    }
    if (evidence.startChar == null &&
        source.text.lastIndexOf(evidence.fragment) != start) {
      return reject('ambiguous_evidence_fragment');
    }
    final sourceKey = '${source.id}|$start|$end';
    if (!uniqueSources.add(sourceKey)) {
      return reject('duplicate_evidence_reference');
    }
    grounded.add(
      GroundedMemoryV3Evidence(
        source: source,
        fragment: evidence.fragment,
        startChar: start,
        endChar: end,
      ),
    );
  }

  final roles = grounded.map((item) => item.source.role).toSet();
  final evidenceTurnIds = grounded.map((item) => item.source.turnId).toSet();
  if (sources.any(
    (source) =>
        evidenceTurnIds.contains(source.turnId) &&
        source.status == 'safety_override',
  )) {
    return reject('safety_ephemeral_exchange');
  }
  if (candidate.kind == 'assistant_commitment') {
    if (candidate.epistemic.explicitness != 'assistant_only' ||
        roles.length != 1 ||
        !roles.contains('assistant')) {
      return reject('invalid_assistant_commitment_provenance');
    }
  } else if (candidate.epistemic.explicitness == 'assistant_only' ||
      roles.any((role) => role != 'user')) {
    return reject('assistant_to_user_contamination');
  }
  if (candidate.epistemic.quoted) return reject('quoted_statement');
  if (candidate.epistemic.hypothetical) return reject('hypothetical_statement');
  if (candidate.epistemic.negated) return reject('negated_candidate');
  if (!entityLocallyGrounded(
    candidate.subject,
    grounded,
    allowUserMarker: true,
  )) {
    return reject('subject_not_locally_grounded');
  }
  if (!objectLocallyGrounded(candidate.object, grounded)) {
    return reject('object_not_locally_grounded');
  }

  final groundedText = [
    candidate.object.text,
    for (final item in grounded) item.fragment,
  ].join(' ');
  final localSensitivity = classifyLocalMemorySensitivity(groundedText);
  if (localSensitivity == 'forbidden') return reject('local_forbidden_content');
  if (localSensitivity == 'restricted') {
    return reject('local_restricted_ephemeral');
  }
  if (candidate.privacy.sensitivity != 'normal' ||
      !{
        'automatic',
        'explicit_only',
      }.contains(candidate.privacy.durableEligibility)) {
    return reject('compiler_sensitive_or_ephemeral');
  }

  final userEvidence = grounded.where((item) => item.source.role == 'user');
  final confidenceValues = userEvidence
      .map((item) => item.source.sttConfidence)
      .toList(growable: false);
  final confidenceKnown = confidenceValues.every((value) => value != null);
  final minimumSttConfidence = confidenceValues.isEmpty
      ? 1.0
      : confidenceValues.map((value) => value ?? 0.5).reduce(math.min);
  final sttAllowsAutoAdmission =
      confidenceKnown &&
      minimumSttConfidence >= memoryV3AutoAdmissionSttThreshold;
  final cappedEpistemicConfidence = math.min(
    candidate.epistemic.confidence,
    minimumSttConfidence,
  );
  final observedAt = grounded
      .map((item) => item.source.createdAtMs)
      .reduce(math.max);

  var disposition = 'admitted';
  var reason = 'explicit_grounded_low_risk';
  if (candidate.epistemic.explicitness == 'implied') {
    disposition = 'deferred';
    reason = 'interpretive_observation';
  } else if (candidate.epistemic.confidence < 0.75) {
    disposition = 'deferred';
    reason = 'low_compiler_confidence';
  } else if (!sttAllowsAutoAdmission) {
    disposition = 'deferred';
    reason = confidenceKnown ? 'low_stt_confidence' : 'unknown_stt_confidence';
  } else if (candidate.temporal.status != 'current' &&
      candidate.temporal.resolutionConfidence < 0.7) {
    disposition = 'deferred';
    reason = 'uncertain_temporal_resolution';
  } else if (looksInstructionLikeMemory(candidate.object.text)) {
    disposition = 'confirmation_required';
    reason = 'instruction_like_memory';
  } else if (candidate.utility.confirmationRequired ||
      candidate.privacy.durableEligibility == 'explicit_only') {
    disposition = 'confirmation_required';
    reason = 'explicit_confirmation_required';
  }
  return MemoryV3CandidateAdmission(
    disposition: disposition,
    reason: reason,
    evidence: List.unmodifiable(grounded),
    temporalStatus:
        sttAllowsAutoAdmission &&
            (candidate.temporal.status == 'current' ||
                candidate.temporal.resolutionConfidence >= 0.7)
        ? candidate.temporal.status
        : 'uncertain',
    epistemicConfidence: cappedEpistemicConfidence,
    observedAtMs: observedAt,
  );
}

bool objectLocallyGrounded(
  MemoryV3ObjectValue object,
  List<GroundedMemoryV3Evidence> evidence,
) {
  final source = normalizeMemoryV3Text(
    evidence.map((item) => item.fragment).join(' '),
  );
  final objectText = normalizeMemoryV3Text(object.text);
  if (objectText.length < 2 || !source.contains(objectText)) return false;
  final target = object.targetEntity;
  if (target == null) return true;
  return entityLocallyGrounded(target, evidence);
}

bool entityLocallyGrounded(
  MemoryV3EntityMention entity,
  List<GroundedMemoryV3Evidence> evidence, {
  bool allowUserMarker = false,
}) {
  if (allowUserMarker &&
      entity.entityType == 'user' &&
      entity.mention == 'user' &&
      entity.relationshipHint == null) {
    return true;
  }
  final source = normalizeMemoryV3Text(
    evidence.map((item) => item.fragment).join(' '),
  );
  final mention = normalizeMemoryV3Text(entity.mention);
  if (mention.length < 2 || !source.contains(mention)) return false;
  final relationship = entity.relationshipHint;
  if (relationship == null) return true;
  final normalizedRelationship = normalizeMemoryV3Text(relationship);
  return normalizedRelationship.length >= 2 &&
      source.contains(normalizedRelationship);
}

bool looksInstructionLikeMemory(String value) => RegExp(
  r'ignore (all |the )?(previous|prior) instructions|system prompt|developer message|call me administrator|act as (an? )?administrator',
  caseSensitive: false,
).hasMatch(value);

String classifyLocalMemorySensitivity(String value) {
  final text = value.toLowerCase();
  if (RegExp(
    r'\b(password|passcode|otp|pin|cvv|api[ _-]?key|secret key|seed phrase)\b|पासवर्ड|ओटीपी|पिन',
  ).hasMatch(text)) {
    return 'forbidden';
  }
  if (RegExp(
    r'\b(suicide|suicidal|self[ -]?harm|kill myself|end my life)\b|आत्महत्या|खुदकुशी|खुद को मार|मरना चाहता|मरना चाहती',
  ).hasMatch(text)) {
    return 'forbidden';
  }
  if (RegExp(
    r'\b(diagnos|medication|therapy|therapist|psychiatr|doctor|hospital|lawsuit|lawyer|legal case|bank account|salary|debt|religion|caste|sexual orientation|home address)\b|इलाज|दवाई|बीमारी|वकील|अदालत|जाति|धर्म|तनख्वाह|कर्ज',
  ).hasMatch(text)) {
    return 'restricted';
  }
  if (RegExp(
        r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
        caseSensitive: false,
      ).hasMatch(value) ||
      RegExp(r'(?<!\d)(?:\+?91[ -]?)?[6-9]\d{9}(?!\d)').hasMatch(value) ||
      RegExp(r'(?<!\d)\d{12,19}(?!\d)').hasMatch(value)) {
    return 'restricted';
  }
  return 'normal';
}

String normalizeMemoryV3Text(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'[^a-z0-9\u0900-\u097f ]'), '');
