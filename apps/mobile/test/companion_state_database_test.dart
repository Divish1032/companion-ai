import 'package:companion_mobile/features/chat_history/data/app_database.dart';
import 'package:companion_mobile/features/chat_history/data/companion_memory_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Companion State ledger', () {
    test(
      'high-confidence correction supersedes the exact current name',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);

        await database.resolveMemoryTurn(
          turnId: 't1',
          text: 'मेरा नाम राहुल है',
          transcriptStatus: 'final',
          sttConfidence: 0.92,
        );
        await database.resolveMemoryTurn(
          turnId: 't2',
          text: 'असल में मेरा नाम अमित है',
          transcriptStatus: 'final',
          sttConfidence: 0.93,
        );
        final answer = await database.resolveMemoryTurn(
          turnId: 't3',
          text: 'मेरा नाम क्या है?',
          transcriptStatus: 'final',
          sttConfidence: 0.95,
        );
        final claims = await database
            .customSelect('SELECT claim_state FROM memory_claims')
            .get();

        expect(answer.directive, 'fact_answer');
        expect((answer.stateFacts.single['value'] as Map)['text'], 'अमित');
        expect(
          claims.where((claim) => claim.data['claim_state'] == 'current'),
          hasLength(1),
        );
        expect(
          claims.where((claim) => claim.data['claim_state'] == 'superseded'),
          hasLength(1),
        );
      },
    );

    test(
      'unknown confidence creates a candidate that confirmation activates',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);

        final pending = await database.resolveMemoryTurn(
          turnId: 't1',
          text: 'मेरा नाम राहुल है',
          transcriptStatus: 'final',
          sttConfidence: null,
        );
        final confirmed = await database.resolveMemoryTurn(
          turnId: 't2',
          text: 'हाँ',
          transcriptStatus: 'final',
          sttConfidence: 0.9,
        );

        expect(pending.directive, 'confirmation');
        expect(
          pending.pendingCandidate?['state_key'],
          'user.profile.preferred_name',
        );
        expect(confirmed.directive, 'setting_ack');
        expect((confirmed.stateFacts.single['value'] as Map)['text'], 'राहुल');
      },
    );

    test(
      'a repeated uncertain relationship becomes current and rejected candidates do not',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);

        final first = await database.resolveMemoryTurn(
          turnId: 't1',
          text: 'मेरे भाई का नाम अमित है',
          transcriptStatus: 'final',
          sttConfidence: null,
        );
        final second = await database.resolveMemoryTurn(
          turnId: 't2',
          text: 'मेरे भाई का नाम अमित है',
          transcriptStatus: 'final',
          sttConfidence: null,
        );
        final pendingName = await database.resolveMemoryTurn(
          turnId: 't3',
          text: 'मेरा नाम राहुल है',
          transcriptStatus: 'final',
          sttConfidence: null,
        );
        await database.resolveMemoryTurn(
          turnId: 't4',
          text: 'नहीं याद रखना',
          transcriptStatus: 'final',
          sttConfidence: 0.9,
        );
        final name = await database.resolveMemoryTurn(
          turnId: 't5',
          text: 'मेरा नाम क्या है?',
          transcriptStatus: 'final',
          sttConfidence: 0.9,
        );

        expect(first.directive, 'confirmation');
        expect(second.directive, 'setting_ack');
        expect(pendingName.directive, 'confirmation');
        expect(name.directive, 'fact_unknown');
      },
    );

    test('clear history erases claims and current-state projections', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.resolveMemoryTurn(
        turnId: 't1',
        text: 'मेरा नाम राहुल है',
        transcriptStatus: 'final',
        sttConfidence: 0.9,
      );

      await database.clearAllHistoryAndCompanionMemory();

      expect(
        await database.customSelect('SELECT * FROM memory_claims').get(),
        isEmpty,
      );
      expect(
        await database.customSelect('SELECT * FROM companion_state').get(),
        isEmpty,
      );
      expect(
        await database
            .customSelect('SELECT * FROM memory_entity_aliases')
            .get(),
        isEmpty,
      );
    });

    test(
      'migrates only parseable legacy profile facts into the ledger',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        await database.upsertUserMessageAndExtractMemory(
          ChatMessagesCompanion.insert(
            id: 'legacy_user',
            sessionId: 's1',
            turnId: 'legacy_turn',
            role: 'user',
            messageText: 'mera naam Rahul hai',
            status: 'final',
            language: 'hi-IN',
            createdAt: 1,
            sttConfidence: const Value(0.95),
          ),
        );

        final answer = await database.resolveMemoryTurn(
          turnId: 'query_turn',
          text: 'मेरा नाम क्या है?',
          transcriptStatus: 'final',
          sttConfidence: 0.9,
        );
        final claims = await database
            .customSelect(
              'SELECT extraction_version FROM memory_claims WHERE claim_state = ?',
            variables: [Variable.withString('current')],
            )
            .get();

        expect(answer.directive, 'fact_answer');
        expect((answer.stateFacts.single['value'] as Map)['text'], 'Rahul');
        expect(claims.single.data['extraction_version'], 'legacy_migration_v1');
      },
    );

    test(
      'keeps ASR provenance and a typed person alias with a current claim',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        await database.resolveMemoryTurn(
          turnId: 't1',
          text: 'मेरा नाम राहुल है',
          transcriptStatus: 'final',
          sttConfidence: 0.91,
          sttProvider: 'vosk',
          sttModel: 'hi-model',
        );

        final claim =
            (await database.customSelect('SELECT * FROM memory_claims').get())
                .single;
        final alias =
            (await database
                    .customSelect('SELECT * FROM memory_entity_aliases')
                    .get())
                .single;

        expect(claim.data['stt_confidence'], 0.91);
        expect(claim.data['provider_metadata_json'], contains('vosk'));
        expect(alias.data['alias'], 'राहुल');
        expect(alias.data['alias_type'], 'exact_transcript');
      },
    );
  });
}
