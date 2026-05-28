// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/sync_event.dart';
import '../../models/sync_record.dart';
import '../sync_adapter.dart';

/// Builds a [Stream] of [SyncEvent]s from a Supabase Realtime channel.
///
/// One handler instance is created per [SyncSubscription]; the channel is
/// torn down when the returned stream loses its last subscriber.
class SupabaseRealtimeHandler {
  /// Creates a handler bound to [client].
  SupabaseRealtimeHandler(this._client);

  final SupabaseClient _client;

  /// Returns a broadcast stream of events scoped to [subscription].
  Stream<SyncEvent> watch(SyncSubscription subscription) {
    final StreamController<SyncEvent> controller =
        StreamController<SyncEvent>.broadcast();
    final RealtimeChannel channel =
        _client.channel('flutter_sync:${subscription.collection}');

    PostgresChangeFilter? filter;
    if (subscription.since != null) {
      filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.gt,
        column: 'updated_at',
        value: subscription.since!,
      );
    }

    void emit(PostgresChangePayload payload) {
      final Map<String, dynamic> row = payload.newRecord;
      if (row.isEmpty) {
        return;
      }
      final SyncRecord record = SyncRecord(
        id: row['id']!.toString(),
        collection: subscription.collection,
        payload: Map<String, Object?>.from(row),
        hlc: row['hlc']?.toString() ?? '',
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now().toUtc(),
        updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
            DateTime.now().toUtc(),
        isDeleted: payload.eventType == PostgresChangeEvent.delete,
      );
      controller.add(
        SyncEventRecordReceived(
          at: DateTime.now().toUtc(),
          record: record,
        ),
      );
    }

    channel
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: subscription.collection,
        filter: filter,
        callback: emit,
      )
      ..subscribe();

    controller.onCancel = () async {
      await _client.removeChannel(channel);
      await controller.close();
    };
    return controller.stream;
  }
}
