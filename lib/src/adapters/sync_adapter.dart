// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

import '../models/sync_batch.dart';
import '../models/sync_event.dart';
import '../models/sync_filter.dart';
import '../models/sync_pull_request.dart';
import '../models/sync_pull_result.dart';
import '../models/sync_push_result.dart';

/// Contract every backend integration must implement.
///
/// A [SyncAdapter] is the only point of contact between FlutterSync and a
/// specific backend (Supabase, Firebase, REST, GraphQL, gRPC, custom). The
/// engine owns batching, retry, conflict resolution, the outbox, and the
/// local store; adapters are deliberately thin and concern themselves only
/// with transport, authentication, and the backend's wire protocol.
///
/// Implementations are expected to be safe to invoke from any isolate and
/// to handle their own internal concurrency. All methods are idempotent
/// with respect to `idempotencyKey` values carried inside the records.
///
/// The two auxiliary value objects [SyncSubscription] and
/// [SyncAdapterCapabilities] are tightly coupled to this contract and are
/// declared in the same file by design — they are part of the adapter
/// surface, not standalone models.
abstract interface class SyncAdapter {
  /// Performs adapter-specific one-time setup (network warm-up, schema
  /// validation, authentication checks). Called once during
  /// `FlutterSync.configure`.
  ///
  /// Implementations must throw a typed adapter exception if the adapter
  /// cannot be brought to a working state; the engine will surface the
  /// failure through `SyncStatus.error`.
  Future<void> initialize();

  /// Pushes [batch] to the backend.
  ///
  /// Returns a [SyncPushResult] describing whether the push fully succeeded,
  /// partially succeeded, must be retried, or failed permanently. The engine
  /// uses this to decide between marking the outbox entries synced,
  /// re-enqueueing them with backoff, or dead-lettering them.
  Future<SyncPushResult> push(SyncBatch batch);

  /// Pulls records changed since `request.since` from the backend.
  ///
  /// Returns a [SyncPullResult] containing the received records plus any
  /// pagination cursor required to fetch additional pages.
  Future<SyncPullResult> pull(SyncPullRequest request);

  /// Subscribes to real-time updates for the supplied [subscription] scope.
  ///
  /// Adapters that do not natively support push notifications (REST, gRPC
  /// without streaming, etc.) may return an empty broadcast stream and rely
  /// on the scheduler's periodic pull instead. See [SyncAdapterCapabilities]
  /// for runtime introspection.
  Stream<SyncEvent> subscribe(SyncSubscription subscription);

  /// Releases adapter resources (network connections, isolates, timers).
  /// Called once during `FlutterSync.dispose`.
  Future<void> dispose();

  /// Describes which optional features this adapter supports.
  ///
  /// The engine consults [capabilities] before invoking features that are
  /// not supported by every backend (real-time push, server-side filters,
  /// schema validation).
  SyncAdapterCapabilities get capabilities;
}

/// Scope of a real-time subscription requested from a [SyncAdapter].
@immutable
class SyncSubscription {
  /// Creates a subscription scope.
  const SyncSubscription({
    required this.collection,
    this.filter,
    this.since,
  });

  /// Logical collection to subscribe to.
  final String collection;

  /// Optional server-side filter narrowing the subscription scope.
  final SyncFilter? filter;

  /// Optional HLC wire-format watermark; events before this point are
  /// suppressed by the adapter when supported.
  final String? since;

  @override
  bool operator ==(Object other) =>
      other is SyncSubscription &&
      other.collection == collection &&
      other.filter == filter &&
      other.since == since;

  @override
  int get hashCode => Object.hash(collection, filter, since);

  @override
  String toString() =>
      'SyncSubscription(collection: $collection, since: $since)';
}

/// Runtime description of optional features supported by a [SyncAdapter].
@immutable
class SyncAdapterCapabilities {
  /// Creates an immutable capability descriptor.
  const SyncAdapterCapabilities({
    required this.realtime,
    required this.serverSideFilters,
    required this.partialSync,
    required this.idempotentPush,
    required this.deltaPull,
    required this.maxBatchSize,
    this.supportsCompression = false,
    this.supportsServerSchemaValidation = false,
  });

  /// `true` when the adapter exposes push-style real-time updates via
  /// `subscribe`.
  final bool realtime;

  /// `true` when the adapter can apply [SyncFilter] on the server.
  final bool serverSideFilters;

  /// `true` when the adapter supports partial-sync scoping per repository.
  final bool partialSync;

  /// `true` when the server safely deduplicates retries by idempotency key.
  final bool idempotentPush;

  /// `true` when the adapter supports incremental delta pulls.
  final bool deltaPull;

  /// Maximum number of records the adapter is willing to accept in a single
  /// `push` call.
  final int maxBatchSize;

  /// `true` when the adapter applies HTTP-level compression on payloads.
  final bool supportsCompression;

  /// `true` when the adapter validates the wire schema server-side before
  /// accepting a push.
  final bool supportsServerSchemaValidation;

  @override
  String toString() =>
      'SyncAdapterCapabilities(realtime: $realtime, deltaPull: $deltaPull, '
      'partialSync: $partialSync, maxBatchSize: $maxBatchSize)';
}
