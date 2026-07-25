import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'app_database.dart';
import 'memory_v3_admission.dart';
import 'memory_v3_models.dart';

const memoryV3CompilerMaxMessages = 12;
const memoryV3CompilerMaxAttempts = 5;
const memoryV3CompilerLease = Duration(minutes: 5);

class MemoryV3CompileJob {
  const MemoryV3CompileJob({
    required this.id,
    required this.requestHash,
    required this.language,
    required this.timezone,
    required this.nowMs,
    required this.status,
    required this.attempts,
    required this.createdAtMs,
  });

  final String id;
  final String requestHash;
  final String language;
  final String timezone;
  final int nowMs;
  final String status;
  final int attempts;
  final int createdAtMs;
}

class MemoryV3CompileJobBundle {
  const MemoryV3CompileJobBundle({required this.job, required this.messages});

  final MemoryV3CompileJob job;
  final List<ChatMessage> messages;

  Map<String, Object?> toRequestJson() => {
    'schema_version': memoryV3CompileSchemaVersion,
    'job_id': job.id,
    'language': job.language,
    'timezone': job.timezone,
    'now_ms': job.nowMs,
    'turns': [
      for (final message in messages)
        {
          'turn_id': message.turnId,
          'role': _normalizedRole(message.role),
          'text': message.messageText,
          'status': message.status,
          'language': message.language,
          'script': _detectScript(message.messageText),
          'stt_confidence': message.sttConfidence,
          'stt_provider': null,
          'stt_model': null,
          'created_at_ms': message.createdAt,
        },
    ],
  };
}

class MemoryV3ApplyResult {
  const MemoryV3ApplyResult({
    required this.admittedCount,
    required this.deferredCount,
    required this.rejectedCount,
    required this.duplicateCount,
  });

  final int admittedCount;
  final int deferredCount;
  final int rejectedCount;
  final int duplicateCount;
}

extension MemoryV3CompilerStore on AppDatabase {
  /// Enqueues a deterministic, bounded snapshot ending at [turnId]. Any older
  /// unclaimed snapshot for the same session is coalesced into this newer one.
  Future<String?> enqueueMemoryV3CompileJob({
    required String sessionId,
    required String turnId,
    required String timezone,
  }) async {
    await ensureMemoryV3Schema();
    return transaction(() async {
      final endRows = await customSelect(
        '''
          SELECT MAX(created_at) AS end_at
          FROM chat_messages
          WHERE session_id = ? AND turn_id = ?
            AND status IN ('final', 'final_corrected', 'safety_override')
        ''',
        variables: [Variable<String>(sessionId), Variable<String>(turnId)],
      ).getSingle();
      final endAt = endRows.data['end_at'] as int?;
      if (endAt == null) return null;

      final messages = await customSelect(
        '''
          SELECT * FROM chat_messages
          WHERE session_id = ? AND created_at <= ?
            AND status IN ('final', 'final_corrected', 'safety_override')
            AND role IN ('user', 'assistant', 'ai')
          ORDER BY created_at DESC,
            CASE role WHEN 'ai' THEN 1 WHEN 'assistant' THEN 1 ELSE 0 END DESC,
            id DESC
          LIMIT ?
        ''',
        variables: [
          Variable<String>(sessionId),
          Variable<int>(endAt),
          const Variable<int>(memoryV3CompilerMaxMessages * 2),
        ],
        readsFrom: {chatMessages},
      ).get();
      final newestUnique = <ChatMessage>[];
      final seenTurnRoles = <String>{};
      for (final row in messages) {
        final message = chatMessages.map(row.data);
        final key = '${message.turnId}|${_normalizedRole(message.role)}';
        if (seenTurnRoles.add(key)) newestUnique.add(message);
        if (newestUnique.length == memoryV3CompilerMaxMessages) break;
      }
      final window = newestUnique.reversed.toList(growable: false);
      final endTurnMessages = window.where((item) => item.turnId == turnId);
      final hasUser = endTurnMessages.any(
        (item) => _normalizedRole(item.role) == 'user',
      );
      final hasAssistant = endTurnMessages.any(
        (item) => _normalizedRole(item.role) == 'assistant',
      );
      if (!hasUser || !hasAssistant || window.isEmpty) return null;

      if (timezone.isEmpty ||
          timezone.length > 64 ||
          window.any(
            (message) =>
                message.turnId.isEmpty ||
                message.turnId.length > 128 ||
                message.messageText.isEmpty ||
                message.messageText.length > 1600 ||
                message.language.length > 32,
          )) {
        return null;
      }

      final language = window.last.language;
      if (language.length < 2) return null;
      final nowMs = window.last.createdAt;
      final canonical = jsonEncode({
        'schema_version': memoryV3CompileSchemaVersion,
        'language': language,
        'timezone': timezone,
        'now_ms': nowMs,
        'messages': [
          for (final message in window)
            [
              message.id,
              message.turnId,
              _normalizedRole(message.role),
              message.status,
              message.messageText,
              message.sttConfidence,
              message.createdAt,
            ],
        ],
      });
      final requestHash = sha256.convert(utf8.encode(canonical)).toString();
      final jobId = 'memory_compile_${requestHash.substring(0, 40)}';

      final existing = await customSelect(
        'SELECT id FROM memory_compile_jobs_v3 WHERE request_hash = ?',
        variables: [Variable<String>(requestHash)],
      ).getSingleOrNull();
      if (existing != null) return existing.read<String>('id');

      // Only unclaimed work is coalesced. A leased job keeps its immutable
      // request snapshot and replay identity.
      await customStatement(
        '''
          DELETE FROM memory_compile_jobs_v3
          WHERE status IN ('pending', 'retry')
            AND EXISTS (
              SELECT 1 FROM memory_compile_job_messages_v3 jm
              JOIN chat_messages m ON m.id = jm.source_message_id
              WHERE jm.job_id = memory_compile_jobs_v3.id
                AND m.session_id = ?
            )
        ''',
        [sessionId],
      );
      await customStatement(
        '''
          INSERT INTO memory_compile_jobs_v3 (
            id, request_hash, language, timezone, now_ms, status, attempts,
            created_at_ms, updated_at_ms
          ) VALUES (?, ?, ?, ?, ?, 'pending', 0, ?, ?)
        ''',
        [jobId, requestHash, language, timezone, nowMs, nowMs, nowMs],
      );
      for (var index = 0; index < window.length; index += 1) {
        await customStatement(
          '''
            INSERT INTO memory_compile_job_messages_v3 (
              job_id, message_ordinal, source_message_id, source_session_id,
              source_turn_id, source_role, source_text, transcript_status,
              language, created_at_ms, stt_confidence
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            jobId,
            index,
            window[index].id,
            window[index].sessionId,
            window[index].turnId,
            _normalizedRole(window[index].role),
            window[index].messageText,
            window[index].status,
            window[index].language,
            window[index].createdAt,
            window[index].sttConfidence,
          ],
        );
      }
      return jobId;
    });
  }

  Future<MemoryV3CompileJob?> claimNextMemoryV3CompileJob({int? nowMs}) async {
    await ensureMemoryV3Schema();
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return transaction(() async {
      final row = await customSelect(
        '''
          SELECT * FROM memory_compile_jobs_v3
          WHERE attempts < ? AND (
            (status IN ('pending', 'retry') AND
              (next_attempt_at_ms IS NULL OR next_attempt_at_ms <= ?))
            OR (status = 'processing' AND lease_expires_at_ms <= ?)
          )
          ORDER BY created_at_ms ASC LIMIT 1
        ''',
        variables: [
          const Variable<int>(memoryV3CompilerMaxAttempts),
          Variable<int>(now),
          Variable<int>(now),
        ],
      ).getSingleOrNull();
      if (row == null) return null;
      final job = _jobFromRow(row.data);
      final nextAttempt = job.attempts + 1;
      await customStatement(
        '''
          UPDATE memory_compile_jobs_v3
          SET status = 'processing', attempts = ?, lease_expires_at_ms = ?,
              next_attempt_at_ms = NULL, updated_at_ms = ?
          WHERE id = ?
        ''',
        [nextAttempt, now + memoryV3CompilerLease.inMilliseconds, now, job.id],
      );
      return MemoryV3CompileJob(
        id: job.id,
        requestHash: job.requestHash,
        language: job.language,
        timezone: job.timezone,
        nowMs: job.nowMs,
        status: 'processing',
        attempts: nextAttempt,
        createdAtMs: job.createdAtMs,
      );
    });
  }

  Future<Duration?> nextMemoryV3CompileDelay({int? nowMs}) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final row = await customSelect(
      '''
        SELECT MIN(CASE
          WHEN status = 'pending' THEN ?
          WHEN status = 'retry' THEN COALESCE(next_attempt_at_ms, ?)
          WHEN status = 'processing' THEN COALESCE(lease_expires_at_ms, ?)
        END) AS ready_at
        FROM memory_compile_jobs_v3
        WHERE attempts < ? AND status IN ('pending', 'retry', 'processing')
      ''',
      variables: [
        Variable<int>(now),
        Variable<int>(now),
        Variable<int>(now),
        const Variable<int>(memoryV3CompilerMaxAttempts),
      ],
    ).getSingle();
    final readyAt = row.data['ready_at'] as int?;
    if (readyAt == null) return null;
    return Duration(milliseconds: math.max(0, readyAt - now));
  }

  Future<MemoryV3CompileJobBundle> readMemoryV3CompileBundle(
    MemoryV3CompileJob job,
  ) async {
    final rows = await customSelect(
      '''
        SELECT * FROM memory_compile_job_messages_v3
        WHERE job_id = ? ORDER BY message_ordinal ASC
      ''',
      variables: [Variable<String>(job.id)],
    ).get();
    return MemoryV3CompileJobBundle(
      job: job,
      messages: [
        for (final row in rows)
          ChatMessage(
            id: row.read<String>('source_message_id'),
            sessionId: row.read<String>('source_session_id'),
            turnId: row.read<String>('source_turn_id'),
            role: row.read<String>('source_role'),
            messageText: row.read<String>('source_text'),
            status: row.read<String>('transcript_status'),
            language: row.read<String>('language'),
            createdAt: row.read<int>('created_at_ms'),
            sttConfidence: row.readNullable<double>('stt_confidence'),
          ),
      ],
    );
  }

  Future<void> failMemoryV3CompileJob(
    MemoryV3CompileJob job, {
    required String errorCode,
    required bool retryable,
    required String runStatus,
    required int startedAtMs,
    String provider = 'unknown',
    String model = 'unknown',
    String promptVersion = 'unknown',
    int? nowMs,
  }) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (!{
      'unavailable',
      'timeout',
      'invalid',
      'rejected',
    }.contains(runStatus)) {
      throw const FormatException('Invalid compiler failure status.');
    }
    final canRetry = retryable && job.attempts < memoryV3CompilerMaxAttempts;
    final backoffMs = math.min(
      const Duration(minutes: 5).inMilliseconds,
      const Duration(seconds: 5).inMilliseconds *
          math.pow(2, math.max(0, job.attempts - 1)).toInt(),
    );
    await transaction(() async {
      await customStatement(
        '''
          INSERT OR IGNORE INTO memory_compile_runs_v3 (
            id, job_id, attempt, status, provider, model, prompt_version,
            usage_source, input_tokens, output_tokens, candidate_count,
            admitted_count, deferred_count, rejected_count, duplicate_count,
            error_code, started_at_ms, completed_at_ms
          ) VALUES (?, ?, ?, ?, ?, ?, ?, 'unknown', 0, 0, 0, 0, 0, 0, 0, ?, ?, ?)
        ''',
        [
          'memory_compile_run_${job.id}_${job.attempts}',
          job.id,
          job.attempts,
          runStatus,
          provider,
          model,
          promptVersion,
          _redactedErrorCode(errorCode),
          math.min(startedAtMs, now),
          now,
        ],
      );
      await customStatement(
        '''
          UPDATE memory_compile_jobs_v3
          SET status = ?, lease_expires_at_ms = NULL, next_attempt_at_ms = ?,
              last_error_code = ?, updated_at_ms = ?, completed_at_ms = ?
          WHERE id = ? AND status = 'processing'
        ''',
        [
          canRetry ? 'retry' : 'dead',
          canRetry ? now + backoffMs : null,
          _redactedErrorCode(errorCode),
          now,
          canRetry ? null : now,
          job.id,
        ],
      );
    });
  }

  /// Re-validates every server candidate and records the append-only ledger,
  /// redacted outcomes, and run metadata in one local transaction. No V3
  /// projection is written here.
  Future<MemoryV3ApplyResult> applyMemoryV3CompileEnvelope({
    required MemoryV3CompileJobBundle bundle,
    required MemoryV3CompileEnvelope envelope,
    required int startedAtMs,
    int? completedAtMs,
  }) async {
    if (envelope.jobId != bundle.job.id) {
      throw const FormatException('Compiler job identity mismatch.');
    }
    final completed = completedAtMs ?? DateTime.now().millisecondsSinceEpoch;
    if (completed < startedAtMs) {
      throw const FormatException('Compiler timing is invalid.');
    }
    return transaction(() async {
      final liveJob = await customSelect(
        'SELECT status, attempts FROM memory_compile_jobs_v3 WHERE id = ?',
        variables: [Variable<String>(bundle.job.id)],
      ).getSingleOrNull();
      if (liveJob == null ||
          liveJob.read<String>('status') != 'processing' ||
          liveJob.read<int>('attempts') != bundle.job.attempts) {
        throw const FormatException('Compiler job is not currently leased.');
      }

      var admittedCount = 0;
      var deferredCount = 0;
      var rejectedCount = 0;
      var duplicateCount = 0;
      for (final candidate in envelope.candidates) {
        final validated = validateMemoryV3Candidate(candidate, [
          for (final message in bundle.messages)
            MemoryV3AdmissionSource(
              id: message.id,
              turnId: message.turnId,
              role: _normalizedRole(message.role),
              text: message.messageText,
              status: message.status,
              createdAtMs: message.createdAt,
              sttConfidence: message.sttConfidence,
            ),
        ]);
        var disposition = validated.disposition;
        var reason = validated.reason;
        String? observationId;

        if (validated.mayStore) {
          observationId = _memoryV3ObservationId(candidate, validated.evidence);
          final blockingControl = await customSelect(
            '''
              SELECT action FROM memory_user_controls_v3
              WHERE target_kind = 'observation' AND target_id = ?
                AND action IN ('reject', 'forget')
              ORDER BY created_at_ms DESC LIMIT 1
            ''',
            variables: [Variable<String>(observationId)],
          ).getSingleOrNull();
          if (blockingControl != null) {
            disposition = 'rejected';
            reason = 'user_control_precedence';
            observationId = null;
          } else {
            final duplicate = await customSelect(
              '''
                SELECT id FROM memory_observations_v3
                WHERE id = ? OR idempotency_key = ? LIMIT 1
              ''',
              variables: [
                Variable<String>(observationId),
                Variable<String>(_memoryV3IdempotencyKey(observationId)),
              ],
            ).getSingleOrNull();
            if (duplicate != null) {
              disposition = 'duplicate';
              reason = 'same_evidence_replay';
              observationId = duplicate.read<String>('id');
            }
          }
        }

        if (validated.mayStore &&
            observationId != null &&
            disposition != 'duplicate') {
          final admissionDisposition = switch (disposition) {
            'admitted' => 'auto_admit',
            'deferred' => 'defer',
            'confirmation_required' => 'confirmation_required',
            _ => throw StateError('Rejected observations cannot be stored.'),
          };
          final candidateObject = candidate.object;
          final target = candidateObject.targetEntity;
          final affect = candidate.affect;
          await customStatement(
            '''
              INSERT INTO memory_observations_v3 (
                id, schema_version, compiler_request_id, candidate_id,
                idempotency_key, kind, subject_entity_type, subject_mention,
                subject_relationship_hint, predicate, object_text,
                normalized_value_json, target_entity_type,
                target_entity_mention, target_relationship_hint,
                user_assessment, temporal_status,
                observed_at_ms, timezone, event_start_at_ms, event_end_at_ms,
                temporal_raw_expression, temporal_resolution_confidence,
                explicitness, epistemic_confidence, is_negated,
                is_hypothetical, is_quoted, affect_emotion, affect_valence,
                affect_arousal, affect_intensity, affect_target, affect_cause,
                affect_confidence, salience, future_utility,
                proactive_allowed, confirmation_required, sensitivity,
                durable_eligibility, privacy_reason, proposed_operation,
                admission_disposition, admission_reason, compiler_provider,
                compiler_model, compiler_prompt_version,
                compiler_contract_version, compiled_at_ms, admitted_at_ms
              ) VALUES (
                ?, 3, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
              )
            ''',
            [
              observationId,
              bundle.job.id,
              _redactedMemoryV3CandidateId(
                bundle.job.id,
                candidate.candidateId,
              ),
              _memoryV3IdempotencyKey(observationId),
              candidate.kind,
              candidate.subject.entityType,
              candidate.subject.mention,
              candidate.subject.relationshipHint,
              candidate.predicate,
              candidateObject.text,
              candidateObject.normalizedValue == null
                  ? null
                  : jsonEncode(candidateObject.normalizedValue),
              target?.entityType,
              target?.mention,
              target?.relationshipHint,
              candidateObject.userAssessment,
              validated.temporalStatus,
              validated.observedAtMs,
              bundle.job.timezone,
              candidate.temporal.eventStartAtMs,
              candidate.temporal.eventEndAtMs,
              candidate.temporal.rawExpression,
              candidate.temporal.resolutionConfidence,
              candidate.epistemic.explicitness,
              validated.epistemicConfidence,
              candidate.epistemic.negated ? 1 : 0,
              candidate.epistemic.hypothetical ? 1 : 0,
              candidate.epistemic.quoted ? 1 : 0,
              affect?.emotion,
              affect?.valence,
              affect?.arousal,
              affect?.intensity,
              affect?.target,
              affect?.cause,
              affect?.confidence,
              candidate.utility.salience,
              candidate.utility.futureUtility,
              disposition == 'admitted' && candidate.utility.proactiveAllowed
                  ? 1
                  : 0,
              disposition == 'confirmation_required' ||
                      candidate.utility.confirmationRequired
                  ? 1
                  : 0,
              candidate.privacy.sensitivity,
              candidate.privacy.durableEligibility,
              candidate.privacy.reason,
              candidate.proposedOperation,
              admissionDisposition,
              reason,
              envelope.model.provider,
              envelope.model.model,
              envelope.model.promptVersion,
              memoryV3CompileContractVersion,
              completed,
              completed,
            ],
          );
          for (var index = 0; index < validated.evidence.length; index += 1) {
            final evidence = validated.evidence[index];
            await customStatement(
              '''
                INSERT INTO memory_observation_evidence_v3 (
                  observation_id, evidence_ordinal, source_message_id,
                  source_turn_id, source_role, evidence_fragment, start_char,
                  end_char, transcript_status, stt_confidence,
                  stt_provider, stt_model
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL)
              ''',
              [
                observationId,
                index,
                evidence.source.id,
                evidence.source.turnId,
                evidence.source.role,
                evidence.fragment,
                evidence.startChar,
                evidence.endChar,
                evidence.source.status,
                evidence.source.sttConfidence,
              ],
            );
          }
        }

        if (disposition == 'admitted') {
          admittedCount += 1;
        } else if (disposition == 'deferred' ||
            disposition == 'confirmation_required') {
          deferredCount += 1;
        } else if (disposition == 'duplicate') {
          duplicateCount += 1;
        } else if (disposition == 'rejected' || disposition == 'noop') {
          rejectedCount += 1;
        } else {
          throw StateError('Unknown compiler admission disposition.');
        }
        await customStatement(
          '''
            INSERT INTO memory_compile_candidate_outcomes_v3 (
              job_id, candidate_id, kind, predicate, proposed_operation,
              disposition, reason, observation_id, created_at_ms
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            bundle.job.id,
            _redactedMemoryV3CandidateId(bundle.job.id, candidate.candidateId),
            candidate.kind,
            candidate.predicate,
            candidate.proposedOperation,
            disposition,
            reason,
            observationId,
            completed,
          ],
        );
      }

      final runId =
          'memory_compile_run_${bundle.job.id}_${bundle.job.attempts}';
      await customStatement(
        '''
          INSERT INTO memory_compile_runs_v3 (
            id, job_id, attempt, status, provider, model, prompt_version,
            usage_source, input_tokens, output_tokens, estimated_micro_inr,
            candidate_count, admitted_count, deferred_count, rejected_count,
            duplicate_count, started_at_ms, completed_at_ms
          ) VALUES (?, ?, ?, 'succeeded', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          runId,
          bundle.job.id,
          bundle.job.attempts,
          envelope.model.provider,
          envelope.model.model,
          envelope.model.promptVersion,
          envelope.model.usageSource,
          envelope.model.inputTokens,
          envelope.model.outputTokens,
          envelope.model.estimatedMicroInr,
          envelope.candidates.length,
          admittedCount,
          deferredCount,
          rejectedCount,
          duplicateCount,
          startedAtMs,
          completed,
        ],
      );
      await customStatement(
        '''
          UPDATE memory_compile_jobs_v3
          SET status = 'succeeded', lease_expires_at_ms = NULL,
              next_attempt_at_ms = NULL, last_error_code = NULL,
              updated_at_ms = ?, completed_at_ms = ?
          WHERE id = ? AND status = 'processing'
        ''',
        [completed, completed, bundle.job.id],
      );
      return MemoryV3ApplyResult(
        admittedCount: admittedCount,
        deferredCount: deferredCount,
        rejectedCount: rejectedCount,
        duplicateCount: duplicateCount,
      );
    });
  }
}

String _memoryV3ObservationId(
  MemoryV3Observation candidate,
  List<GroundedMemoryV3Evidence> evidence,
) {
  final canonical = jsonEncode({
    'kind': candidate.kind,
    'subject_type': candidate.subject.entityType,
    'subject': normalizeMemoryV3Text(candidate.subject.mention),
    'predicate': candidate.predicate,
    'object': normalizeMemoryV3Text(candidate.object.text),
    'target': candidate.object.targetEntity == null
        ? null
        : [
            candidate.object.targetEntity!.entityType,
            normalizeMemoryV3Text(candidate.object.targetEntity!.mention),
          ],
    'evidence': [
      for (final item in evidence)
        [item.source.id, item.startChar, item.endChar, item.fragment],
    ],
  });
  final digest = sha256.convert(utf8.encode(canonical)).toString();
  return 'observation_${digest.substring(0, 40)}';
}

String _memoryV3IdempotencyKey(String observationId) =>
    sha256.convert(utf8.encode('memory_v3|$observationId')).toString();

String _redactedMemoryV3CandidateId(String jobId, String candidateId) =>
    'candidate_${sha256.convert(utf8.encode('$jobId|$candidateId')).toString().substring(0, 32)}';

MemoryV3CompileJob _jobFromRow(Map<String, Object?> row) => MemoryV3CompileJob(
  id: row['id']! as String,
  requestHash: row['request_hash']! as String,
  language: row['language']! as String,
  timezone: row['timezone']! as String,
  nowMs: row['now_ms']! as int,
  status: row['status']! as String,
  attempts: row['attempts']! as int,
  createdAtMs: row['created_at_ms']! as int,
);

String _normalizedRole(String role) => role == 'ai' ? 'assistant' : role;

String _detectScript(String text) {
  final devanagari = RegExp(r'[\u0900-\u097F]').hasMatch(text);
  final latin = RegExp(r'[A-Za-z]').hasMatch(text);
  if (devanagari && latin) return 'mixed';
  if (devanagari) return 'devanagari';
  if (latin) return 'latin';
  return 'unknown';
}

String _redactedErrorCode(String value) {
  final normalized = value.toLowerCase().replaceAll(
    RegExp('[^a-z0-9_\\-]'),
    '_',
  );
  return normalized.substring(0, math.min(80, normalized.length));
}
