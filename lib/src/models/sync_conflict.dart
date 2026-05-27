// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

import 'sync_record.dart';

/// A detected disagreement between two versions of the same record.
///
/// A [SyncConflict] is produced when both the local store and the backend
/// have observed independent modifications to the same `(collection, id)`
/// since the last successful sync. The conflict is routed through the
/// active `ConflictResolver`, which returns the winning [SyncRecord].
@immutable
class SyncConflict {
  /// Creates an immutable conflict descriptor.
  const SyncConflict({
    required this.local,
    required this.remote,
    required this.detectedAt,
    this.basis,
  });

  /// The local version of the record at the moment the conflict was detected.
  final SyncRecord local;

  /// The remote version of the record that triggered the conflict.
  final SyncRecord remote;

  /// Wall-clock instant at which the conflict was detected.
  final DateTime detectedAt;

  /// Optional common ancestor, when known (typically the last record both
  /// sides agreed on). Required for three-way merges; resolvers that do
  /// not need it may ignore the field.
  final SyncRecord? basis;

  /// Logical collection of the conflicting record. The local and remote
  /// versions are guaranteed to share this value.
  String get collection => local.collection;

  /// Stable identifier of the conflicting record. The local and remote
  /// versions are guaranteed to share this value.
  String get id => local.id;

  /// Returns a copy of this conflict with the supplied fields replaced.
  SyncConflict copyWith({
    SyncRecord? local,
    SyncRecord? remote,
    DateTime? detectedAt,
    SyncRecord? basis,
  }) {
    return SyncConflict(
      local: local ?? this.local,
      remote: remote ?? this.remote,
      detectedAt: detectedAt ?? this.detectedAt,
      basis: basis ?? this.basis,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SyncConflict &&
      other.local == local &&
      other.remote == remote &&
      other.detectedAt == detectedAt &&
      other.basis == basis;

  @override
  int get hashCode => Object.hash(local, remote, detectedAt, basis);

  @override
  String toString() =>
      'SyncConflict($collection/$id, detectedAt: $detectedAt)';
}
