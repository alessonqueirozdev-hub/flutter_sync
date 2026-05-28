// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import 'package:meta/meta.dart';

/// Strategy used by [RestSyncAdapter] to attach authentication credentials
/// to outgoing requests.
abstract interface class RestAuthStrategy {
  /// Returns the headers that must be attached to every request.
  ///
  /// Implementations may refresh tokens or call out to an auth provider;
  /// the returned map is merged with [RestSyncConfig.defaultHeaders].
  Future<Map<String, String>> authHeaders();
}

/// Static bearer-token authentication.
@immutable
class BearerTokenAuth implements RestAuthStrategy {
  /// Creates a bearer-token strategy.
  const BearerTokenAuth(this.token);

  /// Static token attached to every request as `Authorization: Bearer ...`.
  final String token;

  @override
  Future<Map<String, String>> authHeaders() async =>
      <String, String>{'Authorization': 'Bearer $token'};
}

/// Dynamic-token strategy that re-fetches the token from a callback when
/// it is missing or expired.
class CallbackBearerAuth implements RestAuthStrategy {
  /// Creates a callback-based bearer-token strategy.
  CallbackBearerAuth(this.fetchToken);

  /// Callback invoked to obtain a fresh token.
  final Future<String> Function() fetchToken;

  String? _cached;
  DateTime? _cachedAt;

  /// How long [authHeaders] re-uses a cached token before re-fetching.
  static const Duration cacheTtl = Duration(minutes: 15);

  @override
  Future<Map<String, String>> authHeaders() async {
    final DateTime? at = _cachedAt;
    if (_cached == null ||
        at == null ||
        DateTime.now().toUtc().difference(at) > cacheTtl) {
      _cached = await fetchToken();
      _cachedAt = DateTime.now().toUtc();
    }
    return <String, String>{'Authorization': 'Bearer ${_cached!}'};
  }
}

/// Static API-key authentication that places the key in a custom header.
@immutable
class ApiKeyAuth implements RestAuthStrategy {
  /// Creates an API-key strategy.
  const ApiKeyAuth({required this.headerName, required this.apiKey});

  /// Header name (e.g. `X-API-Key`).
  final String headerName;

  /// API key value.
  final String apiKey;

  @override
  Future<Map<String, String>> authHeaders() async =>
      <String, String>{headerName: apiKey};
}

/// Configuration for [RestSyncAdapter].
///
/// The adapter assumes a REST contract where each collection is hosted at
/// `{baseUrl}/{collection}` and supports:
///
/// - `GET /{collection}?since={hlc}&limit={n}&cursor={token}` for pulls.
/// - `POST /{collection}` with a JSON body of `{ "records": [ ... ] }`
///   for pushes; the response body is expected to be a `SyncPushResult`
///   JSON envelope.
///
/// Hosts that diverge from this contract should subclass [RestSyncAdapter]
/// and override the request-building hooks.
@immutable
class RestSyncConfig {
  /// Creates a REST adapter configuration.
  const RestSyncConfig({
    required this.baseUrl,
    this.auth,
    this.defaultHeaders = const <String, String>{},
    this.requestTimeout = const Duration(seconds: 30),
  });

  /// Root URL of the REST API (no trailing slash).
  final String baseUrl;

  /// Optional authentication strategy.
  final RestAuthStrategy? auth;

  /// Headers attached to every request, merged with [RestAuthStrategy]
  /// headers (auth wins on conflict).
  final Map<String, String> defaultHeaders;

  /// Maximum time the adapter will wait for any single request to complete.
  final Duration requestTimeout;
}
