// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';
import 'dart:convert';

import 'package:grpc/grpc.dart';

import '../../models/sync_batch.dart';
import '../../models/sync_event.dart';
import '../../models/sync_pull_request.dart';
import '../../models/sync_pull_result.dart';
import '../../models/sync_push_result.dart';
import '../../models/sync_record.dart';
import '../../outbox/outbox_entry.dart';
import '../sync_adapter.dart';

/// Hook used by [GrpcSyncAdapter] to delegate the protobuf wire calls to
/// the consumer-generated stub.
///
/// The adapter is decoupled from the generated stub so that consumers may
/// run `protoc` against `flutter_sync.proto` themselves (Dart's gRPC
/// stack does not yet ship in-tree generation) and provide an instance of
/// this transport. Tests substitute an in-memory transport.
abstract interface class GrpcSyncTransport {
  /// Sends [request] and returns the server response.
  Future<GrpcPushResponse> push(GrpcPushRequest request);

  /// Sends [request] and returns the server response.
  Future<GrpcPullResponse> pull(GrpcPullRequest request);

  /// Returns a stream of records emitted by the server.
  Stream<GrpcWatchEvent> watch(GrpcWatchRequest request);

  /// Closes the underlying gRPC channel.
  Future<void> shutdown();
}

/// Plain-Dart representation of `PushRequest`.
class GrpcPushRequest {
  /// Creates a push request.
  GrpcPushRequest({
    required this.collection,
    required this.records,
    required this.idempotencyKeys,
  });

  /// Logical collection being pushed.
  final String collection;

  /// Records to push.
  final List<SyncRecord> records;

  /// Idempotency keys aligned with [records] by index.
  final List<String> idempotencyKeys;
}

/// Plain-Dart representation of `PushResponse`.
class GrpcPushResponse {
  /// Creates a push response.
  const GrpcPushResponse({
    required this.pushed,
    required this.rejectedIds,
    this.serverCursor,
  });

  /// Number of records the server accepted.
  final int pushed;

  /// Record identifiers the server rejected.
  final List<String> rejectedIds;

  /// Optional server-side advancement cursor.
  final String? serverCursor;
}

/// Plain-Dart representation of `PullRequest`.
class GrpcPullRequest {
  /// Creates a pull request.
  const GrpcPullRequest({
    required this.collection,
    required this.pageSize,
    this.since,
    this.cursor,
    this.includeDeleted = true,
  });

  /// Logical collection to pull.
  final String collection;

  /// Maximum records per page.
  final int pageSize;

  /// HLC watermark; `null` for full pull.
  final String? since;

  /// Opaque continuation token from a previous pull.
  final String? cursor;

  /// Whether tombstones are requested.
  final bool includeDeleted;
}

/// Plain-Dart representation of `PullResponse`.
class GrpcPullResponse {
  /// Creates a pull response.
  const GrpcPullResponse({
    required this.records,
    this.highWaterHlc,
    this.hasMore = false,
    this.nextCursor,
  });

  /// Records returned by the server.
  final List<SyncRecord> records;

  /// New HLC watermark.
  final String? highWaterHlc;

  /// Whether the server has more records to return in subsequent pulls.
  final bool hasMore;

  /// Optional continuation token for the next pull.
  final String? nextCursor;
}

/// Plain-Dart representation of `WatchRequest`.
class GrpcWatchRequest {
  /// Creates a watch request.
  const GrpcWatchRequest({required this.collection, this.since});

  /// Logical collection to subscribe to.
  final String collection;

  /// Optional HLC watermark suppressing events before this point.
  final String? since;
}

/// Plain-Dart representation of `WatchEvent`.
class GrpcWatchEvent {
  /// Creates a watch event.
  const GrpcWatchEvent({required this.record, this.eventSource = 'unknown'});

  /// Received record.
  final SyncRecord record;

  /// Optional event-source tag the server can include for diagnostics.
  final String eventSource;
}

/// FlutterSync adapter targeting a gRPC service implementing the
/// `flutter_sync.proto` contract.
class GrpcSyncAdapter implements SyncAdapter {
  /// Creates a gRPC adapter wrapping [transport].
  GrpcSyncAdapter({
    required GrpcSyncTransport transport,
    SyncAdapterCapabilities? capabilities,
  })  : _transport = transport,
        capabilities = capabilities ??
            const SyncAdapterCapabilities(
              realtime: true,
              serverSideFilters: false,
              partialSync: false,
              idempotentPush: true,
              deltaPull: true,
              maxBatchSize: 1000,
            );

  final GrpcSyncTransport _transport;

  @override
  final SyncAdapterCapabilities capabilities;

  @override
  Future<void> initialize() async {}

  @override
  Future<SyncPushResult> push(SyncBatch batch) async {
    if (batch.isEmpty) {
      return const SyncPushResult.success(pushedCount: 0);
    }
    final List<String> keys = batch.entries
        .map<String>(OutboxEntry.computeIdempotencyKey)
        .toList();
    try {
      final GrpcPushResponse response = await _transport.push(
        GrpcPushRequest(
          collection: batch.collection,
          records: batch.entries,
          idempotencyKeys: keys,
        ),
      );
      if (response.rejectedIds.isNotEmpty) {
        return SyncPushResult.partial(
          pushedCount: response.pushed,
          rejectedIds: response.rejectedIds,
          serverCursor: response.serverCursor,
        );
      }
      return SyncPushResult.success(
        pushedCount: response.pushed,
        serverCursor: response.serverCursor,
      );
    } on GrpcError catch (e) {
      if (e.code == StatusCode.unavailable ||
          e.code == StatusCode.deadlineExceeded) {
        return SyncPushResult.retry(reason: e.message ?? 'unavailable');
      }
      return SyncPushResult.failure(
        reason: e.message ?? 'gRPC error ${e.code}',
        cause: e,
      );
    }
  }

  @override
  Future<SyncPullResult> pull(SyncPullRequest request) async {
    try {
      final GrpcPullResponse response = await _transport.pull(
        GrpcPullRequest(
          collection: request.collection,
          pageSize: request.pageSize,
          since: request.since,
          cursor: request.cursor,
          includeDeleted: request.includeDeleted,
        ),
      );
      return SyncPullResult.success(
        records: response.records,
        highWaterHlc: response.highWaterHlc,
        hasMore: response.hasMore,
      );
    } on GrpcError catch (e) {
      if (e.code == StatusCode.unavailable ||
          e.code == StatusCode.deadlineExceeded) {
        return SyncPullResult.retry(reason: e.message ?? 'unavailable');
      }
      return SyncPullResult.failure(
        reason: e.message ?? 'gRPC error ${e.code}',
        cause: e,
      );
    }
  }

  @override
  Stream<SyncEvent> subscribe(SyncSubscription subscription) {
    return _transport
        .watch(
          GrpcWatchRequest(
            collection: subscription.collection,
            since: subscription.since,
          ),
        )
        .map<SyncEvent>(
          (GrpcWatchEvent e) => SyncEventRecordReceived(
            at: DateTime.now().toUtc(),
            record: e.record,
          ),
        );
  }

  @override
  Future<void> dispose() async {
    await _transport.shutdown();
  }
}

/// Helper used by transports to translate `payload_json` strings into the
/// `Map<String, Object?>` shape FlutterSync's models expect.
@pragma('vm:prefer-inline')
Map<String, Object?> decodeGrpcPayload(String json) {
  if (json.isEmpty) {
    return const <String, Object?>{};
  }
  final Object? decoded = jsonDecode(json);
  if (decoded is Map) {
    return Map<String, Object?>.from(decoded as Map<Object?, Object?>);
  }
  return const <String, Object?>{};
}
