// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:math';

import 'package:flutter_sync/flutter_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GCounter', () {
    test('value is the sum across nodes', () {
      final GCounter c = GCounter()
          .increment('a', 3)
          .increment('b', 5)
          .increment('a', 2);
      expect(c.value, 10);
    });

    test('merge takes per-node maximum', () {
      final GCounter a = GCounter().increment('a', 3).increment('b', 2);
      final GCounter b = GCounter().increment('a', 5).increment('c', 7);
      final GCounter merged = a.merge(b);
      expect(merged.state['a'], 5);
      expect(merged.state['b'], 2);
      expect(merged.state['c'], 7);
      expect(merged.value, 14);
    });

    test('merge is commutative, associative, and idempotent', () {
      final Random rng = Random(42);
      for (int seed = 0; seed < 20; seed++) {
        final GCounter a = _randomGCounter(rng);
        final GCounter b = _randomGCounter(rng);
        final GCounter c = _randomGCounter(rng);
        expect(a.merge(b), b.merge(a), reason: 'commutativity seed=$seed');
        expect(
          a.merge(b).merge(c),
          a.merge(b.merge(c)),
          reason: 'associativity seed=$seed',
        );
        expect(a.merge(a), a, reason: 'idempotency seed=$seed');
      }
    });

    test('rejects non-positive increments', () {
      expect(() => GCounter().increment('a', 0), throwsArgumentError);
      expect(() => GCounter().increment('a', -1), throwsArgumentError);
    });

    test('toJson/fromJson round-trips', () {
      final GCounter c = GCounter().increment('a', 3).increment('b', 7);
      final GCounter restored = GCounter.fromJson(c.toJson());
      expect(restored, c);
    });
  });
}

GCounter _randomGCounter(Random rng) {
  GCounter c = GCounter();
  final int ops = rng.nextInt(8) + 1;
  for (int i = 0; i < ops; i++) {
    c = c.increment('node-${rng.nextInt(4)}', rng.nextInt(5) + 1);
  }
  return c;
}
