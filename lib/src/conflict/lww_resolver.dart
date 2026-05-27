// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import '../core/hlc/hlc_timestamp.dart';
import '../models/sync_conflict.dart';
import '../models/sync_record.dart';
import 'conflict_resolver.dart';

/// Last-Write-Wins resolver: returns the record with the strictly greater
/// [HLCTimestamp].
///
/// LWW is the most common and simplest resolution strategy. Because HLC
/// provides a total order over events across the entire system, the winner
/// is always well-defined — there are no ties.
class LWWResolver implements ConflictResolver {
  /// Creates a stateless last-write-wins resolver.
  const LWWResolver();

  @override
  ConflictResolutionStrategy get strategy =>
      ConflictResolutionStrategy.lastWriteWins;

  @override
  String get name => 'lww';

  @override
  Future<SyncRecord> resolve(SyncConflict conflict) async {
    final HLCTimestamp localHlc = HLCTimestamp.parse(conflict.local.hlc);
    final HLCTimestamp remoteHlc = HLCTimestamp.parse(conflict.remote.hlc);
    return remoteHlc > localHlc ? conflict.remote : conflict.local;
  }
}
