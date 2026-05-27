// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import '../core/hlc/hlc_timestamp.dart';
import '../models/sync_conflict.dart';
import '../models/sync_record.dart';
import 'client_wins_resolver.dart';
import 'conflict_resolver.dart';
import 'lww_resolver.dart';
import 'server_wins_resolver.dart';

/// Per-field strategy applied by [FieldLevelResolver].
enum FieldStrategy {
  /// The field with the strictly greater HLC wins.
  lww,

  /// The remote field always wins.
  serverWins,

  /// The local field always wins.
  clientWins,

  /// The values are merged with the supplied [FieldMerger].
  merge,
}

/// Function signature used by [FieldLevelResolver] for fields configured
/// with [FieldStrategy.merge].
typedef FieldMerger = Object? Function(
  Object? local,
  Object? remote,
);

/// Per-field strategy descriptor for [FieldLevelResolver].
class FieldStrategyConfig {
  /// Creates a per-field strategy descriptor.
  const FieldStrategyConfig({
    required this.strategy,
    this.merger,
  })  : assert(
          strategy != FieldStrategy.merge || merger != null,
          'FieldStrategy.merge requires a merger function.',
        );

  /// Selected strategy for the field.
  final FieldStrategy strategy;

  /// Merge function used when [strategy] is [FieldStrategy.merge].
  final FieldMerger? merger;
}

/// Field-level conflict resolver.
///
/// Resolves each field of the conflicting records independently according
/// to the supplied [strategies] map. Fields not listed in [strategies] are
/// resolved with [defaultStrategy].
class FieldLevelResolver implements ConflictResolver {
  /// Creates a field-level resolver.
  const FieldLevelResolver({
    required this.strategies,
    this.defaultStrategy = const FieldStrategyConfig(strategy: FieldStrategy.lww),
  });

  /// Per-field strategy configuration.
  final Map<String, FieldStrategyConfig> strategies;

  /// Strategy applied to fields not listed in [strategies].
  final FieldStrategyConfig defaultStrategy;

  @override
  ConflictResolutionStrategy get strategy =>
      ConflictResolutionStrategy.fieldLevel;

  @override
  String get name => 'field-level';

  @override
  Future<SyncRecord> resolve(SyncConflict conflict) async {
    final Set<String> allFields = <String>{
      ...conflict.local.payload.keys,
      ...conflict.remote.payload.keys,
    };
    final Map<String, Object?> merged = <String, Object?>{};
    for (final String field in allFields) {
      final FieldStrategyConfig config = strategies[field] ?? defaultStrategy;
      merged[field] = await _applyStrategy(
        config,
        conflict.local.payload[field],
        conflict.remote.payload[field],
        conflict,
      );
    }
    final HLCTimestamp localHlc = HLCTimestamp.parse(conflict.local.hlc);
    final HLCTimestamp remoteHlc = HLCTimestamp.parse(conflict.remote.hlc);
    final HLCTimestamp winnerHlc =
        remoteHlc > localHlc ? remoteHlc : localHlc;
    return conflict.local.copyWith(
      payload: merged,
      hlc: winnerHlc.toWire(),
      updatedAt: conflict.remote.updatedAt.isAfter(conflict.local.updatedAt)
          ? conflict.remote.updatedAt
          : conflict.local.updatedAt,
      isDeleted: conflict.local.isDeleted && conflict.remote.isDeleted,
    );
  }

  Future<Object?> _applyStrategy(
    FieldStrategyConfig config,
    Object? localValue,
    Object? remoteValue,
    SyncConflict conflict,
  ) async {
    switch (config.strategy) {
      case FieldStrategy.lww:
        final SyncRecord winner =
            await const LWWResolver().resolve(conflict);
        return winner == conflict.local ? localValue : remoteValue;
      case FieldStrategy.serverWins:
        final SyncRecord winner =
            await const ServerWinsResolver().resolve(conflict);
        return winner == conflict.local ? localValue : remoteValue;
      case FieldStrategy.clientWins:
        final SyncRecord winner =
            await const ClientWinsResolver().resolve(conflict);
        return winner == conflict.local ? localValue : remoteValue;
      case FieldStrategy.merge:
        return config.merger!(localValue, remoteValue);
    }
  }
}
