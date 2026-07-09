import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat_history/data/memory_model_config.dart';

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());

class AppConfig {
  const AppConfig({
    this.apiBaseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8000',
    ),
    this.memoryEmbeddingModel = defaultMemoryEmbeddingModel,
    this.memoryEmbeddingDimension = memoryEmbeddingDimensions,
    this.memoryRerankModel = defaultMemoryRerankModel,
  });

  final String apiBaseUrl;
  final String memoryEmbeddingModel;
  final int memoryEmbeddingDimension;
  final String memoryRerankModel;
}
