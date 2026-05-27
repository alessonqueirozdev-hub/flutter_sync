// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:math' as math;

import 'hlc_timestamp.dart';

/// Source of monotonic wall-clock physical time, in milliseconds since the
/// Unix epoch.
///
/// Tests override this with a fake to drive the clock deterministically;
/// production code uses [SystemPhysicalClock].
abstract interface class PhysicalClock {
  /// Returns the current wall-clock instant, in milliseconds since the
  /// Unix epoch.
  int nowMillis();
}

/// Default [PhysicalClock] backed by [DateTime.now].
final class SystemPhysicalClock implements PhysicalClock {
  /// Const constructor for the singleton-like system clock.
  const SystemPhysicalClock();

  @override
  int nowMillis() => DateTime.now().millisecondsSinceEpoch;
}

/// Raised by [HybridLogicalClock.receive] when a remote [HLCTimestamp]
/// arrives whose physical-time component is further ahead of the local
/// wall clock than the configured drift tolerance.
class HLCDriftException implements Exception {
  /// Creates a drift exception carrying both the remote and local clocks
  /// for diagnostics.
  const HLCDriftException({
    required this.remote,
    required this.localWallMillis,
    required this.toleranceMillis,
  });

  /// The remote timestamp whose drift exceeded the tolerance.
  final HLCTimestamp remote;

  /// Local wall-clock value at the moment of the check, in milliseconds.
  final int localWallMillis;

  /// Configured drift tolerance, in milliseconds.
  final int toleranceMillis;

  /// Drift between the remote physical time and the local wall clock.
  int get driftMillis => remote.physicalTime - localWallMillis;

  @override
  String toString() =>
      'HLCDriftException(drift: ${driftMillis}ms, tolerance: ${toleranceMillis}ms, '
      'remote: ${remote.toWire()})';
}

/// Implementation of the Hybrid Logical Clock from Kulkarni et al. (2014),
/// *"Logical Physical Clocks and Consistent Snapshots in Globally
/// Distributed Databases."*
///
/// The clock provides two operations:
///
/// - [tick] — called on every local event. Returns a fresh [HLCTimestamp]
///   that is strictly greater than every timestamp previously emitted by
///   this node and every timestamp this node has received via [receive].
/// - [receive] — called on every remote event. Returns a fresh
///   [HLCTimestamp] that is strictly greater than both the previously held
///   local clock and the incoming remote timestamp.
///
/// Both operations are constant-time and allocation-free apart from the
/// returned [HLCTimestamp].
class HybridLogicalClock {
  /// Creates a clock for [nodeId] starting at [initial] (or zero) and
  /// rejecting remote timestamps whose physical drift exceeds
  /// [driftTolerance].
  HybridLogicalClock({
    required String nodeId,
    HLCTimestamp? initial,
    PhysicalClock physicalClock = const SystemPhysicalClock(),
    Duration driftTolerance = const Duration(seconds: 300),
  })  : _nodeId = nodeId,
        _physicalClock = physicalClock,
        _driftToleranceMillis = driftTolerance.inMilliseconds,
        _current = initial ?? HLCTimestamp.zero(nodeId);

  final String _nodeId;
  final PhysicalClock _physicalClock;
  final int _driftToleranceMillis;
  HLCTimestamp _current;

  /// The most recently emitted or received timestamp for this clock.
  HLCTimestamp get current => _current;

  /// Stable identifier of the node owning this clock.
  String get nodeId => _nodeId;

  /// Records a local event and returns its [HLCTimestamp].
  ///
  /// Algorithm:
  ///
  /// ```
  /// let pt = wallclock_now_ms()
  /// if pt > l.physicalTime:
  ///   l.physicalTime = pt
  ///   l.logicalCounter = 0
  /// else:
  ///   l.logicalCounter += 1
  /// ```
  HLCTimestamp tick() {
    final int pt = _physicalClock.nowMillis();
    if (pt > _current.physicalTime) {
      _current = HLCTimestamp(
        physicalTime: pt,
        logicalCounter: 0,
        nodeId: _nodeId,
      );
    } else {
      _current = HLCTimestamp(
        physicalTime: _current.physicalTime,
        logicalCounter: _current.logicalCounter + 1,
        nodeId: _nodeId,
      );
    }
    return _current;
  }

  /// Integrates the supplied [remote] timestamp into this clock and
  /// returns a fresh [HLCTimestamp] for the resulting local event.
  ///
  /// Throws [HLCDriftException] when `remote.physicalTime` is more than
  /// the configured drift tolerance ahead of the local wall clock — the
  /// system is configured to reject suspicious timestamps rather than
  /// silently jumping the local clock by hours or days.
  ///
  /// Algorithm:
  ///
  /// ```
  /// let pt = wallclock_now_ms()
  /// let old = l.physicalTime
  /// l.physicalTime = max(old, remote.physicalTime, pt)
  /// if l.physicalTime == old == remote.physicalTime:
  ///   l.logicalCounter = max(l.logicalCounter, remote.logicalCounter) + 1
  /// elif l.physicalTime == old:
  ///   l.logicalCounter += 1
  /// elif l.physicalTime == remote.physicalTime:
  ///   l.logicalCounter = remote.logicalCounter + 1
  /// else:
  ///   l.logicalCounter = 0
  /// ```
  HLCTimestamp receive(HLCTimestamp remote) {
    final int pt = _physicalClock.nowMillis();
    final int drift = remote.physicalTime - pt;
    if (drift > _driftToleranceMillis) {
      throw HLCDriftException(
        remote: remote,
        localWallMillis: pt,
        toleranceMillis: _driftToleranceMillis,
      );
    }
    final int oldPt = _current.physicalTime;
    final int newPt = math.max(math.max(oldPt, remote.physicalTime), pt);
    final int newCounter;
    if (newPt == oldPt && newPt == remote.physicalTime) {
      newCounter =
          math.max(_current.logicalCounter, remote.logicalCounter) + 1;
    } else if (newPt == oldPt) {
      newCounter = _current.logicalCounter + 1;
    } else if (newPt == remote.physicalTime) {
      newCounter = remote.logicalCounter + 1;
    } else {
      newCounter = 0;
    }
    _current = HLCTimestamp(
      physicalTime: newPt,
      logicalCounter: newCounter,
      nodeId: _nodeId,
    );
    return _current;
  }

  /// Restores the clock to [snapshot] without applying any of the
  /// algorithm's monotonicity invariants.
  ///
  /// This is used by `HLCNode` on startup to seed the clock with the value
  /// persisted from the previous run. Callers MUST ensure that [snapshot]
  /// belongs to this [nodeId]; passing a snapshot from another node
  /// breaks total ordering and is a serious bug.
  void restore(HLCTimestamp snapshot) {
    assert(
      snapshot.nodeId == _nodeId,
      'restore() requires a snapshot from the owning node.',
    );
    _current = snapshot;
  }
}
