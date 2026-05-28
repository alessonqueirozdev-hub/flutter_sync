// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import '../background_sync.dart';

/// Web implementation of [BackgroundSync].
///
/// True background sync on the web requires a `ServiceWorker` with a
/// `SyncManager` registration. This Dart-side adapter records the desired
/// configuration and exposes hooks the host PWA's service worker invokes
/// when the browser fires a `sync` event.
///
/// See `doc/background_sync.md` for the JavaScript registration snippet
/// that should be added to the host PWA's `web/index.html`.
class WebBackgroundSync implements BackgroundSync {
  /// Creates a web background-sync driver.
  WebBackgroundSync();

  BackgroundSyncCallback? _callback;
  BackgroundSyncConfig? _config;

  /// Last registered configuration; exposed so the service-worker bridge
  /// can read the desired interval and constraints.
  BackgroundSyncConfig? get registeredConfig => _config;

  /// Last registered callback; invoked by the service-worker bridge.
  BackgroundSyncCallback? get registeredCallback => _callback;

  @override
  bool get isSupported => true;

  @override
  Future<void> register({
    required BackgroundSyncConfig config,
    required BackgroundSyncCallback onSync,
  }) async {
    _config = config;
    _callback = onSync;
  }

  @override
  Future<void> cancel() async {
    _config = null;
    _callback = null;
  }

  /// Entry point called by the service-worker bridge when the browser
  /// fires a `sync` event. Returns `true` when the sync attempt was
  /// successful (the browser may retry on failure).
  Future<bool> handleSyncEvent() async {
    final BackgroundSyncCallback? cb = _callback;
    if (cb == null) {
      return true;
    }
    try {
      return await cb();
    } catch (_) {
      return false;
    }
  }
}
