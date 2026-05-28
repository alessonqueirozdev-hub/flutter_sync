// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/sync_batch.dart';
import '../../models/sync_event.dart';
import '../../models/sync_pull_request.dart';
import '../../models/sync_pull_result.dart';
import '../../models/sync_push_result.dart';
import '../../models/sync_record.dart';
import '../sync_adapter.dart';
import 'supabase_realtime_handler.dart';

/// FlutterSync adapter targeting Supabase (Postgres + Realtime).
///
/// The adapter maps each [SyncRecord] to a row in the Postgres table whose
/// name matches the record's collection. The host application is
/// responsible for creating the table with a `hlc TEXT NOT NULL` column,
/// `updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`, and an
/// `idempotency_key TEXT UNIQUE` column. The `SupabaseRlsHelper` ships
/// ready-to-paste Row-Level-Security policies that scope rows per user or
/// per organization.
class SupabaseSyncAdapter implements SyncAdapter {
  /// Creates a Supabase adapter.
  SupabaseSyncAdapter({
    required SupabaseClient client,
    SyncAdapterCapabilities? capabilities,
  })  : _client = client,
        _realtime = SupabaseRealtimeHandler(client),
        capabilities = capabilities ??
            const SyncAdapterCapabilities(
              realtime: true,
              serverSideFilters: true,
              partialSync: true,
              idempotentPush: true,
              deltaPull: true,
              maxBatchSize: 500,
            );

  final SupabaseClient _client;
  final SupabaseRealtimeHandler _realtime;

  @override
  final SyncAdapterCapabilities capabilities;

  @override
  Future<void> initialize() async {
    // Supabase initialization is performed by the host app; this is a
    // no-op kept here for symmetry with adapters that need warm-up work.
  }

  @override
  Future<SyncPushResult> push(SyncBatch batch) async {
    if (batch.isEmpty) {
      return const SyncPushResult.success(pushedCount: 0);
    }
    try {
      final List<Map<String, Object?>> rows = <Map<String, Object?>>[
        for (final SyncRecord r in batch.entries)
          <String, Object?>{
            'id': r.id,
            ...r.payload,
            'hlc': r.hlc,
            'created_at': r.createdAt.toUtc().toIso8601String(),
            'updated_at': r.updatedAt.toUtc().toIso8601String(),
            'is_deleted': r.isDeleted,
          },
      ];
      await _client
          .from(batch.collection)
          .upsert(rows, onConflict: 'id', ignoreDuplicates: false);
      return SyncPushResult.success(pushedCount: batch.size);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116' || e.message.contains('timeout')) {
        return SyncPushResult.retry(reason: e.message);
      }
      return SyncPushResult.failure(reason: e.message, cause: e);
    } catch (e) {
      return SyncPushResult.retry(reason: 'unexpected error: $e');
    }
  }

  @override
  Future<SyncPullResult> pull(SyncPullRequest request) async {
    try {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query =
          _client.from(request.collection).select();
      if (request.since != null) {
        query = query.gt('hlc', request.since as Object);
      }
      final PostgrestTransformBuilder<List<Map<String, dynamic>>>
          transformed = query.order('hlc').limit(request.pageSize);
      final List<Map<String, dynamic>> rows = await transformed;
      final List<SyncRecord> records = <SyncRecord>[
        for (final Map<String, dynamic> row in rows)
          SyncRecord(
            id: row['id']!.toString(),
            collection: request.collection,
            payload: Map<String, Object?>.from(row),
            hlc: row['hlc']!.toString(),
            createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now().toUtc(),
            updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
                DateTime.now().toUtc(),
            isDeleted: (row['is_deleted'] as bool?) ?? false,
          ),
      ];
      return SyncPullResult.success(
        records: records,
        hasMore: records.length >= request.pageSize,
        highWaterHlc: records.isEmpty ? null : records.last.hlc,
      );
    } on PostgrestException catch (e) {
      return SyncPullResult.failure(reason: e.message, cause: e);
    } catch (e) {
      return SyncPullResult.retry(reason: 'unexpected error: $e');
    }
  }

  @override
  Stream<SyncEvent> subscribe(SyncSubscription subscription) =>
      _realtime.watch(subscription);

  @override
  Future<void> dispose() async {
    await _client.removeAllChannels();
  }
}
