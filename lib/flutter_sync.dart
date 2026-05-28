// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

/// FlutterSync — offline-first sync engine for Flutter.
///
/// This barrel file is the single source of truth for the public API of the
/// `flutter_sync` package. Any symbol not exported from this file lives in
/// `lib/src/` and is considered internal. Internal symbols may change
/// between minor releases without notice; do not import them directly
/// from `package:flutter_sync/src/...`.
library;

// Backend adapters. Platform-specific adapter classes are exported from
// dedicated sub-libraries to avoid pulling unused backend SDKs into apps
// that only need one (e.g. a Firebase-only app should not transitively
// import the Supabase or gRPC client). The host imports the specific
// adapter it wants.
export 'src/adapters/mock/mock_sync_adapter.dart';
export 'src/adapters/rest/rest_sync_adapter.dart';
export 'src/adapters/rest/rest_sync_config.dart';
// Interfaces (sync_adapter.dart co-exports SyncSubscription +
// SyncAdapterCapabilities; sync_store.dart co-exports SyncStoreConfig,
// SyncStoreEvent, and SyncStoreMigration).
export 'src/adapters/sync_adapter.dart';
// Audit + logging.
export 'src/audit/audit_entry.dart';
export 'src/audit/audit_query.dart';
export 'src/audit/audit_trail.dart';
// Connectivity, bandwidth, scheduler.
export 'src/bandwidth/bandwidth_monitor.dart';
// Conflict resolvers.
export 'src/conflict/client_wins_resolver.dart';
export 'src/conflict/conflict_resolver.dart';
export 'src/conflict/crdt_resolver.dart';
export 'src/conflict/field_level_resolver.dart';
export 'src/conflict/lww_resolver.dart';
export 'src/conflict/server_wins_resolver.dart';
// Delta primitives (advanced users / DevTools authors).
export 'src/core/delta/delta_computer.dart';
export 'src/core/delta/delta_merger.dart';
// Public entry point.
export 'src/core/flutter_sync.dart';
// Hybrid Logical Clock primitives.
export 'src/core/hlc/hlc_clock.dart';
export 'src/core/hlc/hlc_node.dart';
export 'src/core/hlc/hlc_timestamp.dart';
export 'src/core/sync_repository.dart';
// CRDTs.
export 'src/crdt/g_counter.dart';
export 'src/crdt/lww_map.dart';
export 'src/crdt/lww_set.dart';
export 'src/crdt/pn_counter.dart';
export 'src/crdt/sync_text.dart';
export 'src/crdt/two_phase_set.dart';
// Encryption.
export 'src/encryption/argon2_key_deriver.dart';
export 'src/encryption/encryption_config.dart';
export 'src/encryption/key_store.dart';
export 'src/encryption/record_encryptor.dart';
export 'src/encryption/secure_storage_key_store.dart';
export 'src/logging/console_logger.dart';
export 'src/logging/sync_logger.dart';
// Schema migrations.
export 'src/migration/migration_runner.dart';
export 'src/migration/schema_migration.dart';
// Models.
export 'src/models/network_state.dart';
export 'src/models/sync_batch.dart';
export 'src/models/sync_conflict.dart';
export 'src/models/sync_debug_info.dart';
export 'src/models/sync_event.dart';
export 'src/models/sync_filter.dart';
export 'src/models/sync_metadata.dart';
export 'src/models/sync_pull_request.dart';
export 'src/models/sync_pull_result.dart';
export 'src/models/sync_push_result.dart';
export 'src/models/sync_query.dart';
export 'src/models/sync_record.dart';
export 'src/models/sync_status.dart';
// Outbox.
export 'src/outbox/outbox_entry.dart';
export 'src/outbox/outbox_queue.dart';
export 'src/outbox/retry_strategy.dart';
export 'src/scheduler/background_sync.dart';
export 'src/scheduler/connectivity_observer.dart';
export 'src/scheduler/foreground_sync.dart';
export 'src/scheduler/sync_scheduler.dart';
// Local store implementations.
export 'src/store/drift/drift_database.dart';
export 'src/store/drift/drift_sync_store.dart';
export 'src/store/hive/hive_sync_store.dart';
export 'src/store/sync_store.dart';
