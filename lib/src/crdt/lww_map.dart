// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

import '../core/hlc/hlc_timestamp.dart';

/// Per-key tracking record used internally by [LWWMap].
@immutable
class LWWMapEntry<V> {
  /// Creates a tracking record.
  const LWWMapEntry({
    required this.value,
    required this.ts,
    this.isDeleted = false,
  });

  /// Current value of the key; meaningful only when [isDeleted] is `false`.
  final V? value;

  /// HLC timestamp of the most recent write or delete.
  final HLCTimestamp ts;

  /// `true` when the key has been logically deleted.
  final bool isDeleted;

  /// Returns the merge of this record with [other].
  LWWMapEntry<V> merge(LWWMapEntry<V> other) {
    if (other.ts > ts) {
      return other;
    }
    if (ts > other.ts) {
      return this;
    }
    // Same HLC. Prefer the tombstone deterministically.
    return isDeleted ? this : other;
  }

  @override
  String toString() =>
      'LWWMapEntry(value: $value, ts: $ts, isDeleted: $isDeleted)';
}

/// Last-Write-Wins Map Conflict-free Replicated Data Type.
///
/// An [LWWMap] is a key/value store whose entries each carry an
/// [HLCTimestamp]; on merge, each key keeps the value with the highest
/// timestamp. Deletes are represented as tombstoned entries so that
/// deletions propagate correctly even when peers were offline at the
/// moment of the delete.
@immutable
class LWWMap<K, V> {
  /// Creates a map with the supplied initial [entries].
  LWWMap([Map<K, LWWMapEntry<V>>? entries])
      : _entries = Map<K, LWWMapEntry<V>>.unmodifiable(
          entries ?? <K, LWWMapEntry<V>>{},
        );

  /// Per-key tracking records (including tombstones).
  final Map<K, LWWMapEntry<V>> _entries;

  /// Returns the immutable per-key tracking records.
  Map<K, LWWMapEntry<V>> get entries => _entries;

  /// Returns the observable key/value view, excluding tombstones.
  Map<K, V> get value => <K, V>{
        for (final MapEntry<K, LWWMapEntry<V>> e in _entries.entries)
          if (!e.value.isDeleted) e.key: e.value.value as V,
      };

  /// Returns the value associated with [key], or `null` when the key is
  /// absent or tombstoned.
  V? get(K key) {
    final LWWMapEntry<V>? entry = _entries[key];
    if (entry == null || entry.isDeleted) {
      return null;
    }
    return entry.value;
  }

  /// Returns `true` when [key] currently holds a non-tombstone value.
  bool containsKey(K key) {
    final LWWMapEntry<V>? entry = _entries[key];
    return entry != null && !entry.isDeleted;
  }

  /// Returns a new map with `[key] = value` at [ts].
  LWWMap<K, V> set(K key, V value, HLCTimestamp ts) {
    final LWWMapEntry<V>? existing = _entries[key];
    if (existing != null && existing.ts > ts) {
      return this;
    }
    return LWWMap<K, V>(<K, LWWMapEntry<V>>{
      ..._entries,
      key: LWWMapEntry<V>(value: value, ts: ts),
    });
  }

  /// Returns a new map with [key] removed at [ts].
  LWWMap<K, V> delete(K key, HLCTimestamp ts) {
    final LWWMapEntry<V>? existing = _entries[key];
    if (existing != null && existing.ts > ts) {
      return this;
    }
    return LWWMap<K, V>(<K, LWWMapEntry<V>>{
      ..._entries,
      key: LWWMapEntry<V>(value: null, ts: ts, isDeleted: true),
    });
  }

  /// Returns the merge of this map with [other].
  LWWMap<K, V> merge(LWWMap<K, V> other) {
    final Map<K, LWWMapEntry<V>> next =
        Map<K, LWWMapEntry<V>>.from(_entries);
    other._entries.forEach((K key, LWWMapEntry<V> entry) {
      final LWWMapEntry<V>? mine = next[key];
      next[key] = mine == null ? entry : mine.merge(entry);
    });
    return LWWMap<K, V>(next);
  }

  /// Serializes the map to a JSON-compatible representation.
  Map<String, Object?> toJson({
    required Object? Function(K) encodeKey,
    required Object? Function(V) encodeValue,
  }) =>
      <String, Object?>{
        'type': 'lww_map',
        'entries': <Map<String, Object?>>[
          for (final MapEntry<K, LWWMapEntry<V>> e in _entries.entries)
            <String, Object?>{
              'key': encodeKey(e.key),
              if (!e.value.isDeleted) 'value': encodeValue(e.value.value as V),
              'ts': e.value.ts.toWire(),
              'isDeleted': e.value.isDeleted,
            },
        ],
      };

  /// Reconstructs a map from a JSON-compatible representation.
  factory LWWMap.fromJson(
    Map<String, Object?> json, {
    required K Function(Object?) decodeKey,
    required V Function(Object?) decodeValue,
  }) {
    final List<Object?> raw = json['entries']! as List<Object?>;
    final Map<K, LWWMapEntry<V>> entries = <K, LWWMapEntry<V>>{};
    for (final Object? rawEntry in raw) {
      final Map<String, Object?> map =
          Map<String, Object?>.from(rawEntry! as Map<Object?, Object?>);
      final K key = decodeKey(map['key']);
      final bool isDeleted = (map['isDeleted'] as bool?) ?? false;
      final V? value = isDeleted ? null : decodeValue(map['value']);
      final HLCTimestamp ts = HLCTimestamp.parse(map['ts']! as String);
      entries[key] =
          LWWMapEntry<V>(value: value, ts: ts, isDeleted: isDeleted);
    }
    return LWWMap<K, V>(entries);
  }

  @override
  String toString() =>
      'LWWMap(entries: ${_entries.length}, live: ${value.length})';
}
