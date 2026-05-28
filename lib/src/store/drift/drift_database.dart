// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

/// SQL schema strings used by [FlutterSyncDatabase] to bootstrap the local
/// store on first open. They are also re-used by the migration runner so
/// integration tests can stand up a clean schema in-process.
@visibleForTesting
const Map<String, String> flutterSyncDriftSchema = <String, String>{
  'sync_records': '''
    CREATE TABLE IF NOT EXISTS sync_records (
      id              TEXT    NOT NULL,
      collection      TEXT    NOT NULL,
      payload_json    TEXT    NOT NULL,
      hlc             TEXT    NOT NULL,
      created_at_ms   INTEGER NOT NULL,
      updated_at_ms   INTEGER NOT NULL,
      is_deleted      INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (collection, id)
    )
  ''',
  'sync_records_hlc_idx': '''
    CREATE INDEX IF NOT EXISTS sync_records_hlc_idx
      ON sync_records (collection, hlc)
  ''',
  'sync_metadata': '''
    CREATE TABLE IF NOT EXISTS sync_metadata (
      collection              TEXT PRIMARY KEY NOT NULL,
      node_id                 TEXT NOT NULL,
      last_synced_at          TEXT,
      record_count            INTEGER NOT NULL DEFAULT 0,
      pending_count           INTEGER NOT NULL DEFAULT 0,
      last_sync_attempt_at_ms INTEGER,
      last_sync_success_at_ms INTEGER,
      failure_count           INTEGER NOT NULL DEFAULT 0
    )
  ''',
  'outbox_entries': '''
    CREATE TABLE IF NOT EXISTS outbox_entries (
      id                  TEXT PRIMARY KEY NOT NULL,
      record_collection   TEXT NOT NULL,
      record_id           TEXT NOT NULL,
      record_json         TEXT NOT NULL,
      operation           TEXT NOT NULL,
      idempotency_key     TEXT NOT NULL,
      status              TEXT NOT NULL,
      attempt_count       INTEGER NOT NULL DEFAULT 0,
      created_at_ms       INTEGER NOT NULL,
      last_attempt_at_ms  INTEGER,
      next_retry_at_ms    INTEGER,
      failure_reason      TEXT
    )
  ''',
  'outbox_entries_status_idx': '''
    CREATE INDEX IF NOT EXISTS outbox_entries_status_idx
      ON outbox_entries (status, next_retry_at_ms)
  ''',
  'audit_entries': '''
    CREATE TABLE IF NOT EXISTS audit_entries (
      id              TEXT PRIMARY KEY NOT NULL,
      occurred_at_ms  INTEGER NOT NULL,
      collection      TEXT NOT NULL,
      record_id       TEXT NOT NULL,
      operation       TEXT NOT NULL,
      actor_node_id   TEXT NOT NULL,
      detail_json     TEXT
    )
  ''',
  'schema_versions': '''
    CREATE TABLE IF NOT EXISTS schema_versions (
      version    INTEGER PRIMARY KEY NOT NULL,
      applied_at INTEGER NOT NULL
    )
  ''',
};

/// SQLite-backed database that hosts FlutterSync's local state.
///
/// The database wraps a Drift [QueryExecutor] and exposes a small, low-level
/// API surface: schema bootstrap and typed CRUD helpers. The higher-level
/// `SyncStore` contract is implemented in `drift_sync_store.dart` on top of
/// this class.
///
/// FlutterSync intentionally uses Drift in its no-codegen mode: the schema
/// is declared in [flutterSyncDriftSchema] as raw SQL and queries are
/// expressed with `customSelect` / `customStatement`. This keeps the
/// `drift_database.g.dart` companion small and avoids requiring consumers
/// to run `build_runner` after every clone — see the notes in
/// `drift_database.g.dart`.
class FlutterSyncDatabase {
  /// Creates a database wrapper around [executor].
  FlutterSyncDatabase(QueryExecutor executor) : _executor = executor;

  final QueryExecutor _executor;
  bool _initialized = false;

  /// The Drift schema version of this database. Bumped when a structural
  /// change is introduced; the change itself is performed by a registered
  /// `SchemaMigration`.
  static const int schemaVersion = 1;

  /// Underlying Drift executor — exposed for `drift_sync_store.dart` and
  /// for tests that need to issue ad-hoc statements.
  QueryExecutor get executor => _executor;

  /// Opens the underlying database, creates the schema if needed, and
  /// records the bootstrap version.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await _executor.ensureOpen(const _SchemaOnlyOpener(schemaVersion));
    await runInTransaction((QueryExecutor tx) async {
      for (final String sql in flutterSyncDriftSchema.values) {
        await tx.runCustom(sql);
      }
      await tx.runInsert(
        'INSERT OR IGNORE INTO schema_versions (version, applied_at) VALUES (?, ?)',
        <Object?>[schemaVersion, DateTime.now().toUtc().millisecondsSinceEpoch],
      );
    });
    _initialized = true;
  }

  /// Runs [action] inside a single transaction.
  ///
  /// The transaction is committed when [action] returns normally and rolled
  /// back when [action] throws.
  Future<T> runInTransaction<T>(
    Future<T> Function(QueryExecutor tx) action,
  ) async {
    final TransactionExecutor tx = _executor.beginTransaction();
    await tx.ensureOpen(const _SchemaOnlyOpener(schemaVersion));
    try {
      final T result = await action(tx);
      await tx.send();
      return result;
    } catch (_) {
      await tx.rollback();
      rethrow;
    }
  }

  /// Closes the underlying database and releases its resources.
  Future<void> close() async {
    await _executor.close();
    _initialized = false;
  }
}

/// Lightweight Drift [QueryExecutorUser] that only reports the current
/// schema version; FlutterSync handles its own schema bootstrap in SQL.
class _SchemaOnlyOpener implements QueryExecutorUser {
  const _SchemaOnlyOpener(this.schemaVersion);

  @override
  final int schemaVersion;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
