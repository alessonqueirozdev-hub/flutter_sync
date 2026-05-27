// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import '../models/sync_record.dart';

/// Lifecycle state of a single [OutboxEntry].
enum OutboxStatus {
  /// The entry is waiting to be picked up by `OutboxProcessor`.
  pending,

  /// The entry has been claimed and is currently being pushed.
  inflight,

  /// The entry has been successfully synced and is awaiting TTL eviction.
  synced,

  /// The entry has exhausted its retry budget and is dead-lettered.
  failed,
}

/// Operation represented by an [OutboxEntry].
enum OutboxOperation {
  /// Insert or update operation derived from `SyncRecord.upsert`.
  upsert,

  /// Delete operation derived from `SyncRecord.delete` (tombstone).
  delete,
}

/// Single durable record-to-be-pushed kept inside the outbox.
///
/// Every entry carries the [record] payload, the operation [operation] to
/// perform, an [idempotencyKey] for safe server-side deduplication, and
/// retry bookkeeping.
@immutable
class OutboxEntry {
  /// Creates an immutable outbox entry.
  const OutboxEntry({
    required this.id,
    required this.record,
    required this.operation,
    required this.idempotencyKey,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    this.lastAttemptAt,
    this.nextRetryAt,
    this.failureReason,
  });

  /// Computes the canonical idempotency key for [record].
  ///
  /// `sha256(collection + ':' + id + ':' + hlc)` returned as lowercase
  /// hexadecimal. Carrying this key on the wire allows the server to
  /// safely reject retries that produce duplicate writes.
  static String computeIdempotencyKey(SyncRecord record) {
    final List<int> bytes =
        utf8.encode('${record.collection}:${record.id}:${record.hlc}');
    return sha256.convert(bytes).toString();
  }

  /// Stable identifier of the outbox entry (UUID v4).
  final String id;

  /// Record payload to push.
  final SyncRecord record;

  /// Operation to perform on the backend.
  final OutboxOperation operation;

  /// SHA-256 hex digest used by the backend to deduplicate retries.
  final String idempotencyKey;

  /// Current lifecycle status.
  final OutboxStatus status;

  /// Number of push attempts that have completed (succeeded or failed).
  final int attemptCount;

  /// Wall-clock instant the entry was created.
  final DateTime createdAt;

  /// Wall-clock instant of the most recent push attempt.
  final DateTime? lastAttemptAt;

  /// Wall-clock instant at which the next retry is scheduled.
  final DateTime? nextRetryAt;

  /// Actionable reason of the most recent failure; `null` when the entry
  /// has never failed.
  final String? failureReason;

  /// Convenience accessor: collection of the underlying [record].
  String get collection => record.collection;

  /// Convenience accessor: identifier of the underlying [record].
  String get recordId => record.id;

  /// Returns a copy of this entry with the supplied fields replaced.
  OutboxEntry copyWith({
    OutboxStatus? status,
    int? attemptCount,
    DateTime? lastAttemptAt,
    DateTime? nextRetryAt,
    String? failureReason,
  }) =>
      OutboxEntry(
        id: id,
        record: record,
        operation: operation,
        idempotencyKey: idempotencyKey,
        status: status ?? this.status,
        attemptCount: attemptCount ?? this.attemptCount,
        createdAt: createdAt,
        lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
        nextRetryAt: nextRetryAt ?? this.nextRetryAt,
        failureReason: failureReason ?? this.failureReason,
      );

  /// Serializes the entry to a JSON-compatible map.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'record': record.toJson(),
        'operation': operation.name,
        'idempotency_key': idempotencyKey,
        'status': status.name,
        'attempt_count': attemptCount,
        'created_at': createdAt.toUtc().toIso8601String(),
        'last_attempt_at': lastAttemptAt?.toUtc().toIso8601String(),
        'next_retry_at': nextRetryAt?.toUtc().toIso8601String(),
        'failure_reason': failureReason,
      };

  /// Reconstructs an entry from a JSON-compatible map.
  factory OutboxEntry.fromJson(Map<String, Object?> json) => OutboxEntry(
        id: json['id']! as String,
        record: SyncRecord.fromJson(
          Map<String, Object?>.from(json['record']! as Map<Object?, Object?>),
        ),
        operation: OutboxOperation.values.firstWhere(
          (OutboxOperation op) => op.name == json['operation'],
        ),
        idempotencyKey: json['idempotency_key']! as String,
        status: OutboxStatus.values.firstWhere(
          (OutboxStatus s) => s.name == json['status'],
        ),
        attemptCount: (json['attempt_count'] as int?) ?? 0,
        createdAt: DateTime.parse(json['created_at']! as String),
        lastAttemptAt: switch (json['last_attempt_at']) {
          final String s => DateTime.parse(s),
          _ => null,
        },
        nextRetryAt: switch (json['next_retry_at']) {
          final String s => DateTime.parse(s),
          _ => null,
        },
        failureReason: json['failure_reason'] as String?,
      );

  @override
  String toString() =>
      'OutboxEntry($id, ${record.collection}/${record.id}, status: ${status.name}, '
      'attempts: $attemptCount)';
}
