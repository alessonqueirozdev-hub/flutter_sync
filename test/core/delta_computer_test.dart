// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter_sync/flutter_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';
import '../helpers/test_store.dart';

void main() {
  group('DeltaComputer', () {
    late InMemorySyncStore store;
    late DeltaComputer computer;

    setUp(() async {
      store = InMemorySyncStore();
      await store.initialize(const SyncStoreConfig(nodeId: 'test-node'));
      computer = const DeltaComputer();
    });

    tearDown(() async {
      await store.dispose();
    });

    test('returns every record on a null watermark', () async {
      await store.upsert(TestFixtures.record(id: 'a', hlc: _hlc(1)));
      await store.upsert(TestFixtures.record(id: 'b', hlc: _hlc(2)));
      final List<SyncRecord> delta = await computer.compute(
        store: store,
        collection: 'todos',
      );
      expect(delta.length, 2);
      expect(delta.first.id, 'a');
      expect(delta.last.id, 'b');
    });

    test('filters records whose HLC is at or before the watermark', () async {
      await store.upsert(TestFixtures.record(id: 'a', hlc: _hlc(1)));
      await store.upsert(TestFixtures.record(id: 'b', hlc: _hlc(2)));
      await store.upsert(TestFixtures.record(id: 'c', hlc: _hlc(3)));
      final List<SyncRecord> delta = await computer.compute(
        store: store,
        collection: 'todos',
        sinceWire: _hlc(1),
      );
      expect(delta.map((SyncRecord r) => r.id), <String>['b', 'c']);
    });

    test('highWaterMark returns the latest HLC', () async {
      final List<SyncRecord> recs = <SyncRecord>[
        TestFixtures.record(id: 'a', hlc: _hlc(3)),
        TestFixtures.record(id: 'b', hlc: _hlc(1)),
        TestFixtures.record(id: 'c', hlc: _hlc(7)),
      ];
      expect(computer.highWaterMark(recs), _hlc(7));
      expect(computer.highWaterMark(const <SyncRecord>[]), isNull);
    });
  });
}

String _hlc(int counter) => HLCTimestamp(
      physicalTime: 1700000000000,
      logicalCounter: counter,
      nodeId: 'node-a',
    ).toWire();
