// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

import 'sync_record.dart';

/// A grouped collection of [SyncRecord]s pushed to the backend in one call.
///
/// Batching is the unit of work for `SyncAdapter.push`. Batches are sized by
/// `BandwidthMonitor` and `SyncSchedulerConfig` so that each push completes
/// within a bounded duration even on weak connections.
@immutable
class SyncBatch {
  /// Creates an immutable [SyncBatch].
  ///
  /// The [id] is a stable identifier (typically a UUID v4) used by the
  /// backend to correlate logs and by the outbox to deduplicate retries.
  /// The [entries] must all share the same [collection]; mixed-collection
  /// batches are forbidden and rejected by the engine.
  SyncBatch({
    required this.id,
    required this.collection,
    required this.entries,
    required this.createdAt,
  }) : assert(
          entries.every((SyncRecord r) => r.collection == collection),
          'All entries in a SyncBatch must share the same collection.',
        );

  /// Stable identifier of the batch.
  final String id;

  /// Collection shared by every entry in the batch.
  final String collection;

  /// Immutable list of records included in the batch.
  final List<SyncRecord> entries;

  /// Wall-clock instant at which the batch was assembled.
  final DateTime createdAt;

  /// Number of entries in the batch.
  int get size => entries.length;

  /// `true` when the batch carries no entries.
  bool get isEmpty => entries.isEmpty;

  /// `true` when the batch carries at least one entry.
  bool get isNotEmpty => entries.isNotEmpty;

  /// Serializes the batch to a JSON-compatible map.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'collection': collection,
        'created_at': createdAt.toUtc().toIso8601String(),
        'entries': entries.map((SyncRecord r) => r.toJson()).toList(),
      };

  /// Reconstructs a [SyncBatch] from a JSON-compatible map.
  factory SyncBatch.fromJson(Map<String, Object?> json) {
    final List<Object?> rawEntries =
        (json['entries']! as List<Object?>);
    final List<SyncRecord> entries = rawEntries
        .map(
          (Object? e) =>
              SyncRecord.fromJson(Map<String, Object?>.from(e! as Map<Object?, Object?>)),
        )
        .toList();
    return SyncBatch(
      id: json['id']! as String,
      collection: json['collection']! as String,
      entries: entries,
      createdAt: DateTime.parse(json['created_at']! as String),
    );
  }

  @override
  String toString() =>
      'SyncBatch(id: $id, collection: $collection, size: $size)';
}
