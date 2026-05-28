// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter_sync/flutter_sync.dart';

/// Convenience builders for the most common shapes used across the test
/// suite. Each helper returns a fresh instance so tests are free to mutate
/// the returned object.
class TestFixtures {
  const TestFixtures._();

  /// Returns a [SyncRecord] with sensible defaults plus the supplied
  /// overrides.
  static SyncRecord record({
    String id = 'r1',
    String collection = 'todos',
    Map<String, Object?>? payload,
    String? hlc,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isDeleted = false,
  }) {
    final DateTime now = createdAt ?? DateTime.utc(2026, 1, 1, 12);
    return SyncRecord(
      id: id,
      collection: collection,
      payload: payload ?? <String, Object?>{'title': 'Test', 'done': false},
      hlc: hlc ?? const HLCTimestamp(physicalTime: 1700000000000, logicalCounter: 0, nodeId: 'node-a').toWire(),
      createdAt: now,
      updatedAt: updatedAt ?? now,
      isDeleted: isDeleted,
    );
  }

  /// Returns a single-record [SyncBatch].
  static SyncBatch singletonBatch(SyncRecord rec, {String id = 'batch-1'}) =>
      SyncBatch(
        id: id,
        collection: rec.collection,
        entries: <SyncRecord>[rec],
        createdAt: DateTime.utc(2026, 1, 1, 12),
      );

  /// Returns a [SyncConflict] between two records of the same logical key.
  static SyncConflict conflict({
    SyncRecord? local,
    SyncRecord? remote,
  }) {
    final SyncRecord effectiveLocal = local ?? record(hlc: _hlc(10).toWire());
    final SyncRecord effectiveRemote = remote ??
        effectiveLocal.copyWith(
          payload: <String, Object?>{'title': 'Remote', 'done': true},
          hlc: _hlc(20).toWire(),
        );
    return SyncConflict(
      local: effectiveLocal,
      remote: effectiveRemote,
      detectedAt: DateTime.utc(2026, 1, 1, 12, 30),
    );
  }

  static HLCTimestamp _hlc(int counter, {String nodeId = 'node-a'}) =>
      HLCTimestamp(
        physicalTime: 1700000000000,
        logicalCounter: counter,
        nodeId: nodeId,
      );
}
