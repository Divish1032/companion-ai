import 'package:companion_mobile/features/chat_history/data/memory_model_config.dart';
import 'package:companion_mobile/features/chat_history/data/objectbox_memory_vector_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'ObjectBox memory vector index upserts, searches, and clears vectors',
    () async {
      final index = ObjectBoxMemoryVectorIndex.openForTesting(
        name: 'memory-vector-index-test',
      );
      addTearDown(index.close);

      await index.upsert(
        memoryId: 'memory_work',
        embedding: _embedding(first: 1),
      );
      await index.upsert(
        memoryId: 'memory_food',
        embedding: _embedding(second: 1),
      );

      var hits = await index.search(
        queryEmbedding: _embedding(first: 1),
        limit: 2,
      );

      expect(hits, hasLength(2));
      expect(hits.first.memoryId, 'memory_work');
      expect(hits.first.score, greaterThanOrEqualTo(hits.last.score));

      await index.upsert(
        memoryId: 'memory_work',
        embedding: _embedding(third: 1),
      );
      hits = await index.search(queryEmbedding: _embedding(third: 1), limit: 2);

      expect(hits.first.memoryId, 'memory_work');

      await index.deleteAll();
      hits = await index.search(queryEmbedding: _embedding(first: 1), limit: 2);

      expect(hits, isEmpty);
    },
  );

  test('ObjectBox memory vector index rejects unexpected dimensions', () async {
    final index = ObjectBoxMemoryVectorIndex.openForTesting(
      name: 'memory-vector-index-dimensions-test',
    );
    addTearDown(index.close);

    expect(
      () => index.upsert(memoryId: 'bad', embedding: const [1, 2, 3]),
      throwsArgumentError,
    );
  });
}

List<double> _embedding({
  double first = 0,
  double second = 0,
  double third = 0,
}) {
  return <double>[
    first,
    second,
    third,
    for (var i = 3; i < memoryEmbeddingDimensions; i += 1) 0,
  ];
}
