// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import '../models/sync_conflict.dart';
import '../models/sync_record.dart';

/// Identifier of a built-in conflict-resolution strategy.
///
/// Custom resolvers expose [ConflictResolutionStrategy.custom] together with
/// a name reported through `ConflictResolver.name`, allowing the audit trail
/// and DevTools to log which resolver was invoked for each conflict.
enum ConflictResolutionStrategy {
  /// Last-Write-Wins using HLC timestamps.
  lastWriteWins,

  /// The remote record always wins.
  serverWins,

  /// The local record always wins.
  clientWins,

  /// CRDT merge: the resolver knows how to combine the two records
  /// associatively, commutatively, and idempotently.
  crdt,

  /// Per-field resolution: each field is resolved independently with its
  /// own sub-strategy.
  fieldLevel,

  /// User-supplied resolver. The actual logic is in
  /// `ConflictResolver.resolve`.
  custom,
}

/// Contract every conflict-resolution implementation must satisfy.
///
/// Resolvers are invoked synchronously when a pull observes a record whose
/// local counterpart was modified since the last successful sync. The
/// engine then propagates the returned [SyncRecord] to the store and the
/// outbox so that both sides converge to the resolved value.
abstract interface class ConflictResolver {
  /// Resolves the supplied [conflict] to a single canonical [SyncRecord].
  ///
  /// Implementations must be deterministic given identical inputs (so that
  /// concurrent replicas converge to the same value) and must not throw —
  /// fallible logic returns either the local or the remote record with a
  /// rationale logged through the engine's `SyncLogger`.
  Future<SyncRecord> resolve(SyncConflict conflict);

  /// Identifier of the strategy implemented by this resolver.
  ConflictResolutionStrategy get strategy;

  /// Human-readable name surfaced in the audit trail and DevTools.
  ///
  /// Built-in resolvers return a stable identifier (for example
  /// `'lww'`, `'server-wins'`); custom resolvers should return a unique
  /// name that allows operators to correlate audit entries with the
  /// resolver source code.
  String get name;
}
