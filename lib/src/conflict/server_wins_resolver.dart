// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import '../models/sync_conflict.dart';
import '../models/sync_record.dart';
import 'conflict_resolver.dart';

/// Server-wins resolver: the remote record always overrides the local one.
///
/// Useful when the server is treated as the authoritative source of truth
/// — for example, when reference data is centrally curated and devices
/// should never override it.
class ServerWinsResolver implements ConflictResolver {
  /// Creates a stateless server-wins resolver.
  const ServerWinsResolver();

  @override
  ConflictResolutionStrategy get strategy =>
      ConflictResolutionStrategy.serverWins;

  @override
  String get name => 'server-wins';

  @override
  Future<SyncRecord> resolve(SyncConflict conflict) async => conflict.remote;
}
