// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter_sync/flutter_sync.dart' show DeltaComputer;
import 'package:flutter_sync/src/core/delta/delta_computer.dart' show DeltaComputer;
import 'package:meta/meta.dart';

import '../../conflict/conflict_resolver.dart';
import '../../models/sync_conflict.dart';
import '../../models/sync_record.dart';
import '../../store/sync_store.dart';
import '../hlc/hlc_clock.dart';
import '../hlc/hlc_timestamp.dart';

/// Per-record outcome produced by [DeltaMerger.merge].
enum DeltaMergeOutcome {
  /// The remote record was inserted into the store as a new entry.
  inserted,

  /// The remote record was applied because it was strictly newer than the
  /// local record (HLC dominance).
  applied,

  /// The remote record was skipped because the local record was strictly
  /// newer (HLC dominance).
  ignored,

  /// A conflict was detected and resolved via [ConflictResolver]; the
  /// winning record was written to the store.
  resolved,
}

/// Summary of a single [DeltaMerger.merge] invocation.
@immutable
class DeltaMergeReport {
  /// Creates a merge report.
  const DeltaMergeReport({
    required this.inserted,
    required this.applied,
    required this.ignored,
    required this.resolved,
    required this.appliedHighWaterHlc,
  });

  /// Number of remote records inserted as new local entries.
  final int inserted;

  /// Number of remote records that strictly dominated the local record and
  /// were applied as updates.
  final int applied;

  /// Number of remote records ignored because the local record dominated.
  final int ignored;

  /// Number of conflicts resolved via [ConflictResolver].
  final int resolved;

  /// HLC wire-format watermark of the latest remote record processed
  /// (regardless of whether it was applied), or `null` when the batch was
  /// empty. Callers should advance `SyncMetadata.lastSyncedAt` to this
  /// value after the merge.
  final String? appliedHighWaterHlc;

  /// Total number of records processed.
  int get total => inserted + applied + ignored + resolved;

  @override
  String toString() => 'DeltaMergeReport(inserted: $inserted, '
      'applied: $applied, ignored: $ignored, resolved: $resolved, '
      'highWater: $appliedHighWaterHlc)';
}

/// Applies a list of remote records to a local [SyncStore], routing
/// conflicts through the configured [ConflictResolver].
///
/// The merge is the symmetric counterpart to [DeltaComputer]: the computer
/// answers "what do we push?" and the merger answers "what do we accept?".
class DeltaMerger {
  /// Creates a merger bound to [resolver] and [clock].
  ///
  /// [clock] is required so that the local HLC is advanced for every
  /// remote timestamp received — this preserves the HLC invariant that
  /// any future local event is strictly greater than every event the node
  /// has observed.
  const DeltaMerger({
    required this.resolver,
    required this.clock,
  });

  /// Conflict resolver consulted whenever a remote and a local record
  /// collide.
  final ConflictResolver resolver;

  /// Clock used to integrate each remote timestamp.
  final HybridLogicalClock clock;

  /// Applies [remoteRecords] to [store], returning a per-batch
  /// [DeltaMergeReport].
  Future<DeltaMergeReport> merge({
    required SyncStore store,
    required List<SyncRecord> remoteRecords,
  }) async {
    int inserted = 0;
    int applied = 0;
    int ignored = 0;
    int resolved = 0;
    HLCTimestamp? highest;

    for (final SyncRecord remote in remoteRecords) {
      final HLCTimestamp remoteHlc = HLCTimestamp.parse(remote.hlc);
      clock.receive(remoteHlc);
      if (highest == null || remoteHlc > highest) {
        highest = remoteHlc;
      }

      final SyncRecord? local = await store.findById(remote.collection, remote.id);
      if (local == null) {
        await store.upsert(remote);
        inserted += 1;
        continue;
      }

      final HLCTimestamp localHlc = HLCTimestamp.parse(local.hlc);
      final int cmp = remoteHlc.compareTo(localHlc);
      if (cmp == 0) {
        ignored += 1;
        continue;
      }
      if (cmp > 0 && _equalContent(local, remote, ignoreHlc: true)) {
        await store.upsert(remote);
        applied += 1;
        continue;
      }
      if (cmp > 0 && local.updatedAt.isBefore(remote.updatedAt)) {
        await store.upsert(remote);
        applied += 1;
        continue;
      }

      final SyncConflict conflict = SyncConflict(
        local: local,
        remote: remote,
        detectedAt: DateTime.now().toUtc(),
      );
      final SyncRecord winner = await resolver.resolve(conflict);
      await store.upsert(winner);
      resolved += 1;
    }

    return DeltaMergeReport(
      inserted: inserted,
      applied: applied,
      ignored: ignored,
      resolved: resolved,
      appliedHighWaterHlc: highest?.toWire(),
    );
  }

  bool _equalContent(
    SyncRecord a,
    SyncRecord b, {
    required bool ignoreHlc,
  }) {
    if (a.isDeleted != b.isDeleted) {
      return false;
    }
    if (a.collection != b.collection || a.id != b.id) {
      return false;
    }
    if (!ignoreHlc && a.hlc != b.hlc) {
      return false;
    }
    return a.payload.length == b.payload.length;
  }
}
