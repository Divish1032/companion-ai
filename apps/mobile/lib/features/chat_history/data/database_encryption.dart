import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const _databaseKeyName = 'companion_database_key_v1';
const _sqliteHeader = 'SQLite format 3\u0000';

Future<QueryExecutor> openEncryptedCompanionDatabase(File file) async {
  const secureStorage = FlutterSecureStorage();
  var passphrase = await secureStorage.read(key: _databaseKeyName);
  if (passphrase == null || passphrase.length < 32) {
    passphrase = base64UrlEncode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    await secureStorage.write(key: _databaseKeyName, value: passphrase);
  }
  await _recoverInterruptedMigration(file);
  if (await _isPlaintextSqlite(file)) {
    await _migratePlaintextDatabase(file, passphrase);
  }
  final key = passphrase;
  return NativeDatabase.createInBackground(
    file,
    setup: (database) {
      database.execute("PRAGMA key = '${_sqlString(key)}'");
      database.execute('PRAGMA cipher_memory_security = ON');
    },
  );
}

/// Exposed only so the destructive migration path can be exercised against the
/// same SQLite3MultipleCiphers binary used by release builds.
Future<void> migratePlaintextDatabaseForTesting(File file, String passphrase) =>
    _migratePlaintextDatabase(file, passphrase);

Future<void> recoverInterruptedDatabaseMigrationForTesting(File file) =>
    _recoverInterruptedMigration(file);

Future<void> _recoverInterruptedMigration(File file) async {
  final legacy = File('${file.path}.plaintext-migration');
  if (!await legacy.exists()) return;
  // Migration runs before Drift opens the database, so a leftover legacy file
  // means the previous process died before the verified plaintext deletion.
  // Restore that complete source and retry instead of trusting a partial target.
  await _deleteIfPresent(file);
  await _deleteIfPresent(File('${file.path}-wal'));
  await _deleteIfPresent(File('${file.path}-shm'));
  await legacy.rename(file.path);
}

Future<bool> _isPlaintextSqlite(File file) async {
  if (!await file.exists() || await file.length() < 16) return false;
  final handle = await file.open();
  try {
    final header = await handle.read(16);
    return latin1.decode(header, allowInvalid: true) == _sqliteHeader;
  } finally {
    await handle.close();
  }
}

Future<void> _migratePlaintextDatabase(File file, String passphrase) async {
  final legacy = File('${file.path}.plaintext-migration');
  if (await legacy.exists()) {
    throw StateError('A previous encrypted database migration needs recovery.');
  }
  final plaintext = sqlite.sqlite3.open(file.path);
  try {
    plaintext.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  } finally {
    plaintext.close();
  }
  await file.rename(legacy.path);
  await _deleteIfPresent(File('${file.path}-wal'));
  await _deleteIfPresent(File('${file.path}-shm'));

  sqlite.Database? encrypted;
  try {
    encrypted = sqlite.sqlite3.open(file.path);
    encrypted.execute("PRAGMA key = '${_sqlString(passphrase)}'");
    encrypted.execute('PRAGMA cipher_memory_security = ON');
    encrypted.execute(
      "ATTACH DATABASE '${_sqlString(legacy.path)}' AS legacy KEY ''",
    );
    final oldVersion =
        encrypted.select('PRAGMA legacy.user_version').first.values.first
            as int;
    final tables = encrypted.select('''
      SELECT name, sql FROM legacy.sqlite_master
      WHERE type = 'table' AND sql IS NOT NULL
        AND name NOT LIKE 'sqlite_%'
        AND name NOT LIKE 'memory_records_fts%'
      ORDER BY name
    ''');
    encrypted.execute('BEGIN IMMEDIATE');
    try {
      for (final table in tables) {
        final name = table['name']! as String;
        encrypted.execute(table['sql']! as String);
        encrypted.execute(
          'INSERT INTO main.${_sqlIdentifier(name)} '
          'SELECT * FROM legacy.${_sqlIdentifier(name)}',
        );
      }
      final secondarySchema = encrypted.select('''
        SELECT name, sql FROM legacy.sqlite_master
        WHERE type IN ('index', 'trigger', 'view') AND sql IS NOT NULL
          AND name NOT LIKE 'memory_records_fts%'
        ORDER BY type, name
      ''');
      for (final item in secondarySchema) {
        encrypted.execute(item['sql']! as String);
      }
      encrypted.execute('PRAGMA user_version = $oldVersion');
      encrypted.execute('COMMIT');
    } catch (_) {
      encrypted.execute('ROLLBACK');
      rethrow;
    }
    encrypted.execute('DETACH DATABASE legacy');
    final integrity = encrypted
        .select('PRAGMA integrity_check')
        .first
        .values
        .first;
    if (integrity != 'ok') {
      throw StateError('Encrypted SQLite integrity check failed.');
    }
    encrypted.close();
    encrypted = null;
    await legacy.delete();
  } catch (_) {
    encrypted?.close();
    await _deleteIfPresent(file);
    if (await legacy.exists()) await legacy.rename(file.path);
    rethrow;
  }
}

String _sqlIdentifier(String value) => '"${value.replaceAll('"', '""')}"';

String _sqlString(String value) => value.replaceAll("'", "''");

Future<void> _deleteIfPresent(File file) async {
  if (await file.exists()) await file.delete();
}
