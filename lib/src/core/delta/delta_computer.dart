// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import '../../models/sync_query.dart';
import '../../models/sync_record.dart';
import '../../store/sync_store.dart';
import '../hlc/hlc_timestamp.dart';

/// Computes the set of records that have changed since a given HLC
/// watermark and therefore must be pushed to the backend.
///
/// The class is stateless and safe to share. It reads from the supplied
/// [SyncStore] and never mutates it; the work happens on the calling
/// isolate, but the computation is deliberately lightweight (no payload
/// hashing) so this is acceptable up to thousands of records. For larger
/// collections the engine wraps the call in `Isolate.run`.
class DeltaComputer {
  /// Creates a stateless delta computer.
  const DeltaComputer();

  /// Returns the records in [collection] whose HLC is strictly greater
  /// than [sinceWire].
  ///
  /// Pass `null` for [sinceWire] to perform a full initial scan of the
  /// collection — every live record is returned in HLC order.
  Future<List<SyncRecord>> compute({
    required SyncStore store,
    required String collection,
    String? sinceWire,
    bool includeDeleted = true,
  }) async {
    final SyncQuery base =
        includeDeleted ? const SyncQuery().withDeleted() : const SyncQuery();
    final List<SyncRecord> all = await store.findAll(collection, query: base);
    if (sinceWire == null) {
      return _sortByHlc(all);
    }
    final HLCTimestamp since = HLCTimestamp.parse(sinceWire);
    final List<SyncRecord> filtered = <SyncRecord>[];
    for (final SyncRecord record in all) {
      final HLCTimestamp hlc = HLCTimestamp.parse(record.hlc);
      if (hlc > since) {
        filtered.add(record);
      }
    }
    return _sortByHlc(filtered);
  }

  /// Returns the highest HLC observed in [records], or `null` when the
  /// list is empty.
  String? highWaterMark(List<SyncRecord> records) {
    if (records.isEmpty) {
      return null;
    }
    HLCTimestamp highest = HLCTimestamp.parse(records.first.hlc);
    for (int i = 1; i < records.length; i++) {
      final HLCTimestamp candidate = HLCTimestamp.parse(records[i].hlc);
      if (candidate > highest) {
        highest = candidate;
      }
    }
    return highest.toWire();
  }

  List<SyncRecord> _sortByHlc(List<SyncRecord> records) {
    final List<SyncRecord> copy = List<SyncRecord>.of(records);
    copy.sort(
      (SyncRecord a, SyncRecord b) =>
          HLCTimestamp.parse(a.hlc).compareTo(HLCTimestamp.parse(b.hlc)),
    );
    return copy;
  }
}
