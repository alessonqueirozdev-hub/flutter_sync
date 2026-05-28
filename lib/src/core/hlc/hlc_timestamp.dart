// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

/// Immutable Hybrid Logical Clock timestamp.
///
/// A [HLCTimestamp] uniquely orders an event across a distributed system
/// composed of nodes whose physical clocks may drift. The total ordering is
/// `physicalTime`, then `logicalCounter`, then `nodeId` — see [compareTo]
/// for the exact rule.
///
/// The canonical wire and storage representation is
/// `{physicalMs}-{counter}-{nodeId}`, with the first two segments
/// zero-padded so that timestamps sort correctly as plain strings (no
/// numeric parsing needed). The padding widths are:
///
/// - `physicalMs` — 20 digits (sufficient for any 64-bit integer).
/// - `counter` — 10 digits.
///
/// Example:
/// ```
/// 00000001700000000-0000000005-9b2c6d4a-7e90-4f10-9bda-2e0e7c3a5d11
/// ```
@immutable
class HLCTimestamp implements Comparable<HLCTimestamp> {
  /// Creates an immutable HLC timestamp.
  ///
  /// All three components are mandatory. [physicalTime] must be a
  /// non-negative integer (milliseconds since the Unix epoch),
  /// [logicalCounter] must be a non-negative integer, and [nodeId] must be
  /// a non-empty stable identifier (typically a UUID v4).
  const HLCTimestamp({
    required this.physicalTime,
    required this.logicalCounter,
    required this.nodeId,
  })  : assert(physicalTime >= 0, 'physicalTime must be non-negative'),
        assert(logicalCounter >= 0, 'logicalCounter must be non-negative'),
        assert(nodeId.length > 0, 'nodeId must be non-empty');

  /// Parses [wire] into a [HLCTimestamp].
  ///
  /// Throws [FormatException] when [wire] does not match the canonical
  /// `{physicalMs}-{counter}-{nodeId}` format.
  factory HLCTimestamp.parse(String wire) {
    final int firstDash = wire.indexOf('-');
    if (firstDash <= 0) {
      throw FormatException('Invalid HLC wire format: $wire');
    }
    final int secondDash = wire.indexOf('-', firstDash + 1);
    if (secondDash <= firstDash) {
      throw FormatException('Invalid HLC wire format: $wire');
    }
    final String ptSegment = wire.substring(0, firstDash);
    final String cSegment = wire.substring(firstDash + 1, secondDash);
    final String nodeSegment = wire.substring(secondDash + 1);
    final int? pt = int.tryParse(ptSegment);
    final int? c = int.tryParse(cSegment);
    if (pt == null || c == null || nodeSegment.isEmpty) {
      throw FormatException('Invalid HLC wire format: $wire');
    }
    return HLCTimestamp(
      physicalTime: pt,
      logicalCounter: c,
      nodeId: nodeSegment,
    );
  }

  /// Returns a zero-valued timestamp for [nodeId].
  ///
  /// Used as the seed for a brand-new clock that has not yet emitted any
  /// event or received any remote update.
  const HLCTimestamp.zero(this.nodeId)
      : physicalTime = 0,
        logicalCounter = 0;

  /// Wall-clock physical time component in milliseconds since the Unix
  /// epoch.
  final int physicalTime;

  /// Monotonic logical counter incremented when [physicalTime] does not
  /// advance between two consecutive emissions.
  final int logicalCounter;

  /// Stable identifier of the node that emitted this timestamp.
  final String nodeId;

  /// Width of the zero-padded physical-time segment in the wire format.
  static const int _physicalPad = 20;

  /// Width of the zero-padded counter segment in the wire format.
  static const int _counterPad = 10;

  /// Returns the canonical wire/storage representation of this timestamp.
  String toWire() {
    final String pt = physicalTime.toString().padLeft(_physicalPad, '0');
    final String c = logicalCounter.toString().padLeft(_counterPad, '0');
    return '$pt-$c-$nodeId';
  }

  /// Returns a copy of this timestamp with the supplied fields replaced.
  HLCTimestamp copyWith({
    int? physicalTime,
    int? logicalCounter,
    String? nodeId,
  }) {
    return HLCTimestamp(
      physicalTime: physicalTime ?? this.physicalTime,
      logicalCounter: logicalCounter ?? this.logicalCounter,
      nodeId: nodeId ?? this.nodeId,
    );
  }

  /// Total order over HLC timestamps.
  ///
  /// Comparison is performed lexicographically over the triple
  /// `(physicalTime, logicalCounter, nodeId)`. This produces a stable total
  /// order across all nodes regardless of physical-clock skew, which is the
  /// fundamental guarantee provided by an HLC.
  @override
  int compareTo(HLCTimestamp other) {
    if (physicalTime != other.physicalTime) {
      return physicalTime.compareTo(other.physicalTime);
    }
    if (logicalCounter != other.logicalCounter) {
      return logicalCounter.compareTo(other.logicalCounter);
    }
    return nodeId.compareTo(other.nodeId);
  }

  /// `true` when `this` represents an event that happened strictly before
  /// [other] in the global order.
  bool operator <(HLCTimestamp other) => compareTo(other) < 0;

  /// `true` when `this` is less than or equal to [other] in the global
  /// order.
  bool operator <=(HLCTimestamp other) => compareTo(other) <= 0;

  /// `true` when `this` represents an event that happened strictly after
  /// [other] in the global order.
  bool operator >(HLCTimestamp other) => compareTo(other) > 0;

  /// `true` when `this` is greater than or equal to [other] in the global
  /// order.
  bool operator >=(HLCTimestamp other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is HLCTimestamp &&
      other.physicalTime == physicalTime &&
      other.logicalCounter == logicalCounter &&
      other.nodeId == nodeId;

  @override
  int get hashCode => Object.hash(physicalTime, logicalCounter, nodeId);

  @override
  String toString() => toWire();
}
