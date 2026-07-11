import 'dart:convert';

import 'package:companion_mobile/features/chat_history/data/app_database.dart';
import 'package:companion_mobile/features/chat_history/data/memory_embedding_service.dart';
import 'package:companion_mobile/features/chat_history/data/memory_model_config.dart';
import 'package:companion_mobile/features/chat_history/data/memory_vector_index.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('HTTP embedding client sends configured model and dimension', () async {
    final client = HttpMemoryEmbeddingClient(
      baseUrl: 'http://api.test',
      model: 'embedding-test',
      dimension: memoryEmbeddingDimensions,
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(request.url.path, '/v1/embeddings');
        expect(body['model'], 'embedding-test');
        expect(body['dimension'], memoryEmbeddingDimensions);
        expect(body['texts'], ['hello']);
        return http.Response(
          jsonEncode({
            'model': 'embedding-test',
            'dimension': memoryEmbeddingDimensions,
            'embeddings': [_embedding(first: 1)],
          }),
          200,
        );
      }),
    );

    final embeddings = await client.embedTexts(['hello']);

    expect(embeddings.single, _embedding(first: 1));
  });

  test(
    'HTTP rerank client sends configured model and parses result order',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.memoryRecords)
          .insert(
            _memory(
              id: 'memory_a',
              kind: 'semantic',
              label: 'a',
              content: 'Memory A',
            ),
          );
      await database
          .into(database.memoryRecords)
          .insert(
            _memory(
              id: 'memory_b',
              kind: 'semantic',
              label: 'b',
              content: 'Memory B',
            ),
          );
      final candidates = await database.readEmbeddableMemoryRecords();
      final client = HttpMemoryRerankClient(
        baseUrl: 'http://api.test',
        model: 'rerank-test',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(request.url.path, '/v1/rerank');
          expect(body['model'], 'rerank-test');
          expect(body['query'], 'query');
          expect(body['candidates'], isA<List<Object?>>());
          return http.Response(
            jsonEncode({
              'model': 'rerank-test',
              'results': [
                {'id': 'memory_b', 'score': 0.9},
                {'id': 'memory_a', 'score': 0.3},
              ],
            }),
            200,
          );
        }),
      );

      final rankedIds = await client.rerank(
        query: 'query',
        candidates: candidates,
      );

      expect(rankedIds, ['memory_b', 'memory_a']);
    },
  );

  test('syncTurnMemories embeds admitted memories into vector index', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final vectorIndex = InMemoryMemoryVectorIndex();
    addTearDown(database.close);

    await database.upsertUserMessageAndExtractMemory(
      _message(
        id: 'u1',
        turnId: 'turn_1',
        text: 'office mein manager pressure deta hai',
      ),
    );

    final sync = MemoryEmbeddingSync(
      database: database,
      embeddingClient: _FakeEmbeddingClient(),
      vectorIndexLoader: () async => vectorIndex,
    );
    await sync.syncTurnMemories('turn_1');

    final hits = await vectorIndex.search(
      queryEmbedding: _embedding(first: 1),
      limit: 4,
    );

    expect(
      hits.map((hit) => hit.memoryId),
      contains('memory_semantic_work_stress_manager'),
    );
  });

  test('embedding failure does not remove admitted local memory', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final vectorIndex = InMemoryMemoryVectorIndex();
    addTearDown(database.close);

    await database.upsertUserMessageAndExtractMemory(
      _message(id: 'u1', turnId: 'turn_1', text: 'mera naam Rahul hai'),
    );

    final sync = MemoryEmbeddingSync(
      database: database,
      embeddingClient: _FailingEmbeddingClient(),
      vectorIndexLoader: () async => vectorIndex,
    );
    await sync.syncTurnMemories('turn_1');

    final memories = await database.readMemoryContext(
      latestUserText: 'mera naam kya hai?',
      limit: 4,
    );
    final hits = await vectorIndex.search(
      queryEmbedding: _embedding(first: 1),
      limit: 4,
    );

    expect(memories.single.label, 'preferred_name');
    expect(hits, isEmpty);
  });

  test(
    'lookup uses vector hits when deterministic text matching misses',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final vectorIndex = InMemoryMemoryVectorIndex();
      addTearDown(database.close);

      await database
          .into(database.memoryRecords)
          .insert(
            _memory(
              id: 'memory_trip',
              kind: 'episodic',
              label: 'rishikesh_trip',
              content: 'User previously talked about a quiet Rishikesh trip.',
              canonicalText: 'rishikesh travel quiet river',
            ),
          );
      await vectorIndex.upsert(
        memoryId: 'memory_trip',
        embedding: _embedding(first: 1),
      );

      final lookup = MemoryLookupService(
        database: database,
        embeddingClient: _FakeEmbeddingClient(),
        rerankClient: _NoopRerankClient(),
        vectorIndexLoader: () async => vectorIndex,
        embeddingsEnabled: true,
      );
      final memories = await lookup.lookup(
        latestUserText: 'mountain wali purani baat yaad hai?',
        limit: 4,
        retrievalStrategy: 'hybrid_vector',
        rerankerStrategy: 'deterministic',
      );

      expect(memories.map((memory) => memory.id), contains('memory_trip'));
    },
  );

  test(
    'lookup falls back to deterministic retrieval if vector lookup fails',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final vectorIndex = InMemoryMemoryVectorIndex();
      addTearDown(database.close);

      await database.upsertUserMessageAndExtractMemory(
        _message(
          id: 'u1',
          turnId: 'turn_1',
          text: 'office mein manager pressure deta hai',
        ),
      );

      final lookup = MemoryLookupService(
        database: database,
        embeddingClient: _FailingEmbeddingClient(),
        rerankClient: _NoopRerankClient(),
        vectorIndexLoader: () async => vectorIndex,
      );
      final memories = await lookup.lookup(
        latestUserText: 'aaj office se aaya, bad day tha',
        limit: 4,
      );

      expect(
        memories.map((memory) => memory.id),
        contains('memory_semantic_work_stress_manager'),
      );
    },
  );

  test('default strategy never calls embeddings or the reranker', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.upsertUserMessageAndExtractMemory(
      _message(
        id: 'u_deterministic',
        turnId: 'turn_deterministic',
        text: 'office mein manager pressure deta hai',
      ),
    );
    final lookup = MemoryLookupService(
      database: database,
      embeddingClient: _FailingEmbeddingClient(),
      rerankClient: _FailingRerankClient(),
      vectorIndexLoader: () async => InMemoryMemoryVectorIndex(),
    );

    final memories = await lookup.lookup(
      latestUserText: 'aaj office se aaya, bad day tha',
      limit: 4,
      route: 'semantic',
    );

    expect(
      memories.map((memory) => memory.id),
      contains('memory_semantic_work_stress_manager'),
    );
  });

  test(
    'lookup excludes sensitive and stale memories even with vector hits',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final vectorIndex = InMemoryMemoryVectorIndex();
      addTearDown(database.close);

      await database
          .into(database.memoryRecords)
          .insert(
            _memory(
              id: 'memory_sensitive',
              kind: 'semantic',
              label: 'sensitive',
              content: 'Sensitive memory should not be returned.',
              sensitivity: 'medical',
            ),
          );
      await database
          .into(database.memoryRecords)
          .insert(
            _memory(
              id: 'memory_stale',
              kind: 'semantic',
              label: 'stale',
              content: 'Stale memory should not be returned.',
              temporalStatus: 'stale',
            ),
          );
      await vectorIndex.upsert(
        memoryId: 'memory_sensitive',
        embedding: _embedding(first: 1),
      );
      await vectorIndex.upsert(
        memoryId: 'memory_stale',
        embedding: _embedding(first: 1),
      );

      final lookup = MemoryLookupService(
        database: database,
        embeddingClient: _FakeEmbeddingClient(),
        rerankClient: _NoopRerankClient(),
        vectorIndexLoader: () async => vectorIndex,
      );
      final memories = await lookup.lookup(
        latestUserText: 'kuch related yaad hai?',
        limit: 4,
      );

      expect(memories, isEmpty);
    },
  );

  test(
    'lookup rebuilds empty vector index from SQLite memories once',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final vectorIndex = InMemoryMemoryVectorIndex();
      addTearDown(database.close);

      await database
          .into(database.memoryRecords)
          .insert(
            _memory(
              id: 'memory_rebuild',
              kind: 'episodic',
              label: 'rebuild_memory',
              content: 'User mentioned a Rishikesh trip.',
              canonicalText: 'rishikesh trip river',
            ),
          );

      final lookup = MemoryLookupService(
        database: database,
        embeddingClient: _FakeEmbeddingClient(),
        rerankClient: _NoopRerankClient(),
        vectorIndexLoader: () async => vectorIndex,
        embeddingsEnabled: true,
      );
      await lookup.lookup(
        latestUserText: 'purani trip wali baat',
        limit: 4,
        retrievalStrategy: 'hybrid_vector',
        rerankerStrategy: 'deterministic',
      );

      expect(await vectorIndex.count(), 1);
    },
  );

  test(
    'lookup reranks selected memory candidates and falls back on rerank error',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final vectorIndex = InMemoryMemoryVectorIndex();
      addTearDown(database.close);

      await database
          .into(database.memoryRecords)
          .insert(
            _memory(
              id: 'memory_first',
              kind: 'semantic',
              label: 'first',
              content: 'First memory.',
            ),
          );
      await database
          .into(database.memoryRecords)
          .insert(
            _memory(
              id: 'memory_second',
              kind: 'semantic',
              label: 'second',
              content: 'Second memory.',
            ),
          );
      await vectorIndex.upsert(
        memoryId: 'memory_first',
        embedding: _embedding(first: 1),
      );
      await vectorIndex.upsert(
        memoryId: 'memory_second',
        embedding: _embedding(first: 1),
      );

      final rerankedLookup = MemoryLookupService(
        database: database,
        embeddingClient: _FakeEmbeddingClient(),
        rerankClient: _OrderingRerankClient(['memory_second', 'memory_first']),
        vectorIndexLoader: () async => vectorIndex,
        embeddingsEnabled: true,
        rerankerEnabled: true,
      );
      final reranked = await rerankedLookup.lookup(
        latestUserText: 'related memory',
        limit: 4,
        retrievalStrategy: 'hybrid_vector',
        rerankerStrategy: 'qwen3_reranker',
      );

      expect(reranked.map((memory) => memory.id).take(2), [
        'memory_second',
        'memory_first',
      ]);

      final fallbackLookup = MemoryLookupService(
        database: database,
        embeddingClient: _FakeEmbeddingClient(),
        rerankClient: _FailingRerankClient(),
        vectorIndexLoader: () async => vectorIndex,
        embeddingsEnabled: true,
        rerankerEnabled: true,
      );
      final fallback = await fallbackLookup.lookup(
        latestUserText: 'related memory',
        limit: 4,
        retrievalStrategy: 'hybrid_vector',
        rerankerStrategy: 'qwen3_reranker',
      );

      expect(fallback.map((memory) => memory.id), contains('memory_first'));
      expect(fallback.map((memory) => memory.id), contains('memory_second'));
    },
  );
}

class _FakeEmbeddingClient implements MemoryEmbeddingClient {
  @override
  Future<List<List<double>>> embedTexts(
    List<String> texts, {
    String inputType = 'document',
  }) async {
    return [for (var i = 0; i < texts.length; i += 1) _embedding(first: 1)];
  }
}

class _FailingEmbeddingClient implements MemoryEmbeddingClient {
  @override
  Future<List<List<double>>> embedTexts(
    List<String> texts, {
    String inputType = 'document',
  }) async {
    throw const MemoryEmbeddingException(503, '{"code":"unavailable"}');
  }
}

class _NoopRerankClient implements MemoryRerankClient {
  @override
  Future<List<String>> rerank({
    required String query,
    required List<MemoryRecord> candidates,
  }) async {
    return [for (final candidate in candidates) candidate.id];
  }
}

class _OrderingRerankClient implements MemoryRerankClient {
  const _OrderingRerankClient(this.ids);

  final List<String> ids;

  @override
  Future<List<String>> rerank({
    required String query,
    required List<MemoryRecord> candidates,
  }) async {
    return ids;
  }
}

class _FailingRerankClient implements MemoryRerankClient {
  @override
  Future<List<String>> rerank({
    required String query,
    required List<MemoryRecord> candidates,
  }) async {
    throw const MemoryRerankException(503, '{"code":"unavailable"}');
  }
}

ChatMessagesCompanion _message({
  required String id,
  required String turnId,
  required String text,
}) {
  return ChatMessagesCompanion.insert(
    id: id,
    sessionId: 'session_test',
    turnId: turnId,
    role: 'user',
    messageText: text,
    status: 'final',
    language: 'hi-IN',
    createdAt: 1,
    sttConfidence: const Value(0.96),
  );
}

MemoryRecordsCompanion _memory({
  required String id,
  required String kind,
  required String label,
  required String content,
  String canonicalText = 'generic memory text',
  String sensitivity = 'normal',
  String temporalStatus = 'current',
}) {
  return MemoryRecordsCompanion.insert(
    id: id,
    kind: kind,
    label: label,
    content: content,
    originalText: Value(content),
    canonicalText: Value(canonicalText),
    language: const Value('hi-IN'),
    script: const Value('mixed'),
    sourceTurnIdsJson: jsonEncode(['turn_old']),
    sourceRole: 'user',
    transcriptStatus: 'final',
    sttConfidence: const Value(0.96),
    createdAt: 1,
    updatedAt: 1,
    confidenceScore: 0.8,
    importanceScore: 0.7,
    recurrenceCount: const Value(1),
    sensitivity: Value(sensitivity),
    temporalStatus: Value(temporalStatus),
    receiptState: const Value('implicit'),
    evidenceSummary: const Value('test memory'),
  );
}

List<double> _embedding({double first = 0}) {
  return <double>[
    first,
    for (var i = 1; i < memoryEmbeddingDimensions; i += 1) 0,
  ];
}
