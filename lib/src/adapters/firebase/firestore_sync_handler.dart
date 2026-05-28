// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/sync_event.dart';
import '../../models/sync_record.dart';
import '../sync_adapter.dart';

/// Translates between FlutterSync's [SyncRecord] model and Firestore
/// documents.
///
/// The handler isolates Firestore-specific concerns (snapshots, timestamps,
/// path conventions) from the adapter so that `FirebaseSyncAdapter` stays
/// focused on the high-level push/pull/subscribe contract.
class FirestoreSyncHandler {
  /// Creates a handler bound to [firestore].
  FirestoreSyncHandler(this._firestore);

  final FirebaseFirestore _firestore;

  /// Returns the collection reference for [collection].
  CollectionReference<Map<String, Object?>> collectionRef(String collection) =>
      _firestore.collection(collection);

  /// Converts [record] into a Firestore-ready map.
  Map<String, Object?> recordToMap(SyncRecord record) => <String, Object?>{
        'id': record.id,
        ...record.payload,
        'hlc': record.hlc,
        'created_at': Timestamp.fromDate(record.createdAt.toUtc()),
        'updated_at': Timestamp.fromDate(record.updatedAt.toUtc()),
        'is_deleted': record.isDeleted,
      };

  /// Converts a Firestore document snapshot into a [SyncRecord].
  SyncRecord docToRecord(
    String collection,
    DocumentSnapshot<Map<String, Object?>> snapshot,
  ) {
    final Map<String, Object?> data = snapshot.data() ?? <String, Object?>{};
    return SyncRecord(
      id: snapshot.id,
      collection: collection,
      payload: data,
      hlc: data['hlc']?.toString() ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ??
          DateTime.now().toUtc(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ??
          DateTime.now().toUtc(),
      isDeleted: (data['is_deleted'] as bool?) ?? false,
    );
  }

  /// Returns a stream of [SyncEvent]s for [subscription].
  Stream<SyncEvent> watch(SyncSubscription subscription) {
    Query<Map<String, Object?>> query = collectionRef(subscription.collection);
    if (subscription.since != null) {
      query = query.where('hlc', isGreaterThan: subscription.since);
    }
    return query
        .snapshots()
        .expand<SyncEvent>((QuerySnapshot<Map<String, Object?>> snap) {
      final List<SyncEvent> events = <SyncEvent>[];
      for (final DocumentChange<Map<String, Object?>> change in snap.docChanges) {
        events.add(
          SyncEventRecordReceived(
            at: DateTime.now().toUtc(),
            record: docToRecord(subscription.collection, change.doc),
          ),
        );
      }
      return events;
    });
  }
}
