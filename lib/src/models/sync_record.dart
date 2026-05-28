// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Immutable representation of a single synchronizable record.
///
/// A [SyncRecord] is the atomic unit moved across the wire between
/// `SyncStore`, the outbox, and the backend `SyncAdapter`. Every record
/// belongs to a logical [collection], carries an opaque [payload], and is
/// versioned by a Hybrid Logical Clock timestamp stored as the [hlc] string
/// in its canonical wire format (`{physicalMs}-{counter}-{nodeId}`,
/// zero-padded so it sorts lexicographically).
///
/// The class is intentionally backend-agnostic. Adapters are responsible
/// for translating between [SyncRecord] and their own data representation.
@immutable
class SyncRecord {
  /// Creates a new immutable [SyncRecord].
  ///
  /// The [id] is the stable identifier of the record within [collection]
  /// (typically a UUID v4). The [payload] is treated as opaque structured
  /// data and must be JSON-serializable. The [hlc] is the Hybrid Logical
  /// Clock wire-format string emitted by `HLCClock.tick()` or
  /// `HLCClock.receive()`. Tombstones are represented by setting
  /// [isDeleted] to `true`; the [payload] of a tombstone is typically
  /// empty but is preserved for adapters that need it.
  const SyncRecord({
    required this.id,
    required this.collection,
    required this.payload,
    required this.hlc,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  /// Reconstructs a [SyncRecord] from a JSON-compatible map.
  factory SyncRecord.fromJson(Map<String, Object?> json) {
    final dynamic rawPayload = json['payload'];
    final Map<String, Object?> payload = rawPayload is Map
        ? Map<String, Object?>.from(rawPayload as Map<Object?, Object?>)
        : const <String, Object?>{};
    return SyncRecord(
      id: json['id']! as String,
      collection: json['collection']! as String,
      payload: payload,
      hlc: json['hlc']! as String,
      createdAt: DateTime.parse(json['created_at']! as String),
      updatedAt: DateTime.parse(json['updated_at']! as String),
      isDeleted: (json['is_deleted'] as bool?) ?? false,
    );
  }

  /// Stable, opaque identifier of the record within [collection].
  final String id;

  /// Logical collection name (e.g. `'todos'`, `'notes'`).
  final String collection;

  /// Opaque, JSON-serializable structured data carried by the record.
  ///
  /// FlutterSync never inspects the contents of [payload]; it is round-tripped
  /// verbatim between the local store and the backend adapter. The map is
  /// treated as immutable: do not mutate it after passing it to a record.
  final Map<String, Object?> payload;

  /// Hybrid Logical Clock timestamp in wire format.
  ///
  /// The canonical form is `{physicalMs}-{counter}-{nodeId}` with each
  /// segment zero-padded so timestamps compare correctly as plain strings.
  /// See `HLCTimestamp.parse` and `HLCTimestamp.format` (added in Phase 2)
  /// for typed access.
  final String hlc;

  /// Wall-clock instant at which the record was first created locally.
  final DateTime createdAt;

  /// Wall-clock instant at which the record was last modified locally.
  ///
  /// This is informational only — causality is established by [hlc].
  final DateTime updatedAt;

  /// `true` when the record represents a tombstone (logical delete).
  ///
  /// Tombstones are preserved in the local store and the outbox so that
  /// deletions can be propagated to peers that have not yet observed them.
  final bool isDeleted;

  /// Returns a copy of this record with the supplied fields replaced.
  SyncRecord copyWith({
    String? id,
    String? collection,
    Map<String, Object?>? payload,
    String? hlc,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return SyncRecord(
      id: id ?? this.id,
      collection: collection ?? this.collection,
      payload: payload ?? this.payload,
      hlc: hlc ?? this.hlc,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Serializes the record to a JSON-compatible map.
  ///
  /// The output is suitable for storage in the local store, transmission
  /// to a backend adapter, and round-tripping back through [fromJson].
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'collection': collection,
      'payload': payload,
      'hlc': hlc,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SyncRecord &&
        other.id == id &&
        other.collection == collection &&
        other.hlc == hlc &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.isDeleted == isDeleted &&
        const DeepCollectionEquality().equals(other.payload, payload);
  }

  @override
  int get hashCode => Object.hash(
        id,
        collection,
        hlc,
        createdAt,
        updatedAt,
        isDeleted,
        const DeepCollectionEquality().hash(payload),
      );

  @override
  String toString() =>
      'SyncRecord(id: $id, collection: $collection, hlc: $hlc, '
      'isDeleted: $isDeleted)';
}
