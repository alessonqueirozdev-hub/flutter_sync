// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

import 'network_state.dart';

/// Per-collection statistics included in [SyncDebugInfo].
@immutable
class SyncCollectionStats {
  /// Creates immutable collection statistics.
  const SyncCollectionStats({
    required this.collection,
    required this.records,
    required this.pending,
    required this.failed,
    this.lastSyncedAt,
  });

  /// Logical collection name.
  final String collection;

  /// Number of records currently in the local store.
  final int records;

  /// Number of outbox entries currently pending for this collection.
  final int pending;

  /// Number of outbox entries in permanent-failure state.
  final int failed;

  /// HLC wire-format watermark for the most recent successful pull.
  final String? lastSyncedAt;

  @override
  String toString() =>
      'SyncCollectionStats($collection, records: $records, pending: $pending, '
      'failed: $failed)';
}

/// Snapshot of engine state useful for diagnostics and DevTools.
///
/// [SyncDebugInfo] is the value returned by `FlutterSync.debugInfo`. It is
/// produced on demand (no streaming) and represents a consistent point-in-time
/// view across all collections.
@immutable
class SyncDebugInfo {
  /// Creates an immutable debug snapshot.
  const SyncDebugInfo({
    required this.nodeId,
    required this.currentHlc,
    required this.networkState,
    required this.isPaused,
    required this.collections,
    this.outboxPendingTotal = 0,
    this.outboxFailedTotal = 0,
    this.lastSyncSuccessAt,
    this.lastSyncAttemptAt,
  });

  /// Stable installation identifier (UUID v4).
  final String nodeId;

  /// Current Hybrid Logical Clock wire-format value.
  final String currentHlc;

  /// Current observed connectivity state.
  final NetworkState networkState;

  /// `true` when the engine has been explicitly paused via `pause()`.
  final bool isPaused;

  /// Per-collection statistics, indexed by collection name.
  final Map<String, SyncCollectionStats> collections;

  /// Sum of `pending` across every collection.
  final int outboxPendingTotal;

  /// Sum of `failed` across every collection.
  final int outboxFailedTotal;

  /// Wall-clock instant of the most recent successful sync of any collection.
  final DateTime? lastSyncSuccessAt;

  /// Wall-clock instant of the most recent sync attempt of any collection.
  final DateTime? lastSyncAttemptAt;

  @override
  String toString() =>
      'SyncDebugInfo(node: $nodeId, hlc: $currentHlc, '
      'collections: ${collections.length}, '
      'pending: $outboxPendingTotal, failed: $outboxFailedTotal)';
}
