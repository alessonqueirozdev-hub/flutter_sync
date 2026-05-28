// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:math';

import 'package:flutter_sync/flutter_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncText', () {
    test('insert produces the expected value', () {
      final SyncText t = SyncText(siteId: 'a', rng: Random(0));
      t.insert(0, 'Hi');
      t.insert(2, '!');
      expect(t.value, 'Hi!');
      expect(t.length, 3);
    });

    test('insert at index 0 places characters before existing content', () {
      final SyncText t = SyncText(siteId: 'a', rng: Random(0));
      t.insert(0, 'World');
      t.insert(0, 'Hello ');
      expect(t.value, 'Hello World');
    });

    test('delete removes the requested range', () {
      final SyncText t = SyncText(siteId: 'a', rng: Random(0));
      t.insert(0, 'Hello');
      t.delete(1, 4);
      expect(t.value, 'Ho');
    });

    test('merge keeps every character exactly once', () {
      final SyncText left = SyncText(siteId: 'a', rng: Random(1));
      final SyncText right = SyncText(siteId: 'b', rng: Random(2));
      left.insert(0, 'AB');
      right.insert(0, 'CD');
      final SyncText merged = left.merge(right);
      expect(merged.length, 4);
      final List<String> chars = merged.characters
          .map((LogootCharacter c) => c.value)
          .toList();
      expect(chars.toSet(), <String>{'A', 'B', 'C', 'D'});
    });

    test('LogootPosition wire-format round-trips', () {
      final LogootPosition p = LogootPosition(const <LogootAtom>[
        LogootAtom(10, 'a'),
        LogootAtom(42, 'b'),
      ]);
      expect(LogootPosition.parse(p.toWire()), p);
    });
  });
}
