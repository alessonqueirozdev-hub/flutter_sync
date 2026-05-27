// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

import 'sync_record.dart';

/// Outcome of a single `SyncAdapter.pull` invocation.
///
/// [SyncPullResult] is a sealed hierarchy: callers must exhaustively pattern
/// match every variant. The variants distinguish successful incremental
/// pulls (with new records and optionally a new cursor), empty pulls
/// (server has no new data), retryable failure, and permanent failure.
@immutable
sealed class SyncPullResult {
  /// Internal const constructor for subclasses.
  const SyncPullResult();

  /// Creates a successful pull result with [records] and an optional updated
  /// [highWaterHlc] (the HLC wire-format string to advance `lastSyncedAt` to).
  const factory SyncPullResult.success({
    required List<SyncRecord> records,
    String? highWaterHlc,
    bool hasMore,
  }) = SyncPullResultSuccess;

  /// Creates an empty pull result indicating the server has no new data.
  const factory SyncPullResult.empty() = SyncPullResultEmpty;

  /// Creates a retryable-failure pull result.
  const factory SyncPullResult.retry({
    required String reason,
    Duration? retryAfter,
  }) = SyncPullResultRetry;

  /// Creates a permanent-failure pull result.
  const factory SyncPullResult.failure({
    required String reason,
    Object? cause,
  }) = SyncPullResultFailure;
}

/// Success variant of [SyncPullResult].
final class SyncPullResultSuccess extends SyncPullResult {
  /// Creates a successful pull result.
  const SyncPullResultSuccess({
    required this.records,
    this.highWaterHlc,
    this.hasMore = false,
  });

  /// Records returned by the server, ordered by ascending HLC.
  final List<SyncRecord> records;

  /// New high-water HLC mark to persist into `SyncMetadata.lastSyncedAt`.
  /// When `null`, the caller computes it from [records].
  final String? highWaterHlc;

  /// `true` when the server indicates additional pages remain to be fetched
  /// in subsequent pulls.
  final bool hasMore;

  @override
  bool operator ==(Object other) =>
      other is SyncPullResultSuccess &&
      other.records.length == records.length &&
      other.highWaterHlc == highWaterHlc &&
      other.hasMore == hasMore;

  @override
  int get hashCode => Object.hash(records.length, highWaterHlc, hasMore);

  @override
  String toString() => 'SyncPullResult.success(records: ${records.length}, '
      'highWaterHlc: $highWaterHlc, hasMore: $hasMore)';
}

/// Empty variant of [SyncPullResult].
final class SyncPullResultEmpty extends SyncPullResult {
  /// Creates an empty pull result.
  const SyncPullResultEmpty();

  @override
  bool operator ==(Object other) => other is SyncPullResultEmpty;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'SyncPullResult.empty';
}

/// Retryable-failure variant of [SyncPullResult].
final class SyncPullResultRetry extends SyncPullResult {
  /// Creates a retryable-failure pull result.
  const SyncPullResultRetry({required this.reason, this.retryAfter});

  /// Actionable description of why the pull failed transiently.
  final String reason;

  /// Optional server-suggested delay before the next attempt.
  final Duration? retryAfter;

  @override
  bool operator ==(Object other) =>
      other is SyncPullResultRetry &&
      other.reason == reason &&
      other.retryAfter == retryAfter;

  @override
  int get hashCode => Object.hash(reason, retryAfter);

  @override
  String toString() =>
      'SyncPullResult.retry(reason: $reason, retryAfter: $retryAfter)';
}

/// Permanent-failure variant of [SyncPullResult].
final class SyncPullResultFailure extends SyncPullResult {
  /// Creates a permanent-failure pull result.
  const SyncPullResultFailure({required this.reason, this.cause});

  /// Actionable description of why the pull failed permanently.
  final String reason;

  /// Optional underlying error object.
  final Object? cause;

  @override
  bool operator ==(Object other) =>
      other is SyncPullResultFailure &&
      other.reason == reason &&
      other.cause == cause;

  @override
  int get hashCode => Object.hash(reason, cause);

  @override
  String toString() => 'SyncPullResult.failure(reason: $reason)';
}
