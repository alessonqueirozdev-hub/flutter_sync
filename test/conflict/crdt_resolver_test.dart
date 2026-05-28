// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter_sync/flutter_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

void main() {
  group('CRDTResolver', () {
    test('merges registered fields via supplied merger', () async {
      final ConflictResolver resolver = CRDTResolver(
        mergers: <String, CRDTFieldMerger>{
          'tags': (Object? local, Object? remote) {
            final Set<Object?> merged = <Object?>{
              if (local is List<Object?>) ...local,
              if (remote is List<Object?>) ...remote,
            };
            return merged.toList();
          },
        },
      );
      final SyncRecord local = TestFixtures.record(
        payload: const <String, Object?>{'tags': <Object?>['a', 'b']},
      );
      final SyncRecord remote = local.copyWith(
        payload: const <String, Object?>{'tags': <Object?>['b', 'c']},
        hlc: const HLCTimestamp(
          physicalTime: 1700000000000,
          logicalCounter: 30,
          nodeId: 'node-a',
        ).toWire(),
      );
      final SyncRecord winner = await resolver.resolve(SyncConflict(
        local: local,
        remote: remote,
        detectedAt: DateTime.utc(2026),
      ));
      final List<Object?> tags = winner.payload['tags']! as List<Object?>;
      expect(tags.length, 3);
      expect(tags.toSet(), <Object?>{'a', 'b', 'c'});
    });

    test('falls back to LWW for unregistered fields', () async {
      final ConflictResolver resolver = CRDTResolver(
        mergers: <String, CRDTFieldMerger>{},
      );
      final SyncRecord local = TestFixtures.record(
        payload: const <String, Object?>{'title': 'Local'},
      );
      final SyncRecord remote = local.copyWith(
        payload: const <String, Object?>{'title': 'Remote'},
        hlc: const HLCTimestamp(
          physicalTime: 1700000000000,
          logicalCounter: 30,
          nodeId: 'node-a',
        ).toWire(),
      );
      final SyncRecord winner = await resolver.resolve(SyncConflict(
        local: local,
        remote: remote,
        detectedAt: DateTime.utc(2026),
      ));
      expect(winner.payload['title'], 'Remote');
    });

    test('reports CRDT strategy and name', () {
      const ConflictResolver resolver = CRDTResolver(mergers: <String, CRDTFieldMerger>{});
      expect(resolver.strategy, ConflictResolutionStrategy.crdt);
      expect(resolver.name, 'crdt');
    });
  });
}
