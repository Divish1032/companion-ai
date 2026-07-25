import 'package:flutter_test/flutter_test.dart';

import 'package:companion_mobile/features/chat_history/data/memory_v3_admission.dart';
import 'package:companion_mobile/features/chat_history/data/memory_v3_models.dart';

void main() {
  const source = MemoryV3AdmissionSource(
    id: 'message-1',
    turnId: 'turn-1',
    role: 'user',
    text: 'Mera naam Aditi hai.',
    status: 'final',
    createdAtMs: 10,
    sttConfidence: 0.96,
  );

  test('public admission validator admits an exact low-risk fact', () {
    final result = validateMemoryV3Candidate(_candidate(), const [source]);

    expect(result.disposition, 'admitted');
    expect(result.reason, 'explicit_grounded_low_risk');
    expect(result.evidence.single.startChar, 0);
    expect(result.epistemicConfidence, 0.95);
  });

  test('public admission validator applies STT and privacy policy', () {
    final lowStt = validateMemoryV3Candidate(_candidate(), const [
      MemoryV3AdmissionSource(
        id: 'message-1',
        turnId: 'turn-1',
        role: 'user',
        text: 'Mera naam Aditi hai.',
        status: 'final',
        createdAtMs: 10,
        sttConfidence: 0.61,
      ),
    ]);
    final secret = validateMemoryV3Candidate(
      _candidate(objectText: 'PIN', fragment: 'Mera PIN 1234 hai.'),
      const [
        MemoryV3AdmissionSource(
          id: 'message-1',
          turnId: 'turn-1',
          role: 'user',
          text: 'Mera PIN 1234 hai.',
          status: 'final',
          createdAtMs: 10,
          sttConfidence: 0.96,
        ),
      ],
    );

    expect(lowStt.disposition, 'deferred');
    expect(lowStt.reason, 'low_stt_confidence');
    expect(lowStt.temporalStatus, 'uncertain');
    expect(secret.disposition, 'rejected');
    expect(secret.reason, 'local_forbidden_content');
  });
}

MemoryV3Observation _candidate({
  String objectText = 'Aditi',
  String fragment = 'Mera naam Aditi hai.',
}) => MemoryV3Observation.fromJson({
  'schema_version': 3,
  'candidate_id': 'candidate_admission_123',
  'kind': 'profile',
  'subject': {'entity_type': 'user', 'mention': 'user'},
  'predicate': 'preferred_name',
  'object': {'text': objectText, 'normalized_value': objectText},
  'evidence': [
    {'turn_id': 'turn-1', 'role': 'user', 'fragment': fragment},
  ],
  'temporal': {'status': 'current', 'resolution_confidence': 0.9},
  'epistemic': {
    'explicitness': 'explicit',
    'confidence': 0.95,
    'negated': false,
    'hypothetical': false,
    'quoted': false,
  },
  'utility': {
    'salience': 0.9,
    'future_utility': 0.95,
    'proactive_allowed': false,
    'confirmation_required': false,
  },
  'privacy': {'sensitivity': 'normal', 'durable_eligibility': 'automatic'},
  'proposed_operation': 'ADD',
});
