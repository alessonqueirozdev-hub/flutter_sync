// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';
import 'dart:collection';

import 'package:uuid/uuid.dart';

import '../../models/sync_batch.dart';
import '../../models/sync_record.dart';

/// Groups individual [SyncRecord] writes into [SyncBatch]es ready for
/// `SyncAdapter.push`.
///
/// Batches are emitted when either of two thresholds is crossed:
///
/// - **Size** — once [maxBatchSize] records are queued, the batch is
///   flushed immediately.
/// - **Age** — once the oldest queued record reaches [maxBatchAge], the
///   batch is flushed even if it has not reached the size threshold.
///
/// The processor maintains one queue per collection so that records from
/// different collections are never mixed into a single batch (an invariant
/// of [SyncBatch]).
class BatchProcessor {
  /// Creates a batch processor with size and time thresholds.
  BatchProcessor({
    this.maxBatchSize = 100,
    this.maxBatchAge = const Duration(seconds: 5),
    Uuid? uuid,
  })  : _uuid = uuid ?? const Uuid(),
        _controller = StreamController<SyncBatch>.broadcast();

  /// Maximum number of records allowed in a single emitted batch.
  final int maxBatchSize;

  /// Maximum wall-clock age of the oldest queued record before the batch
  /// is flushed.
  final Duration maxBatchAge;

  final Uuid _uuid;
  final StreamController<SyncBatch> _controller;
  final Map<String, Queue<SyncRecord>> _queues =
      <String, Queue<SyncRecord>>{};
  final Map<String, DateTime> _firstEnqueued = <String, DateTime>{};
  final Map<String, Timer> _ageTimers = <String, Timer>{};
  bool _disposed = false;

  /// Broadcast stream of batches ready to push.
  Stream<SyncBatch> get batches => _controller.stream;

  /// Adds [record] to the appropriate per-collection queue. Triggers a
  /// flush if [maxBatchSize] is reached.
  void add(SyncRecord record) {
    _assertNotDisposed();
    final String collection = record.collection;
    final Queue<SyncRecord> queue =
        _queues.putIfAbsent(collection, Queue<SyncRecord>.new);
    queue.add(record);
    _firstEnqueued.putIfAbsent(
      collection,
      () => DateTime.now().toUtc(),
    );
    _ageTimers.putIfAbsent(
      collection,
      () => Timer(maxBatchAge, () => _flush(collection)),
    );
    if (queue.length >= maxBatchSize) {
      _flush(collection);
    }
  }

  /// Forces an immediate flush of every collection with pending records.
  void flushAll() {
    _assertNotDisposed();
    final List<String> collections = _queues.keys.toList(growable: false);
    for (final String collection in collections) {
      _flush(collection);
    }
  }

  /// Forces an immediate flush of [collection] (or no-op when empty).
  void flushCollection(String collection) {
    _assertNotDisposed();
    _flush(collection);
  }

  void _flush(String collection) {
    final Queue<SyncRecord>? queue = _queues[collection];
    if (queue == null || queue.isEmpty) {
      _cleanupCollection(collection);
      return;
    }
    final List<SyncRecord> entries = List<SyncRecord>.of(queue);
    queue.clear();
    _cleanupCollection(collection);
    final SyncBatch batch = SyncBatch(
      id: _uuid.v4(),
      collection: collection,
      entries: entries,
      createdAt: DateTime.now().toUtc(),
    );
    _controller.add(batch);
  }

  void _cleanupCollection(String collection) {
    _firstEnqueued.remove(collection);
    final Timer? timer = _ageTimers.remove(collection);
    timer?.cancel();
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('BatchProcessor has been disposed.');
    }
  }

  /// Closes the output stream and cancels all internal timers.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final Timer timer in _ageTimers.values) {
      timer.cancel();
    }
    _ageTimers.clear();
    _queues.clear();
    _firstEnqueued.clear();
    await _controller.close();
  }
}
