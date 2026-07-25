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
    this.enableMemoryEmbeddings = true,
    this.enableMemoryReranker = false,
    this.enableMemoryExtraction = const bool.fromEnvironment(
      'ENABLE_MEMORY_EXTRACTION',
      defaultValue: false,
    ),
    this.enableMemoryV3Compiler = const bool.fromEnvironment(
      'ENABLE_MEMORY_V3_COMPILER',
      defaultValue: false,
    ),
    this.memoryTimezone = const String.fromEnvironment(
      'MEMORY_TIMEZONE',
      defaultValue: 'Asia/Kolkata',
    ),
  });

  final String apiBaseUrl;
  final String memoryEmbeddingModel;
  final int memoryEmbeddingDimension;
  final String memoryRerankModel;
  final bool enableMemoryEmbeddings;
  final bool enableMemoryReranker;
  final bool enableMemoryExtraction;
  final bool enableMemoryV3Compiler;
  final String memoryTimezone;
}
