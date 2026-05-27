// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

/// High-level synchronization state surfaced on the public `status` stream.
///
/// [SyncStatus] is a sealed hierarchy: callers must use pattern matching to
/// exhaustively handle every variant. The order is approximately:
///
/// `idle` → `syncing` → `synced` → (eventually) `idle`,
///
/// with `offline`, `paused`, and `error` interleaved as appropriate.
@immutable
sealed class SyncStatus {
  /// Internal const constructor for subclasses.
  const SyncStatus();

  /// Constructs the idle status (no sync currently in progress).
  const factory SyncStatus.idle() = SyncStatusIdle;

  /// Constructs an in-progress syncing status.
  const factory SyncStatus.syncing({
    required int total,
    required int completed,
    String? collection,
  }) = SyncStatusSyncing;

  /// Constructs a successfully-synced status with the wall-clock instant
  /// at which the last sync completed.
  const factory SyncStatus.synced(DateTime at) = SyncStatusSynced;

  /// Constructs the offline status (no network connectivity).
  const factory SyncStatus.offline() = SyncStatusOffline;

  /// Constructs the paused status (sync explicitly stopped by the caller).
  const factory SyncStatus.paused() = SyncStatusPaused;

  /// Constructs an error status with an actionable [message] and an optional
  /// underlying [cause].
  const factory SyncStatus.error(String message, {Object? cause}) =
      SyncStatusError;
}

/// Idle status — the engine is ready and waiting for work.
final class SyncStatusIdle extends SyncStatus {
  /// Const constructor for the singleton-like idle status.
  const SyncStatusIdle();

  @override
  bool operator ==(Object other) => other is SyncStatusIdle;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'SyncStatus.idle';
}

/// Syncing status — a push or pull cycle is currently running.
final class SyncStatusSyncing extends SyncStatus {
  /// Creates a syncing status indicating progress.
  const SyncStatusSyncing({
    required this.total,
    required this.completed,
    this.collection,
  });

  /// Total number of records being processed in the current cycle.
  final int total;

  /// Number of records already processed in the current cycle.
  final int completed;

  /// Optional collection being synced; `null` when the cycle spans
  /// multiple collections.
  final String? collection;

  /// Progress in the inclusive range `[0.0, 1.0]`. Returns `0.0` when
  /// [total] is zero.
  double get progress => total == 0 ? 0.0 : completed / total;

  @override
  bool operator ==(Object other) =>
      other is SyncStatusSyncing &&
      other.total == total &&
      other.completed == completed &&
      other.collection == collection;

  @override
  int get hashCode => Object.hash(total, completed, collection);

  @override
  String toString() =>
      'SyncStatus.syncing($completed/$total${collection == null ? '' : ', $collection'})';
}

/// Synced status — the last sync attempt completed successfully.
final class SyncStatusSynced extends SyncStatus {
  /// Creates a synced status with the timestamp [at].
  const SyncStatusSynced(this.at);

  /// Wall-clock instant of the most recent successful sync.
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is SyncStatusSynced && other.at == at;

  @override
  int get hashCode => at.hashCode;

  @override
  String toString() => 'SyncStatus.synced(at: $at)';
}

/// Offline status — no network connectivity is currently available.
final class SyncStatusOffline extends SyncStatus {
  /// Const constructor for the singleton-like offline status.
  const SyncStatusOffline();

  @override
  bool operator ==(Object other) => other is SyncStatusOffline;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'SyncStatus.offline';
}

/// Paused status — sync has been explicitly stopped via `pause()`.
final class SyncStatusPaused extends SyncStatus {
  /// Const constructor for the singleton-like paused status.
  const SyncStatusPaused();

  @override
  bool operator ==(Object other) => other is SyncStatusPaused;

  @override
  int get hashCode => 2;

  @override
  String toString() => 'SyncStatus.paused';
}

/// Error status — a sync attempt failed with an actionable [message].
final class SyncStatusError extends SyncStatus {
  /// Creates an error status with the supplied [message] and optional
  /// underlying [cause].
  const SyncStatusError(this.message, {this.cause});

  /// Human-readable, actionable description of what went wrong.
  final String message;

  /// Optional underlying error object for debugging.
  final Object? cause;

  @override
  bool operator ==(Object other) =>
      other is SyncStatusError &&
      other.message == message &&
      other.cause == cause;

  @override
  int get hashCode => Object.hash(message, cause);

  @override
  String toString() => 'SyncStatus.error($message)';
}
