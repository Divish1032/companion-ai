import 'package:companion_mobile/features/chat_history/data/companion_memory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deterministic Hindi companion-memory parser', () {
    test(
      'extracts exact name, language variants, relation, routine and policy',
      () {
        final name = analyzeMemoryTurn('मेरा नाम अमित है');
        final relation = analyzeMemoryTurn('मेरे भाई का नाम राहुल है');
        final observedSttRelation = analyzeMemoryTurn(
          'मैंने भाई का नाम रोहन है',
        );
        final language = analyzeMemoryTurn('मुझे हिन्दी में जवाब पसंद है');
        final routine = analyzeMemoryTurn('मैं रोज सुबह टहलता हूं');
        final policy = analyzeMemoryTurn(
          'मुझे सलाह देने से पहले बस सुनना पसंद है',
        );
        final boundary = analyzeMemoryTurn('मुझे राजनीति पर बात नहीं करनी है');
        final goal = analyzeMemoryTurn('मेरा लक्ष्य रोज पढ़ना है');

        expect(name.candidate?.stateKey, 'user.profile.preferred_name');
        expect(name.candidate?.value['text'], 'अमित');
        expect(relation.candidate?.stateKey, 'user.relationship.brother.राहुल');
        expect(
          observedSttRelation.candidate?.stateKey,
          'user.relationship.brother.रोहन',
        );
        expect(language.candidate?.value['text'], 'Hindi');
        expect(routine.candidate?.stateKey, 'user.routine.morning.walk');
        expect(policy.candidate?.stateKey, 'user.preference.comfort_style');
        expect(boundary.candidate?.stateKey, 'user.boundary.politics');
        expect(goal.candidate?.stateKey, 'user.goal.रोज_पढ़ना');
      },
    );

    test(
      'accepts a spoken name assertion when Vosk omits the final copula',
      () {
        final name = analyzeMemoryTurn('मेरा नाम राहुल');

        expect(name.action, MemoryActionKind.setState);
        expect(name.candidate?.value['text'], 'राहुल');
      },
    );

    test('routes supported recall questions to exact local state', () {
      expect(
        analyzeMemoryTurn('मेरा नाम क्या है?').stateKey,
        'user.profile.preferred_name',
      );
      expect(
        analyzeMemoryTurn('मेरे भाई का नाम क्या है?').stateKey,
        'user.relationship.brother.*',
      );
      expect(
        analyzeMemoryTurn('मैं रोज सुबह क्या करता हूं?').stateKey,
        'user.routine.morning.*',
      );
      expect(
        analyzeMemoryTurn('मुझे सलाह से पहले क्या पसंद है?').stateKey,
        'user.preference.comfort_style',
      );
      expect(
        analyzeMemoryTurn(
          'मैंने तुम्हें अपने भाई के बारे में क्या बताया था',
        ).stateKey,
        'user.relationship.brother.*',
      );
    });

    test(
      'treats observed Hindi ASR question variants as questions, not names',
      () {
        final profile = analyzeMemoryTurn('मेरा नाम के है');
        final relation = analyzeMemoryTurn('मेरे भाई का नाम के है');

        expect(profile.action, MemoryActionKind.answerState);
        expect(profile.stateKey, 'user.profile.preferred_name');
        expect(profile.candidate, isNull);
        expect(relation.action, MemoryActionKind.answerState);
        expect(relation.stateKey, 'user.relationship.brother.*');
        expect(relation.candidate, isNull);
      },
    );

    test(
      'fails closed for a language without a reviewed exact-memory policy',
      () {
        final analysis = analyzeMemoryTurn(
          'my name is Alex',
          language: 'fr-FR',
        );

        expect(analysis.action, MemoryActionKind.companion);
        expect(analysis.candidate, isNull);
      },
    );

    test('does not silently correct a semantically different ASR word', () {
      expect(
        analyzeMemoryTurn('मुझे सहारा देने से पहले बस सुनना पसंद है').candidate,
        isNull,
      );
    });

    test(
      'keeps sensitive content out of durable state and exposes quality',
      () {
        expect(
          analyzeMemoryTurn('मेरा नाम अमित है और मैं मर जाना चाहता हूं').action,
          MemoryActionKind.none,
        );
        expect(
          analyzeMemoryTurn('मेरी दवा खत्म हो गई और मेरा नाम अमित है').action,
          MemoryActionKind.none,
        );
        expect(
          transcriptQuality(status: 'final', confidence: null),
          TranscriptQuality.unknown,
        );
        expect(
          transcriptQuality(status: 'final', confidence: 0.54),
          TranscriptQuality.low,
        );
        expect(
          transcriptQuality(status: 'final', confidence: 0.80),
          TranscriptQuality.high,
        );
      },
    );

    test(
      'auto-commits explicit unknown-quality facts but guards risky writes',
      () {
        final name = analyzeMemoryTurn('मेरा नाम राहुल');
        final correction = analyzeMemoryTurn('असल में मेरा नाम अमित है');
        final boundary = analyzeMemoryTurn('मुझे राजनीति पर बात नहीं करनी है');

        expect(
          claimAdmission(
            candidate: name.candidate!,
            quality: TranscriptQuality.unknown,
          ),
          ClaimAdmission.commit,
        );
        expect(
          claimAdmission(
            candidate: correction.candidate!,
            quality: TranscriptQuality.unknown,
          ),
          ClaimAdmission.confirm,
        );
        expect(
          claimAdmission(
            candidate: boundary.candidate!,
            quality: TranscriptQuality.unknown,
          ),
          ClaimAdmission.confirm,
        );
        expect(
          claimAdmission(
            candidate: name.candidate!,
            quality: TranscriptQuality.low,
          ),
          ClaimAdmission.confirm,
        );
      },
    );
  });
}
