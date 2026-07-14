import 'dart:convert';

import 'memory_language_policy.dart';

/// Deterministic, phone-owned understanding for the small set of facts that
/// must be exact in a companion conversation. This is deliberately separate
/// from semantic/vector retrieval: a name or response preference is state,
/// not a fuzzy document.
enum TranscriptQuality { high, unknown, low }

enum MemoryActionKind {
  none,
  answerState,
  setState,
  confirmCandidate,
  rejectCandidate,
  retrieveSemantic,
  companion,
}

enum ClaimCardinality { single, multi }

/// The admission decision is made on-device from bounded evidence. A future
/// model may nominate semantic/episodic candidates, but it must not decide a
/// profile-state write or bypass this policy.
enum ClaimAdmission { commit, confirm }

/// A future local NER model may implement this interface. Its output must still
/// enter the candidate/confirmation path; only deterministic extraction can
/// update current state directly in this release.
abstract interface class MemoryExtractor {
  MemoryTurnAnalysis analyze(String text, {String language});
}

class DeterministicMemoryExtractor implements MemoryExtractor {
  const DeterministicMemoryExtractor();

  @override
  MemoryTurnAnalysis analyze(String text, {String language = 'hi-IN'}) =>
      analyzeMemoryTurn(text, language: language);
}

class CompanionClaimCandidate {
  const CompanionClaimCandidate({
    required this.stateKey,
    required this.subject,
    required this.predicate,
    required this.value,
    required this.cardinality,
    required this.category,
    required this.assertionKind,
  });

  final String stateKey;
  final String subject;
  final String predicate;
  final Map<String, Object?> value;
  final ClaimCardinality cardinality;
  final String category;
  final String assertionKind;

  String get valueJson => jsonEncode(value);
}

class MemoryTurnAnalysis {
  const MemoryTurnAnalysis({
    required this.action,
    this.stateKey,
    this.candidate,
    this.queryScope,
  });

  final MemoryActionKind action;
  final String? stateKey;
  final CompanionClaimCandidate? candidate;
  final String? queryScope;
}

TranscriptQuality transcriptQuality({
  required String status,
  required double? confidence,
}) {
  if (status.contains('low_confidence') ||
      status.contains('repeat') ||
      (confidence != null && confidence < 0.55)) {
    return TranscriptQuality.low;
  }
  if (confidence == null) return TranscriptQuality.unknown;
  return confidence >= 0.75
      ? TranscriptQuality.high
      : TranscriptQuality.unknown;
}

ClaimAdmission claimAdmission({
  required CompanionClaimCandidate candidate,
  required TranscriptQuality quality,
}) {
  // A repeat-requested or explicitly low-quality transcript is never enough
  // to alter durable state by itself.
  if (quality == TranscriptQuality.low) return ClaimAdmission.confirm;

  // Vosk often has no reliable final confidence. For an exact, explicit
  // grammar match, treating that as a question on every turn makes the
  // companion feel like a form. Corrections and boundaries remain guarded:
  // a mistaken replacement is more harmful than a missed convenience fact.
  if (quality == TranscriptQuality.unknown &&
      (candidate.assertionKind == 'correction' ||
          candidate.category == 'boundary')) {
    return ClaimAdmission.confirm;
  }
  return ClaimAdmission.commit;
}

MemoryTurnAnalysis analyzeMemoryTurn(String text, {String language = 'hi-IN'}) {
  final policy = MemoryLanguagePolicyRegistry.forLanguage(language);
  final normalized = policy.normalize(text);
  if (normalized.isEmpty ||
      policy.containsAny(normalized, policy.sensitiveMarkers)) {
    return const MemoryTurnAnalysis(action: MemoryActionKind.none);
  }
  if (policy.containsAny(normalized, policy.rejectionMarkers)) {
    return const MemoryTurnAnalysis(action: MemoryActionKind.rejectCandidate);
  }
  if (policy.containsAny(normalized, policy.confirmationMarkers)) {
    return const MemoryTurnAnalysis(action: MemoryActionKind.confirmCandidate);
  }
  if (policy.greetings.contains(normalized)) {
    return const MemoryTurnAnalysis(action: MemoryActionKind.none);
  }

  final query = _queryAction(normalized, policy);
  if (query != null) return query;

  final candidate = policy.supportsDurableExactClaims
      ? _claimCandidate(normalized, policy)
      : null;
  if (candidate != null) {
    return MemoryTurnAnalysis(
      action: MemoryActionKind.setState,
      stateKey: candidate.stateKey,
      candidate: candidate,
    );
  }

  if (policy.containsAny(normalized, policy.workMarkers)) {
    return const MemoryTurnAnalysis(
      action: MemoryActionKind.retrieveSemantic,
      queryScope: 'work',
    );
  }
  return const MemoryTurnAnalysis(action: MemoryActionKind.companion);
}

MemoryTurnAnalysis? _queryAction(String text, MemoryLanguagePolicy policy) {
  if (policy.isQuestion(text) &&
      policy.containsAny(text, policy.relationshipMarkers)) {
    final role = _containsAny(text, const ['बहन', 'sister'])
        ? 'sister'
        : 'brother';
    return MemoryTurnAnalysis(
      action: MemoryActionKind.answerState,
      stateKey: 'user.relationship.$role.*',
    );
  }
  if (policy.isQuestion(text) &&
      _containsAny(text, const ['नाम', 'naam', 'name'])) {
    return const MemoryTurnAnalysis(
      action: MemoryActionKind.answerState,
      stateKey: 'user.profile.preferred_name',
    );
  }
  if (policy.isQuestion(text) &&
      _containsAny(text, const [
        'भाषा',
        'language',
        'हिंदी',
        'हिन्दी',
        'इंग्लिश',
      ])) {
    return const MemoryTurnAnalysis(
      action: MemoryActionKind.answerState,
      stateKey: 'user.preference.response_language',
    );
  }
  if (policy.isQuestion(text) &&
      _containsAny(text, const ['सलाह', 'advice', 'सुनना', 'सुनो'])) {
    return const MemoryTurnAnalysis(
      action: MemoryActionKind.answerState,
      stateKey: 'user.preference.comfort_style',
    );
  }
  if (policy.isQuestion(text) &&
      _containsAny(text, const ['रोज', 'हर दिन', 'सुबह', 'daily', 'morning'])) {
    return const MemoryTurnAnalysis(
      action: MemoryActionKind.answerState,
      stateKey: 'user.routine.morning.*',
    );
  }
  if (policy.isQuestion(text) && _containsAny(text, const ['छोटा', 'short'])) {
    return const MemoryTurnAnalysis(
      action: MemoryActionKind.answerState,
      stateKey: 'user.preference.response_length',
    );
  }
  if (policy.isQuestion(text) &&
      _containsAny(text, const ['राजनीति', 'boundary'])) {
    return const MemoryTurnAnalysis(
      action: MemoryActionKind.answerState,
      stateKey: 'user.boundary.*',
    );
  }
  if (policy.isQuestion(text) && _containsAny(text, const ['लक्ष्य', 'goal'])) {
    return const MemoryTurnAnalysis(
      action: MemoryActionKind.answerState,
      stateKey: 'user.goal.*',
    );
  }
  return null;
}

CompanionClaimCandidate? _claimCandidate(
  String text,
  MemoryLanguagePolicy policy,
) {
  final name = _capture(text, policy.namePatterns, policy: policy);
  if (name != null) {
    return CompanionClaimCandidate(
      stateKey: 'user.profile.preferred_name',
      subject: 'user',
      predicate: 'preferred_name',
      value: {'text': name, 'entity_type': 'person'},
      cardinality: ClaimCardinality.single,
      category: 'profile',
      assertionKind: policy.containsAny(text, policy.correctionMarkers)
          ? 'correction'
          : 'assertion',
    );
  }

  final relation = _capture(
    text,
    policy.relationshipPatterns,
    policy: policy,
    group: 2,
  );
  if (relation != null) {
    final role = _containsAny(text, const ['बहन', 'sister'])
        ? 'sister'
        : 'brother';
    return CompanionClaimCandidate(
      stateKey: 'user.relationship.$role.${_keyToken(relation)}',
      subject: 'user',
      predicate: 'has_$role',
      value: {'text': relation, 'entity_type': 'person', 'role': role},
      cardinality: ClaimCardinality.multi,
      category: 'relationship',
      assertionKind: 'assertion',
    );
  }

  final language = _language(text, policy);
  if (language != null && policy.containsAny(text, policy.preferenceMarkers)) {
    return CompanionClaimCandidate(
      stateKey: 'user.preference.response_language',
      subject: 'user',
      predicate: 'response_language',
      value: {'text': language},
      cardinality: ClaimCardinality.single,
      category: 'preference',
      assertionKind: policy.containsAny(text, policy.correctionMarkers)
          ? 'correction'
          : 'assertion',
    );
  }

  if (policy.containsAny(text, policy.shortResponseMarkers)) {
    return const CompanionClaimCandidate(
      stateKey: 'user.preference.response_length',
      subject: 'user',
      predicate: 'response_length',
      value: {'text': 'short'},
      cardinality: ClaimCardinality.single,
      category: 'preference',
      assertionKind: 'assertion',
    );
  }

  if (policy.containsAny(text, policy.comfortStyleMarkers)) {
    return const CompanionClaimCandidate(
      stateKey: 'user.preference.comfort_style',
      subject: 'user',
      predicate: 'comfort_style',
      value: {'text': 'listen_first'},
      cardinality: ClaimCardinality.single,
      category: 'conversation_policy',
      assertionKind: 'assertion',
    );
  }

  if (policy.containsAny(text, policy.morningWalkMarkers)) {
    return const CompanionClaimCandidate(
      stateKey: 'user.routine.morning.walk',
      subject: 'user',
      predicate: 'routine',
      value: {'text': 'walk', 'time': 'morning'},
      cardinality: ClaimCardinality.multi,
      category: 'routine',
      assertionKind: 'assertion',
    );
  }

  if (policy.containsAny(text, policy.politicsBoundaryMarkers)) {
    return const CompanionClaimCandidate(
      stateKey: 'user.boundary.politics',
      subject: 'user',
      predicate: 'boundary',
      value: {'text': 'politics'},
      cardinality: ClaimCardinality.multi,
      category: 'boundary',
      assertionKind: 'negation',
    );
  }

  final goal = _capture(text, policy.goalPatterns, policy: policy);
  if (goal != null) {
    return CompanionClaimCandidate(
      stateKey: 'user.goal.${_keyToken(goal)}',
      subject: 'user',
      predicate: 'goal',
      value: {'text': goal},
      cardinality: ClaimCardinality.multi,
      category: 'goal',
      assertionKind: 'assertion',
    );
  }
  return null;
}

String? _capture(
  String text,
  List<RegExp> patterns, {
  required MemoryLanguagePolicy policy,
  int group = 1,
}) {
  for (final pattern in patterns) {
    final value = pattern.firstMatch(text)?.group(group)?.trim();
    if (value != null && policy.isValidPersonValue(value)) return value;
  }
  return null;
}

String? _language(String text, MemoryLanguagePolicy policy) {
  for (final entry in policy.languageValues.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  return null;
}

bool _containsAny(String text, Iterable<String> values) =>
    values.any(text.contains);

String _keyToken(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z\u0900-\u097f]+'), '_')
    .replaceAll(RegExp(r'_+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');
