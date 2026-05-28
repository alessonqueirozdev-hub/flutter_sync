// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import '../store/sync_store.dart';

/// Concrete, functional [SyncStoreMigration] that delegates the upgrade
/// and downgrade logic to user-supplied callbacks.
///
/// `SyncStoreMigration` is the minimal contract defined alongside
/// `SyncStore` so that the store interface is self-contained;
/// `SchemaMigration` is the richer construct hosts actually instantiate.
///
/// ```dart
/// final migration = SchemaMigration(
///   version: 2,
///   up: (store) async {
///     // Add a new computed column, backfill data, etc.
///   },
///   down: (store) async {
///     // Reverse the change.
///   },
/// );
/// ```
class SchemaMigration implements SyncStoreMigration {
  /// Creates a migration bound to [version], [up], and optional [down].
  const SchemaMigration({
    required this.version,
    required Future<void> Function(SyncStore store) up,
    Future<void> Function(SyncStore store)? down,
    this.description,
  })  : _up = up,
        _down = down;

  /// Creates a one-shot upgrade-only migration.
  factory SchemaMigration.upgradeOnly({
    required int version,
    required Future<void> Function(SyncStore store) up,
    String? description,
  }) =>
      SchemaMigration(
        version: version,
        up: up,
        description: description,
      );

  @override
  final int version;

  /// Optional human-readable description.
  final String? description;

  final Future<void> Function(SyncStore store) _up;
  final Future<void> Function(SyncStore store)? _down;

  @override
  Future<void> up(SyncStore store) => _up(store);

  @override
  Future<void> down(SyncStore store) async {
    if (_down == null) {
      throw UnsupportedError(
        'Migration version $version does not support rollback.',
      );
    }
    await _down!(store);
  }

  @override
  String toString() =>
      'SchemaMigration(v$version${description == null ? '' : ', $description'})';
}
