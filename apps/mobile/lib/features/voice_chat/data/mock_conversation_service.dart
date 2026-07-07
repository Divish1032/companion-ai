import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../chat_history/data/app_database.dart';

class MockConversationService {
  MockConversationService(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  static const _language = 'hi-IN';
  static const _userTurns = [
    'Aaj mood thoda off hai.',
    'Mujhe bas kisi se baat karni thi.',
    'Kal ka din better kaise banaun?',
  ];
  static const _aiTurns = [
    'Main yahin hoon. Chalo ek chhota sa step sochte hain.',
    'Samajh raha hoon. Thoda sa saans lete hain, phir baat karte hain.',
    'Kal ke liye ek simple plan banate hain, bina pressure ke.',
  ];

  Future<String> startSession() async {
    final sessionId = 'session_${_uuid.v4()}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.upsertSession(
      ChatSessionsCompanion.insert(
        id: sessionId,
        startedAt: now,
        language: _language,
      ),
    );
    await _insertMessage(
      sessionId: sessionId,
      role: 'assistant',
      text: 'Namaste. Main sun raha hoon. Jab ready ho, mic dabao.',
      status: 'final',
      createdAt: now,
    );
    return sessionId;
  }

  Future<void> addMockExchange(String sessionId) async {
    final messages = await _database.readMessages();
    final userTurnIndex =
        messages.where((message) => message.role == 'user').length %
        _userTurns.length;
    final now = DateTime.now().millisecondsSinceEpoch;
    final turnId = 'turn_${_uuid.v4()}';

    await _insertMessage(
      sessionId: sessionId,
      turnId: turnId,
      role: 'user',
      text: _userTurns[userTurnIndex],
      status: 'final',
      createdAt: now,
    );
    await _insertMessage(
      sessionId: sessionId,
      turnId: turnId,
      role: 'assistant',
      text: _aiTurns[userTurnIndex],
      status: 'final',
      createdAt: now + 1,
      latencyJson: '{"mode":"mock"}',
    );
  }

  Future<void> replaceLatestUserTurn() async {
    final latest = await _database.latestFinalUserMessage();
    if (latest == null) {
      return;
    }

    await _database.replaceMessageText(
      messageId: latest.id,
      text: '${latest.messageText} (re-spoken clearly)',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _insertMessage({
    required String sessionId,
    required String role,
    required String text,
    required String status,
    required int createdAt,
    String? turnId,
    String? latencyJson,
  }) {
    return _database.addMessage(
      ChatMessagesCompanion.insert(
        id: 'msg_${_uuid.v4()}',
        sessionId: sessionId,
        turnId: turnId ?? 'turn_${_uuid.v4()}',
        role: role,
        messageText: text,
        status: status,
        language: _language,
        createdAt: createdAt,
        latencyJson: Value(latencyJson),
      ),
    );
  }
}
