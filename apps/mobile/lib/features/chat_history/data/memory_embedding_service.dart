import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import 'app_database.dart';
import 'memory_model_config.dart';
import 'memory_vector_index.dart';
import 'objectbox_memory_vector_index.dart';

final memoryEmbeddingClientProvider = Provider<MemoryEmbeddingClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return HttpMemoryEmbeddingClient(
    baseUrl: config.apiBaseUrl,
    model: config.memoryEmbeddingModel,
    dimension: config.memoryEmbeddingDimension,
  );
});

final memoryRerankClientProvider = Provider<MemoryRerankClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return HttpMemoryRerankClient(
    baseUrl: config.apiBaseUrl,
    model: config.memoryRerankModel,
  );
});

final memoryEmbeddingSyncProvider = Provider<MemoryEmbeddingSync>((ref) {
  final config = ref.watch(appConfigProvider);
  return MemoryEmbeddingSync(
    database: ref.watch(appDatabaseProvider),
    embeddingClient: ref.watch(memoryEmbeddingClientProvider),
    vectorIndexLoader: () => ref.read(memoryVectorIndexProvider.future),
    enabled: config.enableMemoryEmbeddings,
  );
});

final memoryLookupServiceProvider = Provider<MemoryLookupService>((ref) {
  final config = ref.watch(appConfigProvider);
  return MemoryLookupService(
    database: ref.watch(appDatabaseProvider),
    embeddingClient: ref.watch(memoryEmbeddingClientProvider),
    rerankClient: ref.watch(memoryRerankClientProvider),
    vectorIndexLoader: () => ref.read(memoryVectorIndexProvider.future),
    embeddingsEnabled: config.enableMemoryEmbeddings,
    rerankerEnabled: config.enableMemoryReranker,
  );
});

abstract interface class MemoryEmbeddingClient {
  Future<List<List<double>>> embedTexts(
    List<String> texts, {
    String inputType = 'document',
  });
}

abstract interface class MemoryRerankClient {
  Future<List<String>> rerank({
    required String query,
    required List<MemoryRecord> candidates,
  });
}

class HttpMemoryEmbeddingClient implements MemoryEmbeddingClient {
  const HttpMemoryEmbeddingClient({
    required this.baseUrl,
    required this.model,
    required this.dimension,
    http.Client? client,
  }) : _client = client;

  final String baseUrl;
  final String model;
  final int dimension;
  final http.Client? _client;

  @override
  Future<List<List<double>>> embedTexts(
    List<String> texts, {
    String inputType = 'document',
  }) async {
    final client = _client ?? http.Client();
    final shouldCloseClient = _client == null;
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/v1/embeddings'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({
          'texts': texts,
          'model': model,
          'dimension': dimension,
          'input_type': inputType,
        }),
      );
      if (response.statusCode != 200) {
        throw MemoryEmbeddingException(response.statusCode, response.body);
      }
      final body = jsonDecode(response.body) as Map<String, Object?>;
      final responseDimension = body['dimension'];
      final rawEmbeddings = body['embeddings'];
      if (responseDimension != dimension || rawEmbeddings is! List) {
        throw const FormatException('Invalid embedding response shape.');
      }
      final embeddings = [
        for (final rawEmbedding in rawEmbeddings)
          if (rawEmbedding is List)
            [
              for (final value in rawEmbedding)
                if (value is num) value.toDouble(),
            ],
      ];
      if (embeddings.length != texts.length ||
          embeddings.any((embedding) => embedding.length != dimension)) {
        throw const FormatException('Invalid embedding response dimensions.');
      }
      return embeddings;
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }
}

class HttpMemoryRerankClient implements MemoryRerankClient {
  const HttpMemoryRerankClient({
    required this.baseUrl,
    required this.model,
    http.Client? client,
  }) : _client = client;

  final String baseUrl;
  final String model;
  final http.Client? _client;

  @override
  Future<List<String>> rerank({
    required String query,
    required List<MemoryRecord> candidates,
  }) async {
    if (candidates.isEmpty) {
      return const [];
    }
    final client = _client ?? http.Client();
    final shouldCloseClient = _client == null;
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/v1/rerank'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'model': model,
          'candidates': [
            for (final memory in candidates)
              {
                'id': memory.id,
                'text': memory.canonicalText.isNotEmpty
                    ? memory.canonicalText
                    : memory.content,
              },
          ],
        }),
      );
      if (response.statusCode != 200) {
        throw MemoryRerankException(response.statusCode, response.body);
      }
      final body = jsonDecode(response.body) as Map<String, Object?>;
      final rawResults = body['results'];
      if (rawResults is! List) {
        throw const FormatException('Invalid rerank response shape.');
      }
      final knownIds = {for (final candidate in candidates) candidate.id};
      return [
        for (final result in rawResults)
          if (result is Map<String, Object?> &&
              result['id'] is String &&
              knownIds.contains(result['id']))
            result['id'] as String,
      ];
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }
}

class MemoryEmbeddingSync {
  const MemoryEmbeddingSync({
    required this.database,
    required this.embeddingClient,
    required this.vectorIndexLoader,
    this.enabled = true,
  });

  final AppDatabase database;
  final MemoryEmbeddingClient embeddingClient;
  final Future<MemoryVectorIndex> Function() vectorIndexLoader;
  final bool enabled;

  Future<void> syncTurnMemories(String turnId) async {
    if (!enabled) return;
    final memories = await database.readMemoryRecordsForTurn(turnId: turnId);
    final embeddable = [
      for (final memory in memories)
        if (_embeddable(memory)) memory,
    ];
    if (embeddable.isEmpty) {
      return;
    }
    try {
      final embeddings = await embeddingClient.embedTexts([
        for (final memory in embeddable)
          memory.canonicalText.isNotEmpty
              ? memory.canonicalText
              : memory.content,
      ]);
      final vectorIndex = await vectorIndexLoader();
      for (var i = 0; i < embeddable.length && i < embeddings.length; i += 1) {
        final embedding = embeddings[i];
        if (embedding.length != memoryEmbeddingDimensions) {
          continue;
        }
        await vectorIndex.upsert(
          memoryId: embeddable[i].id,
          embedding: embedding,
        );
      }
    } catch (error) {
      developer.log(
        'memory_embedding_sync_failed '
        '{turn_id: $turnId, memory_count: ${embeddable.length}, error_type: ${error.runtimeType}}',
        name: 'companion.memory',
      );
    }
  }

  Future<int> rebuildIndexFromLocalMemory() async {
    if (!enabled) return 0;
    final memories = [
      for (final memory in await database.readEmbeddableMemoryRecords())
        if (_embeddable(memory)) memory,
    ];
    final vectorIndex = await vectorIndexLoader();
    await vectorIndex.deleteAll();
    var indexed = 0;
    for (var start = 0; start < memories.length; start += 32) {
      final batch = memories.skip(start).take(32).toList();
      final embeddings = await embeddingClient.embedTexts([
        for (final memory in batch)
          memory.canonicalText.isNotEmpty
              ? memory.canonicalText
              : memory.content,
      ]);
      for (var i = 0; i < batch.length && i < embeddings.length; i += 1) {
        final embedding = embeddings[i];
        if (embedding.length != memoryEmbeddingDimensions) {
          continue;
        }
        await vectorIndex.upsert(memoryId: batch[i].id, embedding: embedding);
        indexed += 1;
      }
    }
    return indexed;
  }
}

class MemoryLookupService {
  MemoryLookupService({
    required this.database,
    required this.embeddingClient,
    required this.rerankClient,
    required this.vectorIndexLoader,
    this.embeddingsEnabled = false,
    this.rerankerEnabled = false,
  });

  final AppDatabase database;
  final MemoryEmbeddingClient embeddingClient;
  final MemoryRerankClient rerankClient;
  final Future<MemoryVectorIndex> Function() vectorIndexLoader;
  final bool embeddingsEnabled;
  final bool rerankerEnabled;
  bool _rebuildAttempted = false;

  Future<List<MemoryRecord>> lookup({
    required String latestUserText,
    required int limit,
    String retrievalStrategy = 'deterministic',
    String rerankerStrategy = 'deterministic',
    String? route,
  }) async {
    if (limit <= 0) {
      return const [];
    }
    final useVector = retrievalStrategy == 'hybrid_vector' && embeddingsEnabled;
    final useQwenReranker =
        rerankerStrategy == 'qwen3_reranker' && rerankerEnabled;
    if (!useVector) {
      final deterministic = await database.readMemoryContext(
        latestUserText: latestUserText,
        limit: limit,
        route: route,
      );
      return _rerankOrFallback(
        latestUserText,
        deterministic,
        useQwenReranker: useQwenReranker,
      );
    }
    try {
      await _rebuildEmptyVectorIndexOnce();
      final embeddings = await embeddingClient.embedTexts([
        latestUserText,
      ], inputType: 'query');
      if (embeddings.isEmpty) {
        final deterministic = await database.readMemoryContext(
          latestUserText: latestUserText,
          limit: limit,
          route: route,
        );
        return _rerankOrFallback(
          latestUserText,
          deterministic,
          useQwenReranker: useQwenReranker,
        );
      }
      final vectorIndex = await vectorIndexLoader();
      final vectorHits = await vectorIndex.search(
        queryEmbedding: embeddings.single,
        limit: (limit * 2).clamp(limit, 12).toInt(),
      );
      final candidates = await database.readMemoryContext(
        latestUserText: latestUserText,
        limit: limit,
        vectorHits: vectorHits,
        route: route,
      );
      return _rerankOrFallback(
        latestUserText,
        candidates,
        useQwenReranker: useQwenReranker,
      );
    } catch (error) {
      developer.log(
        'memory_lookup_vector_fallback '
        '{limit: $limit, error_type: ${error.runtimeType}}',
        name: 'companion.memory',
      );
      final deterministic = await database.readMemoryContext(
        latestUserText: latestUserText,
        limit: limit,
        route: route,
      );
      return _rerankOrFallback(
        latestUserText,
        deterministic,
        useQwenReranker: useQwenReranker,
      );
    }
  }

  Future<void> _rebuildEmptyVectorIndexOnce() async {
    if (_rebuildAttempted) {
      return;
    }
    _rebuildAttempted = true;
    final vectorIndex = await vectorIndexLoader();
    if (await vectorIndex.count() > 0) {
      return;
    }
    try {
      final sync = MemoryEmbeddingSync(
        database: database,
        embeddingClient: embeddingClient,
        vectorIndexLoader: vectorIndexLoader,
      );
      final indexed = await sync.rebuildIndexFromLocalMemory();
      if (indexed > 0) {
        developer.log(
          'memory_vector_index_rebuilt {memory_count: $indexed}',
          name: 'companion.memory',
        );
      }
    } catch (error) {
      developer.log(
        'memory_vector_index_rebuild_failed {error_type: ${error.runtimeType}}',
        name: 'companion.memory',
      );
    }
  }

  Future<List<MemoryRecord>> _rerankOrFallback(
    String latestUserText,
    List<MemoryRecord> candidates, {
    required bool useQwenReranker,
  }) async {
    if (candidates.length <= 1) {
      return candidates;
    }
    if (!useQwenReranker) {
      return candidates;
    }
    try {
      final rankedIds = await rerankClient.rerank(
        query: latestUserText,
        candidates: candidates,
      );
      if (rankedIds.isEmpty) {
        return candidates;
      }
      final byId = {
        for (final candidate in candidates) candidate.id: candidate,
      };
      return [
        for (final id in rankedIds)
          if (byId.containsKey(id)) byId[id]!,
        for (final candidate in candidates)
          if (!rankedIds.contains(candidate.id)) candidate,
      ].take(candidates.length).toList();
    } catch (error) {
      developer.log(
        'memory_rerank_fallback '
        '{candidate_count: ${candidates.length}, error_type: ${error.runtimeType}}',
        name: 'companion.memory',
      );
      return candidates;
    }
  }
}

class MemoryEmbeddingException implements Exception {
  const MemoryEmbeddingException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'MemoryEmbeddingException($statusCode): $body';
}

class MemoryRerankException implements Exception {
  const MemoryRerankException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'MemoryRerankException($statusCode): $body';
}

bool _embeddable(MemoryRecord memory) {
  // Names and response settings are deterministic Companion State, never
  // fuzzy vector documents. Keep only semantic/episodic material in ObjectBox.
  if (!{'semantic', 'episodic', 'session_summary'}.contains(memory.kind)) {
    return false;
  }
  if (memory.sensitivity != 'normal') {
    return false;
  }
  if (memory.temporalStatus == 'expired') {
    return false;
  }
  if (memory.content.trim().isEmpty) {
    return false;
  }
  return true;
}
