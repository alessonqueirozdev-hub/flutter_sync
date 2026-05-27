// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import 'package:uuid/uuid.dart';

import 'hlc_clock.dart';
import 'hlc_timestamp.dart';

/// Persistent backing for an [HybridLogicalClock].
///
/// An [HLCNode] is responsible for two pieces of state that must outlive
/// the in-memory [HybridLogicalClock]:
///
/// - The stable installation node identifier (`nodeId`) — generated on
///   first launch, persisted forever, and used as the tie-breaker
///   component of every [HLCTimestamp] emitted by this device.
/// - The most recent clock snapshot — restored at startup so that
///   monotonicity holds across app restarts and crashes.
///
/// The interface is intentionally minimal so that backing stores can range
/// from in-memory (tests) to `flutter_secure_storage` (production
/// implementation that ships alongside the encryption layer).
abstract interface class HLCNode {
  /// Returns the stable node identifier, generating and persisting one on
  /// the first call.
  Future<String> nodeId();

  /// Returns the most recently persisted clock snapshot, or `null` when
  /// the clock has never been saved on this device.
  Future<HLCTimestamp?> loadState();

  /// Atomically persists [snapshot] so that the next call to [loadState]
  /// returns it.
  Future<void> saveState(HLCTimestamp snapshot);

  /// Erases the persisted node identifier and clock snapshot.
  ///
  /// Used by integration tests and the "log out / wipe device" code paths.
  /// Subsequent calls to [nodeId] generate a fresh identifier.
  Future<void> reset();
}

/// In-memory [HLCNode] suitable for tests, prototypes, and the first-boot
/// path before a durable implementation is wired in.
class InMemoryHLCNode implements HLCNode {
  /// Creates an in-memory node, optionally pre-populated with [nodeId] and
  /// [initialState].
  InMemoryHLCNode({
    String? nodeId,
    HLCTimestamp? initialState,
    Uuid? uuid,
  })  : _nodeId = nodeId,
        _state = initialState,
        _uuid = uuid ?? const Uuid();

  String? _nodeId;
  HLCTimestamp? _state;
  final Uuid _uuid;

  @override
  Future<String> nodeId() async {
    return _nodeId ??= _uuid.v4();
  }

  @override
  Future<HLCTimestamp?> loadState() async => _state;

  @override
  Future<void> saveState(HLCTimestamp snapshot) async {
    _state = snapshot;
  }

  @override
  Future<void> reset() async {
    _nodeId = null;
    _state = null;
  }
}

/// Builds a [HybridLogicalClock] hydrated from the supplied [node].
///
/// On startup the clock is seeded from `node.loadState()`. Every tick or
/// receive is followed by an asynchronous `node.saveState(clock.current)`
/// to persist the new clock for crash recovery.
class HLCNodeBoundClock {
  /// Wires a clock to its [HLCNode] backing.
  HLCNodeBoundClock({
    required HybridLogicalClock clock,
    required HLCNode node,
  })  : _clock = clock,
        _node = node;

  final HybridLogicalClock _clock;
  final HLCNode _node;

  /// Records a local event and persists the resulting clock state.
  Future<HLCTimestamp> tick() async {
    final HLCTimestamp result = _clock.tick();
    await _node.saveState(result);
    return result;
  }

  /// Integrates a remote [remote] and persists the resulting clock state.
  Future<HLCTimestamp> receive(HLCTimestamp remote) async {
    final HLCTimestamp result = _clock.receive(remote);
    await _node.saveState(result);
    return result;
  }

  /// The most recently emitted or received timestamp.
  HLCTimestamp get current => _clock.current;

  /// Stable identifier of the node owning this clock.
  String get nodeId => _clock.nodeId;
}
