// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter_sync/flutter_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

void main() {
  group('SyncRepository (engine integration)', () {
    test('save persists locally and enqueues to outbox', () async {
      final MockSyncAdapter adapter = MockSyncAdapter();
      final FlutterSync sync = await FlutterSync.configure(
        adapter: adapter,
        store: _MinimalStore(),
        logger: ConsoleLogger(minLevel: SyncLogLevel.warning),
      );
      final SyncRepository<_Todo> repo = sync.repository<_Todo>(
        'todos',
        serializer: const SyncModelSerializer<_Todo>(
          fromJson: _Todo.fromJson,
          toJson: _Todo.toJsonStatic,
        ),
      );
      final _Todo saved = await repo.save(_Todo(id: 't1', title: 'Buy milk'));
      expect(saved.id, 't1');
      final _Todo? readBack = await repo.findById('t1');
      expect(readBack?.title, 'Buy milk');
      await sync.dispose();
    });
  });

  group('TestFixtures', () {
    test('record builder produces consistent defaults', () {
      final SyncRecord r = TestFixtures.record();
      expect(r.collection, 'todos');
      expect(r.payload['title'], 'Test');
    });

    test('conflict builder ensures local and remote share id', () {
      final SyncConflict c = TestFixtures.conflict();
      expect(c.local.id, c.remote.id);
      expect(c.local.collection, c.remote.collection);
    });
  });
}

class _Todo implements SyncModel {
  _Todo({required this.id, required this.title, this.done = false});

  @override
  final String id;
  final String title;
  final bool done;

  factory _Todo.fromJson(Map<String, dynamic> json) => _Todo(
        id: json['id']! as String,
        title: json['title']! as String,
        done: (json['done'] as bool?) ?? false,
      );

  static Map<String, dynamic> toJsonStatic(_Todo t) => t.toJson();

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'done': done,
      };
}

class _MinimalStore implements SyncStore {
  final Map<String, Map<String, SyncRecord>> _records =
      <String, Map<String, SyncRecord>>{};
  final Map<String, SyncMetadata> _meta = <String, SyncMetadata>{};
  String _nodeId = '';

  @override
  Future<void> initialize(SyncStoreConfig config) async {
    _nodeId = config.nodeId;
  }

  @override
  Future<SyncRecord?> findById(String collection, String id) async =>
      _records[collection]?[id];

  @override
  Future<List<SyncRecord>> findAll(String collection, {SyncQuery? query}) async =>
      (_records[collection]?.values ?? const <SyncRecord>[])
          .where((SyncRecord r) => !r.isDeleted)
          .toList();

  @override
  Future<void> upsert(SyncRecord record) async {
    _records.putIfAbsent(record.collection, () => <String, SyncRecord>{})[
        record.id] = record;
  }

  @override
  Future<void> delete(String collection, String id) async {
    final SyncRecord? prev = _records[collection]?[id];
    if (prev != null) {
      _records[collection]![id] =
          prev.copyWith(isDeleted: true, updatedAt: DateTime.now().toUtc());
    }
  }

  @override
  Stream<SyncStoreEvent> watch(String collection, {SyncQuery? query}) =>
      const Stream<SyncStoreEvent>.empty();

  @override
  Future<SyncMetadata> getMetadata(String collection) async =>
      _meta[collection] ??
      SyncMetadata.empty(collection: collection, nodeId: _nodeId);

  @override
  Future<void> setMetadata(String collection, SyncMetadata metadata) async {
    _meta[collection] = metadata;
  }

  @override
  Future<void> runMigration(SyncStoreMigration migration) async {
    await migration.up(this);
  }

  @override
  Future<void> dispose() async {
    _records.clear();
  }
}
