// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

import 'sync_filter.dart';

/// Parameters passed to `SyncAdapter.pull` to retrieve records changed since
/// the last successful sync.
///
/// The contract is incremental ("delta sync"): the server returns only the
/// records whose HLC timestamp is strictly greater than [since]. When [since]
/// is `null`, the server performs a full initial pull (subject to [filter]
/// and [pageSize]).
@immutable
class SyncPullRequest {
  /// Creates an immutable pull request.
  const SyncPullRequest({
    required this.collection,
    this.since,
    this.filter,
    this.pageSize = 100,
    this.cursor,
    this.includeDeleted = true,
  });

  /// Logical collection to pull.
  final String collection;

  /// HLC wire-format watermark; the server returns only records with HLC
  /// strictly greater than this value. `null` requests a full initial pull.
  final String? since;

  /// Optional server-side filter restricting which records are returned.
  final SyncFilter? filter;

  /// Maximum number of records the server should return in this page.
  /// Adapters may cap or honor this value depending on their semantics.
  final int pageSize;

  /// Optional opaque pagination cursor returned by the previous pull when
  /// `SyncPullResultSuccess.hasMore` was `true`.
  final String? cursor;

  /// When `true`, tombstoned records are included in the response so that
  /// deletes can be applied locally. Defaults to `true`.
  final bool includeDeleted;

  /// Returns a copy of this request with the supplied fields replaced.
  SyncPullRequest copyWith({
    String? collection,
    String? since,
    SyncFilter? filter,
    int? pageSize,
    String? cursor,
    bool? includeDeleted,
  }) {
    return SyncPullRequest(
      collection: collection ?? this.collection,
      since: since ?? this.since,
      filter: filter ?? this.filter,
      pageSize: pageSize ?? this.pageSize,
      cursor: cursor ?? this.cursor,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  String toString() => 'SyncPullRequest(collection: $collection, '
      'since: $since, pageSize: $pageSize, '
      'cursor: $cursor, includeDeleted: $includeDeleted)';
}
