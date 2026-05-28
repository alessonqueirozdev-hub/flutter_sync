// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../adapters/sync_adapter.dart';
import '../audit/audit_entry.dart';
import '../audit/audit_trail.dart';
import '../bandwidth/bandwidth_monitor.dart';
import '../conflict/conflict_resolver.dart';
import '../encryption/encryption_config.dart';
import '../encryption/record_encryptor.dart';
import '../logging/sync_logger.dart';
import '../models/network_state.dart';
import '../models/sync_debug_info.dart';
import '../models/sync_event.dart';
import '../models/sync_metadata.dart';
import '../models/sync_pull_request.dart';
import '../models/sync_pull_result.dart';
import '../models/sync_record.dart';
import '../models/sync_status.dart';
import '../outbox/outbox_entry.dart';
import '../outbox/outbox_processor.dart';
import '../outbox/outbox_queue.dart';
import '../outbox/retry_strategy.dart';
import '../scheduler/sync_scheduler.dart';
import '../store/sync_store.dart';
import 'delta/delta_merger.dart';
import 'hlc/hlc_clock.dart';
import 'hlc/hlc_node.dart';
import 'hlc/hlc_timestamp.dart';
import 'optimistic/optimistic_update_manager.dart';

/// Central orchestrator binding together every FlutterSync subsystem.
///
/// The engine owns the lifetime of:
///
/// - The HLC clock and its [HLCNode] persistence.
/// - The [SyncStore] and the [OutboxQueue].
/// - The [SyncAdapter] (which it never modifies, just calls).
/// - The [OutboxProcessor], the [SyncScheduler], the [DeltaMerger].
/// - The [AuditTrail], the [SyncLogger], the [RecordEncryptor] (optional).
///
/// External callers normally do not instantiate [SyncEngine] directly —
/// they configure a [FlutterSync] instance, which builds the engine
/// internally and exposes a typed [SyncRepository] facade per collection.
class SyncEngine {
  /// Creates an engine wiring every collaborator.
  SyncEngine({
    required this.adapter,
    required this.store,
    required this.clock,
    required this.node,
    required this.outbox,
    required this.outboxProcessor,
    required this.scheduler,
    required this.conflictResolver,
    required this.bandwidthMonitor,
    required this.auditTrail,
    required this.logger,
    this.encryptor,
  });

  /// Backend adapter currently in use.
  final SyncAdapter adapter;

  /// Local store currently in use.
  final SyncStore store;

  /// Hybrid Logical Clock instance.
  final HybridLogicalClock clock;

  /// Persistent node backing for [clock].
  final HLCNode node;

  /// Outbox queue.
  final OutboxQueue outbox;

  /// Processor draining [outbox].
  final OutboxProcessor outboxProcessor;

  /// Scheduler orchestrating timing.
  final SyncScheduler scheduler;

  /// Active conflict resolver (may be wrapped per-collection by repositories).
  final ConflictResolver conflictResolver;

  /// Bandwidth monitor consulted by the scheduler.
  final BandwidthMonitor bandwidthMonitor;

  /// Audit trail recording state changes.
  final AuditTrail auditTrail;

  /// Logger receiving every diagnostic message.
  final SyncLogger logger;

  /// Optional encryptor wrapping protected payload fields.
  final RecordEncryptor? encryptor;

  final BehaviorSubject<SyncStatus> _statusSubject =
      BehaviorSubject<SyncStatus>.seeded(const SyncStatus.idle());
  StreamSubscription<NetworkState>? _connectivitySub;
  bool _started = false;
  bool _disposed = false;

  /// Broadcast stream of high-level engine status changes.
  Stream<SyncStatus> get status => _statusSubject.stream.distinct();

  /// Current status snapshot.
  SyncStatus get currentStatus => _statusSubject.value;

  /// Starts the engine: bootstraps the clock, initializes the store, opens
  /// the adapter, and starts the scheduler.
  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    logger.info('Starting SyncEngine', tag: 'engine');
    final String nodeId = await node.nodeId();
    logger.debug('Loaded node id $nodeId', tag: 'engine');
    final HLCTimestamp? snapshot = await node.loadState();
    if (snapshot != null && snapshot.nodeId == nodeId) {
      clock.restore(snapshot);
    }
    await adapter.initialize();
    await scheduler.start();
    _statusSubject.add(const SyncStatus.idle());
    _connectivitySub = scheduler.connectivityObserver.changes.listen(
      (NetworkState state) {
        if (state is NetworkStateNone) {
          _statusSubject.add(const SyncStatus.offline());
        } else if (currentStatus is SyncStatusOffline) {
          _statusSubject.add(const SyncStatus.idle());
        }
      },
    );
  }

  /// Triggers a single full sync cycle: push every pending outbox entry,
  /// then pull deltas for every collection that has metadata.
  Future<void> syncNow({String? collection}) async {
    if (_disposed) {
      throw StateError('SyncEngine has been disposed.');
    }
    _statusSubject.add(
      const SyncStatus.syncing(total: 0, completed: 0),
    );
    try {
      final OutboxProcessResult pushResult =
          await outboxProcessor.processOnce();
      logger.info(
        'Push pass: $pushResult',
        tag: 'engine',
      );
      if (collection != null) {
        await _pullCollection(collection);
      } else {
        // Pull every collection that has metadata. The set is recorded on
        // the first read/write per collection.
        for (final String coll in await _knownCollections()) {
          await _pullCollection(coll);
        }
      }
      _statusSubject.add(SyncStatus.synced(DateTime.now().toUtc()));
    } catch (e, st) {
      logger.error(
        'syncNow failed',
        tag: 'engine',
        error: e,
        stackTrace: st,
      );
      _statusSubject.add(SyncStatus.error(e.toString(), cause: e));
    }
  }

  /// Returns a debug snapshot for tooling.
  Future<SyncDebugInfo> debugInfo() async {
    final Map<String, SyncCollectionStats> stats =
        <String, SyncCollectionStats>{};
    int outboxPending = 0;
    int outboxFailed = 0;
    final List<OutboxEntry> all = await outbox.allEntries();
    for (final OutboxEntry e in all) {
      if (e.status == OutboxStatus.pending) {
        outboxPending += 1;
      } else if (e.status == OutboxStatus.failed) {
        outboxFailed += 1;
      }
    }
    DateTime? lastSuccess;
    DateTime? lastAttempt;
    for (final String coll in await _knownCollections()) {
      final SyncMetadata meta = await store.getMetadata(coll);
      stats[coll] = SyncCollectionStats(
        collection: coll,
        records: meta.recordCount,
        pending: meta.pendingCount,
        failed: 0,
        lastSyncedAt: meta.lastSyncedAt,
      );
      if (meta.lastSyncSuccessAt != null &&
          (lastSuccess == null || meta.lastSyncSuccessAt!.isAfter(lastSuccess))) {
        lastSuccess = meta.lastSyncSuccessAt;
      }
      if (meta.lastSyncAttemptAt != null &&
          (lastAttempt == null || meta.lastSyncAttemptAt!.isAfter(lastAttempt))) {
        lastAttempt = meta.lastSyncAttemptAt;
      }
    }
    return SyncDebugInfo(
      nodeId: await node.nodeId(),
      currentHlc: clock.current.toWire(),
      networkState: scheduler.connectivityObserver.current,
      isPaused: scheduler.isPaused,
      collections: stats,
      outboxPendingTotal: outboxPending,
      outboxFailedTotal: outboxFailed,
      lastSyncSuccessAt: lastSuccess,
      lastSyncAttemptAt: lastAttempt,
    );
  }

  Future<Set<String>> _knownCollections() async {
    // The store does not enumerate metadata, so we infer collections from
    // the outbox. Repositories register metadata on first use; until then,
    // an "unknown" collection has nothing to pull.
    final Set<String> result = <String>{};
    final List<OutboxEntry> entries = await outbox.allEntries();
    for (final OutboxEntry e in entries) {
      result.add(e.collection);
    }
    return result;
  }

  Future<void> _pullCollection(String collection) async {
    final SyncMetadata metadata = await store.getMetadata(collection);
    final SyncPullRequest request = SyncPullRequest(
      collection: collection,
      since: metadata.lastSyncedAt,
      pageSize: bandwidthMonitor.batchSizeFor(
        scheduler.connectivityObserver.current,
      ),
    );
    final SyncPullResult result = await adapter.pull(request);
    switch (result) {
      case SyncPullResultSuccess(
          :final List<SyncRecord> records,
          :final String? highWaterHlc,
        ):
        final DeltaMerger merger =
            DeltaMerger(resolver: conflictResolver, clock: clock);
        final List<SyncRecord> applied = records;
        final List<SyncRecord> decrypted = encryptor == null
            ? applied
            : await Future.wait<SyncRecord>(
                applied.map<Future<SyncRecord>>(encryptor!.decrypt),
              );
        final report = await merger.merge(store: store, remoteRecords: decrypted);
        logger.info(
          'Pull pass for $collection: $report',
          tag: 'engine',
        );
        await store.setMetadata(
          collection,
          metadata.copyWith(
            lastSyncedAt: highWaterHlc ?? metadata.lastSyncedAt,
            lastSyncAttemptAt: DateTime.now().toUtc(),
            lastSyncSuccessAt: DateTime.now().toUtc(),
            failureCount: 0,
          ),
        );
        await auditTrail.record(
          AuditEntry(
            occurredAt: DateTime.now().toUtc(),
            collection: collection,
            recordId: highWaterHlc ?? '-',
            operation: AuditOperation.pulled,
            actorNodeId: clock.nodeId,
            detail: <String, Object?>{
              'received': report.total,
              'applied': report.applied,
              'resolved': report.resolved,
            },
          ),
        );
      case SyncPullResultEmpty():
        await store.setMetadata(
          collection,
          metadata.copyWith(
            lastSyncAttemptAt: DateTime.now().toUtc(),
            lastSyncSuccessAt: DateTime.now().toUtc(),
            failureCount: 0,
          ),
        );
      case SyncPullResultRetry(:final String reason):
        logger.warning(
          'Pull retry for $collection: $reason',
          tag: 'engine',
        );
      case SyncPullResultFailure(:final String reason):
        logger.error(
          'Pull failure for $collection: $reason',
          tag: 'engine',
        );
        await store.setMetadata(
          collection,
          metadata.copyWith(
            lastSyncAttemptAt: DateTime.now().toUtc(),
            failureCount: metadata.failureCount + 1,
          ),
        );
    }
  }

  /// Pauses scheduling.
  void pause() {
    scheduler.pause();
    _statusSubject.add(const SyncStatus.paused());
  }

  /// Resumes scheduling.
  void resume() {
    scheduler.resume();
    _statusSubject.add(const SyncStatus.idle());
  }

  /// Releases every owned resource.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _connectivitySub?.cancel();
    await scheduler.dispose();
    await outbox.dispose();
    await store.dispose();
    await adapter.dispose();
    await auditTrail.dispose();
    await _statusSubject.close();
  }
}
