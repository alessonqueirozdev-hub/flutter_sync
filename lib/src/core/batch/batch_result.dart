// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

import '../../models/sync_batch.dart';

/// Outcome of processing a single [SyncBatch] through `BatchProcessor`.
///
/// [BatchResult] is a sealed hierarchy: callers must exhaustively pattern
/// match every variant. Variants distinguish full success, partial success,
/// retryable failure, and permanent failure.
@immutable
sealed class BatchResult {
  /// Internal const constructor for subclasses.
  const BatchResult();

  /// The batch this result describes.
  SyncBatch get batch;

  /// Creates a full-success result for [batch].
  const factory BatchResult.success(SyncBatch batch) = BatchResultSuccess;

  /// Creates a partial-success result with the ids of [rejectedIds] that
  /// the backend did not accept.
  const factory BatchResult.partial({
    required SyncBatch batch,
    required List<String> rejectedIds,
  }) = BatchResultPartial;

  /// Creates a retryable-failure result.
  const factory BatchResult.retry({
    required SyncBatch batch,
    required String reason,
    Duration? retryAfter,
  }) = BatchResultRetry;

  /// Creates a permanent-failure result.
  const factory BatchResult.failure({
    required SyncBatch batch,
    required String reason,
    Object? cause,
  }) = BatchResultFailure;
}

/// Full-success variant of [BatchResult].
final class BatchResultSuccess extends BatchResult {
  /// Creates a success result for [batch].
  const BatchResultSuccess(this.batch);

  @override
  final SyncBatch batch;

  @override
  String toString() => 'BatchResult.success(${batch.id}, size: ${batch.size})';
}

/// Partial-success variant of [BatchResult].
final class BatchResultPartial extends BatchResult {
  /// Creates a partial-success result.
  const BatchResultPartial({required this.batch, required this.rejectedIds});

  @override
  final SyncBatch batch;

  /// Identifiers the backend rejected.
  final List<String> rejectedIds;

  @override
  String toString() => 'BatchResult.partial(${batch.id}, '
      'rejected: ${rejectedIds.length}/${batch.size})';
}

/// Retryable-failure variant of [BatchResult].
final class BatchResultRetry extends BatchResult {
  /// Creates a retryable-failure result.
  const BatchResultRetry({
    required this.batch,
    required this.reason,
    this.retryAfter,
  });

  @override
  final SyncBatch batch;

  /// Actionable description of why the batch must be retried.
  final String reason;

  /// Optional server-suggested delay before the next attempt.
  final Duration? retryAfter;

  @override
  String toString() => 'BatchResult.retry(${batch.id}, reason: $reason)';
}

/// Permanent-failure variant of [BatchResult].
final class BatchResultFailure extends BatchResult {
  /// Creates a permanent-failure result.
  const BatchResultFailure({
    required this.batch,
    required this.reason,
    this.cause,
  });

  @override
  final SyncBatch batch;

  /// Actionable description of the permanent failure.
  final String reason;

  /// Optional underlying error.
  final Object? cause;

  @override
  String toString() => 'BatchResult.failure(${batch.id}, reason: $reason)';
}
