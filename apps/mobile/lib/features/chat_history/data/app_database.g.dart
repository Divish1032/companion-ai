// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ChatSessionsTable extends ChatSessions
    with TableInfo<$ChatSessionsTable, ChatSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<int> endedAt = GeneratedColumn<int>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, startedAt, endedAt, language];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    } else if (isInserting) {
      context.missing(_languageMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
    );
  }

  @override
  $ChatSessionsTable createAlias(String alias) {
    return $ChatSessionsTable(attachedDatabase, alias);
  }
}

class ChatSession extends DataClass implements Insertable<ChatSession> {
  final String id;
  final int startedAt;
  final int? endedAt;
  final String language;
  const ChatSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.language,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<int>(endedAt);
    }
    map['language'] = Variable<String>(language);
    return map;
  }

  ChatSessionsCompanion toCompanion(bool nullToAbsent) {
    return ChatSessionsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      language: Value(language),
    );
  }

  factory ChatSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatSession(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      endedAt: serializer.fromJson<int?>(json['endedAt']),
      language: serializer.fromJson<String>(json['language']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<int>(startedAt),
      'endedAt': serializer.toJson<int?>(endedAt),
      'language': serializer.toJson<String>(language),
    };
  }

  ChatSession copyWith({
    String? id,
    int? startedAt,
    Value<int?> endedAt = const Value.absent(),
    String? language,
  }) => ChatSession(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    language: language ?? this.language,
  );
  ChatSession copyWithCompanion(ChatSessionsCompanion data) {
    return ChatSession(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      language: data.language.present ? data.language.value : this.language,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatSession(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('language: $language')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, startedAt, endedAt, language);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatSession &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.language == this.language);
}

class ChatSessionsCompanion extends UpdateCompanion<ChatSession> {
  final Value<String> id;
  final Value<int> startedAt;
  final Value<int?> endedAt;
  final Value<String> language;
  final Value<int> rowid;
  const ChatSessionsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.language = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatSessionsCompanion.insert({
    required String id,
    required int startedAt,
    this.endedAt = const Value.absent(),
    required String language,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt),
       language = Value(language);
  static Insertable<ChatSession> custom({
    Expression<String>? id,
    Expression<int>? startedAt,
    Expression<int>? endedAt,
    Expression<String>? language,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (language != null) 'language': language,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatSessionsCompanion copyWith({
    Value<String>? id,
    Value<int>? startedAt,
    Value<int?>? endedAt,
    Value<String>? language,
    Value<int>? rowid,
  }) {
    return ChatSessionsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      language: language ?? this.language,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<int>(endedAt.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatSessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('language: $language, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatMessagesTable extends ChatMessages
    with TableInfo<$ChatMessagesTable, ChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _turnIdMeta = const VerificationMeta('turnId');
  @override
  late final GeneratedColumn<String> turnId = GeneratedColumn<String>(
    'turn_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageTextMeta = const VerificationMeta(
    'messageText',
  );
  @override
  late final GeneratedColumn<String> messageText = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latencyJsonMeta = const VerificationMeta(
    'latencyJson',
  );
  @override
  late final GeneratedColumn<String> latencyJson = GeneratedColumn<String>(
    'latency_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sttConfidenceMeta = const VerificationMeta(
    'sttConfidence',
  );
  @override
  late final GeneratedColumn<double> sttConfidence = GeneratedColumn<double>(
    'stt_confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    turnId,
    role,
    messageText,
    status,
    language,
    createdAt,
    latencyJson,
    sttConfidence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('turn_id')) {
      context.handle(
        _turnIdMeta,
        turnId.isAcceptableOrUnknown(data['turn_id']!, _turnIdMeta),
      );
    } else if (isInserting) {
      context.missing(_turnIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _messageTextMeta,
        messageText.isAcceptableOrUnknown(data['text']!, _messageTextMeta),
      );
    } else if (isInserting) {
      context.missing(_messageTextMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    } else if (isInserting) {
      context.missing(_languageMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('latency_json')) {
      context.handle(
        _latencyJsonMeta,
        latencyJson.isAcceptableOrUnknown(
          data['latency_json']!,
          _latencyJsonMeta,
        ),
      );
    }
    if (data.containsKey('stt_confidence')) {
      context.handle(
        _sttConfidenceMeta,
        sttConfidence.isAcceptableOrUnknown(
          data['stt_confidence']!,
          _sttConfidenceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      turnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turn_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      messageText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      latencyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}latency_json'],
      ),
      sttConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stt_confidence'],
      ),
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }
}

class ChatMessage extends DataClass implements Insertable<ChatMessage> {
  final String id;
  final String sessionId;
  final String turnId;
  final String role;
  final String messageText;
  final String status;
  final String language;
  final int createdAt;
  final String? latencyJson;
  final double? sttConfidence;
  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.turnId,
    required this.role,
    required this.messageText,
    required this.status,
    required this.language,
    required this.createdAt,
    this.latencyJson,
    this.sttConfidence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['turn_id'] = Variable<String>(turnId);
    map['role'] = Variable<String>(role);
    map['text'] = Variable<String>(messageText);
    map['status'] = Variable<String>(status);
    map['language'] = Variable<String>(language);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || latencyJson != null) {
      map['latency_json'] = Variable<String>(latencyJson);
    }
    if (!nullToAbsent || sttConfidence != null) {
      map['stt_confidence'] = Variable<double>(sttConfidence);
    }
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      turnId: Value(turnId),
      role: Value(role),
      messageText: Value(messageText),
      status: Value(status),
      language: Value(language),
      createdAt: Value(createdAt),
      latencyJson: latencyJson == null && nullToAbsent
          ? const Value.absent()
          : Value(latencyJson),
      sttConfidence: sttConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(sttConfidence),
    );
  }

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessage(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      turnId: serializer.fromJson<String>(json['turnId']),
      role: serializer.fromJson<String>(json['role']),
      messageText: serializer.fromJson<String>(json['messageText']),
      status: serializer.fromJson<String>(json['status']),
      language: serializer.fromJson<String>(json['language']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      latencyJson: serializer.fromJson<String?>(json['latencyJson']),
      sttConfidence: serializer.fromJson<double?>(json['sttConfidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'turnId': serializer.toJson<String>(turnId),
      'role': serializer.toJson<String>(role),
      'messageText': serializer.toJson<String>(messageText),
      'status': serializer.toJson<String>(status),
      'language': serializer.toJson<String>(language),
      'createdAt': serializer.toJson<int>(createdAt),
      'latencyJson': serializer.toJson<String?>(latencyJson),
      'sttConfidence': serializer.toJson<double?>(sttConfidence),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? sessionId,
    String? turnId,
    String? role,
    String? messageText,
    String? status,
    String? language,
    int? createdAt,
    Value<String?> latencyJson = const Value.absent(),
    Value<double?> sttConfidence = const Value.absent(),
  }) => ChatMessage(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    turnId: turnId ?? this.turnId,
    role: role ?? this.role,
    messageText: messageText ?? this.messageText,
    status: status ?? this.status,
    language: language ?? this.language,
    createdAt: createdAt ?? this.createdAt,
    latencyJson: latencyJson.present ? latencyJson.value : this.latencyJson,
    sttConfidence: sttConfidence.present
        ? sttConfidence.value
        : this.sttConfidence,
  );
  ChatMessage copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessage(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      turnId: data.turnId.present ? data.turnId.value : this.turnId,
      role: data.role.present ? data.role.value : this.role,
      messageText: data.messageText.present
          ? data.messageText.value
          : this.messageText,
      status: data.status.present ? data.status.value : this.status,
      language: data.language.present ? data.language.value : this.language,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      latencyJson: data.latencyJson.present
          ? data.latencyJson.value
          : this.latencyJson,
      sttConfidence: data.sttConfidence.present
          ? data.sttConfidence.value
          : this.sttConfidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessage(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('turnId: $turnId, ')
          ..write('role: $role, ')
          ..write('messageText: $messageText, ')
          ..write('status: $status, ')
          ..write('language: $language, ')
          ..write('createdAt: $createdAt, ')
          ..write('latencyJson: $latencyJson, ')
          ..write('sttConfidence: $sttConfidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    turnId,
    role,
    messageText,
    status,
    language,
    createdAt,
    latencyJson,
    sttConfidence,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessage &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.turnId == this.turnId &&
          other.role == this.role &&
          other.messageText == this.messageText &&
          other.status == this.status &&
          other.language == this.language &&
          other.createdAt == this.createdAt &&
          other.latencyJson == this.latencyJson &&
          other.sttConfidence == this.sttConfidence);
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessage> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> turnId;
  final Value<String> role;
  final Value<String> messageText;
  final Value<String> status;
  final Value<String> language;
  final Value<int> createdAt;
  final Value<String?> latencyJson;
  final Value<double?> sttConfidence;
  final Value<int> rowid;
  const ChatMessagesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.turnId = const Value.absent(),
    this.role = const Value.absent(),
    this.messageText = const Value.absent(),
    this.status = const Value.absent(),
    this.language = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.latencyJson = const Value.absent(),
    this.sttConfidence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    required String id,
    required String sessionId,
    required String turnId,
    required String role,
    required String messageText,
    required String status,
    required String language,
    required int createdAt,
    this.latencyJson = const Value.absent(),
    this.sttConfidence = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       turnId = Value(turnId),
       role = Value(role),
       messageText = Value(messageText),
       status = Value(status),
       language = Value(language),
       createdAt = Value(createdAt);
  static Insertable<ChatMessage> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? turnId,
    Expression<String>? role,
    Expression<String>? messageText,
    Expression<String>? status,
    Expression<String>? language,
    Expression<int>? createdAt,
    Expression<String>? latencyJson,
    Expression<double>? sttConfidence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (turnId != null) 'turn_id': turnId,
      if (role != null) 'role': role,
      if (messageText != null) 'text': messageText,
      if (status != null) 'status': status,
      if (language != null) 'language': language,
      if (createdAt != null) 'created_at': createdAt,
      if (latencyJson != null) 'latency_json': latencyJson,
      if (sttConfidence != null) 'stt_confidence': sttConfidence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? turnId,
    Value<String>? role,
    Value<String>? messageText,
    Value<String>? status,
    Value<String>? language,
    Value<int>? createdAt,
    Value<String?>? latencyJson,
    Value<double?>? sttConfidence,
    Value<int>? rowid,
  }) {
    return ChatMessagesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      turnId: turnId ?? this.turnId,
      role: role ?? this.role,
      messageText: messageText ?? this.messageText,
      status: status ?? this.status,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      latencyJson: latencyJson ?? this.latencyJson,
      sttConfidence: sttConfidence ?? this.sttConfidence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (turnId.present) {
      map['turn_id'] = Variable<String>(turnId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (messageText.present) {
      map['text'] = Variable<String>(messageText.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (latencyJson.present) {
      map['latency_json'] = Variable<String>(latencyJson.value);
    }
    if (sttConfidence.present) {
      map['stt_confidence'] = Variable<double>(sttConfidence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('turnId: $turnId, ')
          ..write('role: $role, ')
          ..write('messageText: $messageText, ')
          ..write('status: $status, ')
          ..write('language: $language, ')
          ..write('createdAt: $createdAt, ')
          ..write('latencyJson: $latencyJson, ')
          ..write('sttConfidence: $sttConfidence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryRecordsTable extends MemoryRecords
    with TableInfo<$MemoryRecordsTable, MemoryRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalTextMeta = const VerificationMeta(
    'originalText',
  );
  @override
  late final GeneratedColumn<String> originalText = GeneratedColumn<String>(
    'original_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _canonicalTextMeta = const VerificationMeta(
    'canonicalText',
  );
  @override
  late final GeneratedColumn<String> canonicalText = GeneratedColumn<String>(
    'canonical_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('hi-IN'),
  );
  static const VerificationMeta _scriptMeta = const VerificationMeta('script');
  @override
  late final GeneratedColumn<String> script = GeneratedColumn<String>(
    'script',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('mixed'),
  );
  static const VerificationMeta _sourceTurnIdsJsonMeta = const VerificationMeta(
    'sourceTurnIdsJson',
  );
  @override
  late final GeneratedColumn<String> sourceTurnIdsJson =
      GeneratedColumn<String>(
        'source_turn_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _sourceRoleMeta = const VerificationMeta(
    'sourceRole',
  );
  @override
  late final GeneratedColumn<String> sourceRole = GeneratedColumn<String>(
    'source_role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transcriptStatusMeta = const VerificationMeta(
    'transcriptStatus',
  );
  @override
  late final GeneratedColumn<String> transcriptStatus = GeneratedColumn<String>(
    'transcript_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sttConfidenceMeta = const VerificationMeta(
    'sttConfidence',
  );
  @override
  late final GeneratedColumn<double> sttConfidence = GeneratedColumn<double>(
    'stt_confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<int> lastUsedAt = GeneratedColumn<int>(
    'last_used_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptPromptedAtMeta = const VerificationMeta(
    'receiptPromptedAt',
  );
  @override
  late final GeneratedColumn<int> receiptPromptedAt = GeneratedColumn<int>(
    'receipt_prompted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceScoreMeta = const VerificationMeta(
    'confidenceScore',
  );
  @override
  late final GeneratedColumn<double> confidenceScore = GeneratedColumn<double>(
    'confidence_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importanceScoreMeta = const VerificationMeta(
    'importanceScore',
  );
  @override
  late final GeneratedColumn<double> importanceScore = GeneratedColumn<double>(
    'importance_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recurrenceCountMeta = const VerificationMeta(
    'recurrenceCount',
  );
  @override
  late final GeneratedColumn<int> recurrenceCount = GeneratedColumn<int>(
    'recurrence_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _sensitivityMeta = const VerificationMeta(
    'sensitivity',
  );
  @override
  late final GeneratedColumn<String> sensitivity = GeneratedColumn<String>(
    'sensitivity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('normal'),
  );
  static const VerificationMeta _temporalStatusMeta = const VerificationMeta(
    'temporalStatus',
  );
  @override
  late final GeneratedColumn<String> temporalStatus = GeneratedColumn<String>(
    'temporal_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('current'),
  );
  static const VerificationMeta _receiptStateMeta = const VerificationMeta(
    'receiptState',
  );
  @override
  late final GeneratedColumn<String> receiptState = GeneratedColumn<String>(
    'receipt_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('implicit'),
  );
  static const VerificationMeta _supersededByMeta = const VerificationMeta(
    'supersededBy',
  );
  @override
  late final GeneratedColumn<String> supersededBy = GeneratedColumn<String>(
    'superseded_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replacementReasonMeta = const VerificationMeta(
    'replacementReason',
  );
  @override
  late final GeneratedColumn<String> replacementReason =
      GeneratedColumn<String>(
        'replacement_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _evidenceSummaryMeta = const VerificationMeta(
    'evidenceSummary',
  );
  @override
  late final GeneratedColumn<String> evidenceSummary = GeneratedColumn<String>(
    'evidence_summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    label,
    content,
    originalText,
    canonicalText,
    language,
    script,
    sourceTurnIdsJson,
    sourceRole,
    transcriptStatus,
    sttConfidence,
    createdAt,
    updatedAt,
    lastUsedAt,
    receiptPromptedAt,
    confidenceScore,
    importanceScore,
    recurrenceCount,
    sensitivity,
    temporalStatus,
    receiptState,
    supersededBy,
    replacementReason,
    evidenceSummary,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('original_text')) {
      context.handle(
        _originalTextMeta,
        originalText.isAcceptableOrUnknown(
          data['original_text']!,
          _originalTextMeta,
        ),
      );
    }
    if (data.containsKey('canonical_text')) {
      context.handle(
        _canonicalTextMeta,
        canonicalText.isAcceptableOrUnknown(
          data['canonical_text']!,
          _canonicalTextMeta,
        ),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('script')) {
      context.handle(
        _scriptMeta,
        script.isAcceptableOrUnknown(data['script']!, _scriptMeta),
      );
    }
    if (data.containsKey('source_turn_ids_json')) {
      context.handle(
        _sourceTurnIdsJsonMeta,
        sourceTurnIdsJson.isAcceptableOrUnknown(
          data['source_turn_ids_json']!,
          _sourceTurnIdsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceTurnIdsJsonMeta);
    }
    if (data.containsKey('source_role')) {
      context.handle(
        _sourceRoleMeta,
        sourceRole.isAcceptableOrUnknown(data['source_role']!, _sourceRoleMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceRoleMeta);
    }
    if (data.containsKey('transcript_status')) {
      context.handle(
        _transcriptStatusMeta,
        transcriptStatus.isAcceptableOrUnknown(
          data['transcript_status']!,
          _transcriptStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transcriptStatusMeta);
    }
    if (data.containsKey('stt_confidence')) {
      context.handle(
        _sttConfidenceMeta,
        sttConfidence.isAcceptableOrUnknown(
          data['stt_confidence']!,
          _sttConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    }
    if (data.containsKey('receipt_prompted_at')) {
      context.handle(
        _receiptPromptedAtMeta,
        receiptPromptedAt.isAcceptableOrUnknown(
          data['receipt_prompted_at']!,
          _receiptPromptedAtMeta,
        ),
      );
    }
    if (data.containsKey('confidence_score')) {
      context.handle(
        _confidenceScoreMeta,
        confidenceScore.isAcceptableOrUnknown(
          data['confidence_score']!,
          _confidenceScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_confidenceScoreMeta);
    }
    if (data.containsKey('importance_score')) {
      context.handle(
        _importanceScoreMeta,
        importanceScore.isAcceptableOrUnknown(
          data['importance_score']!,
          _importanceScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_importanceScoreMeta);
    }
    if (data.containsKey('recurrence_count')) {
      context.handle(
        _recurrenceCountMeta,
        recurrenceCount.isAcceptableOrUnknown(
          data['recurrence_count']!,
          _recurrenceCountMeta,
        ),
      );
    }
    if (data.containsKey('sensitivity')) {
      context.handle(
        _sensitivityMeta,
        sensitivity.isAcceptableOrUnknown(
          data['sensitivity']!,
          _sensitivityMeta,
        ),
      );
    }
    if (data.containsKey('temporal_status')) {
      context.handle(
        _temporalStatusMeta,
        temporalStatus.isAcceptableOrUnknown(
          data['temporal_status']!,
          _temporalStatusMeta,
        ),
      );
    }
    if (data.containsKey('receipt_state')) {
      context.handle(
        _receiptStateMeta,
        receiptState.isAcceptableOrUnknown(
          data['receipt_state']!,
          _receiptStateMeta,
        ),
      );
    }
    if (data.containsKey('superseded_by')) {
      context.handle(
        _supersededByMeta,
        supersededBy.isAcceptableOrUnknown(
          data['superseded_by']!,
          _supersededByMeta,
        ),
      );
    }
    if (data.containsKey('replacement_reason')) {
      context.handle(
        _replacementReasonMeta,
        replacementReason.isAcceptableOrUnknown(
          data['replacement_reason']!,
          _replacementReasonMeta,
        ),
      );
    }
    if (data.containsKey('evidence_summary')) {
      context.handle(
        _evidenceSummaryMeta,
        evidenceSummary.isAcceptableOrUnknown(
          data['evidence_summary']!,
          _evidenceSummaryMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      originalText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_text'],
      )!,
      canonicalText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_text'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      script: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}script'],
      )!,
      sourceTurnIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_turn_ids_json'],
      )!,
      sourceRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_role'],
      )!,
      transcriptStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_status'],
      )!,
      sttConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stt_confidence'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_used_at'],
      ),
      receiptPromptedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}receipt_prompted_at'],
      ),
      confidenceScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence_score'],
      )!,
      importanceScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}importance_score'],
      )!,
      recurrenceCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recurrence_count'],
      )!,
      sensitivity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sensitivity'],
      )!,
      temporalStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temporal_status'],
      )!,
      receiptState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_state'],
      )!,
      supersededBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}superseded_by'],
      ),
      replacementReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replacement_reason'],
      ),
      evidenceSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_summary'],
      )!,
    );
  }

  @override
  $MemoryRecordsTable createAlias(String alias) {
    return $MemoryRecordsTable(attachedDatabase, alias);
  }
}

class MemoryRecord extends DataClass implements Insertable<MemoryRecord> {
  final String id;
  final String kind;
  final String label;
  final String content;
  final String originalText;
  final String canonicalText;
  final String language;
  final String script;
  final String sourceTurnIdsJson;
  final String sourceRole;
  final String transcriptStatus;
  final double? sttConfidence;
  final int createdAt;
  final int updatedAt;
  final int? lastUsedAt;
  final int? receiptPromptedAt;
  final double confidenceScore;
  final double importanceScore;
  final int recurrenceCount;
  final String sensitivity;
  final String temporalStatus;
  final String receiptState;
  final String? supersededBy;
  final String? replacementReason;
  final String evidenceSummary;
  const MemoryRecord({
    required this.id,
    required this.kind,
    required this.label,
    required this.content,
    required this.originalText,
    required this.canonicalText,
    required this.language,
    required this.script,
    required this.sourceTurnIdsJson,
    required this.sourceRole,
    required this.transcriptStatus,
    this.sttConfidence,
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
    this.receiptPromptedAt,
    required this.confidenceScore,
    required this.importanceScore,
    required this.recurrenceCount,
    required this.sensitivity,
    required this.temporalStatus,
    required this.receiptState,
    this.supersededBy,
    this.replacementReason,
    required this.evidenceSummary,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['label'] = Variable<String>(label);
    map['content'] = Variable<String>(content);
    map['original_text'] = Variable<String>(originalText);
    map['canonical_text'] = Variable<String>(canonicalText);
    map['language'] = Variable<String>(language);
    map['script'] = Variable<String>(script);
    map['source_turn_ids_json'] = Variable<String>(sourceTurnIdsJson);
    map['source_role'] = Variable<String>(sourceRole);
    map['transcript_status'] = Variable<String>(transcriptStatus);
    if (!nullToAbsent || sttConfidence != null) {
      map['stt_confidence'] = Variable<double>(sttConfidence);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<int>(lastUsedAt);
    }
    if (!nullToAbsent || receiptPromptedAt != null) {
      map['receipt_prompted_at'] = Variable<int>(receiptPromptedAt);
    }
    map['confidence_score'] = Variable<double>(confidenceScore);
    map['importance_score'] = Variable<double>(importanceScore);
    map['recurrence_count'] = Variable<int>(recurrenceCount);
    map['sensitivity'] = Variable<String>(sensitivity);
    map['temporal_status'] = Variable<String>(temporalStatus);
    map['receipt_state'] = Variable<String>(receiptState);
    if (!nullToAbsent || supersededBy != null) {
      map['superseded_by'] = Variable<String>(supersededBy);
    }
    if (!nullToAbsent || replacementReason != null) {
      map['replacement_reason'] = Variable<String>(replacementReason);
    }
    map['evidence_summary'] = Variable<String>(evidenceSummary);
    return map;
  }

  MemoryRecordsCompanion toCompanion(bool nullToAbsent) {
    return MemoryRecordsCompanion(
      id: Value(id),
      kind: Value(kind),
      label: Value(label),
      content: Value(content),
      originalText: Value(originalText),
      canonicalText: Value(canonicalText),
      language: Value(language),
      script: Value(script),
      sourceTurnIdsJson: Value(sourceTurnIdsJson),
      sourceRole: Value(sourceRole),
      transcriptStatus: Value(transcriptStatus),
      sttConfidence: sttConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(sttConfidence),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
      receiptPromptedAt: receiptPromptedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptPromptedAt),
      confidenceScore: Value(confidenceScore),
      importanceScore: Value(importanceScore),
      recurrenceCount: Value(recurrenceCount),
      sensitivity: Value(sensitivity),
      temporalStatus: Value(temporalStatus),
      receiptState: Value(receiptState),
      supersededBy: supersededBy == null && nullToAbsent
          ? const Value.absent()
          : Value(supersededBy),
      replacementReason: replacementReason == null && nullToAbsent
          ? const Value.absent()
          : Value(replacementReason),
      evidenceSummary: Value(evidenceSummary),
    );
  }

  factory MemoryRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryRecord(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      label: serializer.fromJson<String>(json['label']),
      content: serializer.fromJson<String>(json['content']),
      originalText: serializer.fromJson<String>(json['originalText']),
      canonicalText: serializer.fromJson<String>(json['canonicalText']),
      language: serializer.fromJson<String>(json['language']),
      script: serializer.fromJson<String>(json['script']),
      sourceTurnIdsJson: serializer.fromJson<String>(json['sourceTurnIdsJson']),
      sourceRole: serializer.fromJson<String>(json['sourceRole']),
      transcriptStatus: serializer.fromJson<String>(json['transcriptStatus']),
      sttConfidence: serializer.fromJson<double?>(json['sttConfidence']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      lastUsedAt: serializer.fromJson<int?>(json['lastUsedAt']),
      receiptPromptedAt: serializer.fromJson<int?>(json['receiptPromptedAt']),
      confidenceScore: serializer.fromJson<double>(json['confidenceScore']),
      importanceScore: serializer.fromJson<double>(json['importanceScore']),
      recurrenceCount: serializer.fromJson<int>(json['recurrenceCount']),
      sensitivity: serializer.fromJson<String>(json['sensitivity']),
      temporalStatus: serializer.fromJson<String>(json['temporalStatus']),
      receiptState: serializer.fromJson<String>(json['receiptState']),
      supersededBy: serializer.fromJson<String?>(json['supersededBy']),
      replacementReason: serializer.fromJson<String?>(
        json['replacementReason'],
      ),
      evidenceSummary: serializer.fromJson<String>(json['evidenceSummary']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'label': serializer.toJson<String>(label),
      'content': serializer.toJson<String>(content),
      'originalText': serializer.toJson<String>(originalText),
      'canonicalText': serializer.toJson<String>(canonicalText),
      'language': serializer.toJson<String>(language),
      'script': serializer.toJson<String>(script),
      'sourceTurnIdsJson': serializer.toJson<String>(sourceTurnIdsJson),
      'sourceRole': serializer.toJson<String>(sourceRole),
      'transcriptStatus': serializer.toJson<String>(transcriptStatus),
      'sttConfidence': serializer.toJson<double?>(sttConfidence),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'lastUsedAt': serializer.toJson<int?>(lastUsedAt),
      'receiptPromptedAt': serializer.toJson<int?>(receiptPromptedAt),
      'confidenceScore': serializer.toJson<double>(confidenceScore),
      'importanceScore': serializer.toJson<double>(importanceScore),
      'recurrenceCount': serializer.toJson<int>(recurrenceCount),
      'sensitivity': serializer.toJson<String>(sensitivity),
      'temporalStatus': serializer.toJson<String>(temporalStatus),
      'receiptState': serializer.toJson<String>(receiptState),
      'supersededBy': serializer.toJson<String?>(supersededBy),
      'replacementReason': serializer.toJson<String?>(replacementReason),
      'evidenceSummary': serializer.toJson<String>(evidenceSummary),
    };
  }

  MemoryRecord copyWith({
    String? id,
    String? kind,
    String? label,
    String? content,
    String? originalText,
    String? canonicalText,
    String? language,
    String? script,
    String? sourceTurnIdsJson,
    String? sourceRole,
    String? transcriptStatus,
    Value<double?> sttConfidence = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> lastUsedAt = const Value.absent(),
    Value<int?> receiptPromptedAt = const Value.absent(),
    double? confidenceScore,
    double? importanceScore,
    int? recurrenceCount,
    String? sensitivity,
    String? temporalStatus,
    String? receiptState,
    Value<String?> supersededBy = const Value.absent(),
    Value<String?> replacementReason = const Value.absent(),
    String? evidenceSummary,
  }) => MemoryRecord(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    label: label ?? this.label,
    content: content ?? this.content,
    originalText: originalText ?? this.originalText,
    canonicalText: canonicalText ?? this.canonicalText,
    language: language ?? this.language,
    script: script ?? this.script,
    sourceTurnIdsJson: sourceTurnIdsJson ?? this.sourceTurnIdsJson,
    sourceRole: sourceRole ?? this.sourceRole,
    transcriptStatus: transcriptStatus ?? this.transcriptStatus,
    sttConfidence: sttConfidence.present
        ? sttConfidence.value
        : this.sttConfidence,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
    receiptPromptedAt: receiptPromptedAt.present
        ? receiptPromptedAt.value
        : this.receiptPromptedAt,
    confidenceScore: confidenceScore ?? this.confidenceScore,
    importanceScore: importanceScore ?? this.importanceScore,
    recurrenceCount: recurrenceCount ?? this.recurrenceCount,
    sensitivity: sensitivity ?? this.sensitivity,
    temporalStatus: temporalStatus ?? this.temporalStatus,
    receiptState: receiptState ?? this.receiptState,
    supersededBy: supersededBy.present ? supersededBy.value : this.supersededBy,
    replacementReason: replacementReason.present
        ? replacementReason.value
        : this.replacementReason,
    evidenceSummary: evidenceSummary ?? this.evidenceSummary,
  );
  MemoryRecord copyWithCompanion(MemoryRecordsCompanion data) {
    return MemoryRecord(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      label: data.label.present ? data.label.value : this.label,
      content: data.content.present ? data.content.value : this.content,
      originalText: data.originalText.present
          ? data.originalText.value
          : this.originalText,
      canonicalText: data.canonicalText.present
          ? data.canonicalText.value
          : this.canonicalText,
      language: data.language.present ? data.language.value : this.language,
      script: data.script.present ? data.script.value : this.script,
      sourceTurnIdsJson: data.sourceTurnIdsJson.present
          ? data.sourceTurnIdsJson.value
          : this.sourceTurnIdsJson,
      sourceRole: data.sourceRole.present
          ? data.sourceRole.value
          : this.sourceRole,
      transcriptStatus: data.transcriptStatus.present
          ? data.transcriptStatus.value
          : this.transcriptStatus,
      sttConfidence: data.sttConfidence.present
          ? data.sttConfidence.value
          : this.sttConfidence,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
      receiptPromptedAt: data.receiptPromptedAt.present
          ? data.receiptPromptedAt.value
          : this.receiptPromptedAt,
      confidenceScore: data.confidenceScore.present
          ? data.confidenceScore.value
          : this.confidenceScore,
      importanceScore: data.importanceScore.present
          ? data.importanceScore.value
          : this.importanceScore,
      recurrenceCount: data.recurrenceCount.present
          ? data.recurrenceCount.value
          : this.recurrenceCount,
      sensitivity: data.sensitivity.present
          ? data.sensitivity.value
          : this.sensitivity,
      temporalStatus: data.temporalStatus.present
          ? data.temporalStatus.value
          : this.temporalStatus,
      receiptState: data.receiptState.present
          ? data.receiptState.value
          : this.receiptState,
      supersededBy: data.supersededBy.present
          ? data.supersededBy.value
          : this.supersededBy,
      replacementReason: data.replacementReason.present
          ? data.replacementReason.value
          : this.replacementReason,
      evidenceSummary: data.evidenceSummary.present
          ? data.evidenceSummary.value
          : this.evidenceSummary,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryRecord(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('content: $content, ')
          ..write('originalText: $originalText, ')
          ..write('canonicalText: $canonicalText, ')
          ..write('language: $language, ')
          ..write('script: $script, ')
          ..write('sourceTurnIdsJson: $sourceTurnIdsJson, ')
          ..write('sourceRole: $sourceRole, ')
          ..write('transcriptStatus: $transcriptStatus, ')
          ..write('sttConfidence: $sttConfidence, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('receiptPromptedAt: $receiptPromptedAt, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('importanceScore: $importanceScore, ')
          ..write('recurrenceCount: $recurrenceCount, ')
          ..write('sensitivity: $sensitivity, ')
          ..write('temporalStatus: $temporalStatus, ')
          ..write('receiptState: $receiptState, ')
          ..write('supersededBy: $supersededBy, ')
          ..write('replacementReason: $replacementReason, ')
          ..write('evidenceSummary: $evidenceSummary')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    kind,
    label,
    content,
    originalText,
    canonicalText,
    language,
    script,
    sourceTurnIdsJson,
    sourceRole,
    transcriptStatus,
    sttConfidence,
    createdAt,
    updatedAt,
    lastUsedAt,
    receiptPromptedAt,
    confidenceScore,
    importanceScore,
    recurrenceCount,
    sensitivity,
    temporalStatus,
    receiptState,
    supersededBy,
    replacementReason,
    evidenceSummary,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryRecord &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.label == this.label &&
          other.content == this.content &&
          other.originalText == this.originalText &&
          other.canonicalText == this.canonicalText &&
          other.language == this.language &&
          other.script == this.script &&
          other.sourceTurnIdsJson == this.sourceTurnIdsJson &&
          other.sourceRole == this.sourceRole &&
          other.transcriptStatus == this.transcriptStatus &&
          other.sttConfidence == this.sttConfidence &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastUsedAt == this.lastUsedAt &&
          other.receiptPromptedAt == this.receiptPromptedAt &&
          other.confidenceScore == this.confidenceScore &&
          other.importanceScore == this.importanceScore &&
          other.recurrenceCount == this.recurrenceCount &&
          other.sensitivity == this.sensitivity &&
          other.temporalStatus == this.temporalStatus &&
          other.receiptState == this.receiptState &&
          other.supersededBy == this.supersededBy &&
          other.replacementReason == this.replacementReason &&
          other.evidenceSummary == this.evidenceSummary);
}

class MemoryRecordsCompanion extends UpdateCompanion<MemoryRecord> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> label;
  final Value<String> content;
  final Value<String> originalText;
  final Value<String> canonicalText;
  final Value<String> language;
  final Value<String> script;
  final Value<String> sourceTurnIdsJson;
  final Value<String> sourceRole;
  final Value<String> transcriptStatus;
  final Value<double?> sttConfidence;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> lastUsedAt;
  final Value<int?> receiptPromptedAt;
  final Value<double> confidenceScore;
  final Value<double> importanceScore;
  final Value<int> recurrenceCount;
  final Value<String> sensitivity;
  final Value<String> temporalStatus;
  final Value<String> receiptState;
  final Value<String?> supersededBy;
  final Value<String?> replacementReason;
  final Value<String> evidenceSummary;
  final Value<int> rowid;
  const MemoryRecordsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.label = const Value.absent(),
    this.content = const Value.absent(),
    this.originalText = const Value.absent(),
    this.canonicalText = const Value.absent(),
    this.language = const Value.absent(),
    this.script = const Value.absent(),
    this.sourceTurnIdsJson = const Value.absent(),
    this.sourceRole = const Value.absent(),
    this.transcriptStatus = const Value.absent(),
    this.sttConfidence = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.receiptPromptedAt = const Value.absent(),
    this.confidenceScore = const Value.absent(),
    this.importanceScore = const Value.absent(),
    this.recurrenceCount = const Value.absent(),
    this.sensitivity = const Value.absent(),
    this.temporalStatus = const Value.absent(),
    this.receiptState = const Value.absent(),
    this.supersededBy = const Value.absent(),
    this.replacementReason = const Value.absent(),
    this.evidenceSummary = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryRecordsCompanion.insert({
    required String id,
    required String kind,
    required String label,
    required String content,
    this.originalText = const Value.absent(),
    this.canonicalText = const Value.absent(),
    this.language = const Value.absent(),
    this.script = const Value.absent(),
    required String sourceTurnIdsJson,
    required String sourceRole,
    required String transcriptStatus,
    this.sttConfidence = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.lastUsedAt = const Value.absent(),
    this.receiptPromptedAt = const Value.absent(),
    required double confidenceScore,
    required double importanceScore,
    this.recurrenceCount = const Value.absent(),
    this.sensitivity = const Value.absent(),
    this.temporalStatus = const Value.absent(),
    this.receiptState = const Value.absent(),
    this.supersededBy = const Value.absent(),
    this.replacementReason = const Value.absent(),
    this.evidenceSummary = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       label = Value(label),
       content = Value(content),
       sourceTurnIdsJson = Value(sourceTurnIdsJson),
       sourceRole = Value(sourceRole),
       transcriptStatus = Value(transcriptStatus),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       confidenceScore = Value(confidenceScore),
       importanceScore = Value(importanceScore);
  static Insertable<MemoryRecord> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? label,
    Expression<String>? content,
    Expression<String>? originalText,
    Expression<String>? canonicalText,
    Expression<String>? language,
    Expression<String>? script,
    Expression<String>? sourceTurnIdsJson,
    Expression<String>? sourceRole,
    Expression<String>? transcriptStatus,
    Expression<double>? sttConfidence,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? lastUsedAt,
    Expression<int>? receiptPromptedAt,
    Expression<double>? confidenceScore,
    Expression<double>? importanceScore,
    Expression<int>? recurrenceCount,
    Expression<String>? sensitivity,
    Expression<String>? temporalStatus,
    Expression<String>? receiptState,
    Expression<String>? supersededBy,
    Expression<String>? replacementReason,
    Expression<String>? evidenceSummary,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (label != null) 'label': label,
      if (content != null) 'content': content,
      if (originalText != null) 'original_text': originalText,
      if (canonicalText != null) 'canonical_text': canonicalText,
      if (language != null) 'language': language,
      if (script != null) 'script': script,
      if (sourceTurnIdsJson != null) 'source_turn_ids_json': sourceTurnIdsJson,
      if (sourceRole != null) 'source_role': sourceRole,
      if (transcriptStatus != null) 'transcript_status': transcriptStatus,
      if (sttConfidence != null) 'stt_confidence': sttConfidence,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (receiptPromptedAt != null) 'receipt_prompted_at': receiptPromptedAt,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      if (importanceScore != null) 'importance_score': importanceScore,
      if (recurrenceCount != null) 'recurrence_count': recurrenceCount,
      if (sensitivity != null) 'sensitivity': sensitivity,
      if (temporalStatus != null) 'temporal_status': temporalStatus,
      if (receiptState != null) 'receipt_state': receiptState,
      if (supersededBy != null) 'superseded_by': supersededBy,
      if (replacementReason != null) 'replacement_reason': replacementReason,
      if (evidenceSummary != null) 'evidence_summary': evidenceSummary,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? label,
    Value<String>? content,
    Value<String>? originalText,
    Value<String>? canonicalText,
    Value<String>? language,
    Value<String>? script,
    Value<String>? sourceTurnIdsJson,
    Value<String>? sourceRole,
    Value<String>? transcriptStatus,
    Value<double?>? sttConfidence,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? lastUsedAt,
    Value<int?>? receiptPromptedAt,
    Value<double>? confidenceScore,
    Value<double>? importanceScore,
    Value<int>? recurrenceCount,
    Value<String>? sensitivity,
    Value<String>? temporalStatus,
    Value<String>? receiptState,
    Value<String?>? supersededBy,
    Value<String?>? replacementReason,
    Value<String>? evidenceSummary,
    Value<int>? rowid,
  }) {
    return MemoryRecordsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      content: content ?? this.content,
      originalText: originalText ?? this.originalText,
      canonicalText: canonicalText ?? this.canonicalText,
      language: language ?? this.language,
      script: script ?? this.script,
      sourceTurnIdsJson: sourceTurnIdsJson ?? this.sourceTurnIdsJson,
      sourceRole: sourceRole ?? this.sourceRole,
      transcriptStatus: transcriptStatus ?? this.transcriptStatus,
      sttConfidence: sttConfidence ?? this.sttConfidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      receiptPromptedAt: receiptPromptedAt ?? this.receiptPromptedAt,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      importanceScore: importanceScore ?? this.importanceScore,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      sensitivity: sensitivity ?? this.sensitivity,
      temporalStatus: temporalStatus ?? this.temporalStatus,
      receiptState: receiptState ?? this.receiptState,
      supersededBy: supersededBy ?? this.supersededBy,
      replacementReason: replacementReason ?? this.replacementReason,
      evidenceSummary: evidenceSummary ?? this.evidenceSummary,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (originalText.present) {
      map['original_text'] = Variable<String>(originalText.value);
    }
    if (canonicalText.present) {
      map['canonical_text'] = Variable<String>(canonicalText.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (script.present) {
      map['script'] = Variable<String>(script.value);
    }
    if (sourceTurnIdsJson.present) {
      map['source_turn_ids_json'] = Variable<String>(sourceTurnIdsJson.value);
    }
    if (sourceRole.present) {
      map['source_role'] = Variable<String>(sourceRole.value);
    }
    if (transcriptStatus.present) {
      map['transcript_status'] = Variable<String>(transcriptStatus.value);
    }
    if (sttConfidence.present) {
      map['stt_confidence'] = Variable<double>(sttConfidence.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<int>(lastUsedAt.value);
    }
    if (receiptPromptedAt.present) {
      map['receipt_prompted_at'] = Variable<int>(receiptPromptedAt.value);
    }
    if (confidenceScore.present) {
      map['confidence_score'] = Variable<double>(confidenceScore.value);
    }
    if (importanceScore.present) {
      map['importance_score'] = Variable<double>(importanceScore.value);
    }
    if (recurrenceCount.present) {
      map['recurrence_count'] = Variable<int>(recurrenceCount.value);
    }
    if (sensitivity.present) {
      map['sensitivity'] = Variable<String>(sensitivity.value);
    }
    if (temporalStatus.present) {
      map['temporal_status'] = Variable<String>(temporalStatus.value);
    }
    if (receiptState.present) {
      map['receipt_state'] = Variable<String>(receiptState.value);
    }
    if (supersededBy.present) {
      map['superseded_by'] = Variable<String>(supersededBy.value);
    }
    if (replacementReason.present) {
      map['replacement_reason'] = Variable<String>(replacementReason.value);
    }
    if (evidenceSummary.present) {
      map['evidence_summary'] = Variable<String>(evidenceSummary.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryRecordsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('content: $content, ')
          ..write('originalText: $originalText, ')
          ..write('canonicalText: $canonicalText, ')
          ..write('language: $language, ')
          ..write('script: $script, ')
          ..write('sourceTurnIdsJson: $sourceTurnIdsJson, ')
          ..write('sourceRole: $sourceRole, ')
          ..write('transcriptStatus: $transcriptStatus, ')
          ..write('sttConfidence: $sttConfidence, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('receiptPromptedAt: $receiptPromptedAt, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('importanceScore: $importanceScore, ')
          ..write('recurrenceCount: $recurrenceCount, ')
          ..write('sensitivity: $sensitivity, ')
          ..write('temporalStatus: $temporalStatus, ')
          ..write('receiptState: $receiptState, ')
          ..write('supersededBy: $supersededBy, ')
          ..write('replacementReason: $replacementReason, ')
          ..write('evidenceSummary: $evidenceSummary, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryEntitiesTable extends MemoryEntities
    with TableInfo<$MemoryEntitiesTable, MemoryEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _canonicalNameMeta = const VerificationMeta(
    'canonicalName',
  );
  @override
  late final GeneratedColumn<String> canonicalName = GeneratedColumn<String>(
    'canonical_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aliasesJsonMeta = const VerificationMeta(
    'aliasesJson',
  );
  @override
  late final GeneratedColumn<String> aliasesJson = GeneratedColumn<String>(
    'aliases_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('hi-IN'),
  );
  static const VerificationMeta _sensitivityMeta = const VerificationMeta(
    'sensitivity',
  );
  @override
  late final GeneratedColumn<String> sensitivity = GeneratedColumn<String>(
    'sensitivity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('normal'),
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<int> firstSeenAt = GeneratedColumn<int>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<int> lastSeenAt = GeneratedColumn<int>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceScoreMeta = const VerificationMeta(
    'confidenceScore',
  );
  @override
  late final GeneratedColumn<double> confidenceScore = GeneratedColumn<double>(
    'confidence_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.7),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    canonicalName,
    aliasesJson,
    language,
    sensitivity,
    firstSeenAt,
    lastSeenAt,
    confidenceScore,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('canonical_name')) {
      context.handle(
        _canonicalNameMeta,
        canonicalName.isAcceptableOrUnknown(
          data['canonical_name']!,
          _canonicalNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalNameMeta);
    }
    if (data.containsKey('aliases_json')) {
      context.handle(
        _aliasesJsonMeta,
        aliasesJson.isAcceptableOrUnknown(
          data['aliases_json']!,
          _aliasesJsonMeta,
        ),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('sensitivity')) {
      context.handle(
        _sensitivityMeta,
        sensitivity.isAcceptableOrUnknown(
          data['sensitivity']!,
          _sensitivityMeta,
        ),
      );
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    if (data.containsKey('confidence_score')) {
      context.handle(
        _confidenceScoreMeta,
        confidenceScore.isAcceptableOrUnknown(
          data['confidence_score']!,
          _confidenceScoreMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      canonicalName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_name'],
      )!,
      aliasesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aliases_json'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      sensitivity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sensitivity'],
      )!,
      firstSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_seen_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_at'],
      )!,
      confidenceScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence_score'],
      )!,
    );
  }

  @override
  $MemoryEntitiesTable createAlias(String alias) {
    return $MemoryEntitiesTable(attachedDatabase, alias);
  }
}

class MemoryEntity extends DataClass implements Insertable<MemoryEntity> {
  final String id;
  final String kind;
  final String canonicalName;
  final String aliasesJson;
  final String language;
  final String sensitivity;
  final int firstSeenAt;
  final int lastSeenAt;
  final double confidenceScore;
  const MemoryEntity({
    required this.id,
    required this.kind,
    required this.canonicalName,
    required this.aliasesJson,
    required this.language,
    required this.sensitivity,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.confidenceScore,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['canonical_name'] = Variable<String>(canonicalName);
    map['aliases_json'] = Variable<String>(aliasesJson);
    map['language'] = Variable<String>(language);
    map['sensitivity'] = Variable<String>(sensitivity);
    map['first_seen_at'] = Variable<int>(firstSeenAt);
    map['last_seen_at'] = Variable<int>(lastSeenAt);
    map['confidence_score'] = Variable<double>(confidenceScore);
    return map;
  }

  MemoryEntitiesCompanion toCompanion(bool nullToAbsent) {
    return MemoryEntitiesCompanion(
      id: Value(id),
      kind: Value(kind),
      canonicalName: Value(canonicalName),
      aliasesJson: Value(aliasesJson),
      language: Value(language),
      sensitivity: Value(sensitivity),
      firstSeenAt: Value(firstSeenAt),
      lastSeenAt: Value(lastSeenAt),
      confidenceScore: Value(confidenceScore),
    );
  }

  factory MemoryEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryEntity(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      canonicalName: serializer.fromJson<String>(json['canonicalName']),
      aliasesJson: serializer.fromJson<String>(json['aliasesJson']),
      language: serializer.fromJson<String>(json['language']),
      sensitivity: serializer.fromJson<String>(json['sensitivity']),
      firstSeenAt: serializer.fromJson<int>(json['firstSeenAt']),
      lastSeenAt: serializer.fromJson<int>(json['lastSeenAt']),
      confidenceScore: serializer.fromJson<double>(json['confidenceScore']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'canonicalName': serializer.toJson<String>(canonicalName),
      'aliasesJson': serializer.toJson<String>(aliasesJson),
      'language': serializer.toJson<String>(language),
      'sensitivity': serializer.toJson<String>(sensitivity),
      'firstSeenAt': serializer.toJson<int>(firstSeenAt),
      'lastSeenAt': serializer.toJson<int>(lastSeenAt),
      'confidenceScore': serializer.toJson<double>(confidenceScore),
    };
  }

  MemoryEntity copyWith({
    String? id,
    String? kind,
    String? canonicalName,
    String? aliasesJson,
    String? language,
    String? sensitivity,
    int? firstSeenAt,
    int? lastSeenAt,
    double? confidenceScore,
  }) => MemoryEntity(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    canonicalName: canonicalName ?? this.canonicalName,
    aliasesJson: aliasesJson ?? this.aliasesJson,
    language: language ?? this.language,
    sensitivity: sensitivity ?? this.sensitivity,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    confidenceScore: confidenceScore ?? this.confidenceScore,
  );
  MemoryEntity copyWithCompanion(MemoryEntitiesCompanion data) {
    return MemoryEntity(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      canonicalName: data.canonicalName.present
          ? data.canonicalName.value
          : this.canonicalName,
      aliasesJson: data.aliasesJson.present
          ? data.aliasesJson.value
          : this.aliasesJson,
      language: data.language.present ? data.language.value : this.language,
      sensitivity: data.sensitivity.present
          ? data.sensitivity.value
          : this.sensitivity,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      confidenceScore: data.confidenceScore.present
          ? data.confidenceScore.value
          : this.confidenceScore,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryEntity(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('canonicalName: $canonicalName, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('language: $language, ')
          ..write('sensitivity: $sensitivity, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('confidenceScore: $confidenceScore')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    canonicalName,
    aliasesJson,
    language,
    sensitivity,
    firstSeenAt,
    lastSeenAt,
    confidenceScore,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryEntity &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.canonicalName == this.canonicalName &&
          other.aliasesJson == this.aliasesJson &&
          other.language == this.language &&
          other.sensitivity == this.sensitivity &&
          other.firstSeenAt == this.firstSeenAt &&
          other.lastSeenAt == this.lastSeenAt &&
          other.confidenceScore == this.confidenceScore);
}

class MemoryEntitiesCompanion extends UpdateCompanion<MemoryEntity> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> canonicalName;
  final Value<String> aliasesJson;
  final Value<String> language;
  final Value<String> sensitivity;
  final Value<int> firstSeenAt;
  final Value<int> lastSeenAt;
  final Value<double> confidenceScore;
  final Value<int> rowid;
  const MemoryEntitiesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.canonicalName = const Value.absent(),
    this.aliasesJson = const Value.absent(),
    this.language = const Value.absent(),
    this.sensitivity = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.confidenceScore = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryEntitiesCompanion.insert({
    required String id,
    required String kind,
    required String canonicalName,
    this.aliasesJson = const Value.absent(),
    this.language = const Value.absent(),
    this.sensitivity = const Value.absent(),
    required int firstSeenAt,
    required int lastSeenAt,
    this.confidenceScore = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       canonicalName = Value(canonicalName),
       firstSeenAt = Value(firstSeenAt),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<MemoryEntity> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? canonicalName,
    Expression<String>? aliasesJson,
    Expression<String>? language,
    Expression<String>? sensitivity,
    Expression<int>? firstSeenAt,
    Expression<int>? lastSeenAt,
    Expression<double>? confidenceScore,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (canonicalName != null) 'canonical_name': canonicalName,
      if (aliasesJson != null) 'aliases_json': aliasesJson,
      if (language != null) 'language': language,
      if (sensitivity != null) 'sensitivity': sensitivity,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryEntitiesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? canonicalName,
    Value<String>? aliasesJson,
    Value<String>? language,
    Value<String>? sensitivity,
    Value<int>? firstSeenAt,
    Value<int>? lastSeenAt,
    Value<double>? confidenceScore,
    Value<int>? rowid,
  }) {
    return MemoryEntitiesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      canonicalName: canonicalName ?? this.canonicalName,
      aliasesJson: aliasesJson ?? this.aliasesJson,
      language: language ?? this.language,
      sensitivity: sensitivity ?? this.sensitivity,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (canonicalName.present) {
      map['canonical_name'] = Variable<String>(canonicalName.value);
    }
    if (aliasesJson.present) {
      map['aliases_json'] = Variable<String>(aliasesJson.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (sensitivity.present) {
      map['sensitivity'] = Variable<String>(sensitivity.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<int>(firstSeenAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<int>(lastSeenAt.value);
    }
    if (confidenceScore.present) {
      map['confidence_score'] = Variable<double>(confidenceScore.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryEntitiesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('canonicalName: $canonicalName, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('language: $language, ')
          ..write('sensitivity: $sensitivity, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryEdgesTable extends MemoryEdges
    with TableInfo<$MemoryEdgesTable, MemoryEdge> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryEdgesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceEntityIdMeta = const VerificationMeta(
    'sourceEntityId',
  );
  @override
  late final GeneratedColumn<String> sourceEntityId = GeneratedColumn<String>(
    'source_entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relationMeta = const VerificationMeta(
    'relation',
  );
  @override
  late final GeneratedColumn<String> relation = GeneratedColumn<String>(
    'relation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetEntityIdMeta = const VerificationMeta(
    'targetEntityId',
  );
  @override
  late final GeneratedColumn<String> targetEntityId = GeneratedColumn<String>(
    'target_entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evidenceTurnIdsJsonMeta =
      const VerificationMeta('evidenceTurnIdsJson');
  @override
  late final GeneratedColumn<String> evidenceTurnIdsJson =
      GeneratedColumn<String>(
        'evidence_turn_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _confidenceScoreMeta = const VerificationMeta(
    'confidenceScore',
  );
  @override
  late final GeneratedColumn<double> confidenceScore = GeneratedColumn<double>(
    'confidence_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.7),
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<int> frequency = GeneratedColumn<int>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _polarityMeta = const VerificationMeta(
    'polarity',
  );
  @override
  late final GeneratedColumn<String> polarity = GeneratedColumn<String>(
    'polarity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('neutral'),
  );
  static const VerificationMeta _sensitivityMeta = const VerificationMeta(
    'sensitivity',
  );
  @override
  late final GeneratedColumn<String> sensitivity = GeneratedColumn<String>(
    'sensitivity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('normal'),
  );
  static const VerificationMeta _temporalStatusMeta = const VerificationMeta(
    'temporalStatus',
  );
  @override
  late final GeneratedColumn<String> temporalStatus = GeneratedColumn<String>(
    'temporal_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('current'),
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<int> firstSeenAt = GeneratedColumn<int>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<int> lastSeenAt = GeneratedColumn<int>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceEntityId,
    relation,
    targetEntityId,
    evidenceTurnIdsJson,
    confidenceScore,
    frequency,
    polarity,
    sensitivity,
    temporalStatus,
    firstSeenAt,
    lastSeenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_edges';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryEdge> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_entity_id')) {
      context.handle(
        _sourceEntityIdMeta,
        sourceEntityId.isAcceptableOrUnknown(
          data['source_entity_id']!,
          _sourceEntityIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceEntityIdMeta);
    }
    if (data.containsKey('relation')) {
      context.handle(
        _relationMeta,
        relation.isAcceptableOrUnknown(data['relation']!, _relationMeta),
      );
    } else if (isInserting) {
      context.missing(_relationMeta);
    }
    if (data.containsKey('target_entity_id')) {
      context.handle(
        _targetEntityIdMeta,
        targetEntityId.isAcceptableOrUnknown(
          data['target_entity_id']!,
          _targetEntityIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetEntityIdMeta);
    }
    if (data.containsKey('evidence_turn_ids_json')) {
      context.handle(
        _evidenceTurnIdsJsonMeta,
        evidenceTurnIdsJson.isAcceptableOrUnknown(
          data['evidence_turn_ids_json']!,
          _evidenceTurnIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('confidence_score')) {
      context.handle(
        _confidenceScoreMeta,
        confidenceScore.isAcceptableOrUnknown(
          data['confidence_score']!,
          _confidenceScoreMeta,
        ),
      );
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    }
    if (data.containsKey('polarity')) {
      context.handle(
        _polarityMeta,
        polarity.isAcceptableOrUnknown(data['polarity']!, _polarityMeta),
      );
    }
    if (data.containsKey('sensitivity')) {
      context.handle(
        _sensitivityMeta,
        sensitivity.isAcceptableOrUnknown(
          data['sensitivity']!,
          _sensitivityMeta,
        ),
      );
    }
    if (data.containsKey('temporal_status')) {
      context.handle(
        _temporalStatusMeta,
        temporalStatus.isAcceptableOrUnknown(
          data['temporal_status']!,
          _temporalStatusMeta,
        ),
      );
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryEdge map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryEdge(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceEntityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_entity_id'],
      )!,
      relation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relation'],
      )!,
      targetEntityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_entity_id'],
      )!,
      evidenceTurnIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_turn_ids_json'],
      )!,
      confidenceScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence_score'],
      )!,
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}frequency'],
      )!,
      polarity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}polarity'],
      )!,
      sensitivity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sensitivity'],
      )!,
      temporalStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temporal_status'],
      )!,
      firstSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_seen_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_at'],
      )!,
    );
  }

  @override
  $MemoryEdgesTable createAlias(String alias) {
    return $MemoryEdgesTable(attachedDatabase, alias);
  }
}

class MemoryEdge extends DataClass implements Insertable<MemoryEdge> {
  final String id;
  final String sourceEntityId;
  final String relation;
  final String targetEntityId;
  final String evidenceTurnIdsJson;
  final double confidenceScore;
  final int frequency;
  final String polarity;
  final String sensitivity;
  final String temporalStatus;
  final int firstSeenAt;
  final int lastSeenAt;
  const MemoryEdge({
    required this.id,
    required this.sourceEntityId,
    required this.relation,
    required this.targetEntityId,
    required this.evidenceTurnIdsJson,
    required this.confidenceScore,
    required this.frequency,
    required this.polarity,
    required this.sensitivity,
    required this.temporalStatus,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_entity_id'] = Variable<String>(sourceEntityId);
    map['relation'] = Variable<String>(relation);
    map['target_entity_id'] = Variable<String>(targetEntityId);
    map['evidence_turn_ids_json'] = Variable<String>(evidenceTurnIdsJson);
    map['confidence_score'] = Variable<double>(confidenceScore);
    map['frequency'] = Variable<int>(frequency);
    map['polarity'] = Variable<String>(polarity);
    map['sensitivity'] = Variable<String>(sensitivity);
    map['temporal_status'] = Variable<String>(temporalStatus);
    map['first_seen_at'] = Variable<int>(firstSeenAt);
    map['last_seen_at'] = Variable<int>(lastSeenAt);
    return map;
  }

  MemoryEdgesCompanion toCompanion(bool nullToAbsent) {
    return MemoryEdgesCompanion(
      id: Value(id),
      sourceEntityId: Value(sourceEntityId),
      relation: Value(relation),
      targetEntityId: Value(targetEntityId),
      evidenceTurnIdsJson: Value(evidenceTurnIdsJson),
      confidenceScore: Value(confidenceScore),
      frequency: Value(frequency),
      polarity: Value(polarity),
      sensitivity: Value(sensitivity),
      temporalStatus: Value(temporalStatus),
      firstSeenAt: Value(firstSeenAt),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory MemoryEdge.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryEdge(
      id: serializer.fromJson<String>(json['id']),
      sourceEntityId: serializer.fromJson<String>(json['sourceEntityId']),
      relation: serializer.fromJson<String>(json['relation']),
      targetEntityId: serializer.fromJson<String>(json['targetEntityId']),
      evidenceTurnIdsJson: serializer.fromJson<String>(
        json['evidenceTurnIdsJson'],
      ),
      confidenceScore: serializer.fromJson<double>(json['confidenceScore']),
      frequency: serializer.fromJson<int>(json['frequency']),
      polarity: serializer.fromJson<String>(json['polarity']),
      sensitivity: serializer.fromJson<String>(json['sensitivity']),
      temporalStatus: serializer.fromJson<String>(json['temporalStatus']),
      firstSeenAt: serializer.fromJson<int>(json['firstSeenAt']),
      lastSeenAt: serializer.fromJson<int>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceEntityId': serializer.toJson<String>(sourceEntityId),
      'relation': serializer.toJson<String>(relation),
      'targetEntityId': serializer.toJson<String>(targetEntityId),
      'evidenceTurnIdsJson': serializer.toJson<String>(evidenceTurnIdsJson),
      'confidenceScore': serializer.toJson<double>(confidenceScore),
      'frequency': serializer.toJson<int>(frequency),
      'polarity': serializer.toJson<String>(polarity),
      'sensitivity': serializer.toJson<String>(sensitivity),
      'temporalStatus': serializer.toJson<String>(temporalStatus),
      'firstSeenAt': serializer.toJson<int>(firstSeenAt),
      'lastSeenAt': serializer.toJson<int>(lastSeenAt),
    };
  }

  MemoryEdge copyWith({
    String? id,
    String? sourceEntityId,
    String? relation,
    String? targetEntityId,
    String? evidenceTurnIdsJson,
    double? confidenceScore,
    int? frequency,
    String? polarity,
    String? sensitivity,
    String? temporalStatus,
    int? firstSeenAt,
    int? lastSeenAt,
  }) => MemoryEdge(
    id: id ?? this.id,
    sourceEntityId: sourceEntityId ?? this.sourceEntityId,
    relation: relation ?? this.relation,
    targetEntityId: targetEntityId ?? this.targetEntityId,
    evidenceTurnIdsJson: evidenceTurnIdsJson ?? this.evidenceTurnIdsJson,
    confidenceScore: confidenceScore ?? this.confidenceScore,
    frequency: frequency ?? this.frequency,
    polarity: polarity ?? this.polarity,
    sensitivity: sensitivity ?? this.sensitivity,
    temporalStatus: temporalStatus ?? this.temporalStatus,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );
  MemoryEdge copyWithCompanion(MemoryEdgesCompanion data) {
    return MemoryEdge(
      id: data.id.present ? data.id.value : this.id,
      sourceEntityId: data.sourceEntityId.present
          ? data.sourceEntityId.value
          : this.sourceEntityId,
      relation: data.relation.present ? data.relation.value : this.relation,
      targetEntityId: data.targetEntityId.present
          ? data.targetEntityId.value
          : this.targetEntityId,
      evidenceTurnIdsJson: data.evidenceTurnIdsJson.present
          ? data.evidenceTurnIdsJson.value
          : this.evidenceTurnIdsJson,
      confidenceScore: data.confidenceScore.present
          ? data.confidenceScore.value
          : this.confidenceScore,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      polarity: data.polarity.present ? data.polarity.value : this.polarity,
      sensitivity: data.sensitivity.present
          ? data.sensitivity.value
          : this.sensitivity,
      temporalStatus: data.temporalStatus.present
          ? data.temporalStatus.value
          : this.temporalStatus,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryEdge(')
          ..write('id: $id, ')
          ..write('sourceEntityId: $sourceEntityId, ')
          ..write('relation: $relation, ')
          ..write('targetEntityId: $targetEntityId, ')
          ..write('evidenceTurnIdsJson: $evidenceTurnIdsJson, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('frequency: $frequency, ')
          ..write('polarity: $polarity, ')
          ..write('sensitivity: $sensitivity, ')
          ..write('temporalStatus: $temporalStatus, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceEntityId,
    relation,
    targetEntityId,
    evidenceTurnIdsJson,
    confidenceScore,
    frequency,
    polarity,
    sensitivity,
    temporalStatus,
    firstSeenAt,
    lastSeenAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryEdge &&
          other.id == this.id &&
          other.sourceEntityId == this.sourceEntityId &&
          other.relation == this.relation &&
          other.targetEntityId == this.targetEntityId &&
          other.evidenceTurnIdsJson == this.evidenceTurnIdsJson &&
          other.confidenceScore == this.confidenceScore &&
          other.frequency == this.frequency &&
          other.polarity == this.polarity &&
          other.sensitivity == this.sensitivity &&
          other.temporalStatus == this.temporalStatus &&
          other.firstSeenAt == this.firstSeenAt &&
          other.lastSeenAt == this.lastSeenAt);
}

class MemoryEdgesCompanion extends UpdateCompanion<MemoryEdge> {
  final Value<String> id;
  final Value<String> sourceEntityId;
  final Value<String> relation;
  final Value<String> targetEntityId;
  final Value<String> evidenceTurnIdsJson;
  final Value<double> confidenceScore;
  final Value<int> frequency;
  final Value<String> polarity;
  final Value<String> sensitivity;
  final Value<String> temporalStatus;
  final Value<int> firstSeenAt;
  final Value<int> lastSeenAt;
  final Value<int> rowid;
  const MemoryEdgesCompanion({
    this.id = const Value.absent(),
    this.sourceEntityId = const Value.absent(),
    this.relation = const Value.absent(),
    this.targetEntityId = const Value.absent(),
    this.evidenceTurnIdsJson = const Value.absent(),
    this.confidenceScore = const Value.absent(),
    this.frequency = const Value.absent(),
    this.polarity = const Value.absent(),
    this.sensitivity = const Value.absent(),
    this.temporalStatus = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryEdgesCompanion.insert({
    required String id,
    required String sourceEntityId,
    required String relation,
    required String targetEntityId,
    this.evidenceTurnIdsJson = const Value.absent(),
    this.confidenceScore = const Value.absent(),
    this.frequency = const Value.absent(),
    this.polarity = const Value.absent(),
    this.sensitivity = const Value.absent(),
    this.temporalStatus = const Value.absent(),
    required int firstSeenAt,
    required int lastSeenAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceEntityId = Value(sourceEntityId),
       relation = Value(relation),
       targetEntityId = Value(targetEntityId),
       firstSeenAt = Value(firstSeenAt),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<MemoryEdge> custom({
    Expression<String>? id,
    Expression<String>? sourceEntityId,
    Expression<String>? relation,
    Expression<String>? targetEntityId,
    Expression<String>? evidenceTurnIdsJson,
    Expression<double>? confidenceScore,
    Expression<int>? frequency,
    Expression<String>? polarity,
    Expression<String>? sensitivity,
    Expression<String>? temporalStatus,
    Expression<int>? firstSeenAt,
    Expression<int>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceEntityId != null) 'source_entity_id': sourceEntityId,
      if (relation != null) 'relation': relation,
      if (targetEntityId != null) 'target_entity_id': targetEntityId,
      if (evidenceTurnIdsJson != null)
        'evidence_turn_ids_json': evidenceTurnIdsJson,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      if (frequency != null) 'frequency': frequency,
      if (polarity != null) 'polarity': polarity,
      if (sensitivity != null) 'sensitivity': sensitivity,
      if (temporalStatus != null) 'temporal_status': temporalStatus,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryEdgesCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceEntityId,
    Value<String>? relation,
    Value<String>? targetEntityId,
    Value<String>? evidenceTurnIdsJson,
    Value<double>? confidenceScore,
    Value<int>? frequency,
    Value<String>? polarity,
    Value<String>? sensitivity,
    Value<String>? temporalStatus,
    Value<int>? firstSeenAt,
    Value<int>? lastSeenAt,
    Value<int>? rowid,
  }) {
    return MemoryEdgesCompanion(
      id: id ?? this.id,
      sourceEntityId: sourceEntityId ?? this.sourceEntityId,
      relation: relation ?? this.relation,
      targetEntityId: targetEntityId ?? this.targetEntityId,
      evidenceTurnIdsJson: evidenceTurnIdsJson ?? this.evidenceTurnIdsJson,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      frequency: frequency ?? this.frequency,
      polarity: polarity ?? this.polarity,
      sensitivity: sensitivity ?? this.sensitivity,
      temporalStatus: temporalStatus ?? this.temporalStatus,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceEntityId.present) {
      map['source_entity_id'] = Variable<String>(sourceEntityId.value);
    }
    if (relation.present) {
      map['relation'] = Variable<String>(relation.value);
    }
    if (targetEntityId.present) {
      map['target_entity_id'] = Variable<String>(targetEntityId.value);
    }
    if (evidenceTurnIdsJson.present) {
      map['evidence_turn_ids_json'] = Variable<String>(
        evidenceTurnIdsJson.value,
      );
    }
    if (confidenceScore.present) {
      map['confidence_score'] = Variable<double>(confidenceScore.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<int>(frequency.value);
    }
    if (polarity.present) {
      map['polarity'] = Variable<String>(polarity.value);
    }
    if (sensitivity.present) {
      map['sensitivity'] = Variable<String>(sensitivity.value);
    }
    if (temporalStatus.present) {
      map['temporal_status'] = Variable<String>(temporalStatus.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<int>(firstSeenAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<int>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryEdgesCompanion(')
          ..write('id: $id, ')
          ..write('sourceEntityId: $sourceEntityId, ')
          ..write('relation: $relation, ')
          ..write('targetEntityId: $targetEntityId, ')
          ..write('evidenceTurnIdsJson: $evidenceTurnIdsJson, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('frequency: $frequency, ')
          ..write('polarity: $polarity, ')
          ..write('sensitivity: $sensitivity, ')
          ..write('temporalStatus: $temporalStatus, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryContradictionsTable extends MemoryContradictions
    with TableInfo<$MemoryContradictionsTable, MemoryContradiction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryContradictionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _oldMemoryIdMeta = const VerificationMeta(
    'oldMemoryId',
  );
  @override
  late final GeneratedColumn<String> oldMemoryId = GeneratedColumn<String>(
    'old_memory_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _newMemoryIdMeta = const VerificationMeta(
    'newMemoryId',
  );
  @override
  late final GeneratedColumn<String> newMemoryId = GeneratedColumn<String>(
    'new_memory_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evidenceTurnIdsJsonMeta =
      const VerificationMeta('evidenceTurnIdsJson');
  @override
  late final GeneratedColumn<String> evidenceTurnIdsJson =
      GeneratedColumn<String>(
        'evidence_turn_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    oldMemoryId,
    newMemoryId,
    reason,
    evidenceTurnIdsJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_contradictions';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryContradiction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('old_memory_id')) {
      context.handle(
        _oldMemoryIdMeta,
        oldMemoryId.isAcceptableOrUnknown(
          data['old_memory_id']!,
          _oldMemoryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_oldMemoryIdMeta);
    }
    if (data.containsKey('new_memory_id')) {
      context.handle(
        _newMemoryIdMeta,
        newMemoryId.isAcceptableOrUnknown(
          data['new_memory_id']!,
          _newMemoryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_newMemoryIdMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('evidence_turn_ids_json')) {
      context.handle(
        _evidenceTurnIdsJsonMeta,
        evidenceTurnIdsJson.isAcceptableOrUnknown(
          data['evidence_turn_ids_json']!,
          _evidenceTurnIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryContradiction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryContradiction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      oldMemoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_memory_id'],
      )!,
      newMemoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_memory_id'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      evidenceTurnIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_turn_ids_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MemoryContradictionsTable createAlias(String alias) {
    return $MemoryContradictionsTable(attachedDatabase, alias);
  }
}

class MemoryContradiction extends DataClass
    implements Insertable<MemoryContradiction> {
  final String id;
  final String oldMemoryId;
  final String newMemoryId;
  final String reason;
  final String evidenceTurnIdsJson;
  final int createdAt;
  const MemoryContradiction({
    required this.id,
    required this.oldMemoryId,
    required this.newMemoryId,
    required this.reason,
    required this.evidenceTurnIdsJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['old_memory_id'] = Variable<String>(oldMemoryId);
    map['new_memory_id'] = Variable<String>(newMemoryId);
    map['reason'] = Variable<String>(reason);
    map['evidence_turn_ids_json'] = Variable<String>(evidenceTurnIdsJson);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  MemoryContradictionsCompanion toCompanion(bool nullToAbsent) {
    return MemoryContradictionsCompanion(
      id: Value(id),
      oldMemoryId: Value(oldMemoryId),
      newMemoryId: Value(newMemoryId),
      reason: Value(reason),
      evidenceTurnIdsJson: Value(evidenceTurnIdsJson),
      createdAt: Value(createdAt),
    );
  }

  factory MemoryContradiction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryContradiction(
      id: serializer.fromJson<String>(json['id']),
      oldMemoryId: serializer.fromJson<String>(json['oldMemoryId']),
      newMemoryId: serializer.fromJson<String>(json['newMemoryId']),
      reason: serializer.fromJson<String>(json['reason']),
      evidenceTurnIdsJson: serializer.fromJson<String>(
        json['evidenceTurnIdsJson'],
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'oldMemoryId': serializer.toJson<String>(oldMemoryId),
      'newMemoryId': serializer.toJson<String>(newMemoryId),
      'reason': serializer.toJson<String>(reason),
      'evidenceTurnIdsJson': serializer.toJson<String>(evidenceTurnIdsJson),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  MemoryContradiction copyWith({
    String? id,
    String? oldMemoryId,
    String? newMemoryId,
    String? reason,
    String? evidenceTurnIdsJson,
    int? createdAt,
  }) => MemoryContradiction(
    id: id ?? this.id,
    oldMemoryId: oldMemoryId ?? this.oldMemoryId,
    newMemoryId: newMemoryId ?? this.newMemoryId,
    reason: reason ?? this.reason,
    evidenceTurnIdsJson: evidenceTurnIdsJson ?? this.evidenceTurnIdsJson,
    createdAt: createdAt ?? this.createdAt,
  );
  MemoryContradiction copyWithCompanion(MemoryContradictionsCompanion data) {
    return MemoryContradiction(
      id: data.id.present ? data.id.value : this.id,
      oldMemoryId: data.oldMemoryId.present
          ? data.oldMemoryId.value
          : this.oldMemoryId,
      newMemoryId: data.newMemoryId.present
          ? data.newMemoryId.value
          : this.newMemoryId,
      reason: data.reason.present ? data.reason.value : this.reason,
      evidenceTurnIdsJson: data.evidenceTurnIdsJson.present
          ? data.evidenceTurnIdsJson.value
          : this.evidenceTurnIdsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryContradiction(')
          ..write('id: $id, ')
          ..write('oldMemoryId: $oldMemoryId, ')
          ..write('newMemoryId: $newMemoryId, ')
          ..write('reason: $reason, ')
          ..write('evidenceTurnIdsJson: $evidenceTurnIdsJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    oldMemoryId,
    newMemoryId,
    reason,
    evidenceTurnIdsJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryContradiction &&
          other.id == this.id &&
          other.oldMemoryId == this.oldMemoryId &&
          other.newMemoryId == this.newMemoryId &&
          other.reason == this.reason &&
          other.evidenceTurnIdsJson == this.evidenceTurnIdsJson &&
          other.createdAt == this.createdAt);
}

class MemoryContradictionsCompanion
    extends UpdateCompanion<MemoryContradiction> {
  final Value<String> id;
  final Value<String> oldMemoryId;
  final Value<String> newMemoryId;
  final Value<String> reason;
  final Value<String> evidenceTurnIdsJson;
  final Value<int> createdAt;
  final Value<int> rowid;
  const MemoryContradictionsCompanion({
    this.id = const Value.absent(),
    this.oldMemoryId = const Value.absent(),
    this.newMemoryId = const Value.absent(),
    this.reason = const Value.absent(),
    this.evidenceTurnIdsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryContradictionsCompanion.insert({
    required String id,
    required String oldMemoryId,
    required String newMemoryId,
    required String reason,
    this.evidenceTurnIdsJson = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       oldMemoryId = Value(oldMemoryId),
       newMemoryId = Value(newMemoryId),
       reason = Value(reason),
       createdAt = Value(createdAt);
  static Insertable<MemoryContradiction> custom({
    Expression<String>? id,
    Expression<String>? oldMemoryId,
    Expression<String>? newMemoryId,
    Expression<String>? reason,
    Expression<String>? evidenceTurnIdsJson,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (oldMemoryId != null) 'old_memory_id': oldMemoryId,
      if (newMemoryId != null) 'new_memory_id': newMemoryId,
      if (reason != null) 'reason': reason,
      if (evidenceTurnIdsJson != null)
        'evidence_turn_ids_json': evidenceTurnIdsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryContradictionsCompanion copyWith({
    Value<String>? id,
    Value<String>? oldMemoryId,
    Value<String>? newMemoryId,
    Value<String>? reason,
    Value<String>? evidenceTurnIdsJson,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return MemoryContradictionsCompanion(
      id: id ?? this.id,
      oldMemoryId: oldMemoryId ?? this.oldMemoryId,
      newMemoryId: newMemoryId ?? this.newMemoryId,
      reason: reason ?? this.reason,
      evidenceTurnIdsJson: evidenceTurnIdsJson ?? this.evidenceTurnIdsJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (oldMemoryId.present) {
      map['old_memory_id'] = Variable<String>(oldMemoryId.value);
    }
    if (newMemoryId.present) {
      map['new_memory_id'] = Variable<String>(newMemoryId.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (evidenceTurnIdsJson.present) {
      map['evidence_turn_ids_json'] = Variable<String>(
        evidenceTurnIdsJson.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryContradictionsCompanion(')
          ..write('id: $id, ')
          ..write('oldMemoryId: $oldMemoryId, ')
          ..write('newMemoryId: $newMemoryId, ')
          ..write('reason: $reason, ')
          ..write('evidenceTurnIdsJson: $evidenceTurnIdsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryEpisodesTable extends MemoryEpisodes
    with TableInfo<$MemoryEpisodesTable, MemoryEpisode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryEpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retrievalTextMeta = const VerificationMeta(
    'retrievalText',
  );
  @override
  late final GeneratedColumn<String> retrievalText = GeneratedColumn<String>(
    'retrieval_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTurnIdsJsonMeta = const VerificationMeta(
    'sourceTurnIdsJson',
  );
  @override
  late final GeneratedColumn<String> sourceTurnIdsJson =
      GeneratedColumn<String>(
        'source_turn_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _entityIdsJsonMeta = const VerificationMeta(
    'entityIdsJson',
  );
  @override
  late final GeneratedColumn<String> entityIdsJson = GeneratedColumn<String>(
    'entity_ids_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _topicKeysJsonMeta = const VerificationMeta(
    'topicKeysJson',
  );
  @override
  late final GeneratedColumn<String> topicKeysJson = GeneratedColumn<String>(
    'topic_keys_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _eventStartAtMeta = const VerificationMeta(
    'eventStartAt',
  );
  @override
  late final GeneratedColumn<int> eventStartAt = GeneratedColumn<int>(
    'event_start_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventEndAtMeta = const VerificationMeta(
    'eventEndAt',
  );
  @override
  late final GeneratedColumn<int> eventEndAt = GeneratedColumn<int>(
    'event_end_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _temporalStatusMeta = const VerificationMeta(
    'temporalStatus',
  );
  @override
  late final GeneratedColumn<String> temporalStatus = GeneratedColumn<String>(
    'temporal_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('past'),
  );
  static const VerificationMeta _explicitnessMeta = const VerificationMeta(
    'explicitness',
  );
  @override
  late final GeneratedColumn<String> explicitness = GeneratedColumn<String>(
    'explicitness',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('explicit'),
  );
  static const VerificationMeta _confidenceScoreMeta = const VerificationMeta(
    'confidenceScore',
  );
  @override
  late final GeneratedColumn<double> confidenceScore = GeneratedColumn<double>(
    'confidence_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importanceScoreMeta = const VerificationMeta(
    'importanceScore',
  );
  @override
  late final GeneratedColumn<double> importanceScore = GeneratedColumn<double>(
    'importance_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sensitivityMeta = const VerificationMeta(
    'sensitivity',
  );
  @override
  late final GeneratedColumn<String> sensitivity = GeneratedColumn<String>(
    'sensitivity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('normal'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    title,
    summary,
    retrievalText,
    sourceTurnIdsJson,
    entityIdsJson,
    topicKeysJson,
    eventStartAt,
    eventEndAt,
    temporalStatus,
    explicitness,
    confidenceScore,
    importanceScore,
    sensitivity,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryEpisode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('retrieval_text')) {
      context.handle(
        _retrievalTextMeta,
        retrievalText.isAcceptableOrUnknown(
          data['retrieval_text']!,
          _retrievalTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_retrievalTextMeta);
    }
    if (data.containsKey('source_turn_ids_json')) {
      context.handle(
        _sourceTurnIdsJsonMeta,
        sourceTurnIdsJson.isAcceptableOrUnknown(
          data['source_turn_ids_json']!,
          _sourceTurnIdsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceTurnIdsJsonMeta);
    }
    if (data.containsKey('entity_ids_json')) {
      context.handle(
        _entityIdsJsonMeta,
        entityIdsJson.isAcceptableOrUnknown(
          data['entity_ids_json']!,
          _entityIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('topic_keys_json')) {
      context.handle(
        _topicKeysJsonMeta,
        topicKeysJson.isAcceptableOrUnknown(
          data['topic_keys_json']!,
          _topicKeysJsonMeta,
        ),
      );
    }
    if (data.containsKey('event_start_at')) {
      context.handle(
        _eventStartAtMeta,
        eventStartAt.isAcceptableOrUnknown(
          data['event_start_at']!,
          _eventStartAtMeta,
        ),
      );
    }
    if (data.containsKey('event_end_at')) {
      context.handle(
        _eventEndAtMeta,
        eventEndAt.isAcceptableOrUnknown(
          data['event_end_at']!,
          _eventEndAtMeta,
        ),
      );
    }
    if (data.containsKey('temporal_status')) {
      context.handle(
        _temporalStatusMeta,
        temporalStatus.isAcceptableOrUnknown(
          data['temporal_status']!,
          _temporalStatusMeta,
        ),
      );
    }
    if (data.containsKey('explicitness')) {
      context.handle(
        _explicitnessMeta,
        explicitness.isAcceptableOrUnknown(
          data['explicitness']!,
          _explicitnessMeta,
        ),
      );
    }
    if (data.containsKey('confidence_score')) {
      context.handle(
        _confidenceScoreMeta,
        confidenceScore.isAcceptableOrUnknown(
          data['confidence_score']!,
          _confidenceScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_confidenceScoreMeta);
    }
    if (data.containsKey('importance_score')) {
      context.handle(
        _importanceScoreMeta,
        importanceScore.isAcceptableOrUnknown(
          data['importance_score']!,
          _importanceScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_importanceScoreMeta);
    }
    if (data.containsKey('sensitivity')) {
      context.handle(
        _sensitivityMeta,
        sensitivity.isAcceptableOrUnknown(
          data['sensitivity']!,
          _sensitivityMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryEpisode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryEpisode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      retrievalText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}retrieval_text'],
      )!,
      sourceTurnIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_turn_ids_json'],
      )!,
      entityIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_ids_json'],
      )!,
      topicKeysJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_keys_json'],
      )!,
      eventStartAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_start_at'],
      ),
      eventEndAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_end_at'],
      ),
      temporalStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temporal_status'],
      )!,
      explicitness: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explicitness'],
      )!,
      confidenceScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence_score'],
      )!,
      importanceScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}importance_score'],
      )!,
      sensitivity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sensitivity'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MemoryEpisodesTable createAlias(String alias) {
    return $MemoryEpisodesTable(attachedDatabase, alias);
  }
}

class MemoryEpisode extends DataClass implements Insertable<MemoryEpisode> {
  final String id;
  final String sessionId;
  final String title;
  final String summary;
  final String retrievalText;
  final String sourceTurnIdsJson;
  final String entityIdsJson;
  final String topicKeysJson;
  final int? eventStartAt;
  final int? eventEndAt;
  final String temporalStatus;
  final String explicitness;
  final double confidenceScore;
  final double importanceScore;
  final String sensitivity;
  final int createdAt;
  final int updatedAt;
  const MemoryEpisode({
    required this.id,
    required this.sessionId,
    required this.title,
    required this.summary,
    required this.retrievalText,
    required this.sourceTurnIdsJson,
    required this.entityIdsJson,
    required this.topicKeysJson,
    this.eventStartAt,
    this.eventEndAt,
    required this.temporalStatus,
    required this.explicitness,
    required this.confidenceScore,
    required this.importanceScore,
    required this.sensitivity,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['title'] = Variable<String>(title);
    map['summary'] = Variable<String>(summary);
    map['retrieval_text'] = Variable<String>(retrievalText);
    map['source_turn_ids_json'] = Variable<String>(sourceTurnIdsJson);
    map['entity_ids_json'] = Variable<String>(entityIdsJson);
    map['topic_keys_json'] = Variable<String>(topicKeysJson);
    if (!nullToAbsent || eventStartAt != null) {
      map['event_start_at'] = Variable<int>(eventStartAt);
    }
    if (!nullToAbsent || eventEndAt != null) {
      map['event_end_at'] = Variable<int>(eventEndAt);
    }
    map['temporal_status'] = Variable<String>(temporalStatus);
    map['explicitness'] = Variable<String>(explicitness);
    map['confidence_score'] = Variable<double>(confidenceScore);
    map['importance_score'] = Variable<double>(importanceScore);
    map['sensitivity'] = Variable<String>(sensitivity);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MemoryEpisodesCompanion toCompanion(bool nullToAbsent) {
    return MemoryEpisodesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      title: Value(title),
      summary: Value(summary),
      retrievalText: Value(retrievalText),
      sourceTurnIdsJson: Value(sourceTurnIdsJson),
      entityIdsJson: Value(entityIdsJson),
      topicKeysJson: Value(topicKeysJson),
      eventStartAt: eventStartAt == null && nullToAbsent
          ? const Value.absent()
          : Value(eventStartAt),
      eventEndAt: eventEndAt == null && nullToAbsent
          ? const Value.absent()
          : Value(eventEndAt),
      temporalStatus: Value(temporalStatus),
      explicitness: Value(explicitness),
      confidenceScore: Value(confidenceScore),
      importanceScore: Value(importanceScore),
      sensitivity: Value(sensitivity),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MemoryEpisode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryEpisode(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      title: serializer.fromJson<String>(json['title']),
      summary: serializer.fromJson<String>(json['summary']),
      retrievalText: serializer.fromJson<String>(json['retrievalText']),
      sourceTurnIdsJson: serializer.fromJson<String>(json['sourceTurnIdsJson']),
      entityIdsJson: serializer.fromJson<String>(json['entityIdsJson']),
      topicKeysJson: serializer.fromJson<String>(json['topicKeysJson']),
      eventStartAt: serializer.fromJson<int?>(json['eventStartAt']),
      eventEndAt: serializer.fromJson<int?>(json['eventEndAt']),
      temporalStatus: serializer.fromJson<String>(json['temporalStatus']),
      explicitness: serializer.fromJson<String>(json['explicitness']),
      confidenceScore: serializer.fromJson<double>(json['confidenceScore']),
      importanceScore: serializer.fromJson<double>(json['importanceScore']),
      sensitivity: serializer.fromJson<String>(json['sensitivity']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'title': serializer.toJson<String>(title),
      'summary': serializer.toJson<String>(summary),
      'retrievalText': serializer.toJson<String>(retrievalText),
      'sourceTurnIdsJson': serializer.toJson<String>(sourceTurnIdsJson),
      'entityIdsJson': serializer.toJson<String>(entityIdsJson),
      'topicKeysJson': serializer.toJson<String>(topicKeysJson),
      'eventStartAt': serializer.toJson<int?>(eventStartAt),
      'eventEndAt': serializer.toJson<int?>(eventEndAt),
      'temporalStatus': serializer.toJson<String>(temporalStatus),
      'explicitness': serializer.toJson<String>(explicitness),
      'confidenceScore': serializer.toJson<double>(confidenceScore),
      'importanceScore': serializer.toJson<double>(importanceScore),
      'sensitivity': serializer.toJson<String>(sensitivity),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  MemoryEpisode copyWith({
    String? id,
    String? sessionId,
    String? title,
    String? summary,
    String? retrievalText,
    String? sourceTurnIdsJson,
    String? entityIdsJson,
    String? topicKeysJson,
    Value<int?> eventStartAt = const Value.absent(),
    Value<int?> eventEndAt = const Value.absent(),
    String? temporalStatus,
    String? explicitness,
    double? confidenceScore,
    double? importanceScore,
    String? sensitivity,
    int? createdAt,
    int? updatedAt,
  }) => MemoryEpisode(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    retrievalText: retrievalText ?? this.retrievalText,
    sourceTurnIdsJson: sourceTurnIdsJson ?? this.sourceTurnIdsJson,
    entityIdsJson: entityIdsJson ?? this.entityIdsJson,
    topicKeysJson: topicKeysJson ?? this.topicKeysJson,
    eventStartAt: eventStartAt.present ? eventStartAt.value : this.eventStartAt,
    eventEndAt: eventEndAt.present ? eventEndAt.value : this.eventEndAt,
    temporalStatus: temporalStatus ?? this.temporalStatus,
    explicitness: explicitness ?? this.explicitness,
    confidenceScore: confidenceScore ?? this.confidenceScore,
    importanceScore: importanceScore ?? this.importanceScore,
    sensitivity: sensitivity ?? this.sensitivity,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MemoryEpisode copyWithCompanion(MemoryEpisodesCompanion data) {
    return MemoryEpisode(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      title: data.title.present ? data.title.value : this.title,
      summary: data.summary.present ? data.summary.value : this.summary,
      retrievalText: data.retrievalText.present
          ? data.retrievalText.value
          : this.retrievalText,
      sourceTurnIdsJson: data.sourceTurnIdsJson.present
          ? data.sourceTurnIdsJson.value
          : this.sourceTurnIdsJson,
      entityIdsJson: data.entityIdsJson.present
          ? data.entityIdsJson.value
          : this.entityIdsJson,
      topicKeysJson: data.topicKeysJson.present
          ? data.topicKeysJson.value
          : this.topicKeysJson,
      eventStartAt: data.eventStartAt.present
          ? data.eventStartAt.value
          : this.eventStartAt,
      eventEndAt: data.eventEndAt.present
          ? data.eventEndAt.value
          : this.eventEndAt,
      temporalStatus: data.temporalStatus.present
          ? data.temporalStatus.value
          : this.temporalStatus,
      explicitness: data.explicitness.present
          ? data.explicitness.value
          : this.explicitness,
      confidenceScore: data.confidenceScore.present
          ? data.confidenceScore.value
          : this.confidenceScore,
      importanceScore: data.importanceScore.present
          ? data.importanceScore.value
          : this.importanceScore,
      sensitivity: data.sensitivity.present
          ? data.sensitivity.value
          : this.sensitivity,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryEpisode(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('retrievalText: $retrievalText, ')
          ..write('sourceTurnIdsJson: $sourceTurnIdsJson, ')
          ..write('entityIdsJson: $entityIdsJson, ')
          ..write('topicKeysJson: $topicKeysJson, ')
          ..write('eventStartAt: $eventStartAt, ')
          ..write('eventEndAt: $eventEndAt, ')
          ..write('temporalStatus: $temporalStatus, ')
          ..write('explicitness: $explicitness, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('importanceScore: $importanceScore, ')
          ..write('sensitivity: $sensitivity, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    title,
    summary,
    retrievalText,
    sourceTurnIdsJson,
    entityIdsJson,
    topicKeysJson,
    eventStartAt,
    eventEndAt,
    temporalStatus,
    explicitness,
    confidenceScore,
    importanceScore,
    sensitivity,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryEpisode &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.title == this.title &&
          other.summary == this.summary &&
          other.retrievalText == this.retrievalText &&
          other.sourceTurnIdsJson == this.sourceTurnIdsJson &&
          other.entityIdsJson == this.entityIdsJson &&
          other.topicKeysJson == this.topicKeysJson &&
          other.eventStartAt == this.eventStartAt &&
          other.eventEndAt == this.eventEndAt &&
          other.temporalStatus == this.temporalStatus &&
          other.explicitness == this.explicitness &&
          other.confidenceScore == this.confidenceScore &&
          other.importanceScore == this.importanceScore &&
          other.sensitivity == this.sensitivity &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MemoryEpisodesCompanion extends UpdateCompanion<MemoryEpisode> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> title;
  final Value<String> summary;
  final Value<String> retrievalText;
  final Value<String> sourceTurnIdsJson;
  final Value<String> entityIdsJson;
  final Value<String> topicKeysJson;
  final Value<int?> eventStartAt;
  final Value<int?> eventEndAt;
  final Value<String> temporalStatus;
  final Value<String> explicitness;
  final Value<double> confidenceScore;
  final Value<double> importanceScore;
  final Value<String> sensitivity;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const MemoryEpisodesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.retrievalText = const Value.absent(),
    this.sourceTurnIdsJson = const Value.absent(),
    this.entityIdsJson = const Value.absent(),
    this.topicKeysJson = const Value.absent(),
    this.eventStartAt = const Value.absent(),
    this.eventEndAt = const Value.absent(),
    this.temporalStatus = const Value.absent(),
    this.explicitness = const Value.absent(),
    this.confidenceScore = const Value.absent(),
    this.importanceScore = const Value.absent(),
    this.sensitivity = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryEpisodesCompanion.insert({
    required String id,
    required String sessionId,
    required String title,
    required String summary,
    required String retrievalText,
    required String sourceTurnIdsJson,
    this.entityIdsJson = const Value.absent(),
    this.topicKeysJson = const Value.absent(),
    this.eventStartAt = const Value.absent(),
    this.eventEndAt = const Value.absent(),
    this.temporalStatus = const Value.absent(),
    this.explicitness = const Value.absent(),
    required double confidenceScore,
    required double importanceScore,
    this.sensitivity = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       title = Value(title),
       summary = Value(summary),
       retrievalText = Value(retrievalText),
       sourceTurnIdsJson = Value(sourceTurnIdsJson),
       confidenceScore = Value(confidenceScore),
       importanceScore = Value(importanceScore),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MemoryEpisode> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? title,
    Expression<String>? summary,
    Expression<String>? retrievalText,
    Expression<String>? sourceTurnIdsJson,
    Expression<String>? entityIdsJson,
    Expression<String>? topicKeysJson,
    Expression<int>? eventStartAt,
    Expression<int>? eventEndAt,
    Expression<String>? temporalStatus,
    Expression<String>? explicitness,
    Expression<double>? confidenceScore,
    Expression<double>? importanceScore,
    Expression<String>? sensitivity,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (retrievalText != null) 'retrieval_text': retrievalText,
      if (sourceTurnIdsJson != null) 'source_turn_ids_json': sourceTurnIdsJson,
      if (entityIdsJson != null) 'entity_ids_json': entityIdsJson,
      if (topicKeysJson != null) 'topic_keys_json': topicKeysJson,
      if (eventStartAt != null) 'event_start_at': eventStartAt,
      if (eventEndAt != null) 'event_end_at': eventEndAt,
      if (temporalStatus != null) 'temporal_status': temporalStatus,
      if (explicitness != null) 'explicitness': explicitness,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      if (importanceScore != null) 'importance_score': importanceScore,
      if (sensitivity != null) 'sensitivity': sensitivity,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryEpisodesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? title,
    Value<String>? summary,
    Value<String>? retrievalText,
    Value<String>? sourceTurnIdsJson,
    Value<String>? entityIdsJson,
    Value<String>? topicKeysJson,
    Value<int?>? eventStartAt,
    Value<int?>? eventEndAt,
    Value<String>? temporalStatus,
    Value<String>? explicitness,
    Value<double>? confidenceScore,
    Value<double>? importanceScore,
    Value<String>? sensitivity,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return MemoryEpisodesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      retrievalText: retrievalText ?? this.retrievalText,
      sourceTurnIdsJson: sourceTurnIdsJson ?? this.sourceTurnIdsJson,
      entityIdsJson: entityIdsJson ?? this.entityIdsJson,
      topicKeysJson: topicKeysJson ?? this.topicKeysJson,
      eventStartAt: eventStartAt ?? this.eventStartAt,
      eventEndAt: eventEndAt ?? this.eventEndAt,
      temporalStatus: temporalStatus ?? this.temporalStatus,
      explicitness: explicitness ?? this.explicitness,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      importanceScore: importanceScore ?? this.importanceScore,
      sensitivity: sensitivity ?? this.sensitivity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (retrievalText.present) {
      map['retrieval_text'] = Variable<String>(retrievalText.value);
    }
    if (sourceTurnIdsJson.present) {
      map['source_turn_ids_json'] = Variable<String>(sourceTurnIdsJson.value);
    }
    if (entityIdsJson.present) {
      map['entity_ids_json'] = Variable<String>(entityIdsJson.value);
    }
    if (topicKeysJson.present) {
      map['topic_keys_json'] = Variable<String>(topicKeysJson.value);
    }
    if (eventStartAt.present) {
      map['event_start_at'] = Variable<int>(eventStartAt.value);
    }
    if (eventEndAt.present) {
      map['event_end_at'] = Variable<int>(eventEndAt.value);
    }
    if (temporalStatus.present) {
      map['temporal_status'] = Variable<String>(temporalStatus.value);
    }
    if (explicitness.present) {
      map['explicitness'] = Variable<String>(explicitness.value);
    }
    if (confidenceScore.present) {
      map['confidence_score'] = Variable<double>(confidenceScore.value);
    }
    if (importanceScore.present) {
      map['importance_score'] = Variable<double>(importanceScore.value);
    }
    if (sensitivity.present) {
      map['sensitivity'] = Variable<String>(sensitivity.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryEpisodesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('retrievalText: $retrievalText, ')
          ..write('sourceTurnIdsJson: $sourceTurnIdsJson, ')
          ..write('entityIdsJson: $entityIdsJson, ')
          ..write('topicKeysJson: $topicKeysJson, ')
          ..write('eventStartAt: $eventStartAt, ')
          ..write('eventEndAt: $eventEndAt, ')
          ..write('temporalStatus: $temporalStatus, ')
          ..write('explicitness: $explicitness, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('importanceScore: $importanceScore, ')
          ..write('sensitivity: $sensitivity, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryOpenThreadsTable extends MemoryOpenThreads
    with TableInfo<$MemoryOpenThreadsTable, MemoryOpenThread> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryOpenThreadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<String> episodeId = GeneratedColumn<String>(
    'episode_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _predicateMeta = const VerificationMeta(
    'predicate',
  );
  @override
  late final GeneratedColumn<String> predicate = GeneratedColumn<String>(
    'predicate',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _objectTextMeta = const VerificationMeta(
    'objectText',
  );
  @override
  late final GeneratedColumn<String> objectText = GeneratedColumn<String>(
    'object_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueStartAtMeta = const VerificationMeta(
    'dueStartAt',
  );
  @override
  late final GeneratedColumn<int> dueStartAt = GeneratedColumn<int>(
    'due_start_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueEndAtMeta = const VerificationMeta(
    'dueEndAt',
  );
  @override
  late final GeneratedColumn<int> dueEndAt = GeneratedColumn<int>(
    'due_end_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('open'),
  );
  static const VerificationMeta _followUpAllowedMeta = const VerificationMeta(
    'followUpAllowed',
  );
  @override
  late final GeneratedColumn<bool> followUpAllowed = GeneratedColumn<bool>(
    'follow_up_allowed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("follow_up_allowed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _proactiveAllowedMeta = const VerificationMeta(
    'proactiveAllowed',
  );
  @override
  late final GeneratedColumn<bool> proactiveAllowed = GeneratedColumn<bool>(
    'proactive_allowed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("proactive_allowed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceTurnIdsJsonMeta = const VerificationMeta(
    'sourceTurnIdsJson',
  );
  @override
  late final GeneratedColumn<String> sourceTurnIdsJson =
      GeneratedColumn<String>(
        'source_turn_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _confidenceScoreMeta = const VerificationMeta(
    'confidenceScore',
  );
  @override
  late final GeneratedColumn<double> confidenceScore = GeneratedColumn<double>(
    'confidence_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sensitivityMeta = const VerificationMeta(
    'sensitivity',
  );
  @override
  late final GeneratedColumn<String> sensitivity = GeneratedColumn<String>(
    'sensitivity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('normal'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closedAtMeta = const VerificationMeta(
    'closedAt',
  );
  @override
  late final GeneratedColumn<int> closedAt = GeneratedColumn<int>(
    'closed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    episodeId,
    kind,
    subject,
    predicate,
    objectText,
    dueStartAt,
    dueEndAt,
    status,
    followUpAllowed,
    proactiveAllowed,
    sourceTurnIdsJson,
    confidenceScore,
    sensitivity,
    createdAt,
    updatedAt,
    closedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_open_threads';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryOpenThread> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('predicate')) {
      context.handle(
        _predicateMeta,
        predicate.isAcceptableOrUnknown(data['predicate']!, _predicateMeta),
      );
    } else if (isInserting) {
      context.missing(_predicateMeta);
    }
    if (data.containsKey('object_text')) {
      context.handle(
        _objectTextMeta,
        objectText.isAcceptableOrUnknown(data['object_text']!, _objectTextMeta),
      );
    } else if (isInserting) {
      context.missing(_objectTextMeta);
    }
    if (data.containsKey('due_start_at')) {
      context.handle(
        _dueStartAtMeta,
        dueStartAt.isAcceptableOrUnknown(
          data['due_start_at']!,
          _dueStartAtMeta,
        ),
      );
    }
    if (data.containsKey('due_end_at')) {
      context.handle(
        _dueEndAtMeta,
        dueEndAt.isAcceptableOrUnknown(data['due_end_at']!, _dueEndAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('follow_up_allowed')) {
      context.handle(
        _followUpAllowedMeta,
        followUpAllowed.isAcceptableOrUnknown(
          data['follow_up_allowed']!,
          _followUpAllowedMeta,
        ),
      );
    }
    if (data.containsKey('proactive_allowed')) {
      context.handle(
        _proactiveAllowedMeta,
        proactiveAllowed.isAcceptableOrUnknown(
          data['proactive_allowed']!,
          _proactiveAllowedMeta,
        ),
      );
    }
    if (data.containsKey('source_turn_ids_json')) {
      context.handle(
        _sourceTurnIdsJsonMeta,
        sourceTurnIdsJson.isAcceptableOrUnknown(
          data['source_turn_ids_json']!,
          _sourceTurnIdsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceTurnIdsJsonMeta);
    }
    if (data.containsKey('confidence_score')) {
      context.handle(
        _confidenceScoreMeta,
        confidenceScore.isAcceptableOrUnknown(
          data['confidence_score']!,
          _confidenceScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_confidenceScoreMeta);
    }
    if (data.containsKey('sensitivity')) {
      context.handle(
        _sensitivityMeta,
        sensitivity.isAcceptableOrUnknown(
          data['sensitivity']!,
          _sensitivityMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('closed_at')) {
      context.handle(
        _closedAtMeta,
        closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryOpenThread map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryOpenThread(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      predicate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}predicate'],
      )!,
      objectText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}object_text'],
      )!,
      dueStartAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_start_at'],
      ),
      dueEndAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_end_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      followUpAllowed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}follow_up_allowed'],
      )!,
      proactiveAllowed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}proactive_allowed'],
      )!,
      sourceTurnIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_turn_ids_json'],
      )!,
      confidenceScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence_score'],
      )!,
      sensitivity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sensitivity'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      closedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}closed_at'],
      ),
    );
  }

  @override
  $MemoryOpenThreadsTable createAlias(String alias) {
    return $MemoryOpenThreadsTable(attachedDatabase, alias);
  }
}

class MemoryOpenThread extends DataClass
    implements Insertable<MemoryOpenThread> {
  final String id;
  final String? episodeId;
  final String kind;
  final String subject;
  final String predicate;
  final String objectText;
  final int? dueStartAt;
  final int? dueEndAt;
  final String status;
  final bool followUpAllowed;
  final bool proactiveAllowed;
  final String sourceTurnIdsJson;
  final double confidenceScore;
  final String sensitivity;
  final int createdAt;
  final int updatedAt;
  final int? closedAt;
  const MemoryOpenThread({
    required this.id,
    this.episodeId,
    required this.kind,
    required this.subject,
    required this.predicate,
    required this.objectText,
    this.dueStartAt,
    this.dueEndAt,
    required this.status,
    required this.followUpAllowed,
    required this.proactiveAllowed,
    required this.sourceTurnIdsJson,
    required this.confidenceScore,
    required this.sensitivity,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || episodeId != null) {
      map['episode_id'] = Variable<String>(episodeId);
    }
    map['kind'] = Variable<String>(kind);
    map['subject'] = Variable<String>(subject);
    map['predicate'] = Variable<String>(predicate);
    map['object_text'] = Variable<String>(objectText);
    if (!nullToAbsent || dueStartAt != null) {
      map['due_start_at'] = Variable<int>(dueStartAt);
    }
    if (!nullToAbsent || dueEndAt != null) {
      map['due_end_at'] = Variable<int>(dueEndAt);
    }
    map['status'] = Variable<String>(status);
    map['follow_up_allowed'] = Variable<bool>(followUpAllowed);
    map['proactive_allowed'] = Variable<bool>(proactiveAllowed);
    map['source_turn_ids_json'] = Variable<String>(sourceTurnIdsJson);
    map['confidence_score'] = Variable<double>(confidenceScore);
    map['sensitivity'] = Variable<String>(sensitivity);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<int>(closedAt);
    }
    return map;
  }

  MemoryOpenThreadsCompanion toCompanion(bool nullToAbsent) {
    return MemoryOpenThreadsCompanion(
      id: Value(id),
      episodeId: episodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeId),
      kind: Value(kind),
      subject: Value(subject),
      predicate: Value(predicate),
      objectText: Value(objectText),
      dueStartAt: dueStartAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueStartAt),
      dueEndAt: dueEndAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueEndAt),
      status: Value(status),
      followUpAllowed: Value(followUpAllowed),
      proactiveAllowed: Value(proactiveAllowed),
      sourceTurnIdsJson: Value(sourceTurnIdsJson),
      confidenceScore: Value(confidenceScore),
      sensitivity: Value(sensitivity),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
    );
  }

  factory MemoryOpenThread.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryOpenThread(
      id: serializer.fromJson<String>(json['id']),
      episodeId: serializer.fromJson<String?>(json['episodeId']),
      kind: serializer.fromJson<String>(json['kind']),
      subject: serializer.fromJson<String>(json['subject']),
      predicate: serializer.fromJson<String>(json['predicate']),
      objectText: serializer.fromJson<String>(json['objectText']),
      dueStartAt: serializer.fromJson<int?>(json['dueStartAt']),
      dueEndAt: serializer.fromJson<int?>(json['dueEndAt']),
      status: serializer.fromJson<String>(json['status']),
      followUpAllowed: serializer.fromJson<bool>(json['followUpAllowed']),
      proactiveAllowed: serializer.fromJson<bool>(json['proactiveAllowed']),
      sourceTurnIdsJson: serializer.fromJson<String>(json['sourceTurnIdsJson']),
      confidenceScore: serializer.fromJson<double>(json['confidenceScore']),
      sensitivity: serializer.fromJson<String>(json['sensitivity']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      closedAt: serializer.fromJson<int?>(json['closedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'episodeId': serializer.toJson<String?>(episodeId),
      'kind': serializer.toJson<String>(kind),
      'subject': serializer.toJson<String>(subject),
      'predicate': serializer.toJson<String>(predicate),
      'objectText': serializer.toJson<String>(objectText),
      'dueStartAt': serializer.toJson<int?>(dueStartAt),
      'dueEndAt': serializer.toJson<int?>(dueEndAt),
      'status': serializer.toJson<String>(status),
      'followUpAllowed': serializer.toJson<bool>(followUpAllowed),
      'proactiveAllowed': serializer.toJson<bool>(proactiveAllowed),
      'sourceTurnIdsJson': serializer.toJson<String>(sourceTurnIdsJson),
      'confidenceScore': serializer.toJson<double>(confidenceScore),
      'sensitivity': serializer.toJson<String>(sensitivity),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'closedAt': serializer.toJson<int?>(closedAt),
    };
  }

  MemoryOpenThread copyWith({
    String? id,
    Value<String?> episodeId = const Value.absent(),
    String? kind,
    String? subject,
    String? predicate,
    String? objectText,
    Value<int?> dueStartAt = const Value.absent(),
    Value<int?> dueEndAt = const Value.absent(),
    String? status,
    bool? followUpAllowed,
    bool? proactiveAllowed,
    String? sourceTurnIdsJson,
    double? confidenceScore,
    String? sensitivity,
    int? createdAt,
    int? updatedAt,
    Value<int?> closedAt = const Value.absent(),
  }) => MemoryOpenThread(
    id: id ?? this.id,
    episodeId: episodeId.present ? episodeId.value : this.episodeId,
    kind: kind ?? this.kind,
    subject: subject ?? this.subject,
    predicate: predicate ?? this.predicate,
    objectText: objectText ?? this.objectText,
    dueStartAt: dueStartAt.present ? dueStartAt.value : this.dueStartAt,
    dueEndAt: dueEndAt.present ? dueEndAt.value : this.dueEndAt,
    status: status ?? this.status,
    followUpAllowed: followUpAllowed ?? this.followUpAllowed,
    proactiveAllowed: proactiveAllowed ?? this.proactiveAllowed,
    sourceTurnIdsJson: sourceTurnIdsJson ?? this.sourceTurnIdsJson,
    confidenceScore: confidenceScore ?? this.confidenceScore,
    sensitivity: sensitivity ?? this.sensitivity,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
  );
  MemoryOpenThread copyWithCompanion(MemoryOpenThreadsCompanion data) {
    return MemoryOpenThread(
      id: data.id.present ? data.id.value : this.id,
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      kind: data.kind.present ? data.kind.value : this.kind,
      subject: data.subject.present ? data.subject.value : this.subject,
      predicate: data.predicate.present ? data.predicate.value : this.predicate,
      objectText: data.objectText.present
          ? data.objectText.value
          : this.objectText,
      dueStartAt: data.dueStartAt.present
          ? data.dueStartAt.value
          : this.dueStartAt,
      dueEndAt: data.dueEndAt.present ? data.dueEndAt.value : this.dueEndAt,
      status: data.status.present ? data.status.value : this.status,
      followUpAllowed: data.followUpAllowed.present
          ? data.followUpAllowed.value
          : this.followUpAllowed,
      proactiveAllowed: data.proactiveAllowed.present
          ? data.proactiveAllowed.value
          : this.proactiveAllowed,
      sourceTurnIdsJson: data.sourceTurnIdsJson.present
          ? data.sourceTurnIdsJson.value
          : this.sourceTurnIdsJson,
      confidenceScore: data.confidenceScore.present
          ? data.confidenceScore.value
          : this.confidenceScore,
      sensitivity: data.sensitivity.present
          ? data.sensitivity.value
          : this.sensitivity,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryOpenThread(')
          ..write('id: $id, ')
          ..write('episodeId: $episodeId, ')
          ..write('kind: $kind, ')
          ..write('subject: $subject, ')
          ..write('predicate: $predicate, ')
          ..write('objectText: $objectText, ')
          ..write('dueStartAt: $dueStartAt, ')
          ..write('dueEndAt: $dueEndAt, ')
          ..write('status: $status, ')
          ..write('followUpAllowed: $followUpAllowed, ')
          ..write('proactiveAllowed: $proactiveAllowed, ')
          ..write('sourceTurnIdsJson: $sourceTurnIdsJson, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('sensitivity: $sensitivity, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('closedAt: $closedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    episodeId,
    kind,
    subject,
    predicate,
    objectText,
    dueStartAt,
    dueEndAt,
    status,
    followUpAllowed,
    proactiveAllowed,
    sourceTurnIdsJson,
    confidenceScore,
    sensitivity,
    createdAt,
    updatedAt,
    closedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryOpenThread &&
          other.id == this.id &&
          other.episodeId == this.episodeId &&
          other.kind == this.kind &&
          other.subject == this.subject &&
          other.predicate == this.predicate &&
          other.objectText == this.objectText &&
          other.dueStartAt == this.dueStartAt &&
          other.dueEndAt == this.dueEndAt &&
          other.status == this.status &&
          other.followUpAllowed == this.followUpAllowed &&
          other.proactiveAllowed == this.proactiveAllowed &&
          other.sourceTurnIdsJson == this.sourceTurnIdsJson &&
          other.confidenceScore == this.confidenceScore &&
          other.sensitivity == this.sensitivity &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.closedAt == this.closedAt);
}

class MemoryOpenThreadsCompanion extends UpdateCompanion<MemoryOpenThread> {
  final Value<String> id;
  final Value<String?> episodeId;
  final Value<String> kind;
  final Value<String> subject;
  final Value<String> predicate;
  final Value<String> objectText;
  final Value<int?> dueStartAt;
  final Value<int?> dueEndAt;
  final Value<String> status;
  final Value<bool> followUpAllowed;
  final Value<bool> proactiveAllowed;
  final Value<String> sourceTurnIdsJson;
  final Value<double> confidenceScore;
  final Value<String> sensitivity;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> closedAt;
  final Value<int> rowid;
  const MemoryOpenThreadsCompanion({
    this.id = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.kind = const Value.absent(),
    this.subject = const Value.absent(),
    this.predicate = const Value.absent(),
    this.objectText = const Value.absent(),
    this.dueStartAt = const Value.absent(),
    this.dueEndAt = const Value.absent(),
    this.status = const Value.absent(),
    this.followUpAllowed = const Value.absent(),
    this.proactiveAllowed = const Value.absent(),
    this.sourceTurnIdsJson = const Value.absent(),
    this.confidenceScore = const Value.absent(),
    this.sensitivity = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryOpenThreadsCompanion.insert({
    required String id,
    this.episodeId = const Value.absent(),
    required String kind,
    required String subject,
    required String predicate,
    required String objectText,
    this.dueStartAt = const Value.absent(),
    this.dueEndAt = const Value.absent(),
    this.status = const Value.absent(),
    this.followUpAllowed = const Value.absent(),
    this.proactiveAllowed = const Value.absent(),
    required String sourceTurnIdsJson,
    required double confidenceScore,
    this.sensitivity = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.closedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       subject = Value(subject),
       predicate = Value(predicate),
       objectText = Value(objectText),
       sourceTurnIdsJson = Value(sourceTurnIdsJson),
       confidenceScore = Value(confidenceScore),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MemoryOpenThread> custom({
    Expression<String>? id,
    Expression<String>? episodeId,
    Expression<String>? kind,
    Expression<String>? subject,
    Expression<String>? predicate,
    Expression<String>? objectText,
    Expression<int>? dueStartAt,
    Expression<int>? dueEndAt,
    Expression<String>? status,
    Expression<bool>? followUpAllowed,
    Expression<bool>? proactiveAllowed,
    Expression<String>? sourceTurnIdsJson,
    Expression<double>? confidenceScore,
    Expression<String>? sensitivity,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? closedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (episodeId != null) 'episode_id': episodeId,
      if (kind != null) 'kind': kind,
      if (subject != null) 'subject': subject,
      if (predicate != null) 'predicate': predicate,
      if (objectText != null) 'object_text': objectText,
      if (dueStartAt != null) 'due_start_at': dueStartAt,
      if (dueEndAt != null) 'due_end_at': dueEndAt,
      if (status != null) 'status': status,
      if (followUpAllowed != null) 'follow_up_allowed': followUpAllowed,
      if (proactiveAllowed != null) 'proactive_allowed': proactiveAllowed,
      if (sourceTurnIdsJson != null) 'source_turn_ids_json': sourceTurnIdsJson,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      if (sensitivity != null) 'sensitivity': sensitivity,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (closedAt != null) 'closed_at': closedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryOpenThreadsCompanion copyWith({
    Value<String>? id,
    Value<String?>? episodeId,
    Value<String>? kind,
    Value<String>? subject,
    Value<String>? predicate,
    Value<String>? objectText,
    Value<int?>? dueStartAt,
    Value<int?>? dueEndAt,
    Value<String>? status,
    Value<bool>? followUpAllowed,
    Value<bool>? proactiveAllowed,
    Value<String>? sourceTurnIdsJson,
    Value<double>? confidenceScore,
    Value<String>? sensitivity,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? closedAt,
    Value<int>? rowid,
  }) {
    return MemoryOpenThreadsCompanion(
      id: id ?? this.id,
      episodeId: episodeId ?? this.episodeId,
      kind: kind ?? this.kind,
      subject: subject ?? this.subject,
      predicate: predicate ?? this.predicate,
      objectText: objectText ?? this.objectText,
      dueStartAt: dueStartAt ?? this.dueStartAt,
      dueEndAt: dueEndAt ?? this.dueEndAt,
      status: status ?? this.status,
      followUpAllowed: followUpAllowed ?? this.followUpAllowed,
      proactiveAllowed: proactiveAllowed ?? this.proactiveAllowed,
      sourceTurnIdsJson: sourceTurnIdsJson ?? this.sourceTurnIdsJson,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      sensitivity: sensitivity ?? this.sensitivity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      closedAt: closedAt ?? this.closedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (episodeId.present) {
      map['episode_id'] = Variable<String>(episodeId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (predicate.present) {
      map['predicate'] = Variable<String>(predicate.value);
    }
    if (objectText.present) {
      map['object_text'] = Variable<String>(objectText.value);
    }
    if (dueStartAt.present) {
      map['due_start_at'] = Variable<int>(dueStartAt.value);
    }
    if (dueEndAt.present) {
      map['due_end_at'] = Variable<int>(dueEndAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (followUpAllowed.present) {
      map['follow_up_allowed'] = Variable<bool>(followUpAllowed.value);
    }
    if (proactiveAllowed.present) {
      map['proactive_allowed'] = Variable<bool>(proactiveAllowed.value);
    }
    if (sourceTurnIdsJson.present) {
      map['source_turn_ids_json'] = Variable<String>(sourceTurnIdsJson.value);
    }
    if (confidenceScore.present) {
      map['confidence_score'] = Variable<double>(confidenceScore.value);
    }
    if (sensitivity.present) {
      map['sensitivity'] = Variable<String>(sensitivity.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<int>(closedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryOpenThreadsCompanion(')
          ..write('id: $id, ')
          ..write('episodeId: $episodeId, ')
          ..write('kind: $kind, ')
          ..write('subject: $subject, ')
          ..write('predicate: $predicate, ')
          ..write('objectText: $objectText, ')
          ..write('dueStartAt: $dueStartAt, ')
          ..write('dueEndAt: $dueEndAt, ')
          ..write('status: $status, ')
          ..write('followUpAllowed: $followUpAllowed, ')
          ..write('proactiveAllowed: $proactiveAllowed, ')
          ..write('sourceTurnIdsJson: $sourceTurnIdsJson, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('sensitivity: $sensitivity, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryExtractionJobsTable extends MemoryExtractionJobs
    with TableInfo<$MemoryExtractionJobsTable, MemoryExtractionJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryExtractionJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTurnIdMeta = const VerificationMeta(
    'startTurnId',
  );
  @override
  late final GeneratedColumn<String> startTurnId = GeneratedColumn<String>(
    'start_turn_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTurnIdMeta = const VerificationMeta(
    'endTurnId',
  );
  @override
  late final GeneratedColumn<String> endTurnId = GeneratedColumn<String>(
    'end_turn_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _extractionVersionMeta = const VerificationMeta(
    'extractionVersion',
  );
  @override
  late final GeneratedColumn<String> extractionVersion =
      GeneratedColumn<String>(
        'extraction_version',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _requestHashMeta = const VerificationMeta(
    'requestHash',
  );
  @override
  late final GeneratedColumn<String> requestHash = GeneratedColumn<String>(
    'request_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<int> nextAttemptAt = GeneratedColumn<int>(
    'next_attempt_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    startTurnId,
    endTurnId,
    status,
    attempts,
    extractionVersion,
    requestHash,
    lastErrorCode,
    nextAttemptAt,
    createdAt,
    updatedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_extraction_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryExtractionJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('start_turn_id')) {
      context.handle(
        _startTurnIdMeta,
        startTurnId.isAcceptableOrUnknown(
          data['start_turn_id']!,
          _startTurnIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startTurnIdMeta);
    }
    if (data.containsKey('end_turn_id')) {
      context.handle(
        _endTurnIdMeta,
        endTurnId.isAcceptableOrUnknown(data['end_turn_id']!, _endTurnIdMeta),
      );
    } else if (isInserting) {
      context.missing(_endTurnIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('extraction_version')) {
      context.handle(
        _extractionVersionMeta,
        extractionVersion.isAcceptableOrUnknown(
          data['extraction_version']!,
          _extractionVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_extractionVersionMeta);
    }
    if (data.containsKey('request_hash')) {
      context.handle(
        _requestHashMeta,
        requestHash.isAcceptableOrUnknown(
          data['request_hash']!,
          _requestHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestHashMeta);
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryExtractionJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryExtractionJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      startTurnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_turn_id'],
      )!,
      endTurnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_turn_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      extractionVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extraction_version'],
      )!,
      requestHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_hash'],
      )!,
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_attempt_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $MemoryExtractionJobsTable createAlias(String alias) {
    return $MemoryExtractionJobsTable(attachedDatabase, alias);
  }
}

class MemoryExtractionJob extends DataClass
    implements Insertable<MemoryExtractionJob> {
  final String id;
  final String sessionId;
  final String startTurnId;
  final String endTurnId;
  final String status;
  final int attempts;
  final String extractionVersion;
  final String requestHash;
  final String? lastErrorCode;
  final int? nextAttemptAt;
  final int createdAt;
  final int updatedAt;
  final int? completedAt;
  const MemoryExtractionJob({
    required this.id,
    required this.sessionId,
    required this.startTurnId,
    required this.endTurnId,
    required this.status,
    required this.attempts,
    required this.extractionVersion,
    required this.requestHash,
    this.lastErrorCode,
    this.nextAttemptAt,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['start_turn_id'] = Variable<String>(startTurnId);
    map['end_turn_id'] = Variable<String>(endTurnId);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    map['extraction_version'] = Variable<String>(extractionVersion);
    map['request_hash'] = Variable<String>(requestHash);
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<int>(nextAttemptAt);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    return map;
  }

  MemoryExtractionJobsCompanion toCompanion(bool nullToAbsent) {
    return MemoryExtractionJobsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      startTurnId: Value(startTurnId),
      endTurnId: Value(endTurnId),
      status: Value(status),
      attempts: Value(attempts),
      extractionVersion: Value(extractionVersion),
      requestHash: Value(requestHash),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory MemoryExtractionJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryExtractionJob(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      startTurnId: serializer.fromJson<String>(json['startTurnId']),
      endTurnId: serializer.fromJson<String>(json['endTurnId']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      extractionVersion: serializer.fromJson<String>(json['extractionVersion']),
      requestHash: serializer.fromJson<String>(json['requestHash']),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
      nextAttemptAt: serializer.fromJson<int?>(json['nextAttemptAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'startTurnId': serializer.toJson<String>(startTurnId),
      'endTurnId': serializer.toJson<String>(endTurnId),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'extractionVersion': serializer.toJson<String>(extractionVersion),
      'requestHash': serializer.toJson<String>(requestHash),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
      'nextAttemptAt': serializer.toJson<int?>(nextAttemptAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'completedAt': serializer.toJson<int?>(completedAt),
    };
  }

  MemoryExtractionJob copyWith({
    String? id,
    String? sessionId,
    String? startTurnId,
    String? endTurnId,
    String? status,
    int? attempts,
    String? extractionVersion,
    String? requestHash,
    Value<String?> lastErrorCode = const Value.absent(),
    Value<int?> nextAttemptAt = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> completedAt = const Value.absent(),
  }) => MemoryExtractionJob(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    startTurnId: startTurnId ?? this.startTurnId,
    endTurnId: endTurnId ?? this.endTurnId,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    extractionVersion: extractionVersion ?? this.extractionVersion,
    requestHash: requestHash ?? this.requestHash,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  MemoryExtractionJob copyWithCompanion(MemoryExtractionJobsCompanion data) {
    return MemoryExtractionJob(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      startTurnId: data.startTurnId.present
          ? data.startTurnId.value
          : this.startTurnId,
      endTurnId: data.endTurnId.present ? data.endTurnId.value : this.endTurnId,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      extractionVersion: data.extractionVersion.present
          ? data.extractionVersion.value
          : this.extractionVersion,
      requestHash: data.requestHash.present
          ? data.requestHash.value
          : this.requestHash,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryExtractionJob(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('startTurnId: $startTurnId, ')
          ..write('endTurnId: $endTurnId, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('extractionVersion: $extractionVersion, ')
          ..write('requestHash: $requestHash, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    startTurnId,
    endTurnId,
    status,
    attempts,
    extractionVersion,
    requestHash,
    lastErrorCode,
    nextAttemptAt,
    createdAt,
    updatedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryExtractionJob &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.startTurnId == this.startTurnId &&
          other.endTurnId == this.endTurnId &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.extractionVersion == this.extractionVersion &&
          other.requestHash == this.requestHash &&
          other.lastErrorCode == this.lastErrorCode &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt);
}

class MemoryExtractionJobsCompanion
    extends UpdateCompanion<MemoryExtractionJob> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> startTurnId;
  final Value<String> endTurnId;
  final Value<String> status;
  final Value<int> attempts;
  final Value<String> extractionVersion;
  final Value<String> requestHash;
  final Value<String?> lastErrorCode;
  final Value<int?> nextAttemptAt;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> completedAt;
  final Value<int> rowid;
  const MemoryExtractionJobsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.startTurnId = const Value.absent(),
    this.endTurnId = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.extractionVersion = const Value.absent(),
    this.requestHash = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryExtractionJobsCompanion.insert({
    required String id,
    required String sessionId,
    required String startTurnId,
    required String endTurnId,
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    required String extractionVersion,
    required String requestHash,
    this.lastErrorCode = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       startTurnId = Value(startTurnId),
       endTurnId = Value(endTurnId),
       extractionVersion = Value(extractionVersion),
       requestHash = Value(requestHash),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MemoryExtractionJob> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? startTurnId,
    Expression<String>? endTurnId,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? extractionVersion,
    Expression<String>? requestHash,
    Expression<String>? lastErrorCode,
    Expression<int>? nextAttemptAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (startTurnId != null) 'start_turn_id': startTurnId,
      if (endTurnId != null) 'end_turn_id': endTurnId,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (extractionVersion != null) 'extraction_version': extractionVersion,
      if (requestHash != null) 'request_hash': requestHash,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryExtractionJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? startTurnId,
    Value<String>? endTurnId,
    Value<String>? status,
    Value<int>? attempts,
    Value<String>? extractionVersion,
    Value<String>? requestHash,
    Value<String?>? lastErrorCode,
    Value<int?>? nextAttemptAt,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? completedAt,
    Value<int>? rowid,
  }) {
    return MemoryExtractionJobsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      startTurnId: startTurnId ?? this.startTurnId,
      endTurnId: endTurnId ?? this.endTurnId,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      extractionVersion: extractionVersion ?? this.extractionVersion,
      requestHash: requestHash ?? this.requestHash,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (startTurnId.present) {
      map['start_turn_id'] = Variable<String>(startTurnId.value);
    }
    if (endTurnId.present) {
      map['end_turn_id'] = Variable<String>(endTurnId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (extractionVersion.present) {
      map['extraction_version'] = Variable<String>(extractionVersion.value);
    }
    if (requestHash.present) {
      map['request_hash'] = Variable<String>(requestHash.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<int>(nextAttemptAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryExtractionJobsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('startTurnId: $startTurnId, ')
          ..write('endTurnId: $endTurnId, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('extractionVersion: $extractionVersion, ')
          ..write('requestHash: $requestHash, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryCandidatesTable extends MemoryCandidates
    with TableInfo<$MemoryCandidatesTable, MemoryCandidate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryCandidatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _candidateKindMeta = const VerificationMeta(
    'candidateKind',
  );
  @override
  late final GeneratedColumn<String> candidateKind = GeneratedColumn<String>(
    'candidate_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _predicateMeta = const VerificationMeta(
    'predicate',
  );
  @override
  late final GeneratedColumn<String> predicate = GeneratedColumn<String>(
    'predicate',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _objectTextMeta = const VerificationMeta(
    'objectText',
  );
  @override
  late final GeneratedColumn<String> objectText = GeneratedColumn<String>(
    'object_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventStartAtMeta = const VerificationMeta(
    'eventStartAt',
  );
  @override
  late final GeneratedColumn<int> eventStartAt = GeneratedColumn<int>(
    'event_start_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventEndAtMeta = const VerificationMeta(
    'eventEndAt',
  );
  @override
  late final GeneratedColumn<int> eventEndAt = GeneratedColumn<int>(
    'event_end_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _temporalStatusMeta = const VerificationMeta(
    'temporalStatus',
  );
  @override
  late final GeneratedColumn<String> temporalStatus = GeneratedColumn<String>(
    'temporal_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _explicitnessMeta = const VerificationMeta(
    'explicitness',
  );
  @override
  late final GeneratedColumn<String> explicitness = GeneratedColumn<String>(
    'explicitness',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceScoreMeta = const VerificationMeta(
    'confidenceScore',
  );
  @override
  late final GeneratedColumn<double> confidenceScore = GeneratedColumn<double>(
    'confidence_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _futureUtilityMeta = const VerificationMeta(
    'futureUtility',
  );
  @override
  late final GeneratedColumn<double> futureUtility = GeneratedColumn<double>(
    'future_utility',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sensitivityMeta = const VerificationMeta(
    'sensitivity',
  );
  @override
  late final GeneratedColumn<String> sensitivity = GeneratedColumn<String>(
    'sensitivity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTurnIdsJsonMeta = const VerificationMeta(
    'sourceTurnIdsJson',
  );
  @override
  late final GeneratedColumn<String> sourceTurnIdsJson =
      GeneratedColumn<String>(
        'source_turn_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _evidenceRoleMeta = const VerificationMeta(
    'evidenceRole',
  );
  @override
  late final GeneratedColumn<String> evidenceRole = GeneratedColumn<String>(
    'evidence_role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _suggestedActionMeta = const VerificationMeta(
    'suggestedAction',
  );
  @override
  late final GeneratedColumn<String> suggestedAction = GeneratedColumn<String>(
    'suggested_action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _followUpAllowedMeta = const VerificationMeta(
    'followUpAllowed',
  );
  @override
  late final GeneratedColumn<bool> followUpAllowed = GeneratedColumn<bool>(
    'follow_up_allowed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("follow_up_allowed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _proactiveAllowedMeta = const VerificationMeta(
    'proactiveAllowed',
  );
  @override
  late final GeneratedColumn<bool> proactiveAllowed = GeneratedColumn<bool>(
    'proactive_allowed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("proactive_allowed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _decisionStateMeta = const VerificationMeta(
    'decisionState',
  );
  @override
  late final GeneratedColumn<String> decisionState = GeneratedColumn<String>(
    'decision_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _decisionReasonMeta = const VerificationMeta(
    'decisionReason',
  );
  @override
  late final GeneratedColumn<String> decisionReason = GeneratedColumn<String>(
    'decision_reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMemoryIdMeta = const VerificationMeta(
    'targetMemoryId',
  );
  @override
  late final GeneratedColumn<String> targetMemoryId = GeneratedColumn<String>(
    'target_memory_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    jobId,
    candidateKind,
    subject,
    predicate,
    objectText,
    eventStartAt,
    eventEndAt,
    temporalStatus,
    explicitness,
    confidenceScore,
    futureUtility,
    sensitivity,
    sourceTurnIdsJson,
    evidenceRole,
    suggestedAction,
    followUpAllowed,
    proactiveAllowed,
    decisionState,
    decisionReason,
    targetMemoryId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_candidates';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryCandidate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('job_id')) {
      context.handle(
        _jobIdMeta,
        jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_jobIdMeta);
    }
    if (data.containsKey('candidate_kind')) {
      context.handle(
        _candidateKindMeta,
        candidateKind.isAcceptableOrUnknown(
          data['candidate_kind']!,
          _candidateKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_candidateKindMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('predicate')) {
      context.handle(
        _predicateMeta,
        predicate.isAcceptableOrUnknown(data['predicate']!, _predicateMeta),
      );
    } else if (isInserting) {
      context.missing(_predicateMeta);
    }
    if (data.containsKey('object_text')) {
      context.handle(
        _objectTextMeta,
        objectText.isAcceptableOrUnknown(data['object_text']!, _objectTextMeta),
      );
    } else if (isInserting) {
      context.missing(_objectTextMeta);
    }
    if (data.containsKey('event_start_at')) {
      context.handle(
        _eventStartAtMeta,
        eventStartAt.isAcceptableOrUnknown(
          data['event_start_at']!,
          _eventStartAtMeta,
        ),
      );
    }
    if (data.containsKey('event_end_at')) {
      context.handle(
        _eventEndAtMeta,
        eventEndAt.isAcceptableOrUnknown(
          data['event_end_at']!,
          _eventEndAtMeta,
        ),
      );
    }
    if (data.containsKey('temporal_status')) {
      context.handle(
        _temporalStatusMeta,
        temporalStatus.isAcceptableOrUnknown(
          data['temporal_status']!,
          _temporalStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_temporalStatusMeta);
    }
    if (data.containsKey('explicitness')) {
      context.handle(
        _explicitnessMeta,
        explicitness.isAcceptableOrUnknown(
          data['explicitness']!,
          _explicitnessMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_explicitnessMeta);
    }
    if (data.containsKey('confidence_score')) {
      context.handle(
        _confidenceScoreMeta,
        confidenceScore.isAcceptableOrUnknown(
          data['confidence_score']!,
          _confidenceScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_confidenceScoreMeta);
    }
    if (data.containsKey('future_utility')) {
      context.handle(
        _futureUtilityMeta,
        futureUtility.isAcceptableOrUnknown(
          data['future_utility']!,
          _futureUtilityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_futureUtilityMeta);
    }
    if (data.containsKey('sensitivity')) {
      context.handle(
        _sensitivityMeta,
        sensitivity.isAcceptableOrUnknown(
          data['sensitivity']!,
          _sensitivityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sensitivityMeta);
    }
    if (data.containsKey('source_turn_ids_json')) {
      context.handle(
        _sourceTurnIdsJsonMeta,
        sourceTurnIdsJson.isAcceptableOrUnknown(
          data['source_turn_ids_json']!,
          _sourceTurnIdsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceTurnIdsJsonMeta);
    }
    if (data.containsKey('evidence_role')) {
      context.handle(
        _evidenceRoleMeta,
        evidenceRole.isAcceptableOrUnknown(
          data['evidence_role']!,
          _evidenceRoleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_evidenceRoleMeta);
    }
    if (data.containsKey('suggested_action')) {
      context.handle(
        _suggestedActionMeta,
        suggestedAction.isAcceptableOrUnknown(
          data['suggested_action']!,
          _suggestedActionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_suggestedActionMeta);
    }
    if (data.containsKey('follow_up_allowed')) {
      context.handle(
        _followUpAllowedMeta,
        followUpAllowed.isAcceptableOrUnknown(
          data['follow_up_allowed']!,
          _followUpAllowedMeta,
        ),
      );
    }
    if (data.containsKey('proactive_allowed')) {
      context.handle(
        _proactiveAllowedMeta,
        proactiveAllowed.isAcceptableOrUnknown(
          data['proactive_allowed']!,
          _proactiveAllowedMeta,
        ),
      );
    }
    if (data.containsKey('decision_state')) {
      context.handle(
        _decisionStateMeta,
        decisionState.isAcceptableOrUnknown(
          data['decision_state']!,
          _decisionStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_decisionStateMeta);
    }
    if (data.containsKey('decision_reason')) {
      context.handle(
        _decisionReasonMeta,
        decisionReason.isAcceptableOrUnknown(
          data['decision_reason']!,
          _decisionReasonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_decisionReasonMeta);
    }
    if (data.containsKey('target_memory_id')) {
      context.handle(
        _targetMemoryIdMeta,
        targetMemoryId.isAcceptableOrUnknown(
          data['target_memory_id']!,
          _targetMemoryIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryCandidate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryCandidate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      jobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_id'],
      )!,
      candidateKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}candidate_kind'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      predicate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}predicate'],
      )!,
      objectText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}object_text'],
      )!,
      eventStartAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_start_at'],
      ),
      eventEndAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_end_at'],
      ),
      temporalStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temporal_status'],
      )!,
      explicitness: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explicitness'],
      )!,
      confidenceScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence_score'],
      )!,
      futureUtility: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}future_utility'],
      )!,
      sensitivity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sensitivity'],
      )!,
      sourceTurnIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_turn_ids_json'],
      )!,
      evidenceRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_role'],
      )!,
      suggestedAction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_action'],
      )!,
      followUpAllowed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}follow_up_allowed'],
      )!,
      proactiveAllowed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}proactive_allowed'],
      )!,
      decisionState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decision_state'],
      )!,
      decisionReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decision_reason'],
      )!,
      targetMemoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_memory_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MemoryCandidatesTable createAlias(String alias) {
    return $MemoryCandidatesTable(attachedDatabase, alias);
  }
}

class MemoryCandidate extends DataClass implements Insertable<MemoryCandidate> {
  final String id;
  final String jobId;
  final String candidateKind;
  final String subject;
  final String predicate;
  final String objectText;
  final int? eventStartAt;
  final int? eventEndAt;
  final String temporalStatus;
  final String explicitness;
  final double confidenceScore;
  final double futureUtility;
  final String sensitivity;
  final String sourceTurnIdsJson;
  final String evidenceRole;
  final String suggestedAction;
  final bool followUpAllowed;
  final bool proactiveAllowed;
  final String decisionState;
  final String decisionReason;
  final String? targetMemoryId;
  final int createdAt;
  const MemoryCandidate({
    required this.id,
    required this.jobId,
    required this.candidateKind,
    required this.subject,
    required this.predicate,
    required this.objectText,
    this.eventStartAt,
    this.eventEndAt,
    required this.temporalStatus,
    required this.explicitness,
    required this.confidenceScore,
    required this.futureUtility,
    required this.sensitivity,
    required this.sourceTurnIdsJson,
    required this.evidenceRole,
    required this.suggestedAction,
    required this.followUpAllowed,
    required this.proactiveAllowed,
    required this.decisionState,
    required this.decisionReason,
    this.targetMemoryId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['job_id'] = Variable<String>(jobId);
    map['candidate_kind'] = Variable<String>(candidateKind);
    map['subject'] = Variable<String>(subject);
    map['predicate'] = Variable<String>(predicate);
    map['object_text'] = Variable<String>(objectText);
    if (!nullToAbsent || eventStartAt != null) {
      map['event_start_at'] = Variable<int>(eventStartAt);
    }
    if (!nullToAbsent || eventEndAt != null) {
      map['event_end_at'] = Variable<int>(eventEndAt);
    }
    map['temporal_status'] = Variable<String>(temporalStatus);
    map['explicitness'] = Variable<String>(explicitness);
    map['confidence_score'] = Variable<double>(confidenceScore);
    map['future_utility'] = Variable<double>(futureUtility);
    map['sensitivity'] = Variable<String>(sensitivity);
    map['source_turn_ids_json'] = Variable<String>(sourceTurnIdsJson);
    map['evidence_role'] = Variable<String>(evidenceRole);
    map['suggested_action'] = Variable<String>(suggestedAction);
    map['follow_up_allowed'] = Variable<bool>(followUpAllowed);
    map['proactive_allowed'] = Variable<bool>(proactiveAllowed);
    map['decision_state'] = Variable<String>(decisionState);
    map['decision_reason'] = Variable<String>(decisionReason);
    if (!nullToAbsent || targetMemoryId != null) {
      map['target_memory_id'] = Variable<String>(targetMemoryId);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  MemoryCandidatesCompanion toCompanion(bool nullToAbsent) {
    return MemoryCandidatesCompanion(
      id: Value(id),
      jobId: Value(jobId),
      candidateKind: Value(candidateKind),
      subject: Value(subject),
      predicate: Value(predicate),
      objectText: Value(objectText),
      eventStartAt: eventStartAt == null && nullToAbsent
          ? const Value.absent()
          : Value(eventStartAt),
      eventEndAt: eventEndAt == null && nullToAbsent
          ? const Value.absent()
          : Value(eventEndAt),
      temporalStatus: Value(temporalStatus),
      explicitness: Value(explicitness),
      confidenceScore: Value(confidenceScore),
      futureUtility: Value(futureUtility),
      sensitivity: Value(sensitivity),
      sourceTurnIdsJson: Value(sourceTurnIdsJson),
      evidenceRole: Value(evidenceRole),
      suggestedAction: Value(suggestedAction),
      followUpAllowed: Value(followUpAllowed),
      proactiveAllowed: Value(proactiveAllowed),
      decisionState: Value(decisionState),
      decisionReason: Value(decisionReason),
      targetMemoryId: targetMemoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetMemoryId),
      createdAt: Value(createdAt),
    );
  }

  factory MemoryCandidate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryCandidate(
      id: serializer.fromJson<String>(json['id']),
      jobId: serializer.fromJson<String>(json['jobId']),
      candidateKind: serializer.fromJson<String>(json['candidateKind']),
      subject: serializer.fromJson<String>(json['subject']),
      predicate: serializer.fromJson<String>(json['predicate']),
      objectText: serializer.fromJson<String>(json['objectText']),
      eventStartAt: serializer.fromJson<int?>(json['eventStartAt']),
      eventEndAt: serializer.fromJson<int?>(json['eventEndAt']),
      temporalStatus: serializer.fromJson<String>(json['temporalStatus']),
      explicitness: serializer.fromJson<String>(json['explicitness']),
      confidenceScore: serializer.fromJson<double>(json['confidenceScore']),
      futureUtility: serializer.fromJson<double>(json['futureUtility']),
      sensitivity: serializer.fromJson<String>(json['sensitivity']),
      sourceTurnIdsJson: serializer.fromJson<String>(json['sourceTurnIdsJson']),
      evidenceRole: serializer.fromJson<String>(json['evidenceRole']),
      suggestedAction: serializer.fromJson<String>(json['suggestedAction']),
      followUpAllowed: serializer.fromJson<bool>(json['followUpAllowed']),
      proactiveAllowed: serializer.fromJson<bool>(json['proactiveAllowed']),
      decisionState: serializer.fromJson<String>(json['decisionState']),
      decisionReason: serializer.fromJson<String>(json['decisionReason']),
      targetMemoryId: serializer.fromJson<String?>(json['targetMemoryId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'jobId': serializer.toJson<String>(jobId),
      'candidateKind': serializer.toJson<String>(candidateKind),
      'subject': serializer.toJson<String>(subject),
      'predicate': serializer.toJson<String>(predicate),
      'objectText': serializer.toJson<String>(objectText),
      'eventStartAt': serializer.toJson<int?>(eventStartAt),
      'eventEndAt': serializer.toJson<int?>(eventEndAt),
      'temporalStatus': serializer.toJson<String>(temporalStatus),
      'explicitness': serializer.toJson<String>(explicitness),
      'confidenceScore': serializer.toJson<double>(confidenceScore),
      'futureUtility': serializer.toJson<double>(futureUtility),
      'sensitivity': serializer.toJson<String>(sensitivity),
      'sourceTurnIdsJson': serializer.toJson<String>(sourceTurnIdsJson),
      'evidenceRole': serializer.toJson<String>(evidenceRole),
      'suggestedAction': serializer.toJson<String>(suggestedAction),
      'followUpAllowed': serializer.toJson<bool>(followUpAllowed),
      'proactiveAllowed': serializer.toJson<bool>(proactiveAllowed),
      'decisionState': serializer.toJson<String>(decisionState),
      'decisionReason': serializer.toJson<String>(decisionReason),
      'targetMemoryId': serializer.toJson<String?>(targetMemoryId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  MemoryCandidate copyWith({
    String? id,
    String? jobId,
    String? candidateKind,
    String? subject,
    String? predicate,
    String? objectText,
    Value<int?> eventStartAt = const Value.absent(),
    Value<int?> eventEndAt = const Value.absent(),
    String? temporalStatus,
    String? explicitness,
    double? confidenceScore,
    double? futureUtility,
    String? sensitivity,
    String? sourceTurnIdsJson,
    String? evidenceRole,
    String? suggestedAction,
    bool? followUpAllowed,
    bool? proactiveAllowed,
    String? decisionState,
    String? decisionReason,
    Value<String?> targetMemoryId = const Value.absent(),
    int? createdAt,
  }) => MemoryCandidate(
    id: id ?? this.id,
    jobId: jobId ?? this.jobId,
    candidateKind: candidateKind ?? this.candidateKind,
    subject: subject ?? this.subject,
    predicate: predicate ?? this.predicate,
    objectText: objectText ?? this.objectText,
    eventStartAt: eventStartAt.present ? eventStartAt.value : this.eventStartAt,
    eventEndAt: eventEndAt.present ? eventEndAt.value : this.eventEndAt,
    temporalStatus: temporalStatus ?? this.temporalStatus,
    explicitness: explicitness ?? this.explicitness,
    confidenceScore: confidenceScore ?? this.confidenceScore,
    futureUtility: futureUtility ?? this.futureUtility,
    sensitivity: sensitivity ?? this.sensitivity,
    sourceTurnIdsJson: sourceTurnIdsJson ?? this.sourceTurnIdsJson,
    evidenceRole: evidenceRole ?? this.evidenceRole,
    suggestedAction: suggestedAction ?? this.suggestedAction,
    followUpAllowed: followUpAllowed ?? this.followUpAllowed,
    proactiveAllowed: proactiveAllowed ?? this.proactiveAllowed,
    decisionState: decisionState ?? this.decisionState,
    decisionReason: decisionReason ?? this.decisionReason,
    targetMemoryId: targetMemoryId.present
        ? targetMemoryId.value
        : this.targetMemoryId,
    createdAt: createdAt ?? this.createdAt,
  );
  MemoryCandidate copyWithCompanion(MemoryCandidatesCompanion data) {
    return MemoryCandidate(
      id: data.id.present ? data.id.value : this.id,
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      candidateKind: data.candidateKind.present
          ? data.candidateKind.value
          : this.candidateKind,
      subject: data.subject.present ? data.subject.value : this.subject,
      predicate: data.predicate.present ? data.predicate.value : this.predicate,
      objectText: data.objectText.present
          ? data.objectText.value
          : this.objectText,
      eventStartAt: data.eventStartAt.present
          ? data.eventStartAt.value
          : this.eventStartAt,
      eventEndAt: data.eventEndAt.present
          ? data.eventEndAt.value
          : this.eventEndAt,
      temporalStatus: data.temporalStatus.present
          ? data.temporalStatus.value
          : this.temporalStatus,
      explicitness: data.explicitness.present
          ? data.explicitness.value
          : this.explicitness,
      confidenceScore: data.confidenceScore.present
          ? data.confidenceScore.value
          : this.confidenceScore,
      futureUtility: data.futureUtility.present
          ? data.futureUtility.value
          : this.futureUtility,
      sensitivity: data.sensitivity.present
          ? data.sensitivity.value
          : this.sensitivity,
      sourceTurnIdsJson: data.sourceTurnIdsJson.present
          ? data.sourceTurnIdsJson.value
          : this.sourceTurnIdsJson,
      evidenceRole: data.evidenceRole.present
          ? data.evidenceRole.value
          : this.evidenceRole,
      suggestedAction: data.suggestedAction.present
          ? data.suggestedAction.value
          : this.suggestedAction,
      followUpAllowed: data.followUpAllowed.present
          ? data.followUpAllowed.value
          : this.followUpAllowed,
      proactiveAllowed: data.proactiveAllowed.present
          ? data.proactiveAllowed.value
          : this.proactiveAllowed,
      decisionState: data.decisionState.present
          ? data.decisionState.value
          : this.decisionState,
      decisionReason: data.decisionReason.present
          ? data.decisionReason.value
          : this.decisionReason,
      targetMemoryId: data.targetMemoryId.present
          ? data.targetMemoryId.value
          : this.targetMemoryId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryCandidate(')
          ..write('id: $id, ')
          ..write('jobId: $jobId, ')
          ..write('candidateKind: $candidateKind, ')
          ..write('subject: $subject, ')
          ..write('predicate: $predicate, ')
          ..write('objectText: $objectText, ')
          ..write('eventStartAt: $eventStartAt, ')
          ..write('eventEndAt: $eventEndAt, ')
          ..write('temporalStatus: $temporalStatus, ')
          ..write('explicitness: $explicitness, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('futureUtility: $futureUtility, ')
          ..write('sensitivity: $sensitivity, ')
          ..write('sourceTurnIdsJson: $sourceTurnIdsJson, ')
          ..write('evidenceRole: $evidenceRole, ')
          ..write('suggestedAction: $suggestedAction, ')
          ..write('followUpAllowed: $followUpAllowed, ')
          ..write('proactiveAllowed: $proactiveAllowed, ')
          ..write('decisionState: $decisionState, ')
          ..write('decisionReason: $decisionReason, ')
          ..write('targetMemoryId: $targetMemoryId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    jobId,
    candidateKind,
    subject,
    predicate,
    objectText,
    eventStartAt,
    eventEndAt,
    temporalStatus,
    explicitness,
    confidenceScore,
    futureUtility,
    sensitivity,
    sourceTurnIdsJson,
    evidenceRole,
    suggestedAction,
    followUpAllowed,
    proactiveAllowed,
    decisionState,
    decisionReason,
    targetMemoryId,
    createdAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryCandidate &&
          other.id == this.id &&
          other.jobId == this.jobId &&
          other.candidateKind == this.candidateKind &&
          other.subject == this.subject &&
          other.predicate == this.predicate &&
          other.objectText == this.objectText &&
          other.eventStartAt == this.eventStartAt &&
          other.eventEndAt == this.eventEndAt &&
          other.temporalStatus == this.temporalStatus &&
          other.explicitness == this.explicitness &&
          other.confidenceScore == this.confidenceScore &&
          other.futureUtility == this.futureUtility &&
          other.sensitivity == this.sensitivity &&
          other.sourceTurnIdsJson == this.sourceTurnIdsJson &&
          other.evidenceRole == this.evidenceRole &&
          other.suggestedAction == this.suggestedAction &&
          other.followUpAllowed == this.followUpAllowed &&
          other.proactiveAllowed == this.proactiveAllowed &&
          other.decisionState == this.decisionState &&
          other.decisionReason == this.decisionReason &&
          other.targetMemoryId == this.targetMemoryId &&
          other.createdAt == this.createdAt);
}

class MemoryCandidatesCompanion extends UpdateCompanion<MemoryCandidate> {
  final Value<String> id;
  final Value<String> jobId;
  final Value<String> candidateKind;
  final Value<String> subject;
  final Value<String> predicate;
  final Value<String> objectText;
  final Value<int?> eventStartAt;
  final Value<int?> eventEndAt;
  final Value<String> temporalStatus;
  final Value<String> explicitness;
  final Value<double> confidenceScore;
  final Value<double> futureUtility;
  final Value<String> sensitivity;
  final Value<String> sourceTurnIdsJson;
  final Value<String> evidenceRole;
  final Value<String> suggestedAction;
  final Value<bool> followUpAllowed;
  final Value<bool> proactiveAllowed;
  final Value<String> decisionState;
  final Value<String> decisionReason;
  final Value<String?> targetMemoryId;
  final Value<int> createdAt;
  final Value<int> rowid;
  const MemoryCandidatesCompanion({
    this.id = const Value.absent(),
    this.jobId = const Value.absent(),
    this.candidateKind = const Value.absent(),
    this.subject = const Value.absent(),
    this.predicate = const Value.absent(),
    this.objectText = const Value.absent(),
    this.eventStartAt = const Value.absent(),
    this.eventEndAt = const Value.absent(),
    this.temporalStatus = const Value.absent(),
    this.explicitness = const Value.absent(),
    this.confidenceScore = const Value.absent(),
    this.futureUtility = const Value.absent(),
    this.sensitivity = const Value.absent(),
    this.sourceTurnIdsJson = const Value.absent(),
    this.evidenceRole = const Value.absent(),
    this.suggestedAction = const Value.absent(),
    this.followUpAllowed = const Value.absent(),
    this.proactiveAllowed = const Value.absent(),
    this.decisionState = const Value.absent(),
    this.decisionReason = const Value.absent(),
    this.targetMemoryId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryCandidatesCompanion.insert({
    required String id,
    required String jobId,
    required String candidateKind,
    required String subject,
    required String predicate,
    required String objectText,
    this.eventStartAt = const Value.absent(),
    this.eventEndAt = const Value.absent(),
    required String temporalStatus,
    required String explicitness,
    required double confidenceScore,
    required double futureUtility,
    required String sensitivity,
    required String sourceTurnIdsJson,
    required String evidenceRole,
    required String suggestedAction,
    this.followUpAllowed = const Value.absent(),
    this.proactiveAllowed = const Value.absent(),
    required String decisionState,
    required String decisionReason,
    this.targetMemoryId = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       jobId = Value(jobId),
       candidateKind = Value(candidateKind),
       subject = Value(subject),
       predicate = Value(predicate),
       objectText = Value(objectText),
       temporalStatus = Value(temporalStatus),
       explicitness = Value(explicitness),
       confidenceScore = Value(confidenceScore),
       futureUtility = Value(futureUtility),
       sensitivity = Value(sensitivity),
       sourceTurnIdsJson = Value(sourceTurnIdsJson),
       evidenceRole = Value(evidenceRole),
       suggestedAction = Value(suggestedAction),
       decisionState = Value(decisionState),
       decisionReason = Value(decisionReason),
       createdAt = Value(createdAt);
  static Insertable<MemoryCandidate> custom({
    Expression<String>? id,
    Expression<String>? jobId,
    Expression<String>? candidateKind,
    Expression<String>? subject,
    Expression<String>? predicate,
    Expression<String>? objectText,
    Expression<int>? eventStartAt,
    Expression<int>? eventEndAt,
    Expression<String>? temporalStatus,
    Expression<String>? explicitness,
    Expression<double>? confidenceScore,
    Expression<double>? futureUtility,
    Expression<String>? sensitivity,
    Expression<String>? sourceTurnIdsJson,
    Expression<String>? evidenceRole,
    Expression<String>? suggestedAction,
    Expression<bool>? followUpAllowed,
    Expression<bool>? proactiveAllowed,
    Expression<String>? decisionState,
    Expression<String>? decisionReason,
    Expression<String>? targetMemoryId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (jobId != null) 'job_id': jobId,
      if (candidateKind != null) 'candidate_kind': candidateKind,
      if (subject != null) 'subject': subject,
      if (predicate != null) 'predicate': predicate,
      if (objectText != null) 'object_text': objectText,
      if (eventStartAt != null) 'event_start_at': eventStartAt,
      if (eventEndAt != null) 'event_end_at': eventEndAt,
      if (temporalStatus != null) 'temporal_status': temporalStatus,
      if (explicitness != null) 'explicitness': explicitness,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      if (futureUtility != null) 'future_utility': futureUtility,
      if (sensitivity != null) 'sensitivity': sensitivity,
      if (sourceTurnIdsJson != null) 'source_turn_ids_json': sourceTurnIdsJson,
      if (evidenceRole != null) 'evidence_role': evidenceRole,
      if (suggestedAction != null) 'suggested_action': suggestedAction,
      if (followUpAllowed != null) 'follow_up_allowed': followUpAllowed,
      if (proactiveAllowed != null) 'proactive_allowed': proactiveAllowed,
      if (decisionState != null) 'decision_state': decisionState,
      if (decisionReason != null) 'decision_reason': decisionReason,
      if (targetMemoryId != null) 'target_memory_id': targetMemoryId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryCandidatesCompanion copyWith({
    Value<String>? id,
    Value<String>? jobId,
    Value<String>? candidateKind,
    Value<String>? subject,
    Value<String>? predicate,
    Value<String>? objectText,
    Value<int?>? eventStartAt,
    Value<int?>? eventEndAt,
    Value<String>? temporalStatus,
    Value<String>? explicitness,
    Value<double>? confidenceScore,
    Value<double>? futureUtility,
    Value<String>? sensitivity,
    Value<String>? sourceTurnIdsJson,
    Value<String>? evidenceRole,
    Value<String>? suggestedAction,
    Value<bool>? followUpAllowed,
    Value<bool>? proactiveAllowed,
    Value<String>? decisionState,
    Value<String>? decisionReason,
    Value<String?>? targetMemoryId,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return MemoryCandidatesCompanion(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      candidateKind: candidateKind ?? this.candidateKind,
      subject: subject ?? this.subject,
      predicate: predicate ?? this.predicate,
      objectText: objectText ?? this.objectText,
      eventStartAt: eventStartAt ?? this.eventStartAt,
      eventEndAt: eventEndAt ?? this.eventEndAt,
      temporalStatus: temporalStatus ?? this.temporalStatus,
      explicitness: explicitness ?? this.explicitness,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      futureUtility: futureUtility ?? this.futureUtility,
      sensitivity: sensitivity ?? this.sensitivity,
      sourceTurnIdsJson: sourceTurnIdsJson ?? this.sourceTurnIdsJson,
      evidenceRole: evidenceRole ?? this.evidenceRole,
      suggestedAction: suggestedAction ?? this.suggestedAction,
      followUpAllowed: followUpAllowed ?? this.followUpAllowed,
      proactiveAllowed: proactiveAllowed ?? this.proactiveAllowed,
      decisionState: decisionState ?? this.decisionState,
      decisionReason: decisionReason ?? this.decisionReason,
      targetMemoryId: targetMemoryId ?? this.targetMemoryId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (candidateKind.present) {
      map['candidate_kind'] = Variable<String>(candidateKind.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (predicate.present) {
      map['predicate'] = Variable<String>(predicate.value);
    }
    if (objectText.present) {
      map['object_text'] = Variable<String>(objectText.value);
    }
    if (eventStartAt.present) {
      map['event_start_at'] = Variable<int>(eventStartAt.value);
    }
    if (eventEndAt.present) {
      map['event_end_at'] = Variable<int>(eventEndAt.value);
    }
    if (temporalStatus.present) {
      map['temporal_status'] = Variable<String>(temporalStatus.value);
    }
    if (explicitness.present) {
      map['explicitness'] = Variable<String>(explicitness.value);
    }
    if (confidenceScore.present) {
      map['confidence_score'] = Variable<double>(confidenceScore.value);
    }
    if (futureUtility.present) {
      map['future_utility'] = Variable<double>(futureUtility.value);
    }
    if (sensitivity.present) {
      map['sensitivity'] = Variable<String>(sensitivity.value);
    }
    if (sourceTurnIdsJson.present) {
      map['source_turn_ids_json'] = Variable<String>(sourceTurnIdsJson.value);
    }
    if (evidenceRole.present) {
      map['evidence_role'] = Variable<String>(evidenceRole.value);
    }
    if (suggestedAction.present) {
      map['suggested_action'] = Variable<String>(suggestedAction.value);
    }
    if (followUpAllowed.present) {
      map['follow_up_allowed'] = Variable<bool>(followUpAllowed.value);
    }
    if (proactiveAllowed.present) {
      map['proactive_allowed'] = Variable<bool>(proactiveAllowed.value);
    }
    if (decisionState.present) {
      map['decision_state'] = Variable<String>(decisionState.value);
    }
    if (decisionReason.present) {
      map['decision_reason'] = Variable<String>(decisionReason.value);
    }
    if (targetMemoryId.present) {
      map['target_memory_id'] = Variable<String>(targetMemoryId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryCandidatesCompanion(')
          ..write('id: $id, ')
          ..write('jobId: $jobId, ')
          ..write('candidateKind: $candidateKind, ')
          ..write('subject: $subject, ')
          ..write('predicate: $predicate, ')
          ..write('objectText: $objectText, ')
          ..write('eventStartAt: $eventStartAt, ')
          ..write('eventEndAt: $eventEndAt, ')
          ..write('temporalStatus: $temporalStatus, ')
          ..write('explicitness: $explicitness, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('futureUtility: $futureUtility, ')
          ..write('sensitivity: $sensitivity, ')
          ..write('sourceTurnIdsJson: $sourceTurnIdsJson, ')
          ..write('evidenceRole: $evidenceRole, ')
          ..write('suggestedAction: $suggestedAction, ')
          ..write('followUpAllowed: $followUpAllowed, ')
          ..write('proactiveAllowed: $proactiveAllowed, ')
          ..write('decisionState: $decisionState, ')
          ..write('decisionReason: $decisionReason, ')
          ..write('targetMemoryId: $targetMemoryId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ChatSessionsTable chatSessions = $ChatSessionsTable(this);
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  late final $MemoryRecordsTable memoryRecords = $MemoryRecordsTable(this);
  late final $MemoryEntitiesTable memoryEntities = $MemoryEntitiesTable(this);
  late final $MemoryEdgesTable memoryEdges = $MemoryEdgesTable(this);
  late final $MemoryContradictionsTable memoryContradictions =
      $MemoryContradictionsTable(this);
  late final $MemoryEpisodesTable memoryEpisodes = $MemoryEpisodesTable(this);
  late final $MemoryOpenThreadsTable memoryOpenThreads =
      $MemoryOpenThreadsTable(this);
  late final $MemoryExtractionJobsTable memoryExtractionJobs =
      $MemoryExtractionJobsTable(this);
  late final $MemoryCandidatesTable memoryCandidates = $MemoryCandidatesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    chatSessions,
    chatMessages,
    memoryRecords,
    memoryEntities,
    memoryEdges,
    memoryContradictions,
    memoryEpisodes,
    memoryOpenThreads,
    memoryExtractionJobs,
    memoryCandidates,
  ];
}

typedef $$ChatSessionsTableCreateCompanionBuilder =
    ChatSessionsCompanion Function({
      required String id,
      required int startedAt,
      Value<int?> endedAt,
      required String language,
      Value<int> rowid,
    });
typedef $$ChatSessionsTableUpdateCompanionBuilder =
    ChatSessionsCompanion Function({
      Value<String> id,
      Value<int> startedAt,
      Value<int?> endedAt,
      Value<String> language,
      Value<int> rowid,
    });

class $$ChatSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $ChatSessionsTable> {
  $$ChatSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatSessionsTable> {
  $$ChatSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatSessionsTable> {
  $$ChatSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);
}

class $$ChatSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatSessionsTable,
          ChatSession,
          $$ChatSessionsTableFilterComposer,
          $$ChatSessionsTableOrderingComposer,
          $$ChatSessionsTableAnnotationComposer,
          $$ChatSessionsTableCreateCompanionBuilder,
          $$ChatSessionsTableUpdateCompanionBuilder,
          (
            ChatSession,
            BaseReferences<_$AppDatabase, $ChatSessionsTable, ChatSession>,
          ),
          ChatSession,
          PrefetchHooks Function()
        > {
  $$ChatSessionsTableTableManager(_$AppDatabase db, $ChatSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<int?> endedAt = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatSessionsCompanion(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                language: language,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int startedAt,
                Value<int?> endedAt = const Value.absent(),
                required String language,
                Value<int> rowid = const Value.absent(),
              }) => ChatSessionsCompanion.insert(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                language: language,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatSessionsTable,
      ChatSession,
      $$ChatSessionsTableFilterComposer,
      $$ChatSessionsTableOrderingComposer,
      $$ChatSessionsTableAnnotationComposer,
      $$ChatSessionsTableCreateCompanionBuilder,
      $$ChatSessionsTableUpdateCompanionBuilder,
      (
        ChatSession,
        BaseReferences<_$AppDatabase, $ChatSessionsTable, ChatSession>,
      ),
      ChatSession,
      PrefetchHooks Function()
    >;
typedef $$ChatMessagesTableCreateCompanionBuilder =
    ChatMessagesCompanion Function({
      required String id,
      required String sessionId,
      required String turnId,
      required String role,
      required String messageText,
      required String status,
      required String language,
      required int createdAt,
      Value<String?> latencyJson,
      Value<double?> sttConfidence,
      Value<int> rowid,
    });
typedef $$ChatMessagesTableUpdateCompanionBuilder =
    ChatMessagesCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> turnId,
      Value<String> role,
      Value<String> messageText,
      Value<String> status,
      Value<String> language,
      Value<int> createdAt,
      Value<String?> latencyJson,
      Value<double?> sttConfidence,
      Value<int> rowid,
    });

class $$ChatMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get turnId => $composableBuilder(
    column: $table.turnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageText => $composableBuilder(
    column: $table.messageText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get latencyJson => $composableBuilder(
    column: $table.latencyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sttConfidence => $composableBuilder(
    column: $table.sttConfidence,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get turnId => $composableBuilder(
    column: $table.turnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageText => $composableBuilder(
    column: $table.messageText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get latencyJson => $composableBuilder(
    column: $table.latencyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sttConfidence => $composableBuilder(
    column: $table.sttConfidence,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get turnId =>
      $composableBuilder(column: $table.turnId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get messageText => $composableBuilder(
    column: $table.messageText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get latencyJson => $composableBuilder(
    column: $table.latencyJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sttConfidence => $composableBuilder(
    column: $table.sttConfidence,
    builder: (column) => column,
  );
}

class $$ChatMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatMessagesTable,
          ChatMessage,
          $$ChatMessagesTableFilterComposer,
          $$ChatMessagesTableOrderingComposer,
          $$ChatMessagesTableAnnotationComposer,
          $$ChatMessagesTableCreateCompanionBuilder,
          $$ChatMessagesTableUpdateCompanionBuilder,
          (
            ChatMessage,
            BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage>,
          ),
          ChatMessage,
          PrefetchHooks Function()
        > {
  $$ChatMessagesTableTableManager(_$AppDatabase db, $ChatMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> turnId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> messageText = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> latencyJson = const Value.absent(),
                Value<double?> sttConfidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion(
                id: id,
                sessionId: sessionId,
                turnId: turnId,
                role: role,
                messageText: messageText,
                status: status,
                language: language,
                createdAt: createdAt,
                latencyJson: latencyJson,
                sttConfidence: sttConfidence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String turnId,
                required String role,
                required String messageText,
                required String status,
                required String language,
                required int createdAt,
                Value<String?> latencyJson = const Value.absent(),
                Value<double?> sttConfidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion.insert(
                id: id,
                sessionId: sessionId,
                turnId: turnId,
                role: role,
                messageText: messageText,
                status: status,
                language: language,
                createdAt: createdAt,
                latencyJson: latencyJson,
                sttConfidence: sttConfidence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatMessagesTable,
      ChatMessage,
      $$ChatMessagesTableFilterComposer,
      $$ChatMessagesTableOrderingComposer,
      $$ChatMessagesTableAnnotationComposer,
      $$ChatMessagesTableCreateCompanionBuilder,
      $$ChatMessagesTableUpdateCompanionBuilder,
      (
        ChatMessage,
        BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage>,
      ),
      ChatMessage,
      PrefetchHooks Function()
    >;
typedef $$MemoryRecordsTableCreateCompanionBuilder =
    MemoryRecordsCompanion Function({
      required String id,
      required String kind,
      required String label,
      required String content,
      Value<String> originalText,
      Value<String> canonicalText,
      Value<String> language,
      Value<String> script,
      required String sourceTurnIdsJson,
      required String sourceRole,
      required String transcriptStatus,
      Value<double?> sttConfidence,
      required int createdAt,
      required int updatedAt,
      Value<int?> lastUsedAt,
      Value<int?> receiptPromptedAt,
      required double confidenceScore,
      required double importanceScore,
      Value<int> recurrenceCount,
      Value<String> sensitivity,
      Value<String> temporalStatus,
      Value<String> receiptState,
      Value<String?> supersededBy,
      Value<String?> replacementReason,
      Value<String> evidenceSummary,
      Value<int> rowid,
    });
typedef $$MemoryRecordsTableUpdateCompanionBuilder =
    MemoryRecordsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> label,
      Value<String> content,
      Value<String> originalText,
      Value<String> canonicalText,
      Value<String> language,
      Value<String> script,
      Value<String> sourceTurnIdsJson,
      Value<String> sourceRole,
      Value<String> transcriptStatus,
      Value<double?> sttConfidence,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> lastUsedAt,
      Value<int?> receiptPromptedAt,
      Value<double> confidenceScore,
      Value<double> importanceScore,
      Value<int> recurrenceCount,
      Value<String> sensitivity,
      Value<String> temporalStatus,
      Value<String> receiptState,
      Value<String?> supersededBy,
      Value<String?> replacementReason,
      Value<String> evidenceSummary,
      Value<int> rowid,
    });

class $$MemoryRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryRecordsTable> {
  $$MemoryRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalText => $composableBuilder(
    column: $table.originalText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalText => $composableBuilder(
    column: $table.canonicalText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get script => $composableBuilder(
    column: $table.script,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTurnIdsJson => $composableBuilder(
    column: $table.sourceTurnIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRole => $composableBuilder(
    column: $table.sourceRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptStatus => $composableBuilder(
    column: $table.transcriptStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sttConfidence => $composableBuilder(
    column: $table.sttConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receiptPromptedAt => $composableBuilder(
    column: $table.receiptPromptedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get importanceScore => $composableBuilder(
    column: $table.importanceScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recurrenceCount => $composableBuilder(
    column: $table.recurrenceCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get temporalStatus => $composableBuilder(
    column: $table.temporalStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptState => $composableBuilder(
    column: $table.receiptState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supersededBy => $composableBuilder(
    column: $table.supersededBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replacementReason => $composableBuilder(
    column: $table.replacementReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceSummary => $composableBuilder(
    column: $table.evidenceSummary,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemoryRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryRecordsTable> {
  $$MemoryRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalText => $composableBuilder(
    column: $table.originalText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalText => $composableBuilder(
    column: $table.canonicalText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get script => $composableBuilder(
    column: $table.script,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTurnIdsJson => $composableBuilder(
    column: $table.sourceTurnIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRole => $composableBuilder(
    column: $table.sourceRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptStatus => $composableBuilder(
    column: $table.transcriptStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sttConfidence => $composableBuilder(
    column: $table.sttConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receiptPromptedAt => $composableBuilder(
    column: $table.receiptPromptedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get importanceScore => $composableBuilder(
    column: $table.importanceScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recurrenceCount => $composableBuilder(
    column: $table.recurrenceCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get temporalStatus => $composableBuilder(
    column: $table.temporalStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptState => $composableBuilder(
    column: $table.receiptState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supersededBy => $composableBuilder(
    column: $table.supersededBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replacementReason => $composableBuilder(
    column: $table.replacementReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceSummary => $composableBuilder(
    column: $table.evidenceSummary,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoryRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryRecordsTable> {
  $$MemoryRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get originalText => $composableBuilder(
    column: $table.originalText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get canonicalText => $composableBuilder(
    column: $table.canonicalText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get script =>
      $composableBuilder(column: $table.script, builder: (column) => column);

  GeneratedColumn<String> get sourceTurnIdsJson => $composableBuilder(
    column: $table.sourceTurnIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceRole => $composableBuilder(
    column: $table.sourceRole,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcriptStatus => $composableBuilder(
    column: $table.transcriptStatus,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sttConfidence => $composableBuilder(
    column: $table.sttConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get receiptPromptedAt => $composableBuilder(
    column: $table.receiptPromptedAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get importanceScore => $composableBuilder(
    column: $table.importanceScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recurrenceCount => $composableBuilder(
    column: $table.recurrenceCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get temporalStatus => $composableBuilder(
    column: $table.temporalStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptState => $composableBuilder(
    column: $table.receiptState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get supersededBy => $composableBuilder(
    column: $table.supersededBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get replacementReason => $composableBuilder(
    column: $table.replacementReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evidenceSummary => $composableBuilder(
    column: $table.evidenceSummary,
    builder: (column) => column,
  );
}

class $$MemoryRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryRecordsTable,
          MemoryRecord,
          $$MemoryRecordsTableFilterComposer,
          $$MemoryRecordsTableOrderingComposer,
          $$MemoryRecordsTableAnnotationComposer,
          $$MemoryRecordsTableCreateCompanionBuilder,
          $$MemoryRecordsTableUpdateCompanionBuilder,
          (
            MemoryRecord,
            BaseReferences<_$AppDatabase, $MemoryRecordsTable, MemoryRecord>,
          ),
          MemoryRecord,
          PrefetchHooks Function()
        > {
  $$MemoryRecordsTableTableManager(_$AppDatabase db, $MemoryRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> originalText = const Value.absent(),
                Value<String> canonicalText = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> script = const Value.absent(),
                Value<String> sourceTurnIdsJson = const Value.absent(),
                Value<String> sourceRole = const Value.absent(),
                Value<String> transcriptStatus = const Value.absent(),
                Value<double?> sttConfidence = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> lastUsedAt = const Value.absent(),
                Value<int?> receiptPromptedAt = const Value.absent(),
                Value<double> confidenceScore = const Value.absent(),
                Value<double> importanceScore = const Value.absent(),
                Value<int> recurrenceCount = const Value.absent(),
                Value<String> sensitivity = const Value.absent(),
                Value<String> temporalStatus = const Value.absent(),
                Value<String> receiptState = const Value.absent(),
                Value<String?> supersededBy = const Value.absent(),
                Value<String?> replacementReason = const Value.absent(),
                Value<String> evidenceSummary = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryRecordsCompanion(
                id: id,
                kind: kind,
                label: label,
                content: content,
                originalText: originalText,
                canonicalText: canonicalText,
                language: language,
                script: script,
                sourceTurnIdsJson: sourceTurnIdsJson,
                sourceRole: sourceRole,
                transcriptStatus: transcriptStatus,
                sttConfidence: sttConfidence,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastUsedAt: lastUsedAt,
                receiptPromptedAt: receiptPromptedAt,
                confidenceScore: confidenceScore,
                importanceScore: importanceScore,
                recurrenceCount: recurrenceCount,
                sensitivity: sensitivity,
                temporalStatus: temporalStatus,
                receiptState: receiptState,
                supersededBy: supersededBy,
                replacementReason: replacementReason,
                evidenceSummary: evidenceSummary,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String label,
                required String content,
                Value<String> originalText = const Value.absent(),
                Value<String> canonicalText = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> script = const Value.absent(),
                required String sourceTurnIdsJson,
                required String sourceRole,
                required String transcriptStatus,
                Value<double?> sttConfidence = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> lastUsedAt = const Value.absent(),
                Value<int?> receiptPromptedAt = const Value.absent(),
                required double confidenceScore,
                required double importanceScore,
                Value<int> recurrenceCount = const Value.absent(),
                Value<String> sensitivity = const Value.absent(),
                Value<String> temporalStatus = const Value.absent(),
                Value<String> receiptState = const Value.absent(),
                Value<String?> supersededBy = const Value.absent(),
                Value<String?> replacementReason = const Value.absent(),
                Value<String> evidenceSummary = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryRecordsCompanion.insert(
                id: id,
                kind: kind,
                label: label,
                content: content,
                originalText: originalText,
                canonicalText: canonicalText,
                language: language,
                script: script,
                sourceTurnIdsJson: sourceTurnIdsJson,
                sourceRole: sourceRole,
                transcriptStatus: transcriptStatus,
                sttConfidence: sttConfidence,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastUsedAt: lastUsedAt,
                receiptPromptedAt: receiptPromptedAt,
                confidenceScore: confidenceScore,
                importanceScore: importanceScore,
                recurrenceCount: recurrenceCount,
                sensitivity: sensitivity,
                temporalStatus: temporalStatus,
                receiptState: receiptState,
                supersededBy: supersededBy,
                replacementReason: replacementReason,
                evidenceSummary: evidenceSummary,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoryRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryRecordsTable,
      MemoryRecord,
      $$MemoryRecordsTableFilterComposer,
      $$MemoryRecordsTableOrderingComposer,
      $$MemoryRecordsTableAnnotationComposer,
      $$MemoryRecordsTableCreateCompanionBuilder,
      $$MemoryRecordsTableUpdateCompanionBuilder,
      (
        MemoryRecord,
        BaseReferences<_$AppDatabase, $MemoryRecordsTable, MemoryRecord>,
      ),
      MemoryRecord,
      PrefetchHooks Function()
    >;
typedef $$MemoryEntitiesTableCreateCompanionBuilder =
    MemoryEntitiesCompanion Function({
      required String id,
      required String kind,
      required String canonicalName,
      Value<String> aliasesJson,
      Value<String> language,
      Value<String> sensitivity,
      required int firstSeenAt,
      required int lastSeenAt,
      Value<double> confidenceScore,
      Value<int> rowid,
    });
typedef $$MemoryEntitiesTableUpdateCompanionBuilder =
    MemoryEntitiesCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> canonicalName,
      Value<String> aliasesJson,
      Value<String> language,
      Value<String> sensitivity,
      Value<int> firstSeenAt,
      Value<int> lastSeenAt,
      Value<double> confidenceScore,
      Value<int> rowid,
    });

class $$MemoryEntitiesTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryEntitiesTable> {
  $$MemoryEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalName => $composableBuilder(
    column: $table.canonicalName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemoryEntitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryEntitiesTable> {
  $$MemoryEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalName => $composableBuilder(
    column: $table.canonicalName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoryEntitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryEntitiesTable> {
  $$MemoryEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get canonicalName => $composableBuilder(
    column: $table.canonicalName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => column,
  );

  GeneratedColumn<int> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => column,
  );
}

class $$MemoryEntitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryEntitiesTable,
          MemoryEntity,
          $$MemoryEntitiesTableFilterComposer,
          $$MemoryEntitiesTableOrderingComposer,
          $$MemoryEntitiesTableAnnotationComposer,
          $$MemoryEntitiesTableCreateCompanionBuilder,
          $$MemoryEntitiesTableUpdateCompanionBuilder,
          (
            MemoryEntity,
            BaseReferences<_$AppDatabase, $MemoryEntitiesTable, MemoryEntity>,
          ),
          MemoryEntity,
          PrefetchHooks Function()
        > {
  $$MemoryEntitiesTableTableManager(
    _$AppDatabase db,
    $MemoryEntitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryEntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> canonicalName = const Value.absent(),
                Value<String> aliasesJson = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> sensitivity = const Value.absent(),
                Value<int> firstSeenAt = const Value.absent(),
                Value<int> lastSeenAt = const Value.absent(),
                Value<double> confidenceScore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryEntitiesCompanion(
                id: id,
                kind: kind,
                canonicalName: canonicalName,
                aliasesJson: aliasesJson,
                language: language,
                sensitivity: sensitivity,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                confidenceScore: confidenceScore,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String canonicalName,
                Value<String> aliasesJson = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> sensitivity = const Value.absent(),
                required int firstSeenAt,
                required int lastSeenAt,
                Value<double> confidenceScore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryEntitiesCompanion.insert(
                id: id,
                kind: kind,
                canonicalName: canonicalName,
                aliasesJson: aliasesJson,
                language: language,
                sensitivity: sensitivity,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                confidenceScore: confidenceScore,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoryEntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryEntitiesTable,
      MemoryEntity,
      $$MemoryEntitiesTableFilterComposer,
      $$MemoryEntitiesTableOrderingComposer,
      $$MemoryEntitiesTableAnnotationComposer,
      $$MemoryEntitiesTableCreateCompanionBuilder,
      $$MemoryEntitiesTableUpdateCompanionBuilder,
      (
        MemoryEntity,
        BaseReferences<_$AppDatabase, $MemoryEntitiesTable, MemoryEntity>,
      ),
      MemoryEntity,
      PrefetchHooks Function()
    >;
typedef $$MemoryEdgesTableCreateCompanionBuilder =
    MemoryEdgesCompanion Function({
      required String id,
      required String sourceEntityId,
      required String relation,
      required String targetEntityId,
      Value<String> evidenceTurnIdsJson,
      Value<double> confidenceScore,
      Value<int> frequency,
      Value<String> polarity,
      Value<String> sensitivity,
      Value<String> temporalStatus,
      required int firstSeenAt,
      required int lastSeenAt,
      Value<int> rowid,
    });
typedef $$MemoryEdgesTableUpdateCompanionBuilder =
    MemoryEdgesCompanion Function({
      Value<String> id,
      Value<String> sourceEntityId,
      Value<String> relation,
      Value<String> targetEntityId,
      Value<String> evidenceTurnIdsJson,
      Value<double> confidenceScore,
      Value<int> frequency,
      Value<String> polarity,
      Value<String> sensitivity,
      Value<String> temporalStatus,
      Value<int> firstSeenAt,
      Value<int> lastSeenAt,
      Value<int> rowid,
    });

class $$MemoryEdgesTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryEdgesTable> {
  $$MemoryEdgesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceEntityId => $composableBuilder(
    column: $table.sourceEntityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetEntityId => $composableBuilder(
    column: $table.targetEntityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceTurnIdsJson => $composableBuilder(
    column: $table.evidenceTurnIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get polarity => $composableBuilder(
    column: $table.polarity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get temporalStatus => $composableBuilder(
    column: $table.temporalStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemoryEdgesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryEdgesTable> {
  $$MemoryEdgesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceEntityId => $composableBuilder(
    column: $table.sourceEntityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetEntityId => $composableBuilder(
    column: $table.targetEntityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceTurnIdsJson => $composableBuilder(
    column: $table.evidenceTurnIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get polarity => $composableBuilder(
    column: $table.polarity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get temporalStatus => $composableBuilder(
    column: $table.temporalStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoryEdgesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryEdgesTable> {
  $$MemoryEdgesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceEntityId => $composableBuilder(
    column: $table.sourceEntityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relation =>
      $composableBuilder(column: $table.relation, builder: (column) => column);

  GeneratedColumn<String> get targetEntityId => $composableBuilder(
    column: $table.targetEntityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evidenceTurnIdsJson => $composableBuilder(
    column: $table.evidenceTurnIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<String> get polarity =>
      $composableBuilder(column: $table.polarity, builder: (column) => column);

  GeneratedColumn<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get temporalStatus => $composableBuilder(
    column: $table.temporalStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );
}

class $$MemoryEdgesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryEdgesTable,
          MemoryEdge,
          $$MemoryEdgesTableFilterComposer,
          $$MemoryEdgesTableOrderingComposer,
          $$MemoryEdgesTableAnnotationComposer,
          $$MemoryEdgesTableCreateCompanionBuilder,
          $$MemoryEdgesTableUpdateCompanionBuilder,
          (
            MemoryEdge,
            BaseReferences<_$AppDatabase, $MemoryEdgesTable, MemoryEdge>,
          ),
          MemoryEdge,
          PrefetchHooks Function()
        > {
  $$MemoryEdgesTableTableManager(_$AppDatabase db, $MemoryEdgesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryEdgesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryEdgesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryEdgesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceEntityId = const Value.absent(),
                Value<String> relation = const Value.absent(),
                Value<String> targetEntityId = const Value.absent(),
                Value<String> evidenceTurnIdsJson = const Value.absent(),
                Value<double> confidenceScore = const Value.absent(),
                Value<int> frequency = const Value.absent(),
                Value<String> polarity = const Value.absent(),
                Value<String> sensitivity = const Value.absent(),
                Value<String> temporalStatus = const Value.absent(),
                Value<int> firstSeenAt = const Value.absent(),
                Value<int> lastSeenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryEdgesCompanion(
                id: id,
                sourceEntityId: sourceEntityId,
                relation: relation,
                targetEntityId: targetEntityId,
                evidenceTurnIdsJson: evidenceTurnIdsJson,
                confidenceScore: confidenceScore,
                frequency: frequency,
                polarity: polarity,
                sensitivity: sensitivity,
                temporalStatus: temporalStatus,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceEntityId,
                required String relation,
                required String targetEntityId,
                Value<String> evidenceTurnIdsJson = const Value.absent(),
                Value<double> confidenceScore = const Value.absent(),
                Value<int> frequency = const Value.absent(),
                Value<String> polarity = const Value.absent(),
                Value<String> sensitivity = const Value.absent(),
                Value<String> temporalStatus = const Value.absent(),
                required int firstSeenAt,
                required int lastSeenAt,
                Value<int> rowid = const Value.absent(),
              }) => MemoryEdgesCompanion.insert(
                id: id,
                sourceEntityId: sourceEntityId,
                relation: relation,
                targetEntityId: targetEntityId,
                evidenceTurnIdsJson: evidenceTurnIdsJson,
                confidenceScore: confidenceScore,
                frequency: frequency,
                polarity: polarity,
                sensitivity: sensitivity,
                temporalStatus: temporalStatus,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoryEdgesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryEdgesTable,
      MemoryEdge,
      $$MemoryEdgesTableFilterComposer,
      $$MemoryEdgesTableOrderingComposer,
      $$MemoryEdgesTableAnnotationComposer,
      $$MemoryEdgesTableCreateCompanionBuilder,
      $$MemoryEdgesTableUpdateCompanionBuilder,
      (
        MemoryEdge,
        BaseReferences<_$AppDatabase, $MemoryEdgesTable, MemoryEdge>,
      ),
      MemoryEdge,
      PrefetchHooks Function()
    >;
typedef $$MemoryContradictionsTableCreateCompanionBuilder =
    MemoryContradictionsCompanion Function({
      required String id,
      required String oldMemoryId,
      required String newMemoryId,
      required String reason,
      Value<String> evidenceTurnIdsJson,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$MemoryContradictionsTableUpdateCompanionBuilder =
    MemoryContradictionsCompanion Function({
      Value<String> id,
      Value<String> oldMemoryId,
      Value<String> newMemoryId,
      Value<String> reason,
      Value<String> evidenceTurnIdsJson,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$MemoryContradictionsTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryContradictionsTable> {
  $$MemoryContradictionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldMemoryId => $composableBuilder(
    column: $table.oldMemoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newMemoryId => $composableBuilder(
    column: $table.newMemoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceTurnIdsJson => $composableBuilder(
    column: $table.evidenceTurnIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemoryContradictionsTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryContradictionsTable> {
  $$MemoryContradictionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldMemoryId => $composableBuilder(
    column: $table.oldMemoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newMemoryId => $composableBuilder(
    column: $table.newMemoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceTurnIdsJson => $composableBuilder(
    column: $table.evidenceTurnIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoryContradictionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryContradictionsTable> {
  $$MemoryContradictionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get oldMemoryId => $composableBuilder(
    column: $table.oldMemoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get newMemoryId => $composableBuilder(
    column: $table.newMemoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get evidenceTurnIdsJson => $composableBuilder(
    column: $table.evidenceTurnIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MemoryContradictionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryContradictionsTable,
          MemoryContradiction,
          $$MemoryContradictionsTableFilterComposer,
          $$MemoryContradictionsTableOrderingComposer,
          $$MemoryContradictionsTableAnnotationComposer,
          $$MemoryContradictionsTableCreateCompanionBuilder,
          $$MemoryContradictionsTableUpdateCompanionBuilder,
          (
            MemoryContradiction,
            BaseReferences<
              _$AppDatabase,
              $MemoryContradictionsTable,
              MemoryContradiction
            >,
          ),
          MemoryContradiction,
          PrefetchHooks Function()
        > {
  $$MemoryContradictionsTableTableManager(
    _$AppDatabase db,
    $MemoryContradictionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryContradictionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryContradictionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MemoryContradictionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> oldMemoryId = const Value.absent(),
                Value<String> newMemoryId = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String> evidenceTurnIdsJson = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryContradictionsCompanion(
                id: id,
                oldMemoryId: oldMemoryId,
                newMemoryId: newMemoryId,
                reason: reason,
                evidenceTurnIdsJson: evidenceTurnIdsJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String oldMemoryId,
                required String newMemoryId,
                required String reason,
                Value<String> evidenceTurnIdsJson = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MemoryContradictionsCompanion.insert(
                id: id,
                oldMemoryId: oldMemoryId,
                newMemoryId: newMemoryId,
                reason: reason,
                evidenceTurnIdsJson: evidenceTurnIdsJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoryContradictionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryContradictionsTable,
      MemoryContradiction,
      $$MemoryContradictionsTableFilterComposer,
      $$MemoryContradictionsTableOrderingComposer,
      $$MemoryContradictionsTableAnnotationComposer,
      $$MemoryContradictionsTableCreateCompanionBuilder,
      $$MemoryContradictionsTableUpdateCompanionBuilder,
      (
        MemoryContradiction,
        BaseReferences<
          _$AppDatabase,
          $MemoryContradictionsTable,
          MemoryContradiction
        >,
      ),
      MemoryContradiction,
      PrefetchHooks Function()
    >;
typedef $$MemoryEpisodesTableCreateCompanionBuilder =
    MemoryEpisodesCompanion Function({
      required String id,
      required String sessionId,
      required String title,
      required String summary,
      required String retrievalText,
      required String sourceTurnIdsJson,
      Value<String> entityIdsJson,
      Value<String> topicKeysJson,
      Value<int?> eventStartAt,
      Value<int?> eventEndAt,
      Value<String> temporalStatus,
      Value<String> explicitness,
      required double confidenceScore,
      required double importanceScore,
      Value<String> sensitivity,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$MemoryEpisodesTableUpdateCompanionBuilder =
    MemoryEpisodesCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> title,
      Value<String> summary,
      Value<String> retrievalText,
      Value<String> sourceTurnIdsJson,
      Value<String> entityIdsJson,
      Value<String> topicKeysJson,
      Value<int?> eventStartAt,
      Value<int?> eventEndAt,
      Value<String> temporalStatus,
      Value<String> explicitness,
      Value<double> confidenceScore,
      Value<double> importanceScore,
      Value<String> sensitivity,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$MemoryEpisodesTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryEpisodesTable> {
  $$MemoryEpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get retrievalText => $composableBuilder(
    column: $table.retrievalText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTurnIdsJson => $composableBuilder(
    column: $table.sourceTurnIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityIdsJson => $composableBuilder(
    column: $table.entityIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topicKeysJson => $composableBuilder(
    column: $table.topicKeysJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eventStartAt => $composableBuilder(
    column: $table.eventStartAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eventEndAt => $composableBuilder(
    column: $table.eventEndAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get temporalStatus => $composableBuilder(
    column: $table.temporalStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explicitness => $composableBuilder(
    column: $table.explicitness,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get importanceScore => $composableBuilder(
    column: $table.importanceScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemoryEpisodesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryEpisodesTable> {
  $$MemoryEpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get retrievalText => $composableBuilder(
    column: $table.retrievalText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTurnIdsJson => $composableBuilder(
    column: $table.sourceTurnIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityIdsJson => $composableBuilder(
    column: $table.entityIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topicKeysJson => $composableBuilder(
    column: $table.topicKeysJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eventStartAt => $composableBuilder(
    column: $table.eventStartAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eventEndAt => $composableBuilder(
    column: $table.eventEndAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get temporalStatus => $composableBuilder(
    column: $table.temporalStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explicitness => $composableBuilder(
    column: $table.explicitness,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get importanceScore => $composableBuilder(
    column: $table.importanceScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoryEpisodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryEpisodesTable> {
  $$MemoryEpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get retrievalText => $composableBuilder(
    column: $table.retrievalText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceTurnIdsJson => $composableBuilder(
    column: $table.sourceTurnIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityIdsJson => $composableBuilder(
    column: $table.entityIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get topicKeysJson => $composableBuilder(
    column: $table.topicKeysJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get eventStartAt => $composableBuilder(
    column: $table.eventStartAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get eventEndAt => $composableBuilder(
    column: $table.eventEndAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get temporalStatus => $composableBuilder(
    column: $table.temporalStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get explicitness => $composableBuilder(
    column: $table.explicitness,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get importanceScore => $composableBuilder(
    column: $table.importanceScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MemoryEpisodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryEpisodesTable,
          MemoryEpisode,
          $$MemoryEpisodesTableFilterComposer,
          $$MemoryEpisodesTableOrderingComposer,
          $$MemoryEpisodesTableAnnotationComposer,
          $$MemoryEpisodesTableCreateCompanionBuilder,
          $$MemoryEpisodesTableUpdateCompanionBuilder,
          (
            MemoryEpisode,
            BaseReferences<_$AppDatabase, $MemoryEpisodesTable, MemoryEpisode>,
          ),
          MemoryEpisode,
          PrefetchHooks Function()
        > {
  $$MemoryEpisodesTableTableManager(
    _$AppDatabase db,
    $MemoryEpisodesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryEpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryEpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryEpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> retrievalText = const Value.absent(),
                Value<String> sourceTurnIdsJson = const Value.absent(),
                Value<String> entityIdsJson = const Value.absent(),
                Value<String> topicKeysJson = const Value.absent(),
                Value<int?> eventStartAt = const Value.absent(),
                Value<int?> eventEndAt = const Value.absent(),
                Value<String> temporalStatus = const Value.absent(),
                Value<String> explicitness = const Value.absent(),
                Value<double> confidenceScore = const Value.absent(),
                Value<double> importanceScore = const Value.absent(),
                Value<String> sensitivity = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryEpisodesCompanion(
                id: id,
                sessionId: sessionId,
                title: title,
                summary: summary,
                retrievalText: retrievalText,
                sourceTurnIdsJson: sourceTurnIdsJson,
                entityIdsJson: entityIdsJson,
                topicKeysJson: topicKeysJson,
                eventStartAt: eventStartAt,
                eventEndAt: eventEndAt,
                temporalStatus: temporalStatus,
                explicitness: explicitness,
                confidenceScore: confidenceScore,
                importanceScore: importanceScore,
                sensitivity: sensitivity,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String title,
                required String summary,
                required String retrievalText,
                required String sourceTurnIdsJson,
                Value<String> entityIdsJson = const Value.absent(),
                Value<String> topicKeysJson = const Value.absent(),
                Value<int?> eventStartAt = const Value.absent(),
                Value<int?> eventEndAt = const Value.absent(),
                Value<String> temporalStatus = const Value.absent(),
                Value<String> explicitness = const Value.absent(),
                required double confidenceScore,
                required double importanceScore,
                Value<String> sensitivity = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MemoryEpisodesCompanion.insert(
                id: id,
                sessionId: sessionId,
                title: title,
                summary: summary,
                retrievalText: retrievalText,
                sourceTurnIdsJson: sourceTurnIdsJson,
                entityIdsJson: entityIdsJson,
                topicKeysJson: topicKeysJson,
                eventStartAt: eventStartAt,
                eventEndAt: eventEndAt,
                temporalStatus: temporalStatus,
                explicitness: explicitness,
                confidenceScore: confidenceScore,
                importanceScore: importanceScore,
                sensitivity: sensitivity,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoryEpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryEpisodesTable,
      MemoryEpisode,
      $$MemoryEpisodesTableFilterComposer,
      $$MemoryEpisodesTableOrderingComposer,
      $$MemoryEpisodesTableAnnotationComposer,
      $$MemoryEpisodesTableCreateCompanionBuilder,
      $$MemoryEpisodesTableUpdateCompanionBuilder,
      (
        MemoryEpisode,
        BaseReferences<_$AppDatabase, $MemoryEpisodesTable, MemoryEpisode>,
      ),
      MemoryEpisode,
      PrefetchHooks Function()
    >;
typedef $$MemoryOpenThreadsTableCreateCompanionBuilder =
    MemoryOpenThreadsCompanion Function({
      required String id,
      Value<String?> episodeId,
      required String kind,
      required String subject,
      required String predicate,
      required String objectText,
      Value<int?> dueStartAt,
      Value<int?> dueEndAt,
      Value<String> status,
      Value<bool> followUpAllowed,
      Value<bool> proactiveAllowed,
      required String sourceTurnIdsJson,
      required double confidenceScore,
      Value<String> sensitivity,
      required int createdAt,
      required int updatedAt,
      Value<int?> closedAt,
      Value<int> rowid,
    });
typedef $$MemoryOpenThreadsTableUpdateCompanionBuilder =
    MemoryOpenThreadsCompanion Function({
      Value<String> id,
      Value<String?> episodeId,
      Value<String> kind,
      Value<String> subject,
      Value<String> predicate,
      Value<String> objectText,
      Value<int?> dueStartAt,
      Value<int?> dueEndAt,
      Value<String> status,
      Value<bool> followUpAllowed,
      Value<bool> proactiveAllowed,
      Value<String> sourceTurnIdsJson,
      Value<double> confidenceScore,
      Value<String> sensitivity,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> closedAt,
      Value<int> rowid,
    });

class $$MemoryOpenThreadsTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryOpenThreadsTable> {
  $$MemoryOpenThreadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get predicate => $composableBuilder(
    column: $table.predicate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objectText => $composableBuilder(
    column: $table.objectText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueStartAt => $composableBuilder(
    column: $table.dueStartAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueEndAt => $composableBuilder(
    column: $table.dueEndAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get followUpAllowed => $composableBuilder(
    column: $table.followUpAllowed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get proactiveAllowed => $composableBuilder(
    column: $table.proactiveAllowed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTurnIdsJson => $composableBuilder(
    column: $table.sourceTurnIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemoryOpenThreadsTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryOpenThreadsTable> {
  $$MemoryOpenThreadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get predicate => $composableBuilder(
    column: $table.predicate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objectText => $composableBuilder(
    column: $table.objectText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueStartAt => $composableBuilder(
    column: $table.dueStartAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueEndAt => $composableBuilder(
    column: $table.dueEndAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get followUpAllowed => $composableBuilder(
    column: $table.followUpAllowed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get proactiveAllowed => $composableBuilder(
    column: $table.proactiveAllowed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTurnIdsJson => $composableBuilder(
    column: $table.sourceTurnIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoryOpenThreadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryOpenThreadsTable> {
  $$MemoryOpenThreadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get episodeId =>
      $composableBuilder(column: $table.episodeId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get predicate =>
      $composableBuilder(column: $table.predicate, builder: (column) => column);

  GeneratedColumn<String> get objectText => $composableBuilder(
    column: $table.objectText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueStartAt => $composableBuilder(
    column: $table.dueStartAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueEndAt =>
      $composableBuilder(column: $table.dueEndAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get followUpAllowed => $composableBuilder(
    column: $table.followUpAllowed,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get proactiveAllowed => $composableBuilder(
    column: $table.proactiveAllowed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceTurnIdsJson => $composableBuilder(
    column: $table.sourceTurnIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);
}

class $$MemoryOpenThreadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryOpenThreadsTable,
          MemoryOpenThread,
          $$MemoryOpenThreadsTableFilterComposer,
          $$MemoryOpenThreadsTableOrderingComposer,
          $$MemoryOpenThreadsTableAnnotationComposer,
          $$MemoryOpenThreadsTableCreateCompanionBuilder,
          $$MemoryOpenThreadsTableUpdateCompanionBuilder,
          (
            MemoryOpenThread,
            BaseReferences<
              _$AppDatabase,
              $MemoryOpenThreadsTable,
              MemoryOpenThread
            >,
          ),
          MemoryOpenThread,
          PrefetchHooks Function()
        > {
  $$MemoryOpenThreadsTableTableManager(
    _$AppDatabase db,
    $MemoryOpenThreadsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryOpenThreadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryOpenThreadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryOpenThreadsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> episodeId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String> predicate = const Value.absent(),
                Value<String> objectText = const Value.absent(),
                Value<int?> dueStartAt = const Value.absent(),
                Value<int?> dueEndAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> followUpAllowed = const Value.absent(),
                Value<bool> proactiveAllowed = const Value.absent(),
                Value<String> sourceTurnIdsJson = const Value.absent(),
                Value<double> confidenceScore = const Value.absent(),
                Value<String> sensitivity = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> closedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryOpenThreadsCompanion(
                id: id,
                episodeId: episodeId,
                kind: kind,
                subject: subject,
                predicate: predicate,
                objectText: objectText,
                dueStartAt: dueStartAt,
                dueEndAt: dueEndAt,
                status: status,
                followUpAllowed: followUpAllowed,
                proactiveAllowed: proactiveAllowed,
                sourceTurnIdsJson: sourceTurnIdsJson,
                confidenceScore: confidenceScore,
                sensitivity: sensitivity,
                createdAt: createdAt,
                updatedAt: updatedAt,
                closedAt: closedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> episodeId = const Value.absent(),
                required String kind,
                required String subject,
                required String predicate,
                required String objectText,
                Value<int?> dueStartAt = const Value.absent(),
                Value<int?> dueEndAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> followUpAllowed = const Value.absent(),
                Value<bool> proactiveAllowed = const Value.absent(),
                required String sourceTurnIdsJson,
                required double confidenceScore,
                Value<String> sensitivity = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> closedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryOpenThreadsCompanion.insert(
                id: id,
                episodeId: episodeId,
                kind: kind,
                subject: subject,
                predicate: predicate,
                objectText: objectText,
                dueStartAt: dueStartAt,
                dueEndAt: dueEndAt,
                status: status,
                followUpAllowed: followUpAllowed,
                proactiveAllowed: proactiveAllowed,
                sourceTurnIdsJson: sourceTurnIdsJson,
                confidenceScore: confidenceScore,
                sensitivity: sensitivity,
                createdAt: createdAt,
                updatedAt: updatedAt,
                closedAt: closedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoryOpenThreadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryOpenThreadsTable,
      MemoryOpenThread,
      $$MemoryOpenThreadsTableFilterComposer,
      $$MemoryOpenThreadsTableOrderingComposer,
      $$MemoryOpenThreadsTableAnnotationComposer,
      $$MemoryOpenThreadsTableCreateCompanionBuilder,
      $$MemoryOpenThreadsTableUpdateCompanionBuilder,
      (
        MemoryOpenThread,
        BaseReferences<
          _$AppDatabase,
          $MemoryOpenThreadsTable,
          MemoryOpenThread
        >,
      ),
      MemoryOpenThread,
      PrefetchHooks Function()
    >;
typedef $$MemoryExtractionJobsTableCreateCompanionBuilder =
    MemoryExtractionJobsCompanion Function({
      required String id,
      required String sessionId,
      required String startTurnId,
      required String endTurnId,
      Value<String> status,
      Value<int> attempts,
      required String extractionVersion,
      required String requestHash,
      Value<String?> lastErrorCode,
      Value<int?> nextAttemptAt,
      required int createdAt,
      required int updatedAt,
      Value<int?> completedAt,
      Value<int> rowid,
    });
typedef $$MemoryExtractionJobsTableUpdateCompanionBuilder =
    MemoryExtractionJobsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> startTurnId,
      Value<String> endTurnId,
      Value<String> status,
      Value<int> attempts,
      Value<String> extractionVersion,
      Value<String> requestHash,
      Value<String?> lastErrorCode,
      Value<int?> nextAttemptAt,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> completedAt,
      Value<int> rowid,
    });

class $$MemoryExtractionJobsTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryExtractionJobsTable> {
  $$MemoryExtractionJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startTurnId => $composableBuilder(
    column: $table.startTurnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endTurnId => $composableBuilder(
    column: $table.endTurnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extractionVersion => $composableBuilder(
    column: $table.extractionVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestHash => $composableBuilder(
    column: $table.requestHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemoryExtractionJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryExtractionJobsTable> {
  $$MemoryExtractionJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startTurnId => $composableBuilder(
    column: $table.startTurnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endTurnId => $composableBuilder(
    column: $table.endTurnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extractionVersion => $composableBuilder(
    column: $table.extractionVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestHash => $composableBuilder(
    column: $table.requestHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoryExtractionJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryExtractionJobsTable> {
  $$MemoryExtractionJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get startTurnId => $composableBuilder(
    column: $table.startTurnId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endTurnId =>
      $composableBuilder(column: $table.endTurnId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get extractionVersion => $composableBuilder(
    column: $table.extractionVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get requestHash => $composableBuilder(
    column: $table.requestHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$MemoryExtractionJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryExtractionJobsTable,
          MemoryExtractionJob,
          $$MemoryExtractionJobsTableFilterComposer,
          $$MemoryExtractionJobsTableOrderingComposer,
          $$MemoryExtractionJobsTableAnnotationComposer,
          $$MemoryExtractionJobsTableCreateCompanionBuilder,
          $$MemoryExtractionJobsTableUpdateCompanionBuilder,
          (
            MemoryExtractionJob,
            BaseReferences<
              _$AppDatabase,
              $MemoryExtractionJobsTable,
              MemoryExtractionJob
            >,
          ),
          MemoryExtractionJob,
          PrefetchHooks Function()
        > {
  $$MemoryExtractionJobsTableTableManager(
    _$AppDatabase db,
    $MemoryExtractionJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryExtractionJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryExtractionJobsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MemoryExtractionJobsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> startTurnId = const Value.absent(),
                Value<String> endTurnId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String> extractionVersion = const Value.absent(),
                Value<String> requestHash = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<int?> nextAttemptAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryExtractionJobsCompanion(
                id: id,
                sessionId: sessionId,
                startTurnId: startTurnId,
                endTurnId: endTurnId,
                status: status,
                attempts: attempts,
                extractionVersion: extractionVersion,
                requestHash: requestHash,
                lastErrorCode: lastErrorCode,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String startTurnId,
                required String endTurnId,
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                required String extractionVersion,
                required String requestHash,
                Value<String?> lastErrorCode = const Value.absent(),
                Value<int?> nextAttemptAt = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryExtractionJobsCompanion.insert(
                id: id,
                sessionId: sessionId,
                startTurnId: startTurnId,
                endTurnId: endTurnId,
                status: status,
                attempts: attempts,
                extractionVersion: extractionVersion,
                requestHash: requestHash,
                lastErrorCode: lastErrorCode,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoryExtractionJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryExtractionJobsTable,
      MemoryExtractionJob,
      $$MemoryExtractionJobsTableFilterComposer,
      $$MemoryExtractionJobsTableOrderingComposer,
      $$MemoryExtractionJobsTableAnnotationComposer,
      $$MemoryExtractionJobsTableCreateCompanionBuilder,
      $$MemoryExtractionJobsTableUpdateCompanionBuilder,
      (
        MemoryExtractionJob,
        BaseReferences<
          _$AppDatabase,
          $MemoryExtractionJobsTable,
          MemoryExtractionJob
        >,
      ),
      MemoryExtractionJob,
      PrefetchHooks Function()
    >;
typedef $$MemoryCandidatesTableCreateCompanionBuilder =
    MemoryCandidatesCompanion Function({
      required String id,
      required String jobId,
      required String candidateKind,
      required String subject,
      required String predicate,
      required String objectText,
      Value<int?> eventStartAt,
      Value<int?> eventEndAt,
      required String temporalStatus,
      required String explicitness,
      required double confidenceScore,
      required double futureUtility,
      required String sensitivity,
      required String sourceTurnIdsJson,
      required String evidenceRole,
      required String suggestedAction,
      Value<bool> followUpAllowed,
      Value<bool> proactiveAllowed,
      required String decisionState,
      required String decisionReason,
      Value<String?> targetMemoryId,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$MemoryCandidatesTableUpdateCompanionBuilder =
    MemoryCandidatesCompanion Function({
      Value<String> id,
      Value<String> jobId,
      Value<String> candidateKind,
      Value<String> subject,
      Value<String> predicate,
      Value<String> objectText,
      Value<int?> eventStartAt,
      Value<int?> eventEndAt,
      Value<String> temporalStatus,
      Value<String> explicitness,
      Value<double> confidenceScore,
      Value<double> futureUtility,
      Value<String> sensitivity,
      Value<String> sourceTurnIdsJson,
      Value<String> evidenceRole,
      Value<String> suggestedAction,
      Value<bool> followUpAllowed,
      Value<bool> proactiveAllowed,
      Value<String> decisionState,
      Value<String> decisionReason,
      Value<String?> targetMemoryId,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$MemoryCandidatesTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryCandidatesTable> {
  $$MemoryCandidatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get candidateKind => $composableBuilder(
    column: $table.candidateKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get predicate => $composableBuilder(
    column: $table.predicate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objectText => $composableBuilder(
    column: $table.objectText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eventStartAt => $composableBuilder(
    column: $table.eventStartAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eventEndAt => $composableBuilder(
    column: $table.eventEndAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get temporalStatus => $composableBuilder(
    column: $table.temporalStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explicitness => $composableBuilder(
    column: $table.explicitness,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get futureUtility => $composableBuilder(
    column: $table.futureUtility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTurnIdsJson => $composableBuilder(
    column: $table.sourceTurnIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceRole => $composableBuilder(
    column: $table.evidenceRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedAction => $composableBuilder(
    column: $table.suggestedAction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get followUpAllowed => $composableBuilder(
    column: $table.followUpAllowed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get proactiveAllowed => $composableBuilder(
    column: $table.proactiveAllowed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decisionState => $composableBuilder(
    column: $table.decisionState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decisionReason => $composableBuilder(
    column: $table.decisionReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetMemoryId => $composableBuilder(
    column: $table.targetMemoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemoryCandidatesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryCandidatesTable> {
  $$MemoryCandidatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get candidateKind => $composableBuilder(
    column: $table.candidateKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get predicate => $composableBuilder(
    column: $table.predicate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objectText => $composableBuilder(
    column: $table.objectText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eventStartAt => $composableBuilder(
    column: $table.eventStartAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eventEndAt => $composableBuilder(
    column: $table.eventEndAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get temporalStatus => $composableBuilder(
    column: $table.temporalStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explicitness => $composableBuilder(
    column: $table.explicitness,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get futureUtility => $composableBuilder(
    column: $table.futureUtility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTurnIdsJson => $composableBuilder(
    column: $table.sourceTurnIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceRole => $composableBuilder(
    column: $table.evidenceRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedAction => $composableBuilder(
    column: $table.suggestedAction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get followUpAllowed => $composableBuilder(
    column: $table.followUpAllowed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get proactiveAllowed => $composableBuilder(
    column: $table.proactiveAllowed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decisionState => $composableBuilder(
    column: $table.decisionState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decisionReason => $composableBuilder(
    column: $table.decisionReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetMemoryId => $composableBuilder(
    column: $table.targetMemoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoryCandidatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryCandidatesTable> {
  $$MemoryCandidatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<String> get candidateKind => $composableBuilder(
    column: $table.candidateKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get predicate =>
      $composableBuilder(column: $table.predicate, builder: (column) => column);

  GeneratedColumn<String> get objectText => $composableBuilder(
    column: $table.objectText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get eventStartAt => $composableBuilder(
    column: $table.eventStartAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get eventEndAt => $composableBuilder(
    column: $table.eventEndAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get temporalStatus => $composableBuilder(
    column: $table.temporalStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get explicitness => $composableBuilder(
    column: $table.explicitness,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get futureUtility => $composableBuilder(
    column: $table.futureUtility,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sensitivity => $composableBuilder(
    column: $table.sensitivity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceTurnIdsJson => $composableBuilder(
    column: $table.sourceTurnIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evidenceRole => $composableBuilder(
    column: $table.evidenceRole,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedAction => $composableBuilder(
    column: $table.suggestedAction,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get followUpAllowed => $composableBuilder(
    column: $table.followUpAllowed,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get proactiveAllowed => $composableBuilder(
    column: $table.proactiveAllowed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get decisionState => $composableBuilder(
    column: $table.decisionState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get decisionReason => $composableBuilder(
    column: $table.decisionReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetMemoryId => $composableBuilder(
    column: $table.targetMemoryId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MemoryCandidatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryCandidatesTable,
          MemoryCandidate,
          $$MemoryCandidatesTableFilterComposer,
          $$MemoryCandidatesTableOrderingComposer,
          $$MemoryCandidatesTableAnnotationComposer,
          $$MemoryCandidatesTableCreateCompanionBuilder,
          $$MemoryCandidatesTableUpdateCompanionBuilder,
          (
            MemoryCandidate,
            BaseReferences<
              _$AppDatabase,
              $MemoryCandidatesTable,
              MemoryCandidate
            >,
          ),
          MemoryCandidate,
          PrefetchHooks Function()
        > {
  $$MemoryCandidatesTableTableManager(
    _$AppDatabase db,
    $MemoryCandidatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryCandidatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryCandidatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryCandidatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> jobId = const Value.absent(),
                Value<String> candidateKind = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String> predicate = const Value.absent(),
                Value<String> objectText = const Value.absent(),
                Value<int?> eventStartAt = const Value.absent(),
                Value<int?> eventEndAt = const Value.absent(),
                Value<String> temporalStatus = const Value.absent(),
                Value<String> explicitness = const Value.absent(),
                Value<double> confidenceScore = const Value.absent(),
                Value<double> futureUtility = const Value.absent(),
                Value<String> sensitivity = const Value.absent(),
                Value<String> sourceTurnIdsJson = const Value.absent(),
                Value<String> evidenceRole = const Value.absent(),
                Value<String> suggestedAction = const Value.absent(),
                Value<bool> followUpAllowed = const Value.absent(),
                Value<bool> proactiveAllowed = const Value.absent(),
                Value<String> decisionState = const Value.absent(),
                Value<String> decisionReason = const Value.absent(),
                Value<String?> targetMemoryId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryCandidatesCompanion(
                id: id,
                jobId: jobId,
                candidateKind: candidateKind,
                subject: subject,
                predicate: predicate,
                objectText: objectText,
                eventStartAt: eventStartAt,
                eventEndAt: eventEndAt,
                temporalStatus: temporalStatus,
                explicitness: explicitness,
                confidenceScore: confidenceScore,
                futureUtility: futureUtility,
                sensitivity: sensitivity,
                sourceTurnIdsJson: sourceTurnIdsJson,
                evidenceRole: evidenceRole,
                suggestedAction: suggestedAction,
                followUpAllowed: followUpAllowed,
                proactiveAllowed: proactiveAllowed,
                decisionState: decisionState,
                decisionReason: decisionReason,
                targetMemoryId: targetMemoryId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String jobId,
                required String candidateKind,
                required String subject,
                required String predicate,
                required String objectText,
                Value<int?> eventStartAt = const Value.absent(),
                Value<int?> eventEndAt = const Value.absent(),
                required String temporalStatus,
                required String explicitness,
                required double confidenceScore,
                required double futureUtility,
                required String sensitivity,
                required String sourceTurnIdsJson,
                required String evidenceRole,
                required String suggestedAction,
                Value<bool> followUpAllowed = const Value.absent(),
                Value<bool> proactiveAllowed = const Value.absent(),
                required String decisionState,
                required String decisionReason,
                Value<String?> targetMemoryId = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MemoryCandidatesCompanion.insert(
                id: id,
                jobId: jobId,
                candidateKind: candidateKind,
                subject: subject,
                predicate: predicate,
                objectText: objectText,
                eventStartAt: eventStartAt,
                eventEndAt: eventEndAt,
                temporalStatus: temporalStatus,
                explicitness: explicitness,
                confidenceScore: confidenceScore,
                futureUtility: futureUtility,
                sensitivity: sensitivity,
                sourceTurnIdsJson: sourceTurnIdsJson,
                evidenceRole: evidenceRole,
                suggestedAction: suggestedAction,
                followUpAllowed: followUpAllowed,
                proactiveAllowed: proactiveAllowed,
                decisionState: decisionState,
                decisionReason: decisionReason,
                targetMemoryId: targetMemoryId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoryCandidatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryCandidatesTable,
      MemoryCandidate,
      $$MemoryCandidatesTableFilterComposer,
      $$MemoryCandidatesTableOrderingComposer,
      $$MemoryCandidatesTableAnnotationComposer,
      $$MemoryCandidatesTableCreateCompanionBuilder,
      $$MemoryCandidatesTableUpdateCompanionBuilder,
      (
        MemoryCandidate,
        BaseReferences<_$AppDatabase, $MemoryCandidatesTable, MemoryCandidate>,
      ),
      MemoryCandidate,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChatSessionsTableTableManager get chatSessions =>
      $$ChatSessionsTableTableManager(_db, _db.chatSessions);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db, _db.chatMessages);
  $$MemoryRecordsTableTableManager get memoryRecords =>
      $$MemoryRecordsTableTableManager(_db, _db.memoryRecords);
  $$MemoryEntitiesTableTableManager get memoryEntities =>
      $$MemoryEntitiesTableTableManager(_db, _db.memoryEntities);
  $$MemoryEdgesTableTableManager get memoryEdges =>
      $$MemoryEdgesTableTableManager(_db, _db.memoryEdges);
  $$MemoryContradictionsTableTableManager get memoryContradictions =>
      $$MemoryContradictionsTableTableManager(_db, _db.memoryContradictions);
  $$MemoryEpisodesTableTableManager get memoryEpisodes =>
      $$MemoryEpisodesTableTableManager(_db, _db.memoryEpisodes);
  $$MemoryOpenThreadsTableTableManager get memoryOpenThreads =>
      $$MemoryOpenThreadsTableTableManager(_db, _db.memoryOpenThreads);
  $$MemoryExtractionJobsTableTableManager get memoryExtractionJobs =>
      $$MemoryExtractionJobsTableTableManager(_db, _db.memoryExtractionJobs);
  $$MemoryCandidatesTableTableManager get memoryCandidates =>
      $$MemoryCandidatesTableTableManager(_db, _db.memoryCandidates);
}
