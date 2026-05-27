// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

/// FlutterSync — offline-first sync engine for Flutter.
///
/// This barrel file is the single source of truth for the public API of the
/// `flutter_sync` package. Any symbol not exported from this file lives in
/// `lib/src/` and is considered internal. Internal symbols may change between
/// minor releases without notice; do not import them directly from
/// `package:flutter_sync/src/...`.
///
/// The exports are grouped by layer and added progressively as each phase of
/// the package is implemented:
///
/// 1. Models — immutable value objects and sealed unions.
/// 2. Interfaces — `SyncAdapter`, `SyncStore`, `ConflictResolver`.
/// 3. Hybrid Logical Clock primitives.
/// 4. CRDTs.
/// 5. Conflict resolvers.
/// 6. Outbox and retry.
/// 7. Local store implementations (Drift, Hive).
/// 8. Scheduler and background sync.
/// 9. Backend adapters (Supabase, Firebase, REST, GraphQL, gRPC, Mock).
/// 10. Encryption.
/// 11. Audit and logging.
/// 12. Schema migrations.
/// 13. Engine and entry point (`FlutterSync`, `SyncRepository`).
/// 14. DevTools overlay.
library;

// Models.
export 'src/models/sync_record.dart';
export 'src/models/sync_metadata.dart';
export 'src/models/sync_status.dart';
export 'src/models/sync_event.dart';
export 'src/models/sync_conflict.dart';
export 'src/models/sync_batch.dart';
export 'src/models/sync_query.dart';
export 'src/models/sync_filter.dart';
export 'src/models/sync_push_result.dart';
export 'src/models/sync_pull_result.dart';
export 'src/models/sync_pull_request.dart';
export 'src/models/network_state.dart';
export 'src/models/sync_debug_info.dart';

// Interfaces.
// `sync_adapter.dart` co-exports the tightly-coupled `SyncSubscription` and
// `SyncAdapterCapabilities` value objects that appear in its signature.
export 'src/adapters/sync_adapter.dart';
export 'src/store/sync_store.dart';
export 'src/conflict/conflict_resolver.dart';
