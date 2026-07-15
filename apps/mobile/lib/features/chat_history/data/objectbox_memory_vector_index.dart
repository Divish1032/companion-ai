import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// Required by objectbox_generator to resolve entity annotations.
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'memory_model_config.dart';
import 'memory_vector_index.dart';
import '../../../objectbox.g.dart';

final memoryVectorIndexProvider = FutureProvider<MemoryVectorIndex>((
  ref,
) async {
  final index = await ObjectBoxMemoryVectorIndex.openOrRecreate();
  ref.onDispose(() {
    unawaited(index.close());
  });
  return index;
});

@Entity()
class ObjectBoxMemoryVector {
  ObjectBoxMemoryVector({
    this.id = 0,
    required this.memoryId,
    required this.embedding,
    required this.updatedAtMs,
  });

  @Id()
  int id;

  @Unique(onConflict: ConflictStrategy.replace)
  String memoryId;

  @HnswIndex(
    dimensions: memoryEmbeddingDimensions,
    distanceType: VectorDistanceType.cosine,
  )
  @Property(type: PropertyType.floatVector)
  List<double> embedding;

  int updatedAtMs;
}

class ObjectBoxMemoryVectorIndex implements MemoryVectorIndex {
  ObjectBoxMemoryVectorIndex._(this._store)
    : _box = _store.box<ObjectBoxMemoryVector>();

  final Store _store;
  final Box<ObjectBoxMemoryVector> _box;

  static Future<ObjectBoxMemoryVectorIndex> open({String? directory}) async {
    final store = await openStore(
      directory: directory ?? await defaultMemoryVectorStoreDirectory(),
    );
    return ObjectBoxMemoryVectorIndex._(store);
  }

  static Future<ObjectBoxMemoryVectorIndex> openOrRecreate({
    String? directory,
  }) async {
    try {
      return await open(directory: directory);
    } catch (_) {
      await deleteMemoryVectorStoreFiles(directory: directory);
      return open(directory: directory);
    }
  }

  static ObjectBoxMemoryVectorIndex openForTesting({required String name}) {
    final store = Store(
      getObjectBoxModel(),
      directory: '${Store.inMemoryPrefix}$name',
    );
    return ObjectBoxMemoryVectorIndex._(store);
  }

  @override
  Future<void> upsert({
    required String memoryId,
    required List<double> embedding,
  }) async {
    if (embedding.length != memoryEmbeddingDimensions) {
      throw ArgumentError.value(
        embedding.length,
        'embedding.length',
        'Expected $memoryEmbeddingDimensions dimensions.',
      );
    }
    _box.put(
      ObjectBoxMemoryVector(
        memoryId: memoryId,
        embedding: List<double>.of(embedding),
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Future<List<VectorSearchHit>> search({
    required List<double> queryEmbedding,
    required int limit,
  }) async {
    if (limit <= 0 || queryEmbedding.length != memoryEmbeddingDimensions) {
      return const [];
    }
    final query = _box
        .query(
          ObjectBoxMemoryVector_.embedding.nearestNeighborsF32(
            queryEmbedding,
            limit,
          ),
        )
        .build();
    try {
      return [
        for (final result in query.findWithScores())
          VectorSearchHit(
            memoryId: result.object.memoryId,
            score: _distanceToSimilarity(result.score),
          ),
      ];
    } finally {
      query.close();
    }
  }

  @override
  Future<int> count() async => _box.count();

  @override
  Future<void> delete(String memoryId) async {
    final query = _box
        .query(ObjectBoxMemoryVector_.memoryId.equals(memoryId))
        .build();
    try {
      query.remove();
    } finally {
      query.close();
    }
  }

  @override
  Future<void> deleteAll() async {
    _box.removeAll();
  }

  Future<void> close() async {
    _store.close();
  }
}

double _distanceToSimilarity(double distance) {
  if (distance < 0 || distance.isNaN) {
    return 0;
  }
  return 1 / (1 + distance);
}

Future<String> defaultMemoryVectorStoreDirectory() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'companion_memory_vectors');
}

Future<void> deleteMemoryVectorStoreFiles({String? directory}) async {
  final directoryPath = directory ?? await defaultMemoryVectorStoreDirectory();
  final directoryFile = Directory(directoryPath);
  if (directoryFile.existsSync()) {
    await directoryFile.delete(recursive: true);
  }
}
