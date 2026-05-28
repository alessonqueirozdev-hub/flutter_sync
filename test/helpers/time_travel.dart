// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter_sync/flutter_sync.dart';

/// Deterministic [PhysicalClock] used by tests that need to advance time
/// without waiting for the wall clock.
class FakePhysicalClock implements PhysicalClock {
  /// Creates a fake clock starting at [initialMillis].
  FakePhysicalClock({int initialMillis = 1700000000000})
      : _nowMillis = initialMillis;

  int _nowMillis;

  @override
  int nowMillis() => _nowMillis;

  /// Sets the clock to [millis].
  void setTime(int millis) {
    _nowMillis = millis;
  }

  /// Advances the clock by [duration].
  void advance(Duration duration) {
    _nowMillis += duration.inMilliseconds;
  }
}

/// Helper that builds a [HybridLogicalClock] driven by a [FakePhysicalClock]
/// so test code can produce deterministic HLC sequences.
class FakeHlcEnvironment {
  /// Creates a fake HLC environment for [nodeId].
  FakeHlcEnvironment({String nodeId = 'node-test'})
      : physical = FakePhysicalClock(),
        clock = HybridLogicalClock(
          nodeId: nodeId,
          physicalClock: FakePhysicalClock(),
        );

  /// Underlying fake physical clock.
  final FakePhysicalClock physical;

  /// HLC clock under test.
  final HybridLogicalClock clock;
}
