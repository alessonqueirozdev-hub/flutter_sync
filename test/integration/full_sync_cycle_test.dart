// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter_sync/flutter_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_store.dart';

void main() {
  test('write → outbox → push → pull cycle round-trips through MockSyncAdapter',
      () async {
    final MockSyncAdapter adapter = MockSyncAdapter();
    final InMemorySyncStore store = InMemorySyncStore();
    final FlutterSync sync = await FlutterSync.configure(
      adapter: adapter,
      store: store,
      logger: ConsoleLogger(minLevel: SyncLogLevel.warning),
    );
    final SyncRepository<_Todo> repo = sync.repository<_Todo>(
      'todos',
      serializer: const SyncModelSerializer<_Todo>(
        fromJson: _Todo.fromJson,
        toJson: _Todo.toJsonStatic,
      ),
    );
    final _Todo write = _Todo(id: 't1', title: 'Wash dishes');
    await repo.save(write);
    await sync.syncNow();
    expect(adapter.stored.length, 1);
    final SyncRecord serverCopy = adapter.stored.values.single;
    expect(serverCopy.id, 't1');
    expect(serverCopy.payload['title'], 'Wash dishes');

    // Inject a remote-only record and pull it.
    adapter.stored['todos/t2'] = SyncRecord(
      id: 't2',
      collection: 'todos',
      payload: const <String, Object?>{
        'id': 't2',
        'title': 'Take out trash',
        'done': false,
      },
      hlc: const HLCTimestamp(
        physicalTime: 1700000000999,
        logicalCounter: 0,
        nodeId: 'remote',
      ).toWire(),
      createdAt: DateTime.utc(2026, 1, 1, 13),
      updatedAt: DateTime.utc(2026, 1, 1, 13),
    );
    await sync.syncNow();
    final List<_Todo> all = await repo.findAll();
    expect(all.length, 2);
    expect(all.map((_Todo t) => t.id).toSet(), <String>{'t1', 't2'});
    await sync.dispose();
  });
}

class _Todo implements SyncModel {
  _Todo({required this.id, required this.title, this.done = false});

  factory _Todo.fromJson(Map<String, dynamic> json) => _Todo(
        id: json['id']! as String,
        title: json['title']! as String,
        done: (json['done'] as bool?) ?? false,
      );

  @override
  final String id;
  final String title;
  final bool done;

  static Map<String, dynamic> toJsonStatic(_Todo t) => t.toJson();

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'done': done,
      };
}
