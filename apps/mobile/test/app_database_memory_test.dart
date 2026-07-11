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
    expect(memories.single.kind, 'core_profile');
    expect(memories.single.label, 'preferred_name');
    expect(memories.single.content, contains('Rahul'));
    expect(memories.single.canonicalText, contains('rahul'));
    expect(memories.single.temporalStatus, 'current');
    expect(memories.single.receiptState, 'implicit');
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

    final nameMemories = await database.readMemoryContext(
      latestUserText: 'मेरा नाम क्या है?',
      limit: 6,
    );
    final languageMemories = await database.readMemoryContext(
      latestUserText: 'मुझे किस language में reply पसंद है?',
      limit: 6,
    );

    expect(
      nameMemories.map((memory) => memory.label),
      contains('preferred_name'),
    );
    expect(
      languageMemories.map((memory) => memory.label),
      contains('language_style'),
    );
    expect(
      nameMemories.any((memory) => memory.content.contains('राहुल')),
      isTrue,
    );
    expect(
      languageMemories.any(
        (memory) => memory.content.contains('English replies'),
      ),
      isTrue,
    );
  });

  test('general turns do not inject unrelated profile memory', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.upsertUserMessageAndExtractMemory(
      _message(
        id: 'profile',
        turnId: 'turn_profile',
        text: 'mera naam Rahul hai',
        confidence: 0.99,
      ),
    );

    final memories = await database.readMemoryContext(
      latestUserText: 'aaj mood thoda off hai',
      limit: 4,
    );

    expect(
      memories.where((memory) => memory.label == 'preferred_name'),
      isEmpty,
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

  test(
    'graph-expanded recall connects vague office day to manager stress',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u1',
          turnId: 'turn_1',
          text: 'office mein manager bahut pressure deta hai',
          confidence: 0.96,
        ),
      );

      final memories = await database.readMemoryContext(
        latestUserText: 'aaj office se aaya, bad day tha',
        limit: 6,
      );

      expect(
        memories.any(
          (memory) =>
              memory.kind == 'semantic' &&
              memory.label == 'recurring_work_stressor' &&
              memory.content.contains('manager pressure'),
        ),
        isTrue,
      );
    },
  );

  test('extracts broader explicit Phase 3 memory categories', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final turns = [
      'meri behen Neha hai',
      'main roz subah walk karta hoon',
      'mera goal fitness improve karna hai',
      'late night calls mat karna',
      'advice se pehle bas sunna',
      'har sunday main chai ritual karta hoon',
      'politics ke baare mein baat mat karna',
      'traffic se stress hota hai',
    ];
    for (var i = 0; i < turns.length; i += 1) {
      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_phase3_$i',
          turnId: 'turn_phase3_$i',
          text: turns[i],
          confidence: 0.95,
          createdAt: i + 1,
        ),
      );
    }

    final memories = await database.select(database.memoryRecords).get();
    final labels = memories.map((memory) => memory.label).toSet();

    expect(labels, contains('family_relationship'));
    expect(labels, contains('routine'));
    expect(labels, contains('goal'));
    expect(labels, contains('boundary'));
    expect(labels, contains('comfort_style'));
    expect(labels, contains('ritual'));
    expect(labels, contains('taboo_topic'));
    expect(labels, contains('recurring_stressor'));
  });

  test('extracts richer Hindi and Devanagari Phase 3 phrasings', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final turns = [
      'मेरी बहन का नाम नेहा है',
      'मैं सुबह ध्यान करता हूं',
      'मुझे इंग्लिश सीखना है',
      'मुझे सलाह नहीं चाहिए',
      'राजनीति के बारे में बात मत करना',
      'पैसे से चिंता होती है',
    ];
    for (var i = 0; i < turns.length; i += 1) {
      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_hi_phase3_$i',
          turnId: 'turn_hi_phase3_$i',
          text: turns[i],
          confidence: 0.95,
          createdAt: i + 1,
        ),
      );
    }

    final rows = await database.select(database.memoryRecords).get();
    final labels = rows.map((memory) => memory.label).toSet();

    expect(labels, contains('family_relationship'));
    expect(labels, contains('routine'));
    expect(labels, contains('goal'));
    expect(labels, contains('boundary'));
    expect(labels, contains('taboo_topic'));
    expect(labels, contains('recurring_stressor'));
    expect(
      rows.any((memory) => memory.canonicalText.contains('english')),
      isTrue,
    );
    expect(
      rows.any((memory) => memory.canonicalText.contains('politics')),
      isTrue,
    );
  });

  test(
    'ambiguous and question-shaped Phase 3 turns are not admitted',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final turns = [
        'shayad mujhe kuch goals sochne chahiye?',
        'kya meri routine yaad hai?',
        'aaj bas thoda ajeeb feel hua',
        'doctor ke paas jaana hai aur fitness improve karna hai',
      ];
      for (var i = 0; i < turns.length; i += 1) {
        await database.upsertUserMessageAndExtractMemory(
          _message(
            id: 'u_false_positive_$i',
            turnId: 'turn_false_positive_$i',
            text: turns[i],
            confidence: 0.95,
            createdAt: i + 1,
          ),
        );
      }

      final rows = await database.select(database.memoryRecords).get();

      expect(rows, isEmpty);
    },
  );

  test(
    'alias linking connects boss sir and kaam variants to work stress',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_alias',
          turnId: 'turn_alias',
          text: 'kaam par boss bahut pressure deta hai',
          confidence: 0.96,
        ),
      );

      final memories = await database.readMemoryContext(
        latestUserText: 'aaj ऑफिस se aaya, sir ki wajah se bad day tha',
        limit: 6,
      );

      expect(
        memories.any(
          (memory) =>
              memory.label == 'recurring_work_stressor' &&
              memory.canonicalText.contains('manager'),
        ),
        isTrue,
      );
    },
  );

  test('contradiction handling updates non-name boundary memories', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database.upsertUserMessageAndExtractMemory(
      _message(
        id: 'u_boundary_1',
        turnId: 'turn_boundary_1',
        text: 'late night calls mat karna',
        confidence: 0.95,
        createdAt: 1,
      ),
    );
    await database.upsertUserMessageAndExtractMemory(
      _message(
        id: 'u_boundary_2',
        turnId: 'turn_boundary_2',
        text: 'actually weekend calls mat karna',
        confidence: 0.95,
        createdAt: 2,
      ),
    );

    final memories = await database.readMemoryContext(
      latestUserText: 'meri boundary kya hai?',
      limit: 4,
    );
    final boundary = memories.firstWhere(
      (memory) => memory.label == 'boundary',
    );
    final contradictions = await database
        .select(database.memoryContradictions)
        .get();

    expect(boundary.content, contains('weekend calls'));
    expect(boundary.replacementReason, 'new_explicit_boundary_statement');
    expect(contradictions.single.reason, 'new_explicit_boundary_statement');
  });

  test(
    'multi-value relationship memories coexist and same relation supersedes',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_relation_1',
          turnId: 'turn_relation_1',
          text: 'meri behen Neha hai',
          confidence: 0.95,
          createdAt: 1,
        ),
      );
      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_relation_2',
          turnId: 'turn_relation_2',
          text: 'mera bhai Aman hai',
          confidence: 0.95,
          createdAt: 2,
        ),
      );
      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_relation_3',
          turnId: 'turn_relation_3',
          text: 'actually meri behen Priya hai',
          confidence: 0.95,
          createdAt: 3,
        ),
      );

      final rows = await database.select(database.memoryRecords).get();
      final relationshipRows = rows
          .where((memory) => memory.label == 'family_relationship')
          .toList();
      final contradictions = await database
          .select(database.memoryContradictions)
          .get();

      expect(relationshipRows, hasLength(2));
      expect(
        relationshipRows.map((memory) => memory.id),
        containsAll([
          'memory_semantic_family_relationship_sister',
          'memory_semantic_family_relationship_brother',
        ]),
      );
      expect(
        relationshipRows
            .firstWhere(
              (memory) =>
                  memory.id == 'memory_semantic_family_relationship_sister',
            )
            .content,
        contains('Priya'),
      );
      expect(
        relationshipRows
            .firstWhere(
              (memory) =>
                  memory.id == 'memory_semantic_family_relationship_brother',
            )
            .content,
        contains('Aman'),
      );
      expect(
        contradictions.single.reason,
        'new_explicit_family_relationship_statement',
      );
    },
  );

  test(
    'multi-value goals and boundaries coexist by topic and supersede by topic',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_goal_1',
          turnId: 'turn_goal_1',
          text: 'mera goal fitness improve karna hai',
          confidence: 0.95,
          createdAt: 1,
        ),
      );
      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_goal_2',
          turnId: 'turn_goal_2',
          text: 'mujhe english seekhna hai',
          confidence: 0.95,
          createdAt: 2,
        ),
      );
      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_goal_3',
          turnId: 'turn_goal_3',
          text: 'actually mera goal fitness maintain karna hai',
          confidence: 0.95,
          createdAt: 3,
        ),
      );
      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_boundary_3',
          turnId: 'turn_boundary_3',
          text: 'late night calls mat karna',
          confidence: 0.95,
          createdAt: 4,
        ),
      );
      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_boundary_4',
          turnId: 'turn_boundary_4',
          text: 'advice nahi chahiye',
          confidence: 0.95,
          createdAt: 5,
        ),
      );

      final rows = await database.select(database.memoryRecords).get();
      final goalRows = rows.where((memory) => memory.label == 'goal').toList();
      final boundaryRows = rows
          .where((memory) => memory.label == 'boundary')
          .toList();

      expect(
        goalRows.map((memory) => memory.id),
        containsAll([
          'memory_semantic_goal_fitness',
          'memory_semantic_goal_english',
        ]),
      );
      expect(
        goalRows
            .firstWhere((memory) => memory.id == 'memory_semantic_goal_fitness')
            .content,
        contains('maintain'),
      );
      expect(
        boundaryRows.map((memory) => memory.id),
        containsAll([
          'memory_semantic_boundary_call',
          'memory_semantic_boundary_advice',
        ]),
      );
    },
  );

  test(
    'local consolidation decays stale low-importance and ages episodic memory',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      const dayMs = 24 * 60 * 60 * 1000;
      await database
          .into(database.memoryRecords)
          .insert(
            _memory(
              id: 'memory_core_name',
              kind: 'core_profile',
              label: 'preferred_name',
              content: 'User prefers to be called Rahul.',
              createdAt: 1,
              updatedAt: 1,
              confidence: 0.9,
              importance: 0.9,
              receiptState: 'confirmed',
            ),
          );
      await database
          .into(database.memoryRecords)
          .insert(
            _memory(
              id: 'memory_low',
              kind: 'semantic',
              label: 'safe_preference',
              content: 'User explicitly said: old low value',
              createdAt: 1,
              updatedAt: 1,
              confidence: 0.55,
              importance: 0.4,
            ),
          );
      await database
          .into(database.memoryRecords)
          .insert(
            _memory(
              id: 'memory_episode',
              kind: 'episodic',
              label: 'past_event',
              content: 'User had a difficult commute.',
              createdAt: 1,
              updatedAt: 1,
              confidence: 0.7,
              importance: 0.5,
            ),
          );

      await database.consolidateLocalMemory(nowMs: 45 * dayMs);

      final rows = await database.select(database.memoryRecords).get();
      final byId = {for (final row in rows) row.id: row};

      expect(byId['memory_core_name']!.importanceScore, 0.9);
      expect(byId['memory_core_name']!.temporalStatus, 'current');
      expect(byId['memory_low']!.temporalStatus, 'stale');
      expect(byId['memory_low']!.importanceScore, lessThan(0.3));
      expect(byId['memory_episode']!.kind, 'session_summary');
      expect(byId['memory_episode']!.label, 'past_episodic_summary');
      expect(byId['memory_episode']!.temporalStatus, 'past');
    },
  );

  test(
    'explicit voice receipt confirmation persists confirmed state',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_receipt_seed',
          turnId: 'turn_receipt_seed',
          text: 'office mein manager bahut pressure deta hai',
          confidence: 0.96,
          createdAt: 1,
        ),
      );

      final pending = await database.readPendingMemoryReceipts(limit: 4);
      expect(
        pending.map((memory) => memory.id),
        contains('memory_semantic_work_stress_manager'),
      );

      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_receipt_yes',
          turnId: 'turn_receipt_yes',
          text: 'haan yaad rakhna',
          confidence: 0.96,
          createdAt: 2,
        ),
      );

      final memories = await database.readMemoryContext(
        latestUserText: 'aaj office ka din phir heavy tha',
        limit: 6,
      );
      final memory = memories.firstWhere(
        (item) => item.id == 'memory_semantic_work_stress_manager',
      );

      expect(memory.receiptState, 'confirmed');
      expect(memory.recurrenceCount, 2);
      expect(
        jsonDecode(memory.sourceTurnIdsJson),
        contains('turn_receipt_yes'),
      );

      final chatRows = await database.select(database.chatMessages).get();
      expect(chatRows.map((row) => row.turnId), contains('turn_receipt_yes'));
      expect(
        (await database.select(database.memoryRecords).get())
            .where((row) => row.label == 'previous_session')
            .map((row) => row.originalText)
            .join('\n'),
        isNot(contains('haan yaad rakhna')),
      );
    },
  );

  test(
    'receipt control without a pending memory is saved but creates no memory',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_receipt_without_pending',
          turnId: 'turn_receipt_without_pending',
          text: 'haan yaad rakhna',
          confidence: 0.96,
          createdAt: 1,
        ),
      );

      final chatRows = await database.select(database.chatMessages).get();
      expect(chatRows, hasLength(1));
      expect(await database.select(database.memoryRecords).get(), isEmpty);
    },
  );

  test(
    'explicit voice receipt rejection expires memory and excludes retrieval',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_receipt_seed',
          turnId: 'turn_receipt_seed',
          text: 'office mein manager bahut pressure deta hai',
          confidence: 0.96,
          createdAt: 1,
        ),
      );
      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_receipt_no',
          turnId: 'turn_receipt_no',
          text: 'nahi yaad mat rakhna',
          confidence: 0.96,
          createdAt: 2,
        ),
      );

      final rows = await database.select(database.memoryRecords).get();
      final rejected = rows.firstWhere(
        (item) => item.id == 'memory_semantic_work_stress_manager',
      );
      final retrieved = await database.readMemoryContext(
        latestUserText: 'office manager pressure yaad hai?',
        limit: 6,
      );
      final embeddable = await database.readEmbeddableMemoryRecords();

      expect(rejected.receiptState, 'rejected');
      expect(rejected.temporalStatus, 'expired');
      expect(rejected.replacementReason, 'explicit_memory_receipt_rejection');
      expect(
        retrieved.map((memory) => memory.id),
        isNot(contains('memory_semantic_work_stress_manager')),
      );
      expect(
        embeddable.map((memory) => memory.id),
        isNot(contains('memory_semantic_work_stress_manager')),
      );

      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_receipt_recall_after_rejection',
          turnId: 'turn_receipt_recall_after_rejection',
          text: 'office mein manager bahut pressure deta hai',
          confidence: 0.96,
          createdAt: 3,
        ),
      );
      final afterRecall =
          await (database.select(database.memoryRecords)..where(
                (row) => row.id.equals('memory_semantic_work_stress_manager'),
              ))
              .getSingle();
      expect(afterRecall.receiptState, 'rejected');
      expect(afterRecall.temporalStatus, 'expired');
    },
  );

  test(
    'vague acknowledgement does not confirm pending memory receipt',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_receipt_seed',
          turnId: 'turn_receipt_seed',
          text: 'office mein manager bahut pressure deta hai',
          confidence: 0.96,
          createdAt: 1,
        ),
      );
      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_receipt_ack',
          turnId: 'turn_receipt_ack',
          text: 'haan theek hai',
          confidence: 0.96,
          createdAt: 2,
        ),
      );

      final pending = await database.readPendingMemoryReceipts(limit: 4);
      final memory = pending.firstWhere(
        (item) => item.id == 'memory_semantic_work_stress_manager',
      );

      expect(memory.receiptState, 'unconfirmed');
      expect(
        jsonDecode(memory.sourceTurnIdsJson),
        isNot(contains('turn_receipt_ack')),
      );
    },
  );

  test('receipt prompts are throttled after being marked prompted', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database.upsertUserMessageAndExtractMemory(
      _message(
        id: 'u_receipt_seed',
        turnId: 'turn_receipt_seed',
        text: 'office mein manager bahut pressure deta hai',
        confidence: 0.96,
        createdAt: 1,
      ),
    );

    final pending = await database.readPendingMemoryReceipts(limit: 4);
    expect(pending, hasLength(1));

    await database.markMemoryReceiptPrompted(
      memoryId: pending.single.id,
      promptedAt: DateTime.now().millisecondsSinceEpoch,
    );

    final throttled = await database.readPendingMemoryReceipts(limit: 4);
    expect(throttled, isEmpty);
  });

  test('memory retrieval does not throttle pending receipt prompt', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database.upsertUserMessageAndExtractMemory(
      _message(
        id: 'u_receipt_seed',
        turnId: 'turn_receipt_seed',
        text: 'office mein manager bahut pressure deta hai',
        confidence: 0.96,
        createdAt: 1,
      ),
    );

    final retrieved = await database.readMemoryContext(
      latestUserText: 'aaj office se aaya bad day tha',
      limit: 6,
    );
    expect(
      retrieved.map((memory) => memory.id),
      contains('memory_semantic_work_stress_manager'),
    );

    final pending = await database.readPendingMemoryReceipts(limit: 4);
    expect(
      pending.map((memory) => memory.id),
      contains('memory_semantic_work_stress_manager'),
    );
  });

  test(
    'redacted memory diagnostics snapshot reports counts without text',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u_diag',
          turnId: 'turn_diag',
          text: 'mera naam Rahul hai',
          confidence: 0.96,
        ),
      );

      final snapshot = await database.readMemoryDiagnosticsSnapshot();

      expect(snapshot['memory_count'], 1);
      expect(snapshot['by_label'], {'preferred_name': 1});
      expect(snapshot['memory_ids'], ['memory_core_profile_preferred_name']);
      expect(snapshot.values.join(' '), isNot(contains('Rahul')));
    },
  );
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

MemoryRecordsCompanion _memory({
  required String id,
  required String kind,
  required String label,
  required String content,
  required int createdAt,
  required int updatedAt,
  required double confidence,
  required double importance,
  String receiptState = 'implicit',
}) {
  return MemoryRecordsCompanion.insert(
    id: id,
    kind: kind,
    label: label,
    content: content,
    originalText: Value(content),
    canonicalText: Value(content.toLowerCase()),
    sourceTurnIdsJson: jsonEncode(['turn_$id']),
    sourceRole: 'user',
    transcriptStatus: 'final',
    createdAt: createdAt,
    updatedAt: updatedAt,
    confidenceScore: confidence,
    importanceScore: importance,
    receiptState: Value(receiptState),
  );
}
