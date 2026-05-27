// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

import '../../models/sync_record.dart';
import '../../store/sync_store.dart';

/// Outcome of a single [RollbackHandler.rollback] invocation.
@immutable
class RollbackOutcome {
  /// Creates an immutable rollback outcome.
  const RollbackOutcome({
    required this.collection,
    required this.id,
    required this.action,
    this.restored,
  });

  /// Collection of the rolled-back record.
  final String collection;

  /// Identifier of the rolled-back record.
  final String id;

  /// Action taken by the handler.
  final RollbackAction action;

  /// Record that was restored to the store; `null` when the action was
  /// [RollbackAction.deleted] (no record to restore).
  final SyncRecord? restored;

  @override
  String toString() => 'RollbackOutcome($collection/$id, action: $action)';
}

/// Concrete action taken by the [RollbackHandler] during a rollback.
enum RollbackAction {
  /// The local record was deleted because the optimistic update was an
  /// insert with no prior state.
  deleted,

  /// The previous local record was restored.
  restored,

  /// No action was needed because the local record matched the optimistic
  /// state (e.g. a concurrent operation already reverted it).
  noop,
}

/// Restores the local store to its pre-optimistic state when a write
/// permanently fails to reach the backend.
///
/// The handler is intentionally separated from [OptimisticUpdateManager]
/// so that the outbox can invoke it without holding a reference to the
/// manager (which lives in the engine layer). It accepts the pre-update
/// snapshot directly.
class RollbackHandler {
  /// Creates a handler bound to [store].
  const RollbackHandler({required SyncStore store}) : _store = store;

  final SyncStore _store;

  /// Reverts the local record `(collection, id)` to [previousState].
  ///
  /// When [previousState] is `null`, the local record is deleted (the
  /// optimistic update inserted a new record that must not survive). When
  /// [previousState] is non-null, the previous record is re-applied to
  /// restore its pre-update state.
  Future<RollbackOutcome> rollback({
    required String collection,
    required String id,
    required SyncRecord? previousState,
  }) async {
    if (previousState == null) {
      await _store.delete(collection, id);
      return RollbackOutcome(
        collection: collection,
        id: id,
        action: RollbackAction.deleted,
      );
    }
    await _store.upsert(previousState);
    return RollbackOutcome(
      collection: collection,
      id: id,
      action: RollbackAction.restored,
      restored: previousState,
    );
  }
}
