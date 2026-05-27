// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

import '../core/hlc/hlc_timestamp.dart';

/// Per-element add/remove tracking record used internally by [LWWSet].
@immutable
class LWWSetEntry<T> {
  /// Creates a tracking record.
  const LWWSetEntry({
    required this.element,
    required this.addTs,
    this.removeTs,
  });

  /// The element this record describes.
  final T element;

  /// Timestamp at which [element] was added (or last re-added).
  final HLCTimestamp addTs;

  /// Timestamp at which [element] was removed; `null` when [element] is
  /// currently a member of the set.
  final HLCTimestamp? removeTs;

  /// `true` when [element] is currently considered a member.
  bool get isPresent => removeTs == null || addTs > removeTs!;

  /// Returns the merge of this record with [other].
  LWWSetEntry<T> merge(LWWSetEntry<T> other) {
    final HLCTimestamp newAdd = addTs > other.addTs ? addTs : other.addTs;
    final HLCTimestamp? newRemove = switch ((removeTs, other.removeTs)) {
      (null, null) => null,
      (final HLCTimestamp a, null) => a,
      (null, final HLCTimestamp b) => b,
      (final HLCTimestamp a, final HLCTimestamp b) => a > b ? a : b,
    };
    return LWWSetEntry<T>(
      element: element,
      addTs: newAdd,
      removeTs: newRemove,
    );
  }

  @override
  String toString() =>
      'LWWSetEntry($element, addTs: $addTs, removeTs: $removeTs)';
}

/// Last-Write-Wins Set Conflict-free Replicated Data Type.
///
/// Unlike [TwoPhaseSet], an [LWWSet] supports the full add/remove
/// lifecycle: an element that has been removed may be re-added by issuing
/// a new add with a fresher HLC timestamp. Membership is decided per
/// element by comparing the latest `add` and `remove` timestamps.
@immutable
class LWWSet<T> {
  /// Creates a set with the supplied initial [entries].
  LWWSet([Map<T, LWWSetEntry<T>>? entries])
      : _entries = Map<T, LWWSetEntry<T>>.unmodifiable(
          entries ?? <T, LWWSetEntry<T>>{},
        );

  /// Per-element tracking records.
  final Map<T, LWWSetEntry<T>> _entries;

  /// Returns the immutable per-element tracking records.
  Map<T, LWWSetEntry<T>> get entries => _entries;

  /// Returns the observable membership set.
  Set<T> get value => <T>{
        for (final LWWSetEntry<T> entry in _entries.values)
          if (entry.isPresent) entry.element,
      };

  /// Returns `true` when [element] is currently a member.
  bool contains(T element) => _entries[element]?.isPresent ?? false;

  /// Returns a new set with [element] added at [ts].
  LWWSet<T> add(T element, HLCTimestamp ts) {
    final LWWSetEntry<T>? existing = _entries[element];
    final LWWSetEntry<T> next = existing == null
        ? LWWSetEntry<T>(element: element, addTs: ts)
        : LWWSetEntry<T>(
            element: element,
            addTs: ts > existing.addTs ? ts : existing.addTs,
            removeTs: existing.removeTs,
          );
    return LWWSet<T>(<T, LWWSetEntry<T>>{..._entries, element: next});
  }

  /// Returns a new set with [element] removed at [ts].
  LWWSet<T> remove(T element, HLCTimestamp ts) {
    final LWWSetEntry<T>? existing = _entries[element];
    final LWWSetEntry<T> next = existing == null
        ? LWWSetEntry<T>(
            element: element,
            addTs: HLCTimestamp.zero(ts.nodeId),
            removeTs: ts,
          )
        : LWWSetEntry<T>(
            element: element,
            addTs: existing.addTs,
            removeTs: existing.removeTs == null
                ? ts
                : (ts > existing.removeTs! ? ts : existing.removeTs),
          );
    return LWWSet<T>(<T, LWWSetEntry<T>>{..._entries, element: next});
  }

  /// Returns the merge of this set with [other].
  LWWSet<T> merge(LWWSet<T> other) {
    final Map<T, LWWSetEntry<T>> next =
        Map<T, LWWSetEntry<T>>.from(_entries);
    other._entries.forEach((T key, LWWSetEntry<T> entry) {
      final LWWSetEntry<T>? mine = next[key];
      next[key] = mine == null ? entry : mine.merge(entry);
    });
    return LWWSet<T>(next);
  }

  /// Serializes the set to a JSON-compatible map.
  Map<String, Object?> toJson({required Object? Function(T) encode}) =>
      <String, Object?>{
        'type': 'lww_set',
        'entries': <Map<String, Object?>>[
          for (final LWWSetEntry<T> entry in _entries.values)
            <String, Object?>{
              'element': encode(entry.element),
              'addTs': entry.addTs.toWire(),
              if (entry.removeTs != null) 'removeTs': entry.removeTs!.toWire(),
            },
        ],
      };

  /// Reconstructs a set from a JSON-compatible map.
  factory LWWSet.fromJson(
    Map<String, Object?> json, {
    required T Function(Object?) decode,
  }) {
    final List<Object?> raw = json['entries']! as List<Object?>;
    final Map<T, LWWSetEntry<T>> entries = <T, LWWSetEntry<T>>{};
    for (final Object? rawEntry in raw) {
      final Map<String, Object?> map =
          Map<String, Object?>.from(rawEntry! as Map<Object?, Object?>);
      final T element = decode(map['element']);
      final HLCTimestamp addTs = HLCTimestamp.parse(map['addTs']! as String);
      final HLCTimestamp? removeTs = switch (map['removeTs']) {
        final String s => HLCTimestamp.parse(s),
        _ => null,
      };
      entries[element] = LWWSetEntry<T>(
        element: element,
        addTs: addTs,
        removeTs: removeTs,
      );
    }
    return LWWSet<T>(entries);
  }

  @override
  String toString() =>
      'LWWSet(entries: ${_entries.length}, live: ${value.length})';
}
