// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';

import '../../models/sync_metadata.dart';
import '../../models/sync_query.dart';
import '../../models/sync_record.dart';
import '../sync_store.dart';

/// Hive-backed [SyncStore] implementation.
///
/// Designed for very small data sets and prototype apps where the cost of
/// bundling SQLite is not justified. Each collection lives in its own
/// `Box<String>` (keyed by `id`, value is a JSON-encoded [SyncRecord]),
/// metadata lives in a single `Box<String>` keyed by collection name, and
/// the schema-version registry is a `Box<int>`.
class HiveSyncStore implements SyncStore {
  /// Creates a Hive-backed store.
  HiveSyncStore({HiveInterface? hive}) : _hive = hive ?? Hive;

  final HiveInterface _hive;
  late SyncStoreConfig _config;
  final Map<String, Box<String>> _collections = <String, Box<String>>{};
  late Box<String> _metadata;
  late Box<int> _schemaVersions;
  final Map<String, StreamController<SyncStoreEvent>> _watchers =
      <String, StreamController<SyncStoreEvent>>{};
  bool _initialized = false;
  bool _disposed = false;

  @override
  Future<void> initialize(SyncStoreConfig config) async {
    if (_disposed) {
      throw StateError('HiveSyncStore has been disposed.');
    }
    if (_initialized) {
      return;
    }
    _config = config;
    if (config.path != null) {
      _hive.init(config.path!);
    }
    _metadata = await _hive.openBox<String>('flutter_sync_metadata');
    _schemaVersions = await _hive.openBox<int>('flutter_sync_schema_versions');
    _initialized = true;
  }

  Future<Box<String>> _collectionBox(String collection) async {
    Box<String>? box = _collections[collection];
    if (box != null) {
      return box;
    }
    box = await _hive.openBox<String>('flutter_sync_records_$collection');
    _collections[collection] = box;
    return box;
  }

  @override
  Future<SyncRecord?> findById(String collection, String id) async {
    final Box<String> box = await _collectionBox(collection);
    final String? raw = box.get(id);
    if (raw == null) {
      return null;
    }
    return _decodeRecord(raw);
  }

  @override
  Future<List<SyncRecord>> findAll(
    String collection, {
    SyncQuery? query,
  }) async {
    final Box<String> box = await _collectionBox(collection);
    final Iterable<SyncRecord> all =
        box.values.map<SyncRecord>(_decodeRecord);
    Iterable<SyncRecord> filtered = all;
    if (query == null || !query.includeDeleted) {
      filtered = filtered.where((SyncRecord r) => !r.isDeleted);
    }
    if (query != null) {
      for (final SyncQueryCondition c in query.conditions) {
        filtered = filtered.where(
          (SyncRecord r) => _evaluateCondition(r.payload[c.field], c),
        );
      }
      if (query.sorts.isNotEmpty) {
        final List<SyncRecord> sorted = filtered.toList();
        sorted.sort((SyncRecord a, SyncRecord b) {
          for (final SyncQuerySort s in query.sorts) {
            final Object? av = a.payload[s.field];
            final Object? bv = b.payload[s.field];
            if (av is! Comparable<Object?> || bv == null) {
              continue;
            }
            final int cmp = (av as Comparable<Object?>).compareTo(bv);
            if (cmp != 0) {
              return s.direction == SyncQuerySortDirection.descending
                  ? -cmp
                  : cmp;
            }
          }
          return 0;
        });
        filtered = sorted;
      }
      final List<SyncRecord> materialized = filtered.toList();
      final int skip = query.offsetCount ?? 0;
      final int take = query.limitCount ?? materialized.length;
      if (skip < materialized.length) {
        final int end = skip + take > materialized.length
            ? materialized.length
            : skip + take;
        return materialized.sublist(skip, end);
      }
      return const <SyncRecord>[];
    }
    return filtered.toList(growable: false);
  }

  @override
  Future<void> upsert(SyncRecord record) async {
    final Box<String> box = await _collectionBox(record.collection);
    final bool existed = box.containsKey(record.id);
    await box.put(record.id, jsonEncode(record.toJson()));
    _emit(
      record.collection,
      existed
          ? SyncStoreEventUpdated(record)
          : SyncStoreEventInserted(record),
    );
  }

  @override
  Future<void> delete(String collection, String id) async {
    final Box<String> box = await _collectionBox(collection);
    final String? raw = box.get(id);
    if (raw == null) {
      return;
    }
    final SyncRecord previous = _decodeRecord(raw);
    final SyncRecord tombstone = previous.copyWith(
      isDeleted: true,
      updatedAt: DateTime.now().toUtc(),
    );
    await box.put(id, jsonEncode(tombstone.toJson()));
    _emit(collection, SyncStoreEventDeleted(collection: collection, id: id));
  }

  @override
  Stream<SyncStoreEvent> watch(String collection, {SyncQuery? query}) {
    final StreamController<SyncStoreEvent> upstream = _watchers.putIfAbsent(
      collection,
      () => StreamController<SyncStoreEvent>.broadcast(),
    );
    final StreamController<SyncStoreEvent> downstream =
        StreamController<SyncStoreEvent>.broadcast();
    late StreamSubscription<SyncStoreEvent> sub;
    downstream.onListen = () async {
      final List<SyncRecord> snapshot =
          await findAll(collection, query: query);
      downstream.add(SyncStoreEventSnapshot(
        collection: collection,
        records: snapshot,
      ));
      sub = upstream.stream
          .where((SyncStoreEvent e) =>
              query == null || _matchesQuery(e, query))
          .listen(
        downstream.add,
        onError: downstream.addError,
        cancelOnError: false,
      );
    };
    downstream.onCancel = () async {
      await sub.cancel();
      await downstream.close();
    };
    return downstream.stream;
  }

  @override
  Future<SyncMetadata> getMetadata(String collection) async {
    final String? raw = _metadata.get(collection);
    if (raw == null) {
      return SyncMetadata.empty(collection: collection, nodeId: _config.nodeId);
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return SyncMetadata.empty(collection: collection, nodeId: _config.nodeId);
    }
    return SyncMetadata.fromJson(
      Map<String, Object?>.from(decoded as Map<Object?, Object?>),
    );
  }

  @override
  Future<void> setMetadata(String collection, SyncMetadata metadata) async {
    await _metadata.put(collection, jsonEncode(metadata.toJson()));
  }

  @override
  Future<void> runMigration(SyncStoreMigration migration) async {
    await migration.up(this);
    await _schemaVersions.put('version', migration.version);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final StreamController<SyncStoreEvent> c in _watchers.values) {
      await c.close();
    }
    _watchers.clear();
    for (final Box<String> box in _collections.values) {
      await box.close();
    }
    _collections.clear();
    await _metadata.close();
    await _schemaVersions.close();
  }

  void _emit(String collection, SyncStoreEvent event) {
    final StreamController<SyncStoreEvent>? c = _watchers[collection];
    if (c != null && !c.isClosed) {
      c.add(event);
    }
  }

  bool _matchesQuery(SyncStoreEvent event, SyncQuery query) {
    final SyncRecord? record = switch (event) {
      SyncStoreEventInserted(:final SyncRecord record) => record,
      SyncStoreEventUpdated(:final SyncRecord record) => record,
      SyncStoreEventDeleted() => null,
      SyncStoreEventSnapshot() => null,
    };
    if (record == null) {
      return true;
    }
    if (!query.includeDeleted && record.isDeleted) {
      return false;
    }
    for (final SyncQueryCondition c in query.conditions) {
      if (!_evaluateCondition(record.payload[c.field], c)) {
        return false;
      }
    }
    return true;
  }

  bool _evaluateCondition(Object? value, SyncQueryCondition c) {
    switch (c.operator) {
      case SyncQueryOperator.equals:
        return value == c.value;
      case SyncQueryOperator.notEquals:
        return value != c.value;
      case SyncQueryOperator.isNull:
        return value == null;
      case SyncQueryOperator.isNotNull:
        return value != null;
      case SyncQueryOperator.inList:
        return (c.value! as List<Object?>).contains(value);
      case SyncQueryOperator.notInList:
        return !(c.value! as List<Object?>).contains(value);
      case SyncQueryOperator.contains:
        return value is String &&
            value.toLowerCase().contains((c.value! as String).toLowerCase());
      case SyncQueryOperator.startsWith:
        return value is String &&
            value.toLowerCase().startsWith((c.value! as String).toLowerCase());
      case SyncQueryOperator.endsWith:
        return value is String &&
            value.toLowerCase().endsWith((c.value! as String).toLowerCase());
      case SyncQueryOperator.lessThan:
      case SyncQueryOperator.lessThanOrEqual:
      case SyncQueryOperator.greaterThan:
      case SyncQueryOperator.greaterThanOrEqual:
        if (value is! Comparable<Object?> || c.value == null) {
          return false;
        }
        final int cmp = (value as Comparable<Object?>).compareTo(c.value);
        switch (c.operator) {
          case SyncQueryOperator.lessThan:
            return cmp < 0;
          case SyncQueryOperator.lessThanOrEqual:
            return cmp <= 0;
          case SyncQueryOperator.greaterThan:
            return cmp > 0;
          case SyncQueryOperator.greaterThanOrEqual:
            return cmp >= 0;
          // ignore: no_default_cases
          default:
            return false;
        }
    }
  }

  SyncRecord _decodeRecord(String raw) {
    final Object? decoded = jsonDecode(raw);
    final Map<String, Object?> map = decoded is Map
        ? Map<String, Object?>.from(decoded as Map<Object?, Object?>)
        : <String, Object?>{};
    return SyncRecord.fromJson(map);
  }
}
