// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:math' as math;

import 'package:flutter_sync/flutter_sync.dart' show PNCounter;
import 'package:flutter_sync/src/crdt/pn_counter.dart' show PNCounter;
import 'package:meta/meta.dart';

/// Grow-only Conflict-free Replicated Data Type for counting.
///
/// A [GCounter] is the canonical CRDT for monotonically-increasing values
/// (likes, downloads, views). Each node owns its own per-node counter; the
/// observable [value] is the sum across every node, and [merge] takes the
/// element-wise maximum so concurrent updates from different nodes are
/// preserved.
///
/// Properties (validated by the property-based tests in Phase 15):
///
/// - **Commutativity** — `a.merge(b)` has the same value as `b.merge(a)`.
/// - **Associativity** — `(a.merge(b)).merge(c)` == `a.merge(b.merge(c))`.
/// - **Idempotency** — `a.merge(a)` == `a`.
@immutable
class GCounter {
  /// Creates a counter with the supplied per-node state.
  ///
  /// The map is defensively copied so callers may mutate the original.
  GCounter([Map<String, int>? counters])
      : _counters = Map<String, int>.unmodifiable(
          (counters ?? <String, int>{}).map<String, int>(
            (String key, int value) =>
                MapEntry<String, int>(key, value < 0 ? 0 : value),
          ),
        );

  /// Reconstructs a counter from a JSON-compatible map.
  factory GCounter.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> rawState =
        Map<String, Object?>.from(json['state']! as Map<Object?, Object?>);
    final Map<String, int> state = rawState.map<String, int>(
      (String key, Object? value) =>
          MapEntry<String, int>(key, (value as num).toInt()),
    );
    return GCounter(state);
  }

  /// Per-node state of the counter. Keys are node identifiers, values are
  /// non-negative integers.
  final Map<String, int> _counters;

  /// Returns the immutable per-node state.
  Map<String, int> get state => _counters;

  /// Observable value of the counter: the sum across every node.
  int get value =>
      _counters.values.fold<int>(0, (int acc, int element) => acc + element);

  /// Returns a new counter with [nodeId]'s counter incremented by [amount].
  ///
  /// [amount] must be a positive integer; for decrements use [PNCounter].
  GCounter increment(String nodeId, [int amount = 1]) {
    if (amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'GCounter.increment requires a positive amount.',
      );
    }
    final Map<String, int> next = Map<String, int>.from(_counters);
    next[nodeId] = (next[nodeId] ?? 0) + amount;
    return GCounter(next);
  }

  /// Returns the merge of this counter with [other].
  GCounter merge(GCounter other) {
    final Map<String, int> next = Map<String, int>.from(_counters);
    other._counters.forEach((String node, int count) {
      next[node] = math.max(next[node] ?? 0, count);
    });
    return GCounter(next);
  }

  /// Serializes the counter to a JSON-compatible map.
  Map<String, Object?> toJson() => <String, Object?>{
        'type': 'g_counter',
        'state': _counters,
      };

  @override
  bool operator ==(Object other) {
    if (other is! GCounter) {
      return false;
    }
    if (other._counters.length != _counters.length) {
      return false;
    }
    for (final MapEntry<String, int> entry in _counters.entries) {
      if (other._counters[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    int hash = 0;
    for (final MapEntry<String, int> entry in _counters.entries) {
      hash = hash ^ Object.hash(entry.key, entry.value);
    }
    return hash;
  }

  @override
  String toString() => 'GCounter(value: $value, nodes: ${_counters.length})';
}
