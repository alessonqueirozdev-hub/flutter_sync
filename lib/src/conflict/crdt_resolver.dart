// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import '../core/hlc/hlc_timestamp.dart';
import '../models/sync_conflict.dart';
import '../models/sync_record.dart';
import 'conflict_resolver.dart';

/// Function signature used by [CRDTResolver] to merge a single field that
/// holds a CRDT payload.
///
/// Implementations receive the two competing JSON-encoded representations
/// and return the merged JSON-encoded result. The function must respect
/// the CRDT properties (commutativity, associativity, idempotency).
typedef CRDTFieldMerger = Object? Function(
  Object? local,
  Object? remote,
);

/// CRDT-aware conflict resolver.
///
/// Merges each field listed in [mergers] using its registered
/// [CRDTFieldMerger]. Fields not present in [mergers] are resolved through
/// the supplied [fallback] resolver (default: last-write-wins by HLC).
///
/// Use this resolver when records carry CRDT payloads (counters, sets,
/// maps, text) that must converge deterministically across replicas.
class CRDTResolver implements ConflictResolver {
  /// Creates a CRDT resolver with the supplied per-field [mergers] and an
  /// optional [fallback] resolver for non-CRDT fields.
  const CRDTResolver({
    required this.mergers,
    this.fallback = const _DefaultLWWFallback(),
  });

  /// Per-field merge functions. Keys are field names (matching keys in
  /// `SyncRecord.payload`).
  final Map<String, CRDTFieldMerger> mergers;

  /// Resolver invoked for fields not present in [mergers].
  final ConflictResolver fallback;

  @override
  ConflictResolutionStrategy get strategy => ConflictResolutionStrategy.crdt;

  @override
  String get name => 'crdt';

  @override
  Future<SyncRecord> resolve(SyncConflict conflict) async {
    final Map<String, Object?> mergedPayload = <String, Object?>{};
    final Set<String> allFields = <String>{
      ...conflict.local.payload.keys,
      ...conflict.remote.payload.keys,
    };
    bool usedFallback = false;
    for (final String field in allFields) {
      final CRDTFieldMerger? merger = mergers[field];
      if (merger == null) {
        usedFallback = true;
        continue;
      }
      mergedPayload[field] = merger(
        conflict.local.payload[field],
        conflict.remote.payload[field],
      );
    }
    final SyncRecord winnerForFallback =
        usedFallback ? await fallback.resolve(conflict) : conflict.local;
    for (final String field in allFields) {
      if (!mergers.containsKey(field)) {
        mergedPayload[field] = winnerForFallback.payload[field];
      }
    }
    final HLCTimestamp localHlc = HLCTimestamp.parse(conflict.local.hlc);
    final HLCTimestamp remoteHlc = HLCTimestamp.parse(conflict.remote.hlc);
    final HLCTimestamp winnerHlc =
        remoteHlc > localHlc ? remoteHlc : localHlc;
    return conflict.local.copyWith(
      payload: mergedPayload,
      hlc: winnerHlc.toWire(),
      updatedAt: conflict.remote.updatedAt.isAfter(conflict.local.updatedAt)
          ? conflict.remote.updatedAt
          : conflict.local.updatedAt,
      isDeleted: conflict.local.isDeleted && conflict.remote.isDeleted,
    );
  }
}

class _DefaultLWWFallback implements ConflictResolver {
  const _DefaultLWWFallback();

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
