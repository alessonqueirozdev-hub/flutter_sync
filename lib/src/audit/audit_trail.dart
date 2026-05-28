// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';
import 'dart:collection';

import 'audit_entry.dart';
import 'audit_query.dart';

/// Persistent, queryable audit trail.
///
/// Every meaningful state change in the engine (write, push, pull,
/// conflict resolution, permanent failure) generates an [AuditEntry] that
/// flows through the trail. The default implementation keeps entries
/// in-memory with a bounded ring; the engine's Drift store can plug in a
/// SQLite-backed implementation when persistence across restarts is
/// required.
abstract interface class AuditTrail {
  /// Records [entry].
  Future<void> record(AuditEntry entry);

  /// Returns entries matching [query], most recent first.
  Future<List<AuditEntry>> find(AuditQuery query);

  /// Broadcast stream of every entry as it is recorded.
  Stream<AuditEntry> get stream;

  /// Removes every entry from the trail.
  Future<void> clear();

  /// Releases resources.
  Future<void> dispose();
}

/// In-memory [AuditTrail] backed by a fixed-size circular buffer.
class InMemoryAuditTrail implements AuditTrail {
  /// Creates a trail with the supplied [maxEntries] capacity.
  InMemoryAuditTrail({this.maxEntries = 1000})
      : _controller = StreamController<AuditEntry>.broadcast();

  /// Maximum number of entries retained before older entries are evicted.
  final int maxEntries;

  final Queue<AuditEntry> _entries = Queue<AuditEntry>();
  final StreamController<AuditEntry> _controller;
  bool _disposed = false;

  @override
  Stream<AuditEntry> get stream => _controller.stream;

  @override
  Future<void> record(AuditEntry entry) async {
    _assertNotDisposed();
    _entries.addLast(entry);
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
    _controller.add(entry);
  }

  @override
  Future<List<AuditEntry>> find(AuditQuery query) async {
    final List<AuditEntry> reversed = _entries.toList().reversed.toList();
    final List<AuditEntry> filtered =
        reversed.where(query.matches).toList(growable: false);
    final int offset = query.offset ?? 0;
    final int limit = query.limit ?? filtered.length;
    if (offset >= filtered.length) {
      return const <AuditEntry>[];
    }
    final int end =
        offset + limit > filtered.length ? filtered.length : offset + limit;
    return filtered.sublist(offset, end);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _entries.clear();
    await _controller.close();
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('AuditTrail has been disposed.');
    }
  }
}
