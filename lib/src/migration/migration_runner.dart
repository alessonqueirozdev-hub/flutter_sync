// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import '../logging/sync_logger.dart';
import '../store/sync_store.dart';
import 'schema_migration.dart';

/// Outcome of a `MigrationRunner.run` invocation.
class MigrationRunResult {
  /// Creates a migration-run result.
  const MigrationRunResult({
    required this.applied,
    required this.skipped,
    required this.startVersion,
    required this.endVersion,
  });

  /// Migrations that were actually applied during this run.
  final List<SchemaMigration> applied;

  /// Migrations that were skipped because their version was already
  /// recorded as applied.
  final List<SchemaMigration> skipped;

  /// Schema version at the start of the run.
  final int startVersion;

  /// Schema version at the end of the run.
  final int endVersion;

  @override
  String toString() => 'MigrationRunResult(applied: ${applied.length}, '
      'skipped: ${skipped.length}, $startVersion → $endVersion)';
}

/// Orchestrates ordered execution of [SchemaMigration]s against a
/// [SyncStore].
///
/// Migrations are sorted by [SchemaMigration.version]; gaps and duplicate
/// versions are surfaced as runtime errors so the runner can never quietly
/// skip a migration. The current schema version is tracked via the
/// `SyncStore`'s migration bookkeeping (e.g. the `schema_versions` table
/// in `DriftSyncStore`).
class MigrationRunner {
  /// Creates a runner bound to [store] and [logger].
  MigrationRunner({
    required this.store,
    SyncLogger? logger,
  }) : _logger = logger;

  /// Target store.
  final SyncStore store;
  final SyncLogger? _logger;

  /// Applies every supplied [migrations] in version order, skipping any
  /// whose version is at or below [currentVersion].
  Future<MigrationRunResult> run({
    required List<SchemaMigration> migrations,
    required int currentVersion,
  }) async {
    final List<SchemaMigration> sorted = List<SchemaMigration>.of(migrations)
      ..sort((SchemaMigration a, SchemaMigration b) =>
          a.version.compareTo(b.version));
    _assertNoDuplicates(sorted);

    final List<SchemaMigration> applied = <SchemaMigration>[];
    final List<SchemaMigration> skipped = <SchemaMigration>[];
    int latest = currentVersion;
    for (final SchemaMigration migration in sorted) {
      if (migration.version <= currentVersion) {
        skipped.add(migration);
        continue;
      }
      _logger?.info(
        'Applying schema migration v${migration.version}',
        tag: 'migrations',
        context: <String, Object?>{
          'description': migration.description,
        },
      );
      await store.runMigration(migration);
      applied.add(migration);
      latest = migration.version;
    }
    return MigrationRunResult(
      applied: applied,
      skipped: skipped,
      startVersion: currentVersion,
      endVersion: latest,
    );
  }

  void _assertNoDuplicates(List<SchemaMigration> sorted) {
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].version == sorted[i - 1].version) {
        throw StateError(
          'Duplicate schema migration version: ${sorted[i].version}',
        );
      }
    }
  }
}
