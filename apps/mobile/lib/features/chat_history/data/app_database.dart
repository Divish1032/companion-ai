import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

class ChatSessions extends Table {
  TextColumn get id => text()();
  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer().nullable()();
  TextColumn get language => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get turnId => text()();
  TextColumn get role => text()();
  TextColumn get messageText => text().named('text')();
  TextColumn get status => text()();
  TextColumn get language => text()();
  IntColumn get createdAt => integer()();
  TextColumn get latencyJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [ChatSessions, ChatMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Sprint 1 starts versioned migrations; future schema changes go here.
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Stream<List<ChatMessage>> watchMessages() {
    return (select(
      chatMessages,
    )..orderBy([(message) => OrderingTerm.asc(message.createdAt)])).watch();
  }

  Future<List<ChatMessage>> readMessages() {
    return (select(
      chatMessages,
    )..orderBy([(message) => OrderingTerm.asc(message.createdAt)])).get();
  }

  Future<void> upsertSession(ChatSessionsCompanion session) {
    return into(chatSessions).insertOnConflictUpdate(session);
  }

  Future<void> addMessage(ChatMessagesCompanion message) {
    return into(chatMessages).insert(message);
  }

  Future<void> replaceMessageText({
    required String messageId,
    required String text,
    required int createdAt,
  }) {
    return (update(
      chatMessages,
    )..where((message) => message.id.equals(messageId))).write(
      ChatMessagesCompanion(
        messageText: Value(text),
        createdAt: Value(createdAt),
        status: const Value('final_replaced'),
      ),
    );
  }

  Future<ChatMessage?> latestFinalUserMessage() {
    return (select(chatMessages)
          ..where(
            (message) =>
                message.role.equals('user') & message.status.like('final%'),
          )
          ..orderBy([(message) => OrderingTerm.desc(message.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> clearHistory() async {
    await transaction(() async {
      await delete(chatMessages).go();
      await delete(chatSessions).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'companion_chat.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
