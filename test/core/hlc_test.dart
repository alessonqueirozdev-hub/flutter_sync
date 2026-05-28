// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter_sync/flutter_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/time_travel.dart';

void main() {
  group('HLCTimestamp', () {
    test('wire format round-trips', () {
      const HLCTimestamp ts = HLCTimestamp(
        physicalTime: 1700000000000,
        logicalCounter: 5,
        nodeId: 'node-a',
      );
      final HLCTimestamp parsed = HLCTimestamp.parse(ts.toWire());
      expect(parsed, ts);
    });

    test('wire format sorts lexicographically by physicalTime', () {
      const HLCTimestamp a = HLCTimestamp(
        physicalTime: 1700000000000,
        logicalCounter: 99,
        nodeId: 'z',
      );
      const HLCTimestamp b = HLCTimestamp(
        physicalTime: 1700000000001,
        logicalCounter: 0,
        nodeId: 'a',
      );
      expect(a.toWire().compareTo(b.toWire()) < 0, isTrue);
      expect(a.compareTo(b), lessThan(0));
    });

    test('compareTo breaks ties by counter then nodeId', () {
      const HLCTimestamp t1 = HLCTimestamp(
        physicalTime: 100,
        logicalCounter: 0,
        nodeId: 'a',
      );
      const HLCTimestamp t2 = HLCTimestamp(
        physicalTime: 100,
        logicalCounter: 1,
        nodeId: 'a',
      );
      const HLCTimestamp t3 = HLCTimestamp(
        physicalTime: 100,
        logicalCounter: 1,
        nodeId: 'b',
      );
      expect(t1.compareTo(t2), lessThan(0));
      expect(t2.compareTo(t3), lessThan(0));
    });

    test('parse rejects malformed wire format', () {
      expect(() => HLCTimestamp.parse('garbage'), throwsFormatException);
      expect(() => HLCTimestamp.parse('abc-1-node'), throwsFormatException);
      expect(() => HLCTimestamp.parse('1-1-'), throwsFormatException);
    });
  });

  group('HybridLogicalClock', () {
    test('tick advances physical when wall clock is ahead', () {
      final FakePhysicalClock physical = FakePhysicalClock(initialMillis: 100);
      final HybridLogicalClock clock = HybridLogicalClock(
        nodeId: 'a',
        physicalClock: physical,
      );
      final HLCTimestamp first = clock.tick();
      physical.advance(const Duration(milliseconds: 50));
      final HLCTimestamp second = clock.tick();
      expect(first.physicalTime, 100);
      expect(first.logicalCounter, 0);
      expect(second.physicalTime, 150);
      expect(second.logicalCounter, 0);
    });

    test('tick increments counter when wall clock has not advanced', () {
      final FakePhysicalClock physical = FakePhysicalClock(initialMillis: 100);
      final HybridLogicalClock clock = HybridLogicalClock(
        nodeId: 'a',
        physicalClock: physical,
      );
      final HLCTimestamp first = clock.tick();
      final HLCTimestamp second = clock.tick();
      final HLCTimestamp third = clock.tick();
      expect(first.logicalCounter, 0);
      expect(second.logicalCounter, 1);
      expect(third.logicalCounter, 2);
    });

    test('receive integrates a remote timestamp ahead of the local clock', () {
      final FakePhysicalClock physical = FakePhysicalClock(initialMillis: 100);
      final HybridLogicalClock clock = HybridLogicalClock(
        nodeId: 'local',
        physicalClock: physical,
      );
      const HLCTimestamp remote = HLCTimestamp(
        physicalTime: 200,
        logicalCounter: 4,
        nodeId: 'remote',
      );
      final HLCTimestamp result = clock.receive(remote);
      expect(result.physicalTime, 200);
      expect(result.logicalCounter, 5);
      expect(result.nodeId, 'local');
    });

    test('receive throws HLCDriftException when remote exceeds tolerance', () {
      final FakePhysicalClock physical = FakePhysicalClock(initialMillis: 100);
      final HybridLogicalClock clock = HybridLogicalClock(
        nodeId: 'local',
        physicalClock: physical,
        driftTolerance: const Duration(seconds: 1),
      );
      const HLCTimestamp remote = HLCTimestamp(
        physicalTime: 10000000,
        logicalCounter: 0,
        nodeId: 'remote',
      );
      expect(() => clock.receive(remote), throwsA(isA<HLCDriftException>()));
    });

    test('restore replaces internal state', () {
      final FakePhysicalClock physical = FakePhysicalClock(initialMillis: 100);
      final HybridLogicalClock clock = HybridLogicalClock(
        nodeId: 'local',
        physicalClock: physical,
      );
      clock.tick();
      clock.restore(const HLCTimestamp(
        physicalTime: 500,
        logicalCounter: 42,
        nodeId: 'local',
      ));
      expect(clock.current.physicalTime, 500);
      expect(clock.current.logicalCounter, 42);
    });
  });
}
