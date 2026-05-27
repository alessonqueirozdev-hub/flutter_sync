// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

import '../models/sync_metadata.dart';
import '../models/sync_query.dart';
import '../models/sync_record.dart';

/// Contract every local-persistence implementation must satisfy.
///
/// A [SyncStore] is the durable, queryable source of truth for the device.
/// All reads served to the application come from the store; writes are
/// applied to the store first (optimistic) and only then enqueued in the
/// outbox for background transmission.
///
/// Two reference implementations ship with FlutterSync:
///
/// - `DriftSyncStore` — SQLite-backed, with full query support, transactions,
///   and migrations.
/// - `HiveSyncStore` — lightweight key/value store, suitable for very small
///   datasets and prototypes.
///
/// Custom implementations are free to back the store with any technology
/// provided they honor the contract below.
abstract interface class SyncStore {
  /// One-time setup: open files, create tables, run pending migrations.
  /// Must be called before any other method.
  Future<void> initialize(SyncStoreConfig config);

  /// Returns the record with the supplied [id] in [collection], or `null`
  /// when no such record exists. Tombstones (records with `isDeleted: true`)
  /// are returned so that callers can distinguish "not present" from
  /// "deleted".
  Future<SyncRecord?> findById(String collection, String id);

  /// Returns the records in [collection] matching the optional [query].
  ///
  /// When [query] is omitted, every live record is returned. Tombstones are
  /// excluded unless `query.includeDeleted` is `true`.
  Future<List<SyncRecord>> findAll(String collection, {SyncQuery? query});

  /// Inserts or replaces [record] in the store. Existing records with the
  /// same `(collection, id)` are overwritten unconditionally — callers are
  /// expected to have already resolved any conflict via `ConflictResolver`.
  Future<void> upsert(SyncRecord record);

  /// Marks the record `(collection, id)` as deleted by writing a tombstone.
  /// The tombstone is propagated to the backend through the outbox so that
  /// peers can observe the deletion.
  Future<void> delete(String collection, String id);

  /// Returns a broadcast stream of [SyncStoreEvent]s for [collection].
  ///
  /// When [query] is supplied, the stream emits only events whose record
  /// would be included in `findAll` with the same query. The first emission
  /// is the current snapshot; subsequent emissions are diffs.
  Stream<SyncStoreEvent> watch(String collection, {SyncQuery? query});

  /// Returns the [SyncMetadata] for [collection], or an empty snapshot when
  /// the collection has never been touched.
  Future<SyncMetadata> getMetadata(String collection);

  /// Atomically persists [metadata] for [collection].
  Future<void> setMetadata(String collection, SyncMetadata metadata);

  /// Runs the supplied [migration] within a single transaction.
  ///
  /// Implementations are expected to record the applied migration version
  /// in their internal schema-version table so that subsequent calls with
  /// the same [migration] are no-ops.
  Future<void> runMigration(SyncStoreMigration migration);

  /// Closes the store and releases its resources.
  Future<void> dispose();
}

/// Configuration value object passed to `SyncStore.initialize`.
///
/// Implementations may interpret [path] differently — `DriftSyncStore`
/// treats it as a filesystem path, `HiveSyncStore` treats it as a box name —
/// but every implementation honors [nodeId] and the [encrypted] hint.
@immutable
class SyncStoreConfig {
  /// Creates an immutable store configuration.
  const SyncStoreConfig({
    required this.nodeId,
    this.path,
    this.encrypted = false,
    this.tombstoneRetention = const Duration(days: 30),
    this.maxRecordsPerCollection,
  });

  /// Stable installation identifier (UUID v4).
  final String nodeId;

  /// Optional storage path or container name; interpreted by the
  /// implementation.
  final String? path;

  /// Hint that records should be encrypted at rest. Implementations that
  /// support encryption honor this flag; others log a warning when it is
  /// set to `true`.
  final bool encrypted;

  /// How long tombstones are retained before garbage collection.
  final Duration tombstoneRetention;

  /// Optional ceiling on the number of records per collection. When set,
  /// the store evicts the oldest tombstones first; live records are never
  /// evicted.
  final int? maxRecordsPerCollection;
}

/// Event emitted by `SyncStore.watch` to communicate record-level changes.
@immutable
sealed class SyncStoreEvent {
  /// Internal const constructor for subclasses.
  const SyncStoreEvent();

  /// Collection the event applies to.
  String get collection;
}

/// A record was inserted into the store.
final class SyncStoreEventInserted extends SyncStoreEvent {
  /// Creates an inserted event carrying the new [record].
  const SyncStoreEventInserted(this.record);

  /// The newly-inserted record.
  final SyncRecord record;

  @override
  String get collection => record.collection;

  @override
  String toString() => 'SyncStoreEvent.inserted(${record.collection}/${record.id})';
}

/// An existing record was updated in the store.
final class SyncStoreEventUpdated extends SyncStoreEvent {
  /// Creates an updated event carrying the updated [record].
  const SyncStoreEventUpdated(this.record);

  /// The updated record.
  final SyncRecord record;

  @override
  String get collection => record.collection;

  @override
  String toString() => 'SyncStoreEvent.updated(${record.collection}/${record.id})';
}

/// A record was removed from the store (tombstone applied or evicted).
final class SyncStoreEventDeleted extends SyncStoreEvent {
  /// Creates a deleted event with the [collection] and [id] of the record
  /// that was removed.
  const SyncStoreEventDeleted({required this.collection, required this.id});

  @override
  final String collection;

  /// Identifier of the deleted record.
  final String id;

  @override
  String toString() => 'SyncStoreEvent.deleted($collection/$id)';
}

/// Initial-snapshot event emitted as the first event on every `watch`.
final class SyncStoreEventSnapshot extends SyncStoreEvent {
  /// Creates an initial-snapshot event with the current matching [records].
  const SyncStoreEventSnapshot({
    required this.collection,
    required this.records,
  });

  @override
  final String collection;

  /// Records matching the watch's query at the moment the snapshot was taken.
  final List<SyncRecord> records;

  @override
  String toString() =>
      'SyncStoreEvent.snapshot($collection, records: ${records.length})';
}

/// Minimal contract a schema migration must satisfy to be runnable through
/// [SyncStore.runMigration].
///
/// The richer migration toolkit (helper base classes, fluent builders,
/// reverse-migration utilities) ships in Phase 12 under
/// `src/migration/schema_migration.dart`. The interface lives here so that
/// the [SyncStore] contract is fully defined without a cross-layer
/// dependency; the migration layer adds value-add helpers that implement
/// this interface.
abstract interface class SyncStoreMigration {
  /// Sequential, monotonically-increasing version number for this migration.
  ///
  /// Migrations are applied in strictly ascending order of [version]. A
  /// migration whose [version] is less than or equal to the store's
  /// current schema version is a no-op.
  int get version;

  /// Migrates the [store] from schema `version - 1` to [version].
  Future<void> up(SyncStore store);

  /// Reverses the migration, restoring schema `version - 1` from [version].
  ///
  /// Implementations that do not support rollback may throw
  /// `UnsupportedError` — the migration runner surfaces this through the
  /// `SyncResult` returned by the public migration API.
  Future<void> down(SyncStore store);
}
