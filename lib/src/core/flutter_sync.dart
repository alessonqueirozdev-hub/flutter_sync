// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import '../adapters/sync_adapter.dart';
import '../audit/audit_trail.dart';
import '../bandwidth/bandwidth_monitor.dart';
import '../conflict/conflict_resolver.dart';
import '../conflict/lww_resolver.dart';
import '../encryption/encryption_config.dart';
import '../encryption/key_store.dart';
import '../encryption/record_encryptor.dart';
import '../encryption/secure_storage_key_store.dart';
import '../logging/console_logger.dart';
import '../logging/sync_logger.dart';
import '../migration/migration_runner.dart';
import '../migration/schema_migration.dart';
import '../models/sync_debug_info.dart';
import '../models/sync_filter.dart';
import '../models/sync_status.dart';
import '../outbox/outbox_processor.dart';
import '../outbox/outbox_queue.dart';
import '../outbox/retry_strategy.dart';
import '../scheduler/connectivity_observer.dart';
import '../scheduler/sync_scheduler.dart';
import '../store/sync_store.dart';
import 'hlc/hlc_clock.dart';
import 'hlc/hlc_node.dart';
import 'sync_engine.dart';
import 'sync_repository.dart';

/// Main entry point of the FlutterSync package.
///
/// `FlutterSync.configure` builds and starts the engine; the returned
/// instance is the long-lived object the host application keeps around for
/// the duration of the session. Repositories for individual collections
/// are obtained via [repository].
///
/// ```dart
/// final flutterSync = FlutterSync.configure(
///   adapter: SupabaseSyncAdapter(client: supabase, userId: user.id),
///   store: DriftSyncStore(database: db),
///   conflictResolver: const LWWResolver(),
/// );
///
/// final todos = flutterSync.repository<Todo>(
///   'todos',
///   serializer: SyncModelSerializer(
///     fromJson: Todo.fromJson,
///     toJson: (t) => t.toJson(),
///   ),
/// );
/// ```
class FlutterSync {
  /// Internal constructor; use [configure] instead.
  FlutterSync._({
    required SyncEngine engine,
    required this.logger,
  }) : _engine = engine;

  /// Configures and starts a [FlutterSync] instance.
  ///
  /// The returned future resolves once every subsystem has been
  /// initialized; until then, repositories created against the instance
  /// queue their writes locally and replay them as soon as start completes.
  static Future<FlutterSync> configure({
    required SyncAdapter adapter,
    required SyncStore store,
    ConflictResolver? conflictResolver,
    SyncSchedulerConfig? schedulerConfig,
    EncryptionConfig? encryptionConfig,
    KeyStore? keyStore,
    List<SchemaMigration> migrations = const <SchemaMigration>[],
    SyncLogger? logger,
    HLCNode? hlcNode,
    RetryStrategy? retryStrategy,
  }) async {
    final SyncLogger effectiveLogger = logger ?? ConsoleLogger();
    final HLCNode effectiveNode = hlcNode ?? InMemoryHLCNode();
    final String nodeId = await effectiveNode.nodeId();
    final HybridLogicalClock clock = HybridLogicalClock(nodeId: nodeId);

    await store.initialize(SyncStoreConfig(
      nodeId: nodeId,
      encrypted: encryptionConfig != null,
    ),);

    if (migrations.isNotEmpty) {
      final MigrationRunner runner = MigrationRunner(
        store: store,
        logger: effectiveLogger,
      );
      await runner.run(migrations: migrations, currentVersion: 0);
    }

    final InMemoryOutboxQueue outbox = InMemoryOutboxQueue();
    final RetryStrategy effectiveRetry =
        retryStrategy ?? ExponentialBackoffRetryStrategy();
    final OutboxProcessor processor = OutboxProcessor(
      queue: outbox,
      adapter: adapter,
      retryStrategy: effectiveRetry,
    );
    final BandwidthMonitor bandwidth = BandwidthMonitor();
    final ConnectivityObserver connectivity = ConnectivityObserver();
    final SyncScheduler scheduler = SyncScheduler(
      config: schedulerConfig ?? const SyncSchedulerConfig(),
      outboxProcessor: processor,
      connectivityObserver: connectivity,
      bandwidthMonitor: bandwidth,
    );

    final RecordEncryptor? encryptor = encryptionConfig == null
        ? null
        : RecordEncryptor(
            config: encryptionConfig,
            keyStore: keyStore ?? SecureStorageKeyStore(),
          );

    final SyncEngine engine = SyncEngine(
      adapter: adapter,
      store: store,
      clock: clock,
      node: effectiveNode,
      outbox: outbox,
      outboxProcessor: processor,
      scheduler: scheduler,
      conflictResolver: conflictResolver ?? const LWWResolver(),
      bandwidthMonitor: bandwidth,
      auditTrail: InMemoryAuditTrail(),
      logger: effectiveLogger,
      encryptor: encryptor,
    );
    await engine.start();
    return FlutterSync._(engine: engine, logger: effectiveLogger);
  }

  final SyncEngine _engine;

  /// Logger configured for this instance.
  final SyncLogger logger;

  /// Returns a typed repository for [collection].
  SyncRepository<T> repository<T extends SyncModel>(
    String collection, {
    required SyncModelSerializer<T> serializer,
    ConflictResolver? conflictResolver,
    SyncFilter? partialSyncFilter,
    EncryptionConfig? collectionEncryption,
  }) =>
      SyncRepository<T>(
        collection: collection,
        engine: _engine,
        serializer: serializer,
        partialSyncFilter: partialSyncFilter,
        collectionEncryption: collectionEncryption,
        conflictResolver: conflictResolver,
      );

  /// Broadcast stream of [SyncStatus] updates.
  Stream<SyncStatus> get status => _engine.status;

  /// Triggers a sync attempt outside the scheduled cadence.
  Future<void> syncNow({String? collection}) =>
      _engine.syncNow(collection: collection);

  /// Pauses scheduled sync. Read operations are unaffected.
  Future<void> pause() async {
    _engine.pause();
  }

  /// Resumes scheduled sync.
  Future<void> resume() async {
    _engine.resume();
  }

  /// Returns a debug snapshot suitable for DevTools and diagnostics.
  Future<SyncDebugInfo> get debugInfo => _engine.debugInfo();

  /// Releases every resource owned by this instance.
  Future<void> dispose() => _engine.dispose();
}
