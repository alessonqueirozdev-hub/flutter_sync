// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter_sync/flutter_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

void main() {
  group('FieldLevelResolver', () {
    test('applies per-field strategy with merge', () async {
      final FieldLevelResolver resolver = FieldLevelResolver(
        strategies: <String, FieldStrategyConfig>{
          'title': const FieldStrategyConfig(strategy: FieldStrategy.serverWins),
          'tags': FieldStrategyConfig(
            strategy: FieldStrategy.merge,
            merger: (Object? local, Object? remote) {
              final Set<Object?> merged = <Object?>{
                if (local is List<Object?>) ...local,
                if (remote is List<Object?>) ...remote,
              };
              return merged.toList();
            },
          ),
        },
      );
      final SyncRecord local = TestFixtures.record(
        payload: const <String, Object?>{
          'title': 'Local',
          'tags': <Object?>['x'],
        },
      );
      final SyncRecord remote = local.copyWith(
        payload: const <String, Object?>{
          'title': 'Remote',
          'tags': <Object?>['y'],
        },
        hlc: const HLCTimestamp(
          physicalTime: 1700000000000,
          logicalCounter: 30,
          nodeId: 'node-b',
        ).toWire(),
      );
      final SyncRecord winner = await resolver.resolve(SyncConflict(
        local: local,
        remote: remote,
        detectedAt: DateTime.utc(2026),
      ));
      expect(winner.payload['title'], 'Remote');
      expect(
        (winner.payload['tags']! as List<Object?>).toSet(),
        <Object?>{'x', 'y'},
      );
    });

    test('uses default strategy for unconfigured fields', () async {
      const FieldLevelResolver resolver = FieldLevelResolver(
        strategies: <String, FieldStrategyConfig>{},
      );
      expect(resolver.strategy, ConflictResolutionStrategy.fieldLevel);
      expect(resolver.name, 'field-level');
    });

    test('FieldStrategyConfig with merge requires a merger', () {
      expect(
        () => const FieldStrategyConfig(strategy: FieldStrategy.merge),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
