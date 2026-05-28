// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import 'package:flutter_sync/flutter_sync.dart';

/// Pure in-memory [SyncStore] used by unit and behavioral tests.
///
/// Avoids any filesystem or platform dependency (no Drift, no Hive) so the
/// test suite stays portable and fast.
class InMemorySyncStore implements SyncStore {
  /// Creates an empty in-memory store.
  InMemorySyncStore();

  final Map<String, Map<String, SyncRecord>> _records =
      <String, Map<String, SyncRecord>>{};
  final Map<String, SyncMetadata> _metadata = <String, SyncMetadata>{};
  final Map<String, StreamController<SyncStoreEvent>> _watchers =
      <String, StreamController<SyncStoreEvent>>{};
  String _nodeId = '';

  @override
  Future<void> initialize(SyncStoreConfig config) async {
    _nodeId = config.nodeId;
  }

  @override
  Future<SyncRecord?> findById(String collection, String id) async =>
      _records[collection]?[id];

  @override
  Future<List<SyncRecord>> findAll(String collection, {SyncQuery? query}) async {
    final Iterable<SyncRecord> all =
        _records[collection]?.values ?? const <SyncRecord>[];
    if (query == null) {
      return all.where((SyncRecord r) => !r.isDeleted).toList();
    }
    Iterable<SyncRecord> filtered = all;
    if (!query.includeDeleted) {
      filtered = filtered.where((SyncRecord r) => !r.isDeleted);
    }
    for (final SyncQueryCondition c in query.conditions) {
      filtered = filtered.where((SyncRecord r) {
        final Object? value = r.payload[c.field];
        switch (c.operator) {
          case SyncQueryOperator.equals:
            return value == c.value;
          case SyncQueryOperator.notEquals:
            return value != c.value;
          default:
            return true;
        }
      });
    }
    return filtered.toList();
  }

  @override
  Future<void> upsert(SyncRecord record) async {
    final Map<String, SyncRecord> bucket =
        _records.putIfAbsent(record.collection, () => <String, SyncRecord>{});
    final bool existed = bucket.containsKey(record.id);
    bucket[record.id] = record;
    _emit(
      record.collection,
      existed
          ? SyncStoreEventUpdated(record)
          : SyncStoreEventInserted(record),
    );
  }

  @override
  Future<void> delete(String collection, String id) async {
    final Map<String, SyncRecord>? bucket = _records[collection];
    final SyncRecord? prev = bucket?[id];
    if (prev != null) {
      bucket![id] = prev.copyWith(isDeleted: true, updatedAt: DateTime.now().toUtc());
    }
    _emit(collection, SyncStoreEventDeleted(collection: collection, id: id));
  }

  @override
  Stream<SyncStoreEvent> watch(String collection, {SyncQuery? query}) {
    final StreamController<SyncStoreEvent> controller = _watchers.putIfAbsent(
      collection,
      () => StreamController<SyncStoreEvent>.broadcast(),
    );
    return controller.stream;
  }

  @override
  Future<SyncMetadata> getMetadata(String collection) async =>
      _metadata[collection] ??
      SyncMetadata.empty(collection: collection, nodeId: _nodeId);

  @override
  Future<void> setMetadata(String collection, SyncMetadata metadata) async {
    _metadata[collection] = metadata;
  }

  @override
  Future<void> runMigration(SyncStoreMigration migration) async {
    await migration.up(this);
  }

  @override
  Future<void> dispose() async {
    for (final StreamController<SyncStoreEvent> c in _watchers.values) {
      await c.close();
    }
    _watchers.clear();
    _records.clear();
    _metadata.clear();
  }

  void _emit(String collection, SyncStoreEvent event) {
    final StreamController<SyncStoreEvent>? c = _watchers[collection];
    if (c != null && !c.isClosed) {
      c.add(event);
    }
  }
}
