// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

import '../../models/sync_record.dart';
import '../../store/sync_store.dart';
import '../hlc/hlc_clock.dart';
import '../hlc/hlc_timestamp.dart';

/// Snapshot used to rewind an optimistic update that failed permanently.
@immutable
class OptimisticSnapshot {
  /// Captures the [previous] state of the record before the optimistic
  /// update was applied. [previous] is `null` when the optimistic update
  /// inserted a new record.
  const OptimisticSnapshot({
    required this.collection,
    required this.id,
    required this.optimisticHlc,
    this.previous,
  });

  /// Collection of the record under optimistic update.
  final String collection;

  /// Identifier of the record under optimistic update.
  final String id;

  /// HLC wire-format value of the optimistic update.
  final String optimisticHlc;

  /// Local state of the record immediately before the optimistic update;
  /// `null` when the update inserted a new record.
  final SyncRecord? previous;

  @override
  String toString() =>
      'OptimisticSnapshot($collection/$id, optimisticHlc: $optimisticHlc)';
}

/// Coordinates the apply-and-revert lifecycle of optimistic local writes.
///
/// Every public write goes through [applyOptimistic], which:
///
/// 1. Reads the previous local state (so it can be restored on failure).
/// 2. Stamps the write with a fresh [HLCTimestamp] via the supplied clock.
/// 3. Persists the new record through `SyncStore.upsert`.
/// 4. Hands the caller back the inserted record and an
///    [OptimisticSnapshot] reference held internally.
///
/// The engine then enqueues the write in the outbox. When the outbox
/// receives the final outcome, it calls [confirm] (success) or [rollback]
/// (permanent failure).
class OptimisticUpdateManager {
  /// Creates a manager bound to [store] and [clock].
  OptimisticUpdateManager({
    required SyncStore store,
    required HybridLogicalClock clock,
  })  : _store = store,
        _clock = clock;

  final SyncStore _store;
  final HybridLogicalClock _clock;
  final Map<String, OptimisticSnapshot> _pending =
      HashMap<String, OptimisticSnapshot>();

  /// Number of optimistic updates currently awaiting confirmation.
  int get pendingCount => _pending.length;

  /// Returns `true` when an optimistic update for `(collection, id)` is
  /// currently pending.
  bool isPending(String collection, String id) =>
      _pending.containsKey(_key(collection, id));

  /// Applies an optimistic write to the local store, returning the newly
  /// persisted record.
  ///
  /// [payload] is treated as opaque structured data; the manager does not
  /// inspect it. When [isDelete] is `true`, the persisted record is a
  /// tombstone with [payload] preserved verbatim (some adapters need it).
  Future<SyncRecord> applyOptimistic({
    required String collection,
    required String id,
    required Map<String, Object?> payload,
    bool isDelete = false,
  }) async {
    final SyncRecord? previous = await _store.findById(collection, id);
    final HLCTimestamp stamp = _clock.tick();
    final DateTime now = DateTime.now().toUtc();
    final SyncRecord record = SyncRecord(
      id: id,
      collection: collection,
      payload: payload,
      hlc: stamp.toWire(),
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
      isDeleted: isDelete,
    );
    await _store.upsert(record);
    _pending[_key(collection, id)] = OptimisticSnapshot(
      collection: collection,
      id: id,
      optimisticHlc: record.hlc,
      previous: previous,
    );
    return record;
  }

  /// Confirms the optimistic update for [record], releasing its snapshot.
  ///
  /// Called by the outbox after the backend has accepted the push.
  void confirm(SyncRecord record) {
    _pending.remove(_key(record.collection, record.id));
  }

  /// Reverts the optimistic update for `(collection, id)` to its
  /// pre-update state.
  ///
  /// Called by the outbox after the push has permanently failed. Returns
  /// the snapshot that was rolled back, or `null` when no pending update
  /// existed for that key (e.g. a concurrent confirm has already arrived).
  Future<OptimisticSnapshot?> rollback({
    required String collection,
    required String id,
  }) async {
    final OptimisticSnapshot? snapshot = _pending.remove(_key(collection, id));
    if (snapshot == null) {
      return null;
    }
    if (snapshot.previous == null) {
      await _store.delete(collection, id);
    } else {
      await _store.upsert(snapshot.previous!);
    }
    return snapshot;
  }

  /// Returns an unmodifiable view of every pending snapshot.
  Map<String, OptimisticSnapshot> snapshotPending() {
    return Map<String, OptimisticSnapshot>.unmodifiable(_pending);
  }

  /// Releases internal state. Does not touch the underlying [SyncStore].
  Future<void> dispose() async {
    _pending.clear();
  }

  String _key(String collection, String id) => '$collection/$id';
}
