import 'dart:io';

import 'package:companion_mobile/features/chat_history/data/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('schema v4 upgrades to v5 without losing durable memory', () async {
    final fixture = await _currentDatabaseFixture('companion-v4-migration');
    final current = fixture.database;
    await current
        .into(current.memoryRecords)
        .insert(
          MemoryRecordsCompanion.insert(
            id: 'memory_existing',
            kind: 'semantic',
            label: 'goal',
            content: 'User wants to learn guitar.',
            sourceTurnIdsJson: '["t1"]',
            sourceRole: 'user',
            transcriptStatus: 'final',
            createdAt: 10,
            updatedAt: 10,
            confidenceScore: 0.9,
            importanceScore: 0.8,
          ),
        );
    await current.close();

    final raw = sqlite.sqlite3.open(fixture.file.path);
    _dropMemoryFts(raw);
    for (final table in const [
      'memory_candidates',
      'memory_extraction_jobs',
      'memory_open_threads',
      'memory_episodes',
    ]) {
      raw.execute('DROP TABLE $table');
    }
    raw.userVersion = 4;
    raw.close();

    final upgraded = AppDatabase.forTesting(NativeDatabase(fixture.file));
    expect(
      (await upgraded.select(upgraded.memoryRecords).getSingle()).content,
      'User wants to learn guitar.',
    );
    expect(await upgraded.select(upgraded.memoryEpisodes).get(), isEmpty);
    final ftsRows = await upgraded
        .customSelect(
          'SELECT memory_id FROM memory_records_fts WHERE memory_id = ?',
          variables: [const Variable<String>('memory_existing')],
        )
        .get();
    expect(ftsRows.single.read<String>('memory_id'), 'memory_existing');
    await upgraded.close();
    await fixture.directory.delete(recursive: true);
  });

  test(
    'schema v1 upgrades directly without duplicate-column failure',
    () async {
      final fixture = await _currentDatabaseFixture('companion-v1-migration');
      await fixture.database.close();
      final raw = sqlite.sqlite3.open(fixture.file.path);
      _dropMemoryFts(raw);
      for (final table in const [
        'memory_candidates',
        'memory_extraction_jobs',
        'memory_open_threads',
        'memory_episodes',
        'memory_contradictions',
        'memory_edges',
        'memory_entities',
        'memory_records',
      ]) {
        raw.execute('DROP TABLE $table');
      }
      raw.execute('ALTER TABLE chat_messages DROP COLUMN stt_confidence');
      raw.userVersion = 1;
      raw.close();

      final upgraded = AppDatabase.forTesting(NativeDatabase(fixture.file));
      expect(await upgraded.select(upgraded.memoryRecords).get(), isEmpty);
      expect(await upgraded.select(upgraded.memoryCandidates).get(), isEmpty);
      await upgraded
          .into(upgraded.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              id: 'm1',
              sessionId: 's1',
              turnId: 't1',
              role: 'user',
              messageText: 'hello',
              status: 'final',
              language: 'hi-IN',
              createdAt: 1,
              sttConfidence: const Value(0.9),
            ),
          );
      expect(
        (await upgraded.select(upgraded.chatMessages).getSingle())
            .sttConfidence,
        0.9,
      );
      await upgraded.close();
      await fixture.directory.delete(recursive: true);
    },
  );
}

Future<_DatabaseFixture> _currentDatabaseFixture(String prefix) async {
  final directory = await Directory.systemTemp.createTemp(prefix);
  final file = File('${directory.path}/companion.sqlite');
  final database = AppDatabase.forTesting(NativeDatabase(file));
  await database.select(database.chatMessages).get();
  return _DatabaseFixture(directory, file, database);
}

void _dropMemoryFts(sqlite.Database database) {
  database.execute('DROP TRIGGER IF EXISTS memory_records_fts_insert');
  database.execute('DROP TRIGGER IF EXISTS memory_records_fts_update');
  database.execute('DROP TRIGGER IF EXISTS memory_records_fts_delete');
  database.execute('DROP TABLE IF EXISTS memory_records_fts');
}

class _DatabaseFixture {
  const _DatabaseFixture(this.directory, this.file, this.database);

  final Directory directory;
  final File file;
  final AppDatabase database;
}
