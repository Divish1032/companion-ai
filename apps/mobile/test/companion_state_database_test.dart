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

        await _resolve(
          database,
          turnId: 't1',
          text: 'मेरा नाम राहुल है',
          transcriptStatus: 'final',
          sttConfidence: 0.92,
        );
        await _resolve(
          database,
          turnId: 't2',
          text: 'असल में मेरा नाम अमित है',
          transcriptStatus: 'final',
          sttConfidence: 0.93,
        );
        final answer = await _resolve(
          database,
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
      'chained corrections Rahul -> Vinay -> Amit leave only Amit current',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);

        await _resolve(
          database,
          turnId: 't1',
          text: 'मेरा नाम राहुल है',
          transcriptStatus: 'final',
          sttConfidence: 0.94,
        );
        await _resolve(
          database,
          turnId: 't2',
          text: 'असल में मेरा नाम विनय है',
          transcriptStatus: 'final',
          sttConfidence: 0.93,
        );
        await _resolve(
          database,
          turnId: 't3',
          text: 'नहीं मेरा नाम अमित है',
          transcriptStatus: 'final',
          sttConfidence: 0.95,
        );
        final answer = await _resolve(
          database,
          turnId: 't4',
          text: 'मेरा नाम क्या है?',
          transcriptStatus: 'final',
          sttConfidence: 0.95,
        );
        final claims = await database
            .customSelect(
              'SELECT claim_state, value_json FROM memory_claims '
              "WHERE state_key = 'user.profile.preferred_name'",
            )
            .get();
        final current = claims
            .where((claim) => claim.data['claim_state'] == 'current')
            .toList();

        expect(answer.directive, 'fact_answer');
        expect((answer.stateFacts.single['value'] as Map)['text'], 'अमित');
        expect(current, hasLength(1));
        expect(current.single.data['value_json'], contains('अमित'));
        expect(
          claims.where((claim) => claim.data['claim_state'] == 'superseded'),
          hasLength(2),
        );
      },
    );

    test(
      'unknown confidence silently commits an exact low-risk assertion',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);

        final committed = await _resolve(
          database,
          turnId: 't1',
          text: 'मेरा नाम राहुल है',
          transcriptStatus: 'final',
          sttConfidence: null,
        );
        final unrelatedYes = await _resolve(
          database,
          turnId: 't2',
          text: 'हाँ',
          transcriptStatus: 'final',
          sttConfidence: 0.9,
        );

        expect(committed.directive, 'setting_ack');
        expect((committed.stateFacts.single['value'] as Map)['text'], 'राहुल');
        expect(unrelatedYes.directive, 'companion');
      },
    );

    test(
      'unknown-confidence profile replacement is deferred without a prompt',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);

        await _resolve(
          database,
          turnId: 't1',
          text: 'मेरा नाम अमित है',
          transcriptStatus: 'final',
          sttConfidence: null,
        );
        final replacement = await _resolve(
          database,
          turnId: 't2',
          text: 'मेरा नाम विनय है',
          transcriptStatus: 'final',
          sttConfidence: null,
        );
        final answer = await _resolve(
          database,
          turnId: 't3',
          text: 'मेरा नाम क्या है?',
          transcriptStatus: 'final',
          sttConfidence: null,
        );

        expect(replacement.directive, 'companion');
        expect(answer.directive, 'fact_answer');
        expect((answer.stateFacts.single['value'] as Map)['text'], 'अमित');
      },
    );

    test('uncertain claims never create a confirmation exchange', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final first = await _resolve(
        database,
        turnId: 't1',
        text: 'मेरे भाई का नाम अमित है',
        transcriptStatus: 'final',
        sttConfidence: 0.5,
      );
      final second = await _resolve(
        database,
        turnId: 't2',
        text: 'मेरे भाई का नाम अमित है',
        transcriptStatus: 'final',
        sttConfidence: 0.5,
      );
      final originalName = await _resolve(
        database,
        turnId: 't3',
        text: 'मेरा नाम राहुल है',
        transcriptStatus: 'final',
        sttConfidence: null,
      );
      final pendingCorrection = await _resolve(
        database,
        turnId: 't4',
        text: 'असल में मेरा नाम अमित है',
        transcriptStatus: 'final',
        sttConfidence: null,
      );
      await _resolve(
        database,
        turnId: 't5',
        text: 'नहीं याद रखना',
        transcriptStatus: 'final',
        sttConfidence: 0.9,
      );
      final name = await _resolve(
        database,
        turnId: 't6',
        text: 'मेरा नाम क्या है?',
        transcriptStatus: 'final',
        sttConfidence: 0.9,
      );

      expect(first.directive, 'companion');
      expect(second.directive, 'companion');
      expect(second.stateFacts, isEmpty);
      expect(originalName.directive, 'setting_ack');
      expect(pendingCorrection.directive, 'companion');
      expect(name.directive, 'fact_answer');
      expect((name.stateFacts.single['value'] as Map)['text'], 'राहुल');
    });

    test(
      'bare acknowledgements never commit an uncertain exact claim',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);

        final pending = await _resolve(
          database,
          turnId: 't1',
          text: 'मेरा नाम राहुल',
          transcriptStatus: 'final',
          sttConfidence: 0.5,
        );
        final unrelated = await _resolve(
          database,
          turnId: 't2',
          text: 'आज मेरा मन उदास है',
          transcriptStatus: 'final',
          sttConfidence: 0.9,
        );
        final lateYes = await _resolve(
          database,
          turnId: 't3',
          text: 'हाँ',
          transcriptStatus: 'final',
          sttConfidence: 0.9,
        );
        final answer = await _resolve(
          database,
          turnId: 't4',
          text: 'मेरा नाम क्या है?',
          transcriptStatus: 'final',
          sttConfidence: 0.9,
        );
        final claims = await database
            .customSelect(
              'SELECT claim_state, confirmation_state FROM memory_claims',
            )
            .get();

        expect(pending.directive, 'companion');
        expect(unrelated.directive, 'companion');
        expect(lateYes.directive, 'companion');
        expect(answer.directive, 'fact_unknown');
        expect(claims, isEmpty);
      },
    );

    test('clear history erases claims and current-state projections', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await _resolve(
        database,
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

        final answer = await _resolve(
          database,
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
        await _resolve(
          database,
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

Future<MemoryTurnResolution> _resolve(
  AppDatabase database, {
  required String turnId,
  required String text,
  required String transcriptStatus,
  required double? sttConfidence,
  String? sttProvider,
  String? sttModel,
}) async {
  await database
      .into(database.chatSessions)
      .insertOnConflictUpdate(
        ChatSessionsCompanion.insert(
          id: 'test_session',
          startedAt: 0,
          language: 'hi-IN',
        ),
      );
  await database
      .into(database.chatMessages)
      .insert(
        ChatMessagesCompanion.insert(
          id: 'message_$turnId',
          sessionId: 'test_session',
          turnId: turnId,
          role: 'user',
          messageText: text,
          status: transcriptStatus,
          language: 'hi-IN',
          createdAt: _turnOrder(turnId),
          sttConfidence: Value(sttConfidence),
        ),
      );
  return database.resolveMemoryTurn(
    turnId: turnId,
    text: text,
    language: 'hi-IN',
    transcriptStatus: transcriptStatus,
    sttConfidence: sttConfidence,
    sttProvider: sttProvider,
    sttModel: sttModel,
  );
}

int _turnOrder(String turnId) {
  final numeric = int.tryParse(
    RegExp(r'\d+').firstMatch(turnId)?.group(0) ?? '',
  );
  return numeric ?? 1000000;
}
