// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/sync_batch.dart';
import '../../models/sync_event.dart';
import '../../models/sync_pull_request.dart';
import '../../models/sync_pull_result.dart';
import '../../models/sync_push_result.dart';
import '../../models/sync_record.dart';
import '../sync_adapter.dart';
import 'rest_sync_config.dart';

/// FlutterSync adapter targeting a generic REST/JSON backend.
///
/// The adapter performs:
///
/// - `GET {baseUrl}/{collection}?since={hlc}&limit={n}&cursor={token}` for
///   pulls. The response is expected to be a JSON object of the shape
///   `{ "records": [...], "next_cursor": "...?", "has_more": bool }`.
/// - `POST {baseUrl}/{collection}` with body
///   `{ "records": [...], "idempotency_keys": [...] }` for pushes. The
///   response is expected to be a JSON object of the shape
///   `{ "pushed": int, "rejected_ids": [...] }`.
///
/// The adapter is intentionally schema-tolerant: missing fields fall back
/// to reasonable defaults so a partially-conforming server still works.
class RestSyncAdapter implements SyncAdapter {
  /// Creates a REST adapter.
  RestSyncAdapter({
    required this.config,
    http.Client? client,
    SyncAdapterCapabilities? capabilities,
  })  : _client = client ?? http.Client(),
        capabilities = capabilities ??
            const SyncAdapterCapabilities(
              realtime: false,
              serverSideFilters: true,
              partialSync: true,
              idempotentPush: true,
              deltaPull: true,
              maxBatchSize: 200,
            );

  /// Effective configuration.
  final RestSyncConfig config;
  final http.Client _client;

  @override
  final SyncAdapterCapabilities capabilities;

  @override
  Future<void> initialize() async {}

  Future<Map<String, String>> _headers() async {
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...config.defaultHeaders,
    };
    if (config.auth != null) {
      headers.addAll(await config.auth!.authHeaders());
    }
    return headers;
  }

  @override
  Future<SyncPushResult> push(SyncBatch batch) async {
    if (batch.isEmpty) {
      return const SyncPushResult.success(pushedCount: 0);
    }
    final Uri uri = Uri.parse('${config.baseUrl}/${batch.collection}');
    final String body = jsonEncode(<String, Object?>{
      'records': <Map<String, Object?>>[
        for (final SyncRecord r in batch.entries) r.toJson(),
      ],
    });
    try {
      final http.Response response = await _client
          .post(uri, headers: await _headers(), body: body)
          .timeout(config.requestTimeout);
      if (response.statusCode >= 500 || response.statusCode == 429) {
        return SyncPushResult.retry(
          reason: 'HTTP ${response.statusCode}',
          retryAfter: _retryAfter(response),
        );
      }
      if (response.statusCode >= 400) {
        return SyncPushResult.failure(
          reason: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }
      final Map<String, Object?> parsed =
          jsonDecode(response.body) as Map<String, Object?>;
      final int pushed =
          (parsed['pushed'] as num?)?.toInt() ?? batch.size;
      final List<String> rejected = <String>[
        for (final Object? r in (parsed['rejected_ids'] as List<Object?>? ?? const <Object?>[]))
          r.toString(),
      ];
      if (rejected.isNotEmpty) {
        return SyncPushResult.partial(
          pushedCount: pushed,
          rejectedIds: rejected,
        );
      }
      return SyncPushResult.success(pushedCount: pushed);
    } on TimeoutException {
      return const SyncPushResult.retry(reason: 'request timed out');
    } catch (e) {
      return SyncPushResult.retry(reason: 'transport error: $e');
    }
  }

  @override
  Future<SyncPullResult> pull(SyncPullRequest request) async {
    final Map<String, String> query = <String, String>{
      'limit': request.pageSize.toString(),
      if (request.since != null) 'since': request.since!,
      if (request.cursor != null) 'cursor': request.cursor!,
      if (request.includeDeleted) 'include_deleted': 'true',
    };
    final Uri uri = Uri.parse('${config.baseUrl}/${request.collection}')
        .replace(queryParameters: query);
    try {
      final http.Response response = await _client
          .get(uri, headers: await _headers())
          .timeout(config.requestTimeout);
      if (response.statusCode >= 500 || response.statusCode == 429) {
        return SyncPullResult.retry(
          reason: 'HTTP ${response.statusCode}',
          retryAfter: _retryAfter(response),
        );
      }
      if (response.statusCode >= 400) {
        return SyncPullResult.failure(
          reason: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }
      final Map<String, Object?> parsed =
          jsonDecode(response.body) as Map<String, Object?>;
      final List<Object?> raw =
          parsed['records'] as List<Object?>? ?? const <Object?>[];
      final List<SyncRecord> records = <SyncRecord>[
        for (final Object? r in raw)
          SyncRecord.fromJson(
            Map<String, Object?>.from(r! as Map<Object?, Object?>),
          ),
      ];
      return SyncPullResult.success(
        records: records,
        highWaterHlc: parsed['high_water_hlc'] as String?,
        hasMore: (parsed['has_more'] as bool?) ?? false,
      );
    } on TimeoutException {
      return const SyncPullResult.retry(reason: 'request timed out');
    } catch (e) {
      return SyncPullResult.retry(reason: 'transport error: $e');
    }
  }

  Duration? _retryAfter(http.Response response) {
    final String? value = response.headers['retry-after'];
    if (value == null) {
      return null;
    }
    final int? seconds = int.tryParse(value);
    return seconds == null ? null : Duration(seconds: seconds);
  }

  @override
  Stream<SyncEvent> subscribe(SyncSubscription subscription) {
    return const Stream<SyncEvent>.empty();
  }

  @override
  Future<void> dispose() async {
    _client.close();
  }
}
