// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import 'package:meta/meta.dart';

import '../adapters/sync_adapter.dart' show SyncAdapter;
import '../audit/audit_entry.dart';
import '../conflict/conflict_resolver.dart';
import '../encryption/encryption_config.dart';
import '../encryption/record_encryptor.dart';
import '../models/sync_filter.dart';
import '../models/sync_query.dart';
import '../models/sync_record.dart';
import '../outbox/outbox_entry.dart';
import '../outbox/outbox_queue.dart';
import '../store/sync_store.dart';
import 'optimistic/optimistic_update_manager.dart';
import 'sync_engine.dart';

/// Contract every model used with [SyncRepository] must satisfy.
abstract interface class SyncModel {
  /// Stable identifier of the model instance (typically a UUID v4).
  String get id;

  /// JSON serialization of the model. The map keys become payload fields
  /// on the wire. Reserved field names (`id`, `collection`, `hlc`,
  /// `created_at`, `updated_at`, `is_deleted`, `_sync_*`) must not be
  /// returned.
  Map<String, dynamic> toJson();
}

/// Bidirectional serializer between [SyncModel] objects and JSON.
@immutable
class SyncModelSerializer<T extends SyncModel> {
  /// Creates a serializer with the supplied [fromJson] and [toJson]
  /// callbacks.
  const SyncModelSerializer({
    required this.fromJson,
    required this.toJson,
  });

  /// Reconstructs a model from a JSON map.
  final T Function(Map<String, dynamic> json) fromJson;

  /// Serializes a model to a JSON map.
  final Map<String, dynamic> Function(T model) toJson;
}

/// Typed CRUD and reactive watch facade for a single collection.
///
/// Repositories are created via `flutterSync.repository<T>(...)` and
/// share the engine's HLC clock, outbox, store, and conflict resolver.
class SyncRepository<T extends SyncModel> {
  /// Creates a repository.
  SyncRepository({
    required this.collection,
    required this.engine,
    required this.serializer,
    this.partialSyncFilter,
    this.collectionEncryption,
    ConflictResolver? conflictResolver,
  })  : _conflictResolver = conflictResolver ?? engine.conflictResolver,
        _optimistic = OptimisticUpdateManager(
          store: engine.store,
          clock: engine.clock,
        );

  /// Logical collection name.
  final String collection;

  /// The engine this repository is bound to.
  final SyncEngine engine;

  /// Serializer for [T].
  final SyncModelSerializer<T> serializer;

  /// Optional server-side filter applied to pulls for this collection.
  final SyncFilter? partialSyncFilter;

  /// Optional per-collection encryption configuration override.
  ///
  /// When non-null, takes precedence over the engine-wide [RecordEncryptor].
  final EncryptionConfig? collectionEncryption;

  // ignore: unused_field
  final ConflictResolver _conflictResolver;
  final OptimisticUpdateManager _optimistic;

  /// Backing store (exposed for advanced cases, e.g. DevTools).
  SyncStore get _store => engine.store;

  /// Backing outbox (exposed for advanced cases).
  OutboxQueue get _outbox => engine.outbox;

  /// Backing adapter for capability introspection.
  SyncAdapter get adapter => engine.adapter;

  /// Persists [model] locally and enqueues a push.
  ///
  /// Returns the persisted model (potentially mutated by the engine to add
  /// engine-managed fields such as `hlc`).
  Future<T> save(T model) async {
    final Map<String, dynamic> payload = serializer.toJson(model);
    SyncRecord record = await _optimistic.applyOptimistic(
      collection: collection,
      id: model.id,
      payload: payload,
    );
    if (engine.encryptor != null) {
      record = await engine.encryptor!.encrypt(record);
    }
    await _outbox.enqueue(record, OutboxOperation.upsert);
    await engine.auditTrail.record(
      AuditEntry(
        occurredAt: DateTime.now().toUtc(),
        collection: collection,
        recordId: model.id,
        operation: AuditOperation.upsert,
        actorNodeId: engine.clock.nodeId,
      ),
    );
    return model;
  }

  /// Marks the record identified by [id] as deleted locally and enqueues
  /// a delete operation for the backend.
  Future<void> delete(String id) async {
    SyncRecord record = await _optimistic.applyOptimistic(
      collection: collection,
      id: id,
      payload: const <String, Object?>{},
      isDelete: true,
    );
    if (engine.encryptor != null) {
      record = await engine.encryptor!.encrypt(record);
    }
    await _outbox.enqueue(record, OutboxOperation.delete);
    await engine.auditTrail.record(
      AuditEntry(
        occurredAt: DateTime.now().toUtc(),
        collection: collection,
        recordId: id,
        operation: AuditOperation.delete,
        actorNodeId: engine.clock.nodeId,
      ),
    );
  }

  /// Reads a single model from the local store.
  Future<T?> findById(String id) async {
    final SyncRecord? record = await _store.findById(collection, id);
    if (record == null || record.isDeleted) {
      return null;
    }
    final SyncRecord decoded = engine.encryptor == null
        ? record
        : await engine.encryptor!.decrypt(record);
    return serializer.fromJson(Map<String, dynamic>.from(decoded.payload));
  }

  /// Returns every model matching [query] from the local store.
  Future<List<T>> findAll([SyncQuery? query]) async {
    final List<SyncRecord> records = await _store.findAll(
      collection,
      query: query,
    );
    return Future.wait<T>(records.map<Future<T>>(_decodeRecord));
  }

  /// Reactive query — emits a fresh list whenever the underlying store
  /// reports a relevant change.
  Stream<List<T>> watch([SyncQuery? query]) async* {
    await for (final _ in _store.watch(collection, query: query)) {
      yield await findAll(query);
    }
  }

  Future<T> _decodeRecord(SyncRecord record) async {
    final SyncRecord decoded = engine.encryptor == null
        ? record
        : await engine.encryptor!.decrypt(record);
    return serializer.fromJson(Map<String, dynamic>.from(decoded.payload));
  }
}
