// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

/// Strategy that resolves the GraphQL document strings (queries,
/// mutations, subscriptions) the adapter sends to the server.
///
/// The default implementation interpolates the collection name into a set
/// of conventional documents; consumers can subclass to point at custom
/// operations defined on their schema.
class GraphQLDocumentFactory {
  /// Const constructor — the default factory is stateless.
  const GraphQLDocumentFactory();

  /// Pull-time query document. Expected variables: `$collection`,
  /// `$since`, `$limit`, `$cursor`.
  String pullQuery(String collection) => '''
    query SyncPull(
      \$collection: String!,
      \$since: String,
      \$limit: Int!,
      \$cursor: String,
    ) {
      sync_pull(
        collection: \$collection,
        since: \$since,
        limit: \$limit,
        cursor: \$cursor,
      ) {
        records {
          id
          collection
          payload
          hlc
          created_at
          updated_at
          is_deleted
        }
        high_water_hlc
        has_more
        next_cursor
      }
    }
  ''';

  /// Push-time mutation. Expected variables: `$collection`, `$records`,
  /// `$idempotency_keys`.
  String pushMutation(String collection) => '''
    mutation SyncPush(
      \$collection: String!,
      \$records: [SyncRecordInput!]!,
    ) {
      sync_push(collection: \$collection, records: \$records) {
        pushed
        rejected_ids
      }
    }
  ''';

  /// Subscription invoked by [SyncAdapter.subscribe]. Expected variables:
  /// `$collection`, `$since`.
  String subscribeDocument(String collection) => '''
    subscription SyncWatch(\$collection: String!, \$since: String) {
      sync_watch(collection: \$collection, since: \$since) {
        record {
          id
          collection
          payload
          hlc
          created_at
          updated_at
          is_deleted
        }
      }
    }
  ''';
}

/// Configuration for the GraphQL adapter.
@immutable
class GraphQLSyncConfig {
  /// Creates a GraphQL adapter configuration.
  const GraphQLSyncConfig({
    required this.endpoint,
    this.subscriptionEndpoint,
    this.headers = const <String, String>{},
    this.documentFactory = const GraphQLDocumentFactory(),
  });

  /// HTTP/HTTPS endpoint for queries and mutations.
  final String endpoint;

  /// Optional WebSocket endpoint for subscriptions.
  ///
  /// When `null`, [subscribe] returns an empty stream and the engine falls
  /// back to scheduled pulls.
  final String? subscriptionEndpoint;

  /// Static headers attached to every operation.
  final Map<String, String> headers;

  /// Strategy producing the operation strings.
  final GraphQLDocumentFactory documentFactory;
}
