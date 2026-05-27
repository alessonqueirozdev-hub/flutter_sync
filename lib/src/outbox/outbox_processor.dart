// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import 'package:uuid/uuid.dart';

import '../adapters/sync_adapter.dart';
import '../models/sync_batch.dart';
import '../models/sync_push_result.dart';
import '../models/sync_record.dart';
import 'outbox_entry.dart';
import 'outbox_queue.dart';
import 'retry_strategy.dart';

/// Outcome of a single [OutboxProcessor.processOnce] call.
class OutboxProcessResult {
  /// Creates a processing summary.
  const OutboxProcessResult({
    required this.attempted,
    required this.succeeded,
    required this.retried,
    required this.deadLettered,
  });

  /// Empty result with all counters at zero.
  factory OutboxProcessResult.empty() => const OutboxProcessResult(
        attempted: 0,
        succeeded: 0,
        retried: 0,
        deadLettered: 0,
      );

  /// Number of entries the processor attempted to push.
  final int attempted;

  /// Number of entries the backend accepted.
  final int succeeded;

  /// Number of entries the processor rescheduled for later retry.
  final int retried;

  /// Number of entries that exhausted their retry budget and were
  /// dead-lettered.
  final int deadLettered;

  @override
  String toString() => 'OutboxProcessResult(attempted: $attempted, '
      'succeeded: $succeeded, retried: $retried, deadLettered: $deadLettered)';
}

/// Drains the [OutboxQueue] by pushing entries through a [SyncAdapter].
///
/// The processor batches entries by collection (respecting the
/// `OutboxQueue`'s ordering) and calls `SyncAdapter.push` with one batch
/// at a time. Outcomes are translated to entry status updates:
///
/// - `SyncPushResultSuccess` → entries marked [OutboxStatus.synced], TTL
///   eviction handled by a separate housekeeping pass.
/// - `SyncPushResultPartial` → succeeded entries marked synced; rejected
///   entries returned to [OutboxStatus.pending] with their retry clock
///   advanced.
/// - `SyncPushResultRetry` → every entry in the batch returned to
///   [OutboxStatus.pending] with a fresh `nextRetryAt`.
/// - `SyncPushResultFailure` → every entry in the batch dead-lettered
///   (marked [OutboxStatus.failed]) and surfaced via the [onFailure]
///   callback.
class OutboxProcessor {
  /// Creates a processor bound to [queue], [adapter] and [retryStrategy].
  OutboxProcessor({
    required this.queue,
    required this.adapter,
    required this.retryStrategy,
    this.maxBatchSize = 100,
    this.onFailure,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  /// Source of pending entries.
  final OutboxQueue queue;

  /// Backend transport.
  final SyncAdapter adapter;

  /// Strategy used to compute retry delays.
  final RetryStrategy retryStrategy;

  /// Maximum number of entries pushed in a single batch.
  final int maxBatchSize;

  /// Callback invoked once per dead-lettered entry. May be `null`.
  final void Function(OutboxEntry entry, String reason)? onFailure;

  final Uuid _uuid;
  bool _running = false;

  /// Processes a single pass over the queue and returns the per-pass
  /// summary.
  ///
  /// Safe to call concurrently — only one pass executes at a time; extra
  /// calls return an empty summary immediately so callers do not need to
  /// implement their own mutual exclusion.
  Future<OutboxProcessResult> processOnce({DateTime? now}) async {
    if (_running) {
      return OutboxProcessResult.empty();
    }
    _running = true;
    try {
      final List<OutboxEntry> due = await queue.dueEntries(
        now: now,
        limit: maxBatchSize,
      );
      if (due.isEmpty) {
        return OutboxProcessResult.empty();
      }
      final Map<String, List<OutboxEntry>> byCollection =
          <String, List<OutboxEntry>>{};
      for (final OutboxEntry entry in due) {
        byCollection
            .putIfAbsent(entry.collection, () => <OutboxEntry>[])
            .add(entry);
      }

      int attempted = 0;
      int succeeded = 0;
      int retried = 0;
      int deadLettered = 0;

      for (final MapEntry<String, List<OutboxEntry>> bucket
          in byCollection.entries) {
        final List<OutboxEntry> bucketEntries = bucket.value;
        await _markInflight(bucketEntries);
        attempted += bucketEntries.length;

        final SyncBatch batch = SyncBatch(
          id: _uuid.v4(),
          collection: bucket.key,
          entries: <SyncRecord>[
            for (final OutboxEntry e in bucketEntries) e.record,
          ],
          createdAt: DateTime.now().toUtc(),
        );

        late SyncPushResult result;
        try {
          result = await adapter.push(batch);
        } catch (e) {
          result = SyncPushResult.retry(reason: 'adapter threw: $e');
        }

        final _Outcome outcome = await _applyResult(bucketEntries, result, now);
        succeeded += outcome.succeeded;
        retried += outcome.retried;
        deadLettered += outcome.deadLettered;
      }

      return OutboxProcessResult(
        attempted: attempted,
        succeeded: succeeded,
        retried: retried,
        deadLettered: deadLettered,
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _markInflight(List<OutboxEntry> entries) async {
    for (final OutboxEntry entry in entries) {
      await queue.update(
        entry.copyWith(
          status: OutboxStatus.inflight,
          lastAttemptAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  Future<_Outcome> _applyResult(
    List<OutboxEntry> entries,
    SyncPushResult result,
    DateTime? now,
  ) async {
    switch (result) {
      case SyncPushResultSuccess():
        for (final OutboxEntry entry in entries) {
          await queue.update(entry.copyWith(status: OutboxStatus.synced));
        }
        return _Outcome(succeeded: entries.length);
      case SyncPushResultPartial(:final List<String> rejectedIds):
        int succeeded = 0;
        int retried = 0;
        int dead = 0;
        for (final OutboxEntry entry in entries) {
          if (!rejectedIds.contains(entry.recordId)) {
            await queue.update(entry.copyWith(status: OutboxStatus.synced));
            succeeded += 1;
            continue;
          }
          final int newAttempt = entry.attemptCount + 1;
          if (newAttempt >= retryStrategy.maxAttempts) {
            await queue.update(
              entry.copyWith(
                status: OutboxStatus.failed,
                attemptCount: newAttempt,
                failureReason: 'server rejected entry id',
              ),
            );
            dead += 1;
            onFailure?.call(entry, 'server rejected entry id');
            continue;
          }
          final Duration delay = retryStrategy.nextDelay(newAttempt);
          await queue.update(
            entry.copyWith(
              status: OutboxStatus.pending,
              attemptCount: newAttempt,
              nextRetryAt: (now ?? DateTime.now().toUtc()).add(delay),
              failureReason: 'server rejected entry id',
            ),
          );
          retried += 1;
        }
        return _Outcome(succeeded: succeeded, retried: retried, deadLettered: dead);
      case SyncPushResultRetry(:final String reason, :final Duration? retryAfter):
        int retried = 0;
        int dead = 0;
        for (final OutboxEntry entry in entries) {
          final int newAttempt = entry.attemptCount + 1;
          if (newAttempt >= retryStrategy.maxAttempts) {
            await queue.update(
              entry.copyWith(
                status: OutboxStatus.failed,
                attemptCount: newAttempt,
                failureReason: reason,
              ),
            );
            dead += 1;
            onFailure?.call(entry, reason);
            continue;
          }
          final Duration delay =
              retryAfter ?? retryStrategy.nextDelay(newAttempt);
          await queue.update(
            entry.copyWith(
              status: OutboxStatus.pending,
              attemptCount: newAttempt,
              nextRetryAt: (now ?? DateTime.now().toUtc()).add(delay),
              failureReason: reason,
            ),
          );
          retried += 1;
        }
        return _Outcome(retried: retried, deadLettered: dead);
      case SyncPushResultFailure(:final String reason):
        for (final OutboxEntry entry in entries) {
          await queue.update(
            entry.copyWith(
              status: OutboxStatus.failed,
              attemptCount: entry.attemptCount + 1,
              failureReason: reason,
            ),
          );
          onFailure?.call(entry, reason);
        }
        return _Outcome(deadLettered: entries.length);
    }
  }
}

class _Outcome {
  const _Outcome({this.succeeded = 0, this.retried = 0, this.deadLettered = 0});
  final int succeeded;
  final int retried;
  final int deadLettered;
}
