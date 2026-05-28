// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:math';

import 'package:flutter_sync/flutter_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LWWSet', () {
    HLCTimestamp ts(int counter, {String node = 'a'}) => HLCTimestamp(
          physicalTime: 1700000000000,
          logicalCounter: counter,
          nodeId: node,
        );

    test('add then remove with newer ts removes the element', () {
      LWWSet<String> s = LWWSet<String>();
      s = s.add('apple', ts(1));
      expect(s.contains('apple'), isTrue);
      s = s.remove('apple', ts(2));
      expect(s.contains('apple'), isFalse);
    });

    test('readd with newer ts re-includes the element', () {
      LWWSet<String> s = LWWSet<String>();
      s = s.add('apple', ts(1));
      s = s.remove('apple', ts(2));
      s = s.add('apple', ts(3));
      expect(s.contains('apple'), isTrue);
    });

    test('merge converges regardless of order', () {
      final Random rng = Random(7);
      for (int seed = 0; seed < 20; seed++) {
        final LWWSet<String> a = _randomOps(rng);
        final LWWSet<String> b = _randomOps(rng);
        expect(a.merge(b).value, b.merge(a).value, reason: 'seed=$seed');
        expect(a.merge(a).value, a.value, reason: 'idempotent seed=$seed');
      }
    });
  });
}

LWWSet<String> _randomOps(Random rng) {
  LWWSet<String> s = LWWSet<String>();
  for (int i = 0; i < rng.nextInt(8) + 1; i++) {
    final String element = 'e${rng.nextInt(4)}';
    final HLCTimestamp t = HLCTimestamp(
      physicalTime: 1700000000000,
      logicalCounter: i,
      nodeId: 'n${rng.nextInt(3)}',
    );
    if (rng.nextBool()) {
      s = s.add(element, t);
    } else {
      s = s.remove(element, t);
    }
  }
  return s;
}
