import 'dart:convert';

import 'package:companion_mobile/features/chat_history/data/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts conservative stable facts with provenance metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database.upsertUserMessageAndExtractMemory(
      _message(
        id: 'm1',
        turnId: 'turn_1',
        text: 'Namaste mera naam Rahul hai',
        confidence: 0.96,
      ),
    );

    final memories = await database.readMemoryContext(
      latestUserText: 'mera naam yaad hai?',
      limit: 4,
    );

    expect(memories, hasLength(1));
    expect(memories.single.kind, 'stable_fact');
    expect(memories.single.label, 'preferred_name');
    expect(memories.single.content, contains('Rahul'));
    expect(jsonDecode(memories.single.sourceTurnIdsJson), contains('turn_1'));
    expect(memories.single.sttConfidence, 0.96);
  });

  test('extracts stable facts from Devanagari Hindi transcripts', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database.upsertUserMessageAndExtractMemory(
      _message(
        id: 'm1',
        turnId: 'turn_1',
        text: 'मेरा नाम राहुल है मुझे इंग्लिश में बात करना पसंद है',
        confidence: 0.97,
      ),
    );

    final memories = await database.readMemoryContext(
      latestUserText: 'मेरा नाम क्या है?',
      limit: 6,
    );

    expect(memories.map((memory) => memory.label), contains('preferred_name'));
    expect(memories.map((memory) => memory.label), contains('language_style'));
    expect(memories.any((memory) => memory.content.contains('राहुल')), isTrue);
    expect(
      memories.any((memory) => memory.content.contains('English replies')),
      isTrue,
    );
  });

  test(
    'question-shaped recall turns do not overwrite preferred name memory',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'm1',
          turnId: 'turn_1',
          text: 'मेरा नाम राहुल है',
          confidence: 0.99,
        ),
      );
      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'm2',
          turnId: 'turn_2',
          text: 'मेरा नाम क्या है',
          confidence: 0.98,
        ),
      );

      final memories = await database.readMemoryContext(
        latestUserText: 'मेरा नाम क्या है?',
        limit: 6,
      );
      final preferredName = memories.firstWhere(
        (memory) => memory.label == 'preferred_name',
      );

      expect(preferredName.content, contains('राहुल'));
      expect(preferredName.content, isNot(contains('क्या')));
    },
  );

  test(
    'preferred name remains retrievable after unrelated later sessions',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'm1',
          turnId: 'turn_1',
          text: 'मेरा नाम राहुल है',
          confidence: 0.99,
        ),
      );
      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'm2',
          turnId: 'turn_2',
          text: 'आज मौसम अच्छा है',
          confidence: 0.95,
        ),
      );
      await database.upsertAssistantMessageAndSummarizeTurn(
        _message(
          id: 'a2',
          turnId: 'turn_2',
          role: 'assistant',
          text: 'हाँ, मौसम अच्छा लग रहा है।',
        ),
      );
      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'm3',
          turnId: 'turn_3',
          text: 'मुझे चाय पसंद है',
          confidence: 0.96,
        ),
      );
      await database.upsertAssistantMessageAndSummarizeTurn(
        _message(
          id: 'a3',
          turnId: 'turn_3',
          role: 'assistant',
          text: 'ठीक है, चाय याद रखूँगा।',
        ),
      );

      final memories = await database.readMemoryContext(
        latestUserText: 'मेरा नाम क्या है?',
        limit: 6,
      );

      expect(memories.first.label, 'preferred_name');
      expect(memories.first.content, contains('राहुल'));
    },
  );

  test('excludes low confidence and sensitive facts from memory', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database.upsertUserMessageAndExtractMemory(
      _message(
        id: 'm1',
        turnId: 'turn_1',
        text: 'mera naam Rahul hai',
        confidence: 0.2,
      ),
    );
    await database.upsertUserMessageAndExtractMemory(
      _message(
        id: 'm2',
        turnId: 'turn_2',
        text: 'main mar jaana chahta hoon aur mera naam Amit hai',
        confidence: 0.9,
      ),
    );

    final memories = await database.readMemoryContext(
      latestUserText: 'kya yaad hai?',
      limit: 4,
    );

    expect(memories, isEmpty);
  });

  test(
    'correction updates stable memory and recent context excludes noisy statuses',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'm1',
          turnId: 'turn_1',
          text: 'mera naam Rahul hai',
          confidence: 0.9,
        ),
      );
      await database.replaceMessageText(
        messageId: 'm1',
        text: 'mera naam Amit hai',
        createdAt: 2,
      );
      await database.upsertMessage(
        _message(
          id: 'm2',
          turnId: 'turn_2',
          text: 'low quality replaced text',
          status: 'final_replaced',
        ),
      );

      final memories = await database.readMemoryContext(
        latestUserText: 'mera naam kya hai?',
        limit: 4,
      );
      final recent = await database.readRecentTranscriptContext(limit: 10);

      expect(memories.single.content, contains('Amit'));
      expect(memories.single.content, isNot(contains('Rahul')));
      expect(recent.map((message) => message.id), isNot(contains('m2')));
      expect(recent.map((message) => message.id), contains('m1'));
    },
  );

  test(
    'complete turns create local summaries and clear history erases memory',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.upsertUserMessageAndExtractMemory(
        _message(id: 'u1', turnId: 'turn_1', text: 'aaj main walk pe gaya tha'),
      );
      await database.upsertAssistantMessageAndSummarizeTurn(
        _message(
          id: 'a1',
          turnId: 'turn_1',
          role: 'assistant',
          text: 'Achha, walk se halka feel hua?',
        ),
      );

      var memories = await database.readMemoryContext(
        latestUserText: 'walk ke baare mein yaad hai?',
        limit: 4,
      );
      expect(
        memories.any((memory) => memory.kind == 'session_summary'),
        isTrue,
      );

      await database.clearHistory();
      memories = await database.readMemoryContext(
        latestUserText: 'kya yaad hai?',
        limit: 4,
      );
      final messages = await database.readMessages();

      expect(memories, isEmpty);
      expect(messages, isEmpty);
    },
  );

  test('sensitive crisis turns do not create session summaries', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database.upsertUserMessageAndExtractMemory(
      _message(id: 'u1', turnId: 'turn_1', text: 'मैं मर जाना चाहता हूं'),
    );
    await database.upsertAssistantMessageAndSummarizeTurn(
      _message(
        id: 'a1',
        turnId: 'turn_1',
        role: 'assistant',
        text: 'कृपया तुरंत किसी trusted person से बात कीजिए।',
      ),
    );

    final memories = await database.readMemoryContext(
      latestUserText: 'कुछ याद है?',
      limit: 10,
    );

    expect(
      memories.where((memory) => memory.kind == 'session_summary'),
      isEmpty,
    );
  });

  test('session summaries are pruned to the latest bounded set', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    for (var i = 1; i <= 6; i += 1) {
      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u$i',
          turnId: 'turn_$i',
          text: 'session $i memory',
          confidence: 0.9,
          sessionId: 'session_$i',
          createdAt: i,
        ),
      );
      await database.upsertAssistantMessageAndSummarizeTurn(
        _message(
          id: 'a$i',
          turnId: 'turn_$i',
          role: 'assistant',
          text: 'assistant summary $i',
          sessionId: 'session_$i',
          createdAt: i + 100,
        ),
      );
    }

    final memories = await database.readMemoryContext(
      latestUserText: 'kuch yaad hai?',
      limit: 20,
    );
    final summaries = memories.where(
      (memory) => memory.kind == 'session_summary',
    );

    expect(summaries.length, lessThanOrEqualTo(4));
  });
}

ChatMessagesCompanion _message({
  required String id,
  required String turnId,
  required String text,
  String role = 'user',
  String status = 'final',
  double? confidence = 0.9,
  String sessionId = 'session_test',
  int createdAt = 1,
}) {
  return ChatMessagesCompanion.insert(
    id: id,
    sessionId: sessionId,
    turnId: turnId,
    role: role,
    messageText: text,
    status: status,
    language: 'hi-IN',
    createdAt: createdAt,
    sttConfidence: Value(confidence),
  );
}
