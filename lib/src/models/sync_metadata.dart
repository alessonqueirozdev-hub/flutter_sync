// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

/// Per-collection synchronization metadata persisted by `SyncStore`.
///
/// `SyncMetadata` tracks the high-water mark required to perform delta
/// pulls (`lastSyncedAt`), the stable installation node identifier
/// (`nodeId`) and counters useful for diagnostics. One instance is
/// maintained per collection and updated atomically alongside the records
/// it summarizes.
@immutable
class SyncMetadata {
  /// Creates an immutable [SyncMetadata] snapshot.
  const SyncMetadata({
    required this.collection,
    required this.nodeId,
    this.lastSyncedAt,
    this.recordCount = 0,
    this.pendingCount = 0,
    this.lastSyncAttemptAt,
    this.lastSyncSuccessAt,
    this.failureCount = 0,
  });

  /// Reconstructs a [SyncMetadata] from a JSON-compatible map.
  factory SyncMetadata.fromJson(Map<String, Object?> json) => SyncMetadata(
        collection: json['collection']! as String,
        nodeId: json['node_id']! as String,
        lastSyncedAt: json['last_synced_at'] as String?,
        recordCount: (json['record_count'] as int?) ?? 0,
        pendingCount: (json['pending_count'] as int?) ?? 0,
        lastSyncAttemptAt: switch (json['last_sync_attempt_at']) {
          final String s => DateTime.parse(s),
          _ => null,
        },
        lastSyncSuccessAt: switch (json['last_sync_success_at']) {
          final String s => DateTime.parse(s),
          _ => null,
        },
        failureCount: (json['failure_count'] as int?) ?? 0,
      );

  /// Returns an empty metadata snapshot bound to [collection] and [nodeId].
  factory SyncMetadata.empty({
    required String collection,
    required String nodeId,
  }) =>
      SyncMetadata(collection: collection, nodeId: nodeId);

  /// Logical collection this metadata is associated with.
  final String collection;

  /// Stable installation identifier (UUID v4) that owns this metadata.
  final String nodeId;

  /// Hybrid Logical Clock wire-format string of the most recent remote
  /// record observed during pull. `null` when no successful pull has run yet.
  final String? lastSyncedAt;

  /// Number of records currently held in the local store for [collection].
  final int recordCount;

  /// Number of outbox entries currently pending for [collection].
  final int pendingCount;

  /// Wall-clock instant of the most recent sync attempt, regardless of
  /// outcome.
  final DateTime? lastSyncAttemptAt;

  /// Wall-clock instant of the most recent successful sync.
  final DateTime? lastSyncSuccessAt;

  /// Number of consecutive sync attempts that have failed since the last
  /// success.
  final int failureCount;

  /// Returns a copy of this metadata with the supplied fields replaced.
  SyncMetadata copyWith({
    String? collection,
    String? nodeId,
    String? lastSyncedAt,
    int? recordCount,
    int? pendingCount,
    DateTime? lastSyncAttemptAt,
    DateTime? lastSyncSuccessAt,
    int? failureCount,
  }) {
    return SyncMetadata(
      collection: collection ?? this.collection,
      nodeId: nodeId ?? this.nodeId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      recordCount: recordCount ?? this.recordCount,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncAttemptAt: lastSyncAttemptAt ?? this.lastSyncAttemptAt,
      lastSyncSuccessAt: lastSyncSuccessAt ?? this.lastSyncSuccessAt,
      failureCount: failureCount ?? this.failureCount,
    );
  }

  /// Serializes the metadata to a JSON-compatible map.
  Map<String, Object?> toJson() => <String, Object?>{
        'collection': collection,
        'node_id': nodeId,
        'last_synced_at': lastSyncedAt,
        'record_count': recordCount,
        'pending_count': pendingCount,
        'last_sync_attempt_at': lastSyncAttemptAt?.toUtc().toIso8601String(),
        'last_sync_success_at': lastSyncSuccessAt?.toUtc().toIso8601String(),
        'failure_count': failureCount,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SyncMetadata &&
        other.collection == collection &&
        other.nodeId == nodeId &&
        other.lastSyncedAt == lastSyncedAt &&
        other.recordCount == recordCount &&
        other.pendingCount == pendingCount &&
        other.lastSyncAttemptAt == lastSyncAttemptAt &&
        other.lastSyncSuccessAt == lastSyncSuccessAt &&
        other.failureCount == failureCount;
  }

  @override
  int get hashCode => Object.hash(
        collection,
        nodeId,
        lastSyncedAt,
        recordCount,
        pendingCount,
        lastSyncAttemptAt,
        lastSyncSuccessAt,
        failureCount,
      );

  @override
  String toString() =>
      'SyncMetadata(collection: $collection, lastSyncedAt: $lastSyncedAt, '
      'records: $recordCount, pending: $pendingCount, failures: $failureCount)';
}
