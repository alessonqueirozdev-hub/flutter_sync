// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// Operation captured by an [AuditEntry].
enum AuditOperation {
  /// A new record was inserted locally and queued for push.
  upsert,

  /// A tombstone was applied locally and queued for push.
  delete,

  /// A remote record was integrated into the local store.
  pulled,

  /// A conflict was resolved.
  conflictResolved,

  /// A push attempt succeeded.
  pushed,

  /// A push attempt failed permanently and was dead-lettered.
  permanentFailure,
}

/// Single immutable entry in the audit trail.
@immutable
class AuditEntry {
  /// Creates an audit entry. [id] defaults to a fresh UUID v4.
  AuditEntry({
    required this.occurredAt, required this.collection, required this.recordId, required this.operation, required this.actorNodeId, String? id,
    this.detail,
    Uuid? uuid,
  }) : id = id ?? (uuid ?? const Uuid()).v4();

  /// Reconstructs an entry from a JSON-compatible map.
  factory AuditEntry.fromJson(Map<String, Object?> json) => AuditEntry(
        id: json['id']! as String,
        occurredAt: DateTime.parse(json['occurred_at']! as String),
        collection: json['collection']! as String,
        recordId: json['record_id']! as String,
        operation: AuditOperation.values
            .firstWhere((AuditOperation o) => o.name == json['operation']),
        actorNodeId: json['actor_node_id']! as String,
        detail: switch (json['detail']) {
          final Map<Object?, Object?> m => Map<String, Object?>.from(m),
          _ => null,
        },
      );

  /// Stable identifier of the entry.
  final String id;

  /// Wall-clock instant the operation occurred.
  final DateTime occurredAt;

  /// Collection of the affected record.
  final String collection;

  /// Identifier of the affected record.
  final String recordId;

  /// Operation that was performed.
  final AuditOperation operation;

  /// HLC `nodeId` of the actor that performed the operation.
  final String actorNodeId;

  /// Optional structured detail (e.g. `{conflictStrategy: 'lww'}`).
  final Map<String, Object?>? detail;

  /// Serializes the entry to a JSON-compatible map.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'collection': collection,
        'record_id': recordId,
        'operation': operation.name,
        'actor_node_id': actorNodeId,
        'detail': detail,
      };

  @override
  String toString() =>
      'AuditEntry($collection/$recordId, ${operation.name}, at: $occurredAt)';
}
