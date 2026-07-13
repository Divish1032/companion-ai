import 'dart:convert';

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
  MemoryTurnAnalysis analyze(String text);
}

class DeterministicMemoryExtractor implements MemoryExtractor {
  const DeterministicMemoryExtractor();

  @override
  MemoryTurnAnalysis analyze(String text) => analyzeMemoryTurn(text);
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

MemoryTurnAnalysis analyzeMemoryTurn(String text) {
  final normalized = _normalize(text);
  if (normalized.isEmpty || _sensitive(normalized)) {
    return const MemoryTurnAnalysis(action: MemoryActionKind.none);
  }
  if (_isRejection(normalized)) {
    return const MemoryTurnAnalysis(action: MemoryActionKind.rejectCandidate);
  }
  if (_isConfirmation(normalized)) {
    return const MemoryTurnAnalysis(action: MemoryActionKind.confirmCandidate);
  }
  if (_isGreeting(normalized)) {
    return const MemoryTurnAnalysis(action: MemoryActionKind.none);
  }

  final query = _queryAction(normalized);
  if (query != null) return query;

  final candidate = _claimCandidate(normalized);
  if (candidate != null) {
    return MemoryTurnAnalysis(
      action: MemoryActionKind.setState,
      stateKey: candidate.stateKey,
      candidate: candidate,
    );
  }

  if (_containsAny(normalized, const [
    'office',
    'काम',
    'ऑफिस',
    'work',
    'manager',
  ])) {
    return const MemoryTurnAnalysis(
      action: MemoryActionKind.retrieveSemantic,
      queryScope: 'work',
    );
  }
  return const MemoryTurnAnalysis(action: MemoryActionKind.companion);
}

MemoryTurnAnalysis? _queryAction(String text) {
  if (_isQuestion(text) && _containsAny(text, const ['नाम', 'naam', 'name'])) {
    if (_containsAny(text, const ['भाई', 'बहन', 'brother', 'sister'])) {
      final role = _containsAny(text, const ['बहन', 'sister'])
          ? 'sister'
          : 'brother';
      return MemoryTurnAnalysis(
        action: MemoryActionKind.answerState,
        stateKey: 'user.relationship.$role.*',
      );
    }
    return const MemoryTurnAnalysis(
      action: MemoryActionKind.answerState,
      stateKey: 'user.profile.preferred_name',
    );
  }
  if (_isQuestion(text) &&
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
  if (_isQuestion(text) &&
      _containsAny(text, const ['सलाह', 'advice', 'सुनना', 'सुनो'])) {
    return const MemoryTurnAnalysis(
      action: MemoryActionKind.answerState,
      stateKey: 'user.preference.comfort_style',
    );
  }
  if (_isQuestion(text) &&
      _containsAny(text, const ['रोज', 'हर दिन', 'सुबह', 'daily', 'morning'])) {
    return const MemoryTurnAnalysis(
      action: MemoryActionKind.answerState,
      stateKey: 'user.routine.morning.*',
    );
  }
  if (_isQuestion(text) && _containsAny(text, const ['छोटा', 'short'])) {
    return const MemoryTurnAnalysis(
      action: MemoryActionKind.answerState,
      stateKey: 'user.preference.response_length',
    );
  }
  if (_isQuestion(text) && _containsAny(text, const ['राजनीति', 'boundary'])) {
    return const MemoryTurnAnalysis(
      action: MemoryActionKind.answerState,
      stateKey: 'user.boundary.*',
    );
  }
  if (_isQuestion(text) && _containsAny(text, const ['लक्ष्य', 'goal'])) {
    return const MemoryTurnAnalysis(
      action: MemoryActionKind.answerState,
      stateKey: 'user.goal.*',
    );
  }
  return null;
}

CompanionClaimCandidate? _claimCandidate(String text) {
  final name = _capture(text, [
    RegExp(
      r'(?:मेरा|meri|mera|my) नाम\s+([a-z\u0900-\u097f]{2,32})(?:\s+(?:है|hai))?',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:my name is)\s+([a-z\u0900-\u097f]{2,32})',
      caseSensitive: false,
    ),
  ]);
  if (name != null) {
    return CompanionClaimCandidate(
      stateKey: 'user.profile.preferred_name',
      subject: 'user',
      predicate: 'preferred_name',
      value: {'text': name, 'entity_type': 'person'},
      cardinality: ClaimCardinality.single,
      category: 'profile',
      assertionKind: _looksLikeCorrection(text) ? 'correction' : 'assertion',
    );
  }

  final relation = _capture(text, [
    RegExp(
      r'(?:मेरा|मेरी|मेरे)\s+(भाई|बहन)\s+का\s+नाम\s+([a-z\u0900-\u097f]{2,32})(?:\s+है)?',
      caseSensitive: false,
    ),
    RegExp(
      r'my\s+(brother|sister)\s+(?:name is|is)\s+([a-z\u0900-\u097f]{2,32})',
      caseSensitive: false,
    ),
  ], group: 2);
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

  final language = _language(text);
  if (language != null &&
      (_containsAny(text, const ['पसंद', 'prefer', 'केवल', 'सिर्फ', 'only']) ||
          _containsAny(text, const ['जवाब', 'उत्तर', 'reply', 'answer']))) {
    return CompanionClaimCandidate(
      stateKey: 'user.preference.response_language',
      subject: 'user',
      predicate: 'response_language',
      value: {'text': language},
      cardinality: ClaimCardinality.single,
      category: 'preference',
      assertionKind: _looksLikeCorrection(text) ? 'correction' : 'assertion',
    );
  }

  if (_containsAny(text, const [
    'छोटे जवाब',
    'छोटा जवाब',
    'short replies',
    'short reply',
  ])) {
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

  if (_containsAny(text, const [
    'सलाह देने से पहले',
    'advice se pehle',
    'listen first',
  ])) {
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

  if (_containsAny(text, const [
    'रोज सुबह टहल',
    'हर सुबह टहल',
    'daily morning walk',
  ])) {
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

  if (_containsAny(text, const [
    'राजनीति पर बात नहीं',
    'politics par baat nahi',
  ])) {
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

  final goal = _capture(text, [
    RegExp(r'(?:मेरा|मेरी) लक्ष्य\s+(.{2,80}?)\s+(?:है|हैं)'),
  ]);
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

String? _capture(String text, List<RegExp> patterns, {int group = 1}) {
  for (final pattern in patterns) {
    final value = pattern.firstMatch(text)?.group(group)?.trim();
    if (value != null && value.isNotEmpty && !_isQuestion(value)) return value;
  }
  return null;
}

String? _language(String text) {
  if (_containsAny(text, const ['हिंदी', 'हिन्दी', 'hindi'])) return 'Hindi';
  if (_containsAny(text, const ['इंग्लिश', 'english'])) return 'English';
  if (text.contains('hinglish')) return 'Hinglish';
  return null;
}

bool _isQuestion(String text) => _containsAny(text, const [
  '?',
  'क्या',
  'कौन',
  'कैसे',
  'किस',
  'kya',
  'kaun',
  'kaise',
  'kis',
  'yaad hai',
  'remember',
]);

bool _isConfirmation(String text) => _containsAny(text, const [
  'हाँ',
  'हां',
  'haan',
  'ha',
  'yes',
  'याद रखना',
  'yaad rakh',
  'confirm',
]);

bool _isRejection(String text) => _containsAny(text, const [
  'नहीं याद',
  'मत याद',
  'nahin',
  'nahi',
  'no',
  'reject',
]);

bool _isGreeting(String text) =>
    const {'नमस्ते', 'hi', 'hello', 'hey', 'haan', 'हाँ'}.contains(text);

bool _looksLikeCorrection(String text) => _containsAny(text, const [
  'असल में',
  'नहीं',
  'गलत',
  'actually',
  'nahi',
  'nahin',
  'correction',
  'instead',
]);

bool _sensitive(String text) => _containsAny(text, const [
  'आत्महत्या',
  'मर जाना',
  'खुद को मार',
  'suicide',
  'medical',
  'medical advice',
  'medicine',
  'दवा',
  'डॉक्टर',
  'doctor',
  'कानूनी',
  'legal',
  'वकील',
  'lawyer',
  'loan',
  'investment',
  'financial',
  'sexual',
  'नशा',
  'addiction',
  'drugs',
  'सिर्फ तुम',
  'तुम्हारे बिना',
]);

bool _containsAny(String text, Iterable<String> values) =>
    values.any(text.contains);

String _normalize(String value) => value
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase()
    .replaceAll('हिन्दी', 'हिंदी');

String _keyToken(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z\u0900-\u097f]+'), '_')
    .replaceAll(RegExp(r'_+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');
