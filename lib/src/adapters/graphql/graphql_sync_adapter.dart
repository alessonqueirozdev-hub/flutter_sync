// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import 'package:graphql/client.dart' as gql;

import '../../models/sync_batch.dart';
import '../../models/sync_event.dart';
import '../../models/sync_pull_request.dart';
import '../../models/sync_pull_result.dart';
import '../../models/sync_push_result.dart';
import '../../models/sync_record.dart';
import '../sync_adapter.dart';
import 'graphql_sync_config.dart';

/// FlutterSync adapter targeting a GraphQL backend that exposes
/// `sync_pull`, `sync_push`, and `sync_watch` operations matching the
/// shape produced by [GraphQLDocumentFactory].
class GraphQLSyncAdapter implements SyncAdapter {
  /// Creates a GraphQL adapter.
  GraphQLSyncAdapter({
    required this.config,
    gql.GraphQLClient? client,
    SyncAdapterCapabilities? capabilities,
  })  : _client = client ??
            gql.GraphQLClient(
              link: gql.HttpLink(
                config.endpoint,
                defaultHeaders: config.headers,
              ),
              cache: gql.GraphQLCache(),
            ),
        capabilities = capabilities ??
            SyncAdapterCapabilities(
              realtime: config.subscriptionEndpoint != null,
              serverSideFilters: true,
              partialSync: true,
              idempotentPush: true,
              deltaPull: true,
              maxBatchSize: 200,
            );

  /// Effective configuration.
  final GraphQLSyncConfig config;
  final gql.GraphQLClient _client;

  @override
  final SyncAdapterCapabilities capabilities;

  @override
  Future<void> initialize() async {}

  @override
  Future<SyncPushResult> push(SyncBatch batch) async {
    if (batch.isEmpty) {
      return const SyncPushResult.success(pushedCount: 0);
    }
    final gql.QueryResult<Object?> result = await _client.mutate(
      gql.MutationOptions(
        document: gql.gql(config.documentFactory.pushMutation(batch.collection)),
        variables: <String, Object?>{
          'collection': batch.collection,
          'records': <Map<String, Object?>>[
            for (final SyncRecord r in batch.entries) r.toJson(),
          ],
        },
      ),
    );
    if (result.hasException) {
      final gql.OperationException ex = result.exception!;
      final bool transient = ex.linkException != null;
      if (transient) {
        return SyncPushResult.retry(reason: ex.toString());
      }
      return SyncPushResult.failure(reason: ex.toString(), cause: ex);
    }
    final Map<String, Object?>? data =
        result.data?['sync_push'] as Map<String, Object?>?;
    final int pushed = (data?['pushed'] as num?)?.toInt() ?? batch.size;
    final List<String> rejected = <String>[
      for (final Object? r in (data?['rejected_ids'] as List<Object?>? ?? const <Object?>[]))
        r.toString(),
    ];
    if (rejected.isNotEmpty) {
      return SyncPushResult.partial(pushedCount: pushed, rejectedIds: rejected);
    }
    return SyncPushResult.success(pushedCount: pushed);
  }

  @override
  Future<SyncPullResult> pull(SyncPullRequest request) async {
    final gql.QueryResult<Object?> result = await _client.query(
      gql.QueryOptions(
        document: gql.gql(config.documentFactory.pullQuery(request.collection)),
        variables: <String, Object?>{
          'collection': request.collection,
          'since': request.since,
          'limit': request.pageSize,
          'cursor': request.cursor,
        },
        fetchPolicy: gql.FetchPolicy.noCache,
      ),
    );
    if (result.hasException) {
      final gql.OperationException ex = result.exception!;
      final bool transient = ex.linkException != null;
      if (transient) {
        return SyncPullResult.retry(reason: ex.toString());
      }
      return SyncPullResult.failure(reason: ex.toString(), cause: ex);
    }
    final Map<String, Object?>? data =
        result.data?['sync_pull'] as Map<String, Object?>?;
    final List<Object?> rawRecords =
        data?['records'] as List<Object?>? ?? const <Object?>[];
    final List<SyncRecord> records = <SyncRecord>[
      for (final Object? r in rawRecords)
        SyncRecord.fromJson(
          Map<String, Object?>.from(r! as Map<Object?, Object?>),
        ),
    ];
    return SyncPullResult.success(
      records: records,
      highWaterHlc: data?['high_water_hlc'] as String?,
      hasMore: (data?['has_more'] as bool?) ?? false,
    );
  }

  @override
  Stream<SyncEvent> subscribe(SyncSubscription subscription) {
    if (config.subscriptionEndpoint == null) {
      return const Stream<SyncEvent>.empty();
    }
    final gql.Stream<gql.QueryResult<Object?>> stream = _client.subscribe(
      gql.SubscriptionOptions(
        document: gql.gql(
          config.documentFactory.subscribeDocument(subscription.collection),
        ),
        variables: <String, Object?>{
          'collection': subscription.collection,
          'since': subscription.since,
        },
      ),
    );
    return stream
        .where((gql.QueryResult<Object?> r) =>
            !r.hasException && r.data != null)
        .map<SyncEvent>((gql.QueryResult<Object?> r) {
      final Map<String, Object?> watch =
          r.data!['sync_watch'] as Map<String, Object?>;
      final Map<String, Object?> rec =
          watch['record']! as Map<String, Object?>;
      return SyncEventRecordReceived(
        at: DateTime.now().toUtc(),
        record: SyncRecord.fromJson(rec),
      );
    });
  }

  @override
  Future<void> dispose() async {}
}
