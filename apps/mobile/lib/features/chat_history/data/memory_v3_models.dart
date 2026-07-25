import 'dart:convert';

const memoryV3CompileContractVersion = 'memory_compile_v3_1';
const memoryV3CompileSchemaVersion = 3;

const memoryV3ObservationKinds = <String>{
  'profile',
  'relationship',
  'preference',
  'routine',
  'goal',
  'value',
  'boundary',
  'episode',
  'open_thread',
  'assistant_commitment',
};

const memoryV3Predicates = <String>{
  'preferred_name',
  'has_relationship',
  'response_language',
  'response_length',
  'support_style',
  'likes',
  'dislikes',
  'avoids_topic',
  'follows_routine',
  'pursues_goal',
  'holds_value',
  'experienced_event',
  'event_outcome',
  'open_thread',
  'assistant_commitment',
  'works_at',
  'profile_association',
  'relationship_association',
  'episode_association',
  'causes_stress',
};

const memoryV3EntityTypes = <String>{
  'user',
  'person',
  'organization',
  'place',
  'event',
  'goal',
  'preference',
  'routine',
  'topic',
  'value',
};

const memoryV3FormationOperation = 'ADD';

final _candidateIdPattern = RegExp(r'^candidate_[A-Za-z0-9_-]{8,128}$');

class MemoryV3CompileEnvelope {
  const MemoryV3CompileEnvelope({
    required this.jobId,
    required this.candidates,
    required this.model,
    this.noMemoryReason,
  });

  factory MemoryV3CompileEnvelope.parse(String expectedJobId, String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const FormatException('Memory V3 compile response is not JSON.');
    }
    final json = _object(decoded, 'compile response');
    _keys(
      json,
      required: const {
        'schema_version',
        'job_id',
        'contract_version',
        'candidates',
        'model',
      },
      optional: const {'no_memory_reason'},
      label: 'compile response',
    );
    if (_integer(json, 'schema_version') != memoryV3CompileSchemaVersion ||
        _text(json, 'job_id', min: 1, max: 175) != expectedJobId ||
        _text(json, 'contract_version', min: 1, max: 80) !=
            memoryV3CompileContractVersion) {
      throw const FormatException('Memory V3 compile envelope mismatch.');
    }
    final rawCandidates = _list(json, 'candidates', max: 24);
    final candidates = rawCandidates
        .map((item) => MemoryV3Observation.fromJson(_object(item, 'candidate')))
        .toList(growable: false);
    final ids = candidates.map((item) => item.candidateId).toSet();
    if (ids.length != candidates.length) {
      throw const FormatException('Duplicate Memory V3 candidate ID.');
    }
    return MemoryV3CompileEnvelope(
      jobId: expectedJobId,
      candidates: candidates,
      noMemoryReason: _nullableText(json, 'no_memory_reason', max: 240),
      model: MemoryV3CompilerModel.fromJson(_object(json['model'], 'model')),
    );
  }

  final String jobId;
  final List<MemoryV3Observation> candidates;
  final String? noMemoryReason;
  final MemoryV3CompilerModel model;
}

class MemoryV3CompilerModel {
  const MemoryV3CompilerModel({
    required this.provider,
    required this.model,
    required this.promptVersion,
    required this.usageSource,
    required this.inputTokens,
    required this.outputTokens,
    this.estimatedMicroInr,
  });

  factory MemoryV3CompilerModel.fromJson(Map<String, Object?> json) {
    _keys(
      json,
      required: const {
        'provider',
        'model',
        'prompt_version',
        'usage_source',
        'input_tokens',
        'output_tokens',
      },
      optional: const {'estimated_micro_inr'},
      label: 'compiler model',
    );
    final usage = _text(json, 'usage_source', min: 1, max: 40);
    if (!{'provider_reported', 'estimated', 'unknown'}.contains(usage)) {
      throw const FormatException('Invalid compiler usage source.');
    }
    final inputTokens = _integer(json, 'input_tokens');
    final outputTokens = _integer(json, 'output_tokens');
    final estimated = _optionalInteger(json, 'estimated_micro_inr');
    if (inputTokens < 0 ||
        outputTokens < 0 ||
        (estimated != null && estimated < 0)) {
      throw const FormatException('Invalid compiler usage values.');
    }
    return MemoryV3CompilerModel(
      provider: _text(json, 'provider', min: 1, max: 80),
      model: _text(json, 'model', min: 1, max: 160),
      promptVersion: _text(json, 'prompt_version', min: 1, max: 80),
      usageSource: usage,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      estimatedMicroInr: estimated,
    );
  }

  final String provider;
  final String model;
  final String promptVersion;
  final String usageSource;
  final int inputTokens;
  final int outputTokens;
  final int? estimatedMicroInr;
}

class MemoryV3Observation {
  const MemoryV3Observation({
    required this.candidateId,
    required this.kind,
    required this.subject,
    required this.predicate,
    required this.object,
    required this.evidence,
    required this.temporal,
    required this.epistemic,
    required this.utility,
    required this.privacy,
    required this.proposedOperation,
    this.affect,
  });

  factory MemoryV3Observation.fromJson(Map<String, Object?> json) {
    _keys(
      json,
      required: const {
        'schema_version',
        'candidate_id',
        'kind',
        'subject',
        'predicate',
        'object',
        'evidence',
        'temporal',
        'epistemic',
        'utility',
        'privacy',
        'proposed_operation',
      },
      optional: const {'affect'},
      label: 'observation',
    );
    if (_integer(json, 'schema_version') != memoryV3CompileSchemaVersion) {
      throw const FormatException('Invalid observation schema version.');
    }
    final candidateId = _text(json, 'candidate_id', min: 1, max: 140);
    final kind = _text(json, 'kind', min: 1, max: 80);
    final predicate = _text(json, 'predicate', min: 1, max: 80);
    final operation = _text(json, 'proposed_operation', min: 1, max: 20);
    if (!_candidateIdPattern.hasMatch(candidateId) ||
        !memoryV3ObservationKinds.contains(kind) ||
        !memoryV3Predicates.contains(predicate) ||
        operation != memoryV3FormationOperation) {
      throw const FormatException('Unknown Memory V3 ontology value.');
    }
    final rawEvidence = _list(json, 'evidence', min: 1, max: 12);
    final evidence = rawEvidence
        .map((item) => MemoryV3Evidence.fromJson(_object(item, 'evidence')))
        .toList(growable: false);
    final evidenceKeys = evidence
        .map(
          (item) =>
              '${item.turnId}|${item.role}|${item.startChar}|${item.endChar}|${item.fragment}',
        )
        .toSet();
    if (evidenceKeys.length != evidence.length) {
      throw const FormatException('Duplicate observation evidence.');
    }
    final affectJson = json['affect'];
    if (affectJson == null && json.containsKey('affect')) {
      throw const FormatException('Optional affect must be omitted, not null.');
    }
    return MemoryV3Observation(
      candidateId: candidateId,
      kind: kind,
      subject: MemoryV3EntityMention.fromJson(
        _object(json['subject'], 'subject'),
      ),
      predicate: predicate,
      object: MemoryV3ObjectValue.fromJson(_object(json['object'], 'object')),
      evidence: evidence,
      temporal: MemoryV3Temporal.fromJson(
        _object(json['temporal'], 'temporal'),
      ),
      epistemic: MemoryV3Epistemic.fromJson(
        _object(json['epistemic'], 'epistemic'),
      ),
      affect: affectJson == null
          ? null
          : MemoryV3Affect.fromJson(_object(affectJson, 'affect')),
      utility: MemoryV3Utility.fromJson(_object(json['utility'], 'utility')),
      privacy: MemoryV3Privacy.fromJson(_object(json['privacy'], 'privacy')),
      proposedOperation: operation,
    );
  }

  final String candidateId;
  final String kind;
  final MemoryV3EntityMention subject;
  final String predicate;
  final MemoryV3ObjectValue object;
  final List<MemoryV3Evidence> evidence;
  final MemoryV3Temporal temporal;
  final MemoryV3Epistemic epistemic;
  final MemoryV3Affect? affect;
  final MemoryV3Utility utility;
  final MemoryV3Privacy privacy;
  final String proposedOperation;
}

class MemoryV3EntityMention {
  const MemoryV3EntityMention({
    required this.entityType,
    required this.mention,
    this.relationshipHint,
  });

  factory MemoryV3EntityMention.fromJson(Map<String, Object?> json) {
    _keys(
      json,
      required: const {'entity_type', 'mention'},
      optional: const {'relationship_hint'},
      label: 'entity mention',
    );
    final type = _text(json, 'entity_type', min: 1, max: 40);
    if (!memoryV3EntityTypes.contains(type)) {
      throw const FormatException('Unknown entity type.');
    }
    return MemoryV3EntityMention(
      entityType: type,
      mention: _text(json, 'mention', min: 1, max: 120),
      relationshipHint: _optionalText(json, 'relationship_hint', max: 80),
    );
  }

  final String entityType;
  final String mention;
  final String? relationshipHint;
}

class MemoryV3ObjectValue {
  const MemoryV3ObjectValue({
    required this.text,
    this.normalizedValue,
    this.targetEntity,
    this.userAssessment,
  });

  factory MemoryV3ObjectValue.fromJson(Map<String, Object?> json) {
    _keys(
      json,
      required: const {'text'},
      optional: const {'normalized_value', 'target_entity', 'user_assessment'},
      label: 'object value',
    );
    final normalized = json['normalized_value'];
    if (normalized != null &&
        normalized is! String &&
        normalized is! num &&
        normalized is! bool) {
      throw const FormatException('Invalid normalized memory value.');
    }
    final target = json['target_entity'];
    if (target == null && json.containsKey('target_entity')) {
      throw const FormatException('Optional target entity cannot be null.');
    }
    return MemoryV3ObjectValue(
      text: _text(json, 'text', min: 1, max: 500),
      normalizedValue: normalized,
      targetEntity: target == null
          ? null
          : MemoryV3EntityMention.fromJson(_object(target, 'target entity')),
      userAssessment: _optionalText(json, 'user_assessment', max: 240),
    );
  }

  final String text;
  final Object? normalizedValue;
  final MemoryV3EntityMention? targetEntity;
  final String? userAssessment;
}

class MemoryV3Evidence {
  const MemoryV3Evidence({
    required this.turnId,
    required this.role,
    required this.fragment,
    this.startChar,
    this.endChar,
  });

  factory MemoryV3Evidence.fromJson(Map<String, Object?> json) {
    _keys(
      json,
      required: const {'turn_id', 'role', 'fragment'},
      optional: const {'start_char', 'end_char'},
      label: 'evidence',
    );
    final role = _text(json, 'role', min: 1, max: 20);
    if (!{'user', 'assistant'}.contains(role)) {
      throw const FormatException('Unknown evidence role.');
    }
    final start = _optionalInteger(json, 'start_char');
    final end = _optionalInteger(json, 'end_char');
    if ((start == null) != (end == null) ||
        (start != null && (start < 0 || end! <= start))) {
      throw const FormatException('Invalid evidence offsets.');
    }
    return MemoryV3Evidence(
      turnId: _text(json, 'turn_id', min: 1, max: 128),
      role: role,
      fragment: _text(json, 'fragment', min: 1, max: 500),
      startChar: start,
      endChar: end,
    );
  }

  final String turnId;
  final String role;
  final String fragment;
  final int? startChar;
  final int? endChar;
}

class MemoryV3Temporal {
  const MemoryV3Temporal({
    required this.status,
    required this.resolutionConfidence,
    this.eventStartAtMs,
    this.eventEndAtMs,
    this.rawExpression,
  });

  factory MemoryV3Temporal.fromJson(Map<String, Object?> json) {
    _keys(
      json,
      required: const {'status', 'resolution_confidence'},
      optional: const {
        'event_start_at_ms',
        'event_end_at_ms',
        'raw_expression',
      },
      label: 'temporal',
    );
    final status = _text(json, 'status', min: 1, max: 20);
    final start = _nullableInteger(json, 'event_start_at_ms');
    final end = _nullableInteger(json, 'event_end_at_ms');
    if (!{'current', 'past', 'future', 'uncertain'}.contains(status) ||
        (start != null && start < 0) ||
        (end != null && (end < 0 || (start != null && end < start)))) {
      throw const FormatException('Invalid observation time.');
    }
    return MemoryV3Temporal(
      status: status,
      eventStartAtMs: start,
      eventEndAtMs: end,
      rawExpression: _nullableText(json, 'raw_expression', max: 120),
      resolutionConfidence: _score(json, 'resolution_confidence'),
    );
  }

  final String status;
  final int? eventStartAtMs;
  final int? eventEndAtMs;
  final String? rawExpression;
  final double resolutionConfidence;
}

class MemoryV3Epistemic {
  const MemoryV3Epistemic({
    required this.explicitness,
    required this.confidence,
    required this.negated,
    required this.hypothetical,
    required this.quoted,
  });

  factory MemoryV3Epistemic.fromJson(Map<String, Object?> json) {
    _keys(
      json,
      required: const {
        'explicitness',
        'confidence',
        'negated',
        'hypothetical',
        'quoted',
      },
      optional: const {},
      label: 'epistemic',
    );
    final explicitness = _text(json, 'explicitness', min: 1, max: 30);
    if (!{'explicit', 'implied', 'assistant_only'}.contains(explicitness)) {
      throw const FormatException('Invalid observation explicitness.');
    }
    return MemoryV3Epistemic(
      explicitness: explicitness,
      confidence: _score(json, 'confidence'),
      negated: _boolean(json, 'negated'),
      hypothetical: _boolean(json, 'hypothetical'),
      quoted: _boolean(json, 'quoted'),
    );
  }

  final String explicitness;
  final double confidence;
  final bool negated;
  final bool hypothetical;
  final bool quoted;
}

class MemoryV3Affect {
  const MemoryV3Affect({
    required this.emotion,
    required this.valence,
    required this.arousal,
    required this.intensity,
    required this.confidence,
    this.target,
    this.cause,
  });

  factory MemoryV3Affect.fromJson(Map<String, Object?> json) {
    _keys(
      json,
      required: const {
        'emotion',
        'valence',
        'arousal',
        'intensity',
        'confidence',
      },
      optional: const {'target', 'cause'},
      label: 'affect',
    );
    final emotion = _text(json, 'emotion', min: 1, max: 40);
    if (!{
      'joy',
      'sadness',
      'anger',
      'fear',
      'frustration',
      'loneliness',
      'anxiety',
      'shame',
      'relief',
      'pride',
      'excitement',
      'disappointment',
      'tiredness',
      'neutral',
      'other',
    }.contains(emotion)) {
      throw const FormatException('Invalid affect emotion.');
    }
    final valence = _number(json, 'valence');
    if (valence < -1 || valence > 1) {
      throw const FormatException('Invalid affect valence.');
    }
    return MemoryV3Affect(
      emotion: emotion,
      valence: valence,
      arousal: _score(json, 'arousal'),
      intensity: _score(json, 'intensity'),
      confidence: _score(json, 'confidence'),
      target: _nullableText(json, 'target', max: 160),
      cause: _nullableText(json, 'cause', max: 240),
    );
  }

  final String emotion;
  final double valence;
  final double arousal;
  final double intensity;
  final String? target;
  final String? cause;
  final double confidence;
}

class MemoryV3Utility {
  const MemoryV3Utility({
    required this.salience,
    required this.futureUtility,
    required this.proactiveAllowed,
    required this.confirmationRequired,
  });

  factory MemoryV3Utility.fromJson(Map<String, Object?> json) {
    _keys(
      json,
      required: const {
        'salience',
        'future_utility',
        'proactive_allowed',
        'confirmation_required',
      },
      optional: const {},
      label: 'utility',
    );
    return MemoryV3Utility(
      salience: _score(json, 'salience'),
      futureUtility: _score(json, 'future_utility'),
      proactiveAllowed: _boolean(json, 'proactive_allowed'),
      confirmationRequired: _boolean(json, 'confirmation_required'),
    );
  }

  final double salience;
  final double futureUtility;
  final bool proactiveAllowed;
  final bool confirmationRequired;
}

class MemoryV3Privacy {
  const MemoryV3Privacy({
    required this.sensitivity,
    required this.durableEligibility,
    this.reason,
  });

  factory MemoryV3Privacy.fromJson(Map<String, Object?> json) {
    _keys(
      json,
      required: const {'sensitivity', 'durable_eligibility'},
      optional: const {'reason'},
      label: 'privacy',
    );
    final sensitivity = _text(json, 'sensitivity', min: 1, max: 30);
    final eligibility = _text(json, 'durable_eligibility', min: 1, max: 30);
    if (!{'normal', 'restricted', 'forbidden'}.contains(sensitivity) ||
        !{
          'automatic',
          'explicit_only',
          'ephemeral',
          'never',
        }.contains(eligibility)) {
      throw const FormatException('Invalid memory privacy classification.');
    }
    return MemoryV3Privacy(
      sensitivity: sensitivity,
      durableEligibility: eligibility,
      reason: _nullableText(json, 'reason', max: 240),
    );
  }

  final String sensitivity;
  final String durableEligibility;
  final String? reason;
}

Map<String, Object?> _object(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object.');
  if (value.keys.any((key) => key is! String)) {
    throw FormatException('$label has a non-string key.');
  }
  return Map<String, Object?>.from(value);
}

void _keys(
  Map<String, Object?> json, {
  required Set<String> required,
  required Set<String> optional,
  required String label,
}) {
  if (!json.keys.toSet().containsAll(required) ||
      json.keys.any(
        (key) => !required.contains(key) && !optional.contains(key),
      )) {
    throw FormatException('$label has missing or unknown fields.');
  }
}

String _text(
  Map<String, Object?> json,
  String key, {
  required int min,
  required int max,
}) {
  final value = json[key];
  if (value is! String || value.length < min || value.length > max) {
    throw FormatException('$key is invalid.');
  }
  return value;
}

String? _optionalText(
  Map<String, Object?> json,
  String key, {
  required int max,
}) {
  if (!json.containsKey(key)) return null;
  return _text(json, key, min: 0, max: max);
}

String? _nullableText(
  Map<String, Object?> json,
  String key, {
  required int max,
}) {
  if (!json.containsKey(key) || json[key] == null) return null;
  return _text(json, key, min: 0, max: max);
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

int? _optionalInteger(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) return null;
  return _integer(json, key);
}

int? _nullableInteger(Map<String, Object?> json, String key) {
  if (!json.containsKey(key) || json[key] == null) return null;
  return _integer(json, key);
}

double _number(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('$key must be numeric.');
  return value.toDouble();
}

double _score(Map<String, Object?> json, String key) {
  final value = _number(json, key);
  if (value < 0 || value > 1) throw FormatException('$key must be a score.');
  return value;
}

bool _boolean(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be boolean.');
  return value;
}

List<Object?> _list(
  Map<String, Object?> json,
  String key, {
  int min = 0,
  required int max,
}) {
  final value = json[key];
  if (value is! List || value.length < min || value.length > max) {
    throw FormatException('$key must be a bounded list.');
  }
  return value.cast<Object?>();
}
