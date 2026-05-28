// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

import 'audit_entry.dart';

/// Fluent, immutable query builder for [AuditTrail.find].
@immutable
class AuditQuery {
  /// Creates an empty audit query.
  const AuditQuery({
    this.collection,
    this.recordId,
    this.operations,
    this.actorNodeId,
    this.since,
    this.until,
    this.limit,
    this.offset,
  });

  /// Restricts to entries for [collection].
  final String? collection;

  /// Restricts to entries for record id [recordId].
  final String? recordId;

  /// Restricts to entries whose operation is in this set.
  final Set<AuditOperation>? operations;

  /// Restricts to entries authored by [actorNodeId].
  final String? actorNodeId;

  /// Restricts to entries with `occurredAt >= since`.
  final DateTime? since;

  /// Restricts to entries with `occurredAt <= until`.
  final DateTime? until;

  /// Maximum number of entries returned.
  final int? limit;

  /// Number of entries skipped at the beginning of the result.
  final int? offset;

  /// Returns a copy restricted to [collection].
  AuditQuery whereCollection(String collection) =>
      _copy(collection: collection);

  /// Returns a copy restricted to [recordId].
  AuditQuery whereRecordId(String recordId) =>
      _copy(recordId: recordId);

  /// Returns a copy restricted to [operation].
  AuditQuery whereOperation(AuditOperation operation) =>
      _copy(operations: <AuditOperation>{...?operations, operation});

  /// Returns a copy restricted to [actorNodeId].
  AuditQuery whereActorNodeId(String actorNodeId) =>
      _copy(actorNodeId: actorNodeId);

  /// Returns a copy restricted to `occurredAt >= since`.
  AuditQuery whereSince(DateTime since) => _copy(since: since);

  /// Returns a copy restricted to `occurredAt <= until`.
  AuditQuery whereUntil(DateTime until) => _copy(until: until);

  /// Returns a copy with the supplied [limit] applied.
  AuditQuery limitTo(int limit) => _copy(limit: limit);

  /// Returns a copy with the supplied [offset] applied.
  AuditQuery skip(int offset) => _copy(offset: offset);

  /// Returns `true` when [entry] matches every constraint in this query.
  bool matches(AuditEntry entry) {
    if (collection != null && entry.collection != collection) {
      return false;
    }
    if (recordId != null && entry.recordId != recordId) {
      return false;
    }
    if (operations != null && !operations!.contains(entry.operation)) {
      return false;
    }
    if (actorNodeId != null && entry.actorNodeId != actorNodeId) {
      return false;
    }
    if (since != null && entry.occurredAt.isBefore(since!)) {
      return false;
    }
    if (until != null && entry.occurredAt.isAfter(until!)) {
      return false;
    }
    return true;
  }

  AuditQuery _copy({
    String? collection,
    String? recordId,
    Set<AuditOperation>? operations,
    String? actorNodeId,
    DateTime? since,
    DateTime? until,
    int? limit,
    int? offset,
  }) =>
      AuditQuery(
        collection: collection ?? this.collection,
        recordId: recordId ?? this.recordId,
        operations: operations ?? this.operations,
        actorNodeId: actorNodeId ?? this.actorNodeId,
        since: since ?? this.since,
        until: until ?? this.until,
        limit: limit ?? this.limit,
        offset: offset ?? this.offset,
      );
}
