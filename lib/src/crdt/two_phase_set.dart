// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

/// Two-Phase Set Conflict-free Replicated Data Type.
///
/// A [TwoPhaseSet] is the simplest CRDT supporting both add and remove. It
/// maintains two grow-only sets internally: [added] and [removed]. An
/// element is considered to be in the set iff it has been added and has
/// not been removed.
///
/// **Limitation:** an element that has been removed once cannot be
/// re-added — the removal is permanent. When re-add semantics are
/// required, use `LWWSet<T>` instead.
///
/// Properties:
///
/// - **Commutativity / associativity / idempotency** — merge is the union
///   of both [added] and [removed] independently.
@immutable
class TwoPhaseSet<T> {
  /// Creates a set with the supplied initial [added] and [removed] members.
  TwoPhaseSet({Set<T>? added, Set<T>? removed})
      : added = Set<T>.unmodifiable(added ?? const <Never>{}),
        removed = Set<T>.unmodifiable(removed ?? const <Never>{});

  /// Elements that have ever been added.
  final Set<T> added;

  /// Elements that have ever been removed.
  final Set<T> removed;

  /// Computes and returns the observable membership set.
  Set<T> get value => added.difference(removed);

  /// Returns `true` when [element] is currently a member of the set.
  bool contains(T element) =>
      added.contains(element) && !removed.contains(element);

  /// Returns a new set with [element] added.
  TwoPhaseSet<T> add(T element) {
    if (added.contains(element)) {
      return this;
    }
    return TwoPhaseSet<T>(
      added: <T>{...added, element},
      removed: removed,
    );
  }

  /// Returns a new set with [element] removed. The element must currently
  /// be a member; removing an element that has never been added is a no-op
  /// to keep the operation idempotent and commutative.
  TwoPhaseSet<T> remove(T element) {
    if (!added.contains(element) || removed.contains(element)) {
      return this;
    }
    return TwoPhaseSet<T>(
      added: added,
      removed: <T>{...removed, element},
    );
  }

  /// Returns the merge of this set with [other].
  TwoPhaseSet<T> merge(TwoPhaseSet<T> other) => TwoPhaseSet<T>(
        added: <T>{...added, ...other.added},
        removed: <T>{...removed, ...other.removed},
      );

  /// Serializes the set to a JSON-compatible map. The element type [T] must
  /// be JSON-encodable; complex element types should be encoded as strings
  /// or maps before being added to the set.
  Map<String, Object?> toJson() => <String, Object?>{
        'type': 'two_phase_set',
        'added': added.toList(),
        'removed': removed.toList(),
      };

  /// Reconstructs a set from a JSON-compatible map.
  factory TwoPhaseSet.fromJson(
    Map<String, Object?> json, {
    required T Function(Object?) decode,
  }) =>
      TwoPhaseSet<T>(
        added: <T>{
          for (final Object? raw in (json['added']! as List<Object?>))
            decode(raw),
        },
        removed: <T>{
          for (final Object? raw in (json['removed']! as List<Object?>))
            decode(raw),
        },
      );

  @override
  bool operator ==(Object other) {
    if (other is! TwoPhaseSet<T>) {
      return false;
    }
    if (other.added.length != added.length ||
        other.removed.length != removed.length) {
      return false;
    }
    for (final T element in added) {
      if (!other.added.contains(element)) {
        return false;
      }
    }
    for (final T element in removed) {
      if (!other.removed.contains(element)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(added),
        Object.hashAllUnordered(removed),
      );

  @override
  String toString() =>
      'TwoPhaseSet(added: ${added.length}, removed: ${removed.length}, '
      'live: ${value.length})';
}
