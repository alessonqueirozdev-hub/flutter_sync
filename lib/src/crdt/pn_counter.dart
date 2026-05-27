// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

import 'g_counter.dart';

/// Positive-Negative Conflict-free Replicated Data Type for counting.
///
/// A [PNCounter] is the natural extension of [GCounter] when the counter
/// must support decrement as well as increment. Internally it is the pair
/// of two [GCounter]s — one accumulating positive contributions, one
/// accumulating negative contributions — and the observable [value] is the
/// difference between the two.
///
/// All three CRDT properties (commutativity, associativity, idempotency)
/// follow directly from those of [GCounter].
@immutable
class PNCounter {
  /// Creates a counter from the supplied [positive] and [negative]
  /// component [GCounter]s.
  PNCounter({GCounter? positive, GCounter? negative})
      : positive = positive ?? GCounter(),
        negative = negative ?? GCounter();

  /// Sub-counter accumulating positive contributions.
  final GCounter positive;

  /// Sub-counter accumulating negative contributions.
  final GCounter negative;

  /// Observable value: `positive.value - negative.value`.
  int get value => positive.value - negative.value;

  /// Returns a new counter with [nodeId]'s positive component increased
  /// by [amount].
  PNCounter increment(String nodeId, [int amount = 1]) => PNCounter(
        positive: positive.increment(nodeId, amount),
        negative: negative,
      );

  /// Returns a new counter with [nodeId]'s negative component increased
  /// by [amount].
  PNCounter decrement(String nodeId, [int amount = 1]) => PNCounter(
        positive: positive,
        negative: negative.increment(nodeId, amount),
      );

  /// Returns the merge of this counter with [other].
  PNCounter merge(PNCounter other) => PNCounter(
        positive: positive.merge(other.positive),
        negative: negative.merge(other.negative),
      );

  /// Serializes the counter to a JSON-compatible map.
  Map<String, Object?> toJson() => <String, Object?>{
        'type': 'pn_counter',
        'positive': positive.toJson(),
        'negative': negative.toJson(),
      };

  /// Reconstructs a counter from a JSON-compatible map.
  factory PNCounter.fromJson(Map<String, Object?> json) => PNCounter(
        positive: GCounter.fromJson(
          Map<String, Object?>.from(json['positive']! as Map<Object?, Object?>),
        ),
        negative: GCounter.fromJson(
          Map<String, Object?>.from(json['negative']! as Map<Object?, Object?>),
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is PNCounter &&
      other.positive == positive &&
      other.negative == negative;

  @override
  int get hashCode => Object.hash(positive, negative);

  @override
  String toString() => 'PNCounter(value: $value)';
}
