import 'dart:math' as math;

abstract interface class MemoryVectorIndex {
  Future<void> upsert({
    required String memoryId,
    required List<double> embedding,
  });

  Future<List<VectorSearchHit>> search({
    required List<double> queryEmbedding,
    required int limit,
  });

  Future<int> count();

  Future<void> delete(String memoryId);

  Future<void> deleteAll();
}

class VectorSearchHit {
  const VectorSearchHit({required this.memoryId, required this.score});

  final String memoryId;
  final double score;
}

class InMemoryMemoryVectorIndex implements MemoryVectorIndex {
  final Map<String, List<double>> _vectors = <String, List<double>>{};

  @override
  Future<void> upsert({
    required String memoryId,
    required List<double> embedding,
  }) async {
    _vectors[memoryId] = List<double>.unmodifiable(embedding);
  }

  @override
  Future<List<VectorSearchHit>> search({
    required List<double> queryEmbedding,
    required int limit,
  }) async {
    final hits = [
      for (final entry in _vectors.entries)
        VectorSearchHit(
          memoryId: entry.key,
          score: _cosine(queryEmbedding, entry.value),
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList();
  }

  @override
  Future<int> count() async => _vectors.length;

  @override
  Future<void> delete(String memoryId) async {
    _vectors.remove(memoryId);
  }

  @override
  Future<void> deleteAll() async {
    _vectors.clear();
  }
}

double _cosine(List<double> a, List<double> b) {
  if (a.isEmpty || b.isEmpty || a.length != b.length) {
    return 0;
  }
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < a.length; i += 1) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA == 0 || normB == 0) {
    return 0;
  }
  return dot / math.sqrt(normA * normB);
}
