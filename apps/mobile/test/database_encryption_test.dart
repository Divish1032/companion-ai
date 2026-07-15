import 'dart:io';

import 'package:companion_mobile/features/chat_history/data/database_encryption.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'plaintext SQLite migrates to encrypted SQLite without losing rows',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'companion-encryption-test',
      );
      final file = File('${directory.path}/companion.sqlite');
      const key = 'test-only-32-byte-database-key-123456789';
      final plaintext = sqlite3.open(file.path);
      plaintext.execute(
        'CREATE TABLE notes (id TEXT PRIMARY KEY, body TEXT NOT NULL)',
      );
      plaintext.execute('INSERT INTO notes VALUES (?, ?)', [
        'n1',
        'private memory',
      ]);
      plaintext.userVersion = 4;
      plaintext.close();

      await migratePlaintextDatabaseForTesting(file, key);

      final header = await file
          .openRead(0, 16)
          .fold<List<int>>([], (all, bytes) => all..addAll(bytes));
      expect(String.fromCharCodes(header), isNot('SQLite format 3\u0000'));
      final encrypted = sqlite3.open(file.path);
      encrypted.execute("PRAGMA key = '$key'");
      expect(
        encrypted.select('SELECT body FROM notes').single['body'],
        'private memory',
      );
      expect(encrypted.userVersion, 4);
      expect(
        encrypted.select('PRAGMA integrity_check').single.values.single,
        'ok',
      );
      encrypted.close();
      await directory.delete(recursive: true);
    },
  );

  test(
    'interrupted migration restores the complete plaintext source',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'companion-encryption-recovery-test',
      );
      final file = File('${directory.path}/companion.sqlite');
      final legacy = File('${file.path}.plaintext-migration');
      await file.writeAsBytes([1, 2, 3, 4]);
      final plaintext = sqlite3.open(legacy.path);
      plaintext.execute('CREATE TABLE notes (body TEXT NOT NULL)');
      plaintext.execute("INSERT INTO notes VALUES ('complete source')");
      plaintext.close();

      await recoverInterruptedDatabaseMigrationForTesting(file);

      expect(await legacy.exists(), isFalse);
      final restored = sqlite3.open(file.path);
      expect(
        restored.select('SELECT body FROM notes').single['body'],
        'complete source',
      );
      restored.close();
      await directory.delete(recursive: true);
    },
  );
}
