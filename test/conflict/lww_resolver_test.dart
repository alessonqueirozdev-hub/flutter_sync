// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter_sync/flutter_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

void main() {
  group('LWWResolver', () {
    const ConflictResolver resolver = LWWResolver();

    test('reports last-write-wins strategy and name', () {
      expect(resolver.strategy, ConflictResolutionStrategy.lastWriteWins);
      expect(resolver.name, 'lww');
    });

    test('returns the remote when its HLC is strictly greater', () async {
      final SyncConflict c = TestFixtures.conflict();
      final SyncRecord winner = await resolver.resolve(c);
      expect(winner, c.remote);
    });

    test('returns the local when its HLC is strictly greater', () async {
      final SyncRecord local = TestFixtures.record(
        hlc: const HLCTimestamp(
          physicalTime: 1700000000000,
          logicalCounter: 99,
          nodeId: 'node-a',
        ).toWire(),
      );
      final SyncRecord remote = local.copyWith(
        payload: const <String, Object?>{'title': 'Older remote'},
        hlc: const HLCTimestamp(
          physicalTime: 1700000000000,
          logicalCounter: 5,
          nodeId: 'node-b',
        ).toWire(),
      );
      final SyncConflict c = SyncConflict(
        local: local,
        remote: remote,
        detectedAt: DateTime.utc(2026, 1, 1),
      );
      final SyncRecord winner = await resolver.resolve(c);
      expect(winner, local);
    });

    test('breaks HLC ties by nodeId via lexicographic order', () async {
      final SyncRecord local = TestFixtures.record(
        hlc: const HLCTimestamp(
          physicalTime: 1700000000000,
          logicalCounter: 5,
          nodeId: 'node-a',
        ).toWire(),
      );
      final SyncRecord remote = local.copyWith(
        hlc: const HLCTimestamp(
          physicalTime: 1700000000000,
          logicalCounter: 5,
          nodeId: 'node-b',
        ).toWire(),
      );
      final SyncRecord winner = await resolver.resolve(
        SyncConflict(local: local, remote: remote, detectedAt: DateTime.utc(2026)),
      );
      expect(winner, remote);
    });
  });
}
