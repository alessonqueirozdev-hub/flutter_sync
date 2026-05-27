// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import '../models/sync_record.dart';
import 'outbox_entry.dart';

/// Event emitted by [OutboxQueue.events] when the queue is mutated.
@immutable
sealed class OutboxQueueEvent {
  /// Internal const constructor for subclasses.
  const OutboxQueueEvent();

  /// The mutated entry.
  OutboxEntry get entry;
}

/// An entry was enqueued.
final class OutboxQueueEventEnqueued extends OutboxQueueEvent {
  /// Creates an enqueued event.
  const OutboxQueueEventEnqueued(this.entry);

  @override
  final OutboxEntry entry;
}

/// An entry's status was updated (claimed, synced, failed, etc.).
final class OutboxQueueEventUpdated extends OutboxQueueEvent {
  /// Creates an updated event.
  const OutboxQueueEventUpdated(this.entry);

  @override
  final OutboxEntry entry;
}

/// An entry was removed from the queue (TTL eviction or explicit purge).
final class OutboxQueueEventRemoved extends OutboxQueueEvent {
  /// Creates a removed event.
  const OutboxQueueEventRemoved(this.entry);

  @override
  final OutboxEntry entry;
}

/// Persistent queue of writes awaiting transmission to the backend.
///
/// The queue is the durability boundary of FlutterSync: a write that has
/// returned success to the caller IS in the queue and WILL be pushed even
/// if the app crashes, the device reboots, or the network is offline for
/// hours.
///
/// This abstract interface is implemented by an in-memory variant
/// (default, used in tests) and a Drift-backed variant introduced in
/// Phase 6.
abstract interface class OutboxQueue {
  /// Adds [record] to the queue with the supplied [operation] and returns
  /// the resulting [OutboxEntry].
  Future<OutboxEntry> enqueue(SyncRecord record, OutboxOperation operation);

  /// Returns all pending entries whose `nextRetryAt` is in the past (or
  /// `null`), ordered by their `createdAt` ascending.
  Future<List<OutboxEntry>> dueEntries({DateTime? now, int limit = 100});

  /// Returns all entries currently in the queue, regardless of status.
  Future<List<OutboxEntry>> allEntries();

  /// Returns the entry whose [OutboxEntry.id] matches [id], or `null`.
  Future<OutboxEntry?> findById(String id);

  /// Replaces the existing entry with [entry] (matched by [OutboxEntry.id]).
  Future<void> update(OutboxEntry entry);

  /// Removes the entry whose [OutboxEntry.id] matches [id].
  Future<void> remove(String id);

  /// Removes every entry from the queue.
  Future<void> clear();

  /// Returns the number of entries currently in the queue.
  Future<int> count();

  /// Broadcast stream of [OutboxQueueEvent]s emitted on every mutation.
  Stream<OutboxQueueEvent> get events;

  /// Closes the queue and releases its resources.
  Future<void> dispose();
}

/// In-memory implementation of [OutboxQueue] used in tests and as the
/// default when no persistent backing is configured.
class InMemoryOutboxQueue implements OutboxQueue {
  /// Creates an in-memory queue.
  InMemoryOutboxQueue({Uuid? uuid})
      : _uuid = uuid ?? const Uuid(),
        _controller = StreamController<OutboxQueueEvent>.broadcast();

  final Uuid _uuid;
  final LinkedHashMap<String, OutboxEntry> _entries =
      LinkedHashMap<String, OutboxEntry>();
  final StreamController<OutboxQueueEvent> _controller;
  bool _disposed = false;

  @override
  Stream<OutboxQueueEvent> get events => _controller.stream;

  @override
  Future<OutboxEntry> enqueue(
    SyncRecord record,
    OutboxOperation operation,
  ) async {
    _assertNotDisposed();
    final OutboxEntry entry = OutboxEntry(
      id: _uuid.v4(),
      record: record,
      operation: operation,
      idempotencyKey: OutboxEntry.computeIdempotencyKey(record),
      status: OutboxStatus.pending,
      attemptCount: 0,
      createdAt: DateTime.now().toUtc(),
    );
    _entries[entry.id] = entry;
    _controller.add(OutboxQueueEventEnqueued(entry));
    return entry;
  }

  @override
  Future<List<OutboxEntry>> dueEntries({DateTime? now, int limit = 100}) async {
    final DateTime threshold = now ?? DateTime.now().toUtc();
    final List<OutboxEntry> due = <OutboxEntry>[];
    for (final OutboxEntry entry in _entries.values) {
      if (entry.status != OutboxStatus.pending) {
        continue;
      }
      if (entry.nextRetryAt != null && entry.nextRetryAt!.isAfter(threshold)) {
        continue;
      }
      due.add(entry);
      if (due.length >= limit) {
        break;
      }
    }
    return due;
  }

  @override
  Future<List<OutboxEntry>> allEntries() async => List<OutboxEntry>.of(_entries.values);

  @override
  Future<OutboxEntry?> findById(String id) async => _entries[id];

  @override
  Future<void> update(OutboxEntry entry) async {
    _assertNotDisposed();
    if (!_entries.containsKey(entry.id)) {
      throw StateError('Cannot update unknown outbox entry: ${entry.id}');
    }
    _entries[entry.id] = entry;
    _controller.add(OutboxQueueEventUpdated(entry));
  }

  @override
  Future<void> remove(String id) async {
    _assertNotDisposed();
    final OutboxEntry? removed = _entries.remove(id);
    if (removed != null) {
      _controller.add(OutboxQueueEventRemoved(removed));
    }
  }

  @override
  Future<void> clear() async {
    _assertNotDisposed();
    final List<OutboxEntry> removed = List<OutboxEntry>.of(_entries.values);
    _entries.clear();
    for (final OutboxEntry entry in removed) {
      _controller.add(OutboxQueueEventRemoved(entry));
    }
  }

  @override
  Future<int> count() async => _entries.length;

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('OutboxQueue has been disposed.');
    }
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
}
