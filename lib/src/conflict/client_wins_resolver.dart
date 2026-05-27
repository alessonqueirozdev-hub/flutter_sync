// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import '../models/sync_conflict.dart';
import '../models/sync_record.dart';
import 'conflict_resolver.dart';

/// Client-wins resolver: the local record always overrides the remote one.
///
/// Useful when the device's input is considered authoritative — for
/// example, on-device user edits in apps where the server is just a
/// backup, or in single-writer workflows where the device is the only
/// origin of new state.
class ClientWinsResolver implements ConflictResolver {
  /// Creates a stateless client-wins resolver.
  const ClientWinsResolver();

  @override
  ConflictResolutionStrategy get strategy =>
      ConflictResolutionStrategy.clientWins;

  @override
  String get name => 'client-wins';

  @override
  Future<SyncRecord> resolve(SyncConflict conflict) async => conflict.local;
}
