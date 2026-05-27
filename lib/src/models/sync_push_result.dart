// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

/// Outcome of a single `SyncAdapter.push` invocation.
///
/// [SyncPushResult] is a sealed hierarchy: callers must exhaustively pattern
/// match every variant. The variants distinguish full success, partial
/// success (some entries accepted, some rejected), retryable failure
/// (transient — schedule another attempt), and permanent failure
/// (dead-letter the entry).
@immutable
sealed class SyncPushResult {
  /// Internal const constructor for subclasses.
  const SyncPushResult();

  /// Creates a fully-successful push result.
  const factory SyncPushResult.success({
    required int pushedCount,
    String? serverCursor,
  }) = SyncPushResultSuccess;

  /// Creates a partial-success push result.
  const factory SyncPushResult.partial({
    required int pushedCount,
    required List<String> rejectedIds,
    String? serverCursor,
  }) = SyncPushResultPartial;

  /// Creates a retryable-failure push result, with an optional suggested
  /// [retryAfter] from the server (e.g. `Retry-After` header).
  const factory SyncPushResult.retry({
    required String reason,
    Duration? retryAfter,
  }) = SyncPushResultRetry;

  /// Creates a permanent-failure push result.
  const factory SyncPushResult.failure({
    required String reason,
    Object? cause,
  }) = SyncPushResultFailure;
}

/// Full-success variant of [SyncPushResult].
final class SyncPushResultSuccess extends SyncPushResult {
  /// Creates a success result.
  const SyncPushResultSuccess({
    required this.pushedCount,
    this.serverCursor,
  });

  /// Number of records the server accepted.
  final int pushedCount;

  /// Optional server-provided cursor advancing pull state.
  final String? serverCursor;

  @override
  bool operator ==(Object other) =>
      other is SyncPushResultSuccess &&
      other.pushedCount == pushedCount &&
      other.serverCursor == serverCursor;

  @override
  int get hashCode => Object.hash(pushedCount, serverCursor);

  @override
  String toString() =>
      'SyncPushResult.success(pushedCount: $pushedCount, cursor: $serverCursor)';
}

/// Partial-success variant of [SyncPushResult].
final class SyncPushResultPartial extends SyncPushResult {
  /// Creates a partial-success result.
  const SyncPushResultPartial({
    required this.pushedCount,
    required this.rejectedIds,
    this.serverCursor,
  });

  /// Number of records the server accepted.
  final int pushedCount;

  /// Identifiers the server rejected; these should be dead-lettered or
  /// re-routed through conflict resolution depending on the rejection
  /// reason (see [SyncPushResultFailure] for terminal failures).
  final List<String> rejectedIds;

  /// Optional server-provided cursor advancing pull state.
  final String? serverCursor;

  @override
  bool operator ==(Object other) =>
      other is SyncPushResultPartial &&
      other.pushedCount == pushedCount &&
      other.rejectedIds.length == rejectedIds.length &&
      other.serverCursor == serverCursor;

  @override
  int get hashCode => Object.hash(pushedCount, rejectedIds.length, serverCursor);

  @override
  String toString() => 'SyncPushResult.partial(pushed: $pushedCount, '
      'rejected: ${rejectedIds.length})';
}

/// Retryable-failure variant of [SyncPushResult].
final class SyncPushResultRetry extends SyncPushResult {
  /// Creates a retryable-failure result.
  const SyncPushResultRetry({required this.reason, this.retryAfter});

  /// Actionable description of why the push failed transiently.
  final String reason;

  /// Optional server-suggested delay before the next attempt.
  final Duration? retryAfter;

  @override
  bool operator ==(Object other) =>
      other is SyncPushResultRetry &&
      other.reason == reason &&
      other.retryAfter == retryAfter;

  @override
  int get hashCode => Object.hash(reason, retryAfter);

  @override
  String toString() =>
      'SyncPushResult.retry(reason: $reason, retryAfter: $retryAfter)';
}

/// Permanent-failure variant of [SyncPushResult].
final class SyncPushResultFailure extends SyncPushResult {
  /// Creates a permanent-failure result.
  const SyncPushResultFailure({required this.reason, this.cause});

  /// Actionable description of why the push failed permanently.
  final String reason;

  /// Optional underlying error object.
  final Object? cause;

  @override
  bool operator ==(Object other) =>
      other is SyncPushResultFailure &&
      other.reason == reason &&
      other.cause == cause;

  @override
  int get hashCode => Object.hash(reason, cause);

  @override
  String toString() => 'SyncPushResult.failure(reason: $reason)';
}
