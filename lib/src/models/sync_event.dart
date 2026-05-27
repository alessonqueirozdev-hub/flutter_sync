// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

import 'sync_conflict.dart';
import 'sync_record.dart';

/// Low-level event emitted by `SyncEngine`, adapters, and the outbox.
///
/// [SyncEvent] is a sealed hierarchy intended for diagnostics, DevTools, the
/// audit trail, and any caller that needs fine-grained insight into the
/// engine's lifecycle. The high-level public surface is `SyncStatus`; events
/// are the supporting raw signal.
@immutable
sealed class SyncEvent {
  /// Internal const constructor for subclasses.
  const SyncEvent();

  /// Wall-clock instant at which the event was generated.
  DateTime get at;
}

/// Marker event indicating that a sync cycle has started.
final class SyncEventCycleStarted extends SyncEvent {
  /// Creates a cycle-started event for the optional [collection].
  const SyncEventCycleStarted({required this.at, this.collection});

  @override
  final DateTime at;

  /// Optional collection scope; `null` when the cycle spans all collections.
  final String? collection;

  @override
  String toString() =>
      'SyncEvent.cycleStarted(${collection ?? 'all'}, at: $at)';
}

/// Marker event indicating that a sync cycle has finished.
final class SyncEventCycleCompleted extends SyncEvent {
  /// Creates a cycle-completed event.
  const SyncEventCycleCompleted({
    required this.at,
    required this.pushed,
    required this.pulled,
    this.collection,
  });

  @override
  final DateTime at;

  /// Number of records successfully pushed during the cycle.
  final int pushed;

  /// Number of records successfully pulled during the cycle.
  final int pulled;

  /// Optional collection scope.
  final String? collection;

  @override
  String toString() =>
      'SyncEvent.cycleCompleted(pushed: $pushed, pulled: $pulled, at: $at)';
}

/// A remote record has been received during pull.
final class SyncEventRecordReceived extends SyncEvent {
  /// Creates a record-received event carrying the received [record].
  const SyncEventRecordReceived({required this.at, required this.record});

  @override
  final DateTime at;

  /// The record received from the backend.
  final SyncRecord record;

  @override
  String toString() =>
      'SyncEvent.recordReceived(${record.collection}/${record.id}, at: $at)';
}

/// A local record has been pushed to the backend.
final class SyncEventRecordPushed extends SyncEvent {
  /// Creates a record-pushed event.
  const SyncEventRecordPushed({
    required this.at,
    required this.collection,
    required this.id,
    required this.hlc,
  });

  @override
  final DateTime at;

  /// Collection of the pushed record.
  final String collection;

  /// Identifier of the pushed record.
  final String id;

  /// Hybrid Logical Clock wire-format string of the pushed record.
  final String hlc;

  @override
  String toString() => 'SyncEvent.recordPushed($collection/$id, at: $at)';
}

/// A conflict has been detected between a local and a remote record.
final class SyncEventConflictDetected extends SyncEvent {
  /// Creates a conflict-detected event carrying the [conflict] payload.
  const SyncEventConflictDetected({required this.at, required this.conflict});

  @override
  final DateTime at;

  /// Conflict descriptor with the competing records.
  final SyncConflict conflict;

  @override
  String toString() => 'SyncEvent.conflictDetected('
      '${conflict.collection}/${conflict.id}, at: $at)';
}

/// A conflict has been resolved.
final class SyncEventConflictResolved extends SyncEvent {
  /// Creates a conflict-resolved event with the resolved [winner] record and
  /// the [strategy] string identifying the resolver that was used.
  const SyncEventConflictResolved({
    required this.at,
    required this.winner,
    required this.strategy,
  });

  @override
  final DateTime at;

  /// The record that won the resolution.
  final SyncRecord winner;

  /// Identifier of the resolver strategy used.
  final String strategy;

  @override
  String toString() => 'SyncEvent.conflictResolved('
      '${winner.collection}/${winner.id}, strategy: $strategy, at: $at)';
}

/// A push has been retried after a transient failure.
final class SyncEventRetryScheduled extends SyncEvent {
  /// Creates a retry-scheduled event with the delay until the next attempt.
  const SyncEventRetryScheduled({
    required this.at,
    required this.collection,
    required this.id,
    required this.attempt,
    required this.nextDelay,
  });

  @override
  final DateTime at;

  /// Collection of the entry being retried.
  final String collection;

  /// Identifier of the entry being retried.
  final String id;

  /// 1-based attempt number that just failed.
  final int attempt;

  /// Computed delay until the next retry.
  final Duration nextDelay;

  @override
  String toString() =>
      'SyncEvent.retryScheduled($collection/$id, attempt: $attempt, '
      'next: $nextDelay)';
}

/// An entry has exhausted its retry budget and is now dead-lettered.
final class SyncEventPermanentFailure extends SyncEvent {
  /// Creates a permanent-failure event with an actionable [reason].
  const SyncEventPermanentFailure({
    required this.at,
    required this.collection,
    required this.id,
    required this.reason,
  });

  @override
  final DateTime at;

  /// Collection of the failed entry.
  final String collection;

  /// Identifier of the failed entry.
  final String id;

  /// Actionable description of why the entry failed permanently.
  final String reason;

  @override
  String toString() =>
      'SyncEvent.permanentFailure($collection/$id, reason: $reason)';
}

/// Periodic heartbeat event emitted by the scheduler.
final class SyncEventHeartbeat extends SyncEvent {
  /// Creates a heartbeat event.
  const SyncEventHeartbeat({required this.at});

  @override
  final DateTime at;

  @override
  String toString() => 'SyncEvent.heartbeat(at: $at)';
}
