// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/sync_batch.dart';
import '../../models/sync_event.dart';
import '../../models/sync_pull_request.dart';
import '../../models/sync_pull_result.dart';
import '../../models/sync_push_result.dart';
import '../../models/sync_record.dart';
import '../sync_adapter.dart';
import 'firestore_sync_handler.dart';

/// FlutterSync adapter targeting Firebase Firestore.
///
/// Each FlutterSync collection maps to a Firestore top-level collection of
/// the same name. Records are stored as documents whose `id` matches
/// [SyncRecord.id]. The `hlc` field is used for delta pulls and ordering.
class FirebaseSyncAdapter implements SyncAdapter {
  /// Creates a Firebase adapter.
  FirebaseSyncAdapter({
    required FirebaseFirestore firestore,
    SyncAdapterCapabilities? capabilities,
  })  : _firestore = firestore,
        _handler = FirestoreSyncHandler(firestore),
        capabilities = capabilities ??
            const SyncAdapterCapabilities(
              realtime: true,
              serverSideFilters: true,
              partialSync: true,
              idempotentPush: true,
              deltaPull: true,
              maxBatchSize: 500,
            );

  final FirebaseFirestore _firestore;
  final FirestoreSyncHandler _handler;

  @override
  final SyncAdapterCapabilities capabilities;

  @override
  Future<void> initialize() async {}

  @override
  Future<SyncPushResult> push(SyncBatch batch) async {
    if (batch.isEmpty) {
      return const SyncPushResult.success(pushedCount: 0);
    }
    try {
      final WriteBatch writeBatch = _firestore.batch();
      for (final SyncRecord record in batch.entries) {
        final DocumentReference<Map<String, Object?>> doc = _handler
            .collectionRef(batch.collection)
            .doc(record.id);
        writeBatch.set(doc, _handler.recordToMap(record));
      }
      await writeBatch.commit();
      return SyncPushResult.success(pushedCount: batch.size);
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return SyncPushResult.retry(reason: e.message ?? e.code);
      }
      return SyncPushResult.failure(reason: e.message ?? e.code, cause: e);
    } catch (e) {
      return SyncPushResult.retry(reason: 'unexpected error: $e');
    }
  }

  @override
  Future<SyncPullResult> pull(SyncPullRequest request) async {
    try {
      Query<Map<String, Object?>> query =
          _handler.collectionRef(request.collection);
      if (request.since != null) {
        query = query.where('hlc', isGreaterThan: request.since);
      }
      query = query.orderBy('hlc').limit(request.pageSize);
      final QuerySnapshot<Map<String, Object?>> snap = await query.get();
      final List<SyncRecord> records = snap.docs
          .map((DocumentSnapshot<Map<String, Object?>> doc) =>
              _handler.docToRecord(request.collection, doc))
          .toList();
      return SyncPullResult.success(
        records: records,
        hasMore: records.length >= request.pageSize,
        highWaterHlc: records.isEmpty ? null : records.last.hlc,
      );
    } on FirebaseException catch (e) {
      return SyncPullResult.failure(reason: e.message ?? e.code, cause: e);
    } catch (e) {
      return SyncPullResult.retry(reason: 'unexpected error: $e');
    }
  }

  @override
  Stream<SyncEvent> subscribe(SyncSubscription subscription) =>
      _handler.watch(subscription);

  @override
  Future<void> dispose() async {}
}
