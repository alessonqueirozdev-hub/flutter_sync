// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import '../../models/sync_batch.dart';
import '../../models/sync_event.dart';
import '../../models/sync_pull_request.dart';
import '../../models/sync_pull_result.dart';
import '../../models/sync_push_result.dart';
import '../../models/sync_record.dart';
import '../sync_adapter.dart';

/// In-memory [SyncAdapter] for tests, prototypes, and the example app.
///
/// The adapter behaves like a perfectly reliable server unless one of the
/// configurable injection points is wired up:
///
/// - `pushBehavior` — replace the default success behavior with a custom
///   per-batch outcome (e.g. force partial success or retry).
/// - `pullBehavior` — replace the default delta-pull behavior.
/// - `latency` — synthetic delay added before every operation.
/// - `failNextPushes` / `failNextPulls` — fail the next N operations,
///   then return to normal.
class MockSyncAdapter implements SyncAdapter {
  /// Creates a mock adapter.
  MockSyncAdapter({
    this.latency = Duration.zero,
    SyncAdapterCapabilities? capabilities,
  }) : capabilities = capabilities ??
            const SyncAdapterCapabilities(
              realtime: true,
              serverSideFilters: false,
              partialSync: false,
              idempotentPush: true,
              deltaPull: true,
              maxBatchSize: 1000,
            );

  /// Synthetic latency added before every operation completes.
  Duration latency;

  /// Number of upcoming `push` calls that should return
  /// `SyncPushResult.failure`. Decremented to zero on use.
  int failNextPushes = 0;

  /// Number of upcoming `pull` calls that should return
  /// `SyncPullResult.failure`. Decremented to zero on use.
  int failNextPulls = 0;

  /// Optional override for the default push behavior.
  Future<SyncPushResult> Function(SyncBatch batch)? pushBehavior;

  /// Optional override for the default pull behavior.
  Future<SyncPullResult> Function(SyncPullRequest request)? pullBehavior;

  @override
  final SyncAdapterCapabilities capabilities;

  /// All records the adapter has ever accepted via `push`, keyed by
  /// `(collection, id)`.
  final Map<String, SyncRecord> stored = <String, SyncRecord>{};

  /// Subscription emitters, keyed by collection.
  final Map<String, StreamController<SyncEvent>> _subscribers =
      <String, StreamController<SyncEvent>>{};

  @override
  Future<void> initialize() async {}

  @override
  Future<SyncPushResult> push(SyncBatch batch) async {
    if (latency != Duration.zero) {
      await Future<void>.delayed(latency);
    }
    if (failNextPushes > 0) {
      failNextPushes -= 1;
      return const SyncPushResult.failure(reason: 'injected failure');
    }
    if (pushBehavior != null) {
      return pushBehavior!(batch);
    }
    for (final SyncRecord r in batch.entries) {
      stored['${r.collection}/${r.id}'] = r;
      final StreamController<SyncEvent>? c = _subscribers[r.collection];
      if (c != null && !c.isClosed) {
        c.add(
          SyncEventRecordReceived(at: DateTime.now().toUtc(), record: r),
        );
      }
    }
    return SyncPushResult.success(pushedCount: batch.size);
  }

  @override
  Future<SyncPullResult> pull(SyncPullRequest request) async {
    if (latency != Duration.zero) {
      await Future<void>.delayed(latency);
    }
    if (failNextPulls > 0) {
      failNextPulls -= 1;
      return const SyncPullResult.failure(reason: 'injected failure');
    }
    if (pullBehavior != null) {
      return pullBehavior!(request);
    }
    final List<SyncRecord> matching = stored.values
        .where((SyncRecord r) =>
            r.collection == request.collection &&
            (request.since == null ||
                r.hlc.compareTo(request.since!) > 0))
        .toList();
    matching.sort(
      (SyncRecord a, SyncRecord b) => a.hlc.compareTo(b.hlc),
    );
    final List<SyncRecord> page = matching.take(request.pageSize).toList();
    return SyncPullResult.success(
      records: page,
      hasMore: matching.length > request.pageSize,
      highWaterHlc: page.isEmpty ? null : page.last.hlc,
    );
  }

  @override
  Stream<SyncEvent> subscribe(SyncSubscription subscription) {
    final StreamController<SyncEvent> controller =
        _subscribers.putIfAbsent(
      subscription.collection,
      () => StreamController<SyncEvent>.broadcast(),
    );
    return controller.stream;
  }

  /// Test helper: clears every stored record and forgets every
  /// configured behavior.
  void reset() {
    stored.clear();
    pushBehavior = null;
    pullBehavior = null;
    failNextPushes = 0;
    failNextPulls = 0;
  }

  @override
  Future<void> dispose() async {
    for (final StreamController<SyncEvent> c in _subscribers.values) {
      await c.close();
    }
    _subscribers.clear();
  }
}
