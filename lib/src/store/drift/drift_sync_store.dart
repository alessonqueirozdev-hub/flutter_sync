// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../models/sync_metadata.dart';
import '../../models/sync_query.dart';
import '../../models/sync_record.dart';
import '../sync_store.dart';
import 'drift_database.dart';

/// SQLite-backed [SyncStore] implementation built on top of
/// [FlutterSyncDatabase].
///
/// The store keeps a per-collection broadcast stream so that `watch`
/// listeners receive snapshots on initial subscription and incremental
/// events on every mutation. The stream is fanned-in from every public
/// mutator (`upsert`, `delete`, `setMetadata`) so that callers do not need
/// to opt in.
class DriftSyncStore implements SyncStore {
  /// Creates a store wrapped around [database].
  DriftSyncStore({required FlutterSyncDatabase database}) : _database = database;

  final FlutterSyncDatabase _database;
  final Map<String, StreamController<SyncStoreEvent>> _watchers =
      <String, StreamController<SyncStoreEvent>>{};
  String _nodeId = '';
  bool _disposed = false;

  @override
  Future<void> initialize(SyncStoreConfig config) async {
    if (_disposed) {
      throw StateError('DriftSyncStore has been disposed.');
    }
    _nodeId = config.nodeId;
    await _database.initialize();
  }

  @override
  Future<SyncRecord?> findById(String collection, String id) async {
    final List<Map<String, Object?>> rows = await _database.executor
        .runSelect(
          'SELECT * FROM sync_records WHERE collection = ? AND id = ? LIMIT 1',
          <Object?>[collection, id],
        );
    if (rows.isEmpty) {
      return null;
    }
    return _rowToRecord(rows.single);
  }

  @override
  Future<List<SyncRecord>> findAll(
    String collection, {
    SyncQuery? query,
  }) async {
    final StringBuffer sql =
        StringBuffer('SELECT * FROM sync_records WHERE collection = ?');
    final List<Object?> args = <Object?>[collection];
    if (query == null || !query.includeDeleted) {
      sql.write(' AND is_deleted = 0');
    }
    if (query != null) {
      for (final SyncQueryCondition c in query.conditions) {
        final _ConditionFragment fragment = _conditionToSql(c);
        sql.write(' AND ');
        sql.write(fragment.sql);
        args.addAll(fragment.args);
      }
      if (query.sorts.isNotEmpty) {
        sql.write(' ORDER BY ');
        sql.write(
          query.sorts
              .map((SyncQuerySort s) =>
                  '${_jsonExtract(s.field)} ${s.direction == SyncQuerySortDirection.descending ? "DESC" : "ASC"}',)
              .join(', '),
        );
      }
      if (query.limitCount != null) {
        sql.write(' LIMIT ?');
        args.add(query.limitCount);
      }
      if (query.offsetCount != null) {
        sql.write(' OFFSET ?');
        args.add(query.offsetCount);
      }
    }
    final List<Map<String, Object?>> rows =
        await _database.executor.runSelect(sql.toString(), args);
    return rows.map(_rowToRecord).toList(growable: false);
  }

  @override
  Future<void> upsert(SyncRecord record) async {
    await _database.executor.runInsert(
      '''
      INSERT INTO sync_records
        (id, collection, payload_json, hlc, created_at_ms, updated_at_ms, is_deleted)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(collection, id) DO UPDATE SET
        payload_json = excluded.payload_json,
        hlc          = excluded.hlc,
        updated_at_ms = excluded.updated_at_ms,
        is_deleted   = excluded.is_deleted
      ''',
      <Object?>[
        record.id,
        record.collection,
        jsonEncode(record.payload),
        record.hlc,
        record.createdAt.toUtc().millisecondsSinceEpoch,
        record.updatedAt.toUtc().millisecondsSinceEpoch,
        record.isDeleted ? 1 : 0,
      ],
    );
    final SyncStoreEvent event = SyncStoreEventUpdated(record);
    _emit(record.collection, event);
  }

  @override
  Future<void> delete(String collection, String id) async {
    await _database.executor.runUpdate(
      '''
      UPDATE sync_records
         SET is_deleted = 1,
             updated_at_ms = ?
       WHERE collection = ?
         AND id = ?
      ''',
      <Object?>[
        DateTime.now().toUtc().millisecondsSinceEpoch,
        collection,
        id,
      ],
    );
    _emit(collection, SyncStoreEventDeleted(collection: collection, id: id));
  }

  @override
  Stream<SyncStoreEvent> watch(String collection, {SyncQuery? query}) {
    final StreamController<SyncStoreEvent> controller =
        _watchers.putIfAbsent(
      collection,
      () => StreamController<SyncStoreEvent>.broadcast(
        onCancel: () => _maybeCloseWatcher(collection),
      ),
    );
    final Stream<SyncStoreEvent> upstream = controller.stream.where(
      (SyncStoreEvent event) =>
          query == null || _matchesQuery(event, query),
    );
    final StreamController<SyncStoreEvent> downstream =
        StreamController<SyncStoreEvent>.broadcast();
    late StreamSubscription<SyncStoreEvent> sub;
    downstream.onListen = () async {
      final List<SyncRecord> snapshot = await findAll(collection, query: query);
      downstream.add(SyncStoreEventSnapshot(
        collection: collection,
        records: snapshot,
      ),);
      sub = upstream.listen(
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
    final List<Map<String, Object?>> rows = await _database.executor.runSelect(
      'SELECT * FROM sync_metadata WHERE collection = ? LIMIT 1',
      <Object?>[collection],
    );
    if (rows.isEmpty) {
      return SyncMetadata.empty(collection: collection, nodeId: _nodeId);
    }
    final Map<String, Object?> row = rows.single;
    return SyncMetadata(
      collection: row['collection']! as String,
      nodeId: row['node_id']! as String,
      lastSyncedAt: row['last_synced_at'] as String?,
      recordCount: (row['record_count'] as int?) ?? 0,
      pendingCount: (row['pending_count'] as int?) ?? 0,
      lastSyncAttemptAt: switch (row['last_sync_attempt_at_ms']) {
        final int ms => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        _ => null,
      },
      lastSyncSuccessAt: switch (row['last_sync_success_at_ms']) {
        final int ms => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        _ => null,
      },
      failureCount: (row['failure_count'] as int?) ?? 0,
    );
  }

  @override
  Future<void> setMetadata(String collection, SyncMetadata metadata) async {
    await _database.executor.runInsert(
      '''
      INSERT INTO sync_metadata
        (collection, node_id, last_synced_at, record_count, pending_count,
         last_sync_attempt_at_ms, last_sync_success_at_ms, failure_count)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(collection) DO UPDATE SET
        node_id                 = excluded.node_id,
        last_synced_at          = excluded.last_synced_at,
        record_count            = excluded.record_count,
        pending_count           = excluded.pending_count,
        last_sync_attempt_at_ms = excluded.last_sync_attempt_at_ms,
        last_sync_success_at_ms = excluded.last_sync_success_at_ms,
        failure_count           = excluded.failure_count
      ''',
      <Object?>[
        metadata.collection,
        metadata.nodeId,
        metadata.lastSyncedAt,
        metadata.recordCount,
        metadata.pendingCount,
        metadata.lastSyncAttemptAt?.toUtc().millisecondsSinceEpoch,
        metadata.lastSyncSuccessAt?.toUtc().millisecondsSinceEpoch,
        metadata.failureCount,
      ],
    );
  }

  @override
  Future<void> runMigration(SyncStoreMigration migration) async {
    await _database.runInTransaction((QueryExecutor tx) async {
      await migration.up(this);
      await tx.runInsert(
        'INSERT OR IGNORE INTO schema_versions (version, applied_at) VALUES (?, ?)',
        <Object?>[migration.version, DateTime.now().toUtc().millisecondsSinceEpoch],
      );
    });
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
    await _database.close();
  }

  void _emit(String collection, SyncStoreEvent event) {
    final StreamController<SyncStoreEvent>? controller = _watchers[collection];
    if (controller != null && !controller.isClosed) {
      controller.add(event);
    }
  }

  Future<void> _maybeCloseWatcher(String collection) async {
    final StreamController<SyncStoreEvent>? controller = _watchers[collection];
    if (controller != null && !controller.hasListener) {
      _watchers.remove(collection);
      await controller.close();
    }
  }

  SyncRecord _rowToRecord(Map<String, Object?> row) {
    final Object? rawPayload = jsonDecode(row['payload_json']! as String);
    final Map<String, Object?> payload = rawPayload is Map
        ? Map<String, Object?>.from(rawPayload as Map<Object?, Object?>)
        : const <String, Object?>{};
    return SyncRecord(
      id: row['id']! as String,
      collection: row['collection']! as String,
      payload: payload,
      hlc: row['hlc']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at_ms']! as int,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at_ms']! as int,
        isUtc: true,
      ),
      isDeleted: (row['is_deleted']! as int) == 1,
    );
  }

  _ConditionFragment _conditionToSql(SyncQueryCondition c) {
    final String column = _jsonExtract(c.field);
    switch (c.operator) {
      case SyncQueryOperator.equals:
        return _ConditionFragment('$column = ?', <Object?>[c.value]);
      case SyncQueryOperator.notEquals:
        return _ConditionFragment('$column != ?', <Object?>[c.value]);
      case SyncQueryOperator.lessThan:
        return _ConditionFragment('$column < ?', <Object?>[c.value]);
      case SyncQueryOperator.lessThanOrEqual:
        return _ConditionFragment('$column <= ?', <Object?>[c.value]);
      case SyncQueryOperator.greaterThan:
        return _ConditionFragment('$column > ?', <Object?>[c.value]);
      case SyncQueryOperator.greaterThanOrEqual:
        return _ConditionFragment('$column >= ?', <Object?>[c.value]);
      case SyncQueryOperator.inList:
        final List<Object?> list = c.value! as List<Object?>;
        final String placeholders =
            List<String>.filled(list.length, '?').join(', ');
        return _ConditionFragment('$column IN ($placeholders)', list);
      case SyncQueryOperator.notInList:
        final List<Object?> list = c.value! as List<Object?>;
        final String placeholders =
            List<String>.filled(list.length, '?').join(', ');
        return _ConditionFragment('$column NOT IN ($placeholders)', list);
      case SyncQueryOperator.contains:
        return _ConditionFragment(
          'lower($column) LIKE ?',
          <Object?>['%${(c.value! as String).toLowerCase()}%'],
        );
      case SyncQueryOperator.startsWith:
        return _ConditionFragment(
          'lower($column) LIKE ?',
          <Object?>['${(c.value! as String).toLowerCase()}%'],
        );
      case SyncQueryOperator.endsWith:
        return _ConditionFragment(
          'lower($column) LIKE ?',
          <Object?>['%${(c.value! as String).toLowerCase()}'],
        );
      case SyncQueryOperator.isNull:
        return _ConditionFragment('$column IS NULL', const <Object?>[]);
      case SyncQueryOperator.isNotNull:
        return _ConditionFragment('$column IS NOT NULL', const <Object?>[]);
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
      final Object? value = record.payload[c.field];
      if (!_evalCondition(value, c)) {
        return false;
      }
    }
    return true;
  }

  bool _evalCondition(Object? value, SyncQueryCondition c) {
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
        final int cmp = value.compareTo(c.value);
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

  String _jsonExtract(String field) =>
      "json_extract(payload_json, '\$.$field')";
}

class _ConditionFragment {
  const _ConditionFragment(this.sql, this.args);
  final String sql;
  final List<Object?> args;
}
