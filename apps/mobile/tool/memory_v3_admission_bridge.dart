import 'dart:convert';
import 'dart:io';

import 'package:companion_mobile/features/chat_history/data/memory_v3_admission.dart';
import 'package:companion_mobile/features/chat_history/data/memory_v3_models.dart';

/// Batch bridge used by the offline evaluator to execute the production phone
/// admission policy. Input and output are JSON and contain no network calls or
/// durable writes.
Future<void> main(List<String> arguments) async {
  if (arguments.length > 1) {
    stderr.writeln(
      'usage: dart run tool/memory_v3_admission_bridge.dart [input.json]',
    );
    exitCode = 64;
    return;
  }
  final input = arguments.isEmpty
      ? await stdin.transform(utf8.decoder).join()
      : await File(arguments.single).readAsString();
  try {
    final decoded = jsonDecode(input);
    if (decoded is! Map<String, Object?> ||
        decoded['cases'] is! List<Object?>) {
      throw const FormatException('Bridge input requires a cases array.');
    }
    final results = <Map<String, Object?>>[];
    for (final rawCase in decoded['cases']! as List<Object?>) {
      if (rawCase is! Map<String, Object?> ||
          rawCase['case_id'] is! String ||
          rawCase['sources'] is! List<Object?> ||
          rawCase['candidates'] is! List<Object?>) {
        throw const FormatException('Invalid bridge case.');
      }
      final sources = [
        for (final item in rawCase['sources']! as List<Object?>)
          MemoryV3AdmissionSource.fromJson(_object(item, 'admission source')),
      ];
      final outcomes = <Map<String, Object?>>[];
      for (final item in rawCase['candidates']! as List<Object?>) {
        final candidate = MemoryV3Observation.fromJson(
          _object(item, 'candidate'),
        );
        outcomes.add({
          'candidate_id': candidate.candidateId,
          ...validateMemoryV3Candidate(candidate, sources).toJson(),
        });
      }
      results.add({'case_id': rawCase['case_id'], 'outcomes': outcomes});
    }
    stdout.writeln(jsonEncode({'results': results}));
  } on Object catch (error) {
    stderr.writeln('memory_v3_admission_bridge_error:${error.runtimeType}');
    exitCode = 65;
  }
}

Map<String, Object?> _object(Object? value, String label) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$label must be an object.');
  }
  return value;
}
