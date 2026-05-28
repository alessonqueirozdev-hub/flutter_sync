// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:math';

import 'package:flutter_sync/flutter_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LWWMap', () {
    HLCTimestamp ts(int counter, {String node = 'a'}) => HLCTimestamp(
          physicalTime: 1700000000000,
          logicalCounter: counter,
          nodeId: node,
        );

    test('newer set overrides older value', () {
      LWWMap<String, int> m = LWWMap<String, int>();
      m = m.set('k', 1, ts(1));
      m = m.set('k', 2, ts(2));
      expect(m.get('k'), 2);
    });

    test('older set is ignored', () {
      LWWMap<String, int> m = LWWMap<String, int>();
      m = m.set('k', 2, ts(2));
      m = m.set('k', 1, ts(1));
      expect(m.get('k'), 2);
    });

    test('delete tombstones the key', () {
      LWWMap<String, int> m = LWWMap<String, int>();
      m = m.set('k', 1, ts(1));
      m = m.delete('k', ts(2));
      expect(m.containsKey('k'), isFalse);
      expect(m.get('k'), isNull);
    });

    test('merge converges regardless of order', () {
      final Random rng = Random(11);
      for (int seed = 0; seed < 20; seed++) {
        final LWWMap<String, int> a = _random(rng);
        final LWWMap<String, int> b = _random(rng);
        expect(a.merge(b).value, b.merge(a).value, reason: 'seed=$seed');
      }
    });
  });
}

LWWMap<String, int> _random(Random rng) {
  LWWMap<String, int> m = LWWMap<String, int>();
  for (int i = 0; i < rng.nextInt(8) + 1; i++) {
    final HLCTimestamp t = HLCTimestamp(
      physicalTime: 1700000000000,
      logicalCounter: i,
      nodeId: 'n${rng.nextInt(3)}',
    );
    final String key = 'k${rng.nextInt(3)}';
    if (rng.nextBool()) {
      m = m.set(key, rng.nextInt(100), t);
    } else {
      m = m.delete(key, t);
    }
  }
  return m;
}
