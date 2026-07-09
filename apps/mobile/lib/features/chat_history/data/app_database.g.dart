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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    label,
    content,
    sourceTurnIdsJson,
    sourceRole,
    transcriptStatus,
    sttConfidence,
    createdAt,
    updatedAt,
    lastUsedAt,
    confidenceScore,
    importanceScore,
    supersededBy,
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
    if (data.containsKey('superseded_by')) {
      context.handle(
        _supersededByMeta,
        supersededBy.isAcceptableOrUnknown(
          data['superseded_by']!,
          _supersededByMeta,
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
      confidenceScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence_score'],
      )!,
      importanceScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}importance_score'],
      )!,
      supersededBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}superseded_by'],
      ),
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
  final String sourceTurnIdsJson;
  final String sourceRole;
  final String transcriptStatus;
  final double? sttConfidence;
  final int createdAt;
  final int updatedAt;
  final int? lastUsedAt;
  final double confidenceScore;
  final double importanceScore;
  final String? supersededBy;
  const MemoryRecord({
    required this.id,
    required this.kind,
    required this.label,
    required this.content,
    required this.sourceTurnIdsJson,
    required this.sourceRole,
    required this.transcriptStatus,
    this.sttConfidence,
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
    required this.confidenceScore,
    required this.importanceScore,
    this.supersededBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['label'] = Variable<String>(label);
    map['content'] = Variable<String>(content);
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
    map['confidence_score'] = Variable<double>(confidenceScore);
    map['importance_score'] = Variable<double>(importanceScore);
    if (!nullToAbsent || supersededBy != null) {
      map['superseded_by'] = Variable<String>(supersededBy);
    }
    return map;
  }

  MemoryRecordsCompanion toCompanion(bool nullToAbsent) {
    return MemoryRecordsCompanion(
      id: Value(id),
      kind: Value(kind),
      label: Value(label),
      content: Value(content),
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
      confidenceScore: Value(confidenceScore),
      importanceScore: Value(importanceScore),
      supersededBy: supersededBy == null && nullToAbsent
          ? const Value.absent()
          : Value(supersededBy),
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
      sourceTurnIdsJson: serializer.fromJson<String>(json['sourceTurnIdsJson']),
      sourceRole: serializer.fromJson<String>(json['sourceRole']),
      transcriptStatus: serializer.fromJson<String>(json['transcriptStatus']),
      sttConfidence: serializer.fromJson<double?>(json['sttConfidence']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      lastUsedAt: serializer.fromJson<int?>(json['lastUsedAt']),
      confidenceScore: serializer.fromJson<double>(json['confidenceScore']),
      importanceScore: serializer.fromJson<double>(json['importanceScore']),
      supersededBy: serializer.fromJson<String?>(json['supersededBy']),
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
      'sourceTurnIdsJson': serializer.toJson<String>(sourceTurnIdsJson),
      'sourceRole': serializer.toJson<String>(sourceRole),
      'transcriptStatus': serializer.toJson<String>(transcriptStatus),
      'sttConfidence': serializer.toJson<double?>(sttConfidence),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'lastUsedAt': serializer.toJson<int?>(lastUsedAt),
      'confidenceScore': serializer.toJson<double>(confidenceScore),
      'importanceScore': serializer.toJson<double>(importanceScore),
      'supersededBy': serializer.toJson<String?>(supersededBy),
    };
  }

  MemoryRecord copyWith({
    String? id,
    String? kind,
    String? label,
    String? content,
    String? sourceTurnIdsJson,
    String? sourceRole,
    String? transcriptStatus,
    Value<double?> sttConfidence = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> lastUsedAt = const Value.absent(),
    double? confidenceScore,
    double? importanceScore,
    Value<String?> supersededBy = const Value.absent(),
  }) => MemoryRecord(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    label: label ?? this.label,
    content: content ?? this.content,
    sourceTurnIdsJson: sourceTurnIdsJson ?? this.sourceTurnIdsJson,
    sourceRole: sourceRole ?? this.sourceRole,
    transcriptStatus: transcriptStatus ?? this.transcriptStatus,
    sttConfidence: sttConfidence.present
        ? sttConfidence.value
        : this.sttConfidence,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
    confidenceScore: confidenceScore ?? this.confidenceScore,
    importanceScore: importanceScore ?? this.importanceScore,
    supersededBy: supersededBy.present ? supersededBy.value : this.supersededBy,
  );
  MemoryRecord copyWithCompanion(MemoryRecordsCompanion data) {
    return MemoryRecord(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      label: data.label.present ? data.label.value : this.label,
      content: data.content.present ? data.content.value : this.content,
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
      confidenceScore: data.confidenceScore.present
          ? data.confidenceScore.value
          : this.confidenceScore,
      importanceScore: data.importanceScore.present
          ? data.importanceScore.value
          : this.importanceScore,
      supersededBy: data.supersededBy.present
          ? data.supersededBy.value
          : this.supersededBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryRecord(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('content: $content, ')
          ..write('sourceTurnIdsJson: $sourceTurnIdsJson, ')
          ..write('sourceRole: $sourceRole, ')
          ..write('transcriptStatus: $transcriptStatus, ')
          ..write('sttConfidence: $sttConfidence, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('importanceScore: $importanceScore, ')
          ..write('supersededBy: $supersededBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    label,
    content,
    sourceTurnIdsJson,
    sourceRole,
    transcriptStatus,
    sttConfidence,
    createdAt,
    updatedAt,
    lastUsedAt,
    confidenceScore,
    importanceScore,
    supersededBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryRecord &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.label == this.label &&
          other.content == this.content &&
          other.sourceTurnIdsJson == this.sourceTurnIdsJson &&
          other.sourceRole == this.sourceRole &&
          other.transcriptStatus == this.transcriptStatus &&
          other.sttConfidence == this.sttConfidence &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastUsedAt == this.lastUsedAt &&
          other.confidenceScore == this.confidenceScore &&
          other.importanceScore == this.importanceScore &&
          other.supersededBy == this.supersededBy);
}

class MemoryRecordsCompanion extends UpdateCompanion<MemoryRecord> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> label;
  final Value<String> content;
  final Value<String> sourceTurnIdsJson;
  final Value<String> sourceRole;
  final Value<String> transcriptStatus;
  final Value<double?> sttConfidence;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> lastUsedAt;
  final Value<double> confidenceScore;
  final Value<double> importanceScore;
  final Value<String?> supersededBy;
  final Value<int> rowid;
  const MemoryRecordsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.label = const Value.absent(),
    this.content = const Value.absent(),
    this.sourceTurnIdsJson = const Value.absent(),
    this.sourceRole = const Value.absent(),
    this.transcriptStatus = const Value.absent(),
    this.sttConfidence = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.confidenceScore = const Value.absent(),
    this.importanceScore = const Value.absent(),
    this.supersededBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryRecordsCompanion.insert({
    required String id,
    required String kind,
    required String label,
    required String content,
    required String sourceTurnIdsJson,
    required String sourceRole,
    required String transcriptStatus,
    this.sttConfidence = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.lastUsedAt = const Value.absent(),
    required double confidenceScore,
    required double importanceScore,
    this.supersededBy = const Value.absent(),
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
    Expression<String>? sourceTurnIdsJson,
    Expression<String>? sourceRole,
    Expression<String>? transcriptStatus,
    Expression<double>? sttConfidence,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? lastUsedAt,
    Expression<double>? confidenceScore,
    Expression<double>? importanceScore,
    Expression<String>? supersededBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (label != null) 'label': label,
      if (content != null) 'content': content,
      if (sourceTurnIdsJson != null) 'source_turn_ids_json': sourceTurnIdsJson,
      if (sourceRole != null) 'source_role': sourceRole,
      if (transcriptStatus != null) 'transcript_status': transcriptStatus,
      if (sttConfidence != null) 'stt_confidence': sttConfidence,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      if (importanceScore != null) 'importance_score': importanceScore,
      if (supersededBy != null) 'superseded_by': supersededBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? label,
    Value<String>? content,
    Value<String>? sourceTurnIdsJson,
    Value<String>? sourceRole,
    Value<String>? transcriptStatus,
    Value<double?>? sttConfidence,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? lastUsedAt,
    Value<double>? confidenceScore,
    Value<double>? importanceScore,
    Value<String?>? supersededBy,
    Value<int>? rowid,
  }) {
    return MemoryRecordsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      content: content ?? this.content,
      sourceTurnIdsJson: sourceTurnIdsJson ?? this.sourceTurnIdsJson,
      sourceRole: sourceRole ?? this.sourceRole,
      transcriptStatus: transcriptStatus ?? this.transcriptStatus,
      sttConfidence: sttConfidence ?? this.sttConfidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      importanceScore: importanceScore ?? this.importanceScore,
      supersededBy: supersededBy ?? this.supersededBy,
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
    if (confidenceScore.present) {
      map['confidence_score'] = Variable<double>(confidenceScore.value);
    }
    if (importanceScore.present) {
      map['importance_score'] = Variable<double>(importanceScore.value);
    }
    if (supersededBy.present) {
      map['superseded_by'] = Variable<String>(supersededBy.value);
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
          ..write('sourceTurnIdsJson: $sourceTurnIdsJson, ')
          ..write('sourceRole: $sourceRole, ')
          ..write('transcriptStatus: $transcriptStatus, ')
          ..write('sttConfidence: $sttConfidence, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('importanceScore: $importanceScore, ')
          ..write('supersededBy: $supersededBy, ')
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
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    chatSessions,
    chatMessages,
    memoryRecords,
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
      required String sourceTurnIdsJson,
      required String sourceRole,
      required String transcriptStatus,
      Value<double?> sttConfidence,
      required int createdAt,
      required int updatedAt,
      Value<int?> lastUsedAt,
      required double confidenceScore,
      required double importanceScore,
      Value<String?> supersededBy,
      Value<int> rowid,
    });
typedef $$MemoryRecordsTableUpdateCompanionBuilder =
    MemoryRecordsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> label,
      Value<String> content,
      Value<String> sourceTurnIdsJson,
      Value<String> sourceRole,
      Value<String> transcriptStatus,
      Value<double?> sttConfidence,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> lastUsedAt,
      Value<double> confidenceScore,
      Value<double> importanceScore,
      Value<String?> supersededBy,
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

  ColumnFilters<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get importanceScore => $composableBuilder(
    column: $table.importanceScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supersededBy => $composableBuilder(
    column: $table.supersededBy,
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

  ColumnOrderings<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get importanceScore => $composableBuilder(
    column: $table.importanceScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supersededBy => $composableBuilder(
    column: $table.supersededBy,
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

  GeneratedColumn<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get importanceScore => $composableBuilder(
    column: $table.importanceScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get supersededBy => $composableBuilder(
    column: $table.supersededBy,
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
                Value<String> sourceTurnIdsJson = const Value.absent(),
                Value<String> sourceRole = const Value.absent(),
                Value<String> transcriptStatus = const Value.absent(),
                Value<double?> sttConfidence = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> lastUsedAt = const Value.absent(),
                Value<double> confidenceScore = const Value.absent(),
                Value<double> importanceScore = const Value.absent(),
                Value<String?> supersededBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryRecordsCompanion(
                id: id,
                kind: kind,
                label: label,
                content: content,
                sourceTurnIdsJson: sourceTurnIdsJson,
                sourceRole: sourceRole,
                transcriptStatus: transcriptStatus,
                sttConfidence: sttConfidence,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastUsedAt: lastUsedAt,
                confidenceScore: confidenceScore,
                importanceScore: importanceScore,
                supersededBy: supersededBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String label,
                required String content,
                required String sourceTurnIdsJson,
                required String sourceRole,
                required String transcriptStatus,
                Value<double?> sttConfidence = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> lastUsedAt = const Value.absent(),
                required double confidenceScore,
                required double importanceScore,
                Value<String?> supersededBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryRecordsCompanion.insert(
                id: id,
                kind: kind,
                label: label,
                content: content,
                sourceTurnIdsJson: sourceTurnIdsJson,
                sourceRole: sourceRole,
                transcriptStatus: transcriptStatus,
                sttConfidence: sttConfidence,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastUsedAt: lastUsedAt,
                confidenceScore: confidenceScore,
                importanceScore: importanceScore,
                supersededBy: supersededBy,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChatSessionsTableTableManager get chatSessions =>
      $$ChatSessionsTableTableManager(_db, _db.chatSessions);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db, _db.chatMessages);
  $$MemoryRecordsTableTableManager get memoryRecords =>
      $$MemoryRecordsTableTableManager(_db, _db.memoryRecords);
}
