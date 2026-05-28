// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:math';

import 'package:flutter_sync/flutter_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PNCounter', () {
    test('supports both increment and decrement', () {
      final PNCounter c = PNCounter()
          .increment('a', 5)
          .decrement('a', 2)
          .increment('b', 3);
      expect(c.value, 6);
    });

    test('merge preserves both components', () {
      final PNCounter a = PNCounter().increment('a', 5).decrement('b', 1);
      final PNCounter b = PNCounter().increment('a', 7).decrement('c', 3);
      final PNCounter merged = a.merge(b);
      expect(merged.value, 7 - 1 - 3);
    });

    test('merge is commutative and idempotent under random ops', () {
      final Random rng = Random(1);
      for (int s = 0; s < 20; s++) {
        final PNCounter a = _random(rng);
        final PNCounter b = _random(rng);
        expect(a.merge(b), b.merge(a));
        expect(a.merge(a), a);
      }
    });

    test('toJson/fromJson round-trips', () {
      final PNCounter c = PNCounter().increment('a', 4).decrement('b', 2);
      final PNCounter back = PNCounter.fromJson(c.toJson());
      expect(back, c);
      expect(back.value, c.value);
    });
  });
}

PNCounter _random(Random rng) {
  PNCounter c = PNCounter();
  for (int i = 0; i < rng.nextInt(8) + 1; i++) {
    final String node = 'n-${rng.nextInt(4)}';
    if (rng.nextBool()) {
      c = c.increment(node, rng.nextInt(5) + 1);
    } else {
      c = c.decrement(node, rng.nextInt(5) + 1);
    }
  }
  return c;
}
